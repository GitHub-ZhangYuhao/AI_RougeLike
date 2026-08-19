---
name: godot-nodes-scenes
description: >
  使用场景树和节点组合来构建 Godot 4.7 项目：创建可复用场景、在运行时实例化
  PackedScenes、安全地遍历场景树，以及注册自动加载单例。适用于设计 .tscn 场景、
  决定如何拆分节点、使用 instantiate() 生成实例、连接自动加载项，或修复 Godot
  项目中的“找不到节点”/已释放节点错误。
---

# Godot 节点与场景 (4.x)

使用节点和场景组合游戏，在运行时实例化它们，并在访问场景树时避免因节点已释放或缺失而崩溃。
目标版本为 **Godot 4.7**。

## 何时使用

- 适用于组织 `.tscn` 场景、选择如何将功能拆分为节点、实例化 `PackedScene`（子弹、
  敌人、UI），或设置自动加载单例。
- 适用于调试 `get_node()` / `$Path` 返回 `null`，或“尝试调用先前已释放的实例”错误。

**不适用的情况：** GDScript 语言/语法 → `godot-gdscript`；基于信号的解耦 →
`godot-signals-groups`；物理体/碰撞 → `godot-physics`。

## 核心工作流

1. **使用组合建模。** 场景是保存为 `.tscn` 的节点树。构建小型、单一用途的场景
   （Player、Bullet、Enemy），再用它们组合出更大的场景。优先添加子节点，而不是使用深层继承。
2. **让场景可复用：** 为其根节点添加脚本并公开 `@export` 配置。保存后，它会成为可多次
   实例化的 `PackedScene`。
3. **在运行时实例化：** 使用 `preload`/`load` → `scene.instantiate()` →
   `add_child(instance)`。在添加后设置位置/状态（也可以在添加前设置，两者都有效）。
4. **安全地访问节点。** 对固定子节点使用 `@onready var x = $Path`；对场景树深处的节点使用
   唯一名称（`%Name`）；绝不要假定节点仍然存在。
5. **使用自动加载项保存全局状态/服务**（游戏状态、音频、场景切换）——在
   Project Settings > Globals (Autoload) 中注册后，可在任何位置通过名称访问。
6. **使用 `queue_free()` 释放节点，** 并通过 `is_instance_valid()` 防护后续访问。

## 模式

### 1. 在运行时实例化场景

```gdscript
extends Node2D

const BULLET := preload("res://bullet.tscn")   # preload: loaded at compile time

func shoot(at: Vector2, dir: Vector2) -> void:
    var bullet := BULLET.instantiate()         # create an instance of the scene
    bullet.global_position = at
    bullet.direction = dir                      # set exported/public state
    add_child(bullet)                           # now it's in the tree and runs
```

### 2. 安全访问节点：$、get_node_or_null 和唯一名称

```gdscript
@onready var label: Label = $UI/Label            # $ is sugar for get_node("UI/Label")
@onready var health_bar: ProgressBar = %HealthBar # % = scene-unique name (rename-proof)

func update() -> void:
    var optional := get_node_or_null("Maybe/Missing")  # returns null instead of erroring
    if optional:
        optional.queue_free()
```

### 3. 自动加载单例（全局游戏状态）

```gdscript
# game_state.gd — add in Project Settings > Globals > Autoload as "GameState".
extends Node

var score := 0
signal score_changed(value: int)

func add_score(points: int) -> void:
    score += points
    score_changed.emit(score)         # any scene can: GameState.score_changed.connect(...)
```

### 4. 切换当前运行场景

```gdscript
func go_to_level_2() -> void:
    # Swaps the current scene for another. Frees the old scene tree.
    get_tree().change_scene_to_file("res://levels/level_2.tscn")
    # Or, with a preloaded PackedScene:
    # get_tree().change_scene_to_packed(LEVEL_2)
```

## 常见陷阱

- **路径错误或节点尚未进入场景树时，`$Path` / `get_node()` 会返回 `null` 或报错。**
  使用 `@onready`，确认路径与场景一致，或对可选节点使用 `get_node_or_null()`。
- **重命名节点会破坏 `$Path`。** 使用**唯一名称**（`%Name`，通过右键 > Access as Unique Name
  设置），让深层引用在重命名和重新设置父节点后仍然有效。
- **在帧中间调用 `free()` 可能导致**仍在使用该节点的其他代码崩溃。优先使用 `queue_free()`
  （在帧末删除），并检查 `is_instance_valid(node)`。
- **在 `add_child()` 之前设置子节点状态**没有问题，但子节点的 `_ready()` 只会在它进入场景树
  _之后_运行——在此之前不要期望其 `@onready` 变量可用。
- **自动加载顺序很重要：** 自动加载项会按列表顺序在主场景之前添加。自动加载项不能依赖主场景已存在。
- **在 Godot 4 中，`instance()` 已重命名**为 `instantiate()`。`preload` 在解析时运行
  （路径必须是常量）；`load` 在运行时运行（路径可以是变量）。
- **`change_scene_to_file()` 是延迟执行的，**而非立即执行——Godot 会在当前帧末切换场景并释放
  旧场景。调用后的任何代码仍针对_旧_场景树运行，且直到下一帧 `get_tree().current_scene` 才是新场景。
  不要在同一行读取新场景的节点；应从新场景的 `_ready()` 中读取。

## 参考资料

- 关于场景继承、从代码保存场景时的 `owner`/所有权、组与唯一名称的对比，以及节点路径边界情况，
  请阅读 `references/tree-and-instancing.md`。

## 相关技能

- `godot-gdscript` — 语言、生命周期和 `@onready`。
- `godot-signals-groups` — 将实例化场景与其生成器解耦。
- `godot-resources` — 在实例之间共享数据而不进行复制。
- `save-systems` — 跨运行持久化场景/游戏状态。
