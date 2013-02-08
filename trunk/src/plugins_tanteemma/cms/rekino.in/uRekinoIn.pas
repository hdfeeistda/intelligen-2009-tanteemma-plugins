unit uRekinoIn;

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
  TRekinoInSettings = class(TCMSFormbasedPlugInSettings)
  strict private
    fgenres: Variant;
  published
    [AttrDefaultValue(False)]
    property use_plainlinks;
    [AttrDefaultValue(False)]
    property use_textasdescription;

    property genres: Variant read fgenres write fgenres;
  end;

  TRekinoIn = class(TCMSFormbasedPlugIn)
  private
    RekinoInSettings: TRekinoInSettings;
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
    function Exec(ComponentController: IComponentController; MirrorController: IMirrorController): Boolean; override;
    function ShowWebsiteSettingsEditor(AWebsiteEditor: IWebsiteEditor): Boolean; override;
  end;

implementation

{ TRekinoIn }

function TRekinoIn.LoadSettings;
begin
  Result := True;
  TPlugInCMSSettingsHelper.LoadSettingsToClass(SettingsFileName, RekinoInSettings, AComponentController);
  with RekinoInSettings do
  begin
    if SameStr('', CharSet) then
      CharSet := DefaultCharset;

    if Assigned(AComponentController) and (genres = null) then
    begin
      ErrorMsg := 'genre is undefined!';
      Result := False;
    end;
  end;
end;

function TRekinoIn.Login(AIdHTTPHelper: TIdHTTPHelper): Boolean;
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
        Add('Username=' + AccountName);
        Add('Passwort=' + AccountPassword);
        Add('cookie=1');
        Add('submit=Login');
      end;

      Request.CharSet := RekinoInSettings.CharSet;
      Enc := CharsetToEncoding(Request.CharSet);
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

    if (Pos('http-equiv="refresh" content="1', ResponseStr) = 0) then
    begin
      with TRegExpr.Create do
        try
          InputString := ResponseStr;
          Expression := '<strong>(.*?)<';

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

function TRekinoIn.PostPage(AIdHTTPHelper: TIdHTTPHelper; AComponentController: IComponentController; AMirrorController: IMirrorController;
  APrevResponse: string): Boolean;

  function IsSeries(AReleaseName: string): Boolean;
  begin
    Result := MatchText('%.Staffel%', AReleaseName);

    with TRegExpr.Create do
      try
        InputString := AReleaseName;
        Expression := '\.S\d{2}E\d{2}\.';

        if Exec(InputString) then
          Result := True
        else
        begin
          Expression := '\.E\d{2}\.';

          if Exec(InputString) then
            Result := True;
        end;
      finally
        Free;
      end;
  end;

var
  Params: TStringList;
  Enc: TEncoding;
  ResponseStr: string;

  I, LanguageId, SeasonNo: Integer;
  _ReleaseName: string;
  _IsSeries: Boolean;
