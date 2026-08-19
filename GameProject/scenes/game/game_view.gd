extends Node2D
## Godot 输入 → InputState；60Hz 累加器驱动纯逻辑；正式美术表现层只读取运行状态。
const GameRunScript: GDScript = preload('res://logic/game_run.gd')
const UiLayoutScript: GDScript = preload('res://logic/ui_layout.gd')
const STEP: float = 1.0 / 60.0
const CAMERA_ZOOM: float = UiLayoutScript.CAMERA_ZOOM
const CAMERA_VISUAL_OFFSET_Y: float = -18.0

var run = GameRunScript.new()
var accumulator: float = 0.0
var visual_time: float = 0.0
## 用于表现层检测波次更替与状态切换，驱动 sfx_requested 发射。
var _prev_view_wave: int = 0
var _prev_view_state: String = ""

@onready var meadow_level = $MeadowLevel
@onready var world_art = $WorldArtView
@onready var player_view = $PlayerView
@onready var overlay = $GameOverlay
@onready var meta_screens = $MetaLayer/MetaScreens
@onready var debug_overlay = $DebugLayer/DebugOverlay
@onready var screen_atmosphere = $ScreenAtmosphere


func _ready() -> void:
	set_process_input(true)
	world_art.bind_run(run)
	overlay.bind_run(run)
	meta_screens.bind_run(run)
	debug_overlay.bind_run(run)
	AudioManager.bind_run(run)
	_prev_view_wave = run.waveDirector.wave
	_prev_view_state = run.state
	_sync_views(get_viewport_rect().size)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == KEY_F2:
			debug_overlay.toggle()
			get_viewport().set_input_as_handled()
			return
		if debug_overlay.is_open():
			if event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
				debug_overlay.set_open(false)
				get_viewport().set_input_as_handled()
				return
		var code: String = _key_code(event as InputEventKey)
		if not code.is_empty():
			if event.pressed:
				run.input.key_down(code)
			else:
				run.input.key_up(code)
	elif event is InputEventMouseMotion:
		if debug_overlay.consumes_pointer(event.position):
			return
		run.input.mouse_move(event.position.x, event.position.y)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if debug_overlay.consumes_pointer(event.position):
			return
		run.input.mouse_move(event.position.x, event.position.y)
		run.input.mouse_down()
	elif event is InputEventScreenTouch:
		# 移动端触摸：主手指（index 0）按下等效鼠标左键点击，选卡/菜单热点复用鼠标命中语义。
		# emulate_mouse_from_touch 开启时系统还会派发模拟鼠标事件，mouse_down() 幂等，重复无害。
		if event.pressed and event.index == 0:
			if debug_overlay.consumes_pointer(event.position):
				return
			run.input.mouse_move(event.position.x, event.position.y)
			run.input.mouse_down()
	elif event is InputEventScreenDrag:
		if event.index == 0:
			if debug_overlay.consumes_pointer(event.position):
				return
			run.input.mouse_move(event.position.x, event.position.y)


func _physics_process(delta: float) -> void:
	visual_time += delta
	accumulator += minf(0.25, delta)
	var size: Vector2 = get_viewport_rect().size
	while accumulator >= STEP:
		run.step(STEP, size.x / CAMERA_ZOOM, size.y / CAMERA_ZOOM)
		run.input.end_frame()
		accumulator -= STEP
	_detect_audio_events()
	_sync_views(size)
	world_art.refresh(delta)
	overlay.refresh(delta)
	meta_screens.refresh()


## 表现层音效触发：检测波次更替与状态切换，通过 Events.sfx_requested 广播。
## AudioManager 已通过轮询覆盖大部分隐式音效（敌人死亡、宝石拾取、受击等），
## 此处仅补充轮询难以捕获的事件（波次起始横幅、进入撤离等）。
func _detect_audio_events() -> void:
	# 波次更替：waveDirector.wave 递增时视为新波次开始
	var current_wave: int = run.waveDirector.wave
	if current_wave > _prev_view_wave and run.state == "playing":
		if run.waveDirector.isBossWave:
			Events.sfx_requested.emit("sfx_boss_alarm", {})
		else:
			Events.sfx_requested.emit("sfx_wave_start", {})
	_prev_view_wave = current_wave
	# 状态切换音效：进入撤离 / 死亡等关键节点
	var current_state: String = run.state
	if current_state != _prev_view_state:
		if current_state == "extraction":
			Events.sfx_requested.emit("sfx_extraction", {})
	_prev_view_state = current_state


func _sync_views(size: Vector2) -> void:
	run.viewport_size = size
	# Scale ScreenAtmosphere ColorRect to fill the viewport
	if screen_atmosphere is ColorRect:
		screen_atmosphere.offset_right = size.x
		screen_atmosphere.offset_bottom = size.y
	var camera_visual := Vector2(run.camera.x, run.camera.y + CAMERA_VISUAL_OFFSET_Y)
	var base_offset := size * 0.5 - camera_visual
	if run.hitShake > 0.0:
		var strength: float = clampf(run.hitShake / 0.25, 0.0, 1.0) * 7.0
		base_offset += Vector2(sin(visual_time * 83.0), cos(visual_time * 67.0)) * strength
	var zoomed_offset := size * 0.5 - (size * 0.5 - base_offset) * CAMERA_ZOOM
	meadow_level.position = zoomed_offset
	meadow_level.scale = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	world_art.position = zoomed_offset
	world_art.scale = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	var player_screen := Vector2(run.player.x, run.player.y) * CAMERA_ZOOM + zoomed_offset
	player_view.sync_from(run.player, run.state, player_screen)
	player_view.scale = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)


func _key_code(event: InputEventKey) -> String:
	match event.physical_keycode:
		KEY_W: return 'KeyW'
		KEY_A: return 'KeyA'
		KEY_S: return 'KeyS'
		KEY_D: return 'KeyD'
		KEY_UP: return 'ArrowUp'
		KEY_DOWN: return 'ArrowDown'
		KEY_LEFT: return 'ArrowLeft'
		KEY_RIGHT: return 'ArrowRight'
		KEY_ENTER: return 'Enter'
		KEY_SPACE: return 'Space'
		KEY_ESCAPE: return 'Escape'
		KEY_1: return 'Digit1'
		KEY_2: return 'Digit2'
		KEY_3: return 'Digit3'
		KEY_4: return 'Digit4'
		KEY_5: return 'Digit5'
		KEY_6: return 'Digit6'
		KEY_C: return 'KeyC'
		KEY_E: return 'KeyE'
		KEY_R: return 'KeyR'
	return ''
