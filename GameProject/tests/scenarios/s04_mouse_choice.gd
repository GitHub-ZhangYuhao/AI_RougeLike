extends RefCounted

const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")

func title() -> String:
    return "[4] 鼠标点击选卡"

func run(runner) -> void:
    Rng.set_seed(4004)
    var game = runner.harness.ensure_game()
    game.pendingChoices = 0
    game.xp = 0.0
    game.gain_xp(game.xp_to_next() / game.mods["xpMult"] + 0.001)
    runner.harness.pump(3)
    runner.check(game.state == "choice", "[4] 升级后应进入选卡界面，实际 %s" % game.state)
    runner.check(not game.currentOffers.is_empty(), "[4] 选卡选项为空")
    if game.currentOffers.is_empty():
        Rng.clear_source()
        return
    var offer: Dictionary = game.currentOffers[0]
    var before_count: int = game.weapons.size()
    var before_stack: int = game.attrStacks.get(offer["card"]["id"], 0)
    var before_level: int = 0
    for weapon in game.weapons:
        if weapon.card["id"] == offer["card"]["id"]:
            before_level = weapon.level
    var rect: Dictionary = UiLayoutScript.get_card_rects(1280, 720, game.currentOffers.size())[0]
    runner.harness.mouse_move(rect["x"] + rect["w"] / 2.0, rect["y"] + rect["h"] / 2.0)
    runner.harness.mouse_down()
    runner.harness.mouse_up()
    runner.harness.pump(3)
    runner.check(game.state == "playing", "[4] 鼠标选卡后应回到 playing，实际 %s" % game.state)
    if offer["type"] == "new":
        runner.check(game.weapons.size() == before_count + 1, "[4] 新武器未入槽")
    elif offer["type"] == "upgrade":
        var upgraded: bool = false
        for weapon in game.weapons:
            if weapon.card["id"] == offer["card"]["id"] and weapon.level == before_level + 1:
                upgraded = true
        runner.check(upgraded, "[4] 武器等级未提升")
    else:
        runner.check(game.attrStacks.get(offer["card"]["id"], 0) == before_stack + 1, "[4] 属性层数未增加")
    Rng.clear_source()
