unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, LCLType,
  Windows, GameEngine;

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
begin
  // Обновляем состояние ввода напрямую из таймера
  FGameEngine.UpdateInput(
    (GetKeyState(VK_LEFT) and $8000) <> 0,
    (GetKeyState(VK_RIGHT) and $8000) <> 0,
    (GetKeyState(VK_UP) and $8000) <> 0,
    (GetKeyState(VK_DOWN) and $8000) <> 0
  );

  // Обновляем состояние игры
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
