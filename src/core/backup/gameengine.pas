unit GameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Map, Player, ResourceManager, Graphics;

type
  TStringArray = array of string;

  TTransition = record
    SrcX, SrcY: Integer;
    DestMap: string;
    DestX, DestY: Integer;
  end;
  TTransitionArray = array of TTransition;

  TGameEngine = class
  private
    FMap: TMap;
    FPlayer: TPlayer;
    FResources: TResourceManager;
    FTransitions: TTransitionArray;
    FSpeed: Double;
    FMoveLeft, FMoveRight, FMoveUp, FMoveDown: Boolean;
    FLevelsPath: string;
    procedure CheckTransitions;
    procedure LoadLevelData(const Filename: string);
  public
    constructor Create(ATileSize: Integer; const ResourceRoot, LevelsPath: string);
    destructor Destroy; override;
    procedure LoadLevel(const Filename: string);
    procedure Update(DeltaTime: Double);
    procedure UpdateInput(Left, Right, Up, Down: Boolean);
    procedure Render(Canvas: TCanvas; DestRect: TRect);
    property Map: TMap read FMap;
    property Player: TPlayer read FPlayer;
  end;

implementation

uses
  Math;  // Убрали LCLType и Dialogs, если не используются

const
  DIAGONAL_FACTOR = 0.7071067812;

{ Вспомогательная функция SplitString }
function SplitString(const S: string; Delimiter: Char): TStringArray;
var
  i, Start: Integer;
begin
  Result := nil;  // Инициализация для устранения предупреждения
  SetLength(Result, 0);
  Start := 1;
  for i := 1 to Length(S) do
  begin
    if S[i] = Delimiter then
    begin
      if i > Start then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Copy(S, Start, i - Start);
      end;
      Start := i + 1;
    end;
  end;
  if Start <= Length(S) then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Copy(S, Start, MaxInt);
  end;
end;

{ TGameEngine }

constructor TGameEngine.Create(ATileSize: Integer; const ResourceRoot, LevelsPath: string);
begin
  FLevelsPath := LevelsPath;
  FResources := TResourceManager.Create(ATileSize, ResourceRoot);
  FMap := TMap.Create(ATileSize);
  FPlayer := TPlayer.Create(ATileSize, 100);
  FSpeed := 100;
  FTransitions := nil;
  FMoveLeft := False;
  FMoveRight := False;
  FMoveUp := False;
  FMoveDown := False;
end;

destructor TGameEngine.Destroy;
begin
  FResources.Free;
  FMap.Free;
  FPlayer.Free;
  inherited;
end;

procedure TGameEngine.UpdateInput(Left, Right, Up, Down: Boolean);
begin
  FMoveLeft := Left;
  FMoveRight := Right;
  FMoveUp := Up;
  FMoveDown := Down;
end;

procedure TGameEngine.Update(DeltaTime: Double);
var
  MoveX, MoveY: Double;
  OldTileX, OldTileY: Integer;
  Moved: Boolean;
begin
  MoveX := 0;
  MoveY := 0;

  if FMoveLeft then MoveX := -FSpeed * DeltaTime;
  if FMoveRight then MoveX := FSpeed * DeltaTime;
  if FMoveUp then MoveY := -FSpeed * DeltaTime;
  if FMoveDown then MoveY := FSpeed * DeltaTime;

  // Коррекция диагонали
  if (MoveX <> 0) and (MoveY <> 0) then
  begin
    MoveX := MoveX * DIAGONAL_FACTOR;
    MoveY := MoveY * DIAGONAL_FACTOR;
  end;

  OldTileX := FPlayer.TileX;
  OldTileY := FPlayer.TileY;

  if (MoveX <> 0) or (MoveY <> 0) then
  begin
    FPlayer.Move(MoveX, MoveY, FMap.Width, FMap.Height);
    Moved := True;
  end
  else
    Moved := False;

  // Проверка переходов при смене тайла
  if (FPlayer.TileX <> OldTileX) or (FPlayer.TileY <> OldTileY) then
    CheckTransitions;

  FPlayer.UpdateAnimation(Moved);
end;

procedure TGameEngine.CheckTransitions;
var
  i: Integer;
  CurrentTileX, CurrentTileY: Integer;
begin
  CurrentTileX := FPlayer.TileX;
  CurrentTileY := FPlayer.TileY;

  for i := 0 to High(FTransitions) do
  begin
    if (FTransitions[i].SrcX = CurrentTileX) and
       (FTransitions[i].SrcY = CurrentTileY) then
    begin
      LoadLevel(FTransitions[i].DestMap);
      FPlayer.SetPositionByTile(FTransitions[i].DestX, FTransitions[i].DestY);
      Break;
    end;
  end;
end;

