unit SpriteDescriptionParser;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TStringArray = array of string;

  TSpriteDescriptionParser = class
  public
    class procedure Parse(const Desc: string;
      out FileNames: TStringArray; out IsSolid, IsBehind: Boolean);
  end;

implementation

class procedure TSpriteDescriptionParser.Parse(const Desc: string;
  out FileNames: TStringArray; out IsSolid, IsBehind: Boolean);

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

var
  Items: TStringArray;
  i: Integer;
  TempFiles: TStringArray;
  HasFrontFlag, HasBehindFlag: Boolean;
begin
  Items := SplitString(Desc, ',');
  IsBehind := True;    // по умолчанию за игроком
  IsSolid := False;
  TempFiles := nil;
  HasFrontFlag := False;
  HasBehindFlag := False;

  // Первый проход: собираем флаги и файлы
  for i := 0 to High(Items) do
  begin
    Items[i] := LowerCase(Trim(Items[i]));

    if Items[i] = 'solid' then
      IsSolid := True
    else if Items[i] = 'front' then
      HasFrontFlag := True
    else if Items[i] = 'behind' then
      HasBehindFlag := True
    else if Items[i] <> '' then
    begin
      // это имя файла – добавляем в результирующий массив
      SetLength(TempFiles, Length(TempFiles) + 1);
      TempFiles[High(TempFiles)] := Items[i];
    end;
  end;

  // Определяем порядок отрисовки (front имеет приоритет над behind)
  if HasFrontFlag then
    IsBehind := False
  else if HasBehindFlag then
    IsBehind := True;
  // если нет ни того, ни другого - оставляем IsBehind = True (по умолчанию)

  FileNames := TempFiles;

  if Length(FileNames) = 0 then
    raise Exception.Create('Не указаны файлы спрайта в строке: ' + Desc);
end;

end.
