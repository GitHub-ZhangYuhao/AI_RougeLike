---
name: physics-tuning
description: >
  调整游戏物理以实现稳定且手感良好的运动——包括固定与可变时间步长、渲染插值、质量/重力/阻力设置、连续碰撞检测（CCD）以防止穿模和消除抖动，以及配置碰撞层和掩码；该引擎中立技能适用于用户提及物理手感、抖动、穿模、固定时间步长、FixedUpdate、CCD、弹跳或不稳定物理或碰撞层的场景。
---

# 物理调整

大多数“糟糕的物理”并非引擎的 bug——而是**固定时间步长的模拟**与**可变速率渲染循环**之间的不匹配，或者是未调优的质量/阻力/CCD/层级设置；本技能涵盖使物理稳定且响应迅速的引擎中立旋钮，请配合 `godot-physics` 或 `unity-physics` 使用以获取具体 API。

## 何时使用

- 当运动出现抖动、物体穿过墙壁（穿模）、堆叠爆炸，或移动感觉飘浮/粘滞/卡顿时使用。
- 用于决定哪些内容应放入固定（物理）步骤而非渲染帧，以及如何在这两者之间进行插值。
- 用于调整重力、质量、阻力、恢复系数、求解器迭代次数、休眠以及碰撞层和掩码。

**何时不应用：** 针对引擎的确切物理节点/组件及碰撞回调，请使用 `godot-physics` 或 `unity-physics`。对于*移动决策*（何时跳跃、AI 转向），请使用 `input-systems` 和 `game-ai`。对于平台跳跃游戏中关于跳跃手感的具体细节如助跑时间/跳跃缓冲，那属于输入/控制器范畴——请查看 `input-systems` 以及 `platformer` 类型技能。

## 核心工作流

1. **在固定时间步长上运行物理。** 以恒定速率进行模拟（例如 50–60 Hz）。固定的 `dt` 使模拟变得近似确定且稳定；可变的 `dt` 会使积分和碰撞不一致。
2. **将物理计算放在物理回调中，而非渲染帧内。** 在固定步骤 (`FixedUpdate` / `_physics_process`) 中应用力/速度并读取碰撞，使用该步骤的 `dt`。
3. **在物理 tick 之间插值渲染。** 渲染帧率 ≠ 物理速率，因此应平滑地将变换插值至最新的物理状态，或启用引擎的重心插值功能以消除可见卡顿。
4. **调整物体而非场景。** 设置质量以获得相对重量感，阻力用于阻尼效果，为每个对象单独设置重力缩放比例，并通过材质设置恢复系数和摩擦力。
5. **使用 CCD 防止小/快速物体的穿模；限制最大速度。**
6. **通过增加求解器迭代次数、合理的物体质量比以及休眠机制来稳定堆叠/关节**（针对静止物体）。
7. **通过手感测试和压力验证效果。** 在低帧率和高帧下游玩；将快速物体投向薄墙；堆叠并推挤物体。报告你的观察结果。

## 模式

### 1. 固定时间步长用于模拟，渲染插值用于流畅度

```gdscript
# Physics callback: runs at the FIXED rate. Use its dt for all integration.
func _physics_process(dt):                  # Unity: void FixedUpdate()
    velocity += gravity * dt                # integrate with the FIXED dt
    move_and_slide()                        # engine resolves collisions this step
    _prev_pos = _curr_pos; _curr_pos = global_position   # record for interpolation

# Render frame: runs as fast as the display. Interpolate between physics states.
func _process(_frame_dt):                   # Unity: void Update()
    var alpha = Engine.get_physics_interpolation_fraction()  # 0..1 within the tick
    visual.global_position = _prev_pos.lerp(_curr_pos, alpha)
# RIGHT: integrate in the fixed step, render via interpolation.
# WRONG: applying forces in _process/Update with frame dt — speed and collisions
# then depend on frame rate and jitter under load.
```
大多数引擎均提供该功能（如 Godot 的 `physics_interpolation` / Rigidbody 插值，或 Unity 中的 `Rigidbody.interpolation = Interpolate`），应优先使用其内置功能而非自行实现。

