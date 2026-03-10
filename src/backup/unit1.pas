unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, LCLType,
  Windows, GameEngine, MMSystem, Logger;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormPaint(Sender: TObject);
    procedure TimerTick(Sender: TObject);
  private
    FGameEngine: TGameEngine;
    FTimer: TTimer;
    FVirtualWidth, FVirtualHeight: Integer;
    FJoystickAvailable: Boolean;
    FResourcesPath: string;  // Добавляем поле для хранения пути к ресурсам
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  VIRTUAL_WIDTH = 320;
  VIRTUAL_HEIGHT = 200;
  TILE_SIZE = 20;
  RESOURCES_ROOT = '..\resources\';  // Относительный путь от src к resources

procedure TForm1.FormCreate(Sender: TObject);
var
  LevelsPath: string;
  ji: JOYINFO;
  AppPath: string;
  ScriptPath: string;
begin
  AppPath := ExtractFilePath(ParamStr(0));
  LogDebug('Application started');
  LogDebug('Application path: ' + AppPath);

  // Формируем абсолютный путь к ресурсам
  FResourcesPath := ExpandFileName(AppPath + RESOURCES_ROOT);
  LogDebug('Resources path: ' + FResourcesPath);

  KeyPreview := True;
  FVirtualWidth := VIRTUAL_WIDTH;
  FVirtualHeight := VIRTUAL_HEIGHT;

  LevelsPath := FResourcesPath + 'levels\';
  LogDebug('Levels path: ' + LevelsPath);

  // Создаем игровой движок
  FGameEngine := TGameEngine.Create(TILE_SIZE, FResourcesPath, LevelsPath);

  // Проверяем джойстик
  FJoystickAvailable := (joyGetPos(JOYSTICKID1, @ji) = JOYERR_NOERROR);
  LogDebug('Joystick available: ' + BoolToStr(FJoystickAvailable, True));

  // Инициализируем пути к звукам (относительные от корня ресурсов)
  FGameEngine.InitSounds(
    'music\background.wav',    // Музыка
    'effects\wind.wav',        // Фоновый шум (ambient)
    'effects\step.wav'         // Шаги
  );

  // Загружаем стартовый скрипт
  ScriptPath := FResourcesPath + 'scripts\startup.txt';
  LogDebug('Script path: ' + ScriptPath);

  if FileExists(ScriptPath) then
    FGameEngine.ScriptEngine.ExecuteFile(ScriptPath)
  else
    LogError('Startup script not found: ' + ScriptPath);

  // Создаем таймер после загрузки скрипта
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 41; // ~24 FPS
  FTimer.OnTimer := @TimerTick;

  LogDebug('Startup script executed');
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  LogDebug('Application shutting down');
  FGameEngine.Free;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    LogDebug('ESC pressed - closing application');
    Close;
  end;
end;

procedure TForm1.TimerTick(Sender: TObject);
var
  ji: JOYINFO;
  keyLeft, keyRight, keyUpPressed, keyDownPressed: Boolean;
  joyLeft, joyRight, joyUp, joyDown: Boolean;
  startPressed: Boolean;
const
  DEADZONE = 10000;
  JOY_BUTTON_START = $0200;
begin
  keyLeft   := (GetKeyState(VK_LEFT) and $8000) <> 0;
  keyRight  := (GetKeyState(VK_RIGHT) and $8000) <> 0;
  keyUpPressed := (GetKeyState(VK_UP) and $8000) <> 0;
  keyDownPressed := (GetKeyState(VK_DOWN) and $8000) <> 0;

  joyLeft := False; joyRight := False; joyUp := False; joyDown := False;
  startPressed := False;

  if FJoystickAvailable then
  begin
    if joyGetPos(JOYSTICKID1, @ji) = JOYERR_NOERROR then
    begin
      if ji.wXpos < 32768 - DEADZONE then
        joyLeft := True
      else if ji.wXpos > 32768 + DEADZONE then
        joyRight := True;

      if ji.wYpos < 32768 - DEADZONE then
        joyUp := True
      else if ji.wYpos > 32768 + DEADZONE then
        joyDown := True;

      startPressed := (ji.wButtons and JOY_BUTTON_START) <> 0;
    end
    else
      FJoystickAvailable := False;
  end;

  if startPressed then
  begin
    LogDebug('Start button pressed - closing application');
    Close;
    Exit;
  end;

  FGameEngine.UpdateInput(
    keyLeft   or joyLeft,
    keyRight  or joyRight,
    keyUpPressed or joyUp,
    keyDownPressed or joyDown
  );

  FGameEngine.Update(FTimer.Interval / 1000.0);
  Invalidate;
end;

procedure TForm1.FormPaint(Sender: TObject);
var
  Scale: Double;
  DestWidth, DestHeight: Integer;
  DestRect: TRect;
begin
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(ClientRect);

  if ClientWidth / FVirtualWidth < ClientHeight / FVirtualHeight then
    Scale := ClientWidth / FVirtualWidth
  else
    Scale := ClientHeight / FVirtualHeight;

  DestWidth := Round(FVirtualWidth * Scale);
  DestHeight := Round(FVirtualHeight * Scale);
  DestRect := Bounds(
    (ClientWidth - DestWidth) div 2,
    (ClientHeight - DestHeight) div 2,
    DestWidth, DestHeight
  );

  SetStretchBltMode(Canvas.Handle, STRETCH_DELETESCANS);
  FGameEngine.Render(Canvas, DestRect);
end;

end.
