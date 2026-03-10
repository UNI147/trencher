unit SoundManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Windows, Classes, Logger, ExtCtrls, MMSystem;

type
  TSoundManager = class
  private
    FStepTimer: TTimer;
    FStepPlaying: Boolean;
    FStepFileName: string;
    FMusicPlaying: Boolean;
    FWindTimer: TTimer;          // таймер для контроля зацикливания ветра
    FWindPlaying: Boolean;
    FWindFileName: string;
    procedure StepTimerHandler(Sender: TObject);
    procedure WindTimerHandler(Sender: TObject); // проверяет состояние ветра и перезапускает
  public
    constructor Create;
    destructor Destroy; override;
    procedure PlayMusic(const FileName: string; Loop: Boolean = True);
    procedure StopMusic;
    procedure PlayWind(const FileName: string; Loop: Boolean = True);
    procedure StopWind;
    procedure PlayStep(const FileName: string; Loop: Boolean = False);
    procedure StopStep;
  end;

implementation

constructor TSoundManager.Create;
begin
  LogSound('TSoundManager.Create (API version)');

  FStepTimer := TTimer.Create(nil);
  FStepTimer.Interval := 400;
  FStepTimer.Enabled := False;
  FStepTimer.OnTimer := @StepTimerHandler;
  FStepPlaying := False;
  FMusicPlaying := False;
  FWindPlaying := False;

  FWindTimer := TTimer.Create(nil);
  FWindTimer.Interval := 500;        // проверка каждые 500 мс
  FWindTimer.Enabled := False;
  FWindTimer.OnTimer := @WindTimerHandler;
end;

destructor TSoundManager.Destroy;
begin
  FStepTimer.Enabled := False;
  FStepTimer.Free;
  FWindTimer.Enabled := False;
  FWindTimer.Free;
  StopMusic;
  StopWind;
  StopStep;
  inherited;
end;

{ Музыка }
procedure TSoundManager.PlayMusic(const FileName: string; Loop: Boolean);
var
  Cmd: string;
  ReturnCode: MCIDEVICEID;
begin
  LogSound('PlayMusic called: ' + FileName);
  StopMusic;

  // Открываем как waveaudio для WAV-файлов
  Cmd := Format('open "%s" type waveaudio alias music', [FileName]);
  ReturnCode := mciSendString(PChar(Cmd), nil, 0, 0);

  if ReturnCode <> 0 then
  begin
    LogError('Failed to open music file, MCI error code: ' + IntToStr(ReturnCode));
    Exit;
  end;

  if Loop then
    Cmd := 'play music repeat'
  else
    Cmd := 'play music';

  ReturnCode := mciSendString(PChar(Cmd), nil, 0, 0);

  if ReturnCode <> 0 then
    LogError('Failed to play music, MCI error code: ' + IntToStr(ReturnCode))
  else
  begin
    FMusicPlaying := True;
    LogSound('Music started successfully');
  end;
end;

procedure TSoundManager.StopMusic;
begin
  if FMusicPlaying then
  begin
    mciSendString('close music', nil, 0, 0);
    FMusicPlaying := False;
    LogSound('Music stopped');
  end;
end;

{ Ветер (WAV) через MCI с зацикливанием через таймер }
procedure TSoundManager.PlayWind(const FileName: string; Loop: Boolean);
var
  Cmd: string;
  ReturnCode: MCIDEVICEID;
begin
  LogSound('PlayWind called: ' + FileName);
  StopWind;  // закрываем предыдущее устройство wind, если открыто

  if not FileExists(FileName) then
  begin
    LogError('Wind file not found: ' + FileName);
    Exit;
  end;

  // открываем wind устройство
  Cmd := Format('open "%s" type waveaudio alias wind', [FileName]);
  ReturnCode := mciSendString(PChar(Cmd), nil, 0, 0);
  if ReturnCode <> 0 then
  begin
    LogError('Failed to open wind file, MCI error code: ' + IntToStr(ReturnCode));
    Exit;
  end;

  // начинаем воспроизведение (без repeat)
  ReturnCode := mciSendString('play wind', nil, 0, 0);
  if ReturnCode <> 0 then
  begin
    LogError('Failed to play wind, MCI error code: ' + IntToStr(ReturnCode));
    mciSendString('close wind', nil, 0, 0);
    Exit;
  end;

  FWindPlaying := True;
  FWindFileName := FileName;
  if Loop then
    FWindTimer.Enabled := True;   // включаем таймер для перезапуска
  LogSound('Wind started successfully (MCI)');
end;

procedure TSoundManager.StopWind;
begin
  FWindTimer.Enabled := False;    // выключаем таймер
  if FWindPlaying then
  begin
    mciSendString('close wind', nil, 0, 0);
    FWindPlaying := False;
    LogSound('Wind stopped (MCI)');
  end;
end;

// Таймер для зацикливания ветра: проверяет, не закончился ли трек
procedure TSoundManager.WindTimerHandler(Sender: TObject);
var
  Status: array[0..128] of Char;
begin
  if not FWindPlaying then Exit;

  // запрашиваем состояние устройства wind
  if mciSendString('status wind mode', @Status, SizeOf(Status), 0) = 0 then
  begin
    if StrIComp(Status, 'stopped') = 0 then
    begin
      // перезапускаем
      mciSendString('seek wind to start', nil, 0, 0);
      mciSendString('play wind', nil, 0, 0);
      LogSound('Wind restarted by timer');
    end;
  end;
end;

{ Шаги (оставлены на PlaySound) }
procedure TSoundManager.StepTimerHandler(Sender: TObject);
begin
  if not FStepPlaying then Exit;
  PlaySound(PChar(FStepFileName), 0, SND_ASYNC or SND_FILENAME or SND_NODEFAULT);
end;

procedure TSoundManager.PlayStep(const FileName: string; Loop: Boolean);
begin
  LogSound('PlayStep called: ' + FileName);

  if not FileExists(FileName) then
  begin
    LogError('Step file not found: ' + FileName);
    Exit;
  end;

  FStepFileName := FileName;
  FStepPlaying := True;

  if Loop then
  begin
    StepTimerHandler(nil);         // сразу проиграть первый шаг
    FStepTimer.Enabled := True;    // включаем таймер для повторения
  end
  else
  begin
    PlaySound(PChar(FileName), 0, SND_ASYNC or SND_FILENAME);
  end;
end;

procedure TSoundManager.StopStep;
begin
  FStepPlaying := False;
  FStepTimer.Enabled := False;
end;

end.
