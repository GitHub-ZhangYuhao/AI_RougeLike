---
name: comfyui-audio
description: ComfyUI 音频生成工作流：ACE-Step 1.5 文生音频（text-to-audio）。专用音频生成模型，适合游戏音效和 BGM。
---

# ComfyUI 音频生成工作流 — ACE-Step 1.5

使用 **ACE-Step 1.5** 专用音频生成模型。纯音频模型，不涉及视频。

## 模型文件（All-in-One）

| 文件 | 大小 | 放置目录 |
|------|------|----------|
| `ace_step_1.5_turbo_aio.safetensors` | 9.34 GB | `models/checkpoints/` |

来源：`Comfy-Org/ace_step_1.5_ComfyUI_files` (HuggingFace)

> 这个文件包含扩散模型 + Qwen3 文本编码器 + VAE，一个文件搞定所有。

## 工作流文件

| 文件 | 用途 |
|------|------|
| `ace_step_1.5_text_to_audio_api.json` | ComfyUI 工作流（拖入界面即可用） |
| `generate_audio.py` | 批量生成脚本（21个游戏音效预设） |

## 节点管线

```
CheckpointLoaderSimple (ace_step_1.5_turbo_aio)
    ├── MODEL  → KSampler.model
    ├── CLIP   → TextEncodeAceStepAudio (正向/负向)
    └── VAE    → VAEDecodeAudio

TextEncodeAceStepAudio (tags="音效描述", lyrics="")
    ↓ CONDITIONING → KSampler (positive/negative)

EmptyAceStep1.5LatentAudio (seconds=2.0)
    ↓ LATENT → KSampler.latent_image

KSampler (steps=20, cfg=7.0, euler, normal)
    ↓ LATENT → VAEDecodeAudio.samples

VAEDecodeAudio
    ↓ AUDIO → PreviewAudio / SaveAudioAdvanced
```

## 使用方法

1. 确保 `ace_step_1.5_turbo_aio.safetensors` 在 `models/checkpoints/`
2. 重启 ComfyUI Desktop
3. 将 `ace_step_1.5_text_to_audio_api.json` 拖入 ComfyUI 界面
4. 修改节点 2 的 `tags` 为你想要的音效描述
5. 点击 Queue Prompt
6. 输出在 ComfyUI `output/audio/` 目录

## 批量生成

```bash
python tools/AudioWorkflows/generate_audio.py --list          # 查看所有预设
python tools/AudioWorkflows/generate_audio.py                  # 生成全部
python tools/AudioWorkflows/generate_audio.py --names sfx_sword_slash bgm_menu  # 指定
python tools/AudioWorkflows/generate_audio.py --dry-run        # 预览提示词
```

## 提示词参考

### 游戏音效

```
# 武器攻击
sharp sword slash, metallic ring, swift air cut, single strike, game audio

# 魔法效果
magical fire explosion, crackling flames, powerful burst, impact, game audio

# 拾取
magical crystal chime, sparkling gem collect, bright short ding, game audio
```

### 背景音乐

```
# 战斗BGM
intense dark fantasy battle music, fast Chinese war drums, aggressive erhu

# 菜单BGM
serene Chinese traditional night, soft erhu melody, gentle guzheng, temple bells
```

### 时长参考

| seconds | 适合 |
|---------|------|
| 0.5-1.0 | 短音效（UI、拾取） |
| 1.0-3.0 | 中等音效（攻击、爆炸） |
| 3.0-10.0 | 长音效、短BGM |
| 10.0-120.0 | BGM段落 |

## 采样建议

- Steps: 20（Turbo 模型收敛快，可提升到 30-50 提高质量）
- CFG: 7.0（可按 5.0-10.0 调整）
- Sampler: euler
- Scheduler: normal

## 后续处理

1. Audacity 裁剪头尾静音
2. BGM 做交叉淡化循环
3. SFX 标准化音量 (-6dB ~ -3dB)
4. 导出为 OGG（游戏用）或 WAV
5. 复制到 `GameProject/assets/audio/`
