unit Player;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Map;

type
  TIsSolidFunc = function(TileX, TileY: Integer): Boolean of object;

  TPlayer = class
  private
    FPixelX, FPixelY: Double;
    FTileSize: Integer;
    FSpeed: Double;
    FLastTileX, FLastTileY: Integer;
    FFrame: Integer;
    FAnimStep: Integer;
    FAnimTimer: Integer;
    procedure UpdateTilePosition;
  public
    constructor Create(ATileSize: Integer; ASpeed: Double);
    procedure SetPositionByTile(TileX, TileY: Integer);
    procedure Move(DeltaX, DeltaY: Double; Map: TMap; IsSolidCallback: TIsSolidFunc);
    procedure UpdateAnimation(Moved: Boolean);
    property PixelX: Double read FPixelX;
    property PixelY: Double read FPixelY;
    property TileX: Integer read FLastTileX;
    property TileY: Integer read FLastTileY;
    property Frame: Integer read FFrame;
    property TileSize: Integer read FTileSize;
  end;

implementation

constructor TPlayer.Create(ATileSize: Integer; ASpeed: Double);
begin
  FTileSize := ATileSize;
  FSpeed := ASpeed;
  FPixelX := 0;
  FPixelY := 0;
  FLastTileX := 0;
  FLastTileY := 0;
  FFrame := 0;
  FAnimStep := 0;
  FAnimTimer := 0;
end;

procedure TPlayer.SetPositionByTile(TileX, TileY: Integer);
begin
  FPixelX := TileX * FTileSize;
  FPixelY := TileY * FTileSize;
  FLastTileX := TileX;
  FLastTileY := TileY;
end;

procedure TPlayer.Move(DeltaX, DeltaY: Double; Map: TMap; IsSolidCallback: TIsSolidFunc);
var
  newX, newY: Double;
  w, h: Integer;

  function RectCollides(x, y: Double): Boolean;
  var
    leftTile, rightTile, topTile, bottomTile, tx, ty: Integer;
  begin
    leftTile := Floor(x / FTileSize);
    rightTile := Floor((x + w - 1) / FTileSize);
    topTile := Floor(y / FTileSize);
    bottomTile := Floor((y + h - 1) / FTileSize);

    // Проверка границ карты
    if leftTile < 0 then leftTile := 0;
    if rightTile >= Map.Width then rightTile := Map.Width - 1;
    if topTile < 0 then topTile := 0;
    if bottomTile >= Map.Height then bottomTile := Map.Height - 1;

    // Проверка столкновений через callback
    for ty := topTile to bottomTile do
      for tx := leftTile to rightTile do
        if IsSolidCallback(tx, ty) then
          Exit(True);

    Result := False;
  end;

begin
  w := FTileSize;
  h := FTileSize;

  // Движение по X
  if DeltaX <> 0 then
  begin
    newX := FPixelX + DeltaX;
    // Границы карты
    if newX < 0 then newX := 0;
    if newX > (Map.Width - 1) * FTileSize then newX := (Map.Width - 1) * FTileSize;
    // Проверка столкновений
    if not RectCollides(newX, FPixelY) then
      FPixelX := newX;
  end;

  // Движение по Y
  if DeltaY <> 0 then
  begin
    newY := FPixelY + DeltaY;
    // Границы карты
    if newY < 0 then newY := 0;
    if newY > (Map.Height - 1) * FTileSize then newY := (Map.Height - 1) * FTileSize;
    // Проверка столкновений
    if not RectCollides(FPixelX, newY) then
      FPixelY := newY;
  end;

  UpdateTilePosition;
end;

procedure TPlayer.UpdateTilePosition;
begin
  FLastTileX := Floor(FPixelX / FTileSize);
  FLastTileY := Floor(FPixelY / FTileSize);
end;

procedure TPlayer.UpdateAnimation(Moved: Boolean);
begin
  if Moved then
  begin
    Inc(FAnimTimer);
    if FAnimTimer >= 6 then
    begin
      FAnimTimer := 0;
      case FAnimStep of
        0: FFrame := 1;
        1: FFrame := 0;
        2: FFrame := 2;
        3: FFrame := 0;
      end;
      Inc(FAnimStep);
      if FAnimStep > 3 then FAnimStep := 0;
    end;
  end
  else
  begin
    FFrame := 0;
    FAnimStep := 0;
    FAnimTimer := 0;
  end;
end;

end.
