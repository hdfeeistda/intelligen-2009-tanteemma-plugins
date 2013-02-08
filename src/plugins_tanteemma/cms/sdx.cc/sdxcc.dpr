library sdxcc;

uses
  uPlugInInterface,
  uPlugInCMSClass,
  uSdxCc in 'uSdxCc.pas';

{$R *.res}

function LoadPlugin(var PlugIn: ICMSPlugIn): Boolean; stdcall; export;
begin
  try
    PlugIn := TSdxCc.Create;
    Result := True;
  except
    Result := False;
  end;
end;

exports
  LoadPlugIn name 'LoadPlugIn';

begin
end.
