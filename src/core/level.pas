unit Level;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Map, GameTypes, ResourceManager, Utils,
  SpriteDescriptionParser;

type
  TLevel = class
  private
    FMap: TMap;
    FTransitions: TTransitionArray;
    FSprites: TMapSpriteArray;
    FSolidSpriteMap: array of array of Boolean;
    FBehindSprites: TMapSpriteArray;
    FFrontSprites: TMapSpriteArray;
    FResourceManager: TResourceManager;
    FStartX, FStartY: Integer;
    procedure BuildSolidSpriteMap;
    procedure SortSpritesByLayer;
  public
    constructor Create(ATileSize: Integer; ResourceManager: TResourceManager);
    destructor Destroy; override;
    procedure LoadFromFile(const Filename: string);
    procedure UpdateDynamicLayers(PlayerFootY: Integer);
    function IsSpriteSolid(TileX, TileY: Integer): Boolean;
    property Map: TMap read FMap;
    property Transitions: TTransitionArray read FTransitions;
    property BehindSprites: TMapSpriteArray read FBehindSprites;
    property FrontSprites: TMapSpriteArray read FFrontSprites;
    property StartX: Integer read FStartX;
    property StartY: Integer read FStartY;
  end;

implementation

{ TLevel }

constructor TLevel.Create(ATileSize: Integer; ResourceManager: TResourceManager);
begin
  FMap := TMap.Create(ATileSize);
  FResourceManager := ResourceManager;
  FTransitions := nil;
  FSprites := nil;
  FBehindSprites := nil;
  FFrontSprites := nil;
  FSolidSpriteMap := nil;
  FStartX := 0;
  FStartY := 0;
end;

destructor TLevel.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TLevel.LoadFromFile(const Filename: string);
var
  Lines: TStringList;
  i, j, W, H, X, Y: Integer;
  TileNames: TStringList;
  Line: string;
  Tokens: TStringArray;
  FileNames: TStringArray;
  Desc: string;
  IsSolid, IsBehind: Boolean;
  SpriteResIndex: Integer;
  Trans: TTransition;
begin
  Lines := TStringList.Create;
  TileNames := TStringList.Create;
  try
    Lines.LoadFromFile(Filename);
    i := 0;

    // #tiles
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i >= Lines.Count) or (Trim(Lines[i]) <> '#tiles') then
      raise Exception.Create('Expected #tiles section');
    Inc(i);
    while (i < Lines.Count) and (Trim(Lines[i]) <> '') and (Trim(Lines[i])[1] <> '#') do
    begin
      TileNames.Add(Trim(Lines[i]));
      Inc(i);
    end;
    FResourceManager.LoadTiles(TileNames);

    // #map
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i >= Lines.Count) or (Trim(Lines[i]) <> '#map') then
      raise Exception.Create('Expected #map section');
    Inc(i);
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    Line := Trim(Lines[i]);
    Tokens := SplitString(Line, ' ');
    if Length(Tokens) <> 2 then
      raise Exception.Create('Invalid map dimensions');
    W := StrToInt(Tokens[0]);
    H := StrToInt(Tokens[1]);
    Inc(i);
    FMap.LoadFromStrings(Lines, i, W, H);
    Inc(i, H);

    // #player
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i >= Lines.Count) or (Trim(Lines[i]) <> '#player') then
      raise Exception.Create('Expected #player section');
    Inc(i);
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    Line := Trim(Lines[i]);
    Tokens := SplitString(Line, ' ');
    if Length(Tokens) <> 2 then
      raise Exception.Create('Invalid player coordinates');
    FStartX := StrToInt(Tokens[0]);
    FStartY := StrToInt(Tokens[1]);
    Inc(i);

    // #transition
    FTransitions := nil;
    while i < Lines.Count do
    begin
      while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
      if i >= Lines.Count then Break;
      if Trim(Lines[i]) <> '#transition' then Break;
      Inc(i);
      while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
      if i >= Lines.Count then Break;
      Line := Trim(Lines[i]);
      Tokens := SplitString(Line, ' ');
      if Length(Tokens) = 5 then
      begin
        Trans.SrcX := StrToInt(Tokens[0]);
        Trans.SrcY := StrToInt(Tokens[1]);
        Trans.DestMap := Tokens[2];
        Trans.DestX := StrToInt(Tokens[3]);
        Trans.DestY := StrToInt(Tokens[4]);
        SetLength(FTransitions, Length(FTransitions) + 1);
        FTransitions[High(FTransitions)] := Trans;
      end;
      Inc(i);
    end;

    // #sprites
    FSprites := nil;
    while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
    if (i < Lines.Count) and (Trim(Lines[i]) = '#sprites') then
    begin
      Inc(i);
      while i < Lines.Count do
      begin
        while (i < Lines.Count) and (Trim(Lines[i]) = '') do Inc(i);
        if i >= Lines.Count then Break;
        if Trim(Lines[i])[1] = '#' then Break;

        Line := Trim(Lines[i]);
        Tokens := SplitString(Line, ' ');
        if Length(Tokens) < 3 then
          raise Exception.Create('Invalid sprite line: ' + Line);
        X := StrToInt(Tokens[0]);
        Y := StrToInt(Tokens[1]);

        Desc := '';
        for j := 2 to High(Tokens) do
        begin
          if j > 2 then Desc := Desc + ' ';
          Desc := Desc + Tokens[j];
        end;

        // Используем новый парсер
        TSpriteDescriptionParser.Parse(Desc, FileNames, IsSolid, IsBehind);

        // Используем новый метод ResourceManager для добавления спрайта
        SpriteResIndex := FResourceManager.AddSprite(FileNames, IsSolid, IsBehind);

        SetLength(FSprites, Length(FSprites) + 1);
        FSprites[High(FSprites)].X := X;
        FSprites[High(FSprites)].Y := Y;
        FSprites[High(FSprites)].SpriteIndex := SpriteResIndex;
        FSprites[High(FSprites)].IsSolid := IsSolid;
        if IsBehind then
          FSprites[High(FSprites)].Layer := slBehind
        else
          FSprites[High(FSprites)].Layer := slFront;
        FSprites[High(FSprites)].BaseY := FMap.TileSize;
        Inc(i);
      end;
    end;

    BuildSolidSpriteMap;
    SortSpritesByLayer;

  finally
    TileNames.Free;
    Lines.Free;
  end;
