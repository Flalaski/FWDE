; FWDE Installer Script for Inno Setup
; Download Inno Setup from: https://jrsoftware.org/isdl.php

#define MyAppName "FWDE"
#define MyAppVersion "1.260309"
#define MyAppPublisher "FWDE Project"
#define MyAppURL "https://github.com/Flalaski/FWDE"
#define MyAppExeName "FWDE.exe"

[Setup]
; Application Info
AppId={{A3B2C1D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation Directories - User AppData
DefaultDirName={userappdata}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest

; Output Configuration
OutputDir=installer_output
OutputBaseFilename=FWDE_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes

; Modern UI
WizardStyle=modern
SetupIconFile=FWDEdesktop.png

; License and Info Pages
LicenseFile=LICENSE
InfoBeforeFile=README.rtf

; Uninstaller
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Run FWDE at Windows startup"; GroupDescription: "Startup Options:"; Flags: unchecked

[Files]
; Main executable
Source: "FWDE.exe"; DestDir: "{app}"; Flags: ignoreversion

; Configuration and data files
Source: "FWDE_Config.json"; DestDir: "{app}"; Flags: ignoreversion confirmoverwrite

; Layouts directory
Source: "Layouts\*"; DestDir: "{app}\Layouts"; Flags: ignoreversion recursesubdirs createallsubdirs

; Documentation
Source: "README.MD"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.rtf"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

; Icon (if exists)
Source: "FWDEdesktop.png"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu shortcut
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

; Desktop shortcut (optional, based on user selection)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; Startup shortcut (optional, based on user selection)
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
; Option to launch FWDE after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any generated files during uninstall
Type: filesandordirs; Name: "{app}\Layouts"
Type: files; Name: "{app}\FWDE_Config.json"

[Code]
// Check if FWDE is running before installation/uninstallation
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Check if FWDE is already running
  if CheckForMutexes('FWDE_Instance_Mutex') then
  begin
    if MsgBox('FWDE is currently running. It must be closed before installation can continue.' + #13#10#13#10 + 'Would you like Setup to close FWDE now?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Attempt to close FWDE gracefully
      if not Exec('taskkill', '/IM FWDE.exe /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        MsgBox('Failed to close FWDE. Please close it manually and run Setup again.', mbError, MB_OK);
        Result := False;
        Exit;
      end;
      Sleep(1000); // Give it time to close
    end
    else
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function InitializeUninstall(): Boolean;
var
  ResultCode: Integer;
begin
  // Check if FWDE is running during uninstall
  if CheckForMutexes('FWDE_Instance_Mutex') then
  begin
    if MsgBox('FWDE is currently running. It must be closed before uninstallation can continue.' + #13#10#13#10 + 'Would you like to close FWDE now?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      if not Exec('taskkill', '/IM FWDE.exe /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        MsgBox('Failed to close FWDE. Please close it manually and run uninstaller again.', mbError, MB_OK);
        Result := False;
        Exit;
      end;
      Sleep(1000);
    end
    else
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;
