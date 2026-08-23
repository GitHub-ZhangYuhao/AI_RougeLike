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

    # --- godot-minigame 4.7+ template ships a "subpack runtime" boot path: ---
    # engine/game.js hardcodes `const pack = '/engine/empty-tips.bin'` (a stub
    # demo project bundled by the template itself) and expects the real game
    # content to be loaded later via addons/godot_subpack_runtime, which this
    # project does not use. Our actual exported content lands untouched in
    # engine/demo-pck.bin (Godot's normal main-pack name) and is simply never
    # referenced. Patch game.js to boot straight into demo-pck.bin (matching
    # the pre-4.7 template behavior) and drop the now-unreferenced stub pack
    # to reclaim ~3MB of budget. Confirmed via VConsole real-device test that
    # the default (unpatched) boot path black-screens on the empty stub.
    $gameJsPath = Join-Path $buildDir 'engine\game.js'
    $emptyTipsPath = Join-Path $buildDir 'engine\empty-tips.bin'
    if (Test-Path $gameJsPath) {
        $js = [System.IO.File]::ReadAllText($gameJsPath, [System.Text.Encoding]::UTF8)
        $jsPatched = $js -replace 'empty-tips\.bin', 'demo-pck.bin'
        if ($jsPatched -ne $js) {
            [System.IO.File]::WriteAllText($gameJsPath, $jsPatched, $utf8NoBom)
            Write-Host '[minigame_export] patched game.js: boot pack empty-tips.bin -> demo-pck.bin'
        }
    }
    if (Test-Path $emptyTipsPath) {
        [System.IO.File]::Delete($emptyTipsPath)
        Write-Host '[minigame_export] removed unused engine/empty-tips.bin stub (~3MB reclaimed)'
    }

    # --- touch/mouse position comes back NaN on WeChat: canvas.getBoundingClientRect()
    # doesn't populate .x/.y on WeChat's minigame canvas (spec allows it, since DOMRect.x/y
    # are read-only getters; WeChat's shim leaves them undefined). godot.js's shared
    # GodotInput.computePosition() reads rect.x/rect.y directly, so evt.clientX - undefined
    # = NaN for every touch AND mouse event position on this platform, breaking all
    # pointer-based UI (card choice hit-testing, virtual joystick drag, everything that
    # reads InputState.mouse_x/mouse_y). The template already has a rect.x=0/rect.y=0
    # "workaround" right before this call, but that's a no-op: assigning to a getter-only
    # DOMRect property silently fails. Fix at the source: use rect.left/rect.top, which are
    # always populated per spec and numerically identical to .x/.y on every environment
    # that implements them correctly.
    $godotJsPath = Join-Path $buildDir 'engine\godot.js'
    if (Test-Path $godotJsPath) {
        $gjs = [System.IO.File]::ReadAllText($godotJsPath, [System.Text.Encoding]::UTF8)
        $gjsPatched = $gjs.Replace(
            'const x=(evt.clientX-rect.x)*rw;const y=(evt.clientY-rect.y)*rh;',
            'const x=(evt.clientX-rect.left)*rw;const y=(evt.clientY-rect.top)*rh;')
        if ($gjsPatched -ne $gjs) {
            [System.IO.File]::WriteAllText($godotJsPath, $gjsPatched, $utf8NoBom)
            Write-Host '[minigame_export] patched godot.js: GodotInput.computePosition uses rect.left/top (fixes NaN touch/mouse position on WeChat)'
        } else {
            Write-Host '[minigame_export] WARNING: computePosition patch target not found in godot.js (template may have changed) - touch/mouse position may be NaN on WeChat'
        }
    }

    # --- patch game.json: plugin template hardcodes iOSHighPerformance(+) = true ---
    # regardless of platform, but these require manual opt-in via the WeChat minigame
    # backend ("游戏能力地图 -> 研发能力 -> 生成提效包 -> 高性能模式"). Leaving them true
    # without that opt-in appears to load a mismatched WAGamePerformanceUtilsSDK
    # instrumentation layer that crashes real-device runs inside compressedTexImage2D
    # ("Invalid value used as weak map key"). Force both false until the backend
    # capability is actually enabled for this AppID.
    $gameJsonPath = Join-Path $buildDir 'game.json'
    if (Test-Path $gameJsonPath) {
        $gj = [System.IO.File]::ReadAllText($gameJsonPath, [System.Text.Encoding]::UTF8)
        $gjPatched = $gj -replace '"iOSHighPerformance(\+?)":\s*true', '"iOSHighPerformance$1": false'
        if ($gjPatched -ne $gj) {
            [System.IO.File]::WriteAllText($gameJsonPath, $gjPatched, $utf8NoBom)
            Write-Host '[minigame_export] patched game.json: iOSHighPerformance / iOSHighPerformance+ forced false (not opted-in on backend)'
        }
    }
    
    # --- NOTE: Brotli decompression disabled due to WeChat 4MB main package limit ---
    # The .br file is ~6MB compressed but ~58MB decompressed, exceeding WeChat's 4MB limit
    # We need to find alternative solutions (CDN loading, subpackaging, or different export settings)
    
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
            # godot-minigame's WeChat WASM template mis-binds VRAM/ETC2 compressed
            # textures (WebGL: INVALID_ENUM: compressedTexImage2D: invalid format),
            # silently failing to render every compressed texture in the exported
            # game (confirmed via VConsole: logic/hit-testing works, only texture
            # upload fails). Switch to Lossy (WebP, CPU-decoded, uploaded as a plain
            # texture) for the minigame export only; reverted below like the slim
            # size limits.
            $r = Invoke-Godot "--headless --path `"$projDir`" --script res://tools/minigame_texture_mode.gd -- --apply" 'lossy_apply'
            if ($r.Code -ne 0) { throw "lossy texture-mode apply failed (exit=$($r.Code)) - see $($r.Log)" }
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