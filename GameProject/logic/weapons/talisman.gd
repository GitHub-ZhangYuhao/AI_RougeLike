extends "res://logic/weapons/weapon_base.gd"
## ← js/weapons/talisman.js：多发雷弹（count 指向最近的 count 个不同目标）、逐目标引雷计数与闪电链。

const ProjectileScript: GDScript = preload("res://logic/projectile.gd")
const BaseScript: GDScript = preload("res://logic/weapons/weapon_base.gd")

const CHAIN_RADIUS: float = 160.0
const THUNDER_AOE_RADIUS: float = 80.0

const CARD: Dictionary = {"id": "talisman", "kind": "weapon", "name": "雷符咒", "maxLevel": 6, "levels": [
    {"damage": 12, "interval": 1.0, "speed": 460, "range": 520, "count": 4},
    {"damage": 15, "interval": 0.95, "speed": 460, "range": 520, "count": 4, "thunder": true},
    {"damage": 19, "interval": 0.88, "speed": 460, "range": 520, "count": 4, "thunder": true},
    {"damage": 23, "interval": 0.81, "speed": 460, "range": 520, "count": 2, "thunder": true, "chain": true, "chainBounces": 2},
    {"damage": 27, "interval": 0.75, "speed": 460, "range": 520, "count": 2, "thunder": true, "chain": true, "chainBounces": 2},
    {"damage": 31, "interval": 0.70, "speed": 490, "range": 550, "count": 1, "thunder": true, "thunderFirst": true, "thunderAoE": true, "chain": true, "chainBounces": 3},
]}

var thunder_counters: Dictionary = {}
var attack_seq: int = 0
var first_done_seq: int = 0
var bolt_fx: Array = []
var chain_fx: Array = []


func update(dt: float, current_world) -> void:
    world = current_world
    _clean_counters(current_world.enemies)
    for fx: Dictionary in bolt_fx:
        fx["ttl"] -= dt
    for fx: Dictionary in chain_fx:
        fx["ttl"] -= dt
    bolt_fx = bolt_fx.filter(func(fx: Dictionary) -> bool: return fx["ttl"] > 0.0)
    chain_fx = chain_fx.filter(func(fx: Dictionary) -> bool: return fx["ttl"] > 0.0)

    timer -= dt
    if timer > 0.0:
        return
    var s: Dictionary = stats
    var targets: Array = BaseScript.nearest_n(current_world.enemies, current_world.player.x, current_world.player.y,
        int(s.get("count", 1)), s["range"] * s["range"])
    if targets.is_empty():
        timer = 0.0
        return
    timer = s["interval"]
    attack_seq += 1
    for target in targets:
        var angle: float = atan2(target.y - current_world.player.y, target.x - current_world.player.x)
        var projectile = ProjectileScript.new(current_world.player.x, current_world.player.y, angle, {
            "speed": s["speed"], "radius": 5.0, "damage": s["damage"] * current_world.mods["damageMult"],
            "lifetime": float(s["range"]) / float(s["speed"]) + 0.3,
            "damageOptions": {"sourceWeaponId": "talisman", "sourceAction": "projectile", "sourceTags": ["lightning", "projectile"]},
        })
        projectile.attackSeq = attack_seq
        projectile.onHit = Callable(self, "_on_projectile_hit").bind(projectile)
        current_world.projectiles.append(projectile)


func _clean_counters(enemies: Array) -> void:
    var alive_ids: Dictionary = {}
    for enemy in enemies:
        if not enemy.dead:
            alive_ids[enemy.get_instance_id()] = true
    for key in thunder_counters.keys():
        if not alive_ids.has(key):
            thunder_counters.erase(key)


func _on_projectile_hit(target, projectile) -> void:
    if world == null:
        return
    var s: Dictionary = stats
    var thunder_damage: float = projectile.damage * 1.5
    if s.get("thunderFirst", false) and projectile.attackSeq != first_done_seq:
        first_done_seq = projectile.attackSeq
        _strike_thunder(target, thunder_damage, world)
    elif s.get("thunder", false):
        var key: int = target.get_instance_id()
        var hits: int = thunder_counters.get(key, 0) + 1
        if hits >= 2:
            thunder_counters.erase(key)
            _strike_thunder(target, thunder_damage, world)
        else:
            thunder_counters[key] = hits
    if s.get("chain", false):
        _chain_lightning(target, projectile.damage * 0.5, world)


func _strike_thunder(target, damage: float, current_world) -> void:
    if stats.get("thunderAoE", false):
        BaseScript.hit_enemies_in_radius(current_world, target.x, target.y, THUNDER_AOE_RADIUS, damage, Callable(),
            {"sourceWeaponId": "talisman", "sourceAction": "thunder", "sourceTags": ["lightning", "thunder", "area"]})
    elif not target.dead:
        current_world.damage_enemy.call(target, damage, {"sourceWeaponId": "talisman", "sourceAction": "thunder", "sourceTags": ["lightning", "thunder"]})
    var aoe: bool = stats.get("thunderAoE", false)
    bolt_fx.append({"x": target.x, "y": target.y, "ttl": 0.18, "aoe": aoe,
        "radius": THUNDER_AOE_RADIUS if aoe else 0.0})


