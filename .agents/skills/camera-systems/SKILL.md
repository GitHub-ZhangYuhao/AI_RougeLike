---
name: camera-systems
description: >
  构建手感良好的游戏摄像机——2D 跟随带死区、前瞻、平滑处理和关卡边界限制；3D 第三人称环绕视角含碰撞检测与第一人称注视控制，以及多目标取景和震动钩子。这些引擎无关的技术可与引擎的相机节点及 Unity Cinemachine 或 Godot Camera2D/PhantomCamera 等 Rig（骨架）配合使用。当用户提及摄像机跟随、跟拍摄像机、死区、前瞻、摄像机平滑处理、摄像机边界/限制、第三人称摄像机、环绕摄像机、第一人称注视、Cinemachine 或摄像机抖动时，请使用此技能。
---

# 摄像机系统

相机是玩家的窗口；糟糕的镜头设计会让一款优秀的游戏变得令人厌恶。本技能涵盖引擎无关的相机技术——平滑跟随、死区处理、前瞻、边界限制、含碰撞检测的第三人称环绕视角、第一人称注视控制以及多目标取景，并将其映射到各引擎特有的相机节点或 Rig 上。

## 何时使用

- 当需要 2D 摄像机流畅地跟随玩家移动、保持在关卡内、预判玩家的运动轨迹，或者忽略微小动作（死区）时使用。
- 当构建 3D 第三人称环绕摄像机（鼠标/摇杆注视、碰撞推入效果）或第一人称注视控制器时，以及需要同时取景多个目标对象时使用。
- 用于修复摄像机抖动、吸附现象、晕动症，或者显示超出关卡边界的画面问题。

**何时不应使用：**若要处理屏幕震动和冲击反馈的*幅度与触发时机*，请使用 `game-feel`（本技能仅公开由其驱动的震动偏移钩子）。对于引擎中具体的相机节点/组件设置，请使用 `godot-3d-essentials`（Camera3D、环境）或对应的引擎技能。玩家移动本身应使用引擎移动技能（`godot-2d-movement`）。若要优化大量摄像机/渲染目标的性能，请参阅 `performance-optimization`。

## 核心工作流

1. **明确摄像机服务的目标。** 平台游戏需要预判跳跃并展示危险，俯视游戏通常居中并带死区，第三人称需要环绕与碰撞，第一人称则只控制视角。游戏类型决定规则。
2. **平滑且独立于帧率地跟随。** 使用指数平滑或弹簧（`SmoothDamp`）让摄像机趋近目标，不要使用固定的 `lerp(a, b, 0.1)`——其中 0.1 是逐帧系数，会随帧率改变手感。
3. **添加死区，**使目标的微小移动不会推动摄像机；仅当目标离开框选区域时才开始跟随。这能减少高频移动游戏引发的眩晕。
4. **使用前瞻引导动作，**沿移动或朝向偏移摄像机目标，并平滑淡入淡出，避免镜头猛甩。
5. **限制在关卡边界内，**确保摄像机绝不显示可玩区域之外的内容；结合平滑处理，使镜头在边缘处柔和停止。
6. **在 3D 中将视角控制与碰撞分离。** 通过 Rig 的 yaw/pitch 实现环绕；几何体遮挡时使用弹簧臂/射线拉近摄像机，并限制 pitch。
7. **在目标移动后更新摄像机。** 在延迟/后处理步骤中跟随（移动和物理结算之后），避免一帧延迟造成的抖动。
8. **以低帧率和高帧率移动目标进行验证，**测试角落、墙壁和关卡边缘；确认无抖动、不会越界窥视且停止平滑。报告实际观察结果。

## 模式

### 1. Godot 2D 内置跟随：平滑 + 边界（不要一开始就自行实现）

```gdscript
# Godot 4.7 Camera2D. Engine-provided smoothing + hard limits + drag margins.
@onready var cam := $Camera2D
func _ready() -> void:
    cam.make_current()
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 6.0           # higher = snappier; lower = floatier
    cam.limit_left = 0; cam.limit_top = 0        # clamp to the level rect (pixels)
    cam.limit_right = level_width; cam.limit_bottom = level_height
    cam.drag_horizontal_enabled = true           # built-in deadzone via drag margins
```
### 2. 帧率无关的平滑跟随（当你手动实现时）

```gdscript
# RIGHT: exponential smoothing — same feel at any FPS. `rate` ~ 5..12.
func _follow(dt: float) -> void:
    var t := 1.0 - exp(-rate * dt)               # converges correctly regardless of dt
    global_position = global_position.lerp(target.global_position, t)
# WRONG: global_position = global_position.lerp(target.global_position, 0.1)
#        → faster smoothing at higher FPS; different feel on every machine.
# Unity 6.3 LTS: Vector3.SmoothDamp(transform.position, target.position, ref vel, smoothTime) in
# LateUpdate gives the same spring behavior with built-in frame-rate correction.
```
### 3. 死区与前瞻（引导玩家，忽略抖动）

