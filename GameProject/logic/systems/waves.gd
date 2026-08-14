extends RefCounted
## ← js/systems/waves.js

var wave: int = 1
var phase: String = "wave"
var waveTimer: float = 90.0
var spawned: int = 0
var baseQuota: int = 16
var quota: int = 16
var restTimer: float = 0.0
var bannerTimer: float = 2.4
var spawnedByType: Dictionary = {}
var eliteSpawned: bool = false
var bossSpawned: bool = false
var isBossWave: bool:
    get: return wave % Config.CONFIG["waves"]["bossEvery"] == 0
var timeRemaining: float:
    get: return maxf(0.0, waveTimer)
var remaining: int:
    get: return maxi(0, quota - spawned)
var spawnInterval: float:
    get: return Config.CONFIG["waves"]["duration"] / maxi(1, quota - (1 if isBossWave else 0))

func update(dt: float, game, camera, view_w: float, view_h: float) -> void:
    bannerTimer -= dt
    if phase == "rest":
        restTimer -= dt
        if restTimer <= 0.0:
            _start_next_wave(game)
        return
    if phase == "overtime":
        if not _boss_alive(game):
            game.on_boss_wave_cleared()
        return
    waveTimer = maxf(0.0, waveTimer - dt)
    if isBossWave:
        _update_boss_wave(dt, game, camera, view_w, view_h)
    else:
        _update_normal_wave(dt, game, camera, view_w, view_h)

func _update_normal_wave(dt: float, game, camera, view_w: float, view_h: float) -> void:
    if wave % Config.CONFIG["waves"]["eliteEvery"] == 0 and not eliteSpawned and remaining > 0:
        var elite = game.spawner.spawn_type("shield", game.elapsed, game.enemies, camera, view_w, view_h,
            {"wave": wave, "spawnedByType": spawnedByType})
        if elite != null:
            eliteSpawned = true
            spawned += 1
            game.spawner.timer = spawnInterval
    if remaining > 0:
        var options: Dictionary = _debug_spawn_options(game, {"spawnLimit": remaining, "spawnInterval": spawnInterval,
            "wave": wave, "quota": quota, "spawnedByType": spawnedByType, "bossWave": false})
        spawned += game.spawner.update(dt, game.elapsed, game.enemies, camera, view_w, view_h, options)
    if waveTimer <= 0.0:
        _start_next_wave(game)

func _update_boss_wave(dt: float, game, camera, view_w: float, view_h: float) -> void:
    if not bossSpawned and remaining > 0:
        var boss = game.spawner.spawn_type("boss", game.elapsed, game.enemies, camera, view_w, view_h,
            {"wave": wave, "spawnedByType": spawnedByType})
        if boss != null:
            bossSpawned = true
            spawned = 1
            game.spawner.timer = spawnInterval
    if remaining > 0:
        var options: Dictionary = _debug_spawn_options(game, {"spawnLimit": remaining, "spawnInterval": spawnInterval,
            "wave": wave, "quota": quota, "spawnedByType": spawnedByType, "bossWave": true, "forceType": "enhancedChaser"})
        spawned += game.spawner.update(dt, game.elapsed, game.enemies, camera, view_w, view_h, options)
    if waveTimer > 0.0 or not bossSpawned:
        return
    if _boss_alive(game):
        phase = "overtime"
        bannerTimer = Config.CONFIG["waves"]["bannerDuration"]
    else:
        game.on_boss_wave_cleared()

func _debug_spawn_options(game, options: Dictionary) -> Dictionary:
    if game.debug == null:
        return options
    options["spawnSettings"] = game.debug.settings["spawn"]
    var alive_cap = game.debug.settings["spawn"]["aliveCap"]
    if alive_cap != null:
        options["aliveCap"] = alive_cap
    return options


func start_wave(requested_wave: int, game = null) -> int:
    wave = clampi(requested_wave, 1, Config.CONFIG["waves"]["maxWave"])
    phase = "wave"
    waveTimer = Config.CONFIG["waves"]["duration"]
    spawned = 0
    baseQuota = _quota_for(wave)
    quota = baseQuota
    restTimer = 0.0
    bannerTimer = Config.CONFIG["waves"]["bannerDuration"]
    eliteSpawned = false
    bossSpawned = false
    spawnedByType = {}
    if game != null:
        game.spawner.timer = 0.0
    return wave

func quantity_multiplier_for(requested_wave: int) -> float:
    var normalized: int = clampi(maxi(1, requested_wave), 1, Config.CONFIG["waves"]["maxWave"])
    if normalized % Config.CONFIG["waves"]["bossEvery"] == 0:
        return (1.0 + _boss_reinforcements_for(normalized)) / Config.CONFIG["waves"]["baseQuota"]
    return minf(Config.CONFIG["waves"]["quantityWaveCap"], 1.0 + (normalized - 1) * Config.CONFIG["waves"]["quantityPerWave"])

func _quota_for(requested_wave: int) -> int:
    return roundi(Config.CONFIG["waves"]["baseQuota"] * quantity_multiplier_for(requested_wave))

func _boss_reinforcements_for(requested_wave: int) -> int:
    if requested_wave == 5: return 4
    if requested_wave == 10: return 6
    return mini(12, 6 + floori((requested_wave - 10) / 5.0) * 2)

func begin_rest() -> void:
    phase = "rest"
    restTimer = Config.CONFIG["waves"]["restDuration"]
    bannerTimer = Config.CONFIG["waves"]["bannerDuration"]

func _start_next_wave(game) -> void:
    if wave >= Config.CONFIG["waves"]["maxWave"]:
        game.on_final_wave_cleared()
    else:
        start_wave(wave + 1, game)

func _boss_alive(game) -> bool:
    for enemy in game.enemies:
        if not enemy.dead and enemy.rank == "boss":
            return true
    return false
