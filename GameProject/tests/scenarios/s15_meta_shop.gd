extends RefCounted

const ShopScript: GDScript = preload("res://logic/meta/shop.gd")

func title() -> String: return "[15] Meta shop"

func run(runner) -> void:
    var game = runner.harness.game
    var main_scene = load("res://scenes/main.tscn").instantiate()
    runner.check(main_scene.has_node("MetaLayer/MetaScreens"), "[15] formal meta UI mounted in main scene")
    main_scene.free()
    # The compact [14] port stops at dead; mirror the prototype's final R before [15].
    game.reset()
    runner.check(game.state == "menu", "[15] should start from menu")
    var curve: Array[int] = [20, 32, 51, 82, 131, 210, 336, 537, 859, 1374]
    for level in range(1, ShopScript.shop_max_level() + 1):
        runner.check(ShopScript.price_for_level(level) == curve[level - 1], "[15] price curve level %d" % level)
    runner.check(ShopScript.price_for_level(0) == 0, "[15] level below one costs zero")

    game.open_shop()
    runner.check(game.state == "shop", "[15] open shop")
    game.save["metaLevels"]["damage"] = 0
    game.save["metaLevels"]["armor"] = 0
    game.save["darkCrystals"] = 500
    runner.check(game.buy_shop_item("damage"), "[15] buy damage level one")
    runner.check(game.save["metaLevels"]["damage"] == 1 and game.save["darkCrystals"] == 480, "[15] level one deducts 20")
    runner.check(game.buy_shop_item("damage"), "[15] buy damage level two")
    runner.check(game.save["metaLevels"]["damage"] == 2 and game.save["darkCrystals"] == 448, "[15] level two deducts 32")
    runner.check(MetaSave.load_save()["metaLevels"]["damage"] == 2, "[15] purchase persists")

    game.save["darkCrystals"] = 10
    runner.check(not game.buy_shop_item("damage"), "[15] insufficient balance rejected")
    runner.check(game.save["metaLevels"]["damage"] == 2 and game.save["darkCrystals"] == 10, "[15] rejected purchase is atomic")
    game.save["metaLevels"]["armor"] = ShopScript.shop_max_level()
    game.save["darkCrystals"] = 99999
    runner.check(not game.buy_shop_item("armor") and game.save["darkCrystals"] == 99999, "[15] max level rejected without deduction")
    runner.check(not game.buy_shop_item("notExist"), "[15] unknown attribute rejected")

    runner.harness.key_down("Escape"); runner.harness.key_up("Escape"); runner.harness.pump(1)
    runner.check(game.state == "menu", "[15] escape returns menu")
    var balance: int = game.save["darkCrystals"]
    runner.check(not game.buy_shop_item("xp") and game.save["darkCrystals"] == balance, "[15] purchase outside shop rejected")
