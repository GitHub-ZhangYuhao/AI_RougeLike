---
name: godot-signals-groups
description: >
  使用信号和节点组构建事件驱动、解耦的 Godot 4.7 游戏玩法：声明并发出自定义信号，
  使用 Callables 连接（包括 bind/单次触发），并通过组和 call_group 向多个节点广播。
  适用于在 Godot 项目中连接节点通信、使用信号替代紧耦合引用、发出/连接事件，
  或迁移 3.x 的 connect("sig", self, "method") 代码。
---

# Godot 信号与组 (4.x)

使用观察者模式（信号）解耦节点，并同时操作多个节点（组），而不是在场景之间硬编码引用。
目标版本为 **Godot 4.7**。

## 何时使用

- 适用于节点需要在不持有其他节点直接引用的情况下，告知它们“发生了某件事”
  （玩家死亡、拾取物品、波次清除）。
- 适用于需要一次寻址一整类节点（“暂停所有敌人”“保存每个检查点”）。

**不适用的情况：** 原始信号_语法_基础 → `godot-gdscript`；场景结构和实例化 →
`godot-nodes-scenes`。对于跨场景的全局事件，请从自动加载项发出（参见 `godot-nodes-scenes`）。

## 核心工作流

1. **确定方向。** 子节点/子场景应向上_发出_信号；父节点负责_连接_它。这样可以保持子节点可复用，
   且无需知道谁在监听。
2. **在发出方声明类型化信号，** 并在事件发生时调用其 `emit()`。
3. **使用 Callable 连接**（`sig.connect(_on_sig)`），也可以在编辑器的 Node 面板中连接。
   使用 `CONNECT_ONE_SHOT` 实现单次触发，使用 `bind()` 传递额外上下文。
4. **使用组进行广播：** 将节点添加到命名组，然后遍历
   `get_tree().get_nodes_in_group(...)` 或调用 `call_group(...)`。
5. **在需要时断开连接**（例如释放长生命周期的监听器之前），并检查 `is_connected()`
   以避免重复连接。

## 模式

### 1. 向上发出，由父节点连接

```gdscript
# coin.gd (reusable pickup — knows nothing about the player or HUD)
extends Area2D
signal collected(value: int)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        collected.emit(10)
        queue_free()
```

```gdscript
# level.gd (the parent wires the coin to game state)
func _ready() -> void:
    for coin in get_tree().get_nodes_in_group("coins"):
        coin.collected.connect(_on_coin_collected)

func _on_coin_collected(value: int) -> void:
    GameState.add_score(value)
```

### 2. 连接标志：单次触发和绑定额外参数

```gdscript
func _ready() -> void:
    # Fire exactly once, then auto-disconnect.
    $Door.opened.connect(_on_door_opened, CONNECT_ONE_SHOT)
    # bind() appends arguments supplied at connect time (after the signal's own args).
    $RedButton.pressed.connect(_on_button.bind("red"))

func _on_button(color: String) -> void:
    print("Pressed the %s button" % color)
```

### 3. 组：向多个节点广播

```gdscript
func pause_all_enemies() -> void:
    # Call a method on every node in the "enemies" group (no-op if missing).
    get_tree().call_group("enemies", "set_paused", true)

func count_enemies() -> int:
    return get_tree().get_nodes_in_group("enemies").size()
```

通过代码或编辑器的 Node > Groups 选项卡将节点添加到组：

```gdscript
func _ready() -> void:
    add_to_group("enemies")        # remove_from_group("enemies") to leave
```

### 4. 内联等待信号

```gdscript
func open_chest() -> void:
    $AnimationPlayer.play("open")
    await $AnimationPlayer.animation_finished   # pause until it emits
    spawn_loot()
```

## 常见陷阱

- **3.x 的 connect 签名已被移除。** `connect("died", self, "_on_died")` →
  `died.connect(_on_died)`。目标由 Callable 隐含指定。旧式
  `Object.connect("died", Callable(self, "_on_died"))` 仍然有效，但方法名字符串形式无效。
- **重复连接会多次触发处理器。** 节点重新添加后在 `_ready()` 中再次连接会叠加回调。
  使用 `if not sig.is_connected(cb): sig.connect(cb)` 进行防护。
- **连接到已释放节点会报错。** 断开长生命周期监听器，或依赖 Godot 在_已连接对象_释放时自动断开
  （对节点会这样做）。
- **组对整个 SceneTree 全局有效，** 而非仅限单个场景。使用相同组名的两个关卡会共享成员。
  如果这会造成影响，请为组名添加命名空间。
- **`call_group` 会静默忽略缺少该方法的节点。** 方法名拼写错误会悄然失败——契约很重要时，
  优先使用类型化信号。
- **信号参数必须匹配。** 使用错误的参数数量/类型发出信号会引发错误；声明类型化参数并严格按其发出。

## 参考资料

- 关于连接标志、延迟连接、自定义信号参数、带超时的等待，以及信号与直接调用之间的权衡，
  请阅读 `references/signal-patterns.md`。

## 相关技能

- `godot-gdscript` — 信号/`await` 语法基础。
- `godot-nodes-scenes` — 用于全局事件总线的自动加载项。
- `game-ai` — 经常驱动和使用这些事件的状态机。
