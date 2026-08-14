extends RefCounted

func title() -> String:
    return "[2] 移动"

func run(runner) -> void:
    var game = runner.harness.ensure_game()
    var start_x: float = game.player.x
    runner.harness.key_down("KeyD")
    runner.harness.pump(60)
    runner.harness.key_up("KeyD")
    runner.check(game.player.x - start_x > 100.0, "[2] 玩家移动异常")
    game.player.maxHp = 100000.0
    game.player.hp = 100000.0
