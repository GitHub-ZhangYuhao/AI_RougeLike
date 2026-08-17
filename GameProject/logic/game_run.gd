extends RefCounted
## ← js/game.js：M1 核心循环。logic 层保持纯 RefCounted，可 headless 定步长驱动。

const InputScript: GDScript = preload("res://logic/input_state.gd")
const PlayerScript: GDScript = preload("res://logic/player.gd")
const CameraScript: GDScript = preload("res://logic/camera.gd")
const CardsScript: GDScript = preload("res://logic/cards.gd")
const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const SpawnerScript: GDScript = preload("res://logic/spawner.gd")
const WavesScript: GDScript = preload("res://logic/systems/waves.gd")
const EnemyScript: GDScript = preload("res://logic/enemy.gd")
const HostileProjectileScript: GDScript = preload("res://logic/enemies/hostile_projectile.gd")
const StatusScript: GDScript = preload("res://logic/systems/status.gd")
const TrailScript: GDScript = preload("res://logic/weapons/trail.gd")
const GemsScript: GDScript = preload("res://logic/gems.gd")
const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")
const UtilsScript: GDScript = preload("res://logic/utils.gd")
const RareItemsScript: GDScript = preload("res://logic/rare_items.gd")
const DropsScript: GDScript = preload("res://logic/meta/drops.gd")
const SynergiesScript: GDScript = preload("res://logic/systems/synergies.gd")
const TasksScript: GDScript = preload("res://logic/systems/tasks.gd")
const ShopScript: GDScript = preload("res://logic/meta/shop.gd")
const MetaItemsScript: GDScript = preload("res://logic/meta/items.gd")
const LevelGeometryScript: GDScript = preload("res://logic/level_geometry.gd")
const DebugRuntimeScript: GDScript = preload("res://logic/debug_runtime.gd")
const WEAPON_EVOLUTION_COLORS: Dictionary = {
    "sword": "#9fe8ff", "cloak": "#ff6b32", "talisman": "#ffe45c",
    "trail": "#ff8a32", "ring": "#8fffd0", "staff": "#d89cff",
}

var state: String
var debug
var weapons: Array = []
var attrStacks: Dictionary = {}
var metaStacks: Dictionary = {}
var mods: Dictionary = {}
var level: int
var xp: float
var kills: int
var elapsed: float
var player
var camera
var input
var enemies: Array = []
var viewport_size: Vector2 = Vector2(1280, 720)
var projectiles: Array = []
var hostileProjectiles: Array = []
var trails: Array[Dictionary] = []
var summons: Array[Dictionary] = []
var effects: Array = []
var moveSpeedBonuses: Dictionary = {}
var gems: Array[Dictionary] = []
var pickups: Array = []
var killLog: Array[Dictionary] = []
var waveDirector
var taskDirector
var spawner
var synergies
var currentOffers: Array[Dictionary] = []
var pendingChoices: int
var pendingTaskRewards: Array = []
var taskBonuses: Dictionary = {}
var taskBlessings: Dictionary = {}
var rareInventory: Dictionary = {}
var rareBonuses: Dictionary = {}
var rareMessage = null
var tempBackpack: Dictionary = {}
var save: Dictionary
var bossesDefeated: int
var lastRunSummary = null
var lastDeathLoss = null
var lastDeathReward: int = 0
var choiceOrigin: String = "opening"
var hitShake: float = 0.0
var _next_kill_id: int = 1
var _final_settled: bool = false
var _death_settled: bool = false
var _synergy_activation_serial_seen: int = 0


func _init() -> void:
    input = InputScript.new()
    save = MetaSave.load_save()
    debug = DebugRuntimeScript.new(self)
    reset()


