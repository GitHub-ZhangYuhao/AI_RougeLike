extends Control
## 虚拟摇杆控制器 - 用于移动端和小游戏环境
## 支持触摸拖动和鼠标操作，输出归一化的移动向量
## 自适应屏幕尺寸，适配不同分辨率手机
##
## 视觉不再用 Control._draw() 手绘（圆形/圆弧/方向指示线）：Godot 有个已知引擎
## bug（godotengine/godot#112757，"Control nodes custom draw calls get culled
## incorrectly"，直到较新版本才修复）——Control 的自定义 _draw() 会按节点的
## transform 矩形做裁剪判断，某些时序下会被直接跳过，Node2D 不受影响。微信这个
## 小游戏定制引擎构建基于 2026-07 的快照，大概率还没有这个修复，且真机上确认
## 表现为摇杆整体不可见（游戏内其它 UI 都是 Node2D._draw()，唯独摇杆是
## Control._draw()，且是全项目唯一一处）。改成 Background/Knob 两个 Panel +
## StyleBoxFlat 圆角矩形（圆角=半径即为圆形），走 Godot 原生 Control 渲染，不
## 依赖 _draw()，规避这个引擎级问题；顺带用更精细的配色替换原来的灰色占位块。

var _touching: bool = false
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob_position: Vector2 = Vector2.ZERO
var _radius: float = 80.0
var _knob_radius: float = 40.0
var _base_radius: float = 80.0
var _base_knob_radius: float = 40.0

signal joystick_moved(vector: Vector2)
signal joystick_released()

@onready var knob: Panel = $Knob
@onready var background: Panel = $Background


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(background, Color(0.15, 0.17, 0.2, 0.55), Color(0.75, 0.85, 0.95, 0.55), 2.0)
	_style_panel(knob, Color(0.55, 0.75, 0.9, 0.85), Color(0.9, 0.97, 1.0, 0.9), 2.0)
	_center = size * 0.5
	_knob_position = _center
	_adapt_to_screen_size()
	show()
	# 诊断日志：核对微信小游戏里这个 Control 的实际位置/尺寸/可见性是否与桌面端一致
	# （排查摇杆在小游戏里不显示的问题）；确认问题后可删除。
	print("[diag] joystick global_rect=%s visible=%s modulate=%s layer=%s" % [
		get_global_rect(), visible, modulate,
		(get_parent() as CanvasLayer).layer if get_parent() is CanvasLayer else "n/a"])
	# 防御性兜底：Control 的 size 在 _ready() 阶段有时还没从 anchor/offset 结算完
	# （读到 (0,0)），等一帧让布局真正结算完，不对就重算一次。
	await get_tree().process_frame
	if size != Vector2.ZERO:
		_adapt_to_screen_size()
		print("[diag] joystick post-layout global_rect=%s" % [get_global_rect()])


func _style_panel(panel: Panel, fill: Color, border: Color, border_width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4096)  # 远大于半径，Godot 会自动夹到圆形
	panel.add_theme_stylebox_override("panel", style)


func _adapt_to_screen_size() -> void:
	var screen_size = get_viewport_rect().size
	var min_dimension = minf(screen_size.x, screen_size.y)
	# 基于屏幕最小边计算缩放因子（适配不同分辨率）
	var scale_factor = min_dimension / 720.0  # 以720p为基准
	# 限制缩放范围，避免过大或过小
	scale_factor = clampf(scale_factor, 0.8, 1.5)

	_radius = _base_radius * scale_factor
	_knob_radius = _base_knob_radius * scale_factor
	_center = size * 0.5
	_knob_position = _center
	background.position = _center - Vector2(_radius, _radius)
	background.size = Vector2(_radius, _radius) * 2.0
	knob.size = Vector2(_knob_radius, _knob_radius) * 2.0
	_update_knob_position()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_touch(event: InputEventScreenTouch) -> void:
	# 用触摸事件自带的 position 命中检测，不要依赖 get_global_mouse_position()：
	# 微信小游戏这个引擎构建上，原始触摸事件不一定会同步更新 Godot 内部的
	# "鼠标位置"（通常靠 emulate_mouse_from_touch 生成合成鼠标事件才会同步），
	# 之前一直用 get_global_mouse_position() 判断，导致命中检测读到的是过期/
	# 零值坐标，摇杆按下永远判定不在范围内，也就永远拖不动。
	if event.pressed and event.index == 0:
		if event.position.distance_to(global_position + _center) < _radius:
			_touching = true
			_touch_index = event.index
			_update_from_position(event.position)
	elif not event.pressed and event.index == _touch_index:
		_touching = false
		_touch_index = -1
		_knob_position = _center
		_update_knob_position()
		joystick_released.emit()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _touching and event.index == _touch_index:
		_update_from_position(event.position)


func _handle_mouse(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if get_global_mouse_position().distance_to(global_position + _center) < _radius:
				_touching = true
		else:
			_touching = false
			_knob_position = _center
			_update_knob_position()
			joystick_released.emit()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _touching:
		_update_from_position(event.position)


func _update_from_position(position: Vector2) -> void:
	var local_pos = position - global_position
	var direction = local_pos - _center
	var distance = direction.length()

	if distance > _radius:
		direction = direction.normalized() * _radius
		distance = _radius

	_knob_position = _center + direction
	_update_knob_position()

	var normalized_vector = direction / _radius
	joystick_moved.emit(normalized_vector)


func _update_knob_position() -> void:
	knob.position = _knob_position - Vector2(_knob_radius, _knob_radius)
