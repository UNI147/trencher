unit Utils;

interface

uses
  GameTypes;

function SplitString(const S: string; Delimiter: Char): TStringArray;

implementation

function SplitString(const S: string; Delimiter: Char): TStringArray;
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

end.

