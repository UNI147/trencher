unit PathResolver;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  IPathResolver = interface
    ['{E1A2B3C4-D5E6-F7G8-H9I0-J1K2L3M4N5O6}']
    function GetFullPath(const ResourceType, FileName: string): string;
  end;

  TResourcePathResolver = class(TInterfacedObject, IPathResolver)
  private
    FResourceRoot: string;
  public
    constructor Create(const ARoot: string);
    function GetFullPath(const ResourceType, FileName: string): string;
  end;

implementation

constructor TResourcePathResolver.Create(const ARoot: string);
begin
  FResourceRoot := ARoot;
end;

function TResourcePathResolver.GetFullPath(const ResourceType, FileName: string): string;
begin
  Result := ExtractFilePath(ParamStr(0)) + FResourceRoot + ResourceType + '\' + FileName;
end;

end.
