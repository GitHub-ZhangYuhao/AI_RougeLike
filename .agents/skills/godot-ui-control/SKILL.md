---
name: godot-ui-control
description: >
  使用 Control 节点构建 Godot 4.7 用户界面：通过锚点和偏移量实现响应式布局，使用
  Container 节点（VBox/HBox/Grid/Margin）自动排列，使用 Theme 资源保持样式一致，
  以及键盘/手柄焦点导航。适用于在 Godot 项目中布局 HUD、菜单或 UI，使用
  Control/Container 节点、锚点、主题，或在 .tscn 中设置焦点。
---

# Godot UI / Control 节点 (4.x)

使用 `Control` 锚点和 `Container` 节点布局响应式 UI，通过 `Theme` 设置样式，
并使其可通过键盘和手柄导航。目标版本为 **Godot 4.7**。

## 何时使用

- 适用于使用 `Control` 派生节点构建 HUD、菜单、物品栏、对话框或设置界面；排列能适应
  窗口尺寸的 UI；设置主题；或连接手柄/键盘焦点导航。

**不适用的情况：** 世界内 2D 节点（`Node2D`/sprites）→ `godot-nodes-scenes`；
制作 UI 过渡动画 → `godot-animation`（Tween）；卡牌手牌等特定游戏类型 UI →
`card-game`/`visual-novel`。完整的输入重绑定请参见 `input-systems`。

## 核心工作流

1. **UI 使用 `Control` 节点，** 而不是 `Node2D`。Controls 具有矩形（位置 + 尺寸）、锚点，
   并参与焦点和主题系统。
2. **使用锚点实现响应式布局。** 锚点是父矩形的比例值（0–1），Control 的边缘会附着于此。
   使用编辑器的 **Layout** 预设（Top-Left、Full Rect、Center 等），而不是手动按像素放置。
3. **让 Containers 定位子节点。** 将子节点放入 `VBoxContainer`、`HBoxContainer`、
   `GridContainer`、`MarginContainer` 等——容器会设置它们的位置/尺寸；通过 `size_flags`
   控制排列方式。不要在容器内设置子节点锚点（容器会重写它们）。
4. **使用 `Theme` 设置样式。** 在顶层 Control 上分配 `Theme` 资源；子节点会继承它。
   仅在必要时使用主题重写为单个节点覆盖样式。
5. **连接焦点，** 使手柄/键盘可以在按钮之间移动；设置默认获得焦点的 Control，
   并定义相邻项或依赖自动相邻项。
6. **连接信号**（`pressed`、`toggled`、`text_submitted`、`value_changed`）。

## 模式

### 1. 使用锚点实现响应式布局（代码形式）

```gdscript
extends Control

func _ready() -> void:
    # Stretch this panel to fill its parent (equivalent to the "Full Rect" preset).
    anchors_preset = Control.PRESET_FULL_RECT
    # Or set anchors manually: all four edges at the parent's far corners.
    # anchor_left = 0; anchor_top = 0; anchor_right = 1; anchor_bottom = 1
```

### 2. 使用容器 + 按钮信号构建菜单

```gdscript
extends VBoxContainer    # children stack vertically, auto-sized

func _ready() -> void:
    for child in get_children():
        if child is Button:
            child.pressed.connect(_on_button_pressed.bind(child.name))
    # Give the first button focus so a gamepad can navigate immediately.
    if get_child_count() > 0:
        (get_child(0) as Control).grab_focus()

func _on_button_pressed(which: StringName) -> void:
    match which:
        "PlayButton":  get_tree().change_scene_to_file("res://game.tscn")
        "QuitButton":  get_tree().quit()
```

### 3. 尺寸标志：让一个子节点扩展以填满剩余空间

```gdscript
# In a HBoxContainer: a label on the left, a spacer that eats remaining width.
func _ready() -> void:
    $Label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    $Spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # grows to fill
```

### 4. 为单个节点重写主题（无需完整 Theme 资源）

```gdscript
func _ready() -> void:
    # Per-node overrides: use add_theme_* (type-specific setters).
    $Title.add_theme_font_size_override("font_size", 32)
    $Title.add_theme_color_override("font_color", Color.GOLD)
    $Panel.add_theme_stylebox_override("panel", preload("res://ui/panel.stylebox.tres"))
```

## 常见陷阱

- **混用手动定位与 Containers。** `Container` 的子节点不能设置自己的位置/锚点——布局由容器控制。
  如需自由放置，请将节点移出容器，或使用普通的 `Control`/`PanelContainer` 包装器。
- **锚点与偏移量。** 锚点是父节点的比例值；偏移量是相对锚定点的像素增量。先通过预设设置锚点，
  再用偏移量微调。锚点为 0 时仅设置位置，会使 UI 无法随窗口缩放。
- **将 `Node2D` 用于 UI。** 位于 `Node2D` 下的按钮/标签无法正确应用主题或获得焦点。
  将 UI 保持在 `CanvasLayer`/`Control` 子树下。
- **手柄焦点丢失。** 如果没有任何节点获得焦点，方向输入不会执行任何操作。在初始 Control 上调用
  `grab_focus()`，并确保 `focus_mode` 不是 `FOCUS_NONE`。
- **Theme 与主题重写。** `Theme` 资源为整个子树设置样式；`add_theme_*` 重写单个节点。
  过度使用逐节点重写会破坏集中式主题管理。
- **`rect_*` 属性已重命名。** Godot 3 的 `rect_size`/`rect_position`/`rect_min_size`
  在 4.x 中现为 `size`/`position`/`custom_minimum_size`。
- 全矩形 Control 上的 **`mouse_filter`** 会拦截原本要传给下方节点的点击；
  对纯装饰面板设置 `MOUSE_FILTER_IGNORE`。

## 参考资料

- 关于锚点/偏移量计算、每种 Container 类型、构建/扩展 Theme 和 StyleBox 资源、
  焦点相邻项连接，以及用于 HUD 的 `CanvasLayer`，请阅读 `references/layout-and-theming.md`。

## 相关技能

- `game-ui-ux` — 跨引擎 UI/UX：响应式缩放、安全区域、焦点导航、界面流程。
- `godot-animation` — 基于 Tween 的 UI 过渡和表现增强。
- `godot-signals-groups` — 将 UI 事件连接到游戏逻辑。
- `input-systems` — 可重绑定输入和多设备焦点。
- `card-game` / `visual-novel` — 重度依赖 UI 的游戏类型模板。
