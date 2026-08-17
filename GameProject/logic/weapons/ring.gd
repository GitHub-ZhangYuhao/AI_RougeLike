extends "res://logic/weapons/weapon_base.gd"
## ← js/weapons/ring.js：旋转接触、血滴子、击杀狂暴与受击反制。


const RING_HIT_COOLDOWN: float = 0.34
const RING_RADIUS: float = 42.0
const CHARGED_BURST_RADIUS: float = 55.0
const FRENZY_KILL_STEP: int = 80

const CARD: Dictionary = {"id": "ring", "kind": "weapon", "name": "玉环", "maxLevel": 6, "levels": [
    {"damage": 12, "count": 2, "orbitRadius": 56, "orbitSpeed": 2.6},
    {"damage": 16, "count": 2, "orbitRadius": 66, "orbitSpeed": 2.8, "coldJade": true},
    {"damage": 20, "count": 3, "orbitRadius": 78, "orbitSpeed": 3.0, "coldJade": true},
    {"damage": 26, "count": 4, "orbitRadius": 92, "orbitSpeed": 3.3, "coldJade": true, "bloodDrop": true, "expandRadius": 80},
    {"damage": 32, "count": 5, "orbitRadius": 106, "orbitSpeed": 3.6, "coldJade": true, "bloodDrop": true, "expandRadius": 95},
    {"damage": 40, "count": 6, "orbitRadius": 120, "orbitSpeed": 4.0, "coldJade": true, "bloodDrop": true, "expandRadius": 110, "ultimate": true, "counterDamage": 200, "counterRadius": 300, "counterCd": 20},
]}

var angle: float = 0.0
var drop_t: float = 0.0
var expand_factor: float = 0.0
var expanding: bool = false
var frenzy_timer: float = 0.0
var next_frenzy_kills: int = FRENZY_KILL_STEP
var last_hurt_seen: float = -1.0
var counter_cd: float = 0.0
var counter_fx: Array = []
var burning_rings: Array[bool] = []
var ring_charge: Array = []


func ring_positions(current_world) -> Array:
    var s: Dictionary = stats
    var orbit_radius: float = s["orbitRadius"] + expand_factor * s.get("expandRadius", 0.0)
    var positions: Array = []
    for i in s["count"]:
        var current_angle: float = angle + i * TAU / s["count"]
        positions.append({"x": current_world.player.x + cos(current_angle) * orbit_radius,
            "y": current_world.player.y + sin(current_angle) * orbit_radius})
    return positions


func update(dt: float, current_world) -> void:
    world = current_world
    var s: Dictionary = stats
    angle += s["orbitSpeed"] * dt
    if s.get("ultimate", false):
        frenzy_timer = maxf(0.0, frenzy_timer - dt)
        counter_cd = maxf(0.0, counter_cd - dt)
        while current_world.kills >= next_frenzy_kills:
            next_frenzy_kills += FRENZY_KILL_STEP
            frenzy_timer = 3.0
            drop_t = 0.0
        var hurt_at: float = current_world.player.lastHurtAt
        if hurt_at != last_hurt_seen:
            last_hurt_seen = hurt_at
            if hurt_at >= 0.0 and counter_cd <= 0.0:
                _counter_nova(current_world, s)

    var frenzy: bool = s.get("ultimate", false) and frenzy_timer > 0.0
    expanding = false
    if s.get("bloodDrop", false):
        var speed_mult: float = 2.0 if frenzy else 1.0
        var expand_duration: float = 1.0 / speed_mult
        drop_t = fmod(drop_t + dt, 3.2)
        if drop_t < expand_duration:
            expand_factor = drop_t / expand_duration
            expanding = true
        elif drop_t < expand_duration * 2.0:
            expand_factor = 1.0 - (drop_t - expand_duration) / expand_duration
        else:
            expand_factor = 0.0
    else:
        expand_factor = 0.0

    var damage_mult: float = 2.0 if frenzy else (1.5 if expanding else 1.0)
    var damage: float = s["damage"] * current_world.mods["damageMult"] * damage_mult
    var positions: Array = ring_positions(current_world)
    var cloak = _sync_ring_synergies(current_world, positions)
    var burn_dps: float = (cloak.stats.get("burnDps", 12.0) if cloak != null else 12.0) * current_world.mods["damageMult"]
    for enemy in current_world.enemies:
        if enemy.dead or enemy.ringCd > 0.0:
            continue
        for ring_index in positions.size():
            var position: Dictionary = positions[ring_index]
            if UtilsScript.dist2(position["x"], position["y"], enemy.x, enemy.y) <= pow(RING_RADIUS + enemy.radius, 2):
                enemy.ringCd = RING_HIT_COOLDOWN
                current_world.damage_enemy.call(enemy, damage, {"sourceWeaponId": "ring", "sourceAction": "contact"})
                if burning_rings[ring_index] and not enemy.dead:
                    current_world.apply_dot.call(enemy, "burn", burn_dps, 2.0)
                    current_world.record_synergy_trigger.call("ring-cloak-burning", 1)
                if s.get("coldJade", false) and not enemy.dead:
                    current_world.apply_slow.call(enemy, 0.25, 1.2)
                _release_furnace_charge(ring_index, position, damage, current_world)
                break
    for fx: Dictionary in counter_fx:
        fx["t"] += dt
    counter_fx = counter_fx.filter(func(fx: Dictionary) -> bool: return fx["t"] < fx["dur"])


