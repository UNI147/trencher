unit ScriptEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SoundManager;

type
  TScriptCommand = procedure(const Params: TStringArray) of object;

  TScriptEngine = class
  private
    FSoundManager: TSoundManager;
    FGameEngine: TObject;
    FCommands: TStringList;
    FLastEffectID: string;
    procedure RegisterDefaultCommands;
    // Команды звука
    procedure CmdPlayMusic(const Params: TStringArray);
    procedure CmdStopMusic(const Params: TStringArray);
    procedure CmdPlayAmbient(const Params: TStringArray);
    procedure CmdStopAmbient(const Params: TStringArray);
    procedure CmdPlayEffect(const Params: TStringArray);
    procedure CmdStopEffect(const Params: TStringArray);
    procedure CmdStopAllSounds(const Params: TStringArray);
    // Команды уровня
    procedure CmdLoadLevel(const Params: TStringArray);
    // Новая команда для инициализации звуков движка
    procedure CmdInitSounds(const Params: TStringArray);
  public
    constructor Create(ASoundManager: TSoundManager; AGameEngine: TObject);
    destructor Destroy; override;
    procedure RegisterCommand(const Name: string; Command: TScriptCommand);
    procedure Execute(const CommandLine: string);
    procedure ExecuteFile(const Filename: string);
    property GameEngine: TObject read FGameEngine write FGameEngine;
  end;

  TMethodContainer = class
  public
    Method: TScriptCommand;
    constructor Create(AMethod: TScriptCommand);
  end;

implementation

uses
  Logger, GameEngine;

{ TMethodContainer }

constructor TMethodContainer.Create(AMethod: TScriptCommand);
begin
  Method := AMethod;
end;

{ TScriptEngine }

constructor TScriptEngine.Create(ASoundManager: TSoundManager; AGameEngine: TObject);
begin
  FSoundManager := ASoundManager;
  FGameEngine := AGameEngine;
  FCommands := TStringList.Create;
  FCommands.CaseSensitive := False;
  RegisterDefaultCommands;
end;

destructor TScriptEngine.Destroy;
var
  i: Integer;
begin
  for i := 0 to FCommands.Count - 1 do
    FCommands.Objects[i].Free;
  FCommands.Free;
  inherited;
end;

procedure TScriptEngine.RegisterCommand(const Name: string; Command: TScriptCommand);
begin
  FCommands.AddObject(Name, TMethodContainer.Create(Command));
end;

procedure TScriptEngine.Execute(const CommandLine: string);
var
  Tokens: TStringArray;
  CmdName: string;
  i: Integer;
  Container: TMethodContainer;
begin
  Tokens := CommandLine.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(Tokens) = 0 then Exit;

  if Tokens[0].StartsWith('#') then Exit;

  CmdName := LowerCase(Tokens[0]);
  i := FCommands.IndexOf(CmdName);

  if i >= 0 then
  begin
    Container := FCommands.Objects[i] as TMethodContainer;
    if Assigned(Container) then
    begin
      LogScript('Executing command: ' + CommandLine);
      Container.Method(Copy(Tokens, 1, Length(Tokens)-1));
    end;
  end
  else
    LogError('Unknown script command: "' + CmdName + '" in line: ' + CommandLine);
end;

procedure TScriptEngine.ExecuteFile(const Filename: string);
var
  Lines: TStringList;
  Line: string;
  FullPath: string;
begin
  FullPath := ExpandFileName(Filename);
  if not FileExists(FullPath) then
  begin
    LogError('Script file not found: ' + FullPath);
    Exit;
  end;

  LogScript('Executing script file: ' + FullPath);
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FullPath);
    for Line in Lines do
      if Trim(Line) <> '' then
        Execute(Line);
  finally
    Lines.Free;
  end;
  LogScript('Finished script file: ' + FullPath);
end;

procedure TScriptEngine.RegisterDefaultCommands;
begin
  RegisterCommand('play_music', @CmdPlayMusic);
  RegisterCommand('stop_music', @CmdStopMusic);
  RegisterCommand('play_ambient', @CmdPlayAmbient);
  RegisterCommand('stop_ambient', @CmdStopAmbient);
  RegisterCommand('play_effect', @CmdPlayEffect);
  RegisterCommand('stop_effect', @CmdStopEffect);
  RegisterCommand('stop_all_sounds', @CmdStopAllSounds);
  RegisterCommand('load_level', @CmdLoadLevel);
  RegisterCommand('init_sounds', @CmdInitSounds); // Новая команда

  // Для обратной совместимости
  RegisterCommand('play_sound', @CmdPlayEffect);