end;

procedure TLevel.BuildSolidSpriteMap;
var
  tileX, tileY, i: Integer;
begin
  SetLength(FSolidSpriteMap, FMap.Height, FMap.Width);
  for tileY := 0 to FMap.Height - 1 do
    for tileX := 0 to FMap.Width - 1 do
      FSolidSpriteMap[tileY, tileX] := False;

  for i := 0 to High(FSprites) do
    if FSprites[i].IsSolid then
    begin
      tileX := FSprites[i].X;
      tileY := FSprites[i].Y;
      if (tileX >= 0) and (tileX < FMap.Width) and (tileY >= 0) and (tileY < FMap.Height) then
        FSolidSpriteMap[tileY, tileX] := True;
    end;
end;

function TLevel.IsSpriteSolid(TileX, TileY: Integer): Boolean;
begin
  if (TileY >= 0) and (TileY < FMap.Height) and (TileX >= 0) and (TileX < FMap.Width) then
    Result := FSolidSpriteMap[TileY, TileX]
  else
    Result := False;
end;

procedure TLevel.SortSpritesByLayer;
var
  i, BehindCount, FrontCount: Integer;
begin
  BehindCount := 0; FrontCount := 0;
  for i := 0 to High(FSprites) do
    if FSprites[i].Layer = slBehind then
      Inc(BehindCount)
    else
      Inc(FrontCount);

  SetLength(FBehindSprites, BehindCount);
  SetLength(FFrontSprites, FrontCount);

  BehindCount := 0; FrontCount := 0;
  for i := 0 to High(FSprites) do
    if FSprites[i].Layer = slBehind then
    begin
      FBehindSprites[BehindCount] := FSprites[i];
      Inc(BehindCount);
    end
    else
    begin
      FFrontSprites[FrontCount] := FSprites[i];
      Inc(FrontCount);
    end;
end;

procedure TLevel.UpdateDynamicLayers(PlayerFootY: Integer);
var
  i: Integer;
  SpriteHeight, SpriteTopY, SpriteBottomY: Integer;
begin
  SetLength(FBehindSprites, 0);
  SetLength(FFrontSprites, 0);

  for i := 0 to High(FSprites) do
  begin
    SpriteHeight := FResourceManager.GetSpriteHeight(FSprites[i].SpriteIndex);
    SpriteTopY := FSprites[i].Y * FMap.TileSize;
    SpriteBottomY := SpriteTopY + SpriteHeight;

    if FSprites[i].Layer = slBehind then
    begin
      SetLength(FBehindSprites, Length(FBehindSprites) + 1);
      FBehindSprites[High(FBehindSprites)] := FSprites[i];
    end
    else
    begin
      if SpriteBottomY <= PlayerFootY then
      begin
        SetLength(FBehindSprites, Length(FBehindSprites) + 1);
        FBehindSprites[High(FBehindSprites)] := FSprites[i];
      end
      else
      begin
        SetLength(FFrontSprites, Length(FFrontSprites) + 1);
        FFrontSprites[High(FFrontSprites)] := FSprites[i];
      end;
    end;
  end;
end;

end.
