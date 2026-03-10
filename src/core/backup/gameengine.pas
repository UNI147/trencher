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

  TSpriteLayer = (slBehind, slFront);  // Четкое разделение слоев

  TMapSprite = record
    X, Y: Integer;          // тайловые координаты
    SpriteIndex: Integer;    // индекс в FSpriteResources
    IsSolid: Boolean;
    Layer: TSpriteLayer;     // вместо IsBehind
    BaseY: Integer;          // Базовая Y-координата для перспективы (низ спрайта)
  end;
  TMapSpriteArray = array of TMapSprite;

  TIsSolidFunc = function(TileX, TileY: Integer): Boolean of object;

  TGameEngine = class
  private
    FMap: TMap;
    FPlayer: TPlayer;
    FResources: TResourceManager;
    FTransitions: TTransitionArray;
    FSpeed: Double;
    FMoveLeft, FMoveRight, FMoveUp, FMoveDown: Boolean;
    FLevelsPath: string;
    FSprites: TMapSpriteArray;
    FBehindSprites: TMapSpriteArray;  // Спрайты за игроком
    FFrontSprites: TMapSpriteArray;   // Спрайты перед игроком
    FDynamicSprites: TMapSpriteArray; // Спрайты с динамическим слоем (перспектива)
    FSolidSpriteMap: array of array of Boolean;
    function IsCellSolid(TileX, TileY: Integer): Boolean;
    procedure CheckTransitions;
    procedure LoadLevelData(const Filename: string);
    procedure SortSpritesByLayer;
    procedure UpdateDynamicLayers; // Новый метод для обновления перспективных слоев
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
  Math;

const
  DIAGONAL_FACTOR = 0.7071067812;

{ Вспомогательная функция SplitString }
function SplitString(const S: string; Delimiter: Char): TStringArray;
var
  i, Start: Integer;
begin
  Result := nil;
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
  FSprites := nil;
  FBehindSprites := nil;
  FFrontSprites := nil;
  FDynamicSprites := nil;
  FSolidSpriteMap := nil;
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

  if (MoveX <> 0) and (MoveY <> 0) then
  begin
    MoveX := MoveX * DIAGONAL_FACTOR;
    MoveY := MoveY * DIAGONAL_FACTOR;
  end;

  OldTileX := FPlayer.TileX;
  OldTileY := FPlayer.TileY;

  if (MoveX <> 0) or (MoveY <> 0) then
  begin
    FPlayer.Move(MoveX, MoveY, FMap, @IsCellSolid);
    Moved := True;
  end
  else
    Moved := False;

  // Обновление анимации тайлов и спрайтов
  FResources.UpdateAnimation(DeltaTime);

  // Обновление динамических слоев спрайтов (перспектива)
  UpdateDynamicLayers;

  if (FPlayer.TileX <> OldTileX) or (FPlayer.TileY <> OldTileY) then
    CheckTransitions;

  FPlayer.UpdateAnimation(Moved);
end;

procedure TGameEngine.UpdateDynamicLayers;
var
  i: Integer;
  PlayerFootY, PlayerCenterY: Integer;
  SpriteBottomY, SpriteTopY: Integer;
  SpriteHeight: Integer;
begin
  // Получаем координаты игрока
  PlayerFootY := Round(FPlayer.PixelY + FMap.TileSize); // Низ игрока (Y + высота)
  PlayerCenterY := Round(FPlayer.PixelY + FMap.TileSize div 2); // Центр игрока для более плавного перехода

  // Очищаем динамические массивы
  SetLength(FBehindSprites, 0);
  SetLength(FFrontSprites, 0);

  // Распределяем спрайты по слоям с учетом перспективы
  for i := 0 to High(FSprites) do
  begin
    // Получаем высоту спрайта из ресурсов
    SpriteHeight := FResources.GetSpriteHeight(FSprites[i].SpriteIndex);

    // Вычисляем верх и низ спрайта
    SpriteTopY := FSprites[i].Y * FMap.TileSize; // Верх спрайта
    SpriteBottomY := SpriteTopY + SpriteHeight; // Низ спрайта

    // Определяем слой отрисовки
    if FSprites[i].Layer = slBehind then
    begin
      // Спрайты, которые всегда должны быть за игроком
      SetLength(FBehindSprites, Length(FBehindSprites) + 1);
      FBehindSprites[High(FBehindSprites)] := FSprites[i];
    end
    else
    begin
      // Для спрайтов с динамическим слоем применяем перспективную коррекцию

      // Классическая перспектива:
      // - Если верх спрайта выше центра игрока (спрайт выше по экрану) -> спрайт ЗА игроком
      // - Если верх спрайта ниже центра игрока (спрайт ниже по экрану) -> спрайт ПЕРЕД игроком

      if SpriteTopY < PlayerCenterY then
      begin
        // Спрайт выше центра игрока - рисуем ЗА игроком
        SetLength(FBehindSprites, Length(FBehindSprites) + 1);
        FBehindSprites[High(FBehindSprites)] := FSprites[i];
      end
      else
      begin
        // Спрайт ниже центра игрока - рисуем ПЕРЕД игроком
        SetLength(FFrontSprites, Length(FFrontSprites) + 1);
        FFrontSprites[High(FFrontSprites)] := FSprites[i];
      end;

      {
      // Альтернативный вариант: сравнение по центру спрайта
      // Может дать более плавный переход

      SpriteCenterY := SpriteTopY + SpriteHeight div 2;

      if SpriteCenterY < PlayerCenterY then
        // Спрайт выше центра игрока - ЗА игроком
        SetLength(FBehindSprites, Length(FBehindSprites) + 1)
      else
        // Спрайт ниже центра игрока - ПЕРЕД игроком
        SetLength(FFrontSprites, Length(FFrontSprites) + 1);
      }
    end;
  end;
