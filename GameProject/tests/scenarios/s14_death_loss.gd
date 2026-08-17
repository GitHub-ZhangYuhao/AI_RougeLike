extends RefCounted
func title() -> String: return "[14] Death loss"
func run(runner) -> void:
    var run = runner.harness.fresh_playing_game(); run.tempBackpack = {"shard": 2, "essence": 1, "soulCrystal": 1}
    run.waveDirector.start_wave(10, run)
    var storage: Dictionary = run.save["storage"].duplicate(true); var crystals: int = run.save["darkCrystals"]
    run.player.hp = 1; run.player.iFrames = 0; run.hurt_player(999); run._handle_collisions()
    runner.check(run.lastDeathLoss == {"shard": 2, "essence": 1, "soulCrystal": 1}, "[14] death loss snapshot")
    runner.check(run.tempBackpack == {"shard": 0, "essence": 0, "soulCrystal": 0}, "[14] death clears backpack")
    runner.check(run.lastDeathReward == 5 and run.save["darkCrystals"] == crystals + 5, "[14] death keeps 35 percent wave crystals")
    runner.check(run.save["storage"] == storage, "[14] death does not bank temporary materials")
