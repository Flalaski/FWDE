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

### Version bump

`update_installer_version.bat` sets `MyAppVersion` in `installer.iss` to
`1.<yyMMdd>` (today's date); that value also drives `OutputBaseFilename`
(`FWDE_Setup_<version>.exe`) and the version shown in Apps & Features.

`installer.iss` is **UTF-8 without a BOM** and deliberately contains non-ASCII
text (the em dash in the `[Run]` description), so the script reads and writes it
as UTF-8 and then verifies that the new version landed *and* that the non-ASCII
character count is unchanged.

> Do not reintroduce `Set-Content -Encoding Ascii` (or any ASCII round-trip) in
> that script. It rewrites UTF-8 characters as `?`: the `[Run]` description
> becomes `??? Windows will ask for administrator rights…` on the next bump.

## What the Installer Does

### Installation
- ✅ Installs FWDE to `%AppData%\FWDE` (no admin rights needed)
- ✅ Creates Start Menu shortcut
- ✅ Optional: Desktop shortcut
- ✅ Optional: Run at Windows startup
- ✅ Preserves user config during updates
- ✅ Includes all necessary files (exe, config, layouts, docs)

## Elevation model (why the installer stays per-user)

The installer and the app have **different** privilege requirements, and the split
is deliberate:

| | Needs admin? | Why |
|---|---|---|
| **Installer** (`FWDE_Setup_*.exe`) | **No** | Installs per-user into `{userappdata}\FWDE`, creates only per-user shortcuts (`{autoprograms}`, `{autodesktop}`, `{userstartup}`), and writes no `HKEY_LOCAL_MACHINE` keys. `PrivilegesRequired=lowest` keeps UAC out of installation entirely. |
| **Running app** (`FWDE.exe`) | **Yes, by default** | Windows UIPI blocks every *write* to windows owned by elevated processes. FWDE's purpose is moving windows, so without a High-integrity token an administrator window can be measured but never placed. |

The installer therefore ships an **"Administrator rights" wizard page** (shown after
the task selection page) that explains the restriction and offers:

- **Request administrator rights when FWDE starts (recommended)** — checked by
  default, leaving `RunAsAdmin` at its shipped value `true`.
- Unchecked — the installer sets `"RunAsAdmin": false` in the config it just
  installed, so FWDE starts without a UAC prompt and simply leaves elevated
  windows alone.

Implementation notes:

- The choice only ever rewrites a config this run **created**. An existing
  `FWDE_Config.json` (upgrade) is never modified — `PrepareToInstall` records
  whether the file already existed, and `CurStepChanged(ssPostInstall)` acts only
  when it did not.
- The rewrite is a literal replacement of `"RunAsAdmin": true` →
  `"RunAsAdmin": false`, and is logged either way (`Elevation: ...` lines in the
  setup log, `SetupLogging=yes`). If the token cannot be found the log warns
  instead of silently doing nothing.
- If the checkbox is unchecked while FWDE is *already* running elevated, the
  change takes effect on the next launch, not immediately.

The full explanation (measured table of allowed reads vs blocked writes, the list
of typically-elevated Windows, what still works without elevation, and the
security caveat) lives in `README.MD` → **Administrator rights**, is installed next
to the app, and is also available at runtime from **Parameter Settings → 🔐 Why
admin?**.

## Testing the elevation page

1. Compile `installer.iss` (below) into a throwaway output directory.
2. Run it, and confirm the **Administrator rights** page appears after the task
   page, with the checkbox ticked.
3. Install with the box ticked → `%AppData%\FWDE\FWDE_Config.json` must contain
   `"RunAsAdmin": true`.
4. Install again with the box cleared (fresh install) → the config must contain
   `"RunAsAdmin": false`, and the setup log must contain
   `Elevation: RunAsAdmin set to false by installer choice`.
5. Upgrade over an existing install with the box cleared → the existing config
   must be untouched and the log must say
   `Elevation: existing config preserved, RunAsAdmin left untouched`.

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
#define MyAppURL "https://github.com/Flalaski/FWDE"
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
