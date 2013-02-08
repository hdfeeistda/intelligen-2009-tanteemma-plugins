unit u1loadNet;

interface

uses
  // Delphi
  Windows, SysUtils, StrUtils,  Variants,
  // RegEx
  RegExpr,
  // Utils,
  uHTMLUtils,
  // Common
  uConst, uWebsiteInterface,
  // HTTPManager
  uHTTPInterface, uHTTPClasses,
  // Plugin system
  uPlugInCMSClass, uPlugInCMSFormbasedClass, uPlugInHTTPClasses;

type

  T1loadNetSettings = class(TCMSFormbasedPlugInSettings)
  strict private
    fround_size: Boolean;

    fgenres, fformats: Variant;
  published
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
    function SettingsClass: TCMSPlugInSettingsMeta; override;
    function GetSettings: TCMSPlugInSettings; override;
    procedure SetSettings(ACMSPlugInSettings: TCMSPlugInSettings); override;
    function LoadSettings(const AWebsiteData: ICMSWebsiteData = nil): Boolean; override;

    function DoBuildLoginRequest(out AHTTPRequest: IHTTPRequest; out AHTTPParams: IHTTPParams; out AHTTPOptions: IHTTPOptions; APrevResponse: string;
      ACAPTCHALogin: Boolean = False): Boolean; override;
    function DoAnalyzeLogin(AResponseStr: string; out ACAPTCHALogin: Boolean): Boolean; override;

    function DoBuildPostRequest(const AWebsiteData: ICMSWebsiteData; out AHTTPRequest: IHTTPRequest; out AHTTPParams: IHTTPParams;
      out AHTTPOptions: IHTTPOptions; APrevResponse: string; APrevRequest: Double): Boolean; override;
    function DoAnalyzePost(AResponseStr: string; AHTTPProcess: IHTTPProcess): Boolean; override;
  public
    function GetName: WideString; override; safecall;
    function DefaultCharset: WideString; override;
    function BelongsTo(AWebsiteSourceCode: WideString): WordBool; override;
  end;

implementation

{ T1loadNet }

function T1loadNet.SettingsClass: TCMSPlugInSettingsMeta;
begin
  Result := T1loadNetSettings;
end;

function T1loadNet.GetSettings;
begin
  Result := _1loadNetSettings;
end;

procedure T1loadNet.SetSettings;
begin
  _1loadNetSettings := ACMSPlugInSettings as T1loadNetSettings;
end;

function T1loadNet.LoadSettings;
begin
  Result := inherited LoadSettings(AWebsiteData);
  with _1loadNetSettings do
  begin
    if SameStr('', CharSet) then
      CharSet := DefaultCharset;

    if Assigned(AWebsiteData) and (categorys = null) then
    begin
      ErrorMsg := 'category is undefined!';
      Result := False;
    end;
  end;
end;

function T1loadNet.DoBuildLoginRequest;
begin
  Result := True;

  AHTTPRequest := THTTPRequest.Create(Website + 'user/login');
  with AHTTPRequest do
  begin
    Referer := Website;
    CharSet := _1loadNetSettings.CharSet;
  end;

  AHTTPParams := THTTPParams.Create;
  with AHTTPParams do
  begin
    AddFormField('ident', AccountName);
    AddFormField('password', AccountPassword);
    AddFormField('go', 'GO!');
  end;

  AHTTPOptions := TPlugInHTTPOptions.Create(Self);
  with AHTTPOptions do
  begin
    RedirectMaximum := 1;
  end;
end;

function T1loadNet.DoAnalyzeLogin;
begin
  ACAPTCHALogin := False;
  Result := not(Pos('/user/logout', AResponseStr) = 0) and (AResponseStr = '');
  if not Result then
    with TRegExpr.Create do
      try
        InputString := AResponseStr;
        Expression := 'class="error">(.*?)<\/p>';

        if Exec(InputString) then
          Self.ErrorMsg := Trim(HTML2Text(Match[1]));
      finally
        Free;
      end;
end;

function T1loadNet.DoBuildPostRequest;

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
    Result := '';
    for I := 0 to length(HosterList) - 1 do
      if SameText(AHosterName, HosterList[I][0]) then
      begin
        Result := HosterList[I][1];
        break;
      end;
  end;

var
  I: Integer;

  FormatSettings: TFormatSettings;
