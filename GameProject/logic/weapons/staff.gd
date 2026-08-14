extends "res://logic/weapons/weapon_base.gd"
## ← js/weapons/staff.js：召唤槽、尸毒、自爆与百鬼夜行。

const BaseScript: GDScript = preload("res://logic/weapons/weapon_base.gd")

const POISON_DPS: float = 8.0
const POISON_DURATION: float = 3.0
const POISON_RADIUS: float = 50.0
const CORPSE_LIFE: float = 10.0
const REGULAR_CAP: int = 3
const CORPSE_CAP: int = 5
const TOTAL_CAP: int = 8
const CONVERT_CHANCE: float = 0.2
const PITY_KILLS: int = 10
const NIGHT_DAMAGE_MULT: float = 1.5
const NIGHT_SPEED_MULT: float = 1.3

const CARD: Dictionary = {"id": "staff", "kind": "weapon", "name": "死灵法杖", "maxLevel": 6, "levels": [
    {"damage": 7, "count": 1, "life": 6, "cd": 4, "speed": 170, "leash": 260},
    {"damage": 9, "count": 2, "life": 6.8, "cd": 3.6, "speed": 180, "leash": 260, "poison": true},
    {"damage": 12, "count": 2, "life": 7.5, "cd": 3.2, "speed": 190, "leash": 260, "poison": true},
    {"damage": 14, "count": 2, "life": 8.2, "cd": 2.8, "speed": 200, "leash": 260, "poison": true, "blast": true, "blastRadius": 85},
    {"damage": 17, "count": 3, "life": 9, "cd": 2.5, "speed": 210, "leash": 260, "poison": true, "blast": true, "blastRadius": 125},
    {"damage": 20, "count": 3, "life": 9.8, "cd": 2.2, "speed": 220, "leash": 280, "poison": true, "blast": true, "blastRadius": 125, "nightParade": true},
]}

var slots: Array = []
var corpses: Array = []
var blasts: Array = []
var last_kill_id: int = 0
var pity: int = 0
var guardian_wards: Array = []
var guardian_rotation_timer: float = 0.0
var guardian_cursor: int = 0


func update(dt: float, current_world) -> void:
    world = current_world
    var s: Dictionary = stats
    var regular_count: int = mini(REGULAR_CAP, s["count"])
    while slots.size() < regular_count:
        slots.append({"phase": "cd", "timer": 0.5 if slots.is_empty() else s["cd"], "summon": null})
    while slots.size() > regular_count:
        var removed: Dictionary = slots.pop_back()
        if removed["summon"] != null:
            _retire_summon(removed["summon"], s, current_world, s.get("blast", false))

    var enemy_in_leash: bool = _enemy_in_leash(current_world, s["leash"])
    for slot: Dictionary in slots:
        if slot["phase"] == "cd":
            slot["timer"] -= dt
            if slot["timer"] <= 0.0:
                if enemy_in_leash:
                    _deploy_summon(slot, s, current_world)
                else:
                    slot["phase"] = "ready"
                    slot["timer"] = 0.0
        elif slot["phase"] == "ready":
            if enemy_in_leash:
                _deploy_summon(slot, s, current_world)
        else:
            slot["timer"] -= dt
            if slot["timer"] <= 0.0:
                if slot["summon"] != null:
                    _retire_summon(slot["summon"], s, current_world, s.get("blast", false))
                slot["summon"] = null
                slot["phase"] = "cd"
                slot["timer"] = s["cd"]
    _sync_guardian_wards(dt, current_world)
    for slot: Dictionary in slots:
        if slot["summon"] != null and not slot["summon"]["dead"]:
            _update_summon(slot["summon"], current_world, s, dt)

    var log: Array = current_world.get("kill_log", current_world.get("killLog", []))
    for kill: Dictionary in log:
        if kill["id"] <= last_kill_id:
            continue
        last_kill_id = kill["id"]
        if not s.get("nightParade", false) or kill.get("noSummon", false):
            continue
        pity += 1
        if Rng.next() < CONVERT_CHANCE or pity >= PITY_KILLS:
            pity = 0
            spawn_corpse(kill["x"], kill["y"], s, current_world)

    for i in range(corpses.size() - 1, -1, -1):
        var summon: Dictionary = corpses[i]
        if summon["dead"]:
            _retire_summon(summon, s, current_world, true)
            corpses.remove_at(i)
            continue
        _update_summon(summon, current_world, s, dt)
        if summon["life"] <= 0.0:
            _retire_summon(summon, s, current_world, true)
            corpses.remove_at(i)

    if s.get("nightParade", false):
        var alive: int = 0
        for summon: Dictionary in current_world.summons:
            if not summon["dead"]:
                alive += 1
        if alive > 0:
            current_world.heal_player.call(minf(2.0, 1.0 + 0.5 * (alive - 1)) * dt)
    for blast: Dictionary in blasts:
        blast["t"] -= dt
    blasts = blasts.filter(func(blast: Dictionary) -> bool: return blast["t"] > 0.0)


