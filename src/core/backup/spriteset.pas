unit SpriteSet;

{$mode objfpc}{$H+}

interface

uses
  Classes, Graphics, SysUtils, PathResolver;

type
  TSprite = record
    Frames: array of TBitmap;
    OriginalHeight: Integer; // для сохранения пропорций
    IsSolid: Boolean;
    IsBehind: Boolean;       // порядок отрисовки
  end;

  TSpriteSet = class
  private
    FSprites: array of TSprite;
    FTileSize: Integer;      // базовый размер тайла (для масштабирования)
    FPathResolver: IPathResolver;
    function GetCount: Integer;
  public
    constructor Create(ATileSize: Integer; APathResolver: IPathResolver);
    destructor Destroy; override;
    function AddSprite(const FileNames: array of string; IsSolid, IsBehind: Boolean): Integer;
    function GetSprite(Index: Integer): TSprite;
    function GetSpriteImage(Index: Integer; Frame: Integer): TBitmap;
    function GetSpriteHeight(Index: Integer): Integer;
    procedure UpdateAnimation(var AFrame: Integer; DeltaTime: Double; AnimInterval: Double);
    property Count: Integer read GetCount;
  end;

implementation

constructor TSpriteSet.Create(ATileSize: Integer; APathResolver: IPathResolver);
begin
  FTileSize := ATileSize;
  FPathResolver := APathResolver;
  FSprites := nil;
end;

destructor TSpriteSet.Destroy;
var
  i, j: Integer;
begin
  for i := 0 to High(FSprites) do
    for j := 0 to High(FSprites[i].Frames) do
      FSprites[i].Frames[j].Free;
  inherited;
end;

function TSpriteSet.GetCount: Integer;
begin
  Result := Length(FSprites);
end;

function TSpriteSet.AddSprite(const FileNames: array of string; IsSolid, IsBehind: Boolean): Integer;
var
  idx, j: Integer;
  Pict: TPicture;
begin
  idx := Length(FSprites);
  SetLength(FSprites, idx + 1);
  SetLength(FSprites[idx].Frames, Length(FileNames));

  FSprites[idx].IsSolid := IsSolid;
  FSprites[idx].IsBehind := IsBehind;
  FSprites[idx].OriginalHeight := FTileSize; // По умолчанию

  for j := 0 to High(FileNames) do
  begin
    FSprites[idx].Frames[j] := TBitmap.Create;
    FSprites[idx].Frames[j].PixelFormat := pf32bit;

    Pict := TPicture.Create;
    try
      Pict.LoadFromFile(FPathResolver.GetFullPath('sprites', FileNames[j]));
      FSprites[idx].Frames[j].Assign(Pict.Bitmap);

      // Сохраняем оригинальную высоту первого кадра
      if (j = 0) and (FSprites[idx].Frames[j].Height <> FTileSize) then
        FSprites[idx].OriginalHeight := FSprites[idx].Frames[j].Height;

      // Масштабируем до размера тайла, если нужно
      if (FSprites[idx].Frames[j].Width <> FTileSize) or
         (FSprites[idx].Frames[j].Height <> FTileSize) then
      begin
        FSprites[idx].Frames[j].SetSize(FTileSize, FTileSize);
      end;
    finally
      Pict.Free;
    end;
  end;

  Result := idx;
end;

function TSpriteSet.GetSprite(Index: Integer): TSprite;
begin
  if (Index >= 0) and (Index < Length(FSprites)) then
    Result := FSprites[Index]
  else
    raise Exception.CreateFmt('Sprite index out of range: %d', [Index]);
end;

function TSpriteSet.GetSpriteImage(Index: Integer; Frame: Integer): TBitmap;
var
  Sprite: TSprite;
  FrameCount: Integer;
begin
  Result := nil;
  if (Index >= 0) and (Index < Length(FSprites)) then
  begin
    Sprite := FSprites[Index];
    FrameCount := Length(Sprite.Frames);
    if FrameCount > 0 then
    begin
      Frame := Frame mod FrameCount; // Защита от выхода за границы
      Result := Sprite.Frames[Frame];
    end;
  end;
end;

function TSpriteSet.GetSpriteHeight(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < Length(FSprites)) then
    Result := FSprites[Index].OriginalHeight
  else
    Result := FTileSize;
end;

procedure TSpriteSet.UpdateAnimation(var AFrame: Integer; DeltaTime: Double; AnimInterval: Double);
var
  AnimTime: Double;
begin
  // Эта функция должна вызываться с внешней переменной времени
  // или можно хранить состояние внутри, но тогда нужен массив состояний
  // Пока оставим как есть - внешнее управление анимацией
end;

end.
