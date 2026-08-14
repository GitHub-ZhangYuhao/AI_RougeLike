extends RefCounted
## ← js/enemies/index.js: seven concrete enemy classes and weighted selection.

const EnemyScript: GDScript = preload("res://logic/enemy.gd")
const EnhancedChaserScript: GDScript = preload("res://logic/enemies/enhanced_chaser.gd")
const ChargerScript: GDScript = preload("res://logic/enemies/charger.gd")
const RangedScript: GDScript = preload("res://logic/enemies/ranged.gd")
const BomberScript: GDScript = preload("res://logic/enemies/bomber.gd")
const ShieldScript: GDScript = preload("res://logic/enemies/shield.gd")
const BossScript: GDScript = preload("res://logic/enemies/boss.gd")

static func enhanced_chaser_ratio(wave: int) -> float:
    if wave < 8: return 0.0
    if wave == 8: return 0.15
    if wave == 9: return 0.35
    if wave == 10: return 0.65
    return 1.0

static func choose_enemy_type(elapsed: float = 0.0, enemies: Array = [], options: Dictionary = {}) -> String:
    var wave: int = maxi(1, floori(options.get("wave", 1)))
    var spawned_by_type: Dictionary = options.get("spawnedByType", {})
    var quota: float = options.get("quota", INF)
    var boss_wave: bool = options.get("bossWave", false)
    var alive_by_type: Dictionary = {}
    for enemy in enemies:
        if not enemy.dead:
            alive_by_type[enemy.type] = alive_by_type.get(enemy.type, 0) + 1
    var ranged_cap: float = maxf(1.0, floor(quota * 0.12)) if is_finite(quota) else INF
    var choices: Array[Dictionary] = []
    var total: float = 0.0
    for type: String in Config.CONFIG["enemyTypes"]:
        if type == "boss" or type == "enhancedChaser":
            continue
        var config: Dictionary = Config.CONFIG["enemyTypes"][type]
        var candidates: Array[Dictionary] = [{"type": type, "config": config, "weight": config["weight"]}]
        if type == "chaser":
            var ratio: float = enhanced_chaser_ratio(wave)
            candidates = [{"type": "chaser", "config": config, "weight": config["weight"] * (1.0 - ratio)},
                {"type": "enhancedChaser", "config": Config.CONFIG["enemyTypes"]["enhancedChaser"], "weight": config["weight"] * ratio}]
        for candidate: Dictionary in candidates:
            var candidate_type: String = candidate["type"]
            var candidate_config: Dictionary = candidate["config"]
            var weight: float = candidate["weight"]
            if weight <= 0.0 or elapsed < candidate_config["unlockAt"] or alive_by_type.get(candidate_type, 0) >= candidate_config["maxAlive"]:
                continue
            if candidate_type == "ranged" and (boss_wave or spawned_by_type.get("ranged", 0) >= ranged_cap):
                continue
            total += weight
            choices.append({"type": candidate_type, "limit": total})
    if choices.is_empty():
        return "enhancedChaser" if wave >= 11 else "chaser"
    var roll: float = Rng.next() * total
    for choice: Dictionary in choices:
        if roll < choice["limit"]:
            return choice["type"]
    return choices[-1]["type"]

static func create_enemy_by_type(type: String, x: float, y: float, elapsed: float = 0.0, wave: int = 1):
    var normalized_wave: int = maxi(1, wave)
    var actual_type: String = type if Config.CONFIG["enemyTypes"].has(type) else ("enhancedChaser" if normalized_wave >= 11 else "chaser")
    var enemy
    match actual_type:
        "enhancedChaser": enemy = EnhancedChaserScript.new(x, y, elapsed)
        "charger": enemy = ChargerScript.new(x, y, elapsed)
        "ranged": enemy = RangedScript.new(x, y, elapsed)
        "bomber": enemy = BomberScript.new(x, y, elapsed)
        "shield": enemy = ShieldScript.new(x, y, elapsed)
        "boss": enemy = BossScript.new(x, y, elapsed)
        _: enemy = EnemyScript.create_chaser(x, y, elapsed)
    return enemy.apply_wave_scaling(normalized_wave)
