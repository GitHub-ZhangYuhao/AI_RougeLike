extends RefCounted

const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const CardsScript: GDScript = preload("res://logic/cards.gd")
const EnemyScript: GDScript = preload("res://logic/enemy.gd")
const ProjectileScript: GDScript = preload("res://logic/projectile.gd")
const StatusScript: GDScript = preload("res://logic/systems/status.gd")
const WorldArtViewScript: GDScript = preload("res://scenes/game/world_art_view.gd")


func title() -> String:
    return "[6] Weapon mechanic changes"


func run(runner) -> void:
    runner.check(WorldArtViewScript.DETAILED_IMPACT_BUDGET == 32
        and WorldArtViewScript.DAMAGE_NUMBER_BUDGET == 24
        and WorldArtViewScript.DETAILED_DOT_BUDGET == 48,
        "[6] world art performance budgets changed unexpectedly")
    var sampled_impacts: int = 0
    for impact_index in 220:
        if WorldArtViewScript.is_budget_sample(impact_index, 220, 32):
            sampled_impacts += 1
    runner.check(sampled_impacts == 32, "[6] impact budget sampling must select exactly 32 of 220")
    var all_small_batches_sampled: bool = true
    for impact_index in 12:
        all_small_batches_sampled = all_small_batches_sampled and WorldArtViewScript.is_budget_sample(impact_index, 12, 32)
    runner.check(all_small_batches_sampled, "[6] batches below the visual budget must remain fully detailed")
    var zero_budget_samples: int = 0
    for impact_index in 12:
        if WorldArtViewScript.is_budget_sample(impact_index, 12, 0):
            zero_budget_samples += 1
    runner.check(zero_budget_samples == 0, "[6] zero visual budget must select no effects")
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

    talisman.level = 6
    var chain_near = _enemy(160.0, 0.0)
    var chain_far = _enemy(161.0, 0.0)
    runner.check(talisman._nearest_chain_enemy({"x": 0.0, "y": 0.0}, [chain_near], {}) == chain_near,
        "[6] talisman chain must reach targets at 160px")
    runner.check(talisman._nearest_chain_enemy({"x": 0.0, "y": 0.0}, [chain_far], {}) == null,
        "[6] talisman chain exceeded 160px radius")
    var thunder_center = _enemy(0.0, 0.0)
    var thunder_edge = _enemy(90.0, 0.0)
    var thunder_outside = _enemy(91.0, 0.0)
    var thunder_hits: Array = []
    talisman_world = _base_world()
    talisman_world.enemies = [thunder_center, thunder_edge, thunder_outside]
    talisman_world.damage_enemy = func(enemy, _damage: float, _options = {}) -> void: thunder_hits.append(enemy)
    talisman._strike_thunder(thunder_center, 10.0, talisman_world)
    runner.check(thunder_hits.has(thunder_edge) and not thunder_hits.has(thunder_outside),
        "[6] talisman thunder AoE must be capped at 80px plus target radius")
    runner.check(talisman.bolt_fx.back()["aoe"] and is_equal_approx(talisman.bolt_fx.back()["radius"], 80.0),
        "[6] talisman thunder visual radius must match gameplay AoE")

    var sword = WeaponFactoryScript.create_weapon("sword")
    var sword_world: Dictionary = _base_world()
    # Lv2 起即无限贯穿，与原型 js/weapons/sword.js 的 maxHits: Infinity 一致（RULES.md §12.1）
    var expected_max_hits: Array = [INF, INF, INF, INF, INF]
    for weapon_level in range(2, 7):
        sword.level = weapon_level
        sword.timer = 0.0
        for projectile in sword_world.projectiles:
            projectile.onHit = Callable()
        sword_world.projectiles.clear()
        sword.update(1.0 / 60.0, sword_world)
        var expected: float = expected_max_hits[weapon_level - 2]
        runner.check(sword_world.projectiles.size() == 1 and sword_world.projectiles[0].maxHits == expected,
            "[6] sword Lv%d hit limit mismatch" % weapon_level)

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
    runner.check(fly_sword.flying_swords.size() == 1
        and fly_sword.flying_swords[0].has("x") and fly_sword.flying_swords[0].has("y")
        and fly_sword.flying_swords[0]["state"] == "orbit",
        "[6] sword intent must expose flying-sword visual state")
    var peak_chains: int = 0
    for ignored in 180:
        fly_sword.update(1.0 / 60.0, fly_world)
        if not fly_sword.flying_swords.is_empty():
            peak_chains = maxi(peak_chains, fly_sword.flying_swords[0]["chains"])
    runner.check(fly_world.enemies.all(func(enemy) -> bool: return enemy.hp < 1000.0),
        "[6] flying sword must pierce every shuttled enemy")
    runner.check(peak_chains >= 3, "[6] flying sword must chain-shuttle between multiple enemies")
    var intent_sword = WeaponFactoryScript.create_weapon("sword")
    intent_sword.level = 6
    intent_sword.hit_carry = 9
    var intent_world: Dictionary = _base_world()
    intent_world.enemies = [_enemy(20.0, 0.0, 1000.0), _enemy(-20.0, 0.0, 1000.0)]
    intent_sword._fire_ring(intent_world, intent_sword.stats)
    runner.check(intent_sword.hit_carry == 9 and intent_sword.flying_swords.is_empty(),
        "[6] draw slash ring must not charge sword intent")

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
    StatusScript.apply_dot(burn_enemy, "burn", 4.0, 5.0)
    StatusScript.apply_dot(burn_enemy, "blaze", 2.0, 2.0)
    runner.check(burn_enemy.dots.size() == 1 and burn_enemy.dots.has("burn")
        and burn_enemy.dots["burn"]["dps"] == 4.0 and burn_enemy.dots["burn"]["timer"] == 2.0
        and StatusScript.has_dot(burn_enemy, "blaze"),
        "[6] fire DoT alias must share one non-stacking burn instance and refresh duration")
    game.damage_enemy(burn_enemy, 2.0)
    runner.check(game.killLog.back()["burned"] and not game.killLog.back().has("blazed"),
        "[6] fire DoT kill log must expose only burned")

    var feedback_enemy = _enemy(40.0, 20.0, 30.0)
    game.damage_enemy(feedback_enemy, 5.0, {"sourceWeaponId": "sword", "sourceAction": "melee", "noSynergy": true})
    runner.check(feedback_enemy.hitFlash > 0.0 and game.effects.any(func(effect: Dictionary) -> bool: return effect["type"] == "weaponImpact" and effect["sourceWeaponId"] == "sword"),
        "[6] weapon hit visual feedback event missing")
    game.damage_enemy(feedback_enemy, 100.0, {"sourceWeaponId": "staff", "sourceAction": "summon", "noSynergy": true})
    runner.check(game.effects.any(func(effect: Dictionary) -> bool: return effect["type"] == "enemyDefeat" and effect["enemyType"] == feedback_enemy.type),
        "[6] enemy defeat visual feedback event missing")

    var dot_scale: Dictionary = {"cloak": 0.0, "trail": 0.0, "sword": 0.0, "staff": 0.0}
    var dot_world: Dictionary = _base_world()
    dot_world.mods["damageMult"] = 2.0
    dot_world.enemies = [_enemy(0.0, 0.0, 1000.0)]
    dot_world.apply_dot = func(_enemy_value, type: String, dps: float, _duration: float) -> void:
        if type == "burn": dot_scale["cloak"] = maxf(dot_scale["cloak"], dps)
    var dot_cloak = WeaponFactoryScript.create_weapon("cloak")
    dot_cloak.level = 2
    dot_cloak.update(0.5, dot_world)
    runner.check(dot_scale["cloak"] == 20.0, "[6] cloak burn must inherit weapon damage multiplier")

    var dot_sword = WeaponFactoryScript.create_weapon("sword")
    dot_sword.level = 4
    dot_world.apply_dot = func(_enemy_value, type: String, dps: float, _duration: float) -> void:
        if type == "bleed": dot_scale["sword"] = dps
    dot_sword._fire_ring(dot_world, dot_sword.stats)
    runner.check(dot_scale["sword"] == 20.0, "[6] sword bleed must inherit weapon damage multiplier")

    var dot_trail = WeaponFactoryScript.create_weapon("trail")
    dot_trail.level = 2
    dot_world.player.moving = true
    dot_world.apply_dot = func(_enemy_value, type: String, dps: float, _duration: float) -> void:
        if type == "burn": dot_scale["trail"] = dps
    dot_trail.update(0.0, dot_world)
    dot_trail.update_trail(dot_world.trails.back(), dot_world, 0.01)
    runner.check(dot_scale["trail"] == 24.0, "[6] trail burn must inherit weapon damage multiplier")

    var dot_staff = WeaponFactoryScript.create_weapon("staff")
    dot_staff.level = 2
    var dot_summon: Dictionary = {"x": 0.0, "y": 0.0, "damage": 10.0, "life": 5.0,
        "speed": 0.0, "hitTimer": 0.0, "wander": 0.0, "dead": false, "corpse": false}
    dot_world.apply_dot = func(_enemy_value, type: String, dps: float, _duration: float) -> void:
        if type == "poison": dot_scale["staff"] = dps
    dot_staff._update_summon(dot_summon, dot_world, dot_staff.stats, 0.0)
    runner.check(dot_scale["staff"] == 16.0, "[6] staff poison must inherit weapon damage multiplier")

    var ring = WeaponFactoryScript.create_weapon("ring")
    ring.level = 4
    ring.drop_t = 0.5
    var ring_world_damage: Dictionary = _base_world()
    ring_world_damage.enemies = [_enemy(132.0, 0.0, 1000.0)]
    var ring_result: Dictionary = {"damage": 0.0, "slowFactor": 0.0, "slowDuration": 0.0}
    ring_world_damage.damage_enemy = func(_enemy_value, damage: float, _options = {}) -> void: ring_result["damage"] = damage
    ring_world_damage.apply_slow = func(_enemy_value, factor: float, duration: float) -> void:
        ring_result["slowFactor"] = factor
        ring_result["slowDuration"] = duration
    ring.update(0.0, ring_world_damage)
    runner.check(is_equal_approx(ring_result["damage"], ring.stats["damage"] * 1.5),
        "[6] jade ring expansion damage must be 1.5x")
    runner.check(is_equal_approx(ring_result["slowFactor"], 0.25) and is_equal_approx(ring_result["slowDuration"], 1.2),
        "[6] cold jade slow must be 25% for 1.2s")

    var frenzy_ring = WeaponFactoryScript.create_weapon("ring")
    frenzy_ring.level = 6
    var frenzy_world: Dictionary = _base_world()
    frenzy_world.kills = 80
    frenzy_world.enemies = [_enemy(120.0, 0.0, 1000.0)]
    var frenzy_damage: Dictionary = {"value": 0.0}
    frenzy_world.damage_enemy = func(_enemy_value, damage: float, _options = {}) -> void: frenzy_damage["value"] = damage
    frenzy_ring.update(0.0, frenzy_world)
    runner.check(is_equal_approx(frenzy_ring.frenzy_timer, 3.0)
        and is_equal_approx(frenzy_damage["value"], frenzy_ring.stats["damage"] * 2.0),
        "[6] jade ring frenzy must trigger every 80 kills for 3s at 2x total damage")
    var counter_result: Dictionary = {"freeze": 0.0}
    frenzy_world.apply_freeze = func(_enemy_value, duration: float) -> void: counter_result["freeze"] = duration
    frenzy_ring._counter_nova(frenzy_world, frenzy_ring.stats)
    runner.check(is_equal_approx(frenzy_ring.counter_cd, 20.0) and is_equal_approx(counter_result["freeze"], 1.5),
        "[6] jade ring counter must freeze 1.5s with 20s cooldown")
    var counter_origin: Dictionary = frenzy_ring.counter_fx.back().duplicate()
    frenzy_world.player.x = 400.0
    frenzy_world.player.y = -200.0
    runner.check(is_equal_approx(counter_origin["x"], 0.0) and is_equal_approx(counter_origin["y"], 0.0)
        and is_equal_approx(counter_origin["r"], frenzy_ring.stats["counterRadius"]),
        "[6] jade ring counter visual must stay at its trigger position")

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
    var raw_points: Array = [[-300.0, 0.0, -0.5], [0.0, 0.0, 0.0], [120.0, 0.0, 0.35], [120.0, 120.0, 0.7], [0.0, 120.0, 1.05], [5.0, 5.0, 1.3]]
    for point: Array in raw_points:
        trail.path_points.append({"x": point[0], "y": point[1], "at": point[2], "trail": {"dead": false}})
    trail_world.elapsed = 1.3
    trail._try_create_furnace(trail_world, trail.stats)
    runner.check(trail.furnaces.size() == 1 and trail.loop_cooldown > 0.0, "[6] trail valid loop did not create furnace")
    runner.check(trail.path_points.size() == 1 and trail.path_points[0]["x"] == -300.0
        and not trail.path_points[0]["trail"]["dead"],
        "[6] trail loop must consume only the closed segment")
    var furnace: Dictionary = trail.furnaces[0]
    furnace["life"] = 8.5
    furnace["fuel"] = 9.0
    trail._try_open(furnace, trail_world, trail.stats)
    runner.check(furnace["opens"] == 1 and trail.hot_zones.size() == 1 and is_equal_approx(furnace["life"], 10.5),
        "[6] trail furnace opening, duration extension, or Ninefold hot zone missing")
    runner.check(furnace["openFx"] > 0.0 and furnace["openNineTurn"],
        "[6] trail furnace opening must expose Ninefold explosion visual state")
    var base_trail = WeaponFactoryScript.create_weapon("trail")
    base_trail.level = 4
    var enhanced_trail = WeaponFactoryScript.create_weapon("trail")
    enhanced_trail.level = 5
    var compare_world: Dictionary = _base_world()
    compare_world.enemies = []
    var square: Array = [{"x": 0.0, "y": 0.0}, {"x": 120.0, "y": 0.0},
        {"x": 120.0, "y": 120.0}, {"x": 0.0, "y": 120.0}]
    base_trail._create_furnace(square, 14400.0, compare_world, base_trail.stats)
    enhanced_trail._create_furnace(square, 14400.0, compare_world, enhanced_trail.stats)
    var base_furnace: Dictionary = base_trail.furnaces[0]
    var enhanced_furnace: Dictionary = enhanced_trail.furnaces[0]
    runner.check(enhanced_furnace["area"] > base_furnace["area"]
        and enhanced_furnace["pullSpeed"] > base_furnace["pullSpeed"]
        and enhanced_furnace["tickDamageMult"] > base_furnace["tickDamageMult"]
        and enhanced_furnace["openDamageMult"] > base_furnace["openDamageMult"],
        "[6] trail Lv5 must enhance furnace area, pull, tick damage, and opening burst")
    trail._update_hot_zones(0.5, trail_world, trail.stats)
    runner.check(hot_result["heals"] == 1.0 and is_equal_approx(hot_result["speed"], 1.12),
        "[6] trail hot-zone healing or movement bonus missing")

    var staff = WeaponFactoryScript.create_weapon("staff")
    runner.check(staff.card["levels"][3]["blastRadius"] == 70
        and staff.card["levels"][4]["blastRadius"] == 105
        and staff.card["levels"][5]["blastRadius"] == 105,
        "[6] staff explosion radius progression must be 70/105/105")
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
    staff.blasts.clear()
    blast_world.damage_enemy = func(_enemy_value, _damage: float, options: Dictionary = {}) -> void: blast_options.merge(options, true)
    staff.detonate({"x": 0.0, "y": 0.0, "damage": 10.0}, staff.stats, blast_world)
    runner.check(blast_options.get("noSummon", false), "[6] staff explosion damage must carry noSummon")
    runner.check(staff.blasts.size() == 1 and is_equal_approx(staff.blasts[0]["maxR"], 105.0)
        and is_equal_approx(staff.blasts[0]["maxT"], 0.35),
        "[6] staff explosion must expose radius and lifetime for rendering")
    for card: Dictionary in CardsScript.WEAPON_CARDS:
        var evolution_weapon = WeaponFactoryScript.create_weapon(card["id"])
        evolution_weapon.level = 4
        game.effects.clear()
        game.on_weapon_level_changed(evolution_weapon, 3)
        runner.check(game.effects.size() == 1 and game.effects[0].get("type") == "weaponEvolution"
            and game.effects[0].get("weaponId") == card["id"] and game.effects[0].get("evolutionLevel") == 4,
            "[6] %s Lv4 evolution feedback" % card["id"])
        evolution_weapon.level = 6
        game.effects.clear()
        game.on_weapon_level_changed(evolution_weapon, 5)
        runner.check(game.effects.size() == 1 and game.effects[0].get("evolutionLevel") == 6
            and game.effects[0].get("radius") > 200.0, "[6] %s Lv6 evolution feedback" % card["id"])
    _release_refs(
        [talisman, sword, ring_sword, whiff_sword, fly_sword, intent_sword, cloak, dot_cloak, dot_sword,
            dot_trail, dot_staff, ring, frenzy_ring, trail, base_trail, enhanced_trail, staff],
        [talisman_world, talisman.world, sword_world, ring_world, whiff_world, fly_world, intent_world, cloak_world,
            dot_world, ring_world_damage, frenzy_world, trail_world, compare_world, staff_world, blast_world]
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