func _enemy_in_leash(current_world, leash: float) -> bool:
    for enemy in current_world.enemies:
        if not enemy.dead and UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) <= leash * leash:
            return true
    return false


func _deploy_summon(slot: Dictionary, s: Dictionary, current_world) -> void:
    var summon: Dictionary = {
        "x": current_world.player.x + _rand_range(-24.0, 24.0),
        "y": current_world.player.y + _rand_range(-24.0, 24.0),
        "damage": s["damage"] * current_world.mods["damageMult"], "life": s["life"], "speed": s["speed"],
        "hitTimer": 0.0, "wander": Rng.next() * TAU, "dead": false, "corpse": false,
    }
    slot["summon"] = summon
    slot["phase"] = "active"
    slot["timer"] = s["life"]
    current_world.summons.append(summon)


func _update_summon(summon: Dictionary, current_world, s: Dictionary, dt: float) -> void:
    summon["life"] -= dt
    summon["hitTimer"] -= dt
    var night: bool = s.get("nightParade", false)
    summon["radius"] = 17.0 if night else (12.0 if summon.get("corpse", false) else 11.0)
    _update_ghostfire(summon, current_world)
    var target = null
    var best_d2: float = INF
    var commanded = null
    var commanded_d2: float = INF
    for enemy in current_world.enemies:
        if enemy.dead or UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) > s["leash"] * s["leash"]:
            continue
        var d2: float = UtilsScript.dist2(summon["x"], summon["y"], enemy.x, enemy.y)
        if d2 < best_d2:
            target = enemy
            best_d2 = d2
        if _has_synergy(current_world, "sword-staff-command") and enemy.synergyMarks.get("swordCommandUntil", -INF) > current_world.elapsed and d2 < commanded_d2:
            commanded = enemy
            commanded_d2 = d2
    if commanded != null:
        target = commanded
        best_d2 = commanded_d2
    var target_x: float
    var target_y: float
    if target != null:
        target_x = target.x
        target_y = target.y
    else:
        summon["wander"] += dt * 1.3
        target_x = current_world.player.x + cos(summon["wander"]) * 52.0
        target_y = current_world.player.y + sin(summon["wander"]) * 52.0
    var dx: float = target_x - summon["x"]
    var dy: float = target_y - summon["y"]
    var distance: float = maxf(0.0001, sqrt(dx * dx + dy * dy))
    var speed: float = summon["speed"] * (NIGHT_SPEED_MULT if night else 1.0)
    if distance > 6.0:
        summon["x"] += dx / distance * speed * dt
        summon["y"] += dy / distance * speed * dt
    var player_distance: float = sqrt(UtilsScript.dist2(summon["x"], summon["y"], current_world.player.x, current_world.player.y))
    if player_distance > s["leash"]:
        summon["x"] = current_world.player.x + (summon["x"] - current_world.player.x) / player_distance * s["leash"]
        summon["y"] = current_world.player.y + (summon["y"] - current_world.player.y) / player_distance * s["leash"]
    var reach: float = (22.0 if night else 14.0) + (target.radius if target != null else 0.0)
    if target != null and best_d2 <= reach * reach and summon["hitTimer"] <= 0.0:
        summon["hitTimer"] = 0.5
        current_world.damage_enemy.call(target, summon["damage"] * (NIGHT_DAMAGE_MULT if night else 1.0),
            {"sourceWeaponId": "staff", "sourceAction": "summon"})
        _share_guardian_slow(summon, target, current_world)
        if s.get("poison", false):
            if not target.dead:
                current_world.apply_dot.call(target, "poison", POISON_DPS, POISON_DURATION)
            for enemy in current_world.enemies:
                if enemy != target and not enemy.dead and UtilsScript.dist2(target.x, target.y, enemy.x, enemy.y) <= pow(POISON_RADIUS + enemy.radius, 2):
                    current_world.apply_dot.call(enemy, "poison", POISON_DPS, POISON_DURATION)


func _retire_summon(summon: Dictionary, s: Dictionary, current_world, should_detonate: bool) -> bool:
    if summon.get("staffRetired", false):
        return false
    summon["staffRetired"] = true
    _convert_corpse_fire(summon, current_world)
    _clear_guardian_state(summon)
    if should_detonate:
        detonate(summon, s, current_world)
    summon["dead"] = true
    return true


func detonate(summon: Dictionary, s: Dictionary, current_world) -> void:
    var radius: float = s.get("blastRadius", 70.0)
    BaseScript.hit_enemies_in_radius(current_world, summon["x"], summon["y"], radius,
        summon["damage"] * 2.0, Callable(), {"sourceWeaponId": "staff", "sourceAction": "summon", "noSummon": true})
    blasts.append({"x": summon["x"], "y": summon["y"], "maxR": radius, "t": 0.35})


func spawn_corpse(x: float, y: float, s: Dictionary, current_world) -> void:
    var regular_alive: int = 0
    for slot: Dictionary in slots:
        if slot["summon"] != null and not slot["summon"]["dead"]:
            regular_alive += 1
    while corpses.size() >= CORPSE_CAP or regular_alive + corpses.size() >= TOTAL_CAP:
        var oldest: Dictionary = corpses.pop_front()
        _retire_summon(oldest, s, current_world, true)
    var summon: Dictionary = {
        "x": x + _rand_range(-8.0, 8.0), "y": y + _rand_range(-8.0, 8.0),
        "damage": s["damage"] * current_world.mods["damageMult"], "life": CORPSE_LIFE,
        "speed": s["speed"], "hitTimer": 0.0, "wander": Rng.next() * TAU,
        "dead": false, "corpse": true,
    }
    corpses.append(summon)
    current_world.summons.append(summon)


func _alive_staff_summons() -> Array:
    var alive: Array = []
    for slot: Dictionary in slots:
        var summon = slot["summon"]
        if summon != null and not summon["dead"] and summon["life"] > 0.0 and not alive.has(summon):
            alive.append(summon)
    for summon: Dictionary in corpses:
        if not summon["dead"] and summon["life"] > 0.0 and not alive.has(summon):
            alive.append(summon)
    return alive


func _sync_guardian_wards(dt: float, current_world) -> void:
    var ring = current_world.get_weapon.call("ring") if _has_synergy(current_world, "ring-staff-guardian") else null
    var alive: Array = _alive_staff_summons()
    var cap: int = mini(2, mini(ring.stats["count"], alive.size())) if ring != null else 0
    if cap <= 0:
        _clear_guardian_wards(current_world)
        return
    guardian_rotation_timer -= dt
    var valid: bool = guardian_wards.size() == cap
    for ward: Dictionary in guardian_wards:
        valid = valid and alive.has(ward["summon"])
    if valid and guardian_rotation_timer > 0.0:
        return
    _clear_guardian_wards(current_world)
    var start: int = guardian_cursor % alive.size()
    for i in cap:
        var summon: Dictionary = alive[(start + i) % alive.size()]
        summon["guardianWardActive"] = true
        summon["guardianWardOwner"] = self
        guardian_wards.append({"summon": summon, "phase": (start + i) * PI * 0.73})
    guardian_cursor = (start + cap) % alive.size()
    guardian_rotation_timer = 2.4


