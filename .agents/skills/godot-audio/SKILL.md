---
name: godot-audio
description: >
  在 Godot 4.7 中播放和混合音频：AudioStreamPlayer（2D/3D 变体）、具有音量/静音和
  效果的音频总线、音乐与 SFX 路由、db/线性音量，以及精确的节拍同步播放时序。
  在 Godot 项目中播放声音或音乐、将 AudioStreamPlayer 节点路由至总线、
  通过 AudioServer 调整总线音量，或将游戏玩法同步到节拍时使用。
---

# Godot 音频 (4.x)

播放 SFX 和音乐，将其路由到总线，以分贝控制音量，并使游戏玩法与节拍同步。
适用于 **Godot 4.7**。

## 何时使用

- 播放音效或音乐、将音频路由到总线（Master/Music/SFX）、从代码调整音量/静音、
  添加总线效果（混响、压缩器）、使用定位 3D 音频，或将事件同步到音乐时使用。

**不应使用的情况：** 与引擎无关的音频*设计*（自适应音乐结构、混音理念、
ducking 模式）→ `audio-design`；在 Godot 外部导入/编码资产。

## 核心工作流

1. **选择播放器节点：**
   - `AudioStreamPlayer` — 非定位音频（音乐、UI、全局 SFX）。
   - `AudioStreamPlayer2D` / `AudioStreamPlayer3D` — 定位音频；根据距离决定音量/声像。
2. 将 `AudioStream` 分配给 `stream`（音乐/循环使用 `.ogg`，短 SFX 使用 `.wav`），
   然后调用 `play()`。对于随场景开始的音乐，设置 `autoplay`。
3. **路由至总线。** 将播放器的 `bus` 设为命名总线（例如 `"Music"`、`"SFX"`）。
   在 Audio 面板（底部 dock）中定义总线；每条总线都可设置音量、静音、solo 和效果。
4. **以 dB 控制音量**，而非线性值（音频是对数的）。`0 dB` = 不变，`-80 dB` ≈ 静音。
   使用 `linear_to_db`/`db_to_linear` 进行转换。
5. 通过总线索引，使用 `AudioServer` **从代码驱动音量/静音**。
6. **对于节奏游戏**，使用输出延迟补偿计算精确的播放时间。

## 模式

### 1. 一次性 SFX（用后即弃）

```gdscript
@onready var sfx: AudioStreamPlayer = $Sfx   # stream assigned in the editor

func play_jump() -> void:
    sfx.pitch_scale = randf_range(0.95, 1.05)   # slight variation avoids fatigue
    sfx.play()

# For many overlapping copies, use an AudioStreamPlayer with an
# AudioStreamPolyphonic stream, or spawn short-lived players and free on `finished`.
```

### 2. 通过 AudioServer 设置总线音量与静音

```gdscript
func set_music_volume(linear_0_to_1: float) -> void:
    var bus := AudioServer.get_bus_index("Music")
    # Convert a 0..1 slider to decibels; clamp avoids -inf at 0.
    AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear_0_to_1, 0.0001)))

func toggle_sfx(muted: bool) -> void:
    AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), muted)
```

### 3. 在两首音乐之间交叉淡化

```gdscript
@onready var a: AudioStreamPlayer = $MusicA
@onready var b: AudioStreamPlayer = $MusicB

func crossfade_to(stream: AudioStream, secs := 1.5) -> void:
    b.stream = stream
    b.volume_db = -40.0
    b.play()
    var tw := create_tween().set_parallel(true)
    tw.tween_property(a, "volume_db", -40.0, secs)   # fade out current
    tw.tween_property(b, "volume_db", 0.0, secs)     # fade in next
    tw.chain().tween_callback(a.stop)
    var tmp := a; a = b; b = tmp                      # swap roles
```

### 4. 节拍精确时序（补偿输出延迟）

```gdscript
@onready var music: AudioStreamPlayer = $Music

func get_playback_time() -> float:
    # Add time since the last audio mix, subtract output latency, for sub-frame accuracy.
    var t := music.get_playback_position() + AudioServer.get_time_since_last_mix()
    return t - AudioServer.get_output_latency()
```

## 常见陷阱

- **将音量视为线性值。** `volume_db`/`set_bus_volume_db` 使用分贝。
  设置 `volume_db = 0.5` 接近全音量，而非一半。使用 `linear_to_db` 映射滑块。
- **`linear_to_db(0.0)` 为 `-inf`。** 转换前将线性值限制到一个较小的最小值
  （例如 `0.0001`），或对 0 作特殊处理 → 静音。
- **总线名称拼写错误会静默失败。** `get_bus_index("Muisc")` 返回 `-1`；随后调用会报错
  或不执行任何操作。应与 Audio 面板中的总线名称完全匹配。
- 当同一播放器被重新触发时，**短 SFX 会被截断**。使用独立播放器、
  `AudioStreamPolyphonic`，或每次使用一个并在 `finished` 时释放的 `AudioStreamPlayer`。
- **音乐不会循环**，除非启用导入/stream 循环（`.ogg` 导入有 Loop 选项；
  `AudioStreamWAV` 有 `loop_mode`）。
- **仅同步到 `get_playback_position()` 会抖动**——它按音频混合而非每帧更新；
  添加 `get_time_since_last_mix()` 并减去 `get_output_latency()`。
- **3D 音频听不到** → 没有用于聆听的 `AudioListener3D`/`Camera3D`，或
  `max_distance`/衰减过强，或错误的总线被静音。

## 参考资料

- 有关总线布局（`.tres`）、添加效果（混响/压缩器/EQ）和 side-chain ducking、
  `AudioStreamPolyphonic`/`AudioStreamInteractive`、麦克风捕获，以及使用
  `AudioStreamGenerator` 生成程序化音频，请阅读 `references/buses-and-effects.md`。

## 相关 skill

- `audio-design` — 与引擎无关的自适应音乐、混音和 ducking 实践。
- `godot-animation` — 将动画/Tween 同步到 `get_playback_position()`。
- `godot-ui-control` — 连接到 `AudioServer` 的音量滑块。
