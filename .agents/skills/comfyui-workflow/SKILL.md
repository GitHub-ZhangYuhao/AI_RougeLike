---
name: comfyui-workflow
description: ComfyUI 工作流模板：Krea-2 Turbo 文生图（text-to-image，支持风格 LoRA）与 MiniMax H3 首尾帧图生视频（first/last-frame to video，原生立体声音频）。当用户需要用 ComfyUI 生成图片、把图片作为首帧/尾帧生成视频、制作角色待机或循环动画视频，或询问 Krea-2、MiniMax H3 工作流的模型清单、节点参数时使用。
---

# ComfyUI Workflow

两个可直接导入 ComfyUI 的 UI 格式工作流模板。本 skill 完全自包含，只使用 skill 目录内的文件。

| 文件 | 用途 | 模型 |
|---|---|---|
| `workflows/krea2_t2i.json` | 文生图（text-to-image），内置提示词增强与 9 种风格 LoRA 切换 | Krea-2 Turbo |
| `workflows/minimax_h3_i2v.json` | 首帧/尾帧图生视频（fl2va），输出带原生立体声音频的 24fps 视频 | MiniMax H3 |

## 导入与运行

1. 将 `workflows/` 下对应 JSON 拖入 ComfyUI 界面（或 Load）加载。
2. 按「模型清单」确认权重已放入对应目录，且 ComfyUI 已更新到最新版。
3. 点击运行。

## 推荐流水线：图 → 视频

1. 用 `krea2_t2i.json` 生成角色/场景图。
2. 在 `minimax_h3_i2v.json` 的 LoadImage 中选中该图作为 `first_frame`（默认同一张图同时接 `last_frame` 以生成无缝循环；若要首尾不同的帧，改接第二张图到 `last_frame`）。
3. 编写运动 + 音频提示词后运行，得到带声音的循环动画视频。

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
| minimax | minimax_h3_fl2va_pruned_int8_convrot.safetensors | models/diffusion_models/ |
| minimax | qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors | models/text_encoders/ |
| minimax | minimax_h3_video_vae_fp16.safetensors | models/vae/ |
| minimax | minimax_h3_audio_vae_fp32.safetensors | models/vae/ |

下载地址：Krea-2 → `huggingface.co/Comfy-Org/Krea-2`；MiniMax H3 → `huggingface.co/Comfy-Org/MiniMax-H3`。另有 BF16 / NVFP4 等变体可选。

## 故障排查

- 报缺模型：核对文件名与目录是否与上表一致。
- Desktop/Cloud 版可能落后于 nightly，模型支持不全时先更新 ComfyUI。
- 运行时错误反馈到 comfyanonymous/ComfyUI issues；前端问题反馈到 Comfy-Org/ComfyUI_frontend issues。