func _clear_guardian_wards(current_world) -> void:
    for summon: Dictionary in current_world.summons:
        _clear_guardian_state(summon)
    guardian_wards.clear()
    guardian_rotation_timer = 0.0
    guardian_cursor = 0


func _clear_guardian_state(summon: Dictionary) -> void:
    if summon.get("guardianWardOwner") != self:
        return
    summon["guardianWardActive"] = false
    summon["guardianWardOwner"] = null
    summon["guardianPulseTimer"] = 0.0


func _share_guardian_slow(summon: Dictionary, target, current_world) -> void:
    if not summon.get("guardianWardActive", false) or not _has_synergy(current_world, "ring-staff-guardian"):
        return
    var ring = current_world.get_weapon.call("ring")
    if ring == null or not ring.stats.get("coldJade", false) or target.dead:
        return
    current_world.apply_slow.call(target, 0.35, 1.6)
    summon["guardianPulseTimer"] = 0.24
    current_world.record_synergy_trigger.call("ring-staff-guardian", 1)


func _update_ghostfire(summon: Dictionary, current_world) -> void:
    if not _has_synergy(current_world, "cloak-staff-ghostfire"):
        summon["ghostfireActive"] = false
        summon["ghostfireUntil"] = -INF
        return
    var cloak = current_world.get_weapon.call("cloak")
    if cloak != null and UtilsScript.dist2(summon["x"], summon["y"], current_world.player.x, current_world.player.y) <= pow(cloak.stats["radius"], 2):
        summon["ghostfireUntil"] = current_world.elapsed + 0.5
    var was_active: bool = summon.get("ghostfireActive", false)
    summon["ghostfireActive"] = summon.get("ghostfireUntil", -INF) > current_world.elapsed
    if not summon["ghostfireActive"]:
        return
    if not was_active:
        summon["ghostfireNextTickAt"] = current_world.elapsed
    if current_world.elapsed < summon.get("ghostfireNextTickAt", -INF):
        return
    summon["ghostfireNextTickAt"] = current_world.elapsed + 0.5
    var hits: int = 0
    for enemy in current_world.enemies:
        if not enemy.dead and current_world.elapsed >= enemy.ghostfireCdUntil and UtilsScript.dist2(summon["x"], summon["y"], enemy.x, enemy.y) <= pow(55.0 + enemy.radius, 2):
            enemy.ghostfireCdUntil = current_world.elapsed + 0.5
            current_world.damage_enemy.call(enemy, summon["damage"] * 0.35, {"sourceWeaponId": "staff", "sourceAction": "ghostfire", "synergyId": "cloak-staff-ghostfire", "noSynergy": true, "noSummon": true})
            hits += 1
    if hits > 0:
        current_world.record_synergy_trigger.call("cloak-staff-ghostfire", hits)


func _convert_corpse_fire(summon: Dictionary, current_world) -> bool:
    if summon.get("corpseFireConverted", false) or not _has_synergy(current_world, "trail-staff-corpse-fire"):
        return false
    var trail = current_world.get_weapon.call("trail")
    if trail == null or trail.find_furnace_at(summon["x"], summon["y"]) == null:
        return false
    var furnace = trail.charge_furnace_at(summon["x"], summon["y"], 1.5, current_world)
    if furnace == null:
        return false
    summon["corpseFireConverted"] = true
    current_world.record_synergy_trigger.call("trail-staff-corpse-fire", 1.5)
    current_world.effects.append({"type": "synergyArc", "x1": summon["x"], "y1": summon["y"], "x2": furnace["center"]["x"], "y2": furnace["center"]["y"], "color": "#d68cff", "ttl": 0.32, "maxTtl": 0.32})
    current_world.effects.append({"type": "synergyBurst", "style": "corpseFire", "x": furnace["center"]["x"], "y": furnace["center"]["y"], "radius": 42.0, "ttl": 0.32, "maxTtl": 0.32})
    return true


func get_guardian_wards() -> Array:
    return guardian_wards


func release_runtime_refs() -> void:
    for ward: Dictionary in guardian_wards:
        _clear_guardian_state(ward["summon"])
    guardian_wards.clear()


static func _rand_range(lo: float, hi: float) -> float:
    return lo + Rng.next() * (hi - lo)
