extends RefCounted
func title() -> String: return "[17] Final wave settlement"
func run(runner) -> void:
    MetaSave.reset_save()
    var run = runner.harness.fresh_playing_game(); runner.check(run.waveDirector.start_wave(26, run) == 25, "[17] wave cap")
    run.tempBackpack = {"shard": 2, "essence": 1, "soulCrystal": 0}; run.bossesDefeated = 5
    Rng.set_source(func(): return 0.99); run.on_boss_wave_cleared(); Rng.clear_source()
    runner.check(run.state == "summary" and run.lastRunSummary["completed"] and run.lastRunSummary["darkCrystalsGained"] == 38, "[17] final reward")
    var crystals: int = run.save["darkCrystals"]; var completions: int = run.save["stats"]["completions"]
    run.on_final_wave_cleared()
    runner.check(run.save["darkCrystals"] == crystals and run.save["stats"]["completions"] == completions, "[17] final settlement idempotent")