procedure TGameEngine.LoadLevel(const Filename: string);
begin
  LoadLevelData(FLevelsPath + Filename);
  // Сбрасываем флаги движения после загрузки уровня
  UpdateInput(False, False, False, False);  // Вместо SetMoveFlags
end;

procedure TGameEngine.Render(Canvas: TCanvas; DestRect: TRect);
var
  VirtualBmp: TBitmap;
  x, y, Idx: Integer;
  TileBmp: TBitmap;
  PlayerBmp: TBitmap;
begin
  VirtualBmp := TBitmap.Create;
  try
    VirtualBmp.SetSize(FMap.Width * FMap.TileSize, FMap.Height * FMap.TileSize);
    VirtualBmp.Canvas.Brush.Color := clBlack;
    VirtualBmp.Canvas.FillRect(0, 0, VirtualBmp.Width, VirtualBmp.Height);

    // Отрисовка карты
    for y := 0 to FMap.Height - 1 do
      for x := 0 to FMap.Width - 1 do
      begin
        Idx := FMap.Tiles[x, y];
        if Idx >= 0 then
        begin
          TileBmp := FResources.GetTileImage(Idx);
          if TileBmp <> nil then
            VirtualBmp.Canvas.Draw(x * FMap.TileSize, y * FMap.TileSize, TileBmp);
        end;
      end;

    // Отрисовка игрока
    PlayerBmp := FResources.GetPlayerSprite(FPlayer.Frame);
    if PlayerBmp <> nil then
      VirtualBmp.Canvas.Draw(Round(FPlayer.PixelX), Round(FPlayer.PixelY), PlayerBmp);

    // Масштабирование на форму
    Canvas.StretchDraw(DestRect, VirtualBmp);
  finally
    VirtualBmp.Free;
  end;
end;

procedure TGameEngine.LoadLevelData(const Filename: string);
var
  Lines: TStringList;
  i, W, H, StartX, StartY: Integer;
  TileNames: TStringList;
  Line: string;
  Tokens: TStringArray;
  Trans: TTransition;
begin
  Lines := TStringList.Create;
  TileNames := TStringList.Create;
  try
    Lines.LoadFromFile(Filename);
    i := 0;

    // #tiles секция
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i >= Lines.Count) or (Trim(Lines[i]) <> '#tiles') then
      raise Exception.Create('Ожидалась секция #tiles');
    Inc(i);
    while (i < Lines.Count) and (Trim(Lines[i]) <> '') and (Trim(Lines[i])[1] <> '#') do
    begin
      TileNames.Add(Trim(Lines[i]));
      Inc(i);
    end;

    // Загрузка тайлов через ResourceManager
    FResources.LoadTiles(TileNames);

    // #map секция
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i >= Lines.Count) or (Trim(Lines[i]) <> '#map') then
      raise Exception.Create('Ожидалась секция #map');
    Inc(i);
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    Line := Trim(Lines[i]);
    Tokens := SplitString(Line, ' ');
    if Length(Tokens) <> 2 then
      raise Exception.Create('Неверный формат размеров карты');
    W := StrToInt(Tokens[0]);
    H := StrToInt(Tokens[1]);
    Inc(i);

    // Загрузка карты
    FMap.LoadFromStrings(Lines, i, W, H);
    Inc(i, H);

    // #player секция
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i >= Lines.Count) or (Trim(Lines[i]) <> '#player') then
      raise Exception.Create('Ожидалась секция #player');
    Inc(i);
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    Line := Trim(Lines[i]);
    Tokens := SplitString(Line, ' ');
    if Length(Tokens) <> 2 then
      raise Exception.Create('Неверный формат координат игрока');
    StartX := StrToInt(Tokens[0]);
    StartY := StrToInt(Tokens[1]);
    Inc(i);

    FPlayer.SetPositionByTile(StartX, StartY);

    // #transition секции
    FTransitions := nil;
    while i < Lines.Count do
    begin
      while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
      if i >= Lines.Count then Break;
      if Trim(Lines[i]) <> '#transition' then
        Break;
      Inc(i);
      while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
      if i >= Lines.Count then Break;
      Line := Trim(Lines[i]);
      Tokens := SplitString(Line, ' ');
      if Length(Tokens) = 5 then
      begin
        Trans.SrcX := StrToInt(Tokens[0]);
        Trans.SrcY := StrToInt(Tokens[1]);
        Trans.DestMap := Tokens[2];
        Trans.DestX := StrToInt(Tokens[3]);
        Trans.DestY := StrToInt(Tokens[4]);
        SetLength(FTransitions, Length(FTransitions) + 1);
        FTransitions[High(FTransitions)] := Trans;
      end;
      Inc(i);
    end;

    // Загрузка спрайтов игрока
    FResources.LoadPlayerSprites;

  finally
    TileNames.Free;
    Lines.Free;
  end;
end;

end.
