unit GameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Map, Player, ResourceManager, Graphics, Level, GameTypes,
  SoundManager, Logger;

type
  TGameEngine = class
  private
    FLevel: TLevel;
    FPlayer: TPlayer;
    FResources: TResourceManager;
    FSpeed: Double;
    FMoveLeft, FMoveRight, FMoveUp, FMoveDown: Boolean;
    FLevelsPath: string;
    FSoundManager: TSoundManager;
    FWasMoving: Boolean;
    FMusicPath, FWindPath, FStepPath: string;
    function IsCellSolid(TileX, TileY: Integer): Boolean;
    procedure CheckTransitions;
  public
    constructor Create(ATileSize: Integer; const ResourceRoot, LevelsPath: string);
    destructor Destroy; override;
    procedure LoadLevel(const Filename: string);
    procedure Update(DeltaTime: Double);
    procedure UpdateInput(Left, Right, Up, Down: Boolean);
    procedure Render(Canvas: TCanvas; DestRect: TRect);
    property Player: TPlayer read FPlayer;
    procedure InitSounds(const MusicFile, WindFile, StepFile: string);
    procedure StartMovingSounds;
    procedure StopMovingSounds;
  end;

implementation

const
  DIAGONAL_FACTOR = 0.7071067812;  // 1/sqrt(2)

constructor TGameEngine.Create(ATileSize: Integer; const ResourceRoot, LevelsPath: string);
begin
  LogDebug('TGameEngine.Create started');
  FLevelsPath := LevelsPath;
  FResources := TResourceManager.Create(ATileSize, ResourceRoot);
  FResources.LoadPlayerSprites;
  FPlayer := TPlayer.Create(ATileSize, 100);
  FSpeed := 100;
  FLevel := nil;
  FMoveLeft := False;
  FMoveRight := False;
  FMoveUp := False;
  FMoveDown := False;
  FSoundManager := TSoundManager.Create;
  FWasMoving := False;
  LogDebug('TGameEngine.Create completed');
end;

destructor TGameEngine.Destroy;
begin
  LogDebug('TGameEngine.Destroy started');
  FLevel.Free;
  FResources.Free;
  FPlayer.Free;
  FSoundManager.Free;
  inherited;
  LogDebug('TGameEngine.Destroy completed');
end;

procedure TGameEngine.UpdateInput(Left, Right, Up, Down: Boolean);
begin
  FMoveLeft := Left;
  FMoveRight := Right;
  FMoveUp := Up;
  FMoveDown := Down;
end;

procedure TGameEngine.LoadLevel(const Filename: string);
begin
  LogDebug('Loading level: ' + Filename);
  if Assigned(FLevel) then
    FLevel.Free;

  FLevel := TLevel.Create(FPlayer.TileSize, FResources);
  FLevel.LoadFromFile(FLevelsPath + Filename);
  FPlayer.SetPositionByTile(FLevel.StartX, FLevel.StartY);
  UpdateInput(False, False, False, False);
  LogDebug('Level loaded. Start position: (' + IntToStr(FLevel.StartX) + ', ' + IntToStr(FLevel.StartY) + ')');
end;

procedure TGameEngine.Update(DeltaTime: Double);
var
  MoveX, MoveY: Double;
  OldTileX, OldTileY: Integer;
  Moved: Boolean;
  IsMoving: Boolean;
begin
  if FLevel = nil then Exit;

  MoveX := 0; MoveY := 0;
  if FMoveLeft then MoveX := -FSpeed * DeltaTime;
  if FMoveRight then MoveX := FSpeed * DeltaTime;
  if FMoveUp then MoveY := -FSpeed * DeltaTime;
  if FMoveDown then MoveY := FSpeed * DeltaTime;

  if (MoveX <> 0) and (MoveY <> 0) then
  begin
    MoveX := MoveX * DIAGONAL_FACTOR;
    MoveY := MoveY * DIAGONAL_FACTOR;
  end;

  IsMoving := (MoveX <> 0) or (MoveY <> 0);

  // Управление звуками движения
  if IsMoving and not FWasMoving then
  begin
    LogDebug('Movement started - playing step sound');
    StartMovingSounds;
  end
  else if not IsMoving and FWasMoving then
  begin
    LogDebug('Movement stopped - stopping step sound');
    StopMovingSounds;
  end;
  FWasMoving := IsMoving;

  OldTileX := FPlayer.TileX;
  OldTileY := FPlayer.TileY;

  if IsMoving then
  begin
    FPlayer.Move(MoveX, MoveY, FLevel.Map, @IsCellSolid);
    Moved := True;
  end
  else
    Moved := False;

  FResources.UpdateAnimation(DeltaTime);

  FLevel.UpdateDynamicLayers(Round(FPlayer.PixelY + FPlayer.TileSize));

  if (FPlayer.TileX <> OldTileX) or (FPlayer.TileY <> OldTileY) then
    CheckTransitions;

  FPlayer.UpdateAnimation(Moved);
end;

procedure TGameEngine.CheckTransitions;
var
  i: Integer;
  Transitions: TTransitionArray;
  CurrentTileX, CurrentTileY: Integer;
  DestMap: string;
  DestX, DestY: Integer;
