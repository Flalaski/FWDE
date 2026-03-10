@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "ISS_FILE=%SCRIPT_DIR%installer.iss"

if not exist "%ISS_FILE%" (
  echo ERROR: installer.iss not found at "%ISS_FILE%"
  exit /b 1
)

for /f %%V in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Get-Date; '1.' + $d.ToString('yyMMdd')"') do set "NEW_VERSION=%%V"

if not defined NEW_VERSION (
  echo ERROR: Failed to compute version string.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $file='%ISS_FILE%'; $v='%NEW_VERSION%'; $lines=Get-Content -LiteralPath $file; $found=$false; for($i=0; $i -lt $lines.Count; $i++){ if($lines[$i] -match '^#define\s+MyAppVersion\s+') { $lines[$i]='#define MyAppVersion ' + [char]34 + $v + [char]34; $found=$true; break } }; if(-not $found){ throw 'MyAppVersion define not found.' }; Set-Content -LiteralPath $file -Value $lines -Encoding Ascii"

if errorlevel 1 (
  echo ERROR: Failed to update installer.iss
  exit /b 1
)

echo Updated installer version to %NEW_VERSION%
echo File: "%ISS_FILE%"
exit /b 0
