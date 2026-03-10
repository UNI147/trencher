unit AnimationController;

interface

type
  TAnimationController = class
  private
    FFrame: Integer;
    FTime: Double;
    FInterval: Double;
  public
    constructor Create(AInterval: Double);
    procedure Update(DeltaTime: Double);
    property CurrentFrame: Integer read FFrame;
  end;
end.
