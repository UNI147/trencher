unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Dialogs, LCLType, Windows,
  Graphics, Math, ExtCtrls, Types;

type
  TStringArray = array of string;

  TTransition = record
    SrcX, SrcY: Integer;
    DestMap: string;
    DestX, DestY: Integer;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormPaint(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
  private
    FTileImages: array of TBitmap;
    FMap: array of array of Integer;
    FMapWidth, FMapHeight: Integer;
    FTileSize: Integer;
    FTransitions: array of TTransition;
    FPlayerSprites: array[0..2] of TBitmap;
    FPlayerFrame: Integer;
    FPlayerPixelX, FPlayerPixelY: Double;
    FSpeed: Double;
    FAnimStep: Integer;
    FAnimTimer: Integer;
    FTimer: TTimer;

    // Флаги движения
    FMoveLeft, FMoveRight, FMoveUp, FMoveDown: Boolean;
    FLastTileX, FLastTileY: Integer;         // последний тайл, на котором был игрок

    procedure LoadLevel(const Filename: string);
    function GetFullPath(const ResourceType, FileName: string): string;
    function SplitString(const S: string; Delimiter: Char): TStringArray;
    procedure LoadPlayerSprites;
    procedure TimerTick(Sender: TObject);
    procedure CheckTransition(TileX, TileY: Integer);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  TILE_SIZE = 20;
  VIRTUAL_WIDTH = 320;
  VIRTUAL_HEIGHT = 200;
  RESOURCES_ROOT = '..\resources\';
  DIAGONAL_FACTOR = 0.7071067812;    // 1 / sqrt(2)

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  KeyPreview := True;                // гарантируем получение всех клавиш
  FTileSize := TILE_SIZE;
  LoadLevel(GetFullPath('levels', 'level.txt'));
  LoadPlayerSprites;

  FSpeed := 100; // пикселей в секунду
  FMoveLeft := False;
  FMoveRight := False;
  FMoveUp := False;
  FMoveDown := False;
  FPlayerFrame := 0;
  FAnimStep := 0;
  FAnimTimer := 0;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 41; // ~24 FPS
  FTimer.OnTimer := @TimerTick;
end;

procedure TForm1.FormDeactivate(Sender: TObject);
begin
  // Сбрасываем флаги, если форма потеряла фокус (предотвращает залипание)
  FMoveLeft := False;
  FMoveRight := False;
  FMoveUp := False;
  FMoveDown := False;
end;

function TForm1.GetFullPath(const ResourceType, FileName: string): string;
begin
  Result := ExtractFilePath(ParamStr(0)) + RESOURCES_ROOT + ResourceType + '\' + FileName;
end;

procedure TForm1.LoadLevel(const Filename: string);
var
  lines: TStringList;
  i, j, idx, w, h: Integer;
  startX, startY: Integer;
  line: string;
  tokens: TStringArray;
  tileNames: TStringList;
  pict: TPicture;
  trans: TTransition;
  tilePath: string;
begin
  // Освобождаем предыдущие данные
  for i := 0 to High(FTileImages) do
    FTileImages[i].Free;
  FTileImages := nil;
  FMap := nil;
  FTransitions := nil;

  lines := TStringList.Create;
  tileNames := TStringList.Create;
  try
    lines.LoadFromFile(Filename);
    i := 0;

    // ----- Секция #tiles -----
    while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
    if (i >= lines.Count) or (Trim(lines[i]) <> '#tiles') then
      raise Exception.Create('Ожидалась секция #tiles');
    Inc(i);
    while (i < lines.Count) and (Trim(lines[i]) <> '') and (Trim(lines[i])[1] <> '#') do
    begin
      tileNames.Add(Trim(lines[i]));
      Inc(i);
    end;

    SetLength(FTileImages, tileNames.Count);
    for j := 0 to tileNames.Count - 1 do
    begin
      FTileImages[j] := TBitmap.Create;
      pict := TPicture.Create;
      try
        tilePath := GetFullPath('tiles', tileNames[j]);
        pict.LoadFromFile(tilePath);
        FTileImages[j].Assign(pict.Bitmap);
        if (FTileImages[j].Width <> FTileSize) or (FTileImages[j].Height <> FTileSize) then
          FTileImages[j].SetSize(FTileSize, FTileSize);
      finally
        pict.Free;
      end;
    end;

    // ----- Секция #map -----
    while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
    if (i >= lines.Count) or (Trim(lines[i]) <> '#map') then
      raise Exception.Create('Ожидалась секция #map');
    Inc(i);
    while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
    line := Trim(lines[i]);
    tokens := SplitString(line, ' ');
    if Length(tokens) <> 2 then
      raise Exception.Create('Неверный формат размеров карты');
    w := StrToInt(tokens[0]);
    h := StrToInt(tokens[1]);
    FMapWidth := w;
    FMapHeight := h;
    Inc(i);

    SetLength(FMap, h, w);
    for j := 0 to h - 1 do
    begin
      while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
      if i >= lines.Count then
        raise Exception.Create('Недостаточно строк карты');
      tokens := SplitString(Trim(lines[i]), ' ');
      if Length(tokens) <> w then
        raise Exception.Create('Неверное количество тайлов в строке карты');
      for idx := 0 to w - 1 do
        FMap[j, idx] := StrToInt(tokens[idx]);
      Inc(i);
    end;

    // ----- Секция #player -----
    while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
    if (i >= lines.Count) or (Trim(lines[i]) <> '#player') then
      raise Exception.Create('Ожидалась секция #player');
    Inc(i);
    while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
    line := Trim(lines[i]);
    tokens := SplitString(line, ' ');
    if Length(tokens) <> 2 then
      raise Exception.Create('Неверный формат координат игрока');
    startX := StrToInt(tokens[0]);
    startY := StrToInt(tokens[1]);
    Inc(i);

    FPlayerPixelX := startX * FTileSize;
    FPlayerPixelY := startY * FTileSize;
    FLastTileX := startX;
    FLastTileY := startY;

    // ----- Секции #transition -----
    while i < lines.Count do
    begin
      while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
      if i >= lines.Count then Break;
      if Trim(lines[i]) <> '#transition' then
        Break;
      Inc(i);
      while (i < lines.Count) and (Trim(lines[i]) = '') do Inc(i);
      if i >= lines.Count then Break;
      line := Trim(lines[i]);
      tokens := SplitString(line, ' ');
      if Length(tokens) = 5 then
      begin
        trans.SrcX := StrToInt(tokens[0]);
        trans.SrcY := StrToInt(tokens[1]);
        trans.DestMap := tokens[2];
        trans.DestX := StrToInt(tokens[3]);
        trans.DestY := StrToInt(tokens[4]);
        SetLength(FTransitions, Length(FTransitions) + 1);
        FTransitions[High(FTransitions)] := trans;
      end;
      Inc(i);
    end;

  finally
    tileNames.Free;
    lines.Free;
  end;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_LEFT:  FMoveLeft := True;
    VK_RIGHT: FMoveRight := True;
    VK_UP:    FMoveUp := True;
    VK_DOWN:  FMoveDown := True;
    VK_ESCAPE: Close;
  end;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_LEFT:  FMoveLeft := False;
    VK_RIGHT: FMoveRight := False;
    VK_UP:    FMoveUp := False;
    VK_DOWN:  FMoveDown := False;
  end;
end;

procedure TForm1.FormPaint(Sender: TObject);
var
  Bitmap: TBitmap;
  Scale: Double;
  DestWidth, DestHeight: Integer;
  DestRect: TRect;
  x, y, idx: Integer;
begin
  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(VIRTUAL_WIDTH, VIRTUAL_HEIGHT);
    Bitmap.Canvas.Brush.Color := clBlack;
    Bitmap.Canvas.FillRect(0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT);

    if Length(FTileImages) > 0 then
      for y := 0 to FMapHeight - 1 do
        for x := 0 to FMapWidth - 1 do
        begin
          idx := FMap[y, x];
          if (idx >= 0) and (idx < Length(FTileImages)) then
            Bitmap.Canvas.Draw(x * FTileSize, y * FTileSize, FTileImages[idx]);
        end;

    if (FPlayerFrame >= 0) and (FPlayerFrame <= 2) and (FPlayerSprites[FPlayerFrame] <> nil) then
      Bitmap.Canvas.Draw(Round(FPlayerPixelX), Round(FPlayerPixelY), FPlayerSprites[FPlayerFrame]);

    Canvas.Brush.Color := clBlack;
    Canvas.FillRect(ClientRect);

    if ClientWidth / VIRTUAL_WIDTH < ClientHeight / VIRTUAL_HEIGHT then
      Scale := ClientWidth / VIRTUAL_WIDTH
    else
      Scale := ClientHeight / VIRTUAL_HEIGHT;

    DestWidth := Round(VIRTUAL_WIDTH * Scale);
    DestHeight := Round(VIRTUAL_HEIGHT * Scale);
    DestRect := Bounds(
      (ClientWidth - DestWidth) div 2,
      (ClientHeight - DestHeight) div 2,
      DestWidth, DestHeight
    );

    SetStretchBltMode(Canvas.Handle, STRETCH_DELETESCANS);
    Canvas.StretchDraw(DestRect, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

function TForm1.SplitString(const S: string; Delimiter: Char): TStringArray;
var
  i, start, cnt: Integer;
begin
  SetLength(Result, 0);
  start := 1;
  for i := 1 to Length(S) do
    if S[i] = Delimiter then
    begin
      if i > start then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Copy(S, start, i - start);
      end;
      start := i + 1;
    end;
  if start <= Length(S) then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Copy(S, start, MaxInt);
  end;
end;

procedure TForm1.LoadPlayerSprites;
var
  i: Integer;
  pict: TPicture;
  path: string;
begin
  for i := 0 to 2 do
  begin
    FPlayerSprites[i] := TBitmap.Create;
    pict := TPicture.Create;
    try
      path := GetFullPath('sprites', Format('player%d.png', [i]));
      pict.LoadFromFile(path);
      FPlayerSprites[i].Assign(pict.Bitmap);
      if (FPlayerSprites[i].Width <> FTileSize) or (FPlayerSprites[i].Height <> FTileSize) then
        FPlayerSprites[i].SetSize(FTileSize, FTileSize);
    except
      FPlayerSprites[i].SetSize(FTileSize, FTileSize);
      FPlayerSprites[i].Canvas.Brush.Color := clRed;
      FPlayerSprites[i].Canvas.FillRect(0, 0, FTileSize, FTileSize);
    end;
    pict.Free;
  end;
end;

procedure TForm1.TimerTick(Sender: TObject);
var
  delta: Double;
  moveX, moveY: Double;
  newX, newY: Double;
  tileX, tileY: Integer;
  moved: Boolean;
begin
  delta := FTimer.Interval / 1000.0;

  moveX := 0;
  moveY := 0;

  if GetAsyncKeyState(VK_LEFT) and $8000 <> 0 then
    moveX := -FSpeed * delta;
  if GetAsyncKeyState(VK_RIGHT) and $8000 <> 0 then
    moveX := FSpeed * delta;
  if GetAsyncKeyState(VK_UP) and $8000 <> 0 then
    moveY := -FSpeed * delta;
  if GetAsyncKeyState(VK_DOWN) and $8000 <> 0 then
    moveY := FSpeed * delta;

  // Коррекция диагонали
  if (moveX <> 0) and (moveY <> 0) then
  begin
    moveX := moveX * DIAGONAL_FACTOR;
    moveY := moveY * DIAGONAL_FACTOR;
  end;

  newX := FPlayerPixelX + moveX;
  newY := FPlayerPixelY + moveY;

  // Ограничение границами карты
  if newX < 0 then newX := 0;
  if newY < 0 then newY := 0;
  if newX > (FMapWidth - 1) * FTileSize then newX := (FMapWidth - 1) * FTileSize;
  if newY > (FMapHeight - 1) * FTileSize then newY := (FMapHeight - 1) * FTileSize;

  moved := (newX <> FPlayerPixelX) or (newY <> FPlayerPixelY);

  if moved then
  begin
    FPlayerPixelX := newX;
    FPlayerPixelY := newY;

    tileX := Floor(FPlayerPixelX / FTileSize);
    tileY := Floor(FPlayerPixelY / FTileSize);

    if (tileX <> FLastTileX) or (tileY <> FLastTileY) then
    begin
      CheckTransition(tileX, tileY);
      FLastTileX := tileX;
      FLastTileY := tileY;
    end;

    // Анимация
    Inc(FAnimTimer);
    if FAnimTimer >= 6 then
    begin
      FAnimTimer := 0;
      case FAnimStep of
        0: FPlayerFrame := 1;
        1: FPlayerFrame := 0;
        2: FPlayerFrame := 2;
        3: FPlayerFrame := 0;
      end;
      Inc(FAnimStep);
      if FAnimStep > 3 then FAnimStep := 0;
    end;
  end
  else
  begin
    FPlayerFrame := 0;
    FAnimStep := 0;
    FAnimTimer := 0;
  end;

  Invalidate;
end;

procedure TForm1.CheckTransition(TileX, TileY: Integer);
var
  i: Integer;
  t: TTransition;
begin
  for i := 0 to High(FTransitions) do
  begin
    t := FTransitions[i];
    if (t.SrcX = TileX) and (t.SrcY = TileY) then
    begin
      LoadLevel(GetFullPath('levels', t.DestMap));
      FPlayerPixelX := t.DestX * FTileSize;
      FPlayerPixelY := t.DestY * FTileSize;
      FLastTileX := t.DestX;
      FLastTileY := t.DestY;
      // Сбрасываем движение после перехода
      FMoveLeft := False;
      FMoveRight := False;
      FMoveUp := False;
      FMoveDown := False;
      Break;
    end;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to 2 do
    FPlayerSprites[i].Free;
end;

end.