func reset() -> void:
    release_runtime_refs()
    state = "menu"
    elapsed = 0.0
    kills = 0
    level = 1
    xp = 0.0
    pendingChoices = 0
    pendingTaskRewards = []
    attrStacks = {}
    metaStacks = save["metaLevels"].duplicate(true)
    taskBonuses = {"damageMult": 0.0, "xpMult": 0.0, "moveSpeedMult": 0.0,
        "armor": 0.0, "magnetRadiusBonus": 0.0, "eliteBossDamageMult": 0.0}
    taskBlessings = {}
    mods = CardsScript.compute_mods(attrStacks, metaStacks)
    tempBackpack = {"shard": 0, "essence": 0, "soulCrystal": 0}
    rareInventory = {}
    rareBonuses = {"damageMult": 1.0, "xpMult": 1.0, "moveSpeedMult": 1.0, "magnetRadiusBonus": 0.0}
    rareMessage = null
    lastRunSummary = null
    lastDeathLoss = null
    lastDeathReward = 0
    _final_settled = false
    _death_settled = false
    _synergy_activation_serial_seen = 0
    player = PlayerScript.new(0.0, 0.0)
    camera = CameraScript.new(0.0, 0.0)
    enemies = []
    projectiles = []
    hostileProjectiles = []
    trails = []
    summons = []
    effects = []
    moveSpeedBonuses = {}
    gems = []
    pickups = []
    weapons = []
    killLog = []
    _next_kill_id = 1
    spawner = SpawnerScript.new()
    waveDirector = WavesScript.new()
    if taskDirector == null:
        taskDirector = TasksScript.new()
    else:
        taskDirector.reset()
    synergies = SynergiesScript.new()
    bossesDefeated = 0
    choiceOrigin = "opening"
    currentOffers = CardsScript.opening_offers(self)
    if debug != null:
        debug.on_game_reset()


func step(dt: float, view_w: float = 1280.0, view_h: float = 720.0) -> void:
    if debug != null and debug.settings["paused"]:
        return
    if state == "menu":
        if input.was_pressed("Enter") or input.was_pressed("Space"):
            _start_run()
        return
    if state == "shop" or state == "storage":
        if input.was_pressed("Escape"):
            back_to_menu()
        return
    if state == "extraction":
        if input.was_pressed("KeyE"):
            extract()
        elif input.was_pressed("KeyC"):
            continue_deeper()
        return
    if state == "summary":
        if input.was_pressed("Enter"):
            state = "menu"
        return
    if state == "opening" or state == "choice":
        _handle_choice(view_w, view_h)
        return
    if state == "dead":
        if input.was_pressed("KeyR"):
            reset()
        return
    if not pendingTaskRewards.is_empty():
        choiceOrigin = "task"
        currentOffers = pendingTaskRewards.pop_front()
        state = "choice"
        return
    if pendingChoices > 0:
        currentOffers = CardsScript.generate_offers(self)
        if currentOffers.is_empty():
            pendingChoices = 0
        else:
            choiceOrigin = "levelup"
            state = "choice"
        return
    if state != "playing":
        return

    _handle_weapon_build_click()
    elapsed += dt
    synergies.update(dt)
    if synergies.activation_serial > _synergy_activation_serial_seen:
        _synergy_activation_serial_seen = synergies.activation_serial
        hitShake = maxf(hitShake, 0.45)
    var temporary_speed_mult: float = 1.0
    for source in moveSpeedBonuses.keys():
        if moveSpeedBonuses[source]["until"] <= elapsed:
            moveSpeedBonuses.erase(source)
        else:
            temporary_speed_mult = maxf(temporary_speed_mult, moveSpeedBonuses[source]["multiplier"])
    player.speed = Config.CONFIG["player"]["speed"] * mods["moveSpeedMult"] * temporary_speed_mult
    player.update(input, dt)
    _clamp_entity_to_level(player, LevelGeometryScript.PLAYER_INSET)
    camera.follow(player, dt, Config.CONFIG["camera"]["lerp"])
    var camera_position: Dictionary = LevelGeometryScript.clamp_camera(camera.x, camera.y, view_w, view_h)
    camera.x = camera_position["x"]
    camera.y = camera_position["y"]
    waveDirector.update(dt, self, camera, view_w, view_h)
    taskDirector.update(dt, self)
    for enemy in enemies:
        if enemy.dead:
            continue
        debug.apply_enemy_multipliers(enemy)
        var dot_damage: float = StatusScript.tick_status(enemy, dt)
        if dot_damage > 0.0:
            damage_enemy(enemy, dot_damage)
        if not enemy.dead:
            enemy.update(player, dt, _world())
    EnemyScript.separate_enemies(enemies, dt)
    for enemy in enemies:
        if not enemy.dead:
            _clamp_entity_to_level(enemy)
    var world: Dictionary = _world()
    for weapon in weapons:
        weapon.update(dt, world)
    for trail: Dictionary in trails:
        TrailScript.update_trail(trail, world, dt)
    for projectile in projectiles:
        if not projectile.dead:
            projectile.update(dt)
            if LevelGeometryScript.is_outside_circle(projectile.x, projectile.y, projectile.radius):
                projectile.dead = true
    for projectile in hostileProjectiles:
        if not projectile.dead:
            projectile.update(dt)
            if LevelGeometryScript.is_outside_circle(projectile.x, projectile.y, projectile.radius):
                projectile.dead = true
    _handle_collisions()
    _update_gems(dt)
    _update_pickups(dt)
    for effect in effects:
        effect["ttl"] -= dt
    _cleanup()
    hitShake = maxf(0.0, hitShake - dt)
    if rareMessage != null:
        rareMessage["ttl"] -= dt
        if rareMessage["ttl"] <= 0.0:
            rareMessage = null


