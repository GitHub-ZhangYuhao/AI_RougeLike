extends RefCounted
## ← js/spawner.js：刷怪节奏、上限与屏外矩形边缘出生。

const EnemyFactoryScript: GDScript = preload("res://logic/enemies/enemy_factory.gd")

var timer: float = 0.0


func update(dt: float, elapsed: float, enemies: Array, camera, view_w: float, view_h: float, options: Dictionary = {}) -> int:
    var spawn_limit: float = options.get("spawnLimit", INF)
    if spawn_limit <= 0.0:
        return 0
    var wave: int = maxi(1, floori(options.get("wave", 1)))
    var settings: Dictionary = options.get("spawnSettings", {})
    if settings.get("paused", false):
        return 0
    var requested: float = options.get("spawnInterval", Config.CONFIG["spawner"]["startInterval"] - (wave - 1) * Config.CONFIG["spawner"]["intervalPerWave"])
    var interval_mult: float = maxf(0.01, settings.get("intervalMult", options.get("intervalMult", 1.0)))
    var interval: float = maxf(Config.CONFIG["spawner"]["minInterval"], requested) * interval_mult
    var default_max_alive: int = mini(Config.CONFIG["spawner"]["maxAliveCap"], Config.CONFIG["spawner"]["startMaxAlive"] + (wave - 1) * Config.CONFIG["spawner"]["maxAlivePerWave"])
    var max_alive: int = options.get("aliveCap", default_max_alive)
    timer -= dt
    var spawned: int = 0
    while timer <= 0.0 and spawned < spawn_limit:
        var alive: int = 0
        for enemy in enemies:
            if not enemy.dead:
                alive += 1
        if alive >= max_alive:
            timer = 0.0
            break
        timer += interval
        var type: String = options.get("forceType", EnemyFactoryScript.choose_enemy_type(elapsed, enemies, options))
        spawn_type(type, elapsed, enemies, camera, view_w, view_h, options)
        spawned += 1
    return spawned


func spawn_type(type: String, elapsed: float, enemies: Array, camera, view_w: float, view_h: float, options: Dictionary = {}):
    var position: Dictionary = _ring_position(camera, view_w, view_h)
    var enemy = EnemyFactoryScript.create_enemy_by_type(type, position["x"], position["y"], elapsed, options.get("wave", 1))
    enemies.append(enemy)
    var counts: Dictionary = options.get("spawnedByType", {})
    counts[enemy.type] = counts.get(enemy.type, 0) + 1
    return enemy


func _ring_position(camera, view_w: float, view_h: float) -> Dictionary:
    var half_w: float = view_w / 2.0 + Config.CONFIG["spawner"]["spawnMargin"]
    var half_h: float = view_h / 2.0 + Config.CONFIG["spawner"]["spawnMargin"]
    var side: int = floori(Rng.next() * 4.0)
    var t: float = -1.0 + Rng.next() * 2.0
    match side:
        0: return {"x": camera.x + t * half_w, "y": camera.y - half_h}
        1: return {"x": camera.x + t * half_w, "y": camera.y + half_h}
        2: return {"x": camera.x - half_w, "y": camera.y + t * half_h}
        _: return {"x": camera.x + half_w, "y": camera.y + t * half_h}
