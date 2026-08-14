extends Node2D
## M1 表现壳：Godot 输入 → InputState；60Hz 累加器驱动纯逻辑；占位绘制。

const GameRunScript: GDScript = preload("res://logic/game_run.gd")
const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")
const STEP: float = 1.0 / 60.0

var run = GameRunScript.new()
var accumulator: float = 0.0


func _ready() -> void:
    set_process_input(true)
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
    queue_redraw()


func _draw() -> void:
    var size: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color("0e0e16"))
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
    draw_circle(Vector2(run.player.x, run.player.y) + offset, run.player.radius, Color("4fc3f7"))
    draw_string(ThemeDB.fallback_font, Vector2(14, 28), "Lv %d  HP %.0f/%.0f  Kills %d  Wave %d" % [run.level, run.player.hp, run.player.maxHp, run.kills, run.waveDirector.wave], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    if run.state == "menu":
        draw_string(ThemeDB.fallback_font, center - Vector2(120, 0), "Press Enter to Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
    elif run.state == "opening" or run.state == "choice":
        var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(size.x, size.y, run.currentOffers.size())
        for i in rects.size():
            var rect: Dictionary = rects[i]
            draw_rect(Rect2(rect["x"], rect["y"], rect["w"], rect["h"]), Color("25253a"), true)
            draw_string(ThemeDB.fallback_font, Vector2(rect["x"] + 12, rect["y"] + 32), "%d. %s" % [i + 1, run.currentOffers[i]["card"]["name"]], HORIZONTAL_ALIGNMENT_LEFT, rect["w"] - 24, 18, Color.WHITE)
    elif run.state == "extraction":
        draw_string(ThemeDB.fallback_font, center - Vector2(190, 0), "Boss cleared: [E] Extract  [C] Continue", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd54f"))
    elif run.state == "dead":
        draw_string(ThemeDB.fallback_font, center - Vector2(110, 0), "Defeated - [R] Return", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ef5350"))
    elif run.state == "summary":
        draw_string(ThemeDB.fallback_font, center - Vector2(120, 0), "Run Complete - Enter", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("69f0ae"))
    if run.rareMessage != null:
        draw_string(ThemeDB.fallback_font, center - Vector2(80, 80), str(run.rareMessage["text"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color("ffd54f"))


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
