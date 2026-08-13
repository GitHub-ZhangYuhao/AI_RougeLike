# Setup script: downloads the pinned Godot engine into GameEngine/ (idempotent).
# Usage: powershell -ExecutionPolicy Bypass -File tools/setup-godot.ps1
$ErrorActionPreference = 'Stop'

$Version = '4.7.1-stable'
$Root = Split-Path -Parent $PSScriptRoot
$EngineDir = Join-Path $Root 'GameEngine'
$Exe = Join-Path $EngineDir 'Godot.exe'

if (Test-Path $Exe) {
  Write-Output "Godot already installed: $Exe"
  & $Exe --version
  exit 0
}

$Url = "https://github.com/godotengine/godot/releases/download/$Version/Godot_v$($Version)_win64.exe.zip"
$Zip = Join-Path $env:TEMP "godot-$Version-win64.zip"

New-Item -ItemType Directory -Path $EngineDir -Force | Out-Null
Write-Output "Downloading $Url ..."
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $Url -OutFile $Zip -TimeoutSec 900

Write-Output 'Extracting...'
Expand-Archive -Path $Zip -DestinationPath $EngineDir -Force
Remove-Item $Zip

$Downloaded = Get-ChildItem $EngineDir -Filter "Godot_v*_win64.exe" | Select-Object -First 1
if (-not $Downloaded) { throw 'Godot executable not found after extraction.' }
Move-Item $Downloaded.FullName $Exe

Write-Output "Installed: $Exe"
& $Exe --version
