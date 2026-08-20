# tools/minigame_export.ps1 — headless minigame export wrapper (Godot 4.5.1 + godot-minigame)
#
# What it does:
#   1. Temporarily strips the dev-only MCPRuntime autoload from project.godot so the
#      exported project.binary does not reference res://addons/godot_mcp/* (which is
#      excluded from release packages). Restores project.godot afterwards, always.
#   2. Runs `--export-release` for the requested preset(s) with a UTF-8 console
#      (chcp 65001) so Chinese preset names survive the round-trip.
#   3. preset.3 is the SLIM preset: before exporting it the script snapshots every
#      assets/**/*.import file, applies the tight size limits
#      (tools/minigame_size_limit.gd --profile slim), rebuilds textures with --import,
#      exports, then restores the snapshot byte-for-byte and re-imports, so the repo
#      always ends in the default size-limit state.
#   4. Verifies the produced pck no longer contains any MCPRuntime autoload reference
#      and prints package sizes.
#
# Usage (from GameProject/):
#   powershell -File tools/minigame_export.ps1                # presets 2 + 3
#   powershell -File tools/minigame_export.ps1 -Presets 2     # only preset.2 (full)
#   powershell -File tools/minigame_export.ps1 -Presets 3     # only preset.3 (slim)
#
# NOTE: close the Godot editor before running — this script edits project.godot and
#       .import files on disk.
param(
    [int[]]$Presets = @(2, 3),
    [string]$GodotExe = ''
)
$ErrorActionPreference = 'Stop'
$projDir = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $projDir -Parent
if ($GodotExe -eq '') { $GodotExe = Join-Path $repoRoot 'GameEngine\4.5\Godot.exe' }
if (-not (Test-Path $GodotExe)) { throw "Godot not found: $GodotExe" }
$logDir = Join-Path $repoRoot 'Experimental'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$projGodot = Join-Path $projDir 'project.godot'
$cfgPath = Join-Path $projDir 'export_presets.cfg'
$cfg = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
$failed = @()

function Get-PresetSection([int]$idx) {
    $hdr = "[preset.$idx]"
    $i = $cfg.IndexOf($hdr)
    if ($i -lt 0) { throw "preset.$idx not found in export_presets.cfg" }
    $j = $cfg.IndexOf("`n[preset.", $i + 1)
    if ($j -lt 0) { $j = $cfg.Length }
    return $cfg.Substring($i, $j - $i)
}

function Invoke-Godot([string]$args_, [string]$logName) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $log = Join-Path $logDir ("$logName`_$stamp.log")
    Write-Host "[minigame_export] $logName (log: $log)"
    $cmd = "chcp 65001 >nul & `"$GodotExe`" $args_ > `"$log`" 2>&1 & echo EXIT=%ERRORLEVEL%"
    $tail = cmd /c $cmd | Select-Object -Last 1
    $code = -1
    if ($tail -match 'EXIT=(\d+)') { $code = [int]$Matches[1] }
    return @{ Code = $code; Log = $log }
}

