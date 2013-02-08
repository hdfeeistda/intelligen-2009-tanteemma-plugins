unit uSexuriaCom;

interface

uses
  // Delphi
  Windows, SysUtils, StrUtils, Classes, Controls, Variants, HTTPApp,
  // Indy
  IdGlobalProtocols,
  // RegEx
  RegExpr,
  // Utils,
  uHTMLUtils, uSpecialStringUtils,
  // Common
  uConst, uAppInterface,
  // Plugin system
  uPlugInCMSClass, uPlugInCMSFormbasedClass, uPlugInCMSSettingsHelper, uIdHTTPHelper;

type
  TSexuriaComSettings = class(TCMSFormbasedPlugInSettings)
  strict private
    fround_size: Boolean;
  published
    [AttrDefaultValue(False)]
    property use_plainlinks;
    [AttrDefaultValue(False)]
    property use_textasdescription;

    [AttrDefaultValue(False)]
    property round_size: Boolean read fround_size write fround_size;

    property categorys;
  end;

  TSexuriaCom = class(TCMSFormbasedPlugIn)
  private
    SexuriaComSettings: TSexuriaComSettings;
  protected
    function LoadSettings(AComponentController: IComponentController = nil): Boolean; override;
    function Login(AIdHTTPHelper: TIdHTTPHelper): Boolean; override;
    function PostPage(AIdHTTPHelper: TIdHTTPHelper; AComponentController: IComponentController; AMirrorController: IMirrorController;
      APrevResponse: string = ''): Boolean; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    function GetName: WideString; override; safecall;
    function DefaultCharset: WideString; override;
    function BelongsTo(AWebsiteSourceCode: WideString): Boolean; override;
    function GetIDs: Integer; override;
    function ShowWebsiteSettingsEditor(AWebsiteEditor: IWebsiteEditor): Boolean; override;
  end;

implementation

{ TSexuriaCom }

function TSexuriaCom.LoadSettings;
begin
  Result := True;
  TPlugInCMSSettingsHelper.LoadSettingsToClass(SettingsFileName, SexuriaComSettings, AComponentController);
  with SexuriaComSettings do
  begin
    if SameStr('', Charset) then
      Charset := DefaultCharset;

    if Assigned(AComponentController) and (categorys = null) then
    begin
      ErrorMsg := 'category is undefined!';
      Result := False;
    end;
  end;
end;

function TSexuriaCom.Login(AIdHTTPHelper: TIdHTTPHelper): Boolean;
var
  Params: TStringList;
  Enc: TEncoding;
  ResponseStr: string;
begin
  Result := False;
  with AIdHTTPHelper do
  begin
    Params := TStringList.Create;
    try
      with Params do
      begin
        Add('user=' + AccountName);
        Add('pwd=' + AccountPassword);
        Add('Submit=');
      end;

      Request.Charset := SexuriaComSettings.Charset;
      Enc := CharsetToEncoding(Request.Charset);
      try
        try
          ResponseStr := Post(Website + 'login.html', Params, Enc);
        except
          on E: Exception do
          begin
            ErrorMsg := E.message;
            Exit;
          end;
        end;
      finally
        Enc.Free;
      end;
    finally
      Params.Free;
    end;

    if (Pos('http-equiv="refresh" content="3', ResponseStr) = 0) then
      with TRegExpr.Create do
      begin
        try
          ModifierG := False;
          InputString := ResponseStr;
          Expression := '<center><B>(.*?)<\/B><\/center>';

          if Exec(InputString) then
            Self.ErrorMsg := Trim(HTML2Text(Match[1]));
        finally
          Free;
        end;
        Exit;
      end;
  end;
  Result := True;
end;

function TSexuriaCom.PostPage(AIdHTTPHelper: TIdHTTPHelper; AComponentController: IComponentController;
  AMirrorController: IMirrorController; APrevResponse: string): Boolean;
const
  DownloadArray: array [0 .. 5, 0 .. 1] of string = (('hoster1_text', 'download2'), ('hoster2_text', 'mirror1'),
    ('hoster3_text', 'mirror2'), ('hoster4_text', 'mirror3'), ('hoster5_text', 'mirror4'), ('hoster6_text', 'mirror5'));
var
  Params: TStringList;
  Enc: TEncoding;
  ResponseStr: string;

  I, J: Integer;
