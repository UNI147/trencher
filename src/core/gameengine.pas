unit GameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Map, Player, ResourceManager, Graphics, Level, GameTypes;

type
  TGameEngine = class
  private
    FLevel: TLevel;
    FPlayer: TPlayer;
    FResources: TResourceManager;
    FSpeed: Double;
    FMoveLeft, FMoveRight, FMoveUp, FMoveDown: Boolean;
    FLevelsPath: string;
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
  end;

implementation

uses
  Math;

const
  DIAGONAL_FACTOR = 0.7071067812;

constructor TGameEngine.Create(ATileSize: Integer; const ResourceRoot, LevelsPath: string);
begin
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
end;

destructor TGameEngine.Destroy;
begin
  FLevel.Free;
  FResources.Free;
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

procedure TGameEngine.LoadLevel(const Filename: string);
begin
  if Assigned(FLevel) then
    FLevel.Free;

  // Используем размер тайла из FPlayer для создания уровня
  FLevel := TLevel.Create(FPlayer.TileSize, FResources);
  FLevel.LoadFromFile(FLevelsPath + Filename);
  FPlayer.SetPositionByTile(FLevel.StartX, FLevel.StartY);
  UpdateInput(False, False, False, False);
end;

procedure TGameEngine.Update(DeltaTime: Double);
var
  MoveX, MoveY: Double;
  OldTileX, OldTileY: Integer;
  Moved: Boolean;
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

  OldTileX := FPlayer.TileX;
  OldTileY := FPlayer.TileY;

  if (MoveX <> 0) or (MoveY <> 0) then
  begin
    FPlayer.Move(MoveX, MoveY, FLevel.Map, @IsCellSolid);
    Moved := True;
  end
  else
    Moved := False;

  FResources.UpdateAnimation(DeltaTime);

  // Используем Player.TileSize (теперь работает!)
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

    // Карта
    for y := 0 to FLevel.Map.Height - 1 do
      for x := 0 to FLevel.Map.Width - 1 do
        if FLevel.Map.Tiles[x, y] >= 0 then
        begin
          TileBmp := FResources.GetTileImage(FLevel.Map.Tiles[x, y]);
          if TileBmp <> nil then
            VirtualBmp.Canvas.Draw(x * FLevel.Map.TileSize, y * FLevel.Map.TileSize, TileBmp);
        end;

    // Спрайты за игроком
    BehindSprites := FLevel.BehindSprites;
    for i := 0 to High(BehindSprites) do
    begin
      SpriteBmp := FResources.GetSpriteImage(BehindSprites[i].SpriteIndex);
      if SpriteBmp <> nil then
        VirtualBmp.Canvas.Draw(BehindSprites[i].X * FLevel.Map.TileSize,
                               BehindSprites[i].Y * FLevel.Map.TileSize, SpriteBmp);
    end;

    // Игрок
    PlayerBmp := FResources.GetPlayerSprite(FPlayer.Frame);
    if PlayerBmp <> nil then
      VirtualBmp.Canvas.Draw(Round(FPlayer.PixelX), Round(FPlayer.PixelY), PlayerBmp);

    // Спрайты перед игроком
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

end.