```gdscript
# Camera only chases once the target leaves the deadzone box, then aims AHEAD of motion.
func _camera_target(dt: float) -> Vector2:
    var to := target.global_position - _focus
    var dz := deadzone_half_extents                  # e.g. Vector2(48, 32)
    # Only move the focus by the overflow beyond the deadzone (per axis).
    _focus.x += clampf(absf(to.x) - dz.x, 0, INF) * signf(to.x)
    _focus.y += clampf(absf(to.y) - dz.y, 0, INF) * signf(to.y)
    var lead := target.velocity.normalized() * look_ahead_dist    # aim ahead of travel
    return _focus + lead
```
### 4. 第三人称环绕轨道与碰撞推入效果

```gdscript
# Godot 4.7. Yaw/pitch a pivot; a SpringArm3D auto-pulls the camera in when blocked.
func _unhandled_input(e):
    if e is InputEventMouseMotion:
        _yaw -= e.relative.x * sensitivity
        _pitch = clampf(_pitch - e.relative.y * sensitivity, -1.2, 0.4)   # clamp pitch!
func _process(_dt):
    pivot.rotation = Vector3(_pitch, _yaw, 0)
    # $SpringArm3D handles wall collision: set spring_length + collision_mask; the child
    # Camera3D slides in automatically. RIGHT: spring arm. WRONG: camera clips through walls.
# Unity 6.3 LTS: a Cinemachine 3 CinemachineCamera (namespace Unity.Cinemachine) with an Orbital
# Follow + Cinemachine Deoccluder; the CinemachineBrain on the Camera blends automatically.
```
### 5. 屏幕震动钩子（所有者触发器位于 `game-feel`）

```gdscript
# Expose an additive offset the game-feel trauma model writes to; follow + shake compose.
var shake_offset := Vector2.ZERO                 # set each frame by game-feel (trauma^2 * noise)
func _apply(final_focus: Vector2) -> void:
    global_position = final_focus + shake_offset  # shake rides ON TOP of smooth follow
# Unity Cinemachine: add a CinemachineBasicMultiChannelPerlin and set amplitude from trauma.
```
## 常见陷阱

- **每帧调用 `lerp(pos, target, const)`** 会受帧率影响——30 FPS 时画面更模糊，144 FPS 时则显得生硬。请使用 `1 - exp(-rate*dt)` 或 `SmoothDamp`。
- **在目标移动前于常规更新中执行跟随逻辑**会导致一帧延迟抖动。应在 `LateUpdate` / 运动/物理解析之后进行跟随计算。
- **缺少边界限制**会让相机显示关卡边缘之外的黑色区域。请将焦点限制在关卡矩形内（需考虑视口半宽，确保*视野范围*而非中心点保持在画面内）。
- **缺乏死区控制**会导致快速反应类游戏中相机随微小移动而剧烈抖动→引发眩晕感。
- **第三人称/第一人称视角中缺少俯仰角限制**会使相机翻转至上方。请将俯仰角限制在约±80°范围内。
- **3D 场景中相机穿墙问题**——使用弹簧臂或遮挡射线将其拉回正确位置。
- **传送/重生时的强制吸附**体验突兀；要么故意硬切并重置平滑参数，要么采用快速缓动。切勿让巨大的 `SmoothDamp` 距离值在关卡中剧烈拉扯。
- **将摇晃效果施加于跟随目标而非叠加偏移量**会导致跟随与摇晃相互冲突。正确组合：先执行平滑跟随，最后添加摇晃偏移量。
- **各轴死区与径向死区的混淆**——方框形死区的感觉不同于圆形死区；请根据需求刻意选择。

## 参考资料

- 关于指数平滑/弹簧推导、完整的带死区和前瞻限制的二维框架、3D 弹簧臂/轨道细节、第一人称视角、多目标/群体构图与分屏显示，以及 Cinemachine 3 / Godot Camera2D / PhantomCamera 的映射关系，请阅读 `references/follow-and-framing.md`。

## 相关技能

- **`game-feel`**——掌控屏幕摇晃带来的创伤感或触发机制；该技能会暴露其写入的偏移量。
- **`godot-2d-movement`, `godot-3d-essentials`**——相机所框定的玩家/世界环境；Camera3D 设置。
- **`physics-tuning`**——将相机跟随与物理步长插值，以消除抖动。
- **`platformer`, `fps-shooter`**——本技能实现的规则适用的游戏类型。
- **`performance-optimization`**——额外相机、渲染目标及分屏显示的开销成本。