end;

procedure TGameEngine.CheckTransitions;
var
  i: Integer;
  CurrentTileX, CurrentTileY: Integer;
  DestMap: string;
  DestX, DestY: Integer;
begin
  CurrentTileX := FPlayer.TileX;
  CurrentTileY := FPlayer.TileY;

  for i := 0 to High(FTransitions) do
  begin
    if (FTransitions[i].SrcX = CurrentTileX) and
       (FTransitions[i].SrcY = CurrentTileY) then
    begin
      // Сохраняем параметры перехода ДО загрузки нового уровня
      DestMap := FTransitions[i].DestMap;
      DestX := FTransitions[i].DestX;
      DestY := FTransitions[i].DestY;

      LoadLevel(DestMap);                // после этого FTransitions уже новый
      FPlayer.SetPositionByTile(DestX, DestY);

      Break;
    end;
  end;
end;

procedure TGameEngine.LoadLevel(const Filename: string);
begin
  LoadLevelData(FLevelsPath + Filename);
  // Сбрасываем флаги движения после загрузки уровня
  UpdateInput(False, False, False, False);
end;

procedure TGameEngine.SortSpritesByLayer;
var
  i: Integer;
  BehindCount, FrontCount: Integer;
begin
  // Подсчитываем количество спрайтов в каждом слое
  BehindCount := 0;
  FrontCount := 0;

  for i := 0 to High(FSprites) do
  begin
    if FSprites[i].Layer = slBehind then
      Inc(BehindCount)
    else
      Inc(FrontCount);
  end;

  // Выделяем память для массивов
  SetLength(FBehindSprites, BehindCount);
  SetLength(FFrontSprites, FrontCount);

  // Заполняем массивы
  BehindCount := 0;
  FrontCount := 0;

  for i := 0 to High(FSprites) do
  begin
    if FSprites[i].Layer = slBehind then
    begin
      FBehindSprites[BehindCount] := FSprites[i];
      Inc(BehindCount);
    end
    else
    begin
      FFrontSprites[FrontCount] := FSprites[i];
      Inc(FrontCount);
    end;
  end;
end;

procedure TGameEngine.Render(Canvas: TCanvas; DestRect: TRect);
var
  VirtualBmp: TBitmap;
  x, y, i: Integer;
  TileBmp: TBitmap;
  PlayerBmp: TBitmap;
  SpriteBmp: TBitmap;
