extends RefCounted

const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const CardsScript: GDScript = preload("res://logic/cards.gd")
const EnemyScript: GDScript = preload("res://logic/enemy.gd")
const ProjectileScript: GDScript = preload("res://logic/projectile.gd")
const StatusScript: GDScript = preload("res://logic/systems/status.gd")


func title() -> String:
    return "[6] Weapon mechanic changes"


func run(runner) -> void:
    var talisman = WeaponFactoryScript.create_weapon("talisman")
    var talisman_world: Dictionary = _base_world()
    talisman.update(1.0 / 60.0, talisman_world)
    runner.check(talisman_world.projectiles.size() == 1, "[6] talisman must fire exactly one projectile")
    talisman.level = 2
    var thunder: Dictionary = {"hits": 0}
    var target_a = _enemy(0.0, 0.0)
    var target_b = _enemy(10.0, 0.0)
    talisman.world = _base_world()
    talisman.world.enemies = [target_a, target_b]
    talisman.world.damage_enemy = func(_enemy_value, _damage, _options = {}) -> void: thunder["hits"] += 1
    var hit_projectile = ProjectileScript.new(0.0, 0.0, 0.0, {"damage": 10.0})
    hit_projectile.attackSeq = 1
    talisman._on_projectile_hit(target_a, hit_projectile)
    talisman._on_projectile_hit(target_b, hit_projectile)
    runner.check(thunder["hits"] == 0, "[6] thunder counters leaked between targets")
    talisman._on_projectile_hit(target_a, hit_projectile)
    runner.check(thunder["hits"] == 1, "[6] second hit on same target must trigger thunder")

    var sword = WeaponFactoryScript.create_weapon("sword")
    var sword_world: Dictionary = _base_world()
    for weapon_level in range(2, 7):
        sword.level = weapon_level
        sword.timer = 0.0
        for projectile in sword_world.projectiles:
            projectile.onHit = Callable()
        sword_world.projectiles.clear()
        sword.update(1.0 / 60.0, sword_world)
        runner.check(sword_world.projectiles.size() == 1 and sword_world.projectiles[0].maxHits == INF,
            "[6] sword Lv%d must pierce infinitely" % weapon_level)

    var game = runner.harness.ensure_game()
    var saved_enemies: Array = game.enemies
    var saved_projectiles: Array = game.projectiles
    var collision_enemies: Array = [_enemy(5000.0, 0.0), _enemy(5000.0, 1.0), _enemy(5000.0, 2.0)]
    var finite = ProjectileScript.new(5000.0, 0.0, 0.0, {"radius": 20.0, "damage": 10.0, "maxHits": 2.0})
    game.enemies = collision_enemies
    game.projectiles = [finite]
    game._handle_collisions()
    var finite_hits: int = collision_enemies.filter(func(enemy) -> bool: return is_equal_approx(enemy.hp, 90.0)).size()
    runner.check(finite.dead and finite_hits == 2 and finite.maxHits == 2.0, "[6] finite projectile hit limit failed")
    var infinite = ProjectileScript.new(5000.0, 0.0, 0.0, {"radius": 20.0, "damage": 10.0, "maxHits": INF})
    for enemy in collision_enemies:
        enemy.hp = 100.0
        enemy.dead = false
    game.projectiles = [infinite]
    game._handle_collisions()
    runner.check(not infinite.dead and collision_enemies.all(func(enemy) -> bool: return is_equal_approx(enemy.hp, 90.0)),
        "[6] infinite projectile piercing failed")
    game.enemies = saved_enemies
    game.projectiles = saved_projectiles

    var ring_sword = WeaponFactoryScript.create_weapon("sword")
    ring_sword.level = 4
    var ring_world: Dictionary = _base_world()
    ring_world.enemies[0].x = 20.0
    var bleed: Dictionary = {"count": 0}
    ring_world.apply_dot = func(_enemy_value, type: String, _dps: float, _duration: float) -> void:
        if type == "bleed": bleed["count"] += 1
    for ignored in 3:
        ring_sword.update(2.0, ring_world)
        ring_world.projectiles.back().onHit.call(ring_world.enemies[0])
    ring_sword.update(2.0, ring_world)
    runner.check(ring_sword.rings.size() == 1 and bleed["count"] == 1,
        "[6] every third HIT sword attack must add draw slash and bleed")
    var whiff_sword = WeaponFactoryScript.create_weapon("sword")
    whiff_sword.level = 4
    var whiff_world: Dictionary = _base_world()
    whiff_world.enemies = []
    for ignored in 6:
        whiff_sword.update(2.0, whiff_world)
    runner.check(whiff_sword.rings.is_empty() and whiff_sword.attack_count == 0,
        "[6] draw slash must not charge on whiffed attacks")

    var fly_sword = WeaponFactoryScript.create_weapon("sword")
    fly_sword.level = 6
    var fly_world: Dictionary = _base_world()
    fly_world.enemies = [_enemy(100.0, 0.0, 1000.0), _enemy(220.0, 0.0, 1000.0), _enemy(340.0, 0.0, 1000.0)]
    fly_world.damage_enemy = func(enemy, damage: float, _options = {}) -> void: enemy.hp -= damage
    fly_sword._spawn_flying_sword(fly_world)
    var peak_chains: int = 0
    for ignored in 180:
        fly_sword.update(1.0 / 60.0, fly_world)
        if not fly_sword.flying_swords.is_empty():
            peak_chains = maxi(peak_chains, fly_sword.flying_swords[0]["chains"])
    runner.check(fly_world.enemies.all(func(enemy) -> bool: return enemy.hp < 1000.0),
        "[6] flying sword must pierce every shuttled enemy")
    runner.check(peak_chains >= 3, "[6] flying sword must chain-shuttle between multiple enemies")

    var cloak = WeaponFactoryScript.create_weapon("cloak")
    cloak.level = 6
    var cloak_world: Dictionary = _base_world()
    cloak.update(0.1, cloak_world)
    cloak_world.kills = 100
    cloak.update(0.1, cloak_world)
    runner.check(cloak.shocks.any(func(shock: Dictionary) -> bool: return shock["enhanced"]),
        "[6] cloak 100-kill enhanced shock missing")
    runner.check(cloak.shock_timer > 2.7, "[6] enhanced shock incorrectly reset normal cooldown")

    var burn_enemy = _enemy(0.0, 0.0, 1.0)
    StatusScript.apply_dot(burn_enemy, "burn", 1.0, 2.0)
    game.damage_enemy(burn_enemy, 2.0)
    runner.check(game.killLog.back()["burned"] and not game.killLog.back()["blazed"],
        "[6] cloak burn incorrectly counts as trail blaze")
    var blaze_enemy = _enemy(0.0, 0.0, 1.0)
    StatusScript.apply_dot(blaze_enemy, "blaze", 1.0, 2.0)
    game.damage_enemy(blaze_enemy, 2.0)
    runner.check(game.killLog.back()["blazed"], "[6] trail blaze was not recorded")

    var trail = WeaponFactoryScript.create_weapon("trail")
    var curve: Array = trail.card["levels"].map(func(level_stats: Dictionary): return level_stats["damage"])
    runner.check(curve == [7, 10, 14, 16, 21, 26], "[6] trail damage nerf curve changed unexpectedly")
    trail.level = 6
    var trail_world: Dictionary = _base_world()
    trail_world.player.x = 60.0
    trail_world.player.y = 60.0
    trail_world.enemies = [_enemy(60.0, 60.0, 10000.0)]
    var hot_result: Dictionary = {"heals": 0.0, "speed": 1.0}
    trail_world.heal_player = func(amount: float) -> void: hot_result["heals"] += amount
    trail_world.set_player_move_speed_bonus = func(_source, multiplier: float, _duration: float = 0.12) -> void: hot_result["speed"] = multiplier
    var raw_points: Array = [[0.0, 0.0, 0.0], [120.0, 0.0, 0.35], [120.0, 120.0, 0.7], [0.0, 120.0, 1.05], [5.0, 5.0, 1.3]]
    for point: Array in raw_points:
        trail.path_points.append({"x": point[0], "y": point[1], "at": point[2], "trail": {"dead": false}})
    trail_world.elapsed = 1.3
    trail._try_create_furnace(trail_world, trail.stats)
    runner.check(trail.furnaces.size() == 1 and trail.loop_cooldown > 0.0, "[6] trail valid loop did not create furnace")
    var furnace: Dictionary = trail.furnaces[0]
    furnace["fuel"] = 9.0
    trail._try_open(furnace, trail_world, trail.stats)
    runner.check(furnace["opens"] == 1 and trail.hot_zones.size() == 1,
        "[6] trail furnace opening or Ninefold hot zone missing")
    trail._update_hot_zones(0.5, trail_world, trail.stats)
    runner.check(hot_result["heals"] == 1.0 and is_equal_approx(hot_result["speed"], 1.12),
        "[6] trail hot-zone healing or movement bonus missing")

    var staff = WeaponFactoryScript.create_weapon("staff")
    staff.level = 6
    var staff_world: Dictionary = _base_world()
    for i in 10:
        staff_world.kill_log.append({"id": i + 1, "x": 0.0, "y": 0.0, "noSummon": true})
    var constant := ConstantSource.new()
    Rng.set_source(Callable(constant, "next_value"))
    staff.update(0.0, staff_world)
    runner.check(staff.corpses.is_empty(), "[6] noSummon kills created corpse minions")
    for i in 60:
        staff_world.kill_log.append({"id": i + 11, "x": 0.0, "y": 0.0, "noSummon": false})
    staff.update(0.0, staff_world)
    Rng.clear_source()
    runner.check(staff.corpses.size() == 5, "[6] corpse minion cap must be 5")
    var blast_world: Dictionary = _base_world()
    blast_world.enemies = [_enemy(0.0, 0.0)]
    var blast_options: Dictionary = {}
    blast_world.damage_enemy = func(_enemy_value, _damage: float, options: Dictionary = {}) -> void: blast_options.merge(options, true)
    staff.detonate({"x": 0.0, "y": 0.0, "damage": 10.0}, staff.stats, blast_world)
    runner.check(blast_options.get("noSummon", false), "[6] staff explosion damage must carry noSummon")
    _release_refs(
        [talisman, sword, ring_sword, whiff_sword, fly_sword, cloak, trail, staff],
        [talisman_world, talisman.world, sword_world, ring_world, whiff_world, fly_world, cloak_world,
            trail_world, staff_world, blast_world]
    )


