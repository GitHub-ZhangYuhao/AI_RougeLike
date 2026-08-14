extends RefCounted

const CardsScript: GDScript = preload("res://logic/cards.gd")

func title() -> String:
    return "[1] 主菜单开局选卡"

func run(runner) -> void:
    Rng.set_seed(1001)
    var game = runner.harness.ensure_game()
    runner.check(game.state == "menu", "[1] 初始状态应为主菜单，实际 %s" % game.state)
    runner.check(game.currentOffers.size() == CardsScript.WEAPON_CARDS.size(), "[1] 开局应展示全部武器卡")
    var runs_before: int = game.save["stats"]["runs"]
    runner.harness.key_down("Enter")
    runner.harness.key_up("Enter")
    runner.harness.pump(1)
    runner.check(game.state == "opening", "[1] Enter 开局后应进入开局选卡，实际 %s" % game.state)
    runner.check(game.save["stats"]["runs"] == runs_before + 1, "[1] 开局数应 +1")
    for offer: Dictionary in game.currentOffers:
        runner.check(offer["card"]["kind"] == "weapon" and offer["type"] == "new", "[1] 开局卡牌应全部是新武器卡")
    runner.harness.pump_with_choices(3, func(offer): return offer["card"]["id"] != "trail")
    runner.check(game.state == "playing", "[1] 选卡后应进入 playing，实际 %s" % game.state)
    runner.check(game.weapons.size() == 1, "[1] 选卡后应持有 1 把武器")
    Rng.clear_source()
