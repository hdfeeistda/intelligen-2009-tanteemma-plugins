unit u1loadNet;

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

  T1loadNetSettings = class(TCMSFormbasedPlugInSettings)
  strict private
    fround_size: Boolean;

    fgenres, fformats: Variant;
  published
    [AttrDefaultValue('')]
    property hoster_blacklist;

    [AttrDefaultValue(False)]
    property use_textasdescription;
    [AttrDefaultValue(False)]
    property round_size: Boolean read fround_size write fround_size;

    property categorys;
    property genres: Variant read fgenres write fgenres;
    property formats: Variant read fformats write fformats;
  end;

  T1loadNet = class(TCMSFormbasedPlugIn)
  private
    _1loadNetSettings: T1loadNetSettings;
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

{ T1loadNet }

function T1loadNet.LoadSettings;
begin
  Result := True;
  TPlugInCMSSettingsHelper.LoadSettingsToClass(SettingsFileName, _1loadNetSettings, AComponentController);
  with _1loadNetSettings do
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

function T1loadNet.Login(AIdHTTPHelper: TIdHTTPHelper): Boolean;
var
  Params: TStringList;
  Enc: TEncoding;
  ResponseStr: string;
begin
  Result := False;
  with AIdHTTPHelper do
  begin
    RedirectMaximum := 1;

    Params := TStringList.Create;
    try
      with Params do
      begin
        Add('ident=' + AccountName);
        Add('password=' + AccountPassword);
        Add('go=GO!');
      end;

      Request.CharSet := _1loadNetSettings.CharSet;
      Enc := CharsetToEncoding(Request.CharSet);
      try
        try
          ResponseStr := Post(Website + 'user/login', Params, Enc);
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

    if (Pos('/user/logout', ResponseStr) = 0) and not(ResponseStr = '') then
    begin
      with TRegExpr.Create do
        try
          InputString := ResponseStr;
          Expression := 'class="error">(.*?)<\/p>';

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

function T1loadNet.PostPage(AIdHTTPHelper: TIdHTTPHelper; AComponentController: IComponentController; AMirrorController: IMirrorController;
  APrevResponse: string): Boolean;

  function convert_hosternames(AHosterName: string): string;

  (*
    <option value="28">files.mail.ru</option> // fehlt noch
    *)

  const
    HosterList: array [0 .. 46, 0 .. 1] of string = ( { }
      ('4fastfile.com', '58'), { }
      ('Bayfiles.com', '49'), { }
      ('Bitshare.com', '34'), { }
      ('Cloudnator.com', '6'), { }
      // ('???', '55'), { }
      ('Crocko.com', '42'), { }
      ('Cloudzer.net', '72'), { }
      ('Datei.to', '23'), { }
      ('Ddlstorage.com', '71'), { }
      ('Depositfiles.com', '10'), { }
      ('Easybytez.com', '50'), { }
      // ('Duckload.com', '33'), { }
      ('Enterupload.com', '43'), { }
      ('Extabit.com', '51'), { }
      ('Fiberupload.com', '53'), { }
      ('Filebase.to', '11'), { }
      ('Filecloud.ws', '57'), { }
      ('Filefactory.com', '13'), { }
      ('Filefrog.to', '29'), { }
      ('Filegag.com', '69'), { }
      ('Filejungle.com', '46'), { }
      ('Filepost.com', '45'), { }
      ('Filesega.com', '54'), { }
      // ('dxr.lanedo.com', '68'), { }
      ('Freakshare.com', '17'), { }
      ('Glumbouploads.com', '64'), { }
      ('Henchfile.com', '66'), { }
      ('Hitfile.net', '56'), { }
      ('Hotfile.com', '3'), { }
      ('Hulkshare.com', '47'), { }
      // ('offline', '63'), { }
      ('Letitbit.net', '30'), { }
      ('Load.to', '32'), { }
      ('Mediafire.com', '37'), { }
      ('Megaupload.com', '8'), { }
      ('Netload.in', '2'), { }
      ('Oron.com', '44'), { }
      ('Rapidgator.net', '52'), { }
      ('Rapidshare.com', '1'), { }
      ('Remixshare.com', '24'), { }
      ('Secureupload.eu', '67'), { }
      // ('Share.cx', '12'), { }
      ('Share-online.biz', '9'), { }
      // ('Shragle.com', '6'), { }
      ('Terabit.to', '62'), { }
      ('Turbobit.net', '48'), { }
      ('Uload.to', '65'), { }
      ('Ultramegabit.info', '59'), { }
      ('Uploaded.net', '4'), { }
      ('Uploading.com', '26'), { }
      ('Usershare.net', '31'), { }
      // ('Wupload.com', '35'), { }
      // ('???', '31'), { }
      ('Venusfile.com', '70'), { }
      // ('X7.to', '7'), { }
      ('Zippyshare.com', '25') { }
    );
  var
    I: Integer;
  begin
    for I := 0 to length(HosterList) - 1 do
      if AnsiSameText(AHosterName, HosterList[I][0]) then
      begin
        Result := HosterList[I][1];
        break;
      end;
  end;

var
  Params: TStringList;
  Enc: TEncoding;
  ResponseStr: string;

  FormatSettings: TFormatSettings;

  I: Integer;
