unit uSdxCc;

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
  TSdxCcSettings = class(TCMSFormbasedPlugInSettings)
  strict private
    fuse_defaultpassword, fround_size, fteam: Boolean;

    fsub_categorys: Variant;
  published
    [AttrDefaultValue(False)]
    property use_plainlinks;
    [AttrDefaultValue(False)]
    property use_textasdescription;

    [AttrDefaultValue(False)]
    property use_defaultpassword: Boolean read fuse_defaultpassword write fuse_defaultpassword;
    [AttrDefaultValue(False)]
    property round_size: Boolean read fround_size write fround_size;
    [AttrDefaultValue(False)]
    property team: Boolean read fteam write fteam;

    property categorys;
    property sub_categorys: Variant read fsub_categorys write fsub_categorys;
  end;

  TSdxCc = class(TCMSFormbasedPlugIn)
  private
    SdxCcSettings: TSdxCcSettings;
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

{ TSdxCc }

function TSdxCc.LoadSettings;
begin
  Result := True;
  TPlugInCMSSettingsHelper.LoadSettingsToClass(SettingsFileName, SdxCcSettings, AComponentController);
  with SdxCcSettings do
  begin
    if SameStr('', Charset) then
      Charset := DefaultCharset;

    if Assigned(AComponentController) then
    begin
      if (categorys = null) then
      begin
        ErrorMsg := 'category is undefined!';
        Result := False;
        Exit;
      end;

      if (sub_categorys = null) then
      begin
        ErrorMsg := 'sub_categorys is undefined!';
        Result := False;
      end;
    end;
  end;
end;

function TSdxCc.Login(AIdHTTPHelper: TIdHTTPHelper): Boolean;
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
        Add('user_name=' + AccountName);
        Add('user_pass=' + AccountPassword);
        Add('remember_me=y');
        Add('login=Login');
      end;

      Request.Charset := SdxCcSettings.Charset;
      Enc := CharsetToEncoding(Request.Charset);
      try
        try
          ResponseStr := Post(Website + '?p=login', Params, Enc);
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

    if (ResponseStr = '') then
    begin
      ErrorMsg := 'Accountname or Accountpassword is wrong.';

      Exit;
    end;

    try
      Get(Website + 'setuser.php?user=' + HTTPEncode(AccountName));
    except
      on E: Exception do
      begin
        ErrorMsg := E.message;
        Exit;
      end;
    end;

  end;
  Result := True;
end;

