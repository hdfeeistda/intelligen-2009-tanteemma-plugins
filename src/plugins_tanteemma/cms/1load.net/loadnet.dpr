library loadnet;

uses
  uPlugInInterface,
  uPlugInCMSClass,
  u1loadNet in 'u1loadNet.pas';

{$R *.res}

function LoadPlugin(var PlugIn: ICMSPlugIn): Boolean; stdcall; export;
begin
  try
    PlugIn := T1loadNet.Create;
    Result := True;
  except
    Result := False;
  end;
end;

exports
  LoadPlugIn name 'LoadPlugIn';

begin
end.
