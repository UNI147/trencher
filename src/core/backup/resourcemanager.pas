unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, ExtCtrls;

type
  TTile = record
    Frames: array of TBitmap;
    IsSolid: Boolean;
  end;

  TResourceManager = class
  private
    FTiles: array of TTile;
    FPlayerSprites: array of TBitmap;
    FTileSize: Integer;
    FResourceRoot: string;
    FAnimFrame: Integer;
    FAnimTime: Double;
    FAnimInterval: Double;
    function GetFullPath(const ResourceType, FileName: string): string;
    function SplitString(const S: string; Delimiter: Char): TStringArray;
  public
    constructor Create(ATileSize: Integer; const ARoot: string);
    destructor Destroy; override;
    procedure LoadTiles(const TileNames: TStrings);
    procedure LoadPlayerSprites;
    procedure UpdateAnimation(DeltaTime: Double);
    function GetTileImage(Index: Integer): TBitmap;
    function GetPlayerSprite(Index: Integer): TBitmap;
    function IsTileSolid(Index: Integer): Boolean;
    property TileSize: Integer read FTileSize;
  end;

implementation

constructor TResourceManager.Create(ATileSize: Integer; const ARoot: string);
begin
  FTileSize := ATileSize;
  FResourceRoot := ARoot;
  FTiles := nil;
  SetLength(FPlayerSprites, 3);
  FAnimFrame := 0;
  FAnimTime := 0;
  FAnimInterval := 0.2; // 200 ms между кадрами
end;

destructor TResourceManager.Destroy;
var
  i, j: Integer;
begin
  for i := 0 to High(FTiles) do
    for j := 0 to High(FTiles[i].Frames) do
      FTiles[i].Frames[j].Free;
  for i := 0 to High(FPlayerSprites) do
    FPlayerSprites[i].Free;
  inherited;
end;

function TResourceManager.GetFullPath(const ResourceType, FileName: string): string;
begin
  Result := ExtractFilePath(ParamStr(0)) + FResourceRoot + ResourceType + '\' + FileName;
end;

function TResourceManager.SplitString(const S: string; Delimiter: Char): TStringArray;
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

procedure TResourceManager.LoadTiles(const TileNames: TStrings);
var
  i, j, k: Integer;
  items: TStringArray;
  item: string;
  isSolid: Boolean;
  Pict: TPicture;
begin
  SetLength(FTiles, TileNames.Count);
  for i := 0 to TileNames.Count - 1 do
  begin
    items := SplitString(Trim(TileNames[i]), ',');
    isSolid := False;

    // Удаляем пустые элементы и обрезаем пробелы
    j := 0;
    while j < Length(items) do
    begin
      items[j] := Trim(items[j]);
      if items[j] = '' then
      begin
        for k := j to Length(items)-2 do
          items[k] := items[k+1];
        SetLength(items, Length(items)-1);
      end
      else
        Inc(j);
    end;

    // Проверка на флаг solid
    if Length(items) > 0 then
    begin
      if CompareText(items[High(items)], 'solid') = 0 then
      begin
        isSolid := True;
        SetLength(items, Length(items)-1);
      end;
    end;

    if Length(items) = 0 then
      raise Exception.Create('Нет имени файла для тайла');

    FTiles[i].IsSolid := isSolid;
    SetLength(FTiles[i].Frames, Length(items));
    for j := 0 to High(items) do
    begin
      FTiles[i].Frames[j] := TBitmap.Create;
      Pict := TPicture.Create;
      try
        Pict.LoadFromFile(GetFullPath('tiles', items[j]));
        FTiles[i].Frames[j].Assign(Pict.Bitmap);
        if (FTiles[i].Frames[j].Width <> FTileSize) or (FTiles[i].Frames[j].Height <> FTileSize) then
          FTiles[i].Frames[j].SetSize(FTileSize, FTileSize);
      finally
        Pict.Free;
      end;
    end;
  end;
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
var
  cnt: Integer;
  frame: Integer;
begin
  if (Index >= 0) and (Index < Length(FTiles)) then
  begin
    cnt := Length(FTiles[Index].Frames);
    if cnt > 0 then
    begin
      frame := FAnimFrame mod cnt;
      Result := FTiles[Index].Frames[frame];
    end
    else
      Result := nil;
  end
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

function TResourceManager.IsTileSolid(Index: Integer): Boolean;
begin
  if (Index >= 0) and (Index < Length(FTiles)) then
    Result := FTiles[Index].IsSolid
  else
    Result := False;
end;

end.
