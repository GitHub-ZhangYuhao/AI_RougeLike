[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputVideo,

    [string]$OutputDir = "",
    [ValidateRange(1, 16)]
    [int]$Grid = 6,
    [ValidateRange(256, 16384)]
    [int]$AtlasSize = 2048,
    [ValidateRange(0, 512)]
    [int]$ContentMax = 0,
    [ValidateRange(0, 64)]
    [int]$Gutter = 8,
    [string]$Model = "birefnet-general-lite",
    [string]$Provider = "auto",
    [switch]$SkipMatting,
    [switch]$SkipAtlas,
    [switch]$NoPreview,
    [switch]$Force,
    [string]$EnvironmentDir = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg is required and must be available on PATH."
}
if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    throw "ffprobe is required and must be available on PATH."
}

$resolvedInput = (Resolve-Path -LiteralPath $InputVideo).Path
if (-not $EnvironmentDir) {
    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $HOME }
    $EnvironmentDir = Join-Path $base "CodexSkillEnvs\video-to-alpha-flipbook"
}
$EnvironmentDir = [System.IO.Path]::GetFullPath($EnvironmentDir)
$python = Join-Path $EnvironmentDir "Scripts\python.exe"

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        throw "uv is required for first-time environment setup. Install uv, then rerun the skill."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $EnvironmentDir) | Out-Null
    & $uv.Source venv $EnvironmentDir --python 3.12
    if ($LASTEXITCODE -ne 0) { throw "Failed to create Python 3.12 environment." }
}

$dependencyCheck = "import importlib.util,sys; mods=('rembg','cv2','onnxruntime','scipy','PIL'); sys.exit(0 if all(importlib.util.find_spec(m) for m in mods) else 1)"
& $python -c $dependencyCheck
if ($LASTEXITCODE -ne 0) {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) { throw "uv is required to install the skill dependencies." }
    $runtime = if ($env:OS -eq "Windows_NT") { "onnxruntime-directml" } else { "onnxruntime" }
    & $uv.Source pip install --python $python rembg opencv-python-headless $runtime
    if ($LASTEXITCODE -ne 0) { throw "Failed to install video-to-alpha-flipbook dependencies." }
}

$pipeline = Join-Path $PSScriptRoot "video_to_alpha_flipbook.py"
$arguments = @(
    $pipeline,
    $resolvedInput,
    "--grid", "$Grid",
    "--atlas-size", "$AtlasSize",
    "--content-max", "$ContentMax",
    "--gutter", "$Gutter",
    "--model", $Model,
    "--provider", $Provider
)
if ($OutputDir) { $arguments += @("--output-dir", [System.IO.Path]::GetFullPath($OutputDir)) }
if ($SkipMatting) { $arguments += "--skip-matting" }
if ($SkipAtlas) { $arguments += "--skip-atlas" }
if ($NoPreview) { $arguments += "--no-preview" }
if ($Force) { $arguments += "--force" }

& $python @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Video to alpha flipbook pipeline failed with exit code $LASTEXITCODE."
}
