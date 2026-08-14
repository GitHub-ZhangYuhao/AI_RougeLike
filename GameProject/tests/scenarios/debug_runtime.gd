extends RefCounted

const EnemyFactoryScript: GDScript = preload("res://logic/enemies/enemy_factory.gd")
const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")

func title() -> String: return "[Debug] Debug Runtime"

func run(runner) -> void:
    var game = runner.harness.game
    var debug = game.debug
    runner.check(debug != null and debug.has_method("set_player_settings"), "[Debug] game.debug missing")
    runner.check(debug.settings["player"]["damageMult"] == 1.0 and debug.settings["enemy"]["hpMult"] == 1.0, "[Debug] default multipliers neutral")
    var base_damage: float = game.mods["damageMult"]
    var base_xp: float = game.mods["xpMult"]
    var base_move: float = game.mods["moveSpeedMult"]
    var base_pickup: float = game.gem_magnet_radius()
    var natural_max_hp: float = game.player.maxHp
    game.player.hp = natural_max_hp * 0.4
    debug.set_player_settings({"damageMult": 2.0, "xpMult": 3.0, "moveSpeedMult": 1.5, "armorBonus": 50.0, "pickupRangeMult": 2.5, "maxHpMult": 2.0})
    runner.check(is_equal_approx(game.mods["damageMult"], base_damage * 2.0), "[Debug] player damage multiplier")
    runner.check(is_equal_approx(game.mods["xpMult"], base_xp * 3.0), "[Debug] player xp multiplier")
    runner.check(is_equal_approx(game.mods["moveSpeedMult"], base_move * 1.5), "[Debug] player move multiplier")
    runner.check(is_equal_approx(game.gem_magnet_radius(), base_pickup * 2.5), "[Debug] pickup multiplier")
    runner.check(is_equal_approx(game.player.maxHp, natural_max_hp * 2.0) and is_equal_approx(game.player.hp / game.player.maxHp, 0.4), "[Debug] max hp ratio")
    debug.set_player_hp(game.player.maxHp * 10.0)
    runner.check(game.player.hp == game.player.maxHp, "[Debug] hp upper clamp")
    debug.set_invincible(true)
    var hp_before: float = game.player.hp
    runner.check(not game.hurt_player(25.0) and game.player.hp == hp_before, "[Debug] invincible")
    debug.set_invincible(false)
    var natural_levels: Dictionary = _weapon_snapshot(game)
    for i in WeaponFactoryScript.WEAPON_CARDS.size():
        debug.set_weapon_level(WeaponFactoryScript.WEAPON_CARDS[i]["id"], i + 1)
    runner.check(game.weapons.size() == WeaponFactoryScript.WEAPON_CARDS.size(), "[Debug] weapon slot bypass")
    debug.set_weapon_level("sword", 0)
    runner.check(game.get_weapon("sword") == null, "[Debug] weapon removal")
    debug.reset_defaults()
    runner.check(_weapon_snapshot(game) == natural_levels, "[Debug] weapon baseline restore")
    for card: Dictionary in WeaponFactoryScript.WEAPON_CARDS:
        debug.set_weapon_level(card["id"], 4)
    game.reset()
    runner.check(game.weapons.size() == 6 and game.weapons.all(func(weapon) -> bool: return weapon.level == 4), "[Debug] weapon overrides survive reset")
    debug.clear_enemies()
    var enemy = EnemyFactoryScript.create_enemy_by_type("chaser", 0.0, 0.0, game.elapsed, game.waveDirector.wave)
    var enemy_base: Dictionary = {"hp": enemy.maxHp, "damage": enemy.damage, "speed": enemy.speed}
    enemy.hp *= 0.4
    game.enemies.append(enemy)
    debug.set_enemy_multipliers({"hpMult": 2.0, "damageMult": 3.0, "speedMult": 4.0})
    runner.check(is_equal_approx(enemy.maxHp, enemy_base["hp"] * 2.0) and is_equal_approx(enemy.hp / enemy.maxHp, 0.4), "[Debug] enemy hp multiplier")
    runner.check(is_equal_approx(enemy.damage, enemy_base["damage"] * 3.0) and is_equal_approx(enemy.speed, enemy_base["speed"] * 4.0), "[Debug] enemy damage speed multipliers")
    var unchanged: Array = [enemy.maxHp, enemy.hp, enemy.damage, enemy.speed]
    debug.set_enemy_multipliers({"hpMult": 2.0, "damageMult": 3.0, "speedMult": 4.0})
    runner.check([enemy.maxHp, enemy.hp, enemy.damage, enemy.speed] == unchanged, "[Debug] enemy multipliers idempotent")
    Rng.set_source(func(): return 0.5)
    var spawned: Array = debug.spawn_enemies("chaser", 3)
    Rng.clear_source()
    runner.check(spawned.size() == 3 and game.enemies.size() == 4, "[Debug] manual spawn")
    runner.check(is_equal_approx(spawned[0].maxHp, enemy_base["hp"] * 2.0), "[Debug] new enemy multiplier")
    debug.set_wave(4)
    var base_quota: int = game.waveDirector.baseQuota
    debug.set_spawn_settings({"quotaMult": 1.5, "aliveCap": 2, "intervalMult": 0.5, "paused": true})
    runner.check(game.waveDirector.quota == roundi(base_quota * 1.5), "[Debug] quota multiplier")
    game.spawner.timer = 0.0
    runner.check(game.spawner.update(1.0, game.elapsed, game.enemies, game.camera, 1280.0, 720.0, {"spawnLimit": 1, "wave": 4, "spawnSettings": debug.settings["spawn"]}) == 0, "[Debug] spawn pause")
    debug.set_invincible(true)
    debug.set_player_settings({"damageMult": 2.25, "xpMult": 1.75})
    debug.set_spawn_settings({"quotaMult": 2.0, "aliveCap": 9, "intervalMult": 0.75, "paused": true})
    debug.set_wave(8)
    var serialized: Dictionary = debug.serialize()
    debug.reset_defaults()
    var restored = debug.apply_serialized(JSON.stringify(serialized))
    runner.check(restored is Dictionary and restored["wave"] == 8, "[Debug] serialize wave round trip")
    runner.check(restored["settings"]["invincible"] and restored["settings"]["player"]["damageMult"] == 2.25, "[Debug] serialize settings round trip")
    runner.check(restored["weaponLevels"] == serialized["weaponLevels"], "[Debug] serialize weapons round trip")
    debug.reset_defaults()
    debug.clear_enemies()
    game.reset()
    game.state = "playing"
    runner.check(not debug.settings["invincible"] and debug.settings["player"]["damageMult"] == 1.0 and game.weapons.is_empty(), "[Debug] cleanup")


func _weapon_snapshot(game) -> Dictionary:
    var result: Dictionary = {}
    for weapon in game.weapons:
        result[weapon.card["id"]] = weapon.level
    return result
