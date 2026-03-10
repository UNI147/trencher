unit Logger;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Windows;

procedure LogDebug(const Msg: string);
procedure LogError(const Msg: string);
procedure LogSound(const Msg: string);

implementation

var
  LogFile: TStringList;
  Initialized: Boolean = False;

procedure InitializeLogger;
var
  LogPath: string;
begin
  if Initialized then Exit;

  LogFile := TStringList.Create;
  LogPath := ExtractFilePath(ParamStr(0)) + 'debug_log.txt';

  // Добавляем заголовок с временем запуска
  LogFile.Add('=== Game Debug Log ===');
  LogFile.Add('Start time: ' + DateTimeToStr(Now));
  LogFile.Add('Working directory: ' + ExtractFilePath(ParamStr(0)));
  LogFile.Add('');

  LogFile.SaveToFile(LogPath);
  Initialized := True;
end;

procedure WriteToLog(const Prefix, Msg: string);
var
  LogPath: string;
  TimeStr: string;
begin
  if not Initialized then
    InitializeLogger;

  TimeStr := FormatDateTime('hh:nn:ss.zzz', Now);
  LogPath := ExtractFilePath(ParamStr(0)) + 'debug_log.txt';

  try
    LogFile.LoadFromFile(LogPath);
    LogFile.Add(Format('[%s] %s: %s', [TimeStr, Prefix, Msg]));
    LogFile.SaveToFile(LogPath);
  except
    // Если не получается записать в файл, пробуем создать новый
    try
      LogFile.Clear;
      LogFile.Add('=== Game Debug Log (recreated) ===');
      LogFile.Add(Format('[%s] %s: %s', [TimeStr, Prefix, Msg]));
      LogFile.SaveToFile(LogPath);
    except
      // Игнорируем ошибки записи
    end;
  end;
end;

procedure LogDebug(const Msg: string);
begin
  WriteToLog('DEBUG', Msg);
  OutputDebugString(PChar('DEBUG: ' + Msg));
end;

procedure LogError(const Msg: string);
begin
  WriteToLog('ERROR', Msg);
  OutputDebugString(PChar('ERROR: ' + Msg));
end;

procedure LogSound(const Msg: string);
begin
  WriteToLog('SOUND', Msg);
  OutputDebugString(PChar('SOUND: ' + Msg));
end;

finalization
  if Assigned(LogFile) then
  begin
    LogFile.Add('');
    LogFile.Add('=== Log closed at ' + DateTimeToStr(Now) + ' ===');
    LogFile.SaveToFile(ExtractFilePath(ParamStr(0)) + 'debug_log.txt');
    LogFile.Free;
  end;

end.