begin
  _ReleaseName := '';

  if Assigned(AComponentController.FindControl(cReleaseName)) then
    _ReleaseName := AComponentController.FindControl(cReleaseName).Value;

  if not(length(_ReleaseName) > 2) then
    _ReleaseName := 'n/a';

  _IsSeries := IsSeries(_ReleaseName) or MatchText('%.S??.%', _ReleaseName) or MatchText('%.HDTV.%', _ReleaseName) or MatchText('%.dTV.%', _ReleaseName);

  Result := False;
  with AIdHTTPHelper do
  begin
    Params := TStringList.Create;
    try
      with Params do
      begin
        Add('imdbid=' + Get(Website + 'iidcrawler.php?name=' + HTTPEncode(Subject) + '&ordner=' + RekinoInSettings.genres));

        if Assigned(AComponentController.FindControl(cPicture)) then
          Add('cover=' + AComponentController.FindControl(cPicture).Value)
        else
          Add('cover=&');

        Add('titel=' + Subject);
        Add('rtitel=' + _ReleaseName);

        if not RekinoInSettings.use_textasdescription and Assigned(AComponentController.FindControl(cDescription)) then
          Add('desc=' + AComponentController.FindControl(cDescription).Value)
        else
          Add('desc=' + Message);

        (*
          case ComponentController.TemplateTypeID of
          cMovie:
          begin
          if IsSeries then
          WriteString('cat=1&')
          else
          WriteString('cat=2&');
          end;
          cXXX:
          WriteString('cat=3&');
          end;
          *)

        Add('ordner=' + RekinoInSettings.genres);

        if _IsSeries then
        begin
          SeasonNo := 1;
          with TRegExpr.Create do
            try
              InputString := _ReleaseName;
              Expression := '\.S(\d+)';

              if Exec(InputString) then
                SeasonNo := StrToInt(Match[1])
              else
              begin
                Expression := '\.Staffel(\d+)';
                if Exec(InputString) then
                  SeasonNo := StrToInt(Match[1]);
              end;
            finally
              Free;
            end;
          Add('staffel=' + IntToStr(SeasonNo));
        end;

        Add('arts=1');

        // 1=DE; 2=EN; 3=MULTI
        if Assigned(AComponentController.FindControl(cLanguage)) then
        begin
          LanguageId := IndexText(AComponentController.FindControl(cLanguage).Value, ['GER', 'ENG']);
          if not(LanguageId = -1) then
            Add('lang=' + IntToStr(LanguageId + 1))
          else
            Add('lang=3');
        end
        else
          Add('lang=1');

        for I := 0 to AMirrorController.MirrorCount - 1 do
        begin
          if RekinoInSettings.use_plainlinks then
            Add('links[' + IntToStr(I + 1) + ']=' + AMirrorController.Mirror[I].DirectlinksMirror[0])
          else if (AMirrorController.Mirror[I].CrypterCount > 0) then
            Add('links[' + IntToStr(I + 1) + ']=' + AMirrorController.Mirror[I].Crypter[0].Link)
          else
          begin
            ErrorMsg := 'No crypter initialized! (disable use_plainlinks or add a crypter)';
            Exit;
          end;
          Add('hoster' + IntToStr(I + 1) + '=' + LowerCase(AMirrorController.Mirror[I].Hoster));
        end;

        Add('submit=Weiter');
      end;

      Request.CharSet := RekinoInSettings.CharSet;
      Enc := CharsetToEncoding(Request.CharSet);
      try
        try
          ResponseStr := Post(Website + 'acp/?a=upload06', Params, Enc);
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

      if (Pos('Erfolgreich Eingetragen', ResponseStr) = 0) then
      begin
        with TRegExpr.Create do
          try
            InputString := ResponseStr;
            Expression := 'style="width:600px;">(.*?)<\/fieldset>';

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

constructor TRekinoIn.Create;
begin
  inherited Create;
  RekinoInSettings := TRekinoInSettings.Create;
end;

destructor TRekinoIn.Destroy;
begin
  RekinoInSettings.Free;
  inherited Destroy;
end;

function TRekinoIn.GetName: WideString;
begin
  Result := 'rekino.in';
end;

function TRekinoIn.DefaultCharset: WideString;
begin
  Result := 'UTF-8';
end;

function TRekinoIn.BelongsTo(AWebsiteSourceCode: WideString): Boolean;
begin
  Result := False;
end;

function TRekinoIn.Exec(ComponentController: IComponentController; MirrorController: IMirrorController): Boolean;
var
  IdHTTPHelper: TIdHTTPHelper;
begin
  Result := False;

  if (ComponentController.TemplateTypeID in [cMovie, cXXX]) then
  begin
    IdHTTPHelper := TIdHTTPHelper.Create(Self);
    try
      if LoadSettings(ComponentController) then
        if (not SameStr('', AccountName) and Login(IdHTTPHelper)) xor SameStr('', AccountName) then
          Result := PostPage(IdHTTPHelper, ComponentController, MirrorController);
    finally
      IdHTTPHelper.Free;
    end;
  end
  else
    ErrorMsg := 'Only Movies and XXX allowed!';
end;

function TRekinoIn.GetIDs: Integer;
begin
  Result := FCheckedIDsList.Count;
end;

function TRekinoIn.ShowWebsiteSettingsEditor;
begin
  TPlugInCMSSettingsHelper.LoadSettingsToWebsiteEditor(SettingsFileName, TRekinoInSettings, AWebsiteEditor);
  Result := IsPositiveResult(AWebsiteEditor.ShowModal);
end;

end.
