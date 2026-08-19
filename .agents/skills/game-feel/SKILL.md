---
name: game-feel
description: >
  添加“爽快感”和游戏质感以提升动作体验——包括屏幕震动、打击停顿（冻结帧）、缓动运动、挤压与拉伸、击退以及分层视听反馈；这些是引擎无关的技术，可与检测到的游戏引擎的缓动、粒子及相机 API 配合使用。当用户提及游戏质感（game feel）、爽快感（juice）“让它感觉良好/有冲击力”、屏幕震动、打击停顿、屏幕冻结、缓动曲线、挤压与拉伸、冲击帧或击中时的反馈/打磨时，请使用此技能。
---

# 游戏手感（Juice）

一个机制能够*运作*与其让人感觉*美好*之间的区别在于反馈：动作引发的分层且略带夸张的反应。本技能涵盖引擎无关的技术——屏幕震动、打击停止、缓动曲线、挤压与拉伸、击退以及叠加的反馈，并告诉你如何应用它们而不会掩盖底层的模拟逻辑。它**在现有机制之上增加打磨效果**；它不实现该机制本身。

## 何时使用

- 当某个动作（击中、跳跃、冲刺、拾取、死亡、按钮按下）在机械上正确但感觉薄弱、轻盈或不令人满意，且你希望其感觉响应迅速并有冲击力时使用。
- 用于添加屏幕震动、打击停止/冻结帧、缓动运动、挤压与拉伸、闪光效果，或为单一事件叠加多个反馈通道时。
- 用于决定*多少*爽快感足够以及何时它会变成噪音。

**当不使用时：**针对原始控制器数学（跳跃高度、Coyote time），请采用 `platformer` 流派和引擎移动技能；针对相机*跟随/死区/轨道*构图，请使用 `camera-systems`（本技能仅触发震动）；针对混音、ducking 和自适应音乐，请使用 `audio-design`；用于基于着色器的溶解/闪光效果，请采用 `shader-programming` 和引擎着色器技能；针对具体的缓动/粒子节点 API，请使用该引擎的动画技能 (`godot-animation`, `unity-animation`)。

## 核心原则：反馈应分层且适度夸张

一次令人满意的击中通常由**5–8 个微小的反应同时触发**组成（约在 ~100 ms 内）：声音、粒子爆发、短暂的打击停止、闪光、击退、小幅屏幕震动以及一个数字弹出。每一个都很便宜；叠加起来，它们读作“冲击力”。两条规则防止其变得混乱：** (1)** *短暂地*夸张并返回静止状态（爽快感是瞬时的，而非新的静止状态）；** (2)** 根据事件重要性缩放爽快感——脚步声不等于 Boss 死亡。

## 核心工作流

1. **确认事件钩子存在。** 爽快感附着于离散的事件：`on_hit`, `on_land`, `on_pickup`, `on_death`, `on_fire`。如果机制不发射这些，请先添加它们。
2. **为每个事件从菜单中选择反馈通道**（声音、粒子、震动、打击停止、闪光、击退、缓动、数字弹出）。先从 2–3 个开始；直到读感良好为止再增加或停止。
3. **赋予运动缓动感，避免使用非线性插值。** 为缩放、位置和 UI 变更的路由配置带缓动曲线的缓动函数（例如：用于“弹出”效果的过冲曲线 `overshoot`，或用于“稳定”效果的外推曲线 `ease-out`）。线性运动会显得像机器人。
4. **为冲击效果保留打击停止和震动。** 它们是强大且易被滥用的工具——持续时间短，根据重要性缩放，绝不在常规动作上使用。
5. **将反馈置于关键模拟之外。** 震动的对象是*相机/视觉*而非身体；打击停止使用时间比例或实时暂停，而非游戏逻辑停滞。
6. **通过重要性层级进行调优。** 定义小/中/大反馈预设并将事件分配至相应层级，使整个游戏的爽快感保持一致且成比例。
7. **通过游玩和观察来验证。** 重复触发该事件；确认反馈已触发、返回静止状态且不令人作呕或阻塞输入。报告你的观察结果（震动是否衰减？在打击停止期间输入是否仍能注册？）。

## 模式

### 1. 通过衰减的“创伤”实现屏幕震动（平滑，非随机抖动）

```gdscript
# Godot 4.7. Store trauma 0..1; shake = trauma^2 so small hits barely move, big hits punch.
# Drives a Camera2D OFFSET (the visual), never the player body. Decays every frame.
@export var decay := 1.2          # trauma lost per second
@export var max_offset := Vector2(12, 8)
@export var max_roll := 0.1       # radians
var trauma := 0.0
var _t := 0.0

func add_trauma(amount: float) -> void:
    trauma = clampf(trauma + amount, 0.0, 1.0)   # hits ADD; they don't reset

func _process(dt: float) -> void:
    if trauma <= 0.0: return
    trauma = maxf(trauma - decay * dt, 0.0)
    var shake := trauma * trauma                  # quadratic: gentle low, sharp high
    _t += dt * 30.0
    # Smooth pseudo-random via sampled noise/sin, NOT rand each frame (that buzzes).
    offset = Vector2(max_offset.x * shake * sin(_t * 1.7),
                     max_offset.y * shake * sin(_t * 2.3))
    rotation = max_roll * shake * sin(_t * 1.1)
# Unity 6.3 LTS: identical model on a CinemachineCamera via CinemachineBasicMultiChannelPerlin
# (set AmplitudeGain/FrequencyGain from trauma^2) — see camera-systems.
```
### 2. 打击停止/定格画面（通过短暂暂停时间来表现冲击力）

