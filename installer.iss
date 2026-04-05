; FWDE installer

#define MyAppName "FWDE"
#define MyAppVersion "1.260404"
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
UninstallDisplayIcon={app}\{#MyAppExeName}
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
Source: "License.rtf"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "FWDEdesktop.png"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startup

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Layouts"; Check: ShouldRemoveUserData
Type: files; Name: "{app}\FWDE_Config.json"; Check: ShouldRemoveUserData

[Code]
var
	RemoveUserData: Boolean;

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

