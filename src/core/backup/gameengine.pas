unit GameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Map, Player, ResourceManager, Graphics;

type
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
    constructor Create(ATileSize: Integer; const ResourceRoot: string);
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
  Math, LCLType, Dialogs;

const
  DIAGONAL_FACTOR = 0.7071067812;

constructor TGameEngine.Create(ATileSize: Integer; const ResourceRoot, LevelsPath: string);
begin
  FLevelsPath := LevelsPath;
  FResources := TResourceManager.Create(ATileSize, ResourceRoot);
  FMap := TMap.Create(ATileSize);
  FPlayer := TPlayer.Create(ATileSize, 100); // скорость 100 пикс/сек
  FSpeed := 100;
  FTransitions := nil;
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
  SetMoveFlags(False, False, False, False);
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
  Tokens: array of string;
  Trans: TTransition;

  function SplitString(const S: string; Delimiter: Char): TStringArray;
  var
    j, start: Integer;
  begin
    SetLength(Result, 0);
    start := 1;
    for j := 1 to Length(S) do
      if S[j] = Delimiter then
      begin
        if j > start then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := Copy(S, start, j - start);
        end;
        start := j + 1;
      end;
    if start <= Length(S) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Copy(S, start, MaxInt);
    end;
  end;

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
        trans.SrcX := StrToInt(Tokens[0]);
        trans.SrcY := StrToInt(Tokens[1]);
        trans.DestMap := Tokens[2];
        trans.DestX := StrToInt(Tokens[3]);
        trans.DestY := StrToInt(Tokens[4]);
        SetLength(FTransitions, Length(FTransitions) + 1);
        FTransitions[High(FTransitions)] := trans;
      end;
      Inc(i);
    end;

    // Загрузка спрайтов игрока (один раз, можно вынести)
    FResources.LoadPlayerSprites;

  finally
    TileNames.Free;
    Lines.Free;
  end;
end;

end.
