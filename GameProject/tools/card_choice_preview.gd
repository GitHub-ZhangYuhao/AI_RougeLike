extends Node

@onready var game_view = $GameView


func _ready() -> void:
    await get_tree().process_frame
    var run = game_view.run
    run.state = "choice"
    run.choiceOrigin = "levelup"
    run.pendingChoices = 1
    var preview_offers: Array[Dictionary] = [
        {
            "type": "new",
            "levelInfo": "获得 Lv.1",
            "card": {"id": "sword", "name": "飞剑", "kind": "weapon", "desc": "御剑回旋，自动追击附近敌人"},
        },
        {
            "type": "upgrade",
            "levelInfo": "Lv.1  →  Lv.2",
            "card": {"id": "cloak", "name": "烈焰衣", "kind": "weapon", "desc": "烈焰护体，灼烧靠近的敌人"},
        },
        {
            "type": "attr",
            "levelInfo": "经验获取 +15%",
            "card": {"id": "xp", "name": "悟道", "kind": "attr", "desc": "心境澄明，更快参悟天地灵机"},
        },
    ]
    run.currentOffers = preview_offers
    run.input.mouse_move(640.0, 390.0)
    game_view.overlay.queue_redraw()