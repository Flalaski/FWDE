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

rem installer.iss is UTF-8 WITHOUT a BOM and deliberately contains non-ASCII text
rem (the em dash in the [Run] description). Reading/writing it as ASCII - as this
rem script used to - silently replaced such characters with "?" on every bump, so
rem the file is handled as UTF-8 here and the result is verified afterwards.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $file='%ISS_FILE%'; $v='%NEW_VERSION%'; $utf8=New-Object System.Text.UTF8Encoding($false); $before=[System.IO.File]::ReadAllText($file,[System.Text.Encoding]::UTF8); $lines=[System.IO.File]::ReadAllLines($file,[System.Text.Encoding]::UTF8); $found=$false; for($i=0; $i -lt $lines.Count; $i++){ if($lines[$i] -match '^#define\s+MyAppVersion\s+'){ $lines[$i]='#define MyAppVersion ' + [char]34 + $v + [char]34; $found=$true; break } }; if(-not $found){ throw 'MyAppVersion define not found.' }; [System.IO.File]::WriteAllLines($file,$lines,$utf8); $after=[System.IO.File]::ReadAllText($file,[System.Text.Encoding]::UTF8); if($after -notmatch [regex]::Escape($v)){ throw 'Write verification failed: version not found after write.' }; $nb=([regex]::Matches($before,'[^\x00-\x7F]')).Count; $na=([regex]::Matches($after,'[^\x00-\x7F]')).Count; if($na -ne $nb){ throw ('Encoding regression: non-ASCII character count changed ' + $nb + ' -> ' + $na) }"

if errorlevel 1 (
  echo ERROR: Failed to update installer.iss
  exit /b 1
)

echo Updated installer version to %NEW_VERSION%
echo File: "%ISS_FILE%"
exit /b 0
