unit AnimationController;

{$mode objfpc}{$H+}

interface

type
  TAnimationController = class
  private
    FFrame: Integer;
    FTime: Double;
    FInterval: Double;
    FMaxFrame: Integer;
  public
    constructor Create(AInterval: Double; AMaxFrame: Integer = 0);
    procedure Update(DeltaTime: Double);
    procedure SetMaxFrame(AMaxFrame: Integer);
    property CurrentFrame: Integer read FFrame;
    property Interval: Double read FInterval write FInterval;
    property MaxFrame: Integer read FMaxFrame write FMaxFrame;
  end;

implementation

constructor TAnimationController.Create(AInterval: Double; AMaxFrame: Integer = 0);
begin
  FInterval := AInterval;
  FMaxFrame := AMaxFrame;
  FFrame := 0;
  FTime := 0;
end;

procedure TAnimationController.Update(DeltaTime: Double);
begin
  if FMaxFrame <= 0 then Exit;

  FTime := FTime + DeltaTime;
  while FTime >= FInterval do
  begin
    FTime := FTime - FInterval;
    FFrame := (FFrame + 1) mod FMaxFrame;
  end;
end;

procedure TAnimationController.SetMaxFrame(AMaxFrame: Integer);
begin
  FMaxFrame := AMaxFrame;
  if FFrame >= FMaxFrame then
    FFrame := 0;
end;

end.
