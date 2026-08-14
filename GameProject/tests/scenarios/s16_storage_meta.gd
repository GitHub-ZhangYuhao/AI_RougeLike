extends RefCounted

const ItemsScript: GDScript = preload("res://logic/meta/items.gd")

func title() -> String: return "[16] Storage and meta attributes"

func run(runner) -> void:
    var game = runner.harness.game
    game.save["storage"] = {"shard": 4, "essence": 2, "soulCrystal": 1}
    MetaSave.persist_save(game.save)
    game.open_storage()
    runner.check(game.state == "storage", "[16] open storage")
    var before: int = game.save["darkCrystals"]
    runner.check(game.sell_storage_item("shard") == 4 * ItemsScript.META_ITEMS["shard"]["sellPrice"], "[16] sell one material stack")
    runner.check(game.save["storage"]["shard"] == 0 and game.save["darkCrystals"] == before + 20, "[16] single sale settles")
    var expected_all: int = 2 * ItemsScript.META_ITEMS["essence"]["sellPrice"] + ItemsScript.META_ITEMS["soulCrystal"]["sellPrice"]
    runner.check(game.sell_all_storage() == expected_all, "[16] sell all amount")
    runner.check(game.save["storage"]["essence"] == 0 and game.save["storage"]["soulCrystal"] == 0, "[16] sell all clears storage")
    runner.check(game.save["darkCrystals"] == before + 20 + expected_all, "[16] sell all settles")
    runner.check(game.sell_storage_item("shard") == 0 and game.sell_all_storage() == 0, "[16] empty storage returns zero")
    runner.check(MetaSave.load_save()["darkCrystals"] == game.save["darkCrystals"], "[16] sale persists")

    runner.harness.key_down("Escape"); runner.harness.key_up("Escape"); runner.harness.pump(1)
    game.save["metaLevels"]["damage"] = 3
    game.save["metaLevels"]["maxHp"] = 2
    game.save["metaLevels"]["magnet"] = 1
    MetaSave.persist_save(game.save)
    runner.harness.key_down("Enter"); runner.harness.key_up("Enter"); runner.harness.pump(1)
    runner.check(game.state == "opening", "[16] enter opening")
    runner.check(game.metaStacks["damage"] == 3 and game.metaStacks["maxHp"] == 2 and game.metaStacks["magnet"] == 1, "[16] meta stacks inherit save")
    runner.check(is_equal_approx(game.mods["damageMult"], 1.45), "[16] damage meta level applies")
    runner.check(is_equal_approx(game.mods["magnetRadiusBonus"], 50.0), "[16] magnet meta level applies")
    runner.check(game.player.maxHp == Config.CONFIG["player"]["maxHp"] + 40 and game.player.hp == game.player.maxHp, "[16] max hp meta applies and heals")
    runner.harness.pump_with_choices(3)
    runner.check(game.state == "playing" and game.metaStacks["damage"] == 3, "[16] meta stacks remain in combat")