### 2. 防止穿模：CCD + 速度限制

```gdscript
# Fast, small bodies skip past thin colliders between ticks. Two fixes:
body.continuous_cd = true            # RigidBody3D bool (RigidBody2D: CCD_MODE_* enum). Unity: rb.collisionDetectionMode = Continuous
# Cap velocity so a single step can't move more than ~one collider thickness.
const MAX_SPEED := 40.0
if velocity.length() > MAX_SPEED:
    velocity = velocity.normalized() * MAX_SPEED
# Rule of thumb: max_distance_per_step (= speed / physics_hz) should be < the
# thinnest wall. Raise physics_hz or enable CCD when that fails.
```
### 3. 物体调整：质量、阻力、重力缩放、材质

```gdscript
# Mass is RELATIVE weight in collisions; it does NOT change fall speed (gravity
# accelerates all masses equally). Use drag and gravity_scale to shape feel.
body.mass = 2.0                      # heavier pushes lighter in collisions
body.linear_damp = 0.5               # air drag: higher = stops sooner (Unity: drag)
body.gravity_scale = 1.5             # per-object gravity multiplier (snappier fall)
# Bounce/slide come from the physics material, not code:
material.bounce = 0.2                # restitution 0..1 (Unity: bounciness)
material.friction = 0.8              # surface grip
```
### 4. 碰撞层和掩码（谁与谁发生碰撞）

```gdscript
# A body is ON its layer(s) and SCANS the layers in its mask. Both directions of a
# pair must be configured for them to interact.
player.collision_layer = LAYER_PLAYER
player.collision_mask  = LAYER_WORLD | LAYER_ENEMY     # player detects world+enemies
pickup.collision_layer = LAYER_PICKUP
pickup.collision_mask  = LAYER_PLAYER                  # pickup only reacts to player
# Unity equivalent: assign GameObject layers and edit the Physics collision matrix
# (or Physics.IgnoreLayerCollision). Keep a named layer constant table, not magic numbers.
```
## 陷阱

- **在渲染帧中应用力/移动** (`Update`/`_process`) 会使行为依赖于帧率——更快的电脑运行更快，且碰撞变得不稳定。应在固定步骤中进行模拟。
- **即使有固定时间步长仍出现可见抖动**通常意味着没有启用渲染插值：物理速率和显示速率相互冲突。请启用插值功能。
- **穿过薄墙的穿模：** 离散碰撞会漏掉快速移动的物体。启用 CCD、限制速度、加厚墙壁或提高物理频率。
- **期望较重的物体会下落得更快。** 重力是加速度；质量影响碰撞响应，不影响下落速度。使用 `gravity_scale`/阻力来塑造手感。
- **爆炸的堆叠 / 抖动的关节：** 物体间的质量比极端不匹配，或者求解器迭代次数太少。保持质量比例适中并提高迭代次数。
- **永远无法休眠的物体**会消耗 CPU 资源并产生抖动。为静止对象启用休眠功能及合理的休眠阈值。
- **单向层级设置：** A 的掩码包含 B 但 B 的掩码排除 A。检测/碰撞可能需要双向配置；请验证完整矩阵。
- **巨大的 `dt` 尖峰**（负载卡顿、断点）会使积分爆炸。限制最大物理步长/子步数，防止停滞导致一切失控。

## 引用

- `references/timestep-and-ccd.md` — 固定时间步长累加循环，插值数学，子步进，CCD 模式，求解器/迭代调整，休眠以及稳定性检查清单。

## 相关技能

- `godot-physics`, `unity-physics` — 具体物体、碰撞体和回调函数。
- `input-systems` — 响应式控制、跳跃缓冲、助跑时间。
- `game-ai` — 必须与物理步骤保持一致的代理移动逻辑。
- `platformer`, `fps-shooter` — 手感依赖于此类调整的游戏类型。