func _start_run() -> void:
    save["stats"]["runs"] += 1
    MetaSave.persist_save(save)
    reset()
    state = "opening"
    var meta_max_hp: int = metaStacks.get("maxHp", 0)
    if meta_max_hp > 0:
        increase_max_hp(20.0 * meta_max_hp, 20.0 * meta_max_hp)


func _handle_choice(view_w: float, view_h: float) -> void:
    var selected: int = -1
    for i in mini(9, currentOffers.size()):
        if input.was_pressed("Digit%d" % (i + 1)) or input.was_pressed("Numpad%d" % (i + 1)):
            selected = i
            break
    if selected < 0 and input.mouse_clicked():
        var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(view_w, view_h, currentOffers.size())
        for i in rects.size():
            var rect: Dictionary = rects[i]
            if input.mouse_x >= rect["x"] and input.mouse_x <= rect["x"] + rect["w"] and input.mouse_y >= rect["y"] and input.mouse_y <= rect["y"] + rect["h"]:
                selected = i
                break
    if selected < 0 or selected >= currentOffers.size():
        return
    _apply_offer(currentOffers[selected])
    _finish_choice()


func _apply_offer(offer: Dictionary) -> void:
    var apply: Callable = offer.get("apply", Callable())
    if apply.is_valid():
        apply.call(self)
        return
    if str(offer.get("type", "")).begins_with("task"):
        TasksScript.apply_reward(offer, self)
        return
    var card: Dictionary = offer["card"]
    if offer["type"] == "new":
        if weapons.size() < Config.CONFIG["cards"]["maxWeaponSlots"]:
            var weapon = WeaponFactoryScript.create_weapon_by_type(card["id"], card)
            if weapon != null:
                weapons.append(weapon)
        synergies.refresh(weapons, elapsed)
    elif offer["type"] == "upgrade":
        for weapon in weapons:
            if weapon.card["id"] == card["id"]:
                var previous_level: int = weapon.level
                weapon.level = mini(weapon.level + 1, weapon.card["maxLevel"])
                on_weapon_level_changed(weapon, previous_level)
                break
        synergies.refresh(weapons, elapsed)
    else:
        var id: String = card["id"]
        if attrStacks.get(id, 0) >= Config.CONFIG["cards"]["attrMaxStack"]:
            return
        attrStacks[id] = attrStacks.get(id, 0) + 1
        if id == "maxHp":
            increase_max_hp(20.0, 20.0)
        recompute_mods()


