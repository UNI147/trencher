unit GameTypes;

interface

type
  TStringArray = array of string;

  TTransition = record
    SrcX, SrcY: Integer;
    DestMap: string;
    DestX, DestY: Integer;
  end;
  TTransitionArray = array of TTransition;

  TSpriteLayer = (slBehind, slFront);

  TMapSprite = record
    X, Y: Integer;
    SpriteIndex: Integer;
    IsSolid: Boolean;
    Layer: TSpriteLayer;
    BaseY: Integer;          // зарезервировано для будущего использования
  end;
  TMapSpriteArray = array of TMapSprite;

implementation

end.