function TSdxCc.PostPage(AIdHTTPHelper: TIdHTTPHelper; AComponentController: IComponentController; AMirrorController: IMirrorController;
  APrevResponse: string): Boolean;

  function convert_hosternames(AHosterName: string): string;
  const
    HosterList: array [0 .. 23, 0 .. 1] of string = ( { }
      ('Rapidshare.com', '5'), { }
      ('SFT', '6'), { }
      ('Uploaded.to', '7'), { }
      ('Zippyshare.com', '9'), { }
      ('Netload.in', '10'), { }
      ('Zshare.net', '11'), { }
      ('Depositfiles.com', '19'), { }
      ('Filefactory.com', '22'), { }
      ('Fileserve.com', '23'), { }
      ('Mail.ru', '24'), { }
      ('Hotfile.com', '25'), { }
      ('Load.to', '26'), { }
      ('Megaupload.com', '27'), { }
      ('X7.to', '31'), { }
      ('Shragle.com', '33'), { }
      ('Filefrog.to', '38'), { }
      ('Share-online.biz', '39'), { }
      ('Filesonic.com', '42'), { }
      ('Kickload.com', '43'), { }
      ('Datei.to', '48'), { }
      ('Freakshare.com', '50'), { }
      ('Wupload.com', '51'), { }
      ('Ziddu.com', '54'), { }
      ('Hulkshare.com', '55') { }
    );
  var
    I: Integer;
  begin
    Result := '44';
    for I := 0 to length(HosterList) - 1 do
      if SameText(AHosterName, HosterList[I][0]) then
      begin
        Result := HosterList[I][1];
        break;
      end;
  end;

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
        Add('download_title=' + Subject);

        if SdxCcSettings.use_textasdescription or (not Assigned(AComponentController.FindControl(cDescription))) then
          Add('download_description=' + Message)
        else
          Add('download_description=' + AComponentController.FindControl(cDescription).Value);

        if Assigned(AComponentController.FindControl(cNFO)) then
          Add('download_nfo=' + AComponentController.FindControl(cNFO).Value);

        if Assigned(AComponentController.FindControl(cPicture)) then
          Add('download_image=' + AComponentController.FindControl(cPicture).Value);

        if Assigned(AComponentController.FindControl(cTrailer)) then
          Add('download_trailer=' + AComponentController.FindControl(cTrailer).Value);

        if Assigned(AComponentController.FindControl(cPassword)) and not SdxCcSettings.use_defaultpassword then
          Add('download_pass=' + AComponentController.FindControl(cPassword).Value)
        else
          Add('download_pass=sdx.cc');

        for I := 0 to AMirrorController.MirrorCount - 1 do
          if AMirrorController.Mirror[I].Size > 0 then
          begin
            if SdxCcSettings.round_size then
              Add('download_filesize=' + IntToStr(round(AMirrorController.Mirror[I].Size)))
            else
              Add('download_filesize=' + FloatToStr(AMirrorController.Mirror[I].Size));
            break;
          end;

        Add('download_cat=' + SdxCcSettings.categorys);
        Add('download_subcat=' + SdxCcSettings.sub_categorys);

        for I := 0 to AMirrorController.MirrorCount - 1 do
        begin
          if (I = 14) then
            break;

          if SdxCcSettings.use_plainlinks then
            Add('download_url[]=' + Trim(AMirrorController.Mirror[I].DirectlinksMirror[0]))
          else if (AMirrorController.Mirror[I].CrypterCount > 0) then
            Add('download_url[]=' + AMirrorController.Mirror[I].Crypter[0].Link)
          else
          begin
            ErrorMsg := 'No crypter initialized! (disable use_plainlinks or add a crypter)';
            Exit;
          end;
          Add('download_hoster[]=' + convert_hosternames(AMirrorController.Mirror[I].Hoster));
        end;

        Add('postreply=');
      end;

      Request.Charset := SdxCcSettings.Charset;
      Enc := CharsetToEncoding(Request.Charset);
      try
        try
          if SdxCcSettings.team then
            ResponseStr := Post(Website + 'submit.php?stype=d', Params, Enc)
          else
            ResponseStr := Post(Website + 'submit.php?stype=d&user=true', Params, Enc);
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

      // Response.RawHeaders.SaveToFile(ExtractFilePath(ParamStr(0)) + 'log.' + GetName + '.raw.txt');
      // Params.SaveToFile(ExtractFilePath(ParamStr(0)) + 'log.' + GetName + '.txt');
      // ReplyData.SaveToFile(ExtractFilePath(ParamStr(0)) + 'log.' + GetName + '.htm');

      if not(Pos('error-message', ResponseStr) = 0) then
      begin
        with TRegExpr.Create do
          try
            ModifierG := False;
            InputString := ResponseStr;
            Expression := 'error-message''>(.*?)<\/div>';

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

constructor TSdxCc.Create;
begin
  inherited Create;
  SdxCcSettings := TSdxCcSettings.Create;
end;

destructor TSdxCc.Destroy;
begin
  SdxCcSettings.Free;
  inherited Destroy;
end;

function TSdxCc.GetName: WideString;
begin
  Result := 'sdx.cc';
end;

function TSdxCc.DefaultCharset: WideString;
begin
  Result := 'ISO-8859-1';
end;

function TSdxCc.BelongsTo(AWebsiteSourceCode: WideString): Boolean;
begin
  Result := False;
end;

function TSdxCc.GetIDs: Integer;
begin
  Result := FCheckedIDsList.Count;
end;

function TSdxCc.ShowWebsiteSettingsEditor;
begin
  TPlugInCMSSettingsHelper.LoadSettingsToWebsiteEditor(SettingsFileName, TSdxCcSettings, AWebsiteEditor);
  Result := IsPositiveResult(AWebsiteEditor.ShowModal);
end;

end.