func _finish_choice() -> void:
    if choiceOrigin == "levelup":
        pendingChoices -= 1
    if not pendingTaskRewards.is_empty():
        choiceOrigin = "task"
        currentOffers = pendingTaskRewards.pop_front()
        return
    if pendingChoices > 0:
        currentOffers = CardsScript.generate_offers(self)
        if not currentOffers.is_empty():
            choiceOrigin = "levelup"
            state = "choice"
            return
        pendingChoices = 0
    state = "playing"


func recompute_mods() -> void:
    mods = CardsScript.compute_mods(attrStacks, metaStacks)
    mods["damageMult"] *= rareBonuses.get("damageMult", 1.0) * (1.0 + taskBonuses.get("damageMult", 0.0))
    mods["xpMult"] *= rareBonuses.get("xpMult", 1.0) * (1.0 + taskBonuses.get("xpMult", 0.0))
    mods["moveSpeedMult"] *= rareBonuses.get("moveSpeedMult", 1.0) * (1.0 + taskBonuses.get("moveSpeedMult", 0.0))
    mods["armor"] += taskBonuses.get("armor", 0.0)
    mods["magnetRadiusBonus"] += taskBonuses.get("magnetRadiusBonus", 0.0)
    if debug != null:
        mods["damageMult"] *= debug.settings["player"]["damageMult"]
        mods["xpMult"] *= debug.settings["player"]["xpMult"]
        mods["moveSpeedMult"] *= debug.settings["player"]["moveSpeedMult"]
        mods["armor"] += debug.settings["player"]["armorBonus"]
    mods["damageReduction"] = minf(0.5, mods["armor"] / (mods["armor"] + 100.0))
    if debug != null:
        debug.sync_player_max_hp()


func xp_to_next() -> float:
    return Config.CONFIG["xp"]["base"] + (level - 1) * Config.CONFIG["xp"]["perLevel"]


func gain_xp(amount: float, apply_multiplier: bool = true) -> void:
    xp += amount * (mods["xpMult"] if apply_multiplier else 1.0)
    while xp >= xp_to_next():
        xp -= xp_to_next()
        level += 1
        pendingChoices += 1


func gem_magnet_radius() -> float:
    var radius: float = Config.CONFIG["gems"]["magnetRadius"] + mods["magnetRadiusBonus"] + rareBonuses.get("magnetRadiusBonus", 0.0)
    return radius * (debug.settings["player"]["pickupRangeMult"] if debug != null else 1.0)


func damage_enemy(enemy, damage: float, options: Dictionary = {}) -> void:
    if enemy.dead:
        return
    var task_damage_mult: float = 1.0 + taskBonuses.get("eliteBossDamageMult", 0.0) if enemy.rank == "elite" or enemy.rank == "boss" else 1.0
    var final_damage: float = enemy.modify_incoming_damage(damage * task_damage_mult)
    if final_damage <= 0.0:
        return
    enemy.hp -= final_damage
    enemy.hitFlash = 0.14
    var defeated: bool = enemy.hp <= 0.0
    _emit_damage_feedback(enemy, final_damage, options, defeated)
    if defeated:
        _kill_enemy(enemy, options)
    if not options.get("noSynergy", false):
        synergies.on_damage({"target": enemy, "damage": final_damage, "options": options}, _world())


func _emit_damage_feedback(enemy, damage: float, options: Dictionary, defeated: bool) -> void:
    var source_weapon_id = options.get("sourceWeaponId")
    if source_weapon_id != null and effects.size() < 220:
        effects.append({"type": "weaponImpact", "x": enemy.x, "y": enemy.y,
            "radius": enemy.radius, "damage": damage, "sourceWeaponId": source_weapon_id,
            "sourceAction": options.get("sourceAction", "hit"),
            "angle": atan2(enemy.y - player.y, enemy.x - player.x),
            "seed": _next_kill_id + effects.size(), "ttl": 0.5, "maxTtl": 0.5})
    if defeated and effects.size() < 220:
        effects.append({"type": "enemyDefeat", "x": enemy.x, "y": enemy.y,
            "radius": enemy.radius, "enemyType": enemy.type, "rank": enemy.rank,
            "sourceWeaponId": source_weapon_id if source_weapon_id != null else "status",
            "flipH": player.x < enemy.x, "seed": _next_kill_id,
            "ttl": 0.38 if enemy.rank == "boss" else 0.3,
            "maxTtl": 0.38 if enemy.rank == "boss" else 0.3})