func _sync_ring_synergies(current_world, positions: Array):
    var cloak = current_world.get_weapon.call("cloak") if _has_synergy(current_world, "ring-cloak-burning") else null
    burning_rings.clear()
    for position: Dictionary in positions:
        burning_rings.append(cloak != null and UtilsScript.dist2(current_world.player.x, current_world.player.y, position["x"], position["y"]) <= pow(cloak.stats["radius"], 2))
    var trail = current_world.get_weapon.call("trail") if _has_synergy(current_world, "ring-trail-charge") else null
    if trail == null:
        ring_charge.clear()
        return cloak
    while ring_charge.size() < positions.size():
        ring_charge.append({"charged": false, "insideFurnace": null})
    ring_charge.resize(positions.size())
    for i in positions.size():
        var position: Dictionary = positions[i]
        var furnace = trail.find_furnace_at(position["x"], position["y"], RING_RADIUS)
        var state: Dictionary = ring_charge[i]
        if furnace != null:
            if state["insideFurnace"] == null and not state["charged"]:
                state["charged"] = true
                current_world.effects.append({"type": "synergyBurst", "style": "jadeCharge", "x": position["x"], "y": position["y"], "radius": 28.0, "ttl": 0.28, "maxTtl": 0.28})
            state["insideFurnace"] = furnace
        else:
            state["insideFurnace"] = null
    return cloak


func _release_furnace_charge(index: int, position: Dictionary, damage: float, current_world) -> void:
    if index >= ring_charge.size() or not ring_charge[index]["charged"] or ring_charge[index]["insideFurnace"] != null:
        return
    ring_charge[index]["charged"] = false
    var hits: int = release_charged_burst(position, damage, current_world)
    current_world.record_synergy_trigger.call("ring-trail-charge", maxi(1, hits))
    current_world.effects.append({"type": "synergyBurst", "style": "jadeCharge", "x": position["x"], "y": position["y"], "radius": CHARGED_BURST_RADIUS, "ttl": 0.3, "maxTtl": 0.3})


func _counter_nova(current_world, s: Dictionary) -> void:
    counter_cd = s.get("counterCd", 20.0)
    var radius: float = s.get("counterRadius", 240.0)
    var damage: float = s.get("counterDamage", 130.0) * current_world.mods["damageMult"]
    for enemy in current_world.enemies:
        if enemy.dead or UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) > pow(radius + enemy.radius, 2):
            continue
        current_world.apply_freeze.call(enemy, 1.5)
        current_world.damage_enemy.call(enemy, damage, {"sourceWeaponId": "ring", "sourceAction": "counter-nova"})
    counter_fx.append({"x": current_world.player.x, "y": current_world.player.y,
        "t": 0.0, "dur": 0.6, "r": radius})


# M4 丹炉联动稳定 hook：没有联动调用时完全无副作用。
func release_charged_burst(position: Dictionary, damage: float, current_world) -> int:
    var hits: int = 0
    for enemy in current_world.enemies:
        if enemy.dead or UtilsScript.dist2(position["x"], position["y"], enemy.x, enemy.y) > pow(CHARGED_BURST_RADIUS + enemy.radius, 2):
            continue
        current_world.damage_enemy.call(enemy, damage * 0.75, {"sourceWeaponId": "ring",
            "sourceAction": "furnace-charge-burst", "noSynergy": true, "noSummon": true})
        hits += 1
    return hits
