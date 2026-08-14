extends RefCounted
func title() -> String: return "[13] Continue deeper"
func run(runner) -> void:
    MetaSave.reset_save()
    var run = runner.harness.fresh_playing_game(); run.waveDirector.start_wave(5, run); run.bossesDefeated = 1
    Rng.set_source(func(): return 0.0); run.on_boss_wave_cleared(); Rng.clear_source()
    runner.check(run.tempBackpack["shard"] == 1, "[13] boss material retained")
    run.continue_deeper()
    runner.check(run.state == "playing" and run.waveDirector.phase == "rest" and run.tempBackpack["shard"] == 1, "[13] continue keeps backpack")