func _release_refs(weapons: Array, worlds: Array) -> void:
    for current_world in worlds:
        if current_world == null:
            continue
        for projectile in current_world.get("projectiles", []):
            projectile.onHit = Callable()
        current_world.get("projectiles", []).clear()
    for weapon in weapons:
        weapon.world = null


func _base_world() -> Dictionary:
    return {
        "player": {"x": 0.0, "y": 0.0, "radius": 12.0, "facing": 0.0, "moving": false, "lastHurtAt": -1.0},
        "enemies": [_enemy(120.0, 0.0, 1000.0)], "projectiles": [], "trails": [], "summons": [], "effects": [],
        "killLog": [], "kill_log": [], "mods": CardsScript.compute_mods({}, {}), "elapsed": 0.0, "kills": 0,
        "damage_enemy": func(_enemy_value, _damage: float, _options = {}) -> void: pass,
        "heal_player": func(_amount: float) -> void: pass,
        "drop_pickup": func(_type: String, _x: float, _y: float, _amount: int = 1) -> void: pass,
        "apply_dot": func(_enemy_value, _type: String, _dps: float, _duration: float) -> void: pass,
        "apply_slow": func(_enemy_value, _factor: float, _duration: float) -> void: pass,
        "apply_freeze": func(_enemy_value, _duration: float) -> void: pass,
        "set_player_move_speed_bonus": func(_source, _multiplier: float, _duration: float = 0.12) -> void: pass,
    }


func _enemy(x: float, y: float, hp: float = 100.0):
    var enemy = EnemyScript.create_chaser(x, y)
    enemy.hp = hp
    enemy.maxHp = hp
    enemy.radius = 10.0
    enemy.dead = false
    return enemy


class ConstantSource extends RefCounted:
    func next_value() -> float:
        return 1.0
