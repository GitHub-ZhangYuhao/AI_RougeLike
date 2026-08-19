---
name: platformer
description: >
  构建 2D 平台跳跃游戏：带土狼时间、跳跃缓冲和可变跳跃高度的跑跳控制，
  以及瓦片关卡与危险物。适用于平台跳跃游戏、类 Mario/Celeste 游戏，或调整跳跃手感。
---

# 平台跳跃游戏

2D 平台跳跃游戏开发指南——涵盖跑跳控制器“手感”、关卡结构、危险物和目标。
这是一项**组合式**技能：将引擎移动技能、瓦片地图技能和设计技能整合为可运行的游戏。
它**不会**重复讲解物理或瓦片地图，而是说明要构建什么以及如何让跳跃手感出色。

## 何时使用

- 构建横向卷轴或单屏平台跳跃游戏、“类 Mario”/“类 Celeste”游戏，
  或任何以**在表面之间跳跃**为核心动作的游戏时使用。
- 跳跃感觉漂浮、迟钝或“不公平”，需要通过土狼时间、跳跃缓冲、可变高度、
  边角修正等方式改善手感时使用。

**何时*不*使用：**无重力的俯视角移动 → 直接使用引擎移动技能。3D 第一人称穿越 →
`fps-shooter`。网格/回合制移动 → `roguelike`。对于原始运动学刚体 API，
使用 `godot-2d-movement`（或所用引擎的控制器技能）。

## 核心循环

**观察缺口/危险物 → 决定跳跃或移动 → 安全落地（或死亡）→ 抵达下一个检查点/目标。**
平台跳跃游戏的成败取决于这一个动作在*每时每刻*的手感，而它会重复成千上万次。
先打磨控制器；其余都是内容。

## 必备系统

1. **跑跳控制器**——水平加速/减速、重力、跳跃，以及下述手感辅助机制。
2. **实体 + 单向碰撞**——地面、墙壁和“可从下方穿过”的平台。
3. **关卡几何体**——瓦片地图或手工放置的碰撞体；构成可游玩空间。
4. **危险物 + 死亡/重生**——尖刺、深坑、敌人；重置到上一个检查点。
5. **检查点 / 关卡目标**——进度标记和胜利条件（旗帜、门、出口）。
6. **摄像机**——通过死区和前视跟随玩家，并限制在关卡边界内。
7. **表现力**——落地尘土、挤压/拉伸、命中停顿、声音。成本低，手感收益极高。

## 设计参数（让跳跃手感正确）

按**结果**（以瓦片为单位的高度、以秒为单位的到达顶点时间）调整，而不是直接猜原始数值。

| 参数 | 影响 | 合理起点 |
|------|--------|---------------------|
| 最大跳跃高度 | 可达范围 | 3–4 个瓦片 |
| 到达顶点时间 | “重量感”/爽利度 | 0.30–0.40 s |
| 下落重力倍率 | 爽利、不漂浮的下落 | 上升重力的 1.5–2.0× |
| 土狼时间 | 离开边缘后仍可起跳 | 0.08–0.12 s（@60 时约 5–7 帧） |
| 跳跃缓冲 | 落地前稍早按下仍会起跳 | 0.10–0.15 s |
| 可变跳跃截断 | 轻按 = 小跳，长按 = 完整跳跃 | 松开时将向上速度乘以 0.4–0.5 |
| 顶点滞空 | 在顶点短暂漂浮以便空中控制 | `|vy|`<阈值附近将重力乘以 0.5 |
| 地面加速度 / 摩擦力 | 响应性与冰滑感的取舍 | 在 0.05–0.1 s 内达到最高速度 |
| 边角修正 | 推过仅被边缘卡住 1–2 px 的位置 | 向侧面最多推移约 4 px |

应根据*手感*参数推导重力和跳跃速度，而不是猜测——参见模式 1。

## 模式

### 1. 根据高度 + 时间求解跳跃物理（而非魔法数字）

