extends RefCounted

const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")

const DEFAULT_SETTINGS: Dictionary = {
    "paused": false,
    "invincible": false,
    "player": {
        "damageMult": 1.0, "xpMult": 1.0, "moveSpeedMult": 1.0,
        "maxHpMult": 1.0, "pickupRangeMult": 1.0, "armorBonus": 0.0,
    },
    "enemy": {"hpMult": 1.0, "damageMult": 1.0, "speedMult": 1.0},
    "spawn": {"quotaMult": 1.0, "aliveCap": null, "intervalMult": 1.0, "paused": false},
}

var _game_ref: WeakRef
var game:
    get: return _game_ref.get_ref()
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var weapon_levels: Dictionary = {}
var weapon_baselines: Dictionary = {}
var applied_player_max_hp_mult: float = 1.0
var enemy_bases: Dictionary = {}


func _init(game_run) -> void:
    _game_ref = weakref(game_run)


func set_paused(value) -> bool:
    settings["paused"] = value == true
    return settings["paused"]


func set_invincible(value) -> bool:
    settings["invincible"] = value == true
    return settings["invincible"]


func set_player_hp(value) -> float:
    game.player.hp = clampf(_number(value, game.player.hp), 0.0, game.player.maxHp)
    return game.player.hp


func set_player_settings(partial: Dictionary = {}) -> Dictionary:
    var player_settings: Dictionary = settings["player"]
    player_settings["damageMult"] = _partial_number(partial, "damageMult", player_settings["damageMult"], 0.0, 1000.0)
    player_settings["xpMult"] = _partial_number(partial, "xpMult", player_settings["xpMult"], 0.0, 1000.0)
    player_settings["moveSpeedMult"] = _partial_number(partial, "moveSpeedMult", player_settings["moveSpeedMult"], 0.0, 100.0)
    player_settings["maxHpMult"] = _partial_number(partial, "maxHpMult", player_settings["maxHpMult"], 0.01, 1000.0)
    player_settings["pickupRangeMult"] = _partial_number(partial, "pickupRangeMult", player_settings["pickupRangeMult"], 0.0, 1000.0)
    player_settings["armorBonus"] = _partial_number(partial, "armorBonus", player_settings["armorBonus"], 0.0, 1000000.0)
    game.recompute_mods()
    return player_settings.duplicate(true)


func set_weapon_level(id: String, value) -> Variant:
    var card: Dictionary = WeaponFactoryScript.card_by_id(id)
    if card.is_empty():
        return false
    var requested: int = clampi(floori(_number(value, 0.0)), 0, card.get("maxLevel", 6))
    if not weapon_baselines.has(id):
        var current = game.get_weapon(id)
        weapon_baselines[id] = current.level if current != null else 0
    weapon_levels[id] = requested
    _apply_weapon_level(id, requested)
    return requested


func grant_xp(value) -> float:
    var granted: float = clampf(_number(value, 0.0), 0.0, 1000000000.0)
    if granted > 0.0:
        game.gain_xp(granted, false)
    return granted


func set_enemy_multipliers(partial: Dictionary = {}) -> Dictionary:
    var enemy_settings: Dictionary = settings["enemy"]
    enemy_settings["hpMult"] = _partial_number(partial, "hpMult", enemy_settings["hpMult"], 0.01, 1000.0)
    enemy_settings["damageMult"] = _partial_number(partial, "damageMult", enemy_settings["damageMult"], 0.0, 1000.0)
    enemy_settings["speedMult"] = _partial_number(partial, "speedMult", enemy_settings["speedMult"], 0.0, 1000.0)
    for enemy in game.enemies:
        apply_enemy_multipliers(enemy)
    return enemy_settings.duplicate(true)


func set_spawn_settings(partial: Dictionary = {}) -> Dictionary:
    var spawn_settings: Dictionary = settings["spawn"]
    spawn_settings["quotaMult"] = _partial_number(partial, "quotaMult", spawn_settings["quotaMult"], 0.0, 1000.0)
    spawn_settings["intervalMult"] = _partial_number(partial, "intervalMult", spawn_settings["intervalMult"], 0.01, 1000.0)
    if partial.has("aliveCap"):
        spawn_settings["aliveCap"] = null if partial["aliveCap"] == null else clampi(floori(_number(partial["aliveCap"], 0.0)), 0, 10000)
    if partial.has("paused"):
        spawn_settings["paused"] = partial["paused"] == true
    _apply_spawn_settings()
    return spawn_settings.duplicate(true)


func set_wave(value) -> int:
    var wave: int = clampi(floori(_number(value, 1.0)), 1, Config.CONFIG["waves"]["maxWave"])
    clear_enemies()
    game.waveDirector.start_wave(wave, game)
    _apply_spawn_settings()
    return game.waveDirector.wave


func next_wave() -> int:
    return set_wave(game.waveDirector.wave + 1)


func spawn_enemies(type: String, count: int = 1) -> Array:
    if not Config.CONFIG["enemyTypes"].has(type):
        return []
    var spawned: Array = []
    for i in clampi(count, 1, 200):
        var enemy = game.spawner.spawn_type(type, game.elapsed, game.enemies, game.camera, 1280.0, 720.0, {"wave": game.waveDirector.wave})
        if enemy != null:
            apply_enemy_multipliers(enemy)
            spawned.append(enemy)
    return spawned


