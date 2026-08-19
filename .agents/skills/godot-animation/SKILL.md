---
name: godot-animation
description: >
  在 Godot 4.7 中以三种方式制作动画：AnimationPlayer 用于关键帧剪辑（包括调用轨道
  和信号轨道），AnimationTree 通过状态机和混合空间处理角色动画，Tween 则通过
  create_tween() 实现简短的程序化/UI 补间。处理 .tscn 中的 AnimationPlayer/
  AnimationTree 节点、混合角色状态、精灵表动画或代码驱动的 Tween 时使用。
---

# Godot 动画 (4.x)

选择并驱动正确的动画工具：`AnimationPlayer`（剪辑）、`AnimationTree`（混合/状态机）
或 `Tween`（简短的程序化移动）。适用于 **Godot 4.7**。

## 何时使用

- 播放关键帧动画、混合行走/奔跑/待机状态、制作精灵表动画，或在代码中对 UI/对象
  进行补间时使用。

**不应使用的情况：** 决定播放哪个状态的移动*逻辑* → `godot-2d-movement`；
UI 布局（区别于 UI 补间）→ `godot-ui-control`；着色器驱动的效果 → `godot-shaders`。

## 核心工作流

1. **选择工具：**
   - `AnimationPlayer` — 创作关键帧剪辑（变换、属性、方法调用、音频，甚至其他动画）。
     它是剪辑数据的事实来源。
   - `AnimationTree` — 在运行时使用状态机和/或混合空间，在这些剪辑之间混合和过渡。
     需要一个 `AnimationPlayer` 提供剪辑。
   - `Tween` — 在代码中执行用后即弃的程序化插值（`create_tween()`）；非常适合 UI 弹出、
     淡入淡出和一次性移动。
2. **对于 2D 精灵表：** 使用 `AnimatedSprite2D` + `SpriteFrames`，或在
   `AnimationPlayer` 中为 `frame` 属性设置关键帧。
3. **对于角色：** 在 `AnimationPlayer` 中构建剪辑，然后添加 `AnimationTree`
   （`active = true`），设置其 `anim_player`，并设计 `AnimationNodeStateMachine` 或
   `AnimationNodeBlendSpace2D` 作为树的根节点。
4. 通过 playback 对象（`travel`）或设置混合参数，**从代码驱动过渡**。
5. 使用 `animation_finished` 信号和调用/方法轨道**响应剪辑事件**。

## 模式

### 1. AnimationPlayer：播放并等待剪辑

```gdscript
@onready var anim: AnimationPlayer = $AnimationPlayer

func attack() -> void:
    anim.play("attack")
    await anim.animation_finished     # resume after the clip ends
    anim.play("idle")
```

### 2. AnimationTree 状态机：在状态之间切换

```gdscript
@onready var tree: AnimationTree = $AnimationTree

func _ready() -> void:
    tree.active = true                # the tree drives animation; AnimationPlayer is the source

func set_state(state: StringName) -> void:
    # The playback object controls an AnimationNodeStateMachine root.
    var sm: AnimationNodeStateMachinePlayback = tree.get("parameters/playback")
    sm.travel(state)                  # transitions using the graph's connections

func _physics_process(_d: float) -> void:
    set_state(&"run" if velocity.length() > 5.0 else &"idle")
```

### 3. 混合空间：通过 2D 参数混合奔跑方向

```gdscript
# Root is an AnimationNodeBlendSpace2D named "Move" with idle/run points placed in it.
func update_locomotion(input_dir: Vector2) -> void:
    # Parameter path = "parameters/<node name>/blend_position".
    tree.set("parameters/Move/blend_position", input_dir)
```

### 4. Tween：淡入并缩放 UI 元素（代码驱动）

```gdscript
func pop_in(node: Control) -> void:
    node.scale = Vector2.ZERO
    node.modulate.a = 0.0
    var tw := create_tween()                          # bound to this node's tree
    tw.set_parallel(true)                             # run the two tweens together
    tw.tween_property(node, "scale", Vector2.ONE, 0.2) \
      .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(node, "modulate:a", 1.0, 0.2)   # sub-property via ":"
```

## 常见陷阱

- **`AnimationTree.active` 保持为 false** → 不会播放任何动画，`travel()` 看起来不起作用。
  设置 `active = true` 并分配 `anim_player` 路径。
- **参数路径错误。** 混合/条件路径为 `"parameters/<NodeName>/..."`，且必须与树中的节点名
  完全匹配（例如 `"parameters/playback"`、`"parameters/Move/blend_position"`）。
  拼写错误会静默地不执行任何操作。
- **AnimationPlayer 与 AnimationTree 互相争夺。** 当 `AnimationTree` 处于活动状态时，
  不要再为相同轨道调用 `AnimationPlayer.play()`——让树控制播放。
- **3.x 的 Tween 节点已被移除。** 4.x 中没有可添加的 `Tween` 节点；应在代码中通过
  `create_tween()` 创建补间（返回 `Tween`）。它们会自动启动并释放自身。
- **重复使用已完成的 tween。** tween 是一次性的；新动画应再次调用 `create_tween()`。
  使用 `set_loops()` 进行重复。
- **`yield`/`yield(anim, "...")` 已被移除。** 使用 `await anim.animation_finished`。
- **子属性补间**使用冒号：`"modulate:a"`、`"position:x"`。对整个属性进行补间会覆盖同级属性。

## 参考资料

- 有关状态机过渡/条件、根运动、one-shot/混合节点、方法与调用轨道、
  `SpriteFrames`/`AnimatedSprite2D` 以及 Tween 缓动/链式调用/回调，请阅读
  `references/animation-tree-and-tween.md`。

## 相关 skill

- `godot-2d-movement` — 提供选择动画所需的速度/状态。
- `godot-ui-control` — 由 Tween 制作动画的 UI。
- `godot-3d-essentials` — 由 AnimationTree 驱动的 3D 角色场景。
- `game-ai` — 与动画状态对应的状态机。