```gdscript
# Godot 4.7. Drop time scale, then restore after a REAL-TIME delay (unaffected by time_scale).
func hit_stop(duration := 0.08, scale := 0.05) -> void:
    Engine.time_scale = scale
    # 4th arg ignore_time_scale=true → the timer still fires while the game is frozen.
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
```
```csharp
// Unity 6.3 LTS (C#). WaitForSecondsRealtime ignores Time.timeScale, so the timer still elapses.
IEnumerator HitStop(float duration = 0.08f, float scale = 0.05f) {
    Time.timeScale = scale;
    yield return new WaitForSecondsRealtime(duration);
    Time.timeScale = 1f;            // RIGHT: real-time wait. WRONG: WaitForSeconds (never resumes at scale 0)
}
```
### 3. 通过缓动动画（"弹跳"）实现挤压与拉伸及过冲效果

```gdscript
# Godot 4.7. Conserve volume: stretch one axis, squash the other, then spring back with overshoot.
func pop(node: Node2D) -> void:
    node.scale = Vector2(1.3, 0.7)                       # instant squash on the event
    var tw := create_tween()
    tw.tween_property(node, "scale", Vector2.ONE, 0.18) \
      .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # BACK = overshoots past 1, settles
# RIGHT: ease back (TRANS_BACK/ELASTIC) for life. WRONG: linear tween → mechanical, dead.
```
### 4. 按重要性缩放的反馈包（保持爽感比例）

```gdscript
# One call per event; the tier decides intensity so the whole game stays consistent.
func feedback(event_pos: Vector2, tier: String) -> void:
    match tier:
        "small":  AudioBus.play("tick");  Camera.add_trauma(0.15)
        "medium": AudioBus.play("hit");   Camera.add_trauma(0.4);  hit_stop(0.05); spawn_particles(event_pos, 6)
        "large":  AudioBus.play("boom");  Camera.add_trauma(0.8);  hit_stop(0.12); spawn_particles(event_pos, 30); flash_white(0.06)
```
## 常见陷阱

- 摇晃玩家/身体而非相机偏移会导致碰撞与瞄准不同步，请晃动相机（或视觉枢轴），切勿晃动模拟变换。
- 每帧随机偏移的蜂鸣声如同静电干扰；通过采样噪声/正弦波和衰减创伤值产生的震动效果使其平滑且自动结束。
- 使用 `WaitForSeconds`/缩放计时器进行“打击停止”后，无论何时都不会恢复（在时间比例为 0 时计时器永远不会推进）。请使用实时等待 (`WaitForSecondsRealtime`) 或 Godot 的忽略时间比例计时器。
- 每次挥击的每一帧都会发生 Hit-stop，这会锁定游戏。每撞击一次触发一次。
- 所有的 `Linear` Tween 看起来都很生硬；请在绝大多数动画中应用缓动函数，仅在需要“弹出”效果时使用回弹或弹性曲线（BACK/ELASTIC），而在需要“沉降”效果时则使用减速曲线。
- **永久性夸张**（缩放永不恢复，震动永不衰减）成为新常态并停止被视为反馈。Juice 必须回归静止状态。
- 过度强化常规动作（每个脚步都进行全屏晃动和打击停顿）会导致恶心并掩盖真实冲击；应根据重要性进行调整，并提供“减少屏幕震动”/“减少闪烁”的可访问性选项。
- 会阻塞输入的反馈（长时间冻结、无法取消的动画）会降低响应速度。保持“果汁”短暂，并让输入缓冲穿过它。

## 参考资料

- 对于创伤震动数学、缓动曲线速查表（哪种缓动适合弹出与稳定）、击退加闪光加数字弹出的配方、重要性等级预设，以及每个引擎的 Tween/粒子绑定，请阅读`references/feedback-recipes.md`。

## 相关技能

- `camera-systems`——拥有相机跟随/死区/轨道功能；该技能仅为其提供震动创伤效果。
- `godot-animation` 和 `unity-animation`——专为 Tween、Animation Player 及粒子系统提供流畅动画效果的插件。
- `audio-design` —— 每个反馈包的声音层；动态降噪和音效变化。
- `physics-tuning`——击退力和时间步长调整必须保持稳定，不得导致系统失稳。
- `platformer`，`fps-shooter`，`roguelike` —— 这些类型因其瞬间的即时的感觉而提升。
