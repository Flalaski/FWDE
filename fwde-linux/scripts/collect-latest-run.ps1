param(
    [string]$RunsRoot,
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RunsRoot)) {
    $RunsRoot = Join-Path $scriptDir 'debug outputs\runs'
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $scriptDir 'debug outputs\bundles'
}

if (-not (Test-Path -LiteralPath $RunsRoot)) {
    Write-Error "Runs root not found: $RunsRoot"
}

$latestRun = Get-ChildItem -LiteralPath $RunsRoot -Directory -Recurse |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'session.log') } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

if (-not $latestRun) {
    Write-Error "No run folders found under: $RunsRoot"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$runName = $latestRun.Name
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$zipPath = Join-Path $OutputDir ("fwde-debug-{0}-{1}.zip" -f $runName, $stamp)

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -LiteralPath $latestRun.FullName -DestinationPath $zipPath -CompressionLevel Optimal -Force

Write-Host "Latest run: $($latestRun.FullName)"
Write-Host "Bundle: $zipPath"