func _kill_enemy(enemy, options: Dictionary = {}) -> void:
    if enemy.dead:
        return
    enemy.dead = true
    kills += 1
    gems.append(GemsScript.create_gem(enemy.x, enemy.y, elapsed))
    if not enemy.get("suppressRareDrop") and enemy.rank == "elite":
        pickups.append(RareItemsScript.create_rare_pickup(enemy.x, enemy.y))
    elif not enemy.get("suppressRareDrop") and enemy.rank == "boss":
        bossesDefeated += 1
        save["stats"]["totalBossKills"] += 1
        MetaSave.persist_save(save)
        # Preserve JS RNG order: each pickup rolls its item, then its pulse.
        pickups.append(RareItemsScript.create_rare_pickup(enemy.x - 14.0, enemy.y))
        pickups.append(RareItemsScript.create_rare_pickup(enemy.x + 14.0, enemy.y))
    killLog.append({"id": _next_kill_id, "x": enemy.x, "y": enemy.y,
        "burned": StatusScript.has_dot(enemy, "burn"),
        "noSummon": options.get("noSummon", false), "noSynergy": options.get("noSynergy", false),
        "sourceWeaponId": options.get("sourceWeaponId"), "sourceAction": options.get("sourceAction"),
        "sourceTags": options.get("sourceTags", []), "synergyId": options.get("synergyId")})
    _next_kill_id += 1
    if killLog.size() > Config.CONFIG["killLog"]["cap"]:
        killLog.pop_front()
    taskDirector.on_enemy_killed(enemy, self)


func hurt_player(damage: float) -> bool:
    if debug != null and debug.settings["invincible"]:
        return false
    var final_damage: float = damage * (1.0 - mods["damageReduction"])
    if not player.hurt(final_damage):
        return false
    hitShake = 0.25
    player.lastHurtAt = elapsed
    return true


func heal_player(amount: float) -> void:
    player.hp = minf(player.maxHp, player.hp + amount)


func increase_max_hp(amount: float, heal_amount: float = -1.0) -> void:
    player.maxHp = maxf(1.0, player.maxHp + amount)
    player.hp = minf(player.maxHp, player.hp + (amount if heal_amount < 0.0 else heal_amount))


func _clamp_entity_to_level(entity, inset: float = 0.0) -> void:
    var position: Dictionary = LevelGeometryScript.clamp_circle(entity.x, entity.y, entity.radius + inset)
    entity.x = position["x"]
    entity.y = position["y"]


func _handle_collisions() -> void:
    for enemy in enemies:
        if enemy.dead:
            continue
        if enemy.hitCooldown <= 0.0 and UtilsScript.dist2(player.x, player.y, enemy.x, enemy.y) <= pow(player.radius + enemy.radius, 2):
            if hurt_player(enemy.damage):
                enemy.hitCooldown = 0.6
    for hostile in hostileProjectiles:
        if hostile.dead:
            continue
        if UtilsScript.dist2(hostile.x, hostile.y, player.x, player.y) <= pow(hostile.radius + player.radius, 2):
            hostile.dead = true
            hurt_player(hostile.damage)
    for projectile in projectiles:
        if projectile.dead:
            continue
        for enemy in enemies:
            if enemy.dead or projectile.hitSet.has(enemy.get_instance_id()):
                continue
            if UtilsScript.dist2(projectile.x, projectile.y, enemy.x, enemy.y) <= pow(projectile.radius + enemy.radius, 2):
                damage_enemy(enemy, projectile.damage, projectile.damageOptions)
                projectile.record_hit(enemy)
                if projectile.dead:
                    break
    # Death is settled at the end of collision processing, after all hit pipelines.
    if player.hp <= 0.0 and state == "playing":
        player.hp = 0.0
        state = "dead"
        _apply_death_loss()


