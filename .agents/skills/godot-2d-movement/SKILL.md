---
name: godot-2d-movement
description: >
  在 Godot 4.7 中使用 CharacterBody2D 和 move_and_slide() 实现 2D 运动学角色移动：
  包含重力的平台游戏跑跳、俯视角八方向移动、斜坡处理以及碰撞读取。编写 2D 玩家或敌人
  控制器、平台游戏或俯视角角色，或者修复包含 CharacterBody2D 的 .tscn 中
  move_and_slide()/is_on_floor() 的行为时使用。
---

# Godot 2D 移动 (4.x)

使用 `CharacterBody2D` 和无参数的 `move_and_slide()` 构建响应灵敏的 2D 角色控制器。
适用于 **Godot 4.7**。

## 何时使用

- 编写会移动并发生碰撞的 2D 玩家/敌人脚本时使用：平台游戏（重力 + 跳跃）或俯视角
  （自由八方向移动）、斜坡行走，或者墙壁/地面检测。
- 当 `move_and_slide()`“不起作用”、角色沉入地面或 `is_on_floor()` 始终为 false 时使用。

**不应使用的情况：** 动态刚体、区域、射线检测、碰撞层 → `godot-physics`；
基于图块的关卡 → `godot-tilemap`；完整的平台游戏模板 → `platformer` 类型 skill；
与引擎无关的手感调校 → `physics-tuning`。

## 核心工作流

1. **使用 `CharacterBody2D`**，并为其添加 `CollisionShape2D` 子节点。它由脚本驱动：
   不会自行下落或对力作出反应。
2. **设置 `velocity` 属性，然后调用 `move_and_slide()`**（4.x 中无参数）。
   此方法读取 `velocity`、移动物体、沿表面滑动，并更新 `velocity` 以反映实际结果。
3. **在 `_physics_process(delta)` 中执行**——`move_and_slide()` 会在内部使用物理步长的
   delta，因此不要自行将 `velocity` 乘以 `delta`。
4. **平台游戏：** 每个 tick 都向 `velocity.y` 添加重力；当 `is_on_floor()` 时，
   通过将 `velocity.y` 设为负值来跳跃。
5. **俯视角：** 根据输入构建方向并乘以速度；设置 `motion_mode = MOTION_MODE_FLOATING`，
   从而不区分“地面/墙壁”。
6. 调用后，使用 `is_on_floor()`、`is_on_wall()`、`get_wall_normal()` 和
   `get_slide_collision(i)` **读取结果**。

## 模式

### 1. 平台游戏控制器（重力、跳跃、斜坡）

```gdscript
extends CharacterBody2D

@export var speed := 200.0
@export var jump_velocity := -400.0
@export var gravity := 1200.0          # pixels/sec^2 (tune to taste)

func _physics_process(delta: float) -> void:
    # Apply gravity while airborne.
    if not is_on_floor():
        velocity.y += gravity * delta

    # Jump only when grounded (Input action set in Project Settings > Input Map).
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    # Horizontal input: -1, 0, or 1.
    var dir := Input.get_axis("move_left", "move_right")
    if dir != 0.0:
        velocity.x = dir * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed)   # decelerate to a stop

    move_and_slide()   # 4.x: no arguments; uses and updates `velocity`
```

### 2. 俯视角八方向移动

```gdscript
extends CharacterBody2D

@export var speed := 220.0

func _ready() -> void:
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # no floor/ceiling concept

func _physics_process(_delta: float) -> void:
    # get_vector returns a normalized-ish Vector2 from four input actions.
    var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = input * speed
    move_and_slide()
```

### 3. 移动后读取滑动碰撞

```gdscript
func _physics_process(delta: float) -> void:
    # ... set velocity ...
    move_and_slide()
    for i in get_slide_collision_count():
        var c := get_slide_collision(i)
        var other := c.get_collider()
        if other and other.is_in_group("enemies"):
            take_damage(1)        # touched an enemy while moving
```

### 4. 土狼时间（离开平台边缘后仍可宽容地跳跃）

```gdscript
@export var coyote_time := 0.1
var _coyote := 0.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta
        _coyote -= delta
    else:
        _coyote = coyote_time

    if Input.is_action_just_pressed("jump") and _coyote > 0.0:
        velocity.y = jump_velocity
        _coyote = 0.0
    # ... horizontal input + move_and_slide() ...
```

## 常见陷阱

- **3.x 的签名已被移除。** `move_and_slide(velocity)`（返回新速度）已被移除。
  在 4.x 中应设置 `velocity` 属性，并无参数调用 `move_and_slide()`。
  `move_and_slide(velocity, Vector2.UP)` 无法解析。
- **将速度乘以 delta。** `move_and_slide()` 已经考虑了物理 delta。
  设置 `velocity = dir * speed * delta` 会让物体缓慢爬行。
- 在 `_physics_process` 而非 `_process` 中移动，否则会产生依赖帧率的抖动运动。
  始终在 `_physics_process` 中移动。
- 当 `up_direction` 错误（默认为 `Vector2.UP`）、不存在 `CollisionShape2D`，
  或本帧从未调用 `move_and_slide()` 时，**`is_on_floor()` 始终为 false**。
- **沉入地面**通常意味着碰撞形状缺失/尺寸为零、地面物体所在的层未包含在此物体的
  mask 中，或者使用 `position +=` 移动物体，而非 velocity + `move_and_slide()`。
- **静止时从斜坡滑落：** 保持 `floor_stop_on_slope = true`（默认值），并设置
  `floor_snap_length`，使物体贴住向下的斜坡。

## 参考资料

- 有关单向平台、移动平台、跳跃缓冲、可变跳跃高度以及 `move_and_collide()`
  （手动碰撞响应），请阅读 `references/controller-recipes.md`。

## 相关 skill

- `godot-physics` — 碰撞层/mask、区域、射线检测、刚体。
- `godot-tilemap` — 构建此角色行走的关卡。
- `godot-animation` — 根据移动状态驱动精灵/骨骼动画。
- `camera-systems` — 跟踪此角色的跟随相机、死区和前视。
- `platformer` / `input-systems` — 完整类型模板与可重新绑定的输入。
