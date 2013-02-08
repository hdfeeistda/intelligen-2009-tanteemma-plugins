library sexuriacom;

uses
  uPlugInInterface,
  uPlugInCMSClass,
  uSexuriaCom in 'uSexuriaCom.pas';

{$R *.res}

function LoadPlugin(var PlugIn: ICMSPlugIn): Boolean; stdcall; export;
begin
  try
    PlugIn := TSexuriaCom.Create;
    Result := True;
  except
    Result := False;
  end;
end;

exports
  LoadPlugIn name 'LoadPlugIn';

begin
end.
