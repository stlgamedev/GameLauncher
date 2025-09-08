
#define VERSION "0.1.0"
#define BuildRoot "C:\Builds\STLGameLauncher\windows\bin"

[Setup]
AppId=STLGameLauncher
AppName=STLGameLauncher
AppVersion={#VERSION}
AppPublisher=STLGameDev
DefaultDirName={autopf}\STLGameLauncher
DefaultGroupName=STLGameLauncher
OutputDir=.
OutputBaseFilename=STLGameLauncher-Setup-v{#StringChange(VERSION, ".", "_")}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0.0

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

[Code]
var
  PageOptions, PagePaths, PageUpdate: TWizardPage;
  RadioModeNormal, RadioModeKiosk: TRadioButton;
  EditIdleMenu, EditIdleGame: TEdit;
  EditContentRoot, EditLogsRoot: TEdit;
  CheckUpdateOnLaunch: TCheckBox;
  EditServerBase, EditSubscription: TEdit;

procedure InitializeWizard;
begin
  // --- Options Page ---
  PageOptions := CreateCustomPage(wpSelectDir, 'Launcher Options', 'Set launcher mode and idle times');
  RadioModeNormal := TRadioButton.Create(PageOptions);
  RadioModeNormal.Parent := PageOptions.Surface;
  RadioModeNormal.Caption := 'Normal mode';
  RadioModeNormal.Checked := True;
  RadioModeNormal.Top := 8;
  RadioModeNormal.Left := 0;

  RadioModeKiosk := TRadioButton.Create(PageOptions);
  RadioModeKiosk.Parent := PageOptions.Surface;
  RadioModeKiosk.Caption := 'Kiosk mode';
  RadioModeKiosk.Top := 32;
  RadioModeKiosk.Left := 0;

  EditIdleMenu := TEdit.Create(PageOptions);
  EditIdleMenu.Parent := PageOptions.Surface;
  EditIdleMenu.Top := 64;
  EditIdleMenu.Left := 0;
  EditIdleMenu.Width := 60;
  EditIdleMenu.Text := '180';

  EditIdleGame := TEdit.Create(PageOptions);
  EditIdleGame.Parent := PageOptions.Surface;
  EditIdleGame.Top := 64;
  EditIdleGame.Left := 80;
  EditIdleGame.Width := 60;
  EditIdleGame.Text := '300';

  // --- Paths Page ---
  PagePaths := CreateCustomPage(PageOptions.ID, 'Paths', 'Where content and logs live');
  EditContentRoot := TEdit.Create(PagePaths);
  EditContentRoot.Parent := PagePaths.Surface;
  EditContentRoot.Top := 8;
  EditContentRoot.Left := 0;
  EditContentRoot.Width := 300;
  EditContentRoot.Text := ExpandConstant('{commonappdata}\\STLGameLauncher\\external');

  EditLogsRoot := TEdit.Create(PagePaths);
  EditLogsRoot.Parent := PagePaths.Surface;
  EditLogsRoot.Top := 40;
  EditLogsRoot.Left := 0;
  EditLogsRoot.Width := 300;
  EditLogsRoot.Text := ExpandConstant('{commonappdata}\\STLGameLauncher\\logs');

  // --- Update/Server Page ---
  PageUpdate := CreateCustomPage(PagePaths.ID, 'Update & Server', 'Update and server settings');
  CheckUpdateOnLaunch := TCheckBox.Create(PageUpdate);
  CheckUpdateOnLaunch.Parent := PageUpdate.Surface;
  CheckUpdateOnLaunch.Top := 8;
  CheckUpdateOnLaunch.Left := 0;
  CheckUpdateOnLaunch.Width := 300;
  CheckUpdateOnLaunch.Caption := 'Check for updates when the application launches';
  CheckUpdateOnLaunch.Checked := True;

  EditSubscription := TEdit.Create(PageUpdate);
  EditSubscription.Parent := PageUpdate.Surface;
  EditSubscription.Top := 40;
  EditSubscription.Left := 0;
  EditSubscription.Width := 300;
  EditSubscription.Text := 'arcade-jam-2018';

  EditServerBase := TEdit.Create(PageUpdate);
  EditServerBase.Parent := PageUpdate.Surface;
  EditServerBase.Top := 72;
  EditServerBase.Left := 0;
  EditServerBase.Width := 300;
  EditServerBase.Text := 'https://sgd.axolstudio.com/';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  IniPath, Mode, Subscription, ContentRoot, LogsRoot, IdleMenu, IdleGame, UpdateOnLaunch, ServerBase, IniText: string;
begin
  if CurStep = ssPostInstall then
  begin
    IniPath := ExpandConstant('{app}\\settings.cfg');
    if RadioModeKiosk.Checked then Mode := 'kiosk' else Mode := 'normal';
    Subscription := Trim(EditSubscription.Text);
    if Subscription = '' then Subscription := 'arcade-jam-2018';
    ContentRoot := Trim(EditContentRoot.Text);
    if ContentRoot = '' then ContentRoot := ExpandConstant('{commonappdata}\\STLGameLauncher\\external');
    LogsRoot := Trim(EditLogsRoot.Text);
    if LogsRoot = '' then LogsRoot := ExpandConstant('{commonappdata}\\STLGameLauncher\\logs');
    IdleMenu := Trim(EditIdleMenu.Text); if IdleMenu = '' then IdleMenu := '180';
    IdleGame := Trim(EditIdleGame.Text); if IdleGame = '' then IdleGame := '300';
    UpdateOnLaunch := IfThen(CheckUpdateOnLaunch.Checked, 'true', 'false');
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
  end;
end;