function Export-Preset([int]$idx) {
    $sec = Get-PresetSection $idx
    $name = [regex]::Match($sec, '(?m)^name="([^"]+)"').Groups[1].Value
    $outRel = [regex]::Match($sec, '(?m)^export_path="([^"]+)"').Groups[1].Value
    if ($name -eq '' -or $outRel -eq '') { throw "preset.$idx missing name/export_path" }
    $outAbs = Join-Path $projDir ($outRel -replace '/', '\')
    $buildDir = Split-Path $outAbs -Parent
    if (Test-Path $buildDir) {
        [System.IO.Directory]::Delete($buildDir, $true)
        Write-Host "[minigame_export] cleaned stale build dir: $buildDir"
    }
    Write-Host "[minigame_export] preset.$idx -> $outRel"
    $r = Invoke-Godot "--headless --path `"$projDir`" --export-release `"$name`" `"$outRel`"" "export_preset$idx"
    if ($r.Code -ne 0) {
        $script:failed += $idx
        Write-Host "[minigame_export] preset.$idx FAILED (exit=$($r.Code)) - see $($r.Log)"
        return
    }
    # --- verify: no MCPRuntime reference left in the packed project ---
    $pck = Join-Path $buildDir 'engine\demo-pck.bin'
    if (Test-Path $pck) {
        $hit = cmd /c "findstr /m /c:`"MCPRuntime`" `"$pck`""
        if ($hit) { Write-Host "[minigame_export] WARNING: MCPRuntime still referenced in $pck" }
        else { Write-Host '[minigame_export] OK: no MCPRuntime reference in pck' }
    }
    $total = (Get-ChildItem $buildDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $pckSize = if (Test-Path $pck) { (Get-Item $pck).Length } else { 0 }
    Write-Host ("[minigame_export] preset.$idx done: total {0:N2} MB (pck {1:N2} MB)" -f ($total/1MB), ($pckSize/1MB))
}

function Save-ImportSnapshot([string]$snapDir) {
    $assetsRoot = Join-Path $projDir 'assets'
    $files = Get-ChildItem $assetsRoot -Recurse -Filter *.import
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($assetsRoot.Length + 1)
        $dest = Join-Path $snapDir $rel
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
    Write-Host "[minigame_export] snapshotted $($files.Count) .import files to $snapDir"
}

function Restore-ImportSnapshot([string]$snapDir) {
    $assetsRoot = Join-Path $projDir 'assets'
    $files = Get-ChildItem $snapDir -Recurse -Filter *.import
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($snapDir.Length + 1)
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $assetsRoot $rel) -Force
    }
    Write-Host "[minigame_export] restored $($files.Count) .import files from snapshot"
}

# --- 1. strip MCPRuntime autoload -------------------------------------------
$original = [System.IO.File]::ReadAllText($projGodot, [System.Text.Encoding]::UTF8)
$stripped = (($original -split "`r?`n") | Where-Object { $_ -notmatch '^MCPRuntime=' }) -join "`n"
if ($stripped -eq $original) {
    Write-Host '[minigame_export] note: MCPRuntime autoload not present; nothing to strip'
} else {
    [System.IO.File]::WriteAllText($projGodot, $stripped, $utf8NoBom)
    Write-Host '[minigame_export] stripped MCPRuntime autoload for export'
}

try {
    # --- default-budget presets first (repo is in default size-limit state) ---
    foreach ($idx in $Presets) {
        if ($idx -ne 3) { Export-Preset $idx }
    }

    # --- preset.3 slim dance: snapshot -> slim limits -> import -> export -> restore ---
    if ($Presets -contains 3) {
        $snap = Join-Path $env:TEMP ("minigame_import_snap_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Save-ImportSnapshot $snap
        try {
            $r = Invoke-Godot "--headless --path `"$projDir`" --script res://tools/minigame_size_limit.gd -- --profile slim --apply" 'slim_apply'
            if ($r.Code -ne 0) { throw "slim size-limit apply failed (exit=$($r.Code)) - see $($r.Log)" }
            $r = Invoke-Godot "--headless --path `"$projDir`" --import" 'slim_import'
            if ($r.Code -ne 0) { throw "slim --import failed (exit=$($r.Code)) - see $($r.Log)" }
            Export-Preset 3
        } finally {
            Restore-ImportSnapshot $snap
            $r = Invoke-Godot "--headless --path `"$projDir`" --import" 'default_import'
            if ($r.Code -ne 0) { Write-Host "[minigame_export] WARNING: default --import after restore failed - see $($r.Log)" }
            [System.IO.Directory]::Delete($snap, $true)
            Write-Host '[minigame_export] snapshot cleaned up; repo back to default size limits'
        }
    }
} finally {
    [System.IO.File]::WriteAllText($projGodot, $original, $utf8NoBom)
    Write-Host '[minigame_export] project.godot restored'
}
if ($failed.Count -gt 0) { throw "export failed for presets: $($failed -join ', ')" }