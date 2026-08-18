extends Node2D
## Godot 输入 → InputState；60Hz 累加器驱动纯逻辑；正式美术表现层只读取运行状态。
const GameRunScript: GDScript = preload('res://logic/game_run.gd')
const STEP: float = 1.0 / 60.0
const CAMERA_ZOOM: float = 0.82
const CAMERA_VISUAL_OFFSET_Y: float = -18.0

var run = GameRunScript.new()
var accumulator: float = 0.0
var visual_time: float = 0.0

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


func _physics_process(delta: float) -> void:
	visual_time += delta
	accumulator += minf(0.25, delta)
	var size: Vector2 = get_viewport_rect().size
	while accumulator >= STEP:
		run.step(STEP, size.x / CAMERA_ZOOM, size.y / CAMERA_ZOOM)
		run.input.end_frame()
		accumulator -= STEP
	_sync_views(size)
	world_art.refresh(delta)
	overlay.refresh(delta)
	meta_screens.refresh()


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
