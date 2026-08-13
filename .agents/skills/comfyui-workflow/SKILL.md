---
name: comfyui-workflow
description: ComfyUI 工作流模板：Krea-2 Turbo 文生图（text-to-image，支持风格 LoRA）、Qwen-Image-Edit 2511 图像编辑（由人物设定生成不同 pose 变体，为精灵图做准备）与 MiniMax H3 首尾帧图生视频（first/last-frame to video，原生立体声音频）。当用户需要用 ComfyUI 生成图片、编辑角色图生成 pose 变体、把图片作为首帧/尾帧生成视频、制作角色待机或循环动画视频，或询问 Krea-2、Qwen-Image-Edit、MiniMax H3 工作流的模型清单、节点参数时使用。
---

# ComfyUI Workflow

三个可直接导入 ComfyUI 的 UI 格式工作流模板。本 skill 完全自包含，只使用 skill 目录内的文件。

| 文件 | 用途 | 模型 |
|---|---|---|
| `workflows/krea2_t2i.json` | 文生图（text-to-image），内置提示词增强与 9 种风格 LoRA 切换 | Krea-2 Turbo |
| `workflows/image_edit.json` | 图像编辑：由人物设定图生成不同 pose 变体（最多 3 张参考图），作为视频与精灵图的上游素材 | Qwen-Image-Edit 2511（+Lightning 4 步加速） |
| `workflows/minimax_h3_i2v.json` | 首帧/尾帧图生视频（fl2va），输出带原生立体声音频的 24fps 视频 | MiniMax H3 |

## 导入与运行

1. 将 `workflows/` 下对应 JSON 拖入 ComfyUI 界面（或 Load）加载。
2. 按「模型清单」确认权重已放入对应目录，且 ComfyUI 已更新到最新版。
3. 点击运行。

## 推荐流水线：人设 → pose 变体 → 视频 → 精灵图

1. 用 `krea2_t2i.json` 生成人物设定图（或直接准备现成的角色设定图）。
2. 在 `image_edit.json` 中把人设图接入 `image1`，按下方提示词规范编写 `图中角色<动作>,<pose>的pose,保持画面风格`，每个 pose 运行一次，得到一组风格统一的 pose 图。
3. 在 `minimax_h3_i2v.json` 中用 LoadImage 把两张 pose 图分别接为 `first_frame` / `last_frame`（同一张图同时接两端则生成无缝循环），编写运动 + 音频提示词后运行，得到循环动画视频。
4. 视频抽帧、抠像并拼合为精灵图，可用本仓库 `.agents/skills/video-to-alpha-flipbook/` 处理。

## krea2_t2i.json（文生图）

双击子图节点可展开完整管线。关键输入：

| 参数 | 说明 |
|---|---|
| `value`（Text String / User Prompt） | 图片描述 |
| `prompt_enhance` | 默认开，先用 LLM 扩写提示词；关闭则原样使用 |
| `enable_lora` | 启用风格 LoRA；同时在 `lora_name` 选文件，按需调 `strength_model` |
| `lora_trigger_word` | 由画布上 CustomCombo 节点按所选 LoRA 自动追加（见下表） |
| `width` / `height` | 由 ResolutionSelector 节点控制 |
| `seed` | 随机种子 |

采样 8 步；结果经 SaveImage 保存，文件名前缀 `Krea2_turbo`。

### 风格 LoRA 触发词

LoRA 从 `huggingface.co/Comfy-Org/Krea-2/tree/main/loras` 下载，放入 `models/loras/`，推荐强度均为 1.0：

| LoRA | 触发词 |
|---|---|
| krea2_darkbrush | monochrome ink wash style |
| krea2_dotmatrix | monochrome stippling style |
| krea2_kidsdrawing | naive expressive sketch style |
| krea2_neondrip | textured abstract style |
| krea2_rainywindow | rainy window style |
| krea2_retroanime | purple retro anime style |
| krea2_softwatercolor | art deco watercolor style |
| krea2_sunsetblur | ethereal motion blur style |
| krea2_vintagetarot | vintage tarot style |

## image_edit.json（图像编辑 / pose 生成）

双击子图节点（Image Edit (Qwen-Image 2511)）可展开完整管线。关键输入：

| 参数 | 说明 |
|---|---|
| `image1` | 待编辑主图（必填）；pose 流水线中接人物设定图 |
| `image2` / `image3` | 可选参考图，用于多图参考编辑 |
| `positive_prompt` | 编辑 / pose 描述；pose 生成必须包含保持风格的要求（见下） |
| `negative_prompt` | 负面提示词，可留空 |
| `unet_name` / `clip_name` / `vae_name` | 模型选择，默认 `qwen_image_edit_2511_bf16` / `qwen_2.5_vl_7b_fp8_scaled` / `qwen_image_vae` |
| `enable_turbo_mode` | 开启后加载 `lora_name` 指定的 Lightning LoRA 并切换 4 步快速采样；关闭则 40 步 |
| `lora_name` | turbo 用的 Lightning LoRA 文件名（仅 `enable_turbo_mode` 时生效） |
| `seed` | 随机种子 |

采样器 `euler`、调度 `simple`、CFG 4.0（CFGNorm）、denoise 1.0；结果经 SaveImage 保存，文件名前缀 `Qwen_Edit_2511`。步数参考表见工作流内 MarkdownNote（Qwen 官方 40 步 / Comfy 20 步，CFG 均 4.0）。

### ⚠️ Pose 生成提示词规范（必须遵守）

用人物设定生成 pose 变体时，**每条正向提示词都必须显式要求保持画面风格**，否则系列 pose 会跑偏风格，无法用于精灵图。固定模板：

```text
图中角色<动作描述>,<pose>的pose,保持画面风格
```

示例：`图中角色向左移动,走路的pose,保持画面风格`（也是工作流默认提示词）。

要点：
- 多个 pose 之间 `image1` 始终保持同一张人设图，只改提示词里的动作/pose 描述。
- 风格仍漂移时，追加 `保持画面风格,统一线条与配色,保持同一角色形象` 或换 seed 重跑。
- 建议先规划 pose 序列（如 待机 → 行走 → 攻击 → 受击 → 死亡），每个 pose 跑一次，便于后续按帧序拼精灵图。

## minimax_h3_i2v.json（首尾帧生视频）

关键输入：

| 参数 | 说明 |
|---|---|
| `first_frame` / `last_frame` | 可选关键帧，模型生成两帧之间的运动；都不接则退化为文生视频（t2va） |
| `prompt` | 镜头、运动与音频（对白/音效/音乐）写在同一段里 |
| `width` / `height` | 原生短边 768，上限 768x1344，取 32 的倍数 |
| `duration`（秒） | 自动换算为帧数：24fps，`max(5, round(a*24))` 后向上对齐 17k+5 网格 |
| `noise_seed` | 随机种子 |

采样器 `res_multistep`、20 步；视频经 SaveVideo 保存，前缀 `video/MiniMax_H3`。输出 16:9 尺寸参考：0.5MP→960x544、0.98MP→1344x768、1.5MP→1664x928、2.0MP→1920x1088（完整表见工作流内 MarkdownNote 节点）。

## 模型清单

| 工作流 | 文件 | 放置目录 |
|---|---|---|
| krea2 | krea2_turbo_fp8_scaled.safetensors | models/diffusion_models/ |
| krea2 | qwen3vl_4b_fp8_scaled.safetensors | models/text_encoders/ |
| krea2 | qwen_image_vae.safetensors | models/vae/ |
| krea2 | krea2_*.safetensors（风格 LoRA） | models/loras/ |
| image_edit | qwen_image_edit_2511_bf16.safetensors | models/diffusion_models/ |
| image_edit | qwen_2.5_vl_7b_fp8_scaled.safetensors | models/text_encoders/ |
| image_edit | qwen_image_vae.safetensors（与 krea2 共用） | models/vae/ |
| image_edit | Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors（turbo LoRA，仅开 `enable_turbo_mode` 时需要） | models/loras/ |
| minimax | minimax_h3_fl2va_pruned_int8_convrot.safetensors | models/diffusion_models/ |
| minimax | qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors | models/text_encoders/ |
| minimax | minimax_h3_video_vae_fp16.safetensors | models/vae/ |
| minimax | minimax_h3_audio_vae_fp32.safetensors | models/vae/ |

下载地址：Krea-2 → `huggingface.co/Comfy-Org/Krea-2`；Qwen-Image-Edit → `huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI`（VAE 复用 `huggingface.co/Comfy-Org/Qwen-Image_ComfyUI` 的 `qwen_image_vae`，文本编码器取自 `huggingface.co/Comfy-Org/HunyuanVideo_1.5_repackaged`）；Lightning 4 步 LoRA → `huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning`；MiniMax H3 → `huggingface.co/Comfy-Org/MiniMax-H3`。另有 BF16 / NVFP4 等变体可选。

## 故障排查

- 报缺模型：核对文件名与目录是否与上表一致。
- Desktop/Cloud 版可能落后于 nightly，模型支持不全时先更新 ComfyUI。
- 运行时错误反馈到 comfyanonymous/ComfyUI issues；前端问题反馈到 Comfy-Org/ComfyUI_frontend issues。