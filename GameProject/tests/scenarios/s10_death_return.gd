extends RefCounted
func title() -> String: return "[10] Death and return"
func run(runner) -> void:
    var run = runner.harness.fresh_playing_game()
    run.player.hp = 1; run.player.iFrames = 0; run.hurt_player(999); run._handle_collisions()
    runner.check(run.state == "dead", "[10] death settles at collision end")
    run.input.key_down("KeyR"); run.step(1.0 / 60.0); run.input.end_frame()
    runner.check(run.state == "menu" and run.weapons.is_empty() and run.level == 1 and run.kills == 0, "[10] R resets run")
