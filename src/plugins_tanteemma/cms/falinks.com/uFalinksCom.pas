unit uFalinksCom;

interface

uses
  // Delphi
  Windows, SysUtils, StrUtils, Classes, Controls, Variants,
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
  TFalinksComSettings = class(TCMSFormbasedPlugInSettings)
  published
    [AttrDefaultValue('')]
    property hoster_blacklist;

    [AttrDefaultValue(False)]
    property use_plainlinks;
    [AttrDefaultValue(False)]
    property use_textasdescription;

    property categorys;
  end;

  TFalinksCom = class(TCMSFormbasedPlugIn)
  private
    FalinksComSettings: TFalinksComSettings;
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

{ TFalinksCom }

function TFalinksCom.LoadSettings;
begin
  Result := True;
  TPlugInCMSSettingsHelper.LoadSettingsToClass(SettingsFileName, FalinksComSettings, AComponentController);
  with FalinksComSettings do
  begin
    if SameStr('', CharSet) then
      CharSet := DefaultCharset;

    if Assigned(AComponentController) and (categorys = null) then
    begin
      ErrorMsg := 'category is undefined!';
      Result := False;
    end;
  end;
end;

function TFalinksCom.Login(AIdHTTPHelper: TIdHTTPHelper): Boolean;
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
        Add('name=' + AccountName);
        Add('password=' + AccountPassword);
        Add('submit-login=');
      end;

      Request.CharSet := FalinksComSettings.CharSet;
      Enc := CharsetToEncoding(Request.CharSet);
      try
        try
          ResponseStr := Post(Website + '?fa=login', Params, Enc);
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

    if (Pos('http-equiv="refresh" content="1', ResponseStr) = 0) then
    begin
      with TRegExpr.Create do
        try
          ModifierG := False;
          InputString := ResponseStr;
          Expression := '<p class="output txtred">(.*?)<\/p>';

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

function TFalinksCom.PostPage(AIdHTTPHelper: TIdHTTPHelper; AComponentController: IComponentController; AMirrorController: IMirrorController;
  APrevResponse: string): Boolean;
const
  DownloadArray: array [0 .. 5, 0 .. 1] of string = (('hoster1', 'download'), ('hoster2', 'mirror1'), ('hoster3', 'mirror2'), ('hoster4', 'mirror3'),
    ('hoster4', 'mirror4'), ('hoster6', 'mirror5'));
var
  Params: TStringList;
  Enc: TEncoding;
  ResponseStr: string;

  I: Integer;
begin
  Result := False;
  with AIdHTTPHelper do
  begin
    Params := TStringList.Create;
    try
      with Params do
      begin
        Add('cat=' + FalinksComSettings.categorys);

        Add('name=' + Subject);

        if not FalinksComSettings.use_textasdescription then
        begin
          if Assigned(AComponentController.FindControl(cDescription)) then
            Add('comment=' + AComponentController.FindControl(cDescription).Value);
        end
        else
          Add('comment=' + Message);

        with TStringList.Create do
          try
            for I := 0 to AMirrorController.MirrorCount - 1 do
              if (Pos(string(AMirrorController.Mirror[I].Hoster), FalinksComSettings.hoster_blacklist) = 0) then
              begin
                if FalinksComSettings.use_plainlinks then
                  Add(AMirrorController.Mirror[I].DirectlinksMirror[0])
                else if (AMirrorController.Mirror[I].CrypterCount > 0) then
                  Add(AMirrorController.Mirror[I].Crypter[0].Link)
                else
                begin
                  ErrorMsg := 'No crypter initialized! (disable use_plainlinks or add a crypter)';
                  Exit;
                end;
              end;
            Params.Add('link=' + Text);
          finally
            Free;
          end;

        Add('submit-link=');
      end;

      Request.CharSet := FalinksComSettings.CharSet;
      Enc := CharsetToEncoding(Request.CharSet);
      try
        try
          ResponseStr := Post(Website + '?fa=addlink', Params, Enc);
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

      if (Pos('<p class="conttext output txtred">', ResponseStr) > 0) then
      begin
        with TRegExpr.Create do
          try
            ModifierG := False;
            InputString := ResponseStr;
            Expression := '<p class="conttext output txtred">(.*?)<\/p>';

            if Exec(InputString) then
              Self.ErrorMsg := HTML2Text(Trim(Match[1])); ;
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

constructor TFalinksCom.Create;
begin
  inherited Create;
  FalinksComSettings := TFalinksComSettings.Create;
end;

destructor TFalinksCom.Destroy;
begin
  FalinksComSettings.Free;
  inherited Destroy;
end;

function TFalinksCom.GetName: WideString;
begin
  Result := 'falinks.com';
end;

function TFalinksCom.DefaultCharset: WideString;
begin
  Result := 'ISO-8859-1';
end;

function TFalinksCom.BelongsTo(AWebsiteSourceCode: WideString): Boolean;
begin
  Result := False;
end;

function TFalinksCom.GetIDs: Integer;
begin
  Result := FCheckedIDsList.Count;
end;

function TFalinksCom.ShowWebsiteSettingsEditor;
begin
  TPlugInCMSSettingsHelper.LoadSettingsToWebsiteEditor(SettingsFileName, TFalinksComSettings, AWebsiteEditor);
  Result := IsPositiveResult(AWebsiteEditor.ShowModal);
end;

end.
