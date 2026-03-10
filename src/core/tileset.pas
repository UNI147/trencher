unit TileSet;

{$mode objfpc}{$H+}

interface

uses
  Classes, Graphics, SysUtils, PathResolver;

type
  TTile = record
    Frames: array of TBitmap;
    IsSolid: Boolean;
  end;

  TTileSet = class
  private
    FTiles: array of TTile;
    FTileSize: Integer;
    FPathResolver: IPathResolver;
    function GetCount: Integer;
    function SplitString(const S: string; Delimiter: Char): TStringArray;
  public
    constructor Create(ATileSize: Integer; APathResolver: IPathResolver);
    destructor Destroy; override;
    procedure LoadFromStrings(const TileDescriptions: TStrings);
    function GetTile(Index: Integer): TTile;
    function GetTileImage(Index: Integer; Frame: Integer): TBitmap;
    function IsTileSolid(Index: Integer): Boolean;
    property TileSize: Integer read FTileSize;
    property Count: Integer read GetCount;
  end;

implementation

constructor TTileSet.Create(ATileSize: Integer; APathResolver: IPathResolver);
begin
  FTileSize := ATileSize;
  FPathResolver := APathResolver;
  FTiles := nil;
end;

destructor TTileSet.Destroy;
var
  i, j: Integer;
begin
  for i := 0 to High(FTiles) do
    for j := 0 to High(FTiles[i].Frames) do
      FTiles[i].Frames[j].Free;
  inherited;
end;

function TTileSet.GetCount: Integer;
begin
  Result := Length(FTiles);
end;

function TTileSet.SplitString(const S: string; Delimiter: Char): TStringArray;
var
  i, Start: Integer;
begin
  Result := nil;
  Start := 1;
  for i := 1 to Length(S) do
  begin
    if S[i] = Delimiter then
    begin
      if i > Start then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Trim(Copy(S, Start, i - Start));
      end;
      Start := i + 1;
    end;
  end;
  if Start <= Length(S) then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Trim(Copy(S, Start, MaxInt));
  end;
end;

procedure TTileSet.LoadFromStrings(const TileDescriptions: TStrings);
var
  i, j: Integer;
  Items: TStringArray;
  FileName: string;
  LastItem: string;
  IsSolid: Boolean;
  Pict: TPicture;
begin
  SetLength(FTiles, TileDescriptions.Count);

  for i := 0 to TileDescriptions.Count - 1 do
  begin
    // Разбиваем строку по запятым
    Items := SplitString(TileDescriptions[i], ',');

    // Проверяем, есть ли флаг solid
    IsSolid := False;
    if Length(Items) > 0 then
    begin
      LastItem := LowerCase(Trim(Items[High(Items)]));
      if LastItem = 'solid' then
      begin
        IsSolid := True;
        // Убираем последний элемент (solid) из списка файлов
        SetLength(Items, Length(Items) - 1);
      end;
    end;

    FTiles[i].IsSolid := IsSolid;

    if Length(Items) = 0 then
      raise Exception.CreateFmt('Нет имени файла для тайла в строке: %s', [TileDescriptions[i]]);

    SetLength(FTiles[i].Frames, Length(Items));

    // Загружаем каждый кадр
    for j := 0 to High(Items) do
    begin
      FileName := Trim(Items[j]);
      if FileName = '' then
        Continue;

      FTiles[i].Frames[j] := TBitmap.Create;
      FTiles[i].Frames[j].PixelFormat := pf32bit;

      Pict := TPicture.Create;
      try
        Pict.LoadFromFile(FPathResolver.GetFullPath('tiles', FileName));
        FTiles[i].Frames[j].Assign(Pict.Bitmap);
        if (FTiles[i].Frames[j].Width <> FTileSize) or
           (FTiles[i].Frames[j].Height <> FTileSize) then
          FTiles[i].Frames[j].SetSize(FTileSize, FTileSize);
      finally
        Pict.Free;
      end;
    end;
  end;
end;

function TTileSet.GetTile(Index: Integer): TTile;
begin
  if (Index >= 0) and (Index < Length(FTiles)) then
    Result := FTiles[Index]
  else
    raise Exception.CreateFmt('Tile index out of range: %d', [Index]);
end;

function TTileSet.GetTileImage(Index: Integer; Frame: Integer): TBitmap;
var
  Tile: TTile;
  FrameCount: Integer;
begin
  Result := nil;
  if (Index >= 0) and (Index < Length(FTiles)) then
  begin
    Tile := FTiles[Index];
    FrameCount := Length(Tile.Frames);
    if FrameCount > 0 then
    begin
      Frame := Frame mod FrameCount; // Защита от выхода за границы
      Result := Tile.Frames[Frame];
    end;
  end;
end;

function TTileSet.IsTileSolid(Index: Integer): Boolean;
begin
  if (Index >= 0) and (Index < Length(FTiles)) then
    Result := FTiles[Index].IsSolid
  else
    Result := False;
end;

end.
