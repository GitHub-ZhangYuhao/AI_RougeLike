---
name: godot-resources
description: >
  使用自定义 Resource 类设计数据驱动的 Godot 4.7 游戏：通过 class_name + @export
  定义类型化数据，保存/加载 .tres/.res 文件，实例化和复制资源，并使用 ResourceLoader
  按需加载（包括线程加载）。适用于在 Godot 项目中将物品/属性/配置建模为数据、创建
  .tres 资源，或使用自定义 Resource 子类以及 ResourceLoader/ResourceSaver。
---

# Godot 资源 (4.x)

将游戏数据建模为可复用、可在 Inspector 中编辑的 `Resource` 对象，而不是硬编码值，
并将其保存/加载为 `.tres`/`.res`。目标版本为 **Godot 4.7**。

## 何时使用

- 适用于将物品、属性、敌人配置、对话文本或关卡元数据表示为数据；在 Inspector 中创建
  `.tres` 文件；或加载/保存自定义资源。

**不适用的情况：** 节点/场景结构 → `godot-nodes-scenes`；保存玩家的_运行时进度_
（与引擎无关的存档格式/槽位）→ `save-systems`；此模式的 C# 版本 → `godot-csharp`。

## 核心工作流

1. **使用 `class_name` 和 `@export` 字段创建 `Resource` 子类。** 它随后会出现在
   "New Resource" 对话框中，并可作为 `@export` 类型在 Inspector 中编辑。
2. **在 FileSystem 面板中将实例创建为 `.tres` 文件**（文本格式，便于比较差异）或 `.res`
   （二进制格式，更小/更快）。在 Inspector 中编辑其字段——无需编写代码。
3. **从节点引用资源：** 使用 `@export var data: ItemResource`，或数组
   `@export var loot: Array[ItemResource]`。
4. **在运行时加载：** 使用 `preload`（常量路径）或 `load`/`ResourceLoader.load`
   （变量路径）。对大型资产使用线程加载。
5. **在运行时修改共享资源前先复制，** 否则所有使用该资源的节点都会一起改变（资源是共享引用）。
6. **使用 `ResourceSaver.save` 保存生成或编辑过的资源。**

## 模式

### 1. 自定义数据资源

```gdscript
# item.gd
extends Resource
class_name ItemResource

@export var id: StringName = &""
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var value: int = 0
```

在 FileSystem 面板中基于此类创建 `sword.tres`，并在 Inspector 中填写内容。

### 2. 从节点使用资源

```gdscript
extends Node
@export var starting_items: Array[ItemResource] = []   # drag .tres files in the Inspector

func _ready() -> void:
    for item in starting_items:
        print("Have: %s (x%d max)" % [item.display_name, item.max_stack])
```

### 3. 修改共享数据前先复制

```gdscript
func give_unique_copy(template: ItemResource) -> ItemResource:
    # true = deep copy sub-resources too; false = shallow (shares sub-resources).
    var copy: ItemResource = template.duplicate(true)
    copy.value += 5                # mutating the copy won't touch the template .tres
    return copy
```

### 4. 在运行时保存和加载资源

```gdscript
func save_config(cfg: Resource) -> void:
    ResourceSaver.save(cfg, "user://config.tres")   # user:// = writable app data dir

func load_config() -> Resource:
    if ResourceLoader.exists("user://config.tres"):
        return ResourceLoader.load("user://config.tres")
    return null
```

## 常见陷阱

- **资源通过引用共享。** 分配给多个节点的同一个 `.tres` 是_同一_对象——修改它会改变所有节点
  （以及重新保存的文件）。为每个实例的状态调用 `duplicate(true)`。
- **要从编辑器实例化，必须使用 `class_name`。** 否则该类不会出现在 "New Resource" 对话框中，
  也不能用作 `@export` 类型。
- **在导出的游戏中，`res://` 是只读的。** 将运行时数据写入 `user://`，绝不要写入 `res://`。
  仅在编辑器中才能通过 `ResourceSaver.save` 保存到 `res://`。
- **在 Resource 中存储节点不会序列化它们。** 资源保存的是数据，而不是活动的场景节点。
  请通过 `PackedScene` 引用场景，而非节点实例。
- **循环资源引用**（A 持有 B，B 持有 A）可能无法正常保存/加载——保持数据图无环，或使用 ID/查找表。
- **`preload` 与 `load`。** `preload` 需要常量路径，并随脚本加载；`load` 在运行时接受变量路径。
  在 `load` 前使用 `ResourceLoader.exists()`，以避免文件缺失错误。
- **不要在 `.tres` 中放置机密信息**——它们会以纯文本形式包含在导出内容中。

## 参考资料

- 关于线程/后台加载（`load_threaded_request`）、具有自定义设置的 `@tool` 资源、自定义
  `ResourceFormatLoader`/`Saver`、场景本地资源和资源 UID，请阅读
  `references/resource-patterns.md`。

## 相关技能

- `godot-gdscript` — 用于定义资源字段的 `@export` 注解。
- `godot-nodes-scenes` — 实例化场景与共享资源数据的对比。
- `save-systems` — 持久化运行时进度（与静态数据分离）。
- `unity-scriptableobjects` — Unity 中等价的数据资产模式。
