unit SpriteDescriptionParser;

interface

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
