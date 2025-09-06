; ============================================================
; STLGameLauncher - Inno Setup Script
; - Reads app version from built EXE
; - Installs launcher to {app}
; - Writes settings.cfg (if missing) using simple wizard inputs
; - Adds a "Check for Updates" shortcut that runs the launcher with --update
; - Copies build output from a fixed folder
; ============================================================

#define BuildRoot  "C:\ProjectBuilds\STLGameLauncher\windows\bin"
#define AppExe     BuildRoot + "\STLGameLauncher.exe"
#define VerFull    GetFileVersion(AppExe)                 ; e.g. "1.0.0.0"
#define VerShort   Copy(VerFull, 1, RPos(".", VerFull)-1) ; e.g. "1.0.0"
#define VerUnd     StringChange(VerShort, ".", "_")       ; e.g. "1_0_0"

[Setup]
AppId=STLGameLauncher
AppName=STLGameLauncher
AppVersion={#VerShort}
AppPublisher=STLGameDev
DefaultDirName={autopf}\STLGameLauncher
DefaultGroupName=STLGameLauncher
OutputDir=.
OutputBaseFilename=STLGameLauncher-Setup-v{#VerUnd}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\STLGameLauncher"; Filename: "{app}\STLGameLauncher.exe"
Name: "{group}\Check for Updates"; Filename: "{app}\STLGameLauncher.exe"; Parameters: "--update"
Name: "{autodesktop}\STLGameLauncher"; Filename: "{app}\STLGameLauncher.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\STLGameLauncher.exe"; Description: "Launch STLGameLauncher"; Flags: nowait postinstall skipifsilent

; ----------------------- Custom Wizard Pages -----------------------
[Code]
var
  PageGeneral: TWizardPage;
  PagePaths: TWizardPage;
  PageUpdate: TWizardPage;
  PageServer: TWizardPage;

  RadioModeNormal, RadioModeKiosk: TRadioButton;
  EditSubscription: TEdit;

  EditContentRoot, EditLogsRoot: TEdit;
  BtnContentBrowse, BtnLogsBrowse: TButton;

  EditIdleMenu, EditIdleGame: TEdit;

  CheckUpdateOnLaunch: TCheckBox;

  EditServerBase: TEdit;

function DirBrowse(const Prompt: string; const Initial: string): string;
begin
  Result := '';
  if BrowseForFolder(WizardForm.Handle, Prompt, Initial, Result) then
  begin
    // nothing
  end;
end;

procedure InitializeWizard;
var
  L: TNewStaticText;
begin
  { General page }
  PageGeneral := CreateCustomPage(wpSelectTasks, 'General', 'Basic launcher options');

  L := TNewStaticText.Create(PageGeneral);
  L.Parent := PageGeneral.Surface;
  L.Caption := 'Mode:';
  L.Left := ScaleX(0);
  L.Top := ScaleY(8);

  RadioModeNormal := TRadioButton.Create(PageGeneral);
  RadioModeNormal.Parent := PageGeneral.Surface;
  RadioModeNormal.Caption := 'normal';
  RadioModeNormal.Left := ScaleX(80);
  RadioModeNormal.Top := ScaleY(6);
  RadioModeNormal.Checked := True;

  RadioModeKiosk := TRadioButton.Create(PageGeneral);
  RadioModeKiosk.Parent := PageGeneral.Surface;
  RadioModeKiosk.Caption := 'kiosk';
  RadioModeKiosk.Left := ScaleX(160);
  RadioModeKiosk.Top := ScaleY(6);

  L := TNewStaticText.Create(PageGeneral);
  L.Parent := PageGeneral.Surface;
  L.Caption := 'Subscription (e.g., arcade-jam-2018):';
  L.Left := ScaleX(0);
  L.Top := ScaleY(36);

  EditSubscription := TEdit.Create(PageGeneral);
  EditSubscription.Parent := PageGeneral.Surface;
  EditSubscription.Left := ScaleX(0);
  EditSubscription.Top := ScaleY(54);
  EditSubscription.Width := ScaleX(320);
  EditSubscription.Text := 'default';

  L := TNewStaticText.Create(PageGeneral);
  L.Parent := PageGeneral.Surface;
  L.Caption := 'Idle (seconds) — Menu / Game:';
  L.Left := ScaleX(0);
  L.Top := ScaleY(88);

  EditIdleMenu := TEdit.Create(PageGeneral);
  EditIdleMenu.Parent := PageGeneral.Surface;
  EditIdleMenu.Left := ScaleX(0);
  EditIdleMenu.Top := ScaleY(106);
  EditIdleMenu.Width := ScaleX(70);
  EditIdleMenu.Text := '180';

  EditIdleGame := TEdit.Create(PageGeneral);
  EditIdleGame.Parent := PageGeneral.Surface;
  EditIdleGame.Left := ScaleX(80);
  EditIdleGame.Top := ScaleY(106);
  EditIdleGame.Width := ScaleX(70);
  EditIdleGame.Text := '300';

  { Paths page }
  PagePaths := CreateCustomPage(PageGeneral.ID, 'Paths', 'Where content and logs live');

  L := TNewStaticText.Create(PagePaths);
  L.Parent := PagePaths.Surface;
  L.Caption := 'Content root (contains games/, trailers/, themes/):';
  L.Left := ScaleX(0);
  L.Top := ScaleY(8);

  EditContentRoot := TEdit.Create(PagePaths);
  EditContentRoot.Parent := PagePaths.Surface;
  EditContentRoot.Left := ScaleX(0);
  EditContentRoot.Top := ScaleY(26);
  EditContentRoot.Width := ScaleX(360);
  EditContentRoot.Text := ExpandConstant('{commonappdata}\STLGameLauncher\external');

  BtnContentBrowse := TButton.Create(PagePaths);
  BtnContentBrowse.Parent := PagePaths.Surface;
  BtnContentBrowse.Left := EditContentRoot.Left + EditContentRoot.Width + ScaleX(8);
  BtnContentBrowse.Top := EditContentRoot.Top;
  BtnContentBrowse.Caption := 'Browse...';
  BtnContentBrowse.OnClick := @OnBrowseContent;

  L := TNewStaticText.Create(PagePaths);
  L.Parent := PagePaths.Surface;
  L.Caption := 'Logs root:';
  L.Left := ScaleX(0);
  L.Top := ScaleY(64);

  EditLogsRoot := TEdit.Create(PagePaths);
  EditLogsRoot.Parent := PagePaths.Surface;
  EditLogsRoot.Left := ScaleX(0);
  EditLogsRoot.Top := ScaleY(82);
  EditLogsRoot.Width := ScaleX(360);
  EditLogsRoot.Text := ExpandConstant('{commonappdata}\STLGameLauncher\logs');

  BtnLogsBrowse := TButton.Create(PagePaths);
  BtnLogsBrowse.Parent := PagePaths.Surface;
  BtnLogsBrowse.Left := EditLogsRoot.Left + EditLogsRoot.Width + ScaleX(8);
  BtnLogsBrowse.Top := EditLogsRoot.Top;
  BtnLogsBrowse.Caption := 'Browse...';
  BtnLogsBrowse.OnClick := @OnBrowseLogs;

  { Update page }
  PageUpdate := CreateCustomPage(PagePaths.ID, 'Updates', 'Update behavior');

  CheckUpdateOnLaunch := TCheckBox.Create(PageUpdate);
  CheckUpdateOnLaunch.Parent := PageUpdate.Surface;
  CheckUpdateOnLaunch.Left := ScaleX(0);
  CheckUpdateOnLaunch.Top := ScaleY(8);
  CheckUpdateOnLaunch.Caption := 'Check for updates on application launch';
  CheckUpdateOnLaunch.Checked := False;

  { Server page }
  PageServer := CreateCustomPage(PageUpdate.ID, 'Server', 'Server base URL');

  L := TNewStaticText.Create(PageServer);
  L.Parent := PageServer.Surface;
  L.Caption := 'Server base (contains per-subscription folders):';
  L.Left := ScaleX(0);
  L.Top := ScaleY(8);

  EditServerBase := TEdit.Create(PageServer);
  EditServerBase.Parent := PageServer.Surface;
  EditServerBase.Left := ScaleX(0);
  EditServerBase.Top := ScaleY(26);
  EditServerBase.Width := ScaleX(420);
  EditServerBase.Text := 'https://sgd.axolstudio.com/';
end;

procedure OnBrowseContent(Sender: TObject);
var S: string;
begin
  S := DirBrowse('Select content root (with games/, trailers/, themes/)', EditContentRoot.Text);
  if S <> '' then EditContentRoot.Text := S;
end;

procedure OnBrowseLogs(Sender: TObject);
var S: string;
begin
  S := DirBrowse('Select logs root', EditLogsRoot.Text);
  if S <> '' then EditLogsRoot.Text := S;
end;

function StrTrim(const S: string): string;
begin
  Result := Trim(S);
end;

function BoolStr(B: Boolean): string;
begin
  if B then Result := 'true' else Result := 'false';
end;

function BuildIni(
  const Mode, Subscription, ContentRoot, LogsRoot, IdleMenu, IdleGame,
  UpdateOnLaunch, ServerBase: string;
  const KeysPrev, KeysNext, KeysSelect, KeysBack, KeysAdmin: string;
  const PadsPrev, PadsNext, PadsSelect, PadsBack, PadsAdmin: string
): string;
var
  S: string;
begin
  S :=
    '; ==========================================================='#13#10 +
    '; STLGameLauncher Settings'#13#10 +
    '; (generated by installer)'#13#10 +
    '; ==========================================================='#13#10#13#10 +

    '[General]'#13#10 +
    'mode = ' + Mode + #13#10 +
    'subscription = ' + Subscription + #13#10 +
    'idle_seconds_menu = ' + IdleMenu + #13#10 +
    'idle_seconds_game = ' + IdleGame + #13#10#13#10 +

    '[Paths]'#13#10 +
    'content_root = ' + ContentRoot + #13#10 +
    'logs_root = ' + LogsRoot + #13#10#13#10 +

    '[Update]'#13#10 +
    'update_on_launch = ' + UpdateOnLaunch + #13#10 +
    'server_base = ' + ServerBase + #13#10#13#10 +

    '[Controls.Keys]'#13#10 +
    'prev = ' + KeysPrev + #13#10 +
    'next = ' + KeysNext + #13#10 +
    'select = ' + KeysSelect + #13#10 +
    'back = ' + KeysBack + #13#10 +
    'admin_exit = ' + KeysAdmin + #13#10#13#10 +

    '[Controls.Pads]'#13#10 +
    'prev = ' + PadsPrev + #13#10 +
    'next = ' + PadsNext + #13#10 +
    'select = ' + PadsSelect + #13#10 +
    'back = ' + PadsBack + #13#10 +
    'admin_exit = ' + PadsAdmin + #13#10;

  Result := S;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  IniPath: string;
  Mode, Subscription, ContentRoot, LogsRoot: string;
  IdleMenu, IdleGame: string;
  UpdateOnLaunch, ServerBase: string;
  IniText: string;
begin
  if CurStep = ssInstall then
  begin
    IniPath := ExpandConstant('{app}\settings.cfg');

    if not FileExists(IniPath) then
    begin
      // Collect values
      if RadioModeKiosk.Checked then Mode := 'kiosk' else Mode := 'normal';
      Subscription := StrTrim(EditSubscription.Text);

      ContentRoot := StrTrim(EditContentRoot.Text);
      if ContentRoot = '' then ContentRoot := ExpandConstant('{commonappdata}\STLGameLauncher\external');

      LogsRoot := StrTrim(EditLogsRoot.Text);
      if LogsRoot = '' then LogsRoot := ExpandConstant('{commonappdata}\STLGameLauncher\logs');

      IdleMenu := StrTrim(EditIdleMenu.Text);
      if IdleMenu = '' then IdleMenu := '180';
      IdleGame := StrTrim(EditIdleGame.Text);
      if IdleGame = '' then IdleGame := '300';

      UpdateOnLaunch := BoolStr(CheckUpdateOnLaunch.Checked);

      ServerBase := StrTrim(EditServerBase.Text);
      if ServerBase = '' then ServerBase := 'https://sgd.axolstudio.com/';

      // Default control mappings (match Config defaults; admin can edit later)
      IniText := BuildIni(
        Mode, Subscription, ContentRoot, LogsRoot, IdleMenu, IdleGame,
        UpdateOnLaunch, ServerBase,
        'left, a', 'right, d', 'enter, space, comma, slash', 'escape', 'shift+f12',
        'pad_left', 'pad_right', 'pad_a, pad_start', 'pad_select', ''
      );

      if SaveStringToFile(IniPath, IniText, False) then
      begin
        // also ensure content/logs dirs exist
        if not DirExists(ContentRoot) then ForceDirectories(ContentRoot);
        if not DirExists(LogsRoot) then ForceDirectories(LogsRoot);
      end;
    end;
  end;
end;