func _chain_lightning(origin, damage: float, current_world) -> void:
    var hit_set: Dictionary = {origin.get_instance_id(): true}
    var current = origin
    var bounces: int = stats.get("chainBounces", 2)
    var ring = current_world.get_weapon.call("ring") if _has_synergy(current_world, "talisman-ring-relay") else null
    var ring_positions: Array = ring.ring_positions(current_world) if ring != null else []
    var corpse_positions: Array = current_world.summons.filter(func(summon: Dictionary) -> bool: return not summon["dead"]) if _has_synergy(current_world, "talisman-staff-corpse-relay") else []
    var ring_used: bool = false
    var corpse_used: bool = false
    var hits: int = 0
    var steps: int = 0
    while hits < bounces and steps < bounces + 2:
        steps += 1
        var best = _nearest_chain_enemy(current, current_world.enemies, hit_set)
        if best == null:
            var relay = _best_relay(current, current_world.enemies, hit_set, ring_positions if not ring_used else [], corpse_positions if not corpse_used else [])
            if relay != null:
                var corpse_relay: bool = relay["type"] == "corpse"
                chain_fx.append({"x1": current.x if not current is Dictionary else current["x"], "y1": current.y if not current is Dictionary else current["y"], "x2": relay["position"]["x"], "y2": relay["position"]["y"], "ttl": 0.15, "relay": not corpse_relay, "corpseRelay": corpse_relay})
                current = relay["position"]
                if corpse_relay:
                    corpse_used = true
                    current_world.record_synergy_trigger.call("talisman-staff-corpse-relay", 1)
                else:
                    ring_used = true
                    current_world.record_synergy_trigger.call("talisman-ring-relay", 1)
                continue
        if best == null:
            break
        hit_set[best.get_instance_id()] = true
        current_world.damage_enemy.call(best, damage, {"sourceWeaponId": "talisman", "sourceAction": "chain", "sourceTags": ["lightning", "chain"]})
        chain_fx.append({"x1": current.x if not current is Dictionary else current["x"], "y1": current.y if not current is Dictionary else current["y"], "x2": best.x, "y2": best.y, "ttl": 0.15})
        current = best
        hits += 1


func _nearest_chain_enemy(current, enemies: Array, hit_set: Dictionary):
    var cx: float = current["x"] if current is Dictionary else current.x
    var cy: float = current["y"] if current is Dictionary else current.y
    var best = null
    var best_d2: float = CHAIN_RADIUS * CHAIN_RADIUS
    for enemy in enemies:
        if enemy.dead or hit_set.has(enemy.get_instance_id()):
            continue
        var d2: float = UtilsScript.dist2(cx, cy, enemy.x, enemy.y)
        if d2 <= best_d2:
            best = enemy
            best_d2 = d2
    return best


func _best_relay(current, enemies: Array, hit_set: Dictionary, rings: Array, corpses: Array):
    var cx: float = current["x"] if current is Dictionary else current.x
    var cy: float = current["y"] if current is Dictionary else current.y
    var result = null
    var best_score: float = INF
    for group: Dictionary in [{"type": "ring", "items": rings}, {"type": "corpse", "items": corpses}]:
        for position in group["items"]:
            var px: float = position["x"] if position is Dictionary else position.x
            var py: float = position["y"] if position is Dictionary else position.y
            var entry: float = UtilsScript.dist2(cx, cy, px, py)
            if entry > CHAIN_RADIUS * CHAIN_RADIUS:
                continue
            for enemy in enemies:
                if enemy.dead or hit_set.has(enemy.get_instance_id()):
                    continue
                var exit: float = UtilsScript.dist2(px, py, enemy.x, enemy.y)
                if exit <= CHAIN_RADIUS * CHAIN_RADIUS and sqrt(entry) + sqrt(exit) < best_score:
                    best_score = sqrt(entry) + sqrt(exit)
                    result = {"type": group["type"], "position": {"x": px, "y": py}}
    return result


func trigger_sword_thunder(target, current_world) -> bool:
    if target == null:
        return false
    var damage: float = stats["damage"] * current_world.mods["damageMult"] * 0.6
    if not target.dead:
        current_world.damage_enemy.call(target, damage, {"sourceWeaponId": "talisman", "sourceAction": "sword-thunder",
            "sourceTags": ["lightning", "thunder", "synergy"], "synergyId": "sword-talisman-mark", "noSynergy": true, "noSummon": true})
    bolt_fx.append({"x": target.x, "y": target.y, "ttl": 0.22, "aoe": false, "swordSynergy": true})
    current_world.record_synergy_trigger.call("sword-talisman-mark", damage)
    return true
