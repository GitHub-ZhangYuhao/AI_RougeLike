extends Node2D

const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")

var run = null


func bind_run(game_run) -> void:
    run = game_run
    queue_redraw()


func refresh() -> void:
    queue_redraw()


func _draw() -> void:
    if run == null:
        return
    var size: Vector2 = get_viewport_rect().size
    var center := size * 0.5
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
