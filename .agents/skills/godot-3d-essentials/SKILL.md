---
name: godot-3d-essentials
description: >
  搭建 Godot 4.7 3D 场景：Node3D 变换、Camera3D、光照
  (DirectionalLight3D/OmniLight3D)、用于天空/环境光/色调映射/后期处理的
  WorldEnvironment、MeshInstance3D 材质，以及用于基于图块的 3D 关卡的 GridMap。
  构建 Godot 项目中的 3D 场景、放置相机/灯光、配置环境和后期处理，或者处理
  Node3D/.tscn 3D 内容与 GridMap 时使用。
---

# Godot 3D 基础 (4.x)

组装一个可用的 3D 场景：变换、相机、灯光、环境/后期处理、材质，以及 `GridMap`
关卡白盒。适用于 **Godot 4.7**。

## 何时使用

- 开始构建或修复 3D 场景时使用：定位 `Camera3D`、添加灯光、设置
  `WorldEnvironment`（天空、环境光、色调映射、辉光/SSAO）、分配材质，
  或者使用 `GridMap` 构建关卡。

**不应使用的情况：** 编写空间着色器 → `godot-shaders`；3D 物理物体和射线检测 →
`godot-physics`；角色动画混合 → `godot-animation`；完整 FPS 模板 → `fps-shooter`
类型 skill。

## 核心工作流

1. **所有 3D 对象都是 `Node3D`**，并具有 `Transform3D`（位置、旋转 basis、缩放）。
   使用 `global_position` 移动，使用 `rotate_y(angle)` 或 `look_at(target)` 旋转。
2. **添加 `Camera3D`。** 将其标记为 `current`（或调用 `make_current()`）；设置 `fov`、
   `near`、`far`。将其设为 rig/pivot 的子节点，以实现轨道或跟随相机。
3. **照亮场景。** `DirectionalLight3D` 是太阳；`OmniLight3D`/`SpotLight3D` 是局部光源。
   为每盏灯启用阴影。没有灯光和环境光时，表面会渲染为黑色。
4. **添加 `WorldEnvironment`** 及一个 `Environment` 资源：背景（天空/颜色）、
   环境光、色调映射和后期处理（辉光、SSAO、雾、调整）。
5. 在 `MeshInstance3D` 上**为网格赋予材质**（`StandardMaterial3D` 或 `ShaderMaterial`）。
6. 使用 `GridMap` **搭建关卡白盒**；它在 3D 网格上放置 `MeshLibrary` 项目
   （相当于图块地图的 3D 版本）。

## 模式

### 1. 跟随相机（第三人称、平滑）

```gdscript
extends Camera3D

@export var target: Node3D
@export var offset := Vector3(0, 4, 8)
@export var smooth := 6.0

func _physics_process(delta: float) -> void:
    if target == null:
        return
    var desired := target.global_position + offset
    global_position = global_position.lerp(desired, smooth * delta)  # smooth follow
    look_at(target.global_position, Vector3.UP)                      # face the target
```

### 2. 在代码中创建太阳 + 环境

```gdscript
func _ready() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-45, -30, 0)
    sun.shadow_enabled = true
    add_child(sun)

    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.sky.sky_material = ProceduralSkyMaterial.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    we.environment = env
    add_child(we)
```

### 3. 从代码分配 StandardMaterial3D

```gdscript
func tint_mesh(mesh: MeshInstance3D, color: Color) -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.0
    mat.roughness = 0.6
    mat.emission_enabled = true
    mat.emission = color * 0.3
    mesh.material_override = mat       # overrides the mesh's surface materials
```

### 4. 将图块放入 GridMap

```gdscript
@onready var grid: GridMap = $GridMap   # cell_size + mesh_library set in the editor

func build_floor(width: int, depth: int, item_id: int) -> void:
    for x in width:
        for z in depth:
            # set_cell_item(Vector3i cell, int item, orientation = 0)
            grid.set_cell_item(Vector3i(x, 0, z), item_id)
```

## 常见陷阱

- **场景渲染为黑色** → 没有灯光和环境光。添加 `DirectionalLight3D` 和/或具有环境光/天空的
  `WorldEnvironment`。新场景默认两者都没有。
- **没有相机/相机错误。** 如果什么都不显示，则没有 `Camera3D` 处于 `current` 状态。
  设置 `current = true` 或 `make_current()`；每个 viewport 只能有一台相机负责渲染。
- **混淆局部与全局变换。** `position`/`rotation` 相对于父节点；
  `global_position`/`global_transform` 位于世界空间。在旋转后的父节点下混用会产生意外结果。
  `look_at` 使用全局坐标。
- **缩放物理/灯光。** `Node3D` 上的非均匀 `scale` 会扭曲子碰撞体和灯光；
  最好缩放网格资产或使用均匀缩放。
- **忘记 `look_at` 中的 `from`/`up`。** `look_at(target, up)`——target 等于节点位置，
  或 `up` 与观察方向平行时，会产生 NaN/翻转。
- **没有 `MeshLibrary` 的 GridMap** 不会放置任何内容。创建一个 `MeshLibrary`（来自场景）
  并分配它；`set_cell_item(cell, -1)` 会清除单元格。
- **HDR/辉光过强** → 检查 `tonemap_mode` 和辉光阈值；在电影式色调映射下，
  原始发光值会产生强烈泛光。

## 参考资料

- 有关 Transform3D 数学、相机投影模式、灯光/阴影参数、完整的 Environment/后期处理选项、
  `MeshLibrary` 创建以及 `ReflectionProbe`/`LightmapGI` 光照，请阅读
  `references/scene-and-environment.md`。

## 相关 skill

- `godot-physics` — 3D 物体、区域和射线检测。
- `godot-shaders` — 用于自定义 3D 表面的空间着色器。
- `godot-animation` — 用于 3D 角色的 `AnimationTree`。
- `camera-systems` — 第三人称轨道/第一人称视角 rig、取景和碰撞。
- `performance-optimization` — 让 3D 场景保持在帧预算内（draw call、灯光、LOD）。
- `fps-shooter` — 将 3D 移动、输入和 AI 组合成游戏。