func _update_gems(dt: float) -> void:
    for gem: Dictionary in gems:
        GemsScript.update_gem(gem, player, dt, gem_magnet_radius())
        if UtilsScript.dist2(player.x, player.y, gem["x"], gem["y"]) <= pow(Config.CONFIG["gems"]["pickupRadius"], 2):
            gem["dead"] = true
            gain_xp(gem["value"])


func _update_pickups(_dt: float) -> void:
    for pickup in pickups:
        if pickup["dead"]:
            continue
        var radius: float = Config.CONFIG["pickups"]["rarePickupRadius"] if pickup.get("kind") == "rare" else Config.CONFIG["pickups"]["pickupRadius"]
        if UtilsScript.dist2(player.x, player.y, pickup["x"], pickup["y"]) > radius * radius:
            continue
        pickup["dead"] = true
        if pickup.get("kind") == "rare":
            var item: Dictionary = RareItemsScript.apply_rare_item(self, pickup)
            if not item.is_empty():
                rareMessage = {"item": item, "text": item["name"], "detail": item["description"], "color": item["color"], "ttl": 3.5}
        elif pickup.get("type") == "hp" or pickup.get("kind") == "hp":
            heal_player(Config.CONFIG["pickups"]["hpValue"] * pickup.get("amount", 1))


func release_runtime_refs() -> void:
    currentOffers.clear()
    pendingTaskRewards.clear()
    if taskDirector != null:
        taskDirector.current = null
    for projectile in projectiles:
        projectile.onHit = Callable()
    for weapon in weapons:
        if weapon.has_method("release_runtime_refs"):
            weapon.release_runtime_refs()
        weapon.world = null


func _cleanup() -> void:
    for i in range(enemies.size() - 1, -1, -1):
        if enemies[i].dead:
            enemies.remove_at(i)
    for i in range(projectiles.size() - 1, -1, -1):
        if projectiles[i].dead:
            projectiles[i].onHit = Callable()
            projectiles.remove_at(i)
    for i in range(hostileProjectiles.size() - 1, -1, -1):
        if hostileProjectiles[i].dead:
            hostileProjectiles.remove_at(i)
    for i in range(trails.size() - 1, -1, -1):
        if trails[i]["dead"]:
            trails.remove_at(i)
    for i in range(summons.size() - 1, -1, -1):
        if summons[i]["dead"]:
            summons.remove_at(i)
    for i in range(gems.size() - 1, -1, -1):
        if gems[i]["dead"]:
            gems.remove_at(i)
    for i in range(pickups.size() - 1, -1, -1):
        if pickups[i]["dead"]:
            pickups.remove_at(i)
    for i in range(effects.size() - 1, -1, -1):
        if effects[i]["ttl"] <= 0.0:
            effects.remove_at(i)


func _world() -> Dictionary:
    return {"player": player, "enemies": enemies, "projectiles": projectiles,
        "hostileProjectiles": hostileProjectiles, "trails": trails, "summons": summons,
        "effects": effects, "weapons": weapons, "synergies": synergies, "mods": mods,
        "elapsed": elapsed, "kills": kills, "killLog": killLog, "kill_log": killLog,
        "damage_enemy": Callable(self, "damage_enemy"), "hurt_player": Callable(self, "hurt_player"),
        "heal_player": Callable(self, "heal_player"), "drop_pickup": Callable(self, "drop_pickup"),
        "spawn_hostile_projectile": Callable(self, "spawn_hostile_projectile"),
        "spawn_enemy_blast": Callable(self, "spawn_enemy_blast"),
        "apply_dot": Callable(StatusScript, "apply_dot"), "apply_slow": Callable(StatusScript, "apply_slow"),
        "apply_freeze": Callable(StatusScript, "apply_freeze"), "has_dot": Callable(StatusScript, "has_dot"),
        "set_player_move_speed_bonus": Callable(self, "set_player_move_speed_bonus"),
        "has_synergy": Callable(self, "has_synergy"), "get_weapon": Callable(self, "get_weapon"),
        "record_synergy_trigger": Callable(self, "record_synergy_trigger")}


