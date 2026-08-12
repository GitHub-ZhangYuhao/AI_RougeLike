---
name: video-to-alpha-flipbook
description: Convert MP4, MOV, WebM, and other FFmpeg-readable videos into raw PNG frame sequences, AI-matted RGBA PNG sequences, and uniformly sampled game-ready sprite sheets/Flipbooks with previews and metadata. Use when the user asks to split a video into frames or 序列帧, perform Alpha/background matting, pack animation frames into a Sprite Sheet/Flipbook/SubUV texture for Unreal or Unity, or compare 5x5, 6x6, and 8x8 atlases.
---

# Video to Alpha Flipbook

将视频通过一个可复现流程转换为原始 PNG、透明 RGBA PNG 和游戏用 Flipbook 图集。优先运行已封装脚本，不要手工重复实现流水线。

## 快速执行

在 Windows PowerShell 中运行：

```powershell
$skill = "C:\WorkSpace\AI_RougeLike\video-to-alpha-flipbook"

& "$skill\scripts\run_video_to_flipbook.ps1" `
  -InputVideo ".\input.mp4" `
  -Grid 6 `
  -AtlasSize 2048
```

首次执行会通过 `uv` 创建共享 Python 3.12 环境、安装依赖并下载 BiRefNet 模型。必须确保 `ffmpeg`、`ffprobe` 和 `uv` 可用。

## 选择输出模式

- 完整流程：不添加跳过参数；输出原始帧、Alpha 帧、图集、预览和元数据。
- 只拆原始 PNG：添加 `-SkipMatting -SkipAtlas`。
- 输出 Alpha PNG，但不合并图集：添加 `-SkipAtlas`。
- 输出不透明图集：添加 `-SkipMatting`；仅在用户明确不需要透明背景时使用。
- 覆盖已有输出：添加 `-Force`；执行前确认目标目录正确。

指定输出目录：

```powershell
& "$skill\scripts\run_video_to_flipbook.ps1" `
  -InputVideo ".\input.mp4" `
  -OutputDir ".\output\input_flipbook" `
  -Grid 6 `
  -AtlasSize 2048
```

## 选择图集网格

默认使用 **6×6**，在清晰度和流畅度之间折中。

| 网格 | 抽取帧数 | 2048 图集中的内容最大边 | 适用情况 |
|---|---:|---:|---|
| 8×8 | 64 | 240 px | 动作快、优先流畅度 |
| 6×6 | 36 | 325 px | 默认选择、质量均衡 |
| 5×5 | 25 | 393 px | 动作慢、优先单帧清晰度 |

脚本始终均匀抽帧并包含第一帧和最后一帧。播放帧率会根据源视频时长自动写入 JSON 和报告。

## 输出结构

完整流程生成：

```text
<video>_flipbook_<grid>x<grid>/
├── frames_raw/                 # 原始 RGB PNG 序列
├── frames_alpha/               # Straight Alpha RGBA PNG 序列
│   └── matting_stats.csv
├── sprite_sheet_*.png          # 最终透明图集
├── sprite_sheet_*.json         # UV、帧映射和建议播放帧率
├── sprite_sheet_*.csv          # 抽帧映射表
├── sprite_sheet_*_checker_preview.jpg
├── sprite_sheet_*_playback_preview.mp4
├── pipeline_manifest.json
└── PROCESS_REPORT.md
```

## 质量检查

完成后必须：

1. 确认 `frames_raw` 与 `frames_alpha` 数量一致。
2. 确认 Alpha PNG 和图集像素格式为 RGBA，Alpha 范围包含 0～255。
3. 播放 `*_playback_preview.mp4`，检查暗部误删、黑边、闪烁和抽帧跳跃。
4. 打开 `*_checker_preview.jpg`，检查网格顺序和单元串色。
5. 如果预览质量不合格，停止后续导入；先调整模型、网格或安全边距。

## 处理约束

- 保持源画面宽高比。
- 使用 PNG 作为 Alpha 中间格式；不要改为 JPG。
- 保持 Straight Alpha。
- 保留透明 RGB 扩展和安全边距，避免 Unreal/Unity 的双线性过滤与 Mipmap 黑边。
- 不要假定普通 H.264 MP4 能保存 Alpha。
- 复杂烟雾、毛发、运动模糊或主体与背景颜色接近时，明确要求用户检查预览。

## 资源

- 一键入口：`scripts/run_video_to_flipbook.ps1`
- 流水线：`scripts/video_to_alpha_flipbook.py`
- Alpha 抠像：`scripts/matting_sequence.py`
- 图集打包：`scripts/build_sprite_sheet.py`
- 预览生成：`scripts/preview_sprite_sheet.py`
- 参数和故障处理：`references/workflow.md`
