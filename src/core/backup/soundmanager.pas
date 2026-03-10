unit SoundManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Windows, Classes, MMSystem, Logger;

type
  TSoundChannel = (scMusic, scAmbient, scEffect);
  TSoundStatus = (ssStopped, ssPlaying, ssPaused);

  TSoundInstance = class
  private
    FFileName: string;
    FChannel: TSoundChannel;
    FLoop: Boolean;
    FSoundStatus: TSoundStatus;
    FVolume: Integer;
    FAlias: string;
    FLastCheckTime: DWORD;
    FCheckInterval: DWORD;
  public
    constructor Create(const AFileName: string; AChannel: TSoundChannel;
                       ALoop: Boolean; const AAlias: string);
    destructor Destroy; override;
    function Play: Boolean;
    procedure Stop;
    procedure Pause;
    procedure SetVolume(AVolume: Integer);
    procedure CheckStatus;  // Теперь вызывается вручную
    property Status: TSoundStatus read FSoundStatus;
    property Channel: TSoundChannel read FChannel;
    property Alias: string read FAlias;
  end;

  TSoundManager = class
  private
    FResourceRoot: string;
    FSoundInstances: TList;  // Используем TList вместо самописного
    FBackgroundMusic: TSoundInstance;
    FBackgroundAmbient: TSoundInstance;
    FNextAliasID: Integer;
    FStatusCheckInterval: DWORD;

    function ResolvePath(const FileName: string): string;
    function GenerateAlias(const Prefix: string): string;
    procedure StopBackgroundChannel(AChannel: TSoundChannel);
    procedure RemoveInstance(Index: Integer);
    function FindInstanceByAlias(const AAlias: string): TSoundInstance;
  public
    constructor Create(const AResourceRoot: string = '');
    destructor Destroy; override;

    procedure Update;  // Добавлен метод для периодического вызова

    procedure SetResourceRoot(const ARoot: string);

    // Для фоновых каналов
    procedure PlayMusic(const FileName: string; Loop: Boolean = True);
    procedure StopMusic;
    procedure PlayAmbient(const FileName: string; Loop: Boolean = True);
    procedure StopAmbient;

    // Для звуковых эффектов
    function PlayEffect(const FileName: string; Loop: Boolean = False): string;
    procedure StopEffect(const EffectAlias: string);
    procedure StopAllEffects;

    // Общие методы
    procedure StopAll;
    procedure SetVolume(const Alias: string; Volume: Integer);
    function IsSoundPlaying(const Alias: string): Boolean;

    property ResourceRoot: string read FResourceRoot write SetResourceRoot;
  end;

implementation

const
  STATUS_CHECK_INTERVAL = 100; // Проверяем статус каждые 100 мс
  MAX_ALIAS_LENGTH = 50;

{ TSoundInstance }

constructor TSoundInstance.Create(const AFileName: string; AChannel: TSoundChannel;
                                   ALoop: Boolean; const AAlias: string);
begin
  FFileName := AFileName;
  FChannel := AChannel;
  FLoop := ALoop;
  FAlias := AAlias;
  FSoundStatus := ssStopped;
  FVolume := 1000;
  FLastCheckTime := 0;
  FCheckInterval := STATUS_CHECK_INTERVAL;
end;

destructor TSoundInstance.Destroy;
begin
  Stop;
  inherited;
end;

function TSoundInstance.Play: Boolean;
var
  Cmd: string;
  ErrorCode: DWORD;
begin
  Result := False;

  if FSoundStatus = ssPlaying then
    Exit(True);

  Stop; // Закрываем предыдущее устройство если было

  if not FileExists(FFileName) then
  begin
    LogError(Format('Sound file not found: %s', [FFileName]));
    Exit;
  end;

  // Открываем файл
  Cmd := Format('open "%s" type waveaudio alias %s', [FFileName, FAlias]);
  if mciSendString(PChar(Cmd), nil, 0, 0) <> 0 then
  begin
    LogError(Format('Failed to open sound: %s', [FFileName]));
    Exit;
  end;

  // Устанавливаем громкость
  if FVolume < 1000 then
  begin
    Cmd := Format('set %s volume %d', [FAlias, FVolume]);
    mciSendString(PChar(Cmd), nil, 0, 0);
  end;

  // Воспроизводим
  Cmd := Format('play %s', [FAlias]);
  ErrorCode := mciSendString(PChar(Cmd), nil, 0, 0);
  if ErrorCode <> 0 then
  begin
    mciSendString(PChar(Format('close %s', [FAlias])), nil, 0, 0);
    LogError(Format('Failed to play sound: %s', [FFileName]));
    Exit;
  end;

  FSoundStatus := ssPlaying;
  FLastCheckTime := GetTickCount;
  LogSound(Format('Sound played: %s [Alias=%s]', [ExtractFileName(FFileName), FAlias]));
  Result := True;
