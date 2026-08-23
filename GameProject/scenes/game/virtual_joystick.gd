extends Control
## 虚拟摇杆控制器 - 用于移动端和小游戏环境
## 支持触摸拖动和鼠标操作，输出归一化的移动向量
## 自适应屏幕尺寸，适配不同分辨率手机

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

@onready var knob = $Knob
@onready var background = $Background

func _ready() -> void:
	_center = size * 0.5
	_knob_position = _center
	_update_knob_position()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 确保摇杆可见
	show()
	# 根据屏幕尺寸自适应调整摇杆大小
	_adapt_to_screen_size()
	# 在PC端也显示摇杆（用于测试）
	show()
	# 诊断日志：核对微信小游戏里这个 Control 的实际位置/尺寸/可见性是否与桌面端一致
	# （排查摇杆在小游戏里不显示的问题）；确认问题后可删除。
	print("[diag] joystick global_rect=%s visible=%s modulate=%s layer=%s" % [
		get_global_rect(), visible, modulate,
		(get_parent() as CanvasLayer).layer if get_parent() is CanvasLayer else "n/a"])

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
	if event.pressed and event.index == 0:
		if get_global_mouse_position().distance_to(global_position + _center) < _radius:
			_touching = true
			_touch_index = event.index
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

func _draw() -> void:
	# 绘制摇杆背景
	draw_circle(_center, _radius, Color(0.3, 0.3, 0.3, 0.6))
	# 绘制摇杆边缘
	draw_arc(_center, _radius, 0, TAU, 32, Color(0.7, 0.7, 0.7, 0.9), 3.0)
	# 绘制摇杆中心点
	draw_circle(_center, 8.0 * (_radius / _base_radius), Color(0.8, 0.8, 0.8, 0.8))
	# 绘制方向指示
	var indicator_radius = _radius * 0.7
	draw_line(_center, _center + Vector2(indicator_radius, 0), Color(0.6, 0.6, 0.6, 0.5), 2.0)
	draw_line(_center, _center + Vector2(0, indicator_radius), Color(0.6, 0.6, 0.6, 0.5), 2.0)