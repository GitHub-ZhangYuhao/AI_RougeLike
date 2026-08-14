extends Node2D
## M1 表现壳：Godot 输入 → InputState；60Hz 累加器驱动纯逻辑；占位绘制。

const GameRunScript: GDScript = preload("res://logic/game_run.gd")
const STEP: float = 1.0 / 60.0

var run = GameRunScript.new()
var accumulator: float = 0.0

@onready var meadow_level = $MeadowLevel
@onready var player_view = $PlayerView
@onready var overlay = $GameOverlay


func _ready() -> void:
	set_process_input(true)
	overlay.bind_run(run)
	_sync_views(get_viewport_rect().size)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: String = _key_code(event as InputEventKey)
		if not code.is_empty():
			if event.pressed:
				run.input.key_down(code)
			else:
				run.input.key_up(code)
	elif event is InputEventMouseMotion:
		run.input.mouse_move(event.position.x, event.position.y)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		run.input.mouse_move(event.position.x, event.position.y)
		run.input.mouse_down()


func _physics_process(delta: float) -> void:
	accumulator += minf(0.25, delta)
	var size: Vector2 = get_viewport_rect().size
	while accumulator >= STEP:
		run.step(STEP, size.x, size.y)
		run.input.end_frame()
		accumulator -= STEP
	_sync_views(size)
	overlay.refresh()
	queue_redraw()


func _sync_views(size: Vector2) -> void:
	var offset := size * 0.5 - Vector2(run.camera.x, run.camera.y)
	meadow_level.position = offset
	player_view.sync_from(run.player, run.state, Vector2(run.player.x, run.player.y) + offset)


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var center := size * 0.5
	var offset := center - Vector2(run.camera.x, run.camera.y)
	for gem: Dictionary in run.gems:
		draw_circle(Vector2(gem["x"], gem["y"]) + offset, 5.0, Color(gem["color"]))
	for pickup in run.pickups:
		var pickup_color := Color("ffd54f") if pickup.get("kind") == "rare" else Color("66bb6a")
		draw_circle(Vector2(pickup["x"], pickup["y"]) + offset, 9.0, pickup_color)
	for projectile in run.hostileProjectiles:
		draw_circle(Vector2(projectile.x, projectile.y) + offset, projectile.radius, Color("ffb74d"))
	for effect in run.effects:
		draw_arc(Vector2(effect["x"], effect["y"]) + offset, effect["radius"], 0.0, TAU, 32, Color(effect["color"]), 3.0)
	var enemy_colors: Dictionary = {"chaser": Color("ef5350"), "enhancedChaser": Color("d84315"),
		"charger": Color("ff7043"), "ranged": Color("ab47bc"), "bomber": Color("ffca28"),
		"shield": Color("78909c"), "boss": Color("7e57c2")}
	for enemy in run.enemies:
		var body_color: Color = Color("81d4fa") if enemy.frozenTimer > 0.0 else enemy_colors.get(enemy.type, Color("ef5350"))
		draw_circle(Vector2(enemy.x, enemy.y) + offset, enemy.radius, body_color)
		if enemy.slowTimer > 0.0:
			draw_arc(Vector2(enemy.x, enemy.y) + offset, enemy.radius + 4.0, 0.0, TAU, 20, Color("80cbc4"), 2.0)
		if enemy.rank == "boss":
			draw_arc(Vector2(enemy.x, enemy.y) + offset, enemy.radius + 8.0, 0.0, TAU, 24, Color("ffd54f"), 4.0)


func _key_code(event: InputEventKey) -> String:
	match event.physical_keycode:
		KEY_W: return "KeyW"
		KEY_A: return "KeyA"
		KEY_S: return "KeyS"
		KEY_D: return "KeyD"
		KEY_UP: return "ArrowUp"
		KEY_DOWN: return "ArrowDown"
		KEY_LEFT: return "ArrowLeft"
		KEY_RIGHT: return "ArrowRight"
		KEY_ENTER: return "Enter"
		KEY_SPACE: return "Space"
		KEY_ESCAPE: return "Escape"
		KEY_1: return "Digit1"
		KEY_2: return "Digit2"
		KEY_3: return "Digit3"
		KEY_4: return "Digit4"
		KEY_5: return "Digit5"
		KEY_6: return "Digit6"
		KEY_C: return "KeyC"
		KEY_E: return "KeyE"
		KEY_R: return "KeyR"
	return ""
