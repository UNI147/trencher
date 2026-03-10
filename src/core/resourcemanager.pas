unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, Graphics, SysUtils,
  PathResolver, TileSet, SpriteSet, SpriteDescriptionParser, Logger;  // Добавлен Logger

type
  TResourceManager = class
  private
    FPathResolver: IPathResolver;
    FTileSet: TTileSet;
    FSpriteSet: TSpriteSet;
    FPlayerSprites: array of TBitmap;
    FTileSize: Integer;
    FAnimFrame: Integer;
    FAnimTime: Double;
    FAnimInterval: Double;
  public
    constructor Create(ATileSize: Integer; const ARoot: string);
    destructor Destroy; override;

    procedure LoadTiles(const TileNames: TStrings);
    procedure LoadPlayerSprites;
    procedure LoadSpritesFromDescriptions(const Descriptions: TStrings);

    procedure UpdateAnimation(DeltaTime: Double);

    function GetTileImage(Index: Integer): TBitmap;
    function IsTileSolid(Index: Integer): Boolean;
    property TileSet: TTileSet read FTileSet;
    property TileSize: Integer read FTileSize;

    function GetSpriteImage(Index: Integer): TBitmap;
    function GetSpriteHeight(Index: Integer): Integer;
    function IsSpriteSolid(Index: Integer): Boolean;
    function IsSpriteBehind(Index: Integer): Boolean;
    property SpriteSet: TSpriteSet read FSpriteSet;

    function GetPlayerSprite(Index: Integer): TBitmap;

    function AddSprite(const FileNames: array of string; IsSolid, IsBehind: Boolean): Integer;
  end;

implementation

constructor TResourceManager.Create(ATileSize: Integer; const ARoot: string);
begin
  LogDebug('TResourceManager.Create: TileSize=' + IntToStr(ATileSize) + ', Root=' + ARoot);
  FTileSize := ATileSize;
  FPathResolver := TResourcePathResolver.Create(ARoot);
  FTileSet := TTileSet.Create(ATileSize, FPathResolver);
  FSpriteSet := TSpriteSet.Create(ATileSize, FPathResolver);

  SetLength(FPlayerSprites, 3);
  FAnimFrame := 0;
  FAnimTime := 0;
  FAnimInterval := 0.2;
end;

destructor TResourceManager.Destroy;
var
  i: Integer;
begin
  LogDebug('TResourceManager.Destroy');
  for i := 0 to High(FPlayerSprites) do
    FPlayerSprites[i].Free;

  FTileSet.Free;
  FSpriteSet.Free;
  inherited;
end;

procedure TResourceManager.LoadTiles(const TileNames: TStrings);
begin
  LogDebug('Loading ' + IntToStr(TileNames.Count) + ' tiles');
  FTileSet.LoadFromStrings(TileNames);
end;

procedure TResourceManager.LoadPlayerSprites;
var
  i: Integer;
  Png: TPortableNetworkGraphic;
  Path: string;
begin
  LogDebug('Loading player sprites');
  for i := 0 to 2 do
  begin
    FPlayerSprites[i] := TBitmap.Create;
    FPlayerSprites[i].PixelFormat := pf32bit;
    Png := TPortableNetworkGraphic.Create;
    try
      Path := FPathResolver.GetFullPath('sprites', Format('player%d.png', [i]));
      LogDebug('  Loading player sprite ' + IntToStr(i) + ' from: ' + Path);

      if FileExists(Path) then
      begin
        Png.LoadFromFile(Path);
        FPlayerSprites[i].SetSize(FTileSize, FTileSize);
        FPlayerSprites[i].Canvas.Draw(0, 0, Png);
        LogDebug('  Player sprite ' + IntToStr(i) + ' loaded successfully');
      end
      else
      begin
        LogError('  Player sprite file not found: ' + Path);
        FPlayerSprites[i].SetSize(FTileSize, FTileSize);
        FPlayerSprites[i].Canvas.Brush.Color := clRed;
        FPlayerSprites[i].Canvas.FillRect(0, 0, FTileSize, FTileSize);
      end;
    finally
      Png.Free;
    end;
  end;
  LogDebug('Player sprites loading completed');
end;

procedure TResourceManager.LoadSpritesFromDescriptions(const Descriptions: TStrings);
var
  i: Integer;
  FileNames: TStringArray;
  IsSolid, IsBehind: Boolean;
begin
  LogDebug('Loading sprites from ' + IntToStr(Descriptions.Count) + ' descriptions');
  for i := 0 to Descriptions.Count - 1 do
  begin
    TSpriteDescriptionParser.Parse(Descriptions[i], FileNames, IsSolid, IsBehind);
    FSpriteSet.AddSprite(FileNames, IsSolid, IsBehind);
    LogDebug('  Added sprite with ' + IntToStr(Length(FileNames)) + ' frames');
  end;
end;

procedure TResourceManager.UpdateAnimation(DeltaTime: Double);
begin
  FAnimTime := FAnimTime + DeltaTime;
  while FAnimTime >= FAnimInterval do
  begin
    FAnimTime := FAnimTime - FAnimInterval;
    Inc(FAnimFrame);
  end;
end;

function TResourceManager.GetTileImage(Index: Integer): TBitmap;
begin
  Result := FTileSet.GetTileImage(Index, FAnimFrame);
end;

function TResourceManager.IsTileSolid(Index: Integer): Boolean;
begin
  Result := FTileSet.IsTileSolid(Index);
end;

function TResourceManager.GetSpriteImage(Index: Integer): TBitmap;
begin
  Result := FSpriteSet.GetSpriteImage(Index, FAnimFrame);
end;

function TResourceManager.GetSpriteHeight(Index: Integer): Integer;
begin
  Result := FSpriteSet.GetSpriteHeight(Index);
end;

function TResourceManager.IsSpriteSolid(Index: Integer): Boolean;
var
  Sprite: TSprite;
begin
  if (Index >= 0) and (Index < FSpriteSet.Count) then
  begin
    Sprite := FSpriteSet.GetSprite(Index);
    Result := Sprite.IsSolid;
  end
  else
    Result := False;
end;

function TResourceManager.IsSpriteBehind(Index: Integer): Boolean;
var
  Sprite: TSprite;
begin
  if (Index >= 0) and (Index < FSpriteSet.Count) then
  begin
    Sprite := FSpriteSet.GetSprite(Index);
    Result := Sprite.IsBehind;
  end
  else
    Result := True;
end;

function TResourceManager.GetPlayerSprite(Index: Integer): TBitmap;
begin
  if (Index >= 0) and (Index < Length(FPlayerSprites)) then
    Result := FPlayerSprites[Index]
  else
    Result := nil;
end;

function TResourceManager.AddSprite(const FileNames: array of string; IsSolid, IsBehind: Boolean): Integer;
begin
  Result := FSpriteSet.AddSprite(FileNames, IsSolid, IsBehind);
  LogDebug('Added sprite at index ' + IntToStr(Result));
end;

end.
