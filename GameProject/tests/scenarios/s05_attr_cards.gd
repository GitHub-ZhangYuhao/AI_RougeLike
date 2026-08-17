extends RefCounted

const CardsScript: GDScript = preload("res://logic/cards.gd")

func title() -> String:
    return "[5] Base attributes"

func run(runner) -> void:
    var ids: Array[String] = []
    for card: Dictionary in CardsScript.ATTR_CARDS:
        ids.append(card["id"])
    runner.check(ids == ["damage", "armor", "magnet", "xp", "maxHp", "moveSpeed"], "[5] attribute pool contains removed or missing cards")
    runner.check(Config.CONFIG["gems"]["magnetRadius"] == 240, "[5] base magnet radius must be 240px")
    runner.check(Config.CONFIG["gems"]["pickupRadius"] == 30, "[5] gem pickup radius must be 30px")
    runner.check(Config.CONFIG["pickups"]["pickupRadius"] == 30 and Config.CONFIG["pickups"]["rarePickupRadius"] == 58, "[5] pickup radii must match enlarged UX targets")
    var mods: Dictionary = CardsScript.compute_mods({"damage": 2, "armor": 5, "magnet": 2, "xp": 3, "maxHp": 2, "moveSpeed": 1})
    var expected: Dictionary = {"damageMult": 1.3, "armor": 75.0, "damageReduction": 75.0 / 175.0, "magnetRadiusBonus": 100.0, "xpMult": 1.45, "maxHpBonus": 40.0, "moveSpeedMult": 1.06}
    for key: String in expected:
        runner.check(absf(mods[key] - expected[key]) < 0.000001, "[5] bad %s: %s" % [key, mods[key]])
    runner.check(CardsScript.compute_mods({"armor": 1000})["damageReduction"] == 0.5, "[5] armor reduction must cap at 50%")
    runner.check(CardsScript.compute_mods({"unknown": 99})["damageMult"] == 1.0, "[5] compute_mods must ignore unknown ids")
    var game = runner.harness.ensure_game()
    var saved_stacks: Dictionary = game.attrStacks
    var saved_mods: Dictionary = game.mods
    var saved_hp: float = game.player.hp
    var saved_max_hp: float = game.player.maxHp
    game.attrStacks = {}
    game.recompute_mods()
    game.player.hp = 50.0
    game.player.maxHp = 100.0
    game._apply_offer({"card": CardsScript.card_by_id("maxHp"), "type": "attr"})
    runner.check(game.player.maxHp == 120.0 and game.player.hp == 70.0, "[5] max HP card must add and heal 20")
    game.mods = CardsScript.compute_mods({"armor": 5})
    game.player.hp = 100.0
    game.player.iFrames = 0.0
    game.hurt_player(100.0)
    runner.check(absf(game.player.hp - (100.0 - 100.0 * (1.0 - 75.0 / 175.0))) < 0.000001, "[5] player armor reduction was not applied")
    game.attrStacks = saved_stacks
    game.mods = saved_mods
    game.player.hp = saved_hp
    game.player.maxHp = saved_max_hp
    game.player.iFrames = 0.0