```python
# Pseudocode. Pick the FEEL you want, then derive the physics. y-axis points DOWN.
# From kinematics: h = (g * t^2) / 2  and  v0 = g * t.
JUMP_HEIGHT   = 3.5 * TILE      # how high, in world units
TIME_TO_APEX  = 0.35            # seconds to reach the top

gravity       = (2 * JUMP_HEIGHT) / (TIME_TO_APEX ** 2)   # rising gravity
jump_velocity = -(2 * JUMP_HEIGHT) / TIME_TO_APEX         # negative = upward
fall_gravity  = gravity * 1.8   # heavier on the way down → less floaty
```

### 2. 土狼时间 + 跳跃缓冲 + 可变高度（手感核心）

```python
# Pseudocode in the per-frame update. dt = seconds since last frame.
# Timers count DOWN; refresh coyote while grounded, buffer on a fresh press.
if on_floor:
    coyote_timer = COYOTE_TIME           # 0.1
if jump_pressed_this_frame:
    buffer_timer = JUMP_BUFFER           # 0.12
coyote_timer -= dt
buffer_timer -= dt

# A jump is allowed if we pressed recently AND were grounded recently.
if buffer_timer > 0 and coyote_timer > 0:
    velocity.y   = jump_velocity
    buffer_timer = 0
    coyote_timer = 0                     # consume both so we can't double-jump

# Variable height: releasing jump early while still rising cuts the arc short.
if jump_released_this_frame and velocity.y < 0:
    velocity.y *= 0.45

# Asymmetric gravity: snappier fall than rise.
g = fall_gravity if velocity.y > 0 else gravity
velocity.y += g * dt
```

### 3. 单向平台

从上方视为实体，从下方可以穿过。大多数引擎会在瓦片/碰撞体上提供“单向碰撞”标志；
启用它，并在玩家按住下 + 跳跃时禁用该碰撞数帧，让玩家可以**向下穿过**。
不要重新实现碰撞数学。

## 陷阱 / 失败模式

- **逐帧移动未按 `dt` 缩放** → 速度随帧率变化。所有速度积分和计时器都必须使用 `dt`。
  （参见 `physics-tuning`。）
- **跳跃漂浮** → 重力对称。让下落重力大于上升重力。
- **“跳跃没有响应”** → 没有输入缓冲。落地前约 0.1 s 内的按键应被缓存。
- **“掉下边缘后无法跳跃”** → 没有土狼时间。离开地面后约 0.1 s 内仍允许跳跃。
- **粘墙 / 卡在瓦片接缝** → 使用单个胶囊/方盒碰撞体，而非逐瓦片碰撞体，并加入边角修正。
- **高速时穿过地面** → 为高速物体启用连续碰撞 / 更小的固定时间步长（参见 `physics-tuning`）。
- **摄像机突跳并引发恶心** → 平滑/插值跟随，加入死区，并限制在边界内。
- **教学不佳造成难度墙** → 每个区域先引入一种机制，再将它们组合起来。

## 组合方式（由以下技能构建）

- **控制器实体：**`godot-2d-movement`（Godot `CharacterBody2D`）；其他引擎使用引擎核心 + 物理技能（`unity-physics`、`phaser-arcade-physics`、`pygame-core`）。
- **关卡：**`godot-tilemap` / `unity-tilemap-2d` 用于几何体；`level-design` 用于布局、节奏和教学顺序。
- **手感/物理：**`physics-tuning` 用于时间步长、CCD 和稳定性。
- **输入：**`input-systems` 用于缓冲、按键重映射和手柄支持。
- **润色：**`audio-design` 用于 SFX/音乐；引擎动画技能用于挤压/拉伸。
- **流程：**先用 `prototype-fast` 对控制器进行灰盒原型验证，再构建内容。

## 参考资料

- 有关跳跃数学推导、完整手感调整表、边角修正、移动/单向平台和摄像机跟随，
  请阅读 `references/feel-tuning.md`。