func _handle_weapon_build_click() -> bool:
    for i in mini(6, weapons.size()):
        if input.was_pressed("Digit%d" % (i + 1)):
            return synergies.toggle_build_weapon(weapons[i].card["id"], weapons, elapsed)
    if input.mouse_clicked():
        var rects: Array[Dictionary] = UiLayoutScript.get_weapon_slot_rects(viewport_size.x, viewport_size.y)
        for i in mini(rects.size(), weapons.size()):
            var rect: Dictionary = rects[i]
            if input.mouse_x >= rect["x"] and input.mouse_x <= rect["x"] + rect["w"] and input.mouse_y >= rect["y"] and input.mouse_y <= rect["y"] + rect["h"]:
                return synergies.toggle_build_weapon(weapons[i].card["id"], weapons, elapsed)
    return false


func set_player_move_speed_bonus(source, multiplier: float, duration: float = 0.12) -> void:
    moveSpeedBonuses[source] = {"multiplier": multiplier, "until": elapsed + duration}


func drop_pickup(type: String, x: float, y: float, amount: int = 1) -> void:
    if type == "hp":
        var alive_hp: int = 0
        for pickup in pickups:
            if not pickup["dead"] and (pickup.get("type") == "hp" or pickup.get("kind") == "hp"):
                alive_hp += 1
        if alive_hp >= Config.CONFIG["pickups"]["maxAlive"]:
            return
    pickups.append({"type": type, "kind": type, "x": x, "y": y, "amount": amount, "dead": false})


func spawn_hostile_projectile(options: Dictionary):
    var projectile = HostileProjectileScript.new(options)
    hostileProjectiles.append(projectile)
    return projectile


func spawn_enemy_blast(options, y: float = 0.0, radius: float = 0.0, ttl: float = 0.35) -> void:
    var effect: Dictionary
    if options is Dictionary:
        effect = options.duplicate(true)
        effect["type"] = "enemyBlast"
        effect["color"] = effect.get("color", "#ff7043")
        effect["ttl"] = effect.get("ttl", 0.35)
    else:
        effect = {"type": "enemyBlast", "x": float(options), "y": y, "radius": radius,
            "color": "#ff7043", "ttl": ttl}
    effect["maxTtl"] = effect["ttl"]
    effects.append(effect)


func on_boss_wave_cleared() -> void:
    # Timed boss checkpoints clear reinforcements and every hostile projectile.
    enemies.clear()
    hostileProjectiles.clear()
    for id: String in DropsScript.roll_boss_drops(bossesDefeated):
        tempBackpack[id] = tempBackpack.get(id, 0) + 1
    if waveDirector.wave >= Config.CONFIG["waves"]["maxWave"]:
        on_final_wave_cleared()
    else:
        state = "extraction"


func on_final_wave_cleared() -> void:
    if _final_settled:
        return
    _final_settled = true
    _finish_run(true)


func open_shop() -> void:
    if state == "menu":
        state = "shop"


func open_storage() -> void:
    if state == "menu":
        state = "storage"


func back_to_menu() -> void:
    reset()


func buy_shop_item(attr_id: String) -> bool:
    if state != "shop":
        return false
    var bought: bool = ShopScript.try_buy(save, attr_id)
    if bought:
        MetaSave.persist_save(save)
    return bought


func sell_storage_item(item_id: String) -> int:
    if state != "storage" or not MetaItemsScript.META_ITEMS.has(item_id):
        return 0
    var count: int = save["storage"].get(item_id, 0)
    if count <= 0:
        return 0
    var gained: int = count * MetaItemsScript.META_ITEMS[item_id]["sellPrice"]
    save["storage"][item_id] = 0
    save["darkCrystals"] += gained
    MetaSave.persist_save(save)
    return gained