end;

procedure TScriptEngine.CmdPlayMusic(const Params: TStringArray);
var
  FileName: string;
  Loop: Boolean;
begin
  if Length(Params) < 1 then
  begin
    LogError('play_music: missing filename parameter');
    Exit;
  end;

  FileName := Params[0];
  Loop := (Length(Params) >= 2) and (LowerCase(Params[1]) = 'loop');

  LogScript('play_music: "' + FileName + '" Loop=' + BoolToStr(Loop, True));
  FSoundManager.PlayMusic(FileName, Loop);
end;

procedure TScriptEngine.CmdStopMusic(const Params: TStringArray);
begin
  LogScript('stop_music');
  FSoundManager.StopMusic;
end;

procedure TScriptEngine.CmdPlayAmbient(const Params: TStringArray);
var
  FileName: string;
  Loop: Boolean;
begin
  if Length(Params) < 1 then
  begin
    LogError('play_ambient: missing filename parameter');
    Exit;
  end;

  FileName := Params[0];
  Loop := (Length(Params) >= 2) and (LowerCase(Params[1]) = 'loop');

  LogScript('play_ambient: "' + FileName + '" Loop=' + BoolToStr(Loop, True));
  FSoundManager.PlayAmbient(FileName, Loop);
end;

procedure TScriptEngine.CmdStopAmbient(const Params: TStringArray);
begin
  LogScript('stop_ambient');
  FSoundManager.StopAmbient;
end;

procedure TScriptEngine.CmdPlayEffect(const Params: TStringArray);
var
  FileName: string;
  Loop: Boolean;
  EffectID: string;
begin
  if Length(Params) < 1 then
  begin
    LogError('play_effect: missing filename parameter');
    Exit;
  end;

  FileName := Params[0];
  Loop := (Length(Params) >= 2) and (LowerCase(Params[1]) = 'loop');

  LogScript('play_effect: "' + FileName + '" Loop=' + BoolToStr(Loop, True));
  EffectID := FSoundManager.PlayEffect(FileName, Loop);

  if EffectID <> '' then
  begin
    FLastEffectID := EffectID;
    LogSound('Effect started with ID: ' + EffectID);
  end;
end;

procedure TScriptEngine.CmdStopEffect(const Params: TStringArray);
var
  EffectID: string;
begin
  if Length(Params) >= 1 then
    EffectID := Params[0]
  else
    EffectID := FLastEffectID;

  if EffectID <> '' then
  begin
    LogScript('stop_effect: ' + EffectID);
    FSoundManager.StopEffect(EffectID);
  end
  else
    LogError('stop_effect: no effect ID specified');
end;

procedure TScriptEngine.CmdStopAllSounds(const Params: TStringArray);
begin
  LogScript('stop_all_sounds');
  FSoundManager.StopAll;
end;

procedure TScriptEngine.CmdLoadLevel(const Params: TStringArray);
var
  LevelFile: string;
  GameEng: TGameEngine;
begin
  if Length(Params) < 1 then
  begin
    LogError('load_level: missing filename parameter');
    Exit;
  end;

  LevelFile := Params[0];
  LogScript('load_level: "' + LevelFile + '"');

  if Assigned(FGameEngine) and (FGameEngine is TGameEngine) then
  begin
    GameEng := FGameEngine as TGameEngine;
    GameEng.LoadLevel(LevelFile);
  end
  else
    LogError('load_level: GameEngine not assigned');
end;

// Новая команда для инициализации звуков движка
procedure TScriptEngine.CmdInitSounds(const Params: TStringArray);
var
  GameEng: TGameEngine;
begin
  if Length(Params) < 3 then
  begin
    LogError('init_sounds: need 3 parameters: music_file ambient_file step_file');
    Exit;
  end;

  if Assigned(FGameEngine) and (FGameEngine is TGameEngine) then
  begin
    GameEng := FGameEngine as TGameEngine;
    GameEng.InitSounds(Params[0], Params[1], Params[2]);
    LogScript('init_sounds: Music="' + Params[0] + '", Ambient="' + Params[1] + '", Step="' + Params[2] + '"');
  end
  else
    LogError('init_sounds: GameEngine not assigned');
end;

end.
