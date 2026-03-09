unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, ExtCtrls;

type
  TResourceManager = class
  private
    FTileImages: array of TBitmap;
    FPlayerSprites: array of TBitmap;
    FTileSize: Integer;
    FResourceRoot: string;
    function GetFullPath(const ResourceType, FileName: string): string;
  public
    constructor Create(ATileSize: Integer; const ARoot: string);
    destructor Destroy; override;
    procedure LoadTiles(const TileNames: TStrings);
    procedure LoadPlayerSprites;
    function GetTileImage(Index: Integer): TBitmap;
    function GetPlayerSprite(Index: Integer): TBitmap;
    property TileSize: Integer read FTileSize;
  end;

implementation

constructor TResourceManager.Create(ATileSize: Integer; const ARoot: string);
begin
  FTileSize := ATileSize;
  FResourceRoot := ARoot;
  FTileImages := nil;
  SetLength(FPlayerSprites, 3);
end;

destructor TResourceManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FTileImages) do
    FTileImages[i].Free;
  for i := 0 to High(FPlayerSprites) do
    FPlayerSprites[i].Free;
  inherited;
end;

function TResourceManager.GetFullPath(const ResourceType, FileName: string): string;
begin
  Result := ExtractFilePath(ParamStr(0)) + FResourceRoot + ResourceType + '\' + FileName;
end;

procedure TResourceManager.LoadTiles(const TileNames: TStrings);
var
  i: Integer;
  Pict: TPicture;  // Восстанавливаем Pict для загрузки тайлов
begin
  SetLength(FTileImages, TileNames.Count);
  for i := 0 to TileNames.Count - 1 do
  begin
    FTileImages[i] := TBitmap.Create;
    Pict := TPicture.Create;
    try
      Pict.LoadFromFile(GetFullPath('tiles', TileNames[i]));
      FTileImages[i].Assign(Pict.Bitmap);
      if (FTileImages[i].Width <> FTileSize) or (FTileImages[i].Height <> FTileSize) then
        FTileImages[i].SetSize(FTileSize, FTileSize);
    finally
      Pict.Free;
    end;
  end;
end;

procedure TResourceManager.LoadPlayerSprites;
var
  i: Integer;
  Png: TPortableNetworkGraphic;  // Для PNG используем TPortableNetworkGraphic
  Path: string;
begin
  for i := 0 to 2 do
  begin
    FPlayerSprites[i] := TBitmap.Create;
    FPlayerSprites[i].PixelFormat := pf32bit;

    Png := TPortableNetworkGraphic.Create;
    try
      Path := GetFullPath('sprites', Format('player%d.png', [i]));
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

function TResourceManager.GetTileImage(Index: Integer): TBitmap;
begin
  if (Index >= 0) and (Index < Length(FTileImages)) then
    Result := FTileImages[Index]
  else
    Result := nil;
end;

function TResourceManager.GetPlayerSprite(Index: Integer): TBitmap;
begin
  if (Index >= 0) and (Index < Length(FPlayerSprites)) then
    Result := FPlayerSprites[Index]
  else
    Result := nil;
end;

end.
