---
name: godot-physics
description: >
  在 2D 和 3D 中使用 Godot 4.7 物理体与检测：RigidBody、StaticBody、Area 和
  CharacterBody；碰撞层与遮罩；接触/重叠信号；以及射线检测（RayCast 节点和直接空间状态查询）。
  适用于配置碰撞层/遮罩、使用 Area2D/Area3D 检测重叠、向 RigidBody 施加力，
  或在 Godot 项目（包含物理体的 .tscn）中投射射线。
---

# Godot 物理 (4.x, 2D + 3D)

选择正确的物理体，设置碰撞层/遮罩，检测重叠并投射射线。这些概念同时适用于 2D 和 3D
（替换 `2D`/`3D` 后缀即可）。目标版本为 **Godot 4.7**。

## 何时使用

- 适用于选择物理体类型、设置碰撞层/遮罩以使正确的对象发生碰撞、使用 `Area` 检测重叠
  （触发器、受击框）、向 `RigidBody` 施加力/冲量，或为视线/地面检测投射射线。

**不适用的情况：** 运动学角色控制器（`move_and_slide`）→ `godot-2d-movement`；
图块碰撞设置 → `godot-tilemap`；调整物理的_手感_（时间步长、质量、抖动）→ `physics-tuning`。

## 核心工作流

1. **选择物理体类型：**
   - `StaticBody` — 永不移动（地板、墙壁）。参与碰撞，但不进行模拟。
   - `RigidBody` — 完全模拟（重力、力、反弹）。不要直接设置其 `position`；应施加力/冲量，
     或设置 `linear_velocity`。
   - `CharacterBody` — 由脚本驱动的运动学物体（参见 `godot-2d-movement`）。
   - `Area` — 检测重叠，并可施加重力/阻尼；不产生实体碰撞。
   每个物理体都需要一个 `CollisionShape`（或 `CollisionPolygon`）子节点。
2. **配置层和遮罩。** 物理体_位于_其**层**上，并通过其**遮罩**进行_扫描_。只有一方的层包含在
   另一方的遮罩中，两个物理体才会交互。为清晰起见，请在 Project Settings > Layer Names 中命名层。
3. **使用 `Area` 信号检测重叠**（`body_entered`、`area_entered`）。
4. **使用力/冲量驱动 RigidBodies，** 或重写 `_integrate_forces` 以获得完全控制。
5. **投射射线：** 使用每帧轮询的 `RayCast2D/3D` 节点，或从代码执行一次性空间状态查询。

## 模式

### 1. 碰撞层与遮罩（通过代码设置）

```gdscript
# Player is on layer 1, scans layers 2 (walls) and 3 (enemies).
func _ready() -> void:
    set_collision_layer_value(1, true)    # I am on layer 1
    set_collision_mask_value(2, true)     # I collide with things on layer 2
    set_collision_mask_value(3, true)     # ...and layer 3
    # Bit-field forms also exist: collision_layer = 1; collision_mask = 0b110
```

### 2. 将 Area2D 用作触发器/受击框

```gdscript
extends Area2D                            # e.g. a damage zone

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("take_damage"):
        body.take_damage(10)

func _on_area_entered(area: Area2D) -> void:
    print("Overlapped area: ", area.name)
```

### 3. 向 RigidBody3D 施加力和冲量

```gdscript
extends RigidBody3D

func push(direction: Vector3) -> void:
    apply_central_impulse(direction * 8.0)     # instantaneous velocity change

func _physics_process(_delta: float) -> void:
    apply_central_force(Vector3.FORWARD * 4.0) # continuous force (per tick)
    # Never set `position` on a RigidBody to move it; use forces/impulses or
    # set linear_velocity. Use freeze=true if you must hold it in place.
```

### 4. 两种射线检测方式

```gdscript
# A) RayCast2D node: enable it, then poll after physics has updated.
@onready var ray: RayCast2D = $RayCast2D    # set target_position in the editor

func _physics_process(_delta: float) -> void:
    if ray.is_colliding():
        var hit := ray.get_collider()
        var point := ray.get_collision_point()

# B) One-shot query from code (no node needed).
func ground_under(global_from: Vector2) -> Dictionary:
    var space := get_world_2d().direct_space_state
    var query := PhysicsRayQueryParameters2D.create(global_from, global_from + Vector2(0, 64))
    query.collision_mask = 1                 # only layer 1
    return space.intersect_ray(query)        # {} if nothing hit, else collider/position/normal
```

## 常见陷阱

- **混淆层与遮罩**是最常见的问题。层 =“我是什么”；遮罩 =“我寻找什么”。若要让 A 检测 B，
  B 的层必须包含在 A 的遮罩中。检测可以是单向的。
- **通过 `position` 移动 RigidBody** 会与求解器冲突，并导致穿透/抖动。请使用冲量/力、设置
  `linear_velocity`，或将其 `freeze`。如需传送，请在 `_integrate_forces` 内设置位置并将速度清零。
- 当 monitoring 和 monitorable 均未设置，或层/遮罩不重叠时，**`Area` 不会触发**。
  Area 必须开启 `monitoring` 才能检测；`monitorable` 则允许其他对象检测它。
- 如果 `enabled` 为 false，或在物理更新前读取，**RayCast2D/3D 会读到过期数据或无数据。**
  请在 `_physics_process` 中读取；在同一物理帧内移动后调用 `force_raycast_update()`。
- **忘记添加 `CollisionShape`**（或将其留空）会导致物理体永不碰撞。
- **高速对象会穿过**薄墙；请在 RigidBody 上启用**连续 CD**（`continuous_cd`），或使用基于射线检测的检查。
- **让 `intersect_ray` 排除自身物理体？** 传入 `query.exclude = [self.get_rid()]`
  （一个 `Array[RID]`，而不是节点数组）以跳过自身命中。

## 参考资料

- 关于 `_integrate_forces`、关节、单向碰撞、直接访问 `PhysicsServer`、形状查询
  （`intersect_shape`）和 3D `move_and_collide`，请阅读 `references/bodies-and-queries.md`。

## 相关技能

- `godot-2d-movement` — 运动学 `CharacterBody2D` 控制器。
- `godot-tilemap` — 图块碰撞形状及其层。
- `physics-tuning` — 与引擎无关的手感调整：时间步长、质量、阻力、CCD。
- `godot-3d-essentials` — 这些物理体所在的 3D 场景设置。
