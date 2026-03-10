unit TileSet;

interface

uses
  Classes, Graphics;

type
  TTile = record
    Frames: array of TBitmap;
    IsSolid: Boolean;
  end;

  TTileSet = class
  private
    FTiles: array of TTile;
    FTileSize: Integer;
    FResourcePathResolver: TObject; // или интерфейс для получения путей
  public
    constructor Create(ATileSize: Integer; APathResolver: TObject);
    destructor Destroy; override;
    procedure LoadFromStrings(const TileDescriptions: TStrings);
    function GetTile(Index: Integer): TTile;
    function GetTileImage(Index: Integer; Frame: Integer): TBitmap;
    function IsTileSolid(Index: Integer): Boolean;
    property TileSize: Integer read FTileSize;
  end;
end.
