#define VERSION "0.1.0"
#define BuildRoot "export\\windows\\bin"

[Setup]
AppId=STLGameLauncher
AppName=STLGameLauncher
AppVersion={#VERSION}
AppPublisher=STLGameDev
DefaultDirName={autopf}\STLGameLauncher
DefaultGroupName=STLGameLauncher
OutputDir=.\Builds
OutputBaseFilename=STLGameLauncher-Setup-v{#StringChange(VERSION, ".", "_")}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0.0
; Ensure the install location prompt is shown
; Do NOT set DisableDirPage=yes (leave it out or set to no)
DisableDirPage=no

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
Filename: "schtasks.exe"; Parameters: {code:GetTaskParams}; StatusMsg: "Registering kiosk auto-start..."; Flags: runhidden
Filename: "powershell.exe"; Parameters: "-Command ""Try {{ Get-ScheduledTask -TaskName 'STLGameLauncherKiosk' | Set-ScheduledTask -Settings (New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)) }} Catch {{ }}"""; StatusMsg: "Configuring kiosk task restart-on-failure..."; Flags: runhidden

[Code]
var
  PageOptions, PagePaths, PageUpdate: TWizardPage;
  RadioModeNormal, RadioModeKiosk: TRadioButton;
  EditIdleMenu, EditIdleGame: TEdit;
  EditContentRoot, EditLogsRoot: TEdit;
  CheckUpdateOnLaunch: TCheckBox;
  EditServerBase, EditSubscription: TEdit;

procedure InitializeWizard;
var
  L: TLabel;
begin
  // --- Options Page ---
  // Place after the default directory page so user sees install location prompt
  PageOptions := CreateCustomPage(wpSelectProgramGroup, 'Launcher Options', 'Set launcher mode and idle times');

  L := TLabel.Create(PageOptions);
  L.Parent := PageOptions.Surface;
  L.Caption := 'Select launcher mode:';
  L.Top := 8;
  L.Left := 0;
  L.Font.Style := [fsBold];

  RadioModeNormal := TRadioButton.Create(PageOptions);
  RadioModeNormal.Parent := PageOptions.Surface;
  RadioModeNormal.Caption := 'Normal mode';
  RadioModeNormal.Checked := True;
  RadioModeNormal.Top := L.Top + L.Height + 8;
  RadioModeNormal.Left := 16;

  RadioModeKiosk := TRadioButton.Create(PageOptions);
  RadioModeKiosk.Parent := PageOptions.Surface;
  RadioModeKiosk.Caption := 'Kiosk mode';
  RadioModeKiosk.Top := RadioModeNormal.Top + RadioModeNormal.Height + 8;
  RadioModeKiosk.Left := 16;

  L := TLabel.Create(PageOptions);
  L.Parent := PageOptions.Surface;
  L.Caption := 'Idle time before attract mode (menu):';
  L.Top := RadioModeKiosk.Top + RadioModeKiosk.Height + 16;
  L.Left := 0;

  EditIdleMenu := TEdit.Create(PageOptions);
  EditIdleMenu.Parent := PageOptions.Surface;
  EditIdleMenu.Top := L.Top + L.Height + 4;
  EditIdleMenu.Left := 16;
  EditIdleMenu.Width := 120;
  EditIdleMenu.Text := '180';

  L := TLabel.Create(PageOptions);
  L.Parent := PageOptions.Surface;
  L.Caption := 'Idle time before attract mode (in-game):';
  L.Top := EditIdleMenu.Top + EditIdleMenu.Height + 12;
  L.Left := 0;

  EditIdleGame := TEdit.Create(PageOptions);
  EditIdleGame.Parent := PageOptions.Surface;
  EditIdleGame.Top := L.Top + L.Height + 4;
  EditIdleGame.Left := 16;
  EditIdleGame.Width := 120;
  EditIdleGame.Text := '300';

  // --- Paths Page ---
  PagePaths := CreateCustomPage(PageOptions.ID, 'Paths', 'Where content and logs live');

  L := TLabel.Create(PagePaths);
  L.Parent := PagePaths.Surface;
  L.Caption := 'Content root (contains games/, trailers/, theme/):';
  L.Top := 8;
  L.Left := 0;

  EditContentRoot := TEdit.Create(PagePaths);
  EditContentRoot.Parent := PagePaths.Surface;
  EditContentRoot.Top := L.Top + L.Height + 4;
  EditContentRoot.Left := 16;
  EditContentRoot.Width := 320;
  EditContentRoot.Text := 'external';

  L := TLabel.Create(PagePaths);
  L.Parent := PagePaths.Surface;
  L.Caption := 'Logs root:';
  L.Top := EditContentRoot.Top + EditContentRoot.Height + 16;
  L.Left := 0;

  EditLogsRoot := TEdit.Create(PagePaths);
  EditLogsRoot.Parent := PagePaths.Surface;
  EditLogsRoot.Top := L.Top + L.Height + 4;
  EditLogsRoot.Left := 16;
  EditLogsRoot.Width := 320;
  EditLogsRoot.Text := 'logs';

  // --- Update/Server Page ---
  PageUpdate := CreateCustomPage(PagePaths.ID, 'Update & Server', 'Update and server settings');

  L := TLabel.Create(PageUpdate);
  L.Parent := PageUpdate.Surface;
  L.Caption := 'Update behavior:';
  L.Top := 8;
  L.Left := 0;

  CheckUpdateOnLaunch := TCheckBox.Create(PageUpdate);
  CheckUpdateOnLaunch.Parent := PageUpdate.Surface;
  CheckUpdateOnLaunch.Top := L.Top + L.Height + 4;
  CheckUpdateOnLaunch.Left := 16;
  CheckUpdateOnLaunch.Width := 400; // Increased width for clarity
  CheckUpdateOnLaunch.Caption := 'Check for updates at launch'; // Shorter caption to avoid truncation
  CheckUpdateOnLaunch.Checked := True;

  L := TLabel.Create(PageUpdate);
  L.Parent := PageUpdate.Surface;
  L.Caption := 'Subscription (e.g., arcade-jam-2018):';
  L.Top := CheckUpdateOnLaunch.Top + CheckUpdateOnLaunch.Height + 16;
  L.Left := 0;

  EditSubscription := TEdit.Create(PageUpdate);
  EditSubscription.Parent := PageUpdate.Surface;
  EditSubscription.Top := L.Top + L.Height + 4;
  EditSubscription.Left := 16;
  EditSubscription.Width := 320;
  EditSubscription.Text := 'arcade-jam-2018';

  L := TLabel.Create(PageUpdate);
  L.Parent := PageUpdate.Surface;
  L.Caption := 'Server base URL:';
  L.Top := EditSubscription.Top + EditSubscription.Height + 16;
  L.Left := 0;

  EditServerBase := TEdit.Create(PageUpdate);
  EditServerBase.Parent := PageUpdate.Surface;
  EditServerBase.Top := L.Top + L.Height + 4;
  EditServerBase.Left := 16;
  EditServerBase.Width := 320;
  EditServerBase.Text := 'https://sgd.axolstudio.com/';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  IniPath, Mode, Subscription, ContentRoot, LogsRoot, IdleMenu, IdleGame, UpdateOnLaunch, ServerBase, IniText: string;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    IniPath := ExpandConstant('{app}\settings.cfg');
    if RadioModeKiosk.Checked then Mode := 'kiosk' else Mode := 'normal';
    Subscription := Trim(EditSubscription.Text);
    if Subscription = '' then Subscription := 'arcade-jam-2018';
    ContentRoot := Trim(EditContentRoot.Text);
    if ContentRoot = '' then ContentRoot := ExpandConstant('{commonappdata}\STLGameLauncher\external');
    LogsRoot := Trim(EditLogsRoot.Text);
    if LogsRoot = '' then LogsRoot := ExpandConstant('{commonappdata}\STLGameLauncher\logs');
    IdleMenu := Trim(EditIdleMenu.Text); if IdleMenu = '' then IdleMenu := '180';
    IdleGame := Trim(EditIdleGame.Text); if IdleGame = '' then IdleGame := '300';
    if CheckUpdateOnLaunch.Checked then
      UpdateOnLaunch := 'true'
    else
      UpdateOnLaunch := 'false';
    ServerBase := Trim(EditServerBase.Text);
    if ServerBase = '' then ServerBase := 'https://sgd.axolstudio.com/';

    IniText :=
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
      'server_base = ' + ServerBase + #13#10;

    SaveStringToFile(IniPath, IniText, False);

    // Always create the task, but disable it if not kiosk mode
    if Mode <> 'kiosk' then
      Exec('schtasks.exe', '/Change /TN "STLGameLauncherKiosk" /DISABLE', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function GetTaskParams(Param: String): String;
begin
  Result := '/Create /F /RL HIGHEST /SC ONLOGON /TN "STLGameLauncherKiosk" /TR "' + ExpandConstant('{app}') + '\STLGameLauncher.exe"';
end;
