---
name: input-systems
description: >
  构建游戏输入系统——动作映射（将按键抽象为命名动作）、带冲突检测与持久化的重绑定、多设备支持（键盘、手柄、触控），以及模拟摇杆死区等手感特性，如输入缓冲和跳跃提前期，还有无障碍功能。引擎中立。当用户提及输入映射、重新绑定控制、手柄支持、死区、输入缓冲、跳跃提前期或可访问性控制时使用此技能。
---

# 输入系统

永远不要将游戏逻辑直接连接到原始按键。将物理输入（一个键、一个按钮、一次触控）映射到命名的**动作** (`jump`, `interact`, `move`)，让游戏逻辑读取这些动作。这一层间接处理为你带来了几乎免费的重新绑定功能、多设备支持和无障碍性。本技能是引擎中立的架构；可将其绑定至 `unity-input-system`、`unreal-enhanced-input` 或 Godot 的 `InputMap`。

## 何时使用

- 用于设计输入层：动作、绑定、多种设备及带冲突检测与保存绑定的重新绑定 UI。
- 用于添加模拟处理（死区、灵敏度）和游戏手感特性（输入缓冲、跳跃提前期）。
- 用于使控制具备无障碍性（完整重映射、按住 vs 切换、灵敏度、无需同时按下多个键）。

**何时 *不* 使用：** 对于引擎的具体输入包/API，请使用 `unity-input-system`、`unreal-enhanced-input` 或 Godot 的 InputMap；关于为移动/跳跃 **物理模拟** 提供缓冲的数据流，请参阅 `physics-tuning` 和引擎的移动技能；将绑定持久化到磁盘属于 `save-systems`。

## 核心工作流

1. **定义动作而非按键。** 游戏逻辑询问“是否按下了 `jump`"，绝不再问“是否按下了 Space"。动作为稳定的契约；绑定为数据。
2. **为每个设备绑定。** 每个动作持有键盘、手柄和触控的对应绑定。活跃的设备是最后发送输入的那个设备；切换 UI 提示以匹配当前设备。
3. **读取正确的边缘信号。** 对于离散动作（跳跃、交互），使用 *本帧按下* (edge)；对于连续动作（移动、瞄准），使用 *持续按住* (level)。混淆两者会导致重复触发或漏按。
4. **过滤模拟输入。** 对摇杆/扳机应用死区，使静止漂移读数为零，并根据喜好调整灵敏度曲线。
5. **缓冲以提升手感。** 记住一个稍早按下动作的短暂窗口，以便稍早的按压仍能触发（输入缓冲）；允许在离开边缘后不久仍进行跳跃（跳跃提前期）。
6. **将重新绑定作为一等公民对待。** 提供一个能捕获下一个输入、检测冲突并持久化绑定的 UI——以及重置为默认值的选项。通过 `save-systems` 保存。
7. **在所有设备上验证**，并在重绑定时：键盘、手柄、触控；在游戏过程中重新绑定一个动作，确认游戏逻辑和提示随之更新。

## 模式

### 1. 使用动作而非原始按键；区分边缘与持续状态

```gdscript
# Gameplay reads ACTIONS. The mapping from key/button to action lives in data.
# Discrete (edge): fire once on the press frame.
if Input.is_action_just_pressed("jump"):
    try_jump()
# Continuous (held): read every frame as an axis.
var move := Input.get_axis("move_left", "move_right")   # -1..1
player.velocity.x = move * RUN_SPEED
# RIGHT: name actions ("jump"); rebinding/devices just change the binding data.
# WRONG: `if Input.is_key_pressed(KEY_SPACE)` — unrebindable, keyboard-only,
# and `is_key_pressed` is a held check that would re-fire jump every frame.
```
引擎等效实现：Godot 的 `InputMap` 与 `Input.is_action_just_pressed`，Unity 输入系统的 `InputAction`/动作映射表；Unreal Engine 增强型输入的“输入操作”（Input Actions）+ “输入映射上下文”（Input Mapping Contexts）。

### 2. 模拟死区与灵敏度

