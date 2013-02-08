library falinkscom;

uses
  uPlugInInterface,
  uPlugInCMSClass,
  uFalinksCom in 'uFalinksCom.pas';

{$R *.res}

function LoadPlugin(var PlugIn: ICMSPlugIn): Boolean; stdcall; export;
begin
  try
    PlugIn := TFalinksCom.Create;
    Result := True;
  except
    Result := False;
  end;
end;

exports
  LoadPlugIn name 'LoadPlugIn';

begin
end.