begin
  if FLevel = nil then Exit;
  Transitions := FLevel.Transitions;
  CurrentTileX := FPlayer.TileX;
  CurrentTileY := FPlayer.TileY;

  for i := 0 to High(Transitions) do
    if (Transitions[i].SrcX = CurrentTileX) and (Transitions[i].SrcY = CurrentTileY) then
    begin
      LogDebug('Transition triggered at (' + IntToStr(CurrentTileX) + ', ' + IntToStr(CurrentTileY) + ')');
      LogDebug('  Dest: ' + Transitions[i].DestMap + ' at (' + IntToStr(Transitions[i].DestX) + ', ' + IntToStr(Transitions[i].DestY) + ')');

      DestMap := Transitions[i].DestMap;
      DestX := Transitions[i].DestX;
      DestY := Transitions[i].DestY;
      LoadLevel(DestMap);
      FPlayer.SetPositionByTile(DestX, DestY);
      Break;
    end;
end;

function TGameEngine.IsCellSolid(TileX, TileY: Integer): Boolean;
begin
  if (TileX < 0) or (TileX >= FLevel.Map.Width) or (TileY < 0) or (TileY >= FLevel.Map.Height) then
    Result := True
  else
    Result := FResources.IsTileSolid(FLevel.Map.Tiles[TileX, TileY]) or FLevel.IsSpriteSolid(TileX, TileY);
end;

procedure TGameEngine.Render(Canvas: TCanvas; DestRect: TRect);
var
  VirtualBmp: TBitmap;
  x, y, i: Integer;
  TileBmp, PlayerBmp, SpriteBmp: TBitmap;
  BehindSprites, FrontSprites: TMapSpriteArray;
begin
  if FLevel = nil then Exit;

  VirtualBmp := TBitmap.Create;
  try
    VirtualBmp.SetSize(FLevel.Map.Width * FLevel.Map.TileSize, FLevel.Map.Height * FLevel.Map.TileSize);
    VirtualBmp.Canvas.Brush.Color := clBlack;
    VirtualBmp.Canvas.FillRect(0, 0, VirtualBmp.Width, VirtualBmp.Height);

    for y := 0 to FLevel.Map.Height - 1 do
      for x := 0 to FLevel.Map.Width - 1 do
        if FLevel.Map.Tiles[x, y] >= 0 then
        begin
          TileBmp := FResources.GetTileImage(FLevel.Map.Tiles[x, y]);
          if TileBmp <> nil then
            VirtualBmp.Canvas.Draw(x * FLevel.Map.TileSize, y * FLevel.Map.TileSize, TileBmp);
        end;

    BehindSprites := FLevel.BehindSprites;
    for i := 0 to High(BehindSprites) do
    begin
      SpriteBmp := FResources.GetSpriteImage(BehindSprites[i].SpriteIndex);
      if SpriteBmp <> nil then
        VirtualBmp.Canvas.Draw(BehindSprites[i].X * FLevel.Map.TileSize,
                               BehindSprites[i].Y * FLevel.Map.TileSize, SpriteBmp);
    end;

    PlayerBmp := FResources.GetPlayerSprite(FPlayer.Frame);
    if PlayerBmp <> nil then
      VirtualBmp.Canvas.Draw(Round(FPlayer.PixelX), Round(FPlayer.PixelY), PlayerBmp);

    FrontSprites := FLevel.FrontSprites;
    for i := 0 to High(FrontSprites) do
    begin
      SpriteBmp := FResources.GetSpriteImage(FrontSprites[i].SpriteIndex);
      if SpriteBmp <> nil then
        VirtualBmp.Canvas.Draw(FrontSprites[i].X * FLevel.Map.TileSize,
                               FrontSprites[i].Y * FLevel.Map.TileSize, SpriteBmp);
    end;

    Canvas.StretchDraw(DestRect, VirtualBmp);
  finally
    VirtualBmp.Free;
  end;
end;

procedure TGameEngine.InitSounds(const MusicFile, WindFile, StepFile: string);
begin
  LogSound('Initializing sounds...');
  LogSound('  Music: ' + MusicFile);
  LogSound('  Wind: ' + WindFile);
  LogSound('  Step: ' + StepFile);

  FMusicPath := MusicFile;
  FWindPath := WindFile;
  FStepPath := StepFile;

  if FileExists(MusicFile) then
  begin
    LogSound('Music file exists, playing...');
    FSoundManager.PlayMusic(FMusicPath, True);
  end
  else
    LogError('Music file not found: ' + MusicFile);

  if FileExists(WindFile) then
  begin
    LogSound('Wind file exists, playing...');
    FSoundManager.PlayWind(FWindPath, True);
  end
  else
    LogError('Wind file not found: ' + WindFile);
end;

procedure TGameEngine.StartMovingSounds;
begin
  LogSound('StartMovingSounds called');
  if FStepPath <> '' then
  begin
    if FileExists(FStepPath) then
    begin
      LogSound('Playing step sound: ' + FStepPath);
      FSoundManager.PlayStep(FStepPath, True);
    end
    else
      LogError('Step file not found: ' + FStepPath);
  end
  else
  begin
    LogError('FStepPath is empty');
    FSoundManager.PlayStep(ExtractFilePath(ParamStr(0)) + 'resources\effects\step.wav', True);
  end;
end;

procedure TGameEngine.StopMovingSounds;
begin
  LogSound('StopMovingSounds called');
  FSoundManager.StopStep;
end;

end.
