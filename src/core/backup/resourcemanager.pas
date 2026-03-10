unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, ExtCtrls;

type
  TStringArray = array of string;

  TTile = record
    Frames: array of TBitmap;
    IsSolid: Boolean;
    SpriteHeight: Integer;
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
    FSpriteResources: array of TTile;
    function GetFullPath(const ResourceType, FileName: string): string;
    function SplitString(const S: string; Delimiter: Char): TStringArray;
    function GetSpriteHeight(Index: Integer): Integer;
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
    function AddSpriteFrames(const FileNames: TStringArray): Integer;
    function GetSpriteImage(Index: Integer): TBitmap;
    procedure ParseSpriteDescription(const Desc: string;
      out FileNames: TStringArray; out IsSolid, IsBehind: Boolean);
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
  for i := 0 to High(FSpriteResources) do
    for j := 0 to High(FSpriteResources[i].Frames) do
      FSpriteResources[i].Frames[j].Free;
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

procedure TResourceManager.LoadTiles(const TileNames: TStrings);
var
  i, j: Integer;
  Items: TStringArray;
  FileName: string;
  LastItem: string;
  IsSolid: Boolean;
  Pict: TPicture;
begin
  SetLength(FTiles, TileNames.Count);

  for i := 0 to TileNames.Count - 1 do
  begin
    // Разбиваем строку по запятым
    Items := SplitString(TileNames[i], ',');

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
      raise Exception.CreateFmt('Нет имени файла для тайла в строке: %s', [TileNames[i]]);

    SetLength(FTiles[i].Frames, Length(Items));

    // Загружаем каждый кадр
    for j := 0 to High(Items) do
    begin
      FileName := Trim(Items[j]);
      if FileName = '' then
        Continue;

      FTiles[i].Frames[j] := TBitmap.Create;
      Pict := TPicture.Create;
      try
        Pict.LoadFromFile(GetFullPath('tiles', FileName));
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

function TResourceManager.AddSpriteFrames(const FileNames: TStringArray): Integer;
var
  idx, j: Integer;
  Pict: TPicture;
begin
  idx := Length(FSpriteResources);
  SetLength(FSpriteResources, idx + 1);
  SetLength(FSpriteResources[idx].Frames, Length(FileNames));
  FSpriteResources[idx].SpriteHeight := FTileSize; // По умолчанию

  for j := 0 to High(FileNames) do
  begin
    FSpriteResources[idx].Frames[j] := TBitmap.Create;
    Pict := TPicture.Create;
    try
      Pict.LoadFromFile(GetFullPath('sprites', FileNames[j]));
      FSpriteResources[idx].Frames[j].Assign(Pict.Bitmap);
      if (FSpriteResources[idx].Frames[j].Width <> FTileSize) or
         (FSpriteResources[idx].Frames[j].Height <> FTileSize) then
      begin
        // Сохраняем оригинальную высоту для перспективы
        FSpriteResources[idx].SpriteHeight := FSpriteResources[idx].Frames[j].Height;
        FSpriteResources[idx].Frames[j].SetSize(FTileSize, FTileSize);
      end;
    finally
      Pict.Free;
    end;
  end;
  FSpriteResources[idx].IsSolid := False;
  Result := idx;
end;

function TResourceManager.GetSpriteHeight(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < Length(FSpriteResources)) then
    Result := FSpriteResources[Index].SpriteHeight
  else
    Result := FTileSize;
end;

function TResourceManager.GetSpriteImage(Index: Integer): TBitmap;
var
  cnt: Integer;
  frame: Integer;
begin
  if (Index >= 0) and (Index < Length(FSpriteResources)) then
  begin
    cnt := Length(FSpriteResources[Index].Frames);
    if cnt > 0 then
    begin
      frame := FAnimFrame mod cnt;
      Result := FSpriteResources[Index].Frames[frame];
    end
    else
      Result := nil;
  end
  else
    Result := nil;
end;

procedure TResourceManager.ParseSpriteDescription(const Desc: string;
  out FileNames: TStringArray; out IsSolid, IsBehind: Boolean);
var
  Items: TStringArray;
  i: Integer;
  TempFiles: TStringArray;
begin
  Items := SplitString(Desc, ',');
  IsBehind := True;    // по умолчанию за игроком
  IsSolid := False;
  TempFiles := nil;

  for i := 0 to High(Items) do
  begin
    Items[i] := LowerCase(Trim(Items[i]));  // приводим к нижнему регистру для сравнения

    if Items[i] = 'behind' then
      IsBehind := True
    else if Items[i] = 'front' then
      IsBehind := False
    else if Items[i] = 'solid' then
      IsSolid := True
    else if Items[i] <> '' then
    begin
      // это имя файла – добавляем в результирующий массив
      SetLength(TempFiles, Length(TempFiles) + 1);
      TempFiles[High(TempFiles)] := Items[i];
    end;
  end;

  // Если не указано явно 'front', оставляем 'behind' (по умолчанию)
  // Проверяем, было ли указание 'front' в списке
  for i := 0 to High(Items) do
  begin
    if Items[i] = 'front' then
    begin
      IsBehind := False;
      Break;
    end
    else if Items[i] = 'behind' then
    begin
      IsBehind := True;
      Break;
    end;
  end;

  FileNames := TempFiles;

  if Length(FileNames) = 0 then
    raise Exception.Create('Не указаны файлы спрайта в строке: ' + Desc);
end;

end.
