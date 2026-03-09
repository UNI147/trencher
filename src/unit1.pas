unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, LCLType,
  Windows, GameEngine, MMSystem;

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
  RESOURCES_ROOT = '..\resources\';

procedure TForm1.FormCreate(Sender: TObject);
var
  LevelsPath: string;
  ji: JOYINFO;   // для проверки джойстика
begin
  KeyPreview := True;
  FVirtualWidth := VIRTUAL_WIDTH;
  FVirtualHeight := VIRTUAL_HEIGHT;

  LevelsPath := ExtractFilePath(ParamStr(0)) + RESOURCES_ROOT + 'levels\';

  FGameEngine := TGameEngine.Create(TILE_SIZE, RESOURCES_ROOT, LevelsPath);
  FGameEngine.LoadLevel('level.txt');  // Теперь только имя файла

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 41; // ~24 FPS
  FTimer.OnTimer := @TimerTick;

  // Проверяем, подключён ли джойстик
  FJoystickAvailable := (joyGetPos(JOYSTICKID1, @ji) = JOYERR_NOERROR);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FGameEngine.Free;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

procedure TForm1.TimerTick(Sender: TObject);
var
  ji: JOYINFO;
  keyLeft, keyRight, keyUpPressed, keyDownPressed: Boolean;
  joyLeft, joyRight, joyUp, joyDown: Boolean;
  startPressed: Boolean;
const
  DEADZONE = 10000;
  JOY_BUTTON_START = $0200;  // Кнопка 10 (Start)
begin
  // --- Ввод с клавиатуры ---
  keyLeft   := (GetKeyState(VK_LEFT) and $8000) <> 0;
  keyRight  := (GetKeyState(VK_RIGHT) and $8000) <> 0;
  keyUpPressed := (GetKeyState(VK_UP) and $8000) <> 0;
  keyDownPressed := (GetKeyState(VK_DOWN) and $8000) <> 0;

  // --- Ввод с джойстика (если доступен) ---
  joyLeft := False; joyRight := False; joyUp := False; joyDown := False;
  startPressed := False;

  if FJoystickAvailable then
  begin
    if joyGetPos(JOYSTICKID1, @ji) = JOYERR_NOERROR then
    begin
      // Оси X и Y
      if ji.wXpos < 32768 - DEADZONE then
        joyLeft := True
      else if ji.wXpos > 32768 + DEADZONE then
        joyRight := True;

      if ji.wYpos < 32768 - DEADZONE then
        joyUp := True
      else if ji.wYpos > 32768 + DEADZONE then
        joyDown := True;

      // Проверка кнопки Start
      startPressed := (ji.wButtons and JOY_BUTTON_START) <> 0;
    end
    else
      FJoystickAvailable := False;
  end;

  // --- Выход по кнопке Start на геймпаде ---
  if startPressed then
  begin
    Close;
    Exit;  // Выходим из процедуры, чтобы не обновлять игру
  end;

  // --- Объединяем команды (клавиатура ИЛИ джойстик) ---
  FGameEngine.UpdateInput(
    keyLeft   or joyLeft,
    keyRight  or joyRight,
    keyUpPressed or joyUp,
    keyDownPressed or joyDown
  );

  // --- Обновление игры и перерисовка ---
  FGameEngine.Update(FTimer.Interval / 1000.0);
  Invalidate;
end;

procedure TForm1.FormPaint(Sender: TObject);
var
  Scale: Double;
  DestWidth, DestHeight: Integer;
  DestRect: TRect;
begin
  // Очистка формы
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(ClientRect);

  // Расчет масштаба
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

  // Рендеринг игры
  SetStretchBltMode(Canvas.Handle, STRETCH_DELETESCANS);
  FGameEngine.Render(Canvas, DestRect);
end;

end.
