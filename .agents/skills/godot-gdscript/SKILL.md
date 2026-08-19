---
name: godot-gdscript
description: >
  为 Godot 4.7 编写符合惯例的 GDScript：静态类型、节点生命周期
  (_ready/_process/_physics_process)、@export/@onready/@tool 注解、信号，以及用于异步
  流程的 await。编辑 Godot 项目 (project.godot) 中的 .gd 脚本、编写或调试 GDScript，
  或将 3.x GDScript 移植到 4.x（函数签名、yield 改为 await、export 改为 @export）时使用。
---

# Godot GDScript (4.x)

编写正确的静态类型 GDScript，并按照引擎的设计方式使用节点生命周期和信号系统。
适用于 **Godot 4.7** (GDScript 2.0)。

## 何时使用

- 编写或修复 `.gd` 文件时使用：声明变量、函数、类，使用 `@export`/`@onready`、
  连接信号，或等待协程/信号。
- 将 Godot 3.x 脚本移植到 4.x，且脚本不再能解析时使用。

**不应使用的情况：** 场景/节点结构和实例化问题 → `godot-nodes-scenes`；
信号*架构*/解耦模式 → `godot-signals-groups`；使用 C# 而非 GDScript → `godot-csharp`。

## 核心工作流

1. **尽可能为所有内容添加类型。** GDScript 2.0 支持静态类型
   （`var hp: int = 10`、`func add(a: int, b: int) -> int:`）。类型可在解析时捕获错误并加快 VM。
   使用 `:=` 进行类型推断。
2. **按用途使用生命周期回调：** `_ready()` 在节点及其子节点进入树时执行一次；
   `_process(delta)` 在每个渲染帧执行；`_physics_process(delta)` 在固定物理 tick 执行
   （用于移动/物理）。
3. **使用 `@onready` 获取节点引用**，不要在 `_init()` 中获取——节点进入树之前，
   子节点尚不存在。
4. **使用 `@export` 暴露可调参数**，以便设计师在 Inspector 中编辑。
5. 在读起来清晰的情况下，**使用信号 + `await` 响应事件**，而不是轮询。
6. **运行并阅读错误。** Debugger 面板会打印带行号的类型错误；先修复第一个错误
   （后续错误通常是级联产生的）。

## 模式

### 1. 包含生命周期、@export 和 @onready 的类型化脚本

```gdscript
extends Node2D
class_name Spinner            # registers a global type usable in other scripts

@export var speed: float = 90.0          # editable in the Inspector (degrees/sec)
@export_range(0, 10, 0.5) var wobble := 2.0
@onready var sprite: Sprite2D = $Sprite2D # resolved when the node enters the tree

func _ready() -> void:
    # Runs once, after children are ready. Safe to touch $Sprite2D here.
    sprite.modulate = Color.AQUA

func _process(delta: float) -> void:
    # delta is seconds since last frame; multiply rates by it for FPS independence.
    rotation_degrees += speed * delta
```

### 2. 信号：声明、发出、连接（4.x Callable 语法）

```gdscript
extends Node

signal health_changed(current: int, maximum: int)   # typed signal params

var health := 100

func take_damage(amount: int) -> void:
    health = max(health - amount, 0)
    health_changed.emit(health, 100)     # 4.x: emit as a method on the signal

func _ready() -> void:
    # 4.x: connect with a Callable, not a string method name.
    health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, maximum: int) -> void:
    print("HP: %d/%d" % [current, maximum])
```

### 3. await——暂停，直到计时器或信号触发（替代 3.x yield）

```gdscript
func flash_then_continue() -> void:
    modulate = Color.RED
    await get_tree().create_timer(0.2).timeout   # resume after 0.2s
    modulate = Color.WHITE
    # await any signal: var result = await some_node.some_signal
```

### 4. Lambda、类型化数组和安全访问

```gdscript
var enemies: Array[Node] = []                    # typed array

func cull_dead() -> void:
    enemies = enemies.filter(func(e): return e.is_inside_tree())

func get_first_name(d: Dictionary) -> String:
    return d.get("name", "unknown")              # default avoids missing-key errors
```

## 常见陷阱

- **3.x → 4.x 信号 API 已更改。** `emit_signal("x")` 仍然可用，但首选 `x.emit(...)`；
  `connect("x", self, "_on_x")` 已被移除——使用带 Callable 的 `x.connect(_on_x)`。
  `yield(obj, "sig")` 现在是 `await obj.sig`。
- **`export var` 现在是 `@export var`**（注解）。同样，`onready`→`@onready`、
  `tool`→`@tool`、`remote`/`master` RPC 关键字 → `@rpc(...)` 注解。
- **在 `_init()` 中使用 `@onready` 和 `$NodePath` 会失败**——节点尚未进入树。
  应在 `_ready()` 中或使用 `@onready` 初始化节点引用。
- **整数除法会截断。** `5 / 2 == 2`。使用 `5.0 / 2` 或转换为 `float`。
- **`_process` 与 `_physics_process`。** 将 `move_and_slide()` 和物理逻辑放在
  `_physics_process(delta)` 中；使用 `_process` 会使运动依赖帧率。
- **`class_name` 在整个项目中必须唯一**，并且若要在其他脚本中使用该类型名，
  或将其用作 Inspector 类型，就必须声明它。

## 参考资料

- 有关完整注解列表、高级类型和风格约定，请阅读 `references/annotations-and-typing.md`。

## 相关 skill

- `godot-nodes-scenes` — 场景树、实例化和 autoload。
- `godot-signals-groups` — 使用信号和组的事件驱动架构。
- `godot-resources` — 使用自定义 `Resource` 类型的数据驱动设计。
- `godot-csharp` — 使用 C#/.NET 实现相同的引擎概念。