end;

procedure TSoundInstance.Stop;
begin
  if FSoundStatus <> ssStopped then
  begin
    mciSendString(PChar(Format('stop %s', [FAlias])), nil, 0, 0);
    mciSendString(PChar(Format('close %s', [FAlias])), nil, 0, 0);
    FSoundStatus := ssStopped;
    LogSound(Format('Sound stopped: %s', [FAlias]));
  end;
end;

procedure TSoundInstance.Pause;
begin
  if FSoundStatus = ssPlaying then
  begin
    mciSendString(PChar(Format('pause %s', [FAlias])), nil, 0, 0);
    FSoundStatus := ssPaused;
  end;
end;

procedure TSoundInstance.SetVolume(AVolume: Integer);
begin
  if AVolume < 0 then AVolume := 0;
  if AVolume > 1000 then AVolume := 1000;

  FVolume := AVolume;

  if FSoundStatus = ssPlaying then
  begin
    mciSendString(PChar(Format('set %s volume %d', [FAlias, FVolume])), nil, 0, 0);
  end;
end;

procedure TSoundInstance.CheckStatus;
var
  StatusStr: array[0..128] of Char;
  CurrentTime: DWORD;
begin
  if FSoundStatus <> ssPlaying then
    Exit;

  // Убираем ограничение на проверку - проверяем каждый раз

  if mciSendString(PChar(Format('status %s mode', [FAlias])), @StatusStr, SizeOf(StatusStr), 0) = 0 then
  begin
    if (StrIComp(StatusStr, 'stopped') = 0) then
    begin
      if FLoop then
      begin
        // Для зацикленных звуков лучше использовать MCI с флагом "repeat"

        // Останавливаем текущее воспроизведение
        mciSendString(PChar(Format('stop %s', [FAlias])), nil, 0, 0);

        // Перематываем в начало
        mciSendString(PChar(Format('seek %s to start', [FAlias])), nil, 0, 0);

        // Запускаем снова
        mciSendString(PChar(Format('play %s', [FAlias])), nil, 0, 0);

        LogSound(Format('Looping sound restarted: %s', [FAlias]));
      end
      else
      begin
        FSoundStatus := ssStopped;
      end;
    end;
  end
  else
  begin
    FSoundStatus := ssStopped;
  end;
end;

{ TSoundManager }

constructor TSoundManager.Create(const AResourceRoot: string = '');
begin
  FResourceRoot := AResourceRoot;
  if FResourceRoot <> '' then
    FResourceRoot := IncludeTrailingPathDelimiter(FResourceRoot);

  FSoundInstances := TList.Create;
  FBackgroundMusic := nil;
  FBackgroundAmbient := nil;
  FNextAliasID := 1;
  FStatusCheckInterval := STATUS_CHECK_INTERVAL;

  LogSound('TSoundManager optimized created');
end;

destructor TSoundManager.Destroy;
begin
  StopAll;
  FSoundInstances.Free;
  inherited;
end;

procedure TSoundManager.Update;
var
  i: Integer;
  Instance: TSoundInstance;
begin
  // Убираем задержку или уменьшаем её, вызывая CheckStatus без ограничений
  for i := FSoundInstances.Count - 1 downto 0 do
  begin
    Instance := TSoundInstance(FSoundInstances[i]);
    Instance.CheckStatus; // Будет проверять каждый кадр

    if (Instance.Channel = scEffect) and
       (Instance.Status = ssStopped) and
       (not Instance.FLoop) then
    begin
      RemoveInstance(i);
    end;
  end;
end;

procedure TSoundManager.RemoveInstance(Index: Integer);
begin
  if (Index >= 0) and (Index < FSoundInstances.Count) then
  begin
    TSoundInstance(FSoundInstances[Index]).Free;
    FSoundInstances.Delete(Index);
  end;
end;

function TSoundManager.FindInstanceByAlias(const AAlias: string): TSoundInstance;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FSoundInstances.Count - 1 do
  begin
    if TSoundInstance(FSoundInstances[i]).Alias = AAlias then
    begin
      Result := TSoundInstance(FSoundInstances[i]);
      Break;
    end;
  end;
end;

procedure TSoundManager.SetResourceRoot(const ARoot: string);
begin
  FResourceRoot := ARoot;
  if FResourceRoot <> '' then
    FResourceRoot := IncludeTrailingPathDelimiter(FResourceRoot);
end;

function TSoundManager.ResolvePath(const FileName: string): string;
begin
  if (Length(FileName) > 2) and (FileName[2] = ':') then
    Result := FileName
  else if FResourceRoot <> '' then
    Result := FResourceRoot + FileName
  else
    Result := FileName;

  Result := ExpandFileName(Result);
