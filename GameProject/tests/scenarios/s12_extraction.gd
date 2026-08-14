extends RefCounted
func title() -> String: return "[12] Extraction"
func run(runner) -> void:
    MetaSave.reset_save()
    var run = runner.harness.fresh_playing_game(); run.waveDirector.start_wave(5, run); run.bossesDefeated = 1
    Rng.set_source(func(): return 0.99); run.on_boss_wave_cleared(); Rng.clear_source()
    runner.check(run.state == "extraction" and run.enemies.is_empty() and run.hostileProjectiles.is_empty(), "[12] boss clear checkpoint cleanup")
    var before: int = run.save["darkCrystals"]; run.extract()
    runner.check(run.state == "summary" and run.save["darkCrystals"] == before + 8, "[12] extraction reward")
    runner.check(run.lastRunSummary.has_all(["completed", "wave", "kills", "level", "bossesDefeated", "elapsed", "darkCrystalsGained", "itemsBanked"]), "[12] complete summary fields")