begin
  Result := True;

  GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT, FormatSettings);
  FormatSettings.DecimalSeparator := '.';

  AHTTPRequest := THTTPRequest.Create(Website + 'create-upload');
  with AHTTPRequest do
  begin
    Referer := Website;
    CharSet := _1loadNetSettings.CharSet;
  end;

  AHTTPParams := THTTPParams.Create;
  with AHTTPParams do
  begin
    AddFormField('title', Subject);

    if Assigned(AWebsiteData.FindControl(cReleaseName)) then
      AddFormField('release', AWebsiteData.FindControl(cReleaseName).Value);

    AddFormField('category_id', VarToStr(_1loadNetSettings.categorys));

    AddFormField('genre_id', VarToStr(_1loadNetSettings.genres));

    AddFormField('format_id', VarToStr(_1loadNetSettings.formats));

    if Assigned(AWebsiteData.FindControl(cReleaseDate)) then
      AddFormField('release_year', FormatDateTime('yyyy', StrToDateTimeDef(AWebsiteData.FindControl(cReleaseDate).Value, Now, FormatSettings), FormatSettings))
    else
      AddFormField('release_year', FormatDateTime('yyyy', Now, FormatSettings));

    for I := 0 to AWebsiteData.MirrorCount - 1 do
      if AWebsiteData.Mirror[I].Size > 0 then
      begin
        if _1loadNetSettings.round_size then
          AddFormField('size', IntToStr(round(AWebsiteData.Mirror[I].Size)))
        else
          AddFormField('size', FloatToStr(AWebsiteData.Mirror[I].Size, FormatSettings));
        break;
      end;

    if Assigned(AWebsiteData.FindControl(cPicture)) then
      AddFormField('cover_link', AWebsiteData.FindControl(cPicture).Value);

    AddFormField('xrel_link', '');

    if Assigned(AWebsiteData.FindControl(cSample)) then
      AddFormField('sample', AWebsiteData.FindControl(cSample).Value);

    if Assigned(AWebsiteData.FindControl(cPassword)) then
      AddFormField('password', AWebsiteData.FindControl(cPassword).Value);

    if Assigned(AWebsiteData.FindControl(cLanguage)) then
    begin
      if SameText('GER;ENG', AWebsiteData.FindControl(cLanguage).Value) then
        AddFormField('language', 'Englisch-Deutsch')
      else if not(Pos(';', AWebsiteData.FindControl(cLanguage).Value) = 0) and (Pos('GER', string(AWebsiteData.FindControl(cLanguage).Value)) > 0) then
        AddFormField('language', 'Multi inkl. Deutsch')
      else if not(Pos(';', AWebsiteData.FindControl(cLanguage).Value) = 0) then
        AddFormField('language', 'Multi')
      else
        case IndexText(AWebsiteData.FindControl(cLanguage).Value, ['GER', 'ENG', 'SPA', 'JPN', 'FRE', 'ITA', 'RUS', 'TUR']) of
          0:
            AddFormField('language', 'Deutsch');
          1:
            AddFormField('language', 'Englisch');
          2:
            AddFormField('language', 'Spanisch');
          3:
            AddFormField('language', 'Japanisch');
          4:
            AddFormField('language', 'Franz&ouml;sisch');
          5:
            AddFormField('language', 'Italienisch');
          6:
            AddFormField('language', 'Russisch');
          7:
            AddFormField('language', 'T&uuml;rkisch');
        else
          AddFormField('language', 'Unbekannt');
        end
    end
    else
      AddFormField('language', 'Unbekannt');

    if not _1loadNetSettings.use_textasdescription then
    begin
      if Assigned(AWebsiteData.FindControl(cDescription)) then
        AddFormField('description', AWebsiteData.FindControl(cDescription).Value);
    end
    else
      AddFormField('description', Message);

    for I := 0 to AWebsiteData.MirrorCount - 1 do
      if (AWebsiteData.Mirror[I].CrypterCount > 0) then
      begin
        AddFormField('download_link[]', AWebsiteData.Mirror[I].Crypter[0].Value);
        AddFormField('hosters[]', convert_hosternames(AWebsiteData.Mirror[I].Hoster));
        AddFormField('status_image[]', AWebsiteData.Mirror[I].Crypter[0].StatusImage);
        AddFormField('members_only[]', '0');
      end
      else
      begin
        ErrorMsg := 'No crypter initialized! (disable use_plainlinks or add a crypter)';
        Exit;
      end;

    AddFormField('submit', 'Upload Eintragen');
  end;

  AHTTPOptions := TPlugInHTTPOptions.Create(Self);
end;

function T1loadNet.DoAnalyzePost;
begin
  Result := (Pos('class="error"', AResponseStr) = 0);
  if not Result then
    with TRegExpr.Create do
      try
        InputString := AResponseStr;
        if (Pos('div class="error"', AResponseStr) = 0) then
          Expression := 'class="error">(.*?)<\/'
        else
          Expression := 'class="error".*?<ul>(.*?)<\/ul>';

        if Exec(InputString) then
          Self.ErrorMsg := HTML2Text(Trim(Match[1]));
      finally
        Free;
      end;
end;

function T1loadNet.GetName;
begin
  Result := '1load.net';
end;

function T1loadNet.DefaultCharset;
begin
  Result := 'UTF-8';
end;

function T1loadNet.BelongsTo;
begin
  Result := (Pos('action="/user/login"', string(AWebsiteSourceCode)) > 0) and (Pos('name="ident" value="Username"', string(AWebsiteSourceCode)) > 0);
end;

end.
