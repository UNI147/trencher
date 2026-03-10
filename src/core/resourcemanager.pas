unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, Graphics, SysUtils,
  PathResolver, TileSet, SpriteSet, SpriteDescriptionParser;

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

    // Загрузка ресурсов
    procedure LoadTiles(const TileNames: TStrings);
    procedure LoadPlayerSprites;
    procedure LoadSpritesFromDescriptions(const Descriptions: TStrings);

    // Анимация
    procedure UpdateAnimation(DeltaTime: Double);

    // Доступ к тайлам
    function GetTileImage(Index: Integer): TBitmap;
    function IsTileSolid(Index: Integer): Boolean;
    property TileSet: TTileSet read FTileSet;
    property TileSize: Integer read FTileSize;

    // Доступ к спрайтам
    function GetSpriteImage(Index: Integer): TBitmap;
    function GetSpriteHeight(Index: Integer): Integer;
    function IsSpriteSolid(Index: Integer): Boolean;
    function IsSpriteBehind(Index: Integer): Boolean;
    property SpriteSet: TSpriteSet read FSpriteSet;

    // Доступ к игроку
    function GetPlayerSprite(Index: Integer): TBitmap;

    // Добавление спрайтов "на лету"
    function AddSprite(const FileNames: array of string; IsSolid, IsBehind: Boolean): Integer;
  end;

implementation

constructor TResourceManager.Create(ATileSize: Integer; const ARoot: string);
begin
  FTileSize := ATileSize;
  FPathResolver := TResourcePathResolver.Create(ARoot);
  FTileSet := TTileSet.Create(ATileSize, FPathResolver);
  FSpriteSet := TSpriteSet.Create(ATileSize, FPathResolver);

  SetLength(FPlayerSprites, 3);
  FAnimFrame := 0;
  FAnimTime := 0;
  FAnimInterval := 0.2; // 200 ms между кадрами
end;

destructor TResourceManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FPlayerSprites) do
    FPlayerSprites[i].Free;

  FTileSet.Free;
  FSpriteSet.Free;
  inherited;
end;

procedure TResourceManager.LoadTiles(const TileNames: TStrings);
begin
  FTileSet.LoadFromStrings(TileNames);
end;

procedure TResourceManager.LoadPlayerSprites;
var
  i: Integer;
  Png: TPortableNetworkGraphic;
  Path: string;
begin
  for i := 0 to 2 do
  begin
    FPlayerSprites[i] := TBitmap.Create;
    FPlayerSprites[i].PixelFormat := pf32bit;
    Png := TPortableNetworkGraphic.Create;
    try
      Path := FPathResolver.GetFullPath('sprites', Format('player%d.png', [i]));
      if FileExists(Path) then
      begin
        Png.LoadFromFile(Path);
        FPlayerSprites[i].SetSize(FTileSize, FTileSize);
        FPlayerSprites[i].Canvas.Draw(0, 0, Png);
      end
      else
      begin
        FPlayerSprites[i].SetSize(FTileSize, FTileSize);
        FPlayerSprites[i].Canvas.Brush.Color := clRed;
        FPlayerSprites[i].Canvas.FillRect(0, 0, FTileSize, FTileSize);
      end;
    finally
      Png.Free;
    end;
  end;
end;

procedure TResourceManager.LoadSpritesFromDescriptions(const Descriptions: TStrings);
var
  i: Integer;
  FileNames: TStringArray;
  IsSolid, IsBehind: Boolean;
begin
  for i := 0 to Descriptions.Count - 1 do
  begin
    TSpriteDescriptionParser.Parse(Descriptions[i], FileNames, IsSolid, IsBehind);
    FSpriteSet.AddSprite(FileNames, IsSolid, IsBehind);
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
    Result := True; // по умолчанию за игроком
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
end;

end.