begin
  Result := False;
  with AIdHTTPHelper do
  begin
    Params := TStringList.Create;
    try
      with Params do
      begin
        Add('name=' + Subject);

        if Assigned(AComponentController.FindControl(cPassword)) then
          Add('password=' + AComponentController.FindControl(cPassword).Value);

        for I := 0 to AMirrorController.MirrorCount - 1 do
          if AMirrorController.Mirror[I].Size > 0 then
          begin
            if SexuriaComSettings.round_size then
              Add('size=' + IntToStr(round(AMirrorController.Mirror[I].Size)))
            else
              Add('size=' + FloatToStr(AMirrorController.Mirror[I].Size));
            break;
          end;

        if Assigned(AComponentController.FindControl(cPicture)) then
          Add('image=' + AComponentController.FindControl(cPicture).Value);

        if Assigned(AComponentController.FindControl(cSample)) then
          Add('image3=' + AComponentController.FindControl(cSample).Value);

        if Assigned(AComponentController.FindControl(cRuntime)) then
          Add('dauer=' + AComponentController.FindControl(cRuntime).Value + ' Minuten')
        else
          Add('dauer=90 Minuten');

        Add('cat[]=' + SexuriaComSettings.categorys);

        if not SexuriaComSettings.use_textasdescription then
        begin
          if Assigned(AComponentController.FindControl(cDescription)) then
            Add('beschreibung=' + AComponentController.FindControl(cDescription).Value);
        end
        else
          Add('beschreibung=' + Message);

        J := 0;
        for I := 0 to AMirrorController.MirrorCount - 1 do
          if (Pos(string(AMirrorController.Mirror[I].Hoster), SexuriaComSettings.hoster_blacklist) = 0) then
          begin
            if (J = 6) then
              break;

            if SexuriaComSettings.use_plainlinks then
              Add(DownloadArray[J][1] + '=' + Trim(AMirrorController.Mirror[I].DirectlinksMirror[0]))
            else if (AMirrorController.Mirror[I].CrypterCount > 0) then
              Add(DownloadArray[J][1] + '=' + AMirrorController.Mirror[I].Crypter[0].Link)
          else
          begin
            ErrorMsg := 'No crypter initialized! (disable use_plainlinks or add a crypter)';
            Exit;
          end;
            Add(DownloadArray[J][0] + '=' + AMirrorController.Mirror[I].Hoster);

            Inc(J);
          end;

        Add('sent=1');
      end;

      Request.Charset := SexuriaComSettings.Charset;
      Enc := CharsetToEncoding(Request.Charset);
      try
        try
          ResponseStr := Post(Website + 'index.php?do=add', Params, Enc);
        except
          on E: Exception do
          begin
            ErrorMsg := E.message;
            Exit;
          end;
        end;
      finally
        Enc.Free;
      end;

      with TStringlist.Create do
      try

        Text := ResponseStr;
        SaveToFile('a.htm');
      finally
        Free;
      end;

      if (Pos('href="javascript:history.back()', ResponseStr) > 0) then
      begin
        with TRegExpr.Create do
          try
            ModifierG := False;
            InputString := ResponseStr;
            Expression := '<br><br><center>(.*?)<br><br><br>';

            if Exec(InputString) then
              Self.ErrorMsg := Trim(HTML2Text(Match[1]));
          finally
            Free;
          end;
        Exit;
      end;

      Result := True;
    finally
      Params.Free;
    end;
  end;
end;

constructor TSexuriaCom.Create;
begin
  inherited Create;
  SexuriaComSettings := TSexuriaComSettings.Create;
end;

destructor TSexuriaCom.Destroy;
begin
  SexuriaComSettings.Free;
  inherited Destroy;
end;

function TSexuriaCom.GetName: WideString;
begin
  Result := 'sexuria.com';
end;

function TSexuriaCom.DefaultCharset: WideString;
begin
  Result := 'ISO-8859-1';
end;

function TSexuriaCom.BelongsTo(AWebsiteSourceCode: WideString): Boolean;
begin
  Result := False;
end;

function TSexuriaCom.GetIDs: Integer;
begin
  Result := FCheckedIDsList.Count;
end;

function TSexuriaCom.ShowWebsiteSettingsEditor;
begin
  TPlugInCMSSettingsHelper.LoadSettingsToWebsiteEditor(SettingsFileName, TSexuriaComSettings, AWebsiteEditor);
  Result := IsPositiveResult(AWebsiteEditor.ShowModal);
end;

end.