func sell_all_storage() -> int:
    if state != "storage":
        return 0
    var gained: int = 0
    for item: Dictionary in MetaItemsScript.META_ITEM_LIST:
        var count: int = save["storage"].get(item["id"], 0)
        if count > 0:
            save["storage"][item["id"]] = 0
            gained += count * item["sellPrice"]
    if gained > 0:
        save["darkCrystals"] += gained
        MetaSave.persist_save(save)
    return gained


func queue_task_reward(offers: Array) -> void:
    if not offers.is_empty():
        pendingTaskRewards.append(offers)


func extract() -> void:
    if state == "extraction":
        _finish_run(false)


func continue_deeper() -> void:
    if state != "extraction":
        return
    if waveDirector.wave >= Config.CONFIG["waves"]["maxWave"]:
        on_final_wave_cleared()
        return
    state = "playing"
    waveDirector.begin_rest()


func _finish_run(completed: bool) -> void:
    var settled_wave: int = waveDirector.wave
    var crystals: int = roundi(settled_wave * Config.CONFIG["meta"]["waveRewardMult"])
    save["darkCrystals"] += crystals
    var banked: Dictionary = tempBackpack.duplicate(true)
    for id: String in tempBackpack:
        save["storage"][id] = save["storage"].get(id, 0) + tempBackpack[id]
    tempBackpack = {"shard": 0, "essence": 0, "soulCrystal": 0}
    save["stats"]["extractions"] += 1
    if completed:
        save["stats"]["completions"] += 1
    save["stats"]["bestWave"] = maxi(save["stats"]["bestWave"], settled_wave)
    lastRunSummary = {"completed": completed, "wave": settled_wave, "kills": kills, "level": level,
        "bossesDefeated": bossesDefeated, "elapsed": elapsed, "darkCrystalsGained": crystals, "itemsBanked": banked}
    MetaSave.persist_save(save)
    state = "summary"


func _apply_death_loss() -> void:
    if _death_settled:
        return
    _death_settled = true
    lastDeathLoss = tempBackpack.duplicate(true)
    lastDeathReward = roundi(waveDirector.wave * Config.CONFIG["meta"]["waveRewardMult"] * Config.CONFIG["meta"]["deathRewardMult"])
    save["darkCrystals"] += lastDeathReward
    tempBackpack = {"shard": 0, "essence": 0, "soulCrystal": 0}
    MetaSave.persist_save(save)


func on_weapon_level_changed(weapon, previous_level: int) -> void:
    var evolution_level: int = 6 if previous_level < 6 and weapon.level >= 6 else (4 if previous_level < 4 and weapon.level >= 4 else 0)
    if evolution_level == 0:
        return
    var id: String = weapon.card["id"]
    var color: String = WEAPON_EVOLUTION_COLORS.get(id, "#fff176")
    var ultimate: bool = evolution_level == 6
    var duration: float = 1.8 if ultimate else 1.25
    effects.append({"type": "weaponEvolution", "weaponId": id, "evolutionLevel": evolution_level,
        "x": player.x, "y": player.y, "radius": 280.0 if ultimate else 190.0,
        "color": color, "ttl": duration, "maxTtl": duration})
    hitShake = maxf(hitShake, 0.48 if ultimate else 0.32)
    rareMessage = {"text": ("终极蜕变" if ultimate else "法器觉醒") + " · " + weapon.card["name"],
        "detail": CardsScript.weapon_level_benefit(id, evolution_level), "color": color,
        "ttl": 3.8 if ultimate else 3.0}


func has_synergy(id: String) -> bool:
    return synergies.is_active(id)


func get_weapon(id: String):
    for weapon in weapons:
        if weapon.card["id"] == id:
            return weapon
    return null


func record_synergy_trigger(id: String, amount: float = 1.0) -> void:
    if synergies.record_trigger(id, amount):
        effects.append({"type": "synergyTrigger", "synergyId": id, "x": player.x, "y": player.y,
            "radius": 82.0, "ttl": 0.5, "maxTtl": 0.5})
