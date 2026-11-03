; FWDE installer

#define MyAppName "FWDE"
#define MyAppVersion "1.261102"
#define MyAppPublisher "Flalaski"
#define MyAppURL "https://flalaski.com"
#define MyAppExeName "FWDE.exe"

[Setup]
AppId={{43C9F2F3-DFFA-46AC-B8EE-E0C2F51B50E8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={userappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=License.rtf
InfoBeforeFile=README.rtf
UninstallDisplayIcon={app}\{#MyAppExeName}
; PrivilegesRequired=lowest keeps the INSTALLER itself unelevated: FWDE installs
; per-user into {userappdata}\FWDE and never writes HKLM, so no UAC prompt is
; needed to install. Elevation applies only to the RUNNING app (see the
; elevation wizard page + the RunAsAdmin setting), because Windows UIPI refuses
; every write (SetWindowPos/MoveWindow/SetWindowLongPtr -> ACCESS_DENIED) to
; windows owned by elevated processes.
PrivilegesRequired=lowest
OutputDir=installer_output
OutputBaseFilename=FWDE_Setup_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: exclusive
Name: "startup"; Description: "Run {#MyAppName} when I sign in"; GroupDescription: "Startup"; Flags: exclusive

[Dirs]
Name: "{app}\Layouts"

[Files]
Source: "{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Keep existing config during update so user settings are preserved.
Source: "FWDE_Config.json"; DestDir: "{app}"; Flags: onlyifdoesntexist
Source: "README.MD"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.rtf"; DestDir: "{app}"; Flags: ignoreversion
Source: "License.rtf"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "FWDEdesktop.png"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startup

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}} — Windows will ask for administrator rights (see the Administrator rights page)"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Layouts"; Check: ShouldRemoveUserData
Type: files; Name: "{app}\FWDE_Config.json"; Check: ShouldRemoveUserData

[CustomMessages]
ElevationPageCaption=Administrator rights
ElevationPageDescription=Why FWDE asks for elevation, and what it buys you
ElevationCheckCaption=Request administrator rights when FWDE starts (recommended)
ElevationFooter=You can change this later: Parameter Settings -> RunAsAdmin.

[Code]
var
	RemoveUserData: Boolean;
	ConfigExistedBefore: Boolean;
	ElevationCheckBox: TNewCheckBox;

{ The concise version of the "why admin?" explanation. The full breakdown lives
  in README.MD and in the app's Parameter Settings -> "Why admin?" dialog. }
function ElevationBodyText: String;
begin
	Result :=
		'Windows starts FWDE unelevated (Medium integrity). User Interface Privilege ' +
		'Isolation (UIPI) then blocks every WRITE to windows owned by an elevated ' +
		'(administrator) process - SetWindowPos, MoveWindow and SetWindowLongPtr all ' +
		'fail with Access Denied - while reads still succeed.' + #13#10 + #13#10 +
		'Without elevation those windows can be detected but never moved: Task Manager, ' +
		'Registry Editor, elevated terminals, anything started with "Run as ' +
		'administrator" (for example Notepad++ showing [Administrator] in its title), ' +
		'installers and MMC snap-ins.' + #13#10 + #13#10 +
		'Nothing else needs admin rights: no service, no driver, no machine-wide ' +
		'registry writes, and this installer stays per-user. The UAC prompt at launch ' +
		'is FWDE asking for the High-integrity token it needs in order to move those ' +
		'windows. Decline it and FWDE still runs - it simply leaves elevated windows ' +
		'alone and Ctrl+Alt+D reports exactly which ones are affected.' + #13#10 + #13#10 +
		'Full breakdown: README.MD, section "Administrator rights", or the ' +
		'"Why admin?" button in Parameter Settings.';
end;

procedure InitializeWizard;
var
	Page: TWizardPage;
	Body: TNewStaticText;
	Footer: TNewStaticText;
begin
	Page := CreateCustomPage(wpSelectTasks,
		CustomMessage('ElevationPageCaption'),
		CustomMessage('ElevationPageDescription'));

	Body := TNewStaticText.Create(Page);
	Body.Parent := Page.Surface;
	Body.Left := 0;
	Body.Top := 8;
	Body.Width := Page.SurfaceWidth;
	Body.AutoSize := False;
	Body.WordWrap := True;
	Body.Height := Page.SurfaceHeight - 60;
	Body.Caption := ElevationBodyText;

	ElevationCheckBox := TNewCheckBox.Create(Page);
	ElevationCheckBox.Parent := Page.Surface;
	ElevationCheckBox.Left := 0;
	ElevationCheckBox.Top := Body.Top + Body.Height + 8;
	ElevationCheckBox.Width := Page.SurfaceWidth;
	ElevationCheckBox.Caption := CustomMessage('ElevationCheckCaption');
	ElevationCheckBox.Checked := True;

	Footer := TNewStaticText.Create(Page);
	Footer.Parent := Page.Surface;
	Footer.Left := 0;
	Footer.Top := ElevationCheckBox.Top + 24;
	Footer.Width := Page.SurfaceWidth;
	Footer.AutoSize := False;
	Footer.WordWrap := True;
	Footer.Height := 20;
	Footer.Caption := CustomMessage('ElevationFooter');
end;

{ Record whether a config already exists BEFORE any files are copied, so the
  checkbox below only ever rewrites a config that this run installed. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
	ConfigExistedBefore := FileExists(ExpandConstant('{app}\FWDE_Config.json'));
	Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
	ConfigPath: String;
	Lines: TArrayOfString;
	I, Changed: Integer;
begin
	if CurStep = ssPostInstall then
	begin
		if ConfigExistedBefore then
			Log('Elevation: existing config preserved, RunAsAdmin left untouched')
		else if ElevationCheckBox.Checked then
			Log('Elevation: RunAsAdmin stays true (default)')
		else
		begin
			ConfigPath := ExpandConstant('{app}\FWDE_Config.json');
			if FileExists(ConfigPath) and LoadStringsFromFile(ConfigPath, Lines) then
			begin
				Changed := 0;
				for I := 0 to GetArrayLength(Lines) - 1 do
				begin
					Changed := Changed + StringChangeEx(Lines[I], '"RunAsAdmin": true',
						'"RunAsAdmin": false', True);
				end;
				if Changed > 0 then
				begin
					SaveStringsToFile(ConfigPath, Lines, False);
					Log('Elevation: RunAsAdmin set to false by installer choice');
				end
				else
					Log('Elevation: WARNING could not rewrite RunAsAdmin in FWDE_Config.json');
			end;
		end;
	end;
end;

function ShouldRemoveUserData: Boolean;
begin
	Result := RemoveUserData;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
	if CurUninstallStep = usUninstall then
	begin
		RemoveUserData :=
			MsgBox(
				'Remove FWDE user data (config and layouts)?',
				mbConfirmation,
				MB_YESNO
			) = IDYES;
	end;
end;

