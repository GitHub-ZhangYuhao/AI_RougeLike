extends RefCounted

func title() -> String:
    return "[3] 站桩 60 秒定时波"

func run(runner) -> void:
    # 固定种子保证 60 秒刷怪、卡池洗牌与宝石散射可复现。
    Rng.set_seed(3003)
    var game = runner.harness.ensure_game()
    runner.harness.pump_with_choices(3600)
    runner.check(game.kills > 0, "[3] 没有产生击杀")
    runner.check(game.level >= 2, "[3] 玩家应该至少升到 2 级")
    runner.check(game.state == "playing", "[3] 应处于战斗状态，实际 %s" % game.state)
    runner.check(game.weapons.size() <= Config.CONFIG["cards"]["maxWeaponSlots"], "[3] 武器数量超过槽位上限")
    runner.check(game.waveDirector.wave == 1 and game.waveDirector.timeRemaining < 31.0, "[3] 90 秒定时波不应在 60 秒时提前推进")
    Rng.clear_source()
