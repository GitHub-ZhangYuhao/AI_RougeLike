# Workflow Reference

## Pipeline

```text
video
  -> ffprobe inspection
  -> lossless PNG extraction with FFmpeg
  -> BiRefNet soft Alpha inference
  -> flat-background edge decontamination
  -> transparent RGB bleed
  -> RGBA PNG sequence
  -> uniform frame sampling
  -> exact-size RGBA Sprite Sheet
  -> checkerboard and playback previews
```

## Runtime requirements

- Windows PowerShell
- FFmpeg and ffprobe on `PATH`
- `uv` for first-run Python environment creation
- Python 3.12 environment created automatically under `%LOCALAPPDATA%\CodexSkillEnvs\video-to-alpha-flipbook`
- First model download: approximately 224 MB for `birefnet-general-lite`

The wrapper installs `rembg`, `opencv-python-headless`, and `onnxruntime-directml`. ONNX Runtime still exposes `CPUExecutionProvider` as a fallback.

## Useful commands

Complete 6×6 pipeline:

```powershell
& "C:\WorkSpace\AIGame\.agents\skills\video-to-alpha-flipbook\scripts\run_video_to_flipbook.ps1" `
  -InputVideo ".\clip.mp4" -Grid 6 -AtlasSize 2048
```

Alpha sequence only:

```powershell
& "C:\WorkSpace\AIGame\.agents\skills\video-to-alpha-flipbook\scripts\run_video_to_flipbook.ps1" `
  -InputVideo ".\clip.mp4" -SkipAtlas
```

Raw frame extraction only:

```powershell
& "C:\WorkSpace\AIGame\.agents\skills\video-to-alpha-flipbook\scripts\run_video_to_flipbook.ps1" `
  -InputVideo ".\clip.mp4" -SkipMatting -SkipAtlas
```

Use a different model or provider:

```powershell
& "C:\WorkSpace\AIGame\.agents\skills\video-to-alpha-flipbook\scripts\run_video_to_flipbook.ps1" `
  -InputVideo ".\clip.mp4" `
  -Model "birefnet-general" `
  -Provider "CPUExecutionProvider"
```

## Grid math for a 2048 atlas

The script computes:

```text
samples = grid × grid
content_max = floor(atlas_size / grid) - 2 × gutter
playback_fps = samples / source_duration_seconds
```

With an 8 px gutter:

| Grid | Samples | Content max | Approx. playback for 4.84 s |
|---|---:|---:|---:|
| 8×8 | 64 | 240 | 13.223 FPS |
| 6×6 | 36 | 325 | 7.438 FPS |
| 5×5 | 25 | 393 | 5.165 FPS |

When the atlas size is not divisible by the grid, physical cells differ by at most one pixel. UVs remain normalized by row and column, and JSON records exact pixel bounds.

## Troubleshooting

### CUDA provider fails to load

Prefer `DmlExecutionProvider` on Windows. The wrapper selects DirectML automatically. Do not install a full CUDA toolkit unless the user explicitly needs CUDA.

### Output directory is not empty

Use a new output directory or rerun with `-Force` only after confirming that replacing the directory is safe.

### Grid needs more frames than the video contains

Choose a smaller grid. A 5×5 grid requires at least 25 extracted frames.

### Subject has dark halos

Inspect the green-background preview. Increase RGB bleed only if needed. Avoid premultiplied/straight Alpha mismatches in the target engine.

### Alpha flickers

Try a stronger matting model, reduce the output frame rate, or add temporal stabilization before atlas packing. Do not hide flicker by blindly thresholding Alpha; that destroys soft edges.

### Unreal texture appears blurred

Compare 8×8, 6×6, and 5×5 variants. Prefer 6×6 first. Confirm texture compression, mip settings, and material blend mode in the target project.

## Validation commands

```powershell
(Get-ChildItem .\frames_raw -Filter 'frame_*.png').Count
(Get-ChildItem .\frames_alpha -Filter 'frame_*.png').Count
ffprobe -v error -show_entries stream=width,height,pix_fmt -of default=noprint_wrappers=1 .\sprite_sheet_*.png
```
