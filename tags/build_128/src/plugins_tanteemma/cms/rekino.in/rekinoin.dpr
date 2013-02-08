library rekinoin;

uses
  uPlugInInterface,
  uPlugInCMSClass,
  uRekinoIn in 'uRekinoIn.pas';

{$R *.res}

function LoadPlugin(var PlugIn: ICMSPlugIn): Boolean; stdcall; export;
begin
  try
    PlugIn := TRekinoIn.Create;
    Result := True;
  except
    Result := False;
  end;
end;

exports
  LoadPlugIn name 'LoadPlugIn';

begin
end.
