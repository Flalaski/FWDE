# Building the FWDE Installer

This guide explains how to create a Windows installer for FWDE that installs to user AppData and includes an uninstaller.

## Prerequisites

1. **Inno Setup Compiler** (free)
   - Download from: https://jrsoftware.org/isdl.php
   - Install the latest version (includes the IDE and compiler)

2. **Compiled FWDE.exe**
   - Already present in the project
   - To recompile: Right-click FWDE.ahk → "Compile Script" (requires AHK v2)

## Building the Installer

### Method 1: Using Inno Setup IDE (Easy)

1. Open **Inno Setup Compiler**
2. Open the file `installer.iss`
3. Click **Build → Compile** (or press Ctrl+F9)
4. The installer will be created in `installer_output/FWDE_Setup_1.0.0.exe`

### Method 2: Command Line (For Automation)

```powershell
# Using the Inno Setup compiler from command line
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

## What the Installer Does

### Installation
- ✅ Installs FWDE to `%AppData%\FWDE` (no admin rights needed)
- ✅ Creates Start Menu shortcut
- ✅ Optional: Desktop shortcut
- ✅ Optional: Run at Windows startup
- ✅ Preserves user config during updates
- ✅ Includes all necessary files (exe, config, layouts, docs)

### Uninstallation
- ✅ Automatically added to Windows "Add/Remove Programs"
- ✅ Checks if FWDE is running and closes it gracefully
- ✅ Removes all installed files and shortcuts
- ✅ Cleans up user data (optional prompt can be added)

## Installation Locations

| Item | Path |
|------|------|
| **Main App** | `%AppData%\FWDE\` |
| **Config** | `%AppData%\FWDE\FWDE_Config.json` |
| **Layouts** | `%AppData%\FWDE\Layouts\` |
| **Shortcuts** | `%AppData%\Microsoft\Windows\Start Menu\Programs\` |
| **Startup** | `%AppData%\Microsoft\Windows\Start Menu\Programs\Startup\` (if selected) |

## Customizing the Installer

### Changing Version Number
Edit line 5 in `installer.iss`:
```pascal
#define MyAppVersion "1.0.0"  ; Change this
```

### Changing Publisher/URL
Edit lines 6-7 in `installer.iss`:
```pascal
#define MyAppPublisher "Your Name"
#define MyAppURL "https://github.com/yourusername/FWDE"
```

### Adding More Files
Add entries to the `[Files]` section:
```pascal
Source: "MyFile.txt"; DestDir: "{app}"; Flags: ignoreversion
```

### Changing Default Options
In the `[Tasks]` section, remove `Flags: unchecked` to enable by default:
```pascal
Name: "desktopicon"; Description: "Create desktop icon"; Flags: unchecked ; Remove this flag to check by default
```

## Testing the Installer

1. **Build the installer** using one of the methods above
2. **Test installation:**
   - Run `FWDE_Setup_1.0.0.exe`
   - Follow the wizard
   - Verify files are in `%AppData%\FWDE`
   - Launch FWDE from Start Menu

3. **Test uninstallation:**
   - Go to Windows Settings → Apps → Installed apps
   - Find "FWDE" and click Uninstall
   - Verify all files are removed

## Advanced: Automated Build Script

Create `build.ps1` for automated builds:

```powershell
# Build FWDE Installer
$InnoSetup = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$ScriptFile = "installer.iss"

Write-Host "Building FWDE Installer..." -ForegroundColor Cyan

if (Test-Path $InnoSetup) {
    & $InnoSetup $ScriptFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Installer built successfully!" -ForegroundColor Green
        Write-Host "Output: installer_output\FWDE_Setup_1.0.0.exe" -ForegroundColor Green
    } else {
        Write-Host "✗ Build failed!" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Inno Setup not found at: $InnoSetup" -ForegroundColor Red
}
```

## Distribution

Once built, distribute `FWDE_Setup_1.0.0.exe`:
- Upload to GitHub Releases
- Share via direct download
- No installation necessary for end users to run the setup

## Troubleshooting

**"File not found" during compilation**
- Ensure all files referenced in `[Files]` section exist
- Check that FWDE.exe is compiled and present

**"Access denied" during installation**
- The installer uses `%AppData%` which doesn't require admin rights
- Verify `PrivilegesRequired=lowest` is set in installer.iss

**Config file gets overwritten on update**
- The `confirmoverwrite` flag prompts users before overwriting
- Consider using `onlyifdoesntexist` flag for first-time installs

## Next Steps

- Add digital signature for trusted installer (optional, requires code signing certificate)
- Create auto-update mechanism
- Add silent install mode: `FWDE_Setup.exe /SILENT`
