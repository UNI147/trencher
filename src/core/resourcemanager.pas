unit ResourceManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, ExtCtrls;

type
  TStringArray = array of string;  // Добавляем для совместимости

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
    function ExtractFlags(const Items: TStringArray; out CleanItems: TStringArray): Boolean;
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

function TResourceManager.ExtractFlags(const Items: TStringArray; out CleanItems: TStringArray): Boolean;
var
  i, j: Integer;
  LastItem: string;
begin
  Result := False;  // По умолчанию solid = false
  CleanItems := nil;

  if Length(Items) = 0 then
    Exit;

  // Проверяем последний элемент на наличие флага solid
  LastItem := LowerCase(Items[High(Items)]);
  if (LastItem = 'solid') then
  begin
    Result := True;  // solid = true
    // Копируем все элементы кроме последнего
    SetLength(CleanItems, Length(Items) - 1);
    for i := 0 to Length(Items) - 2 do
      CleanItems[i] := Items[i];
  end
  else
  begin
    // Просто копируем все элементы
    SetLength(CleanItems, Length(Items));
    for i := 0 to High(Items) do
      CleanItems[i] := Items[i];
  end;

  // Дополнительная проверка: если после удаления solid остались пустые строки - убираем их
  i := 0;
  while i < Length(CleanItems) do
  begin
    if CleanItems[i] = '' then
    begin
      for j := i to Length(CleanItems) - 2 do
        CleanItems[j] := CleanItems[j+1];
      SetLength(CleanItems, Length(CleanItems) - 1);
    end
    else
      Inc(i);
  end;
end;

procedure TResourceManager.LoadTiles(const TileNames: TStrings);
var
  i, j: Integer;
  RawItems: TStringArray;
  CleanItems: TStringArray;
  IsSolid: Boolean;
  Pict: TPicture;
begin
  SetLength(FTiles, TileNames.Count);

  for i := 0 to TileNames.Count - 1 do
  begin
    // Разбиваем строку по запятым
    RawItems := SplitString(TileNames[i], ',');

    // Извлекаем флаги (solid) и получаем чистый список файлов
    IsSolid := ExtractFlags(RawItems, CleanItems);

    if Length(CleanItems) = 0 then
      raise Exception.CreateFmt('Нет имени файла для тайла в строке: %s', [TileNames[i]]);

    FTiles[i].IsSolid := IsSolid;
    SetLength(FTiles[i].Frames, Length(CleanItems));

    // Загружаем каждый кадр
    for j := 0 to High(CleanItems) do
    begin
      FTiles[i].Frames[j] := TBitmap.Create;
      Pict := TPicture.Create;
      try
        Pict.LoadFromFile(GetFullPath('tiles', CleanItems[j]));
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
