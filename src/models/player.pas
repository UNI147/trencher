unit Player;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
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
    procedure Move(DeltaX, DeltaY: Double; MapWidth, MapHeight: Integer);
    procedure UpdateAnimation(Moved: Boolean);
    property PixelX: Double read FPixelX;
    property PixelY: Double read FPixelY;
    property TileX: Integer read FLastTileX;
    property TileY: Integer read FLastTileY;
    property Frame: Integer read FFrame;
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

procedure TPlayer.Move(DeltaX, DeltaY: Double; MapWidth, MapHeight: Integer);
var
  NewX, NewY: Double;
begin
  NewX := FPixelX + DeltaX;
  NewY := FPixelY + DeltaY;

  // Ограничение границами
  if NewX < 0 then NewX := 0;
  if NewY < 0 then NewY := 0;
  if NewX > (MapWidth - 1) * FTileSize then NewX := (MapWidth - 1) * FTileSize;
  if NewY > (MapHeight - 1) * FTileSize then NewY := (MapHeight - 1) * FTileSize;

  FPixelX := NewX;
  FPixelY := NewY;
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
