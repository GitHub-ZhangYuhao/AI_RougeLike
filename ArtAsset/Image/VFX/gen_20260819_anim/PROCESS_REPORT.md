# 炽热披风爆燃序列帧重抠像报告（2026-08-19）

## 背景

用户反馈「爆燃那一下」表现不足。排查发现源视频（MiniMax H3，124 帧）本身质量合格，
问题出在 BiRefNet（显著性目标分割）抠像：扩散火焰被当作背景侵蚀，迸发峰值帧只剩细弱火苗，
且逐帧掩膜抖动造成覆盖率弧线断裂（slot10 从 82% 骤降到 19.8%）。

结论：不重生成视频，改用亮度型 alpha 重抠像。源视频副本见
`ArtAsset/Video/Effect/MiniMax_H3_cloak_fire_burst_00001_.mp4`（与 gen_20260818_anim/videos/ 源 SHA256 一致）。

## 方法（remat_luma.py）

黑底发光素材的标准做法：

- `a_lin = clip((max(R,G,B) - black_point) / (255 - black_point), 0, 1)`，black_point 取帧边框中位亮度；
- `noise_floor = 0.02` 以下置 0 去噪；
- `alpha = a_lin ^ gamma`，gamma=0.8 增厚光晕；
- RGB 按 `a_lin`（clamp ≥0.10）反乘得 straight alpha，透明区 bleed-radius 24 从最近可见像素填充（防双线性过滤黑边）。

无 ONNX 模型依赖，124 帧 12.2s（CPU numpy），逐帧连续无时序抖动。

## 覆盖率弧线对比（25 个采样槽，visible_fraction）

| 阶段 | 旧 BiRefNet | 新亮度 alpha |
| --- | --- | --- |
| 蓄力 slot0–4 | 23.9–52.3% | 53.0–71.7% |
| 迸发 slot5–11 | 19.8–82.0%（slot10 断裂） | 81.9–87.7%（持续饱满） |
| 渐散 slot12–19 | 11.2–47.3%（抖动） | 13.0–52.7%（单调渐散） |
| 收尾 slot20–24 | 2.9→0.07% | 9.3→0.00% |

## 图集

沿用硬规格（`logic/systems/flipbook.gd` 依赖，未改动）：2000×2000 RGBA8 straight alpha，
5×5，cell 400×400，content 384×384 居中，gutter 8，行优先 0–24 一次性播放，fps 4.8387。

替换三处同一 blob：

- `ArtAsset/Image/VFX/gen_20260818_anim/cloak_flipbook/sprite_sheet_5x5_25f_2000.png`
- `ArtAsset/Image/VFX/gen_20260818_anim/final/cloak_fire_burst_anim.png`
- `GameProject/assets/vfx/cloak_fire_burst_anim.png`

体积 3,272,723 → 3,888,494 字节（火焰内容更饱满，PNG 熵增）。

## QA

- frames_alpha=124，与 frames_raw 一致；alpha 范围 0–255。
- checker_preview 目检：网格顺序正确、无串色、透明底干净；迸发段明亮饱满，消散段单调渐隐。
- 暗底合成对比（raw vs 旧 vs 新）：新抠像完整保留爆燃主体与光晕，旧版仅剩火苗。
- Godot smoke / 原型 smoke 双绿（见提交前验证）。
