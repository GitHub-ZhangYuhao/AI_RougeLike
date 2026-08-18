# 序列帧图集生产报告（agent β，2026-08-18）

管线：Krea-2 Turbo 文生图关键帧 → MiniMax H3 图生视频 → video-to-alpha-flipbook（BiRefNet 抠像 + 5×5 图集）。
ComfyUI 服务：http://127.0.0.1:8188（v0.31.1，API 格式 graph 直连）。

## 1. furnace_flame_anim.png（火行路径火焰循环）

- 关键帧：keyframes/kf_furnace_loop_final.png；Krea-2 Turbo（krea2_turbo_fp8_scaled + qwen3vl_4b clip + qwen_image_vae），768×768，8 步 euler/simple，CFG 1.0，seed 2026081801。
- 视频：videos/MiniMax_H3_furnace_flame_loop_00001_.mp4；MiniMax H3（minimax_h3_fl2va_pruned_int8_convrot + qwen3vl_32b_minimax_h3_nvfp4_awq + minimax_h3_video_vae_fp16），first_frame=last_frame=同一关键帧（锁首尾保证循环），768×768，length=124 @24fps = 5.1667s，20 步 res_multistep/simple，noise_seed 2026081811。prompt 见 driver_comfy.py VIDEOS["furnace_flame_loop"]。
- 抽帧：124 帧均匀抽 25 帧（含首尾，步长 5.125）。
- 抠像：birefnet-general-lite（DirectML），bleed-radius 24；frames_raw=frames_alpha=124。
- 图集：2000×2000 RGBA8 straight alpha，5×5，cell 400×400，content 384×384 居中，transparent gutter 8。
- 接缝修正：BiRefNet 逐帧 alpha 抖动（相邻帧约 21/255）使原始抠像首尾差约 43/255，而视频原始首尾差仅 0.77/255；因首尾帧同源同关键帧，将 slot24 单元直接复制 slot0 内容，实现完美接缝。
- 播放规格：行优先 0–24；建议 fps 4.8387（=25/5.1667）；循环区间 0–23（24 个唯一帧，frame24 为 frame0 的接缝副本）；帧尺寸 400×400 cell / 384×384 内容。

## 2. cloak_fire_burst_anim.png（炽热披风 Lv6 爆发，一次性）

- 关键帧：keyframes/kf_cloak_charge_final.png；Krea-2 Turbo，seed 2026081802（单关键帧，按用户确认管线）。
- 视频：videos/MiniMax_H3_cloak_fire_burst_00001_.mp4；MiniMax H3，仅 first_frame（无 last_frame），768×768，124 @24fps = 5.1667s，20 步 res_multistep，noise_seed 2026081812。prompt：charge→burst→dissipate 一次性序列（见 cloak_single.py）。
- 抽帧/抠像/图集：同 furnace（25 帧均匀含首尾；124=124；BiRefNet general-lite）。
- 覆盖率弧线（行优先 25 格）：22→48%（蓄力）→ 54–76%（迸发峰值 frame9）→ 渐散 → 0.06%（frame24 近全透明），符合蓄力-迸发-消散。
- 播放规格：行优先 0–24 一次性播放，不循环；建议 fps 4.8387；帧尺寸同 furnace。

## QA 结论
- 两图集均 RGBA8，alpha 0–255；frames_raw 与 frames_alpha 数量一致（124）。
- checker_preview 目检：透明底干净、无黑底残留、无单元串色、网格顺序正确。
- furnace 帧覆盖率 6–10% 稳定连贯；cloak 弧线完整；消散段有火焰固有闪烁（可接受）。

## 归档
ArtAsset/Image/VFX/gen_20260818_anim/（沿用 gen_YYYYMMDD 命名）：keyframes/、videos/、furnace_flipbook/、cloak_flipbook/、final/、driver_comfy.py、cloak_single.py、各日志。

## 问题记录
1. 旧双关键帧 cloak 任务与用户最新确认的单关键帧管线不符：已取消队列任务（/queue delete + /interrupt）并重排单关键帧版本；kf_cloak_fade_final.png 作为未用概念图留存归档。
2. BiRefNet 时序抖动 → furnace 做了 slot24:=slot0 接缝修正（见上）。
3. 共享 ComfyUI 队列存在他人任务，排队等待属正常。
4. 4.84 fps 为 25 帧覆盖 5.17s 的固有结果；如需更顺滑可提 fps（会缩短感知时长），属集成侧权衡。