end;

function TSoundManager.GenerateAlias(const Prefix: string): string;
begin
  Result := Prefix + IntToStr(FNextAliasID) + '_' + IntToStr(GetTickCount mod 10000);
  Inc(FNextAliasID);
  if Length(Result) > MAX_ALIAS_LENGTH then
    SetLength(Result, MAX_ALIAS_LENGTH);
end;

procedure TSoundManager.StopBackgroundChannel(AChannel: TSoundChannel);
var
  Instance: TSoundInstance;
begin
  case AChannel of
    scMusic:
      if Assigned(FBackgroundMusic) then
      begin
        Instance := FBackgroundMusic;
        FBackgroundMusic := nil;
        FSoundInstances.Remove(Instance);
        Instance.Free;
      end;
    scAmbient:
      if Assigned(FBackgroundAmbient) then
      begin
        Instance := FBackgroundAmbient;
        FBackgroundAmbient := nil;
        FSoundInstances.Remove(Instance);
        Instance.Free;
      end;
  end;
end;

procedure TSoundManager.PlayMusic(const FileName: string; Loop: Boolean);
var
  FullPath: string;
  Alias: string;
begin
  FullPath := ResolvePath(FileName);
  if not FileExists(FullPath) then
  begin
    LogError('Music file not found: ' + FullPath);
    Exit;
  end;

  StopBackgroundChannel(scMusic);

  Alias := GenerateAlias('MUSIC_');
  FBackgroundMusic := TSoundInstance.Create(FullPath, scMusic, Loop, Alias);
  FSoundInstances.Add(FBackgroundMusic);

  if not FBackgroundMusic.Play then
    StopBackgroundChannel(scMusic);
end;

procedure TSoundManager.StopMusic;
begin
  StopBackgroundChannel(scMusic);
end;

procedure TSoundManager.PlayAmbient(const FileName: string; Loop: Boolean);
var
  FullPath: string;
  Alias: string;
begin
  FullPath := ResolvePath(FileName);
  if not FileExists(FullPath) then
  begin
    LogError('Ambient file not found: ' + FullPath);
    Exit;
  end;

  StopBackgroundChannel(scAmbient);

  Alias := GenerateAlias('AMBIENT_');
  FBackgroundAmbient := TSoundInstance.Create(FullPath, scAmbient, Loop, Alias);
  FSoundInstances.Add(FBackgroundAmbient);

  FBackgroundAmbient.Play;
end;

procedure TSoundManager.StopAmbient;
begin
  StopBackgroundChannel(scAmbient);
end;

function TSoundManager.PlayEffect(const FileName: string; Loop: Boolean): string;
var
  FullPath: string;
  Alias: string;
  Effect: TSoundInstance;
begin
  Result := '';
  FullPath := ResolvePath(FileName);
  if not FileExists(FullPath) then
  begin
    LogError('Effect file not found: ' + FullPath);
    Exit;
  end;

  Alias := GenerateAlias('EFFECT_');
  Effect := TSoundInstance.Create(FullPath, scEffect, Loop, Alias);
  FSoundInstances.Add(Effect);

  if Effect.Play then
    Result := Alias
  else
  begin
    FSoundInstances.Remove(Effect);
    Effect.Free;
  end;
end;

procedure TSoundManager.StopEffect(const EffectAlias: string);
var
  Effect: TSoundInstance;
  i: Integer;
begin
  Effect := FindInstanceByAlias(EffectAlias);
  if Assigned(Effect) and (Effect.Channel = scEffect) then
  begin
    i := FSoundInstances.IndexOf(Effect);
    if i >= 0 then
      RemoveInstance(i);
  end;
end;

procedure TSoundManager.StopAllEffects;
var
  i: Integer;
  Instance: TSoundInstance;
begin
  for i := FSoundInstances.Count - 1 downto 0 do
  begin
    Instance := TSoundInstance(FSoundInstances[i]);
    if Instance.Channel = scEffect then
      RemoveInstance(i);
  end;
end;

procedure TSoundManager.StopAll;
begin
  StopMusic;
  StopAmbient;
  StopAllEffects;
end;

procedure TSoundManager.SetVolume(const Alias: string; Volume: Integer);
var
  Instance: TSoundInstance;
begin
  Instance := FindInstanceByAlias(Alias);
  if Assigned(Instance) then
    Instance.SetVolume(Volume);
end;

function TSoundManager.IsSoundPlaying(const Alias: string): Boolean;
var
  Instance: TSoundInstance;
begin
  Instance := FindInstanceByAlias(Alias);
  Result := Assigned(Instance) and (Instance.Status = ssPlaying);
end;

end.
