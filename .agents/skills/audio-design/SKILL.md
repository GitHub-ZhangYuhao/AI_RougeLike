---
name: audio-design
description: >
  实现游戏音频实践——总线/混音器架构与分贝增益，侧链（ducking）、通过分层和重排序实现的自适应/动态音乐、音效变化以及节拍同步。引擎无关。当用户提及音频混合、音频总线、自适应/动态音乐、侧链、音效变化、音乐层或将游戏玩法与节拍同步时使用此技能。
---

# 音频设计

游戏音频由**混音图与音乐系统组成**。将每个声音路由至一组总线，以便进行平衡和处理；通过分层和重排序使音乐能够*响应*玩法而非循环播放单一曲目。本技能教授可移植的实践方法：将其绑定到 `godot-audio`、Unity 的 AudioMixer 或中间件（FMOD/Wwise）以获取具体 API。

## 何时使用

- 用于设计总线/混音器布局，设置群组音量并应用效果（混响、压缩、均衡器）于声音群组。
- 用于在对话或冲击下降低音乐/环境音的音量（侧链）。
- 用于构建对战斗/探索强度做出反应的自适应音乐。
- 用于添加音效变化（音调/样本随机化）并将事件同步到节拍上。

**何时*不*使用：**对于引擎的具体音频节点/流，请使用 `godot-audio` 或该引擎的音频技能。加载/传输和资产导入是引擎相关事项。针对驱动总线音量的 UI 滑块，请参阅引擎 UI 技能。

## 核心工作流

1. **布局总线而非单个声音音量。**典型树状结构：`Master ← {Music, SFX, Ambience, UI, Voice}`。所有声音都播放到总线上；玩家设置滑块映射为总线音量。永远不要手动设置数百个剪辑的音量。
2. **使用分贝而非线性值工作。**感知响度是对数性的。音量和自动化应在 dB 下运行，仅在边缘进行转换。
3. **保留余量（Headroom）。**在混音过程中，请确保主输出峰值低于 0 dBFS（考虑到许多游戏的目标响度约为 -14 至 -16 LUFS），以防止削波失真。
4. **使用侧链压缩器或音量自动化降低竞争源：**当语音/重要音效播放时，音乐总线下降，然后恢复。
5. **通过*垂直*分层（渐隐渐出的干声）和/或 *水平*重排序（在音乐边界处交换片段）使音乐自适应。**参见参考文档。
6. **使用小范围的随机音调/音量偏移和样本池来变化重复的音效**，使得脚步声和打击感听起来不机械。
7. **在实际输出上验证。**佩戴耳机并使用扬声器试听；检查混音是否平衡、侧链效果可闻但不产生泵动效应（pumping），音乐过渡是否落在节拍上——不要仅凭编辑器电平表假设结果。

## 模式

### 1. 总线路由与 dB 增益

```gdscript
# Route sounds to named buses; control GROUPS, not individual clips.
sfx_player.bus = "SFX"
music_player.bus = "Music"

# Map a 0..1 settings slider to decibels (linear_to_db), the perceptual unit.
func set_bus_volume(bus_name: String, slider01: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    var db := linear_to_db(clamp(slider01, 0.0001, 1.0))   # 0 -> silence, 1 -> 0 dB
    AudioServer.set_bus_volume_db(idx, db)
# RIGHT: slider -> dB via linear_to_db. WRONG: assigning slider01 straight as dB
# (a "0.5" would be only +0.5 dB — almost no change — and 0 would be 0 dB, full).
```
### 2. 通过侧链进行 Ducking（音乐在语音下下降）

```gdscript
# A compressor on the MUSIC bus, keyed by the VOICE bus, lowers music while
# dialogue plays, then releases. This is "sidechain ducking".
# Setup (engine-specific): add a compressor effect to the Music bus and set its
# sidechain to the Voice bus. Then tune:
#   threshold: level on Voice that triggers ducking (e.g. -30 dB)
#   ratio:     how hard to duck (e.g. 8:1 for a clear dip)
#   attack:    fast (~10 ms) so music gets out of the way promptly
#   release:   slow (~300-500 ms) so it recovers smoothly, not pumping
# No-middleware alternative: tween the Music bus volume down on voice start and
# back up on voice end.
func duck_music(active: bool) -> void:
    var target_db := -12.0 if active else 0.0
    create_tween().tween_method(
        func(v): set_bus_volume_db("Music", v), current_music_db, target_db, 0.25)
```
### 3. 音效变化（消除“机枪”重复感）

```gdscript
# Randomize pitch slightly and pick from a sample pool so repeats feel organic.
func play_varied(samples: Array, bus := "SFX") -> void:
    var p := AudioStreamPlayer.new()
    p.stream = samples[randi() % samples.size()]   # rotate through several takes
    p.bus = bus
    p.pitch_scale = randf_range(0.94, 1.06)         # +/- ~6% pitch wobble
    add_child(p); p.play()
    p.finished.connect(p.queue_free)                # clean up one-shots
```
### 4. 节拍同步事件（量化到音乐网格）

```gdscript
# Schedule gameplay/visuals on musical time, not frame time, so they land on beat.
const BPM := 120.0
var seconds_per_beat := 60.0 / BPM

func current_beat(playback_position_sec: float) -> int:
    return int(playback_position_sec / seconds_per_beat)

# Quantize an action to the NEXT beat boundary instead of firing immediately.
func time_until_next_beat(pos: float) -> float:
    return seconds_per_beat - fmod(pos, seconds_per_beat)
# Drive timing from the audio playback clock, which is steadier than frame delta.
```
## 陷阱

- **将滑块值视为 dB。**音量是对数性的；通过 `linear_to_db` 映射 `0..1`（并使用 `db_to_linear` 反向转换）。线性滑块在原始振幅上感觉几乎无效，直到非常底部。
- **使用单个剪辑的音量和总线**使得全局平衡处理不可能并膨胀保存/设置文件。请在总线上进行混音。
- **主输出削波**。声音电平超出 0 dBFS 会产生失真；请预留动态余量，并将限幅器置于主输出通道作为保护手段，而非直接应用于混音总线。
- **泵动式 Ducking：**过快的释放时间或过高的比率会使音乐产生可闻的呼吸感（breathe）。延长释放时间并降低比率。
- **为整个游戏循环单一音乐曲目**会显得平淡无奇。使用分层或响应状态的片段（参见参考文档）。
- **节拍同步基于帧时间。**`delta` 会有漂移；读取**音频播放位置**进行音乐计时，并考虑输出延迟。
- **不受控制的单音播放器：**创建 AudioStreamPlayers 而不释放它们会导致内存泄漏。在 `finished` 时释放或使用小型池。

## 引用文档

- `references/adaptive-music.md` —— 垂直分层与水平重排序、过渡时机（小节/量化）、打击乐音效（stingers）和强度映射以及交叉淡入淡出。

## 相关技能

- `godot-audio` —— Godot 中的总线、`AudioStreamPlayer`、效果和节拍同步。
- `input-systems` —— 从输入动作触发音频。
- `physics-tuning`——驱动冲击音效的碰撞事件。
- `platformer`, `roguelike` —— 其手感依赖音频反馈的类型。