```gdscript
# Raw sticks never rest at exactly zero. Apply a RADIAL deadzone (on the vector
# length), not per-axis, so diagonals aren't clipped into the axes.
func apply_deadzone(stick: Vector2, dead := 0.2, sens := 1.0) -> Vector2:
    var mag := stick.length()
    if mag < dead:
        return Vector2.ZERO                      # inside deadzone -> no movement
    # Rescale so motion ramps from 0 at the edge of the deadzone, not from `dead`.
    var scaled := (mag - dead) / (1.0 - dead)
    return stick.normalized() * pow(scaled, sens)  # sens>1 = finer near center
# WRONG: clamping each axis separately — it carves a square hole and snaps to axes.
```
### 3. 输入缓冲 + 跳跃提前期（宽容、响应式手感）

```gdscript
# Buffer: a jump pressed slightly BEFORE landing still triggers on touchdown.
# Coyote: a jump pressed slightly AFTER walking off a ledge still works.
const BUFFER := 0.12   # seconds an early press stays "remembered"
const COYOTE := 0.10   # seconds after leaving ground you can still jump
var _buffer_timer := 0.0
var _coyote_timer := 0.0

func _physics_process(dt):
    _buffer_timer -= dt
    _coyote_timer = COYOTE if is_on_floor() else _coyote_timer - dt
    if Input.is_action_just_pressed("jump"):
        _buffer_timer = BUFFER                  # remember the press
    if _buffer_timer > 0.0 and _coyote_timer > 0.0:
        velocity.y = JUMP_VELOCITY
        _buffer_timer = 0.0; _coyote_timer = 0.0  # consume both so it fires once
```
### 4. 带冲突检测的重绑定

```gdscript
# Capture the next physical input, reject duplicates, then persist.
func rebind(action: String, event: InputEvent) -> bool:
    for other in actions:                        # conflict check across actions
        if other != action and binding_of(other) == event:
            return false                         # already used -> let UI warn/swap
    set_binding(action, event)                   # engine: erase old + add new event
    save_bindings()                              # persist (see save-systems)
    return true
# Always provide "reset to defaults", and never let the player unbind a key they
# need to reach the menu without an alternative.
```
## 陷阱

- **在游戏逻辑中硬编码按键**会阻碍重绑定、锁定手柄/触控支持并分散输入逻辑。仅读取命名动作。
- **边缘与持续状态混淆：** 对跳跃使用持续按住检查会导致每帧重复触发；对移动使用边缘检查则丢失持续按压信号。将检查类型匹配到动作类型。
- **每轴死区**会裁剪对角线摇杆输入并将运动锁定到各轴上。应基于向量幅度应用径向死区。
- **缺乏缓冲/跳跃提前期**会使紧致的平台游戏即使物理正确也显得不公平——玩家“明显按下了跳跃”。添加小的时间窗口。
- **无冲突处理的重绑定**允许两个动作共享一个键，或因取消菜单访问键而困住玩家。检测冲突；保证有返回路径。
- **未随设备变化切换提示**会向手柄玩家显示"Space 按键”（原文为 Space）。跟踪最后使用的设备并更换符号。
- **忽视无障碍性：** 强制同时按键、无重映射选项、固定灵敏度、仅按住动作等。提供重映射、切换 vs 按住以及灵敏度调节功能。
- **在错误的循环中读取输入：** 在物理步骤中轮询持续状态以获得一致移动；捕获离散按压以确保帧间不漏按任何操作。

## 引用

- `references/buffering-and-accessibility.md` — 缓冲/跳跃提前期调优、跳跃手感（可变高度、顶点）、设备检测与提示切换、触控控制，以及无障碍检查清单（重映射、切换/按住、灵敏度、延迟）。

## 相关技能

- `unity-input-system`, `unreal-enhanced-input` — 具体的引擎输入 API（Godot 使用 `InputMap` + `Input` 单例）。
- `save-systems` — 持久化自定义按键绑定和输入设置。
- `physics-tuning` — 缓冲/跳跃提前期窗口所驱动的移动物理模拟调优。
- `platformer`, `fps-shooter` — 手感依赖输入处理的类型。