func clear_enemies() -> int:
    var count: int = game.enemies.size()
    game.enemies.clear()
    game.hostileProjectiles.clear()
    enemy_bases.clear()
    return count


func reset_defaults() -> Dictionary:
    settings = DEFAULT_SETTINGS.duplicate(true)
    game.recompute_mods()
    for enemy in game.enemies:
        apply_enemy_multipliers(enemy)
    _apply_spawn_settings()
    for id: String in weapon_baselines:
        _apply_weapon_level(id, weapon_baselines[id])
    weapon_levels.clear()
    weapon_baselines.clear()
    return serialize()


func serialize() -> Dictionary:
    var levels: Dictionary = {}
    for weapon in game.weapons:
        levels[weapon.card["id"]] = weapon.level
    return {
        "version": 1,
        "settings": settings.duplicate(true),
        "weaponLevels": levels,
        "wave": game.waveDirector.wave,
    }


func apply_serialized(data) -> Variant:
    var parsed = JSON.parse_string(data) if data is String else data
    if not parsed is Dictionary:
        return false
    reset_defaults()
    var next_settings: Dictionary = parsed.get("settings", parsed)
    set_paused(next_settings.get("paused", false))
    set_invincible(next_settings.get("invincible", false))
    set_player_settings(next_settings.get("player", {}))
    set_enemy_multipliers(next_settings.get("enemy", {}))
    set_spawn_settings(next_settings.get("spawn", {}))
    var levels: Dictionary = parsed.get("weaponLevels", {})
    for id: String in levels:
        set_weapon_level(id, levels[id])
    if parsed.has("wave"):
        set_wave(parsed["wave"])
    return serialize()


func on_game_reset() -> void:
    applied_player_max_hp_mult = 1.0
    enemy_bases.clear()
    game.recompute_mods()
    _apply_spawn_settings()
    for id: String in weapon_levels:
        weapon_baselines[id] = 0
        _apply_weapon_level(id, weapon_levels[id])


func sync_player_max_hp() -> void:
    var previous: float = maxf(0.0001, game.player.maxHp)
    var ratio: float = maxf(0.0, game.player.hp) / previous
    var next: float = settings["player"]["maxHpMult"]
    var scale: float = next / maxf(0.0001, applied_player_max_hp_mult)
    game.player.maxHp = maxf(1.0, previous * scale)
    game.player.hp = minf(game.player.maxHp, game.player.maxHp * ratio)
    applied_player_max_hp_mult = next


func apply_enemy_multipliers(enemy):
    if enemy == null:
        return enemy
    var id: int = enemy.get_instance_id()
    if not enemy_bases.has(id):
        enemy_bases[id] = {
            "hpMult": 1.0, "damageMult": 1.0, "speedMult": 1.0,
            "unscaledDamage": enemy.damage, "unscaledSpeed": enemy.speed,
        }
    var applied: Dictionary = enemy_bases[id]
    var next: Dictionary = settings["enemy"]
    var hp_ratio: float = maxf(0.0, enemy.hp) / enemy.maxHp if enemy.maxHp > 0.0 else 1.0
    enemy.maxHp = maxf(0.0001, enemy.maxHp * next["hpMult"] / maxf(0.0001, applied["hpMult"]))
    enemy.hp = minf(enemy.maxHp, enemy.maxHp * hp_ratio)
    if applied["damageMult"] > 0.0:
        applied["unscaledDamage"] = enemy.damage / applied["damageMult"]
    if applied["speedMult"] > 0.0:
        applied["unscaledSpeed"] = enemy.speed / applied["speedMult"]
    enemy.damage = applied["unscaledDamage"] * next["damageMult"]
    enemy.speed = applied["unscaledSpeed"] * next["speedMult"]
    applied["hpMult"] = next["hpMult"]
    applied["damageMult"] = next["damageMult"]
    applied["speedMult"] = next["speedMult"]
    return enemy


func _apply_weapon_level(id: String, level: int) -> void:
    var existing = game.get_weapon(id)
    if level <= 0:
        game.weapons = game.weapons.filter(func(weapon) -> bool: return weapon.card["id"] != id)
        game.synergies.refresh(game.weapons, game.elapsed)
        return
    if existing == null:
        existing = WeaponFactoryScript.create_weapon(id)
        game.weapons.append(existing)
    existing.level = level
    var kept: bool = false
    game.weapons = game.weapons.filter(func(weapon) -> bool:
        if weapon.card["id"] != id:
            return true
        if not kept:
            kept = true
            return true
        return false
    )
    game.synergies.refresh(game.weapons, game.elapsed)


func _apply_spawn_settings() -> void:
    if game.waveDirector == null:
        return
    game.waveDirector.quota = roundi(game.waveDirector.baseQuota * settings["spawn"]["quotaMult"])


func _partial_number(partial: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
    if not partial.has(key):
        return fallback
    return clampf(_number(partial[key], fallback), minimum, maximum)


func _number(value, fallback: float) -> float:
    if value == null:
        return fallback
    var number: float = float(value)
    return number if is_finite(number) else fallback