begin
  VirtualBmp := TBitmap.Create;
  try
    VirtualBmp.SetSize(FMap.Width * FMap.TileSize, FMap.Height * FMap.TileSize);
    VirtualBmp.Canvas.Brush.Color := clBlack;
    VirtualBmp.Canvas.FillRect(0, 0, VirtualBmp.Width, VirtualBmp.Height);

    // 1. Отрисовка карты (всегда самый нижний слой)
    for y := 0 to FMap.Height - 1 do
      for x := 0 to FMap.Width - 1 do
      begin
        if FMap.Tiles[x, y] >= 0 then
        begin
          TileBmp := FResources.GetTileImage(FMap.Tiles[x, y]);
          if TileBmp <> nil then
            VirtualBmp.Canvas.Draw(x * FMap.TileSize, y * FMap.TileSize, TileBmp);
        end;
      end;

    // 2. Спрайты за игроком (нижний слой - behind + динамические спрайты снизу)
    for i := 0 to High(FBehindSprites) do
    begin
      SpriteBmp := FResources.GetSpriteImage(FBehindSprites[i].SpriteIndex);
      if SpriteBmp <> nil then
        VirtualBmp.Canvas.Draw(FBehindSprites[i].X * FMap.TileSize,
                               FBehindSprites[i].Y * FMap.TileSize, SpriteBmp);
    end;

    // 3. Игрок (средний слой)
    PlayerBmp := FResources.GetPlayerSprite(FPlayer.Frame);
    if PlayerBmp <> nil then
      VirtualBmp.Canvas.Draw(Round(FPlayer.PixelX), Round(FPlayer.PixelY), PlayerBmp);

    // 4. Спрайты перед игроком (верхний слой - front + динамические спрайты сверху)
    for i := 0 to High(FFrontSprites) do
    begin
      SpriteBmp := FResources.GetSpriteImage(FFrontSprites[i].SpriteIndex);
      if SpriteBmp <> nil then
        VirtualBmp.Canvas.Draw(FFrontSprites[i].X * FMap.TileSize,
                               FFrontSprites[i].Y * FMap.TileSize, SpriteBmp);
    end;

    // Масштабирование на форму
    Canvas.StretchDraw(DestRect, VirtualBmp);
  finally
    VirtualBmp.Free;
  end;
end;

procedure TGameEngine.LoadLevelData(const Filename: string);
var
  Lines: TStringList;
  i, j, W, H, StartX, StartY: Integer;
  TileNames: TStringList;
  Line: string;
  Tokens: TStringArray;
  FileNames: TStringArray;
  Desc: string;
  IsSolid, IsBehind: Boolean;
  SpriteResIndex: Integer;
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

    // Инициализация карты твёрдых спрайтов
    SetLength(FSolidSpriteMap, FMap.Height, FMap.Width);
    for StartY := 0 to FMap.Height - 1 do
      for StartX := 0 to FMap.Width - 1 do
        FSolidSpriteMap[StartY, StartX] := False;

    // #sprites секция
    FSprites := nil;
    FBehindSprites := nil;
    FFrontSprites := nil;

    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i < Lines.Count) and (Trim(Lines[i]) = '#sprites') then
    begin
      Inc(i);
      while i < Lines.Count do
      begin
        while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
        if i >= Lines.Count then Break;
        if Trim(Lines[i])[1] = '#' then Break;

        Line := Trim(Lines[i]);
        Tokens := SplitString(Line, ' ');
        if Length(Tokens) < 3 then
          raise Exception.Create('Invalid sprite line: ' + Line);
        StartX := StrToInt(Tokens[0]);
        StartY := StrToInt(Tokens[1]);

        Desc := '';
        for j := 2 to High(Tokens) do
        begin
          if j > 2 then Desc := Desc + ' ';
          Desc := Desc + Tokens[j];
        end;

        FResources.ParseSpriteDescription(Desc, FileNames, IsSolid, IsBehind);
        SpriteResIndex := FResources.AddSpriteFrames(FileNames);

        SetLength(FSprites, Length(FSprites) + 1);
        with FSprites[High(FSprites)] do
        begin
          X := StartX;
          Y := StartY;
          SpriteIndex := SpriteResIndex;
          IsSolid := IsSolid;
          if IsBehind then
            Layer := slBehind
          else
            Layer := slFront;
          BaseY := FMap.TileSize; // По умолчанию высота спрайта = размеру тайла
        end;

        if IsSolid and (StartY >= 0) and (StartY < FMap.Height) and
           (StartX >= 0) and (StartX < FMap.Width) then
          FSolidSpriteMap[StartY, StartX] := True;

        Inc(i);
      end;
    end;

    // Сортируем спрайты по слоям после загрузки
    SortSpritesByLayer;

    // Загрузка спрайтов игрока
    FResources.LoadPlayerSprites;

  finally
    TileNames.Free;
    Lines.Free;
  end;

end;

function TGameEngine.IsCellSolid(TileX, TileY: Integer): Boolean;
begin
  if (TileX < 0) or (TileX >= FMap.Width) or (TileY < 0) or (TileY >= FMap.Height) then
    Result := True   // границы карты считаются непроходимыми
  else
    Result := FResources.IsTileSolid(FMap.Tiles[TileX, TileY]) or FSolidSpriteMap[TileY, TileX];
end;

end.
