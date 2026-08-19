---
name: game-ui-ux
description: >
  设计与构建能够适配所有屏幕的游戏用户界面及体验——包括 HUD、菜单和覆盖层；采用基于锚点的响应式布局以实现分辨率与比例缩放及安全区域适配；支持键盘/手柄焦点导航；管理屏幕/菜单状态栈；并实施事件驱动（非轮询）的 HUD 更新。这些引擎无关的模式可与检测到的游戏引擎 UI 技能配合使用。当用户提及 HUD、血条、主菜单、暂停菜单、设置界面、UI 布局、锚点、UI 缩放、宽高比、安全区域、手柄/键盘菜单导航，或将 UI 与游戏状态连接时请使用此技能。
---

# 游戏 UI/UX

构建能够在手机、超宽显示器和电视上保持正确显示的 HUD 和菜单，同时兼容手柄和鼠标。本技能掌握引擎无关的 UI 架构——响应式布局、缩放、焦点导航、屏幕流程以及 UI 如何与游戏状态交互——并将具体的组件 API 委托给引擎 UI 技能处理。

## 何时使用

- **使用场景**：在构建 HUD（生命值/弹药数/分数）、菜单（主菜单/暂停/设置）、库存或商店界面，或其他任何覆盖层时，若希望其能正确缩放和导航，请使用此技能。
- **修复问题**：用于解决在其他分辨率/宽高比下 UI 崩溃、忽略刘海屏/安全区域、无法配合手柄使用，或因每帧轮询而绑定游戏状态的问题。
- **结构化流程**：用于将屏幕流程（标题 → 游戏 → 暂停 → 设置）构建为栈结构，而非标志位集合。

**何时不应用此技能**：针对引擎具体 UI 节点、组件及样式处理，请使用 `godot-ui-control` 或 Unity UI (UGUI/UI Toolkit)；用于视觉冲击效果（如按钮弹跳、伤害数字显示、屏幕震动），请选用 `game-feel`；在分支对话界面中，应使用 `dialogue-systems`；如需翻译 UI 文本字符串，则属于本地化工作（参考 `references/` 和 `input-systems` 以重新绑定屏幕）；对于卡片或棋盘布局的具体实现，《卡牌游戏》流派会组合此技能。

## 核心工作流

1. **选择布局模型：锚点 + 容器，绝不使用绝对像素坐标。** 将元素锚定到边缘、角落或中心，让容器（行、列、网格）自动排列子项。绝对的 `(x, y)` 位置会在遇到第一个新分辨率时失效。
2. **为整个 UI 选择合适的缩放策略**：设定一个参考分辨率以适配窗口大小（大多数游戏），并制定其他宽高比下的额外宽度/高度政策（黑边模式、全屏扩展，或将 HUD 角落锚点向外延伸）。
3. **尊重安全区域。** 将关键 UI 元素内缩于屏幕边缘之外，防止刘海屏圆角和电视过扫描区域遮挡内容。
4. **确保每个屏幕均可键盘/手柄导航。** 为每页设置初始焦点控件，定义焦点顺序与相邻项，并显示清晰的焦点高亮。鼠标操作必须能与焦点共存。
5. **将屏幕建模为栈结构。** 压入（暂停覆盖游戏）、弹出（恢复），并将输入和可见性传递给顶层屏幕。这使得覆盖层和“返回”功能变得简单。
6. **通过事件驱动 HUD，而非轮询。** HUD 订阅 `health_changed`、`score_changed` 等信号，仅在触发时更新——它不会每帧读取游戏状态。
7. **跨设备和分辨率进行验证。** 调整窗口大小、切换宽高比、拔掉鼠标仅用手柄导航，并确认焦点、缩放和安全区域内边距是否正确。报告你在哪些分辨率下实际观察到的情况。

## 模式

### 1. 使用锚点和容器，而不是绝对坐标（Anchors + Containers）

```gdscript
# Godot 4.7. Anchor a HUD label to the TOP-LEFT; let a container flow a row of hearts.
func _ready() -> void:
    $Score.set_anchors_preset(Control.PRESET_TOP_LEFT)   # sticks to the corner at any size
    # An HBoxContainer auto-lays-out children left-to-right; never position hearts by hand.
    for i in lives:
        $Hearts.add_child(make_heart())                   # HBoxContainer spaces them for you
# Unity 6.3 LTS uGUI: set RectTransform anchors to the corner; use a HorizontalLayoutGroup.
# RIGHT: anchors + layout groups. WRONG: rect.anchoredPosition = new Vector2(640, 360) (1080p-only).
```
### 2. 将界面缩放到参考分辨率（一套 UI 适配多屏）

