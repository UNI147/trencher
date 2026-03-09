unit Map;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TStringArray = array of string;  // Добавьте это определение

  TMap = class
  private
    FData: array of array of Integer;
    FWidth, FHeight: Integer;
    FTileSize: Integer;
    function GetTile(X, Y: Integer): Integer;
    procedure SetTile(X, Y: Integer; Value: Integer);
  public
    constructor Create(ATileSize: Integer);
    procedure LoadFromStrings(Lines: TStrings; StartIndex: Integer; W, H: Integer);
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Tiles[X, Y: Integer]: Integer read GetTile write SetTile; default;
    property TileSize: Integer read FTileSize;
  end;

implementation

{ Вспомогательная функция SplitString }
function SplitString(const S: string; Delimiter: Char): TStringArray;
var
  i, Start: Integer;
begin
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

{ TMap }

constructor TMap.Create(ATileSize: Integer);
begin
  FTileSize := ATileSize;
  FWidth := 0;
  FHeight := 0;
end;

function TMap.GetTile(X, Y: Integer): Integer;
begin
  if (X >= 0) and (X < FWidth) and (Y >= 0) and (Y < FHeight) then
    Result := FData[Y, X]
  else
    Result := -1;
end;

procedure TMap.SetTile(X, Y: Integer; Value: Integer);
begin
  if (X >= 0) and (X < FWidth) and (Y >= 0) and (Y < FHeight) then
    FData[Y, X] := Value;
end;

procedure TMap.LoadFromStrings(Lines: TStrings; StartIndex: Integer; W, H: Integer);
var
  i, j: Integer;
  Tokens: TStringArray;
begin
  FWidth := W;
  FHeight := H;
  SetLength(FData, H, W);

  for i := 0 to H - 1 do
  begin
    Tokens := SplitString(Trim(Lines[StartIndex + i]), ' ');
    for j := 0 to W - 1 do
      if j < Length(Tokens) then
        FData[i, j] := StrToIntDef(Tokens[j], 0)
      else
        FData[i, j] := 0;
  end;
end;

end.