begin
  GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT, FormatSettings);
  FormatSettings.DecimalSeparator := '.';

  Result := False;
  with AIdHTTPHelper do
  begin
    Params := TStringList.Create;
    try
      with Params do
      begin
        Add('title=' + Subject);

        if Assigned(AComponentController.FindControl(cReleaseName)) then
          Add('release=' + AComponentController.FindControl(cReleaseName).Value);

        Add('category_id=' + VarToStr(_1loadNetSettings.categorys));

        Add('genre_id=' + VarToStr(_1loadNetSettings.genres));

        Add('format_id=' + VarToStr(_1loadNetSettings.formats));

        if Assigned(AComponentController.FindControl(cReleaseDate)) then
          Add('release_year=' + FormatDateTime('yyyy', StrToDateTimeDef(AComponentController.FindControl(cReleaseDate).Value, Now, FormatSettings),
              FormatSettings))
        else
          Add('release_year=' + FormatDateTime('yyyy', Now, FormatSettings));

        for I := 0 to AMirrorController.MirrorCount - 1 do
          if AMirrorController.Mirror[I].Size > 0 then
          begin
            if _1loadNetSettings.round_size then
              Add('size=' + IntToStr(round(AMirrorController.Mirror[I].Size)))
            else
              Add('size=' + FloatToStr(AMirrorController.Mirror[I].Size, FormatSettings));
            break;
          end;

        if Assigned(AComponentController.FindControl(cPicture)) then
          Add('cover_link=' + AComponentController.FindControl(cPicture).Value);

        Add('xrel_link=');

        if Assigned(AComponentController.FindControl(cSample)) then
          Add('sample=' + AComponentController.FindControl(cSample).Value);

        if Assigned(AComponentController.FindControl(cPassword)) then
          Add('password=' + AComponentController.FindControl(cPassword).Value);

        if Assigned(AComponentController.FindControl(cLanguage)) then
        begin
          if SameText('GER;ENG', AComponentController.FindControl(cLanguage).Value) then
            Add('language=Englisch-Deutsch')
          else if not(Pos(';', AComponentController.FindControl(cLanguage).Value) = 0) and
            (Pos('GER', string(AComponentController.FindControl(cLanguage).Value)) > 0) then
            Add('language=Multi inkl. Deutsch')
          else if not(Pos(';', AComponentController.FindControl(cLanguage).Value) = 0) then
            Add('language=Multi')
          else
            case IndexText(AComponentController.FindControl(cLanguage).Value, ['GER', 'ENG', 'SPA', 'JPN', 'FRE', 'ITA', 'RUS', 'TUR']) of
              0:
                Add('language=Deutsch');
              1:
                Add('language=Englisch');
              2:
                Add('language=Spanisch');
              3:
                Add('language=Japanisch');
              4:
                Add('language=Franz&ouml;sisch');
              5:
                Add('language=Italienisch');
              6:
                Add('language=Russisch');
              7:
                Add('language=T&uuml;rkisch');
            else
              Add('language=Unbekannt');
            end
        end
        else
          Add('language=Unbekannt');

        if not _1loadNetSettings.use_textasdescription then
        begin
          if Assigned(AComponentController.FindControl(cDescription)) then
            Add('description=' + AComponentController.FindControl(cDescription).Value);
        end
        else
          Add('description=' + Message);

        for I := 0 to AMirrorController.MirrorCount - 1 do
          if (Pos(string(AMirrorController.Mirror[I].Hoster), _1loadNetSettings.hoster_blacklist) = 0) then
            if (AMirrorController.Mirror[I].CrypterCount > 0) then
            begin
              Add('download_link[]=' + AMirrorController.Mirror[I].Crypter[0].Link);
              Add('hosters[]=' + convert_hosternames(AMirrorController.Mirror[I].Hoster));
              Add('status_image[]=' + AMirrorController.Mirror[I].Crypter[0].StatusImage);
              Add('members_only[]=0');
            end
            else
            begin
              ErrorMsg := 'No crypter initialized! (disable use_plainlinks or add a crypter)';
              Exit;
            end;

        Add('submit=Upload Eintragen');
      end;

      Request.CharSet := _1loadNetSettings.CharSet;
      Enc := CharsetToEncoding(Request.CharSet);
      try
        try
          ResponseStr := Post(Website + 'create-upload', Params, Enc);
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

      (*
        with TStringList.Create do
        try
        Text := ResponseStr;
        SaveToFile(ExtractFilePath(ParamStr(0)) + 'a.htm');
        finally
        Free;
        end;
        *)

      if not(Pos('class="error"', ResponseStr) = 0) then
      begin
        with TRegExpr.Create do
          try
            InputString := ResponseStr;

            if (Pos('div class="error"', ResponseStr) = 0) then
              Expression := 'class="error">(.*?)<\/'
            else
              Expression := 'class="error".*?<ul>(.*?)<\/ul>';

            if Exec(InputString) then
              Self.ErrorMsg := HTML2Text(Trim(Match[1]));
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

constructor T1loadNet.Create;
begin
  inherited Create;
  _1loadNetSettings := T1loadNetSettings.Create;
end;

destructor T1loadNet.Destroy;
begin
  _1loadNetSettings.Free;
  inherited Destroy;
end;

function T1loadNet.GetName: WideString;
begin
  Result := '1load.net';
end;

function T1loadNet.DefaultCharset: WideString;
begin
  Result := 'UTF-8';
end;

function T1loadNet.BelongsTo(AWebsiteSourceCode: WideString): Boolean;
begin
  Result := (Pos('action="/user/login"', string(AWebsiteSourceCode)) > 0) and (Pos('name="ident" value="Username"', string(AWebsiteSourceCode)) > 0);
end;

function T1loadNet.GetIDs: Integer;
begin
  Result := FCheckedIDsList.Count;
end;

function T1loadNet.ShowWebsiteSettingsEditor;
begin
  TPlugInCMSSettingsHelper.LoadSettingsToWebsiteEditor(SettingsFileName, T1loadNetSettings, AWebsiteEditor);
  Result := IsPositiveResult(AWebsiteEditor.ShowModal);
end;

end.