```text
# Godot 4.7 — Project Settings > Display > Window > Stretch:
#   Mode = "canvas_items", Aspect = "expand", reference size e.g. 1920x1080.
#   UI scales to the window; "expand" reveals extra space you anchor HUD corners into.
# Unity 6.3 LTS — Canvas > CanvasScaler:
#   UI Scale Mode = "Scale With Screen Size", Reference Resolution = 1920x1080,
#   Match = 0.5 (blend width/height) — pick 1.0 if your HUD is height-critical.
```
### 3. 刘海屏/过扫描的安全区域内边距

```gdscript
# Godot 4.7. Inset a margin container to the OS-reported safe rect (phones, TVs).
func _apply_safe_area() -> void:
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    var win := DisplayServer.window_get_size()
    $Margin.add_theme_constant_override("margin_left", safe.position.x)
    $Margin.add_theme_constant_override("margin_top",  safe.position.y)
    $Margin.add_theme_constant_override("margin_right", win.x - safe.end.x)
    $Margin.add_theme_constant_override("margin_bottom", win.y - safe.end.y)
# Unity 6.3 LTS: read Screen.safeArea (Rect in pixels) and set a panel's anchorMin/anchorMax to
# safeArea.position / (position+size) normalized by Screen.width/height.
```
### 4. 游戏手柄/键盘焦点（若无此功能，在控制器上将无法正常使用界面）

```gdscript
# Godot 4.7. Give each screen a default focus and wire neighbors so a stick/d-pad walks it.
func _on_screen_shown() -> void:
    $PlayButton.grab_focus()                               # always focus SOMETHING on open
$PlayButton.focus_neighbor_bottom = $SettingsButton.get_path()
$SettingsButton.focus_neighbor_top = $PlayButton.get_path()
# Unity 6.3 LTS: EventSystem.SetSelectedGameObject(playButton) on enable; set each Selectable's
# Navigation (Explicit or Automatic). RIGHT: a control is focused on open. WRONG: nothing
# selected → the gamepad does nothing and the player is stuck.
```
### 5. 基于事件的 HUD（将 UI 与游戏逻辑解耦）

```gdscript
# RIGHT: HUD reacts to a signal; it updates only when health actually changes.
func _ready() -> void:
    player.health_changed.connect(_on_health_changed)     # emitted by gameplay
func _on_health_changed(current: int, max: int) -> void:
    $HealthBar.value = float(current) / max
# WRONG: func _process(dt): $HealthBar.value = player.hp / player.max_hp  # polls every frame,
# couples UI to the player's internals, and runs work even when nothing changed.
```
## 常见陷阱

- **绝对像素位置/单一设计分辨率。** 在你的显示器上看起来完美，但在其他设备上完全崩坏。应锚定到边缘或中心，并使用容器进行布局流动。
- **缺乏宽高比策略。** 仅适配 16:9 的布局会在超宽屏和手机上出现严重的裁剪或黑边问题。决定采用扩展模式还是黑边模式，并将 HUD 锚定在向外移动的角落上。
- **忽略安全区域。** HUD 被刘海屏遮挡或在电视过扫描范围内丢失。应将关键元素进行内缩处理。
- **缺乏初始焦点/无焦点邻居定义。** 游戏在手柄下无法游玩；玩家进入菜单时没有任何选项被选中。始终聚焦一个控件并定义导航路径。
- **在 `_process`/`Update` 中轮询游戏状态。** 将 UI 与内部逻辑耦合且浪费计算资源。应通过信号或事件推送更新。
- **固定的微小字体大小。** 在大距离观看电视或小手机上难以阅读。让文本随 UI 缩放，并提供字号选项。
- **菜单流程使用布尔标志 (`isPaused`, `inSettings` …)。** 会变得难以管理。请使用带压入/弹出功能的屏幕栈结构。
- **硬编码的英文字符串嵌入布局中。** 翻译后会导致按钮溢出。将文本外部化，让容器根据内容自动调整大小（参见 `references/`）。
- **仅支持鼠标或仅支持焦点操作。** 应同时支持两者；切换输入设备不应让用户陷入困境。

## 参考资料

- 关于各引擎的拉伸/缩放模式、安全区域数学计算、完整的焦点导航和屏幕栈模式、叙事性与非叙事性 UI、无障碍功能（文本大小、对比度、色盲友好状态）以及本地化就绪布局，请阅读 `references/layout-and-flow.md`。

## 相关技能

- `godot-ui-control`（Unity UI/UGUI/UI Toolkit）——针对具体组件、主题及样式的处理。
- `game-feel` —— 基于此布局之上的按钮弹跳效果、过渡动画及 HUD“爽感”元素。
- `dialogue-systems` —— 运行在此 UI 外壳内部的对话/选择界面系统。
- `input-systems` —— 设备切换、重新绑定屏幕和可访问控件处理。
- `rpg`, `card-game`, `tower-defense`, `visual-novel` —— 高度依赖 UI 的流派，会组合使用此技能。
