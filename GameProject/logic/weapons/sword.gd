extends "res://logic/weapons/weapon_base.gd"
## ← js/weapons/sword.js：近战、无限穿透剑气、拔剑斩与剑意飞剑。

const ProjectileScript: GDScript = preload("res://logic/projectile.gd")
const BaseScript: GDScript = preload("res://logic/weapons/weapon_base.gd")

const CARD: Dictionary = {
    "id": "sword", "kind": "weapon", "name": "道剑", "maxLevel": 6,
    "levels": [
        {"damage": 16, "meleeRange": 125, "interval": 1.15, "arc": 120},
        {"damage": 20, "projectile": true, "projectileRange": 520, "projectileSpeed": 500, "maxHits": INF, "interval": 1.08},
        {"damage": 26, "projectile": true, "projectileRange": 550, "projectileSpeed": 560, "maxHits": INF, "interval": 1.00},
        {"damage": 32, "projectile": true, "projectileRange": 570, "projectileSpeed": 580, "maxHits": INF, "interval": 0.94, "drawSlash": true, "ringRadius": 350, "ringBleedDps": 10},
        {"damage": 40, "projectile": true, "projectileRange": 600, "projectileSpeed": 620, "maxHits": INF, "interval": 0.87, "drawSlash": true, "ringRadius": 380, "ringBleedDps": 11},
        {"damage": 48, "projectile": true, "projectileRange": 640, "projectileSpeed": 660, "maxHits": INF, "interval": 0.80, "drawSlash": true, "ringRadius": 380, "ringBleedDps": 12, "swordIntent": true, "flyMax": 10, "flyInterval": 1.2, "flyRange": 260, "flyChain": 6, "flyChainRange": 240},
    ],
}

var attack_count: int = 0
var pending_ring: bool = false
var hit_carry: int = 0
var flying_swords: Array = []
var rings: Array = []
var flame_blade_ready_at: float = 0.0


func update(dt: float, current_world) -> void:
    world = current_world
    var s: Dictionary = stats
    _update_projectile_synergies(current_world, s)
    _update_flying_swords(dt, current_world, s)
    for ring: Dictionary in rings:
        ring["ttl"] -= dt
    rings = rings.filter(func(ring: Dictionary) -> bool: return ring["ttl"] > 0.0)
    if pending_ring:
        pending_ring = false
        _fire_ring(current_world, s)

    timer -= dt
    if timer > 0.0:
        return
    timer = s["interval"]
    var range_value: float = s.get("projectileRange", s.get("meleeRange", 125.0) * 1.8)
    var target = BaseScript.nearest_enemy(current_world.enemies, current_world.player.x, current_world.player.y, range_value * range_value)
    var angle: float = atan2(target.y - current_world.player.y, target.x - current_world.player.x) if target != null else current_world.player.facing
    var damage: float = s["damage"] * current_world.mods["damageMult"]
    if s.get("projectile", false):
        _fire_main_sword(current_world, s, angle, damage)
    elif _melee_slash(current_world, s, angle, damage):
        _count_main_hit(s)


func _fire_main_sword(current_world, s: Dictionary, angle: float, damage: float) -> void:
    var projectile = ProjectileScript.new(current_world.player.x, current_world.player.y, angle, {
        "speed": s["projectileSpeed"], "radius": 11.0, "damage": damage,
        "lifetime": float(s["projectileRange"]) / float(s["projectileSpeed"]), "maxHits": s["maxHits"],
        "damageOptions": {"sourceWeaponId": "sword", "sourceAction": "projectile", "sourceTags": ["projectile"]},
    })
    projectile.swordQi = true
    projectile.synergyPrevX = projectile.x
    projectile.synergyPrevY = projectile.y
    var hit_state: Dictionary = {"counted": false}
    projectile.onHit = Callable(self, "_on_main_projectile_hit").bind(projectile, hit_state, current_world)
    current_world.projectiles.append(projectile)


func _on_main_projectile_hit(enemy, _projectile, hit_state: Dictionary, current_world) -> void:
    var s: Dictionary = stats
    if not hit_state["counted"]:
        hit_state["counted"] = true
        _count_main_hit(s)
    _on_damage_hit(enemy, current_world, s, true, "projectile")
    _try_ring_return(_projectile, enemy, current_world)


func _melee_slash(current_world, s: Dictionary, angle: float, damage: float) -> bool:
    var hit_any: bool = false
    var half_arc: float = deg_to_rad(s["arc"]) * 0.5
    for enemy in current_world.enemies:
        if enemy.dead or UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) > pow(s["meleeRange"] + enemy.radius, 2):
            continue
        if UtilsScript.angle_diff(atan2(enemy.y - current_world.player.y, enemy.x - current_world.player.x), angle) <= half_arc:
            current_world.damage_enemy.call(enemy, damage, {"sourceWeaponId": "sword", "sourceAction": "melee"})
            _on_damage_hit(enemy, current_world, s, true, "melee")
            hit_any = true
    if hit_any:
        var slash_x: float = current_world.player.x + cos(angle) * s["meleeRange"] * 0.55
        var slash_y: float = current_world.player.y + sin(angle) * s["meleeRange"] * 0.55
        current_world.effects.append({"type": "slash", "x": slash_x, "y": slash_y,
            "range": s["meleeRange"] * 0.85, "angle": angle,
            "ttl": 0.22, "maxTtl": 0.22})
    return hit_any


func _count_main_hit(s: Dictionary) -> void:
    attack_count += 1
    if s.get("drawSlash", false) and attack_count % 3 == 0:
        pending_ring = true


func _fire_ring(current_world, s: Dictionary) -> void:
    var on_hit := func(enemy) -> void:
        if not enemy.dead:
            current_world.apply_dot.call(enemy, "bleed", s.get("ringBleedDps", 10) * current_world.mods["damageMult"], 2.5)
        _on_damage_hit(enemy, current_world, s, false, "ring")
    BaseScript.hit_enemies_in_radius(current_world, current_world.player.x, current_world.player.y,
        s["ringRadius"], s["damage"] * current_world.mods["damageMult"] * 2.5, on_hit,
        {"sourceWeaponId": "sword", "sourceAction": "ring"})
    rings.append({"x": current_world.player.x, "y": current_world.player.y, "r": s["ringRadius"], "ttl": 0.28})


func _on_damage_hit(enemy, current_world, s: Dictionary, count_intent: bool, action: String = "projectile") -> void:
    if _has_synergy(current_world, "sword-staff-command") and ["projectile", "flyingSword"].has(action):
        enemy.synergyMarks["swordCommandUntil"] = current_world.elapsed + 3.0
        current_world.record_synergy_trigger.call("sword-staff-command", 1)
        current_world.effects.append({"type": "synergyCommandMark", "x": enemy.x, "y": enemy.y, "ttl": 0.32, "maxTtl": 0.32})
    if _has_synergy(current_world, "sword-talisman-mark"):
        var talisman = current_world.get_weapon.call("talisman")
        if talisman != null:
            talisman.trigger_sword_thunder(enemy, current_world)
    if action == "melee" or action == "ring":
        _try_flame_blade(enemy, current_world, s)
    if count_intent and s.get("swordIntent", false):
        hit_carry += 1
        while hit_carry >= 10:
            hit_carry -= 10
            if flying_swords.size() < s["flyMax"]:
                _spawn_flying_sword(current_world)


func _try_flame_blade(enemy, current_world, s: Dictionary) -> void:
    if not _has_synergy(current_world, "sword-cloak-flame") or enemy.dead or enemy.dots.get("burn", {}).get("timer", 0.0) <= 0.0 or current_world.elapsed < flame_blade_ready_at:
        return
    flame_blade_ready_at = current_world.elapsed + 0.4
    var dx: float = enemy.x - current_world.player.x
    var dy: float = enemy.y - current_world.player.y
    var distance: float = sqrt(dx * dx + dy * dy)
    if distance > 0.001:
        dx /= distance
        dy /= distance
    else:
        dx = cos(current_world.player.facing)
        dy = sin(current_world.player.facing)
    var x2: float = enemy.x + dx * 145.0
    var y2: float = enemy.y + dy * 145.0
    var damage: float = s["damage"] * current_world.mods["damageMult"] * 0.4
    var hits: int = 0
    for target in current_world.enemies:
        if not target.dead and _point_segment_dist2(target.x, target.y, enemy.x, enemy.y, x2, y2) <= pow(34.0 + target.radius, 2):
            current_world.damage_enemy.call(target, damage, {"sourceWeaponId": "sword", "sourceAction": "flame-blade", "sourceTags": ["fire", "area"], "synergyId": "sword-cloak-flame", "noSynergy": true, "noSummon": true})
            hits += 1
    current_world.record_synergy_trigger.call("sword-cloak-flame", hits)
    current_world.effects.append({"type": "synergyFlameBlade", "x1": enemy.x, "y1": enemy.y, "x2": x2, "y2": y2, "width": 34.0, "ttl": 0.25, "maxTtl": 0.25})


func _update_projectile_synergies(current_world, s: Dictionary) -> void:
    var return_active: bool = _has_synergy(current_world, "sword-ring-return")
    var cut_active: bool = _has_synergy(current_world, "sword-trail-cut")
    var ring = current_world.get_weapon.call("ring") if return_active else null
    var positions: Array = ring.ring_positions(current_world) if ring != null else []
    var trail = current_world.get_weapon.call("trail") if cut_active else null
    for projectile in current_world.projectiles:
        if not projectile.swordQi or projectile.dead:
            continue
        var x1: float = projectile.synergyPrevX
        var y1: float = projectile.synergyPrevY
        if not return_active:
            projectile.ringReturnCharged = false
        elif not projectile.ringReturnCharged and not projectile.ringReturnUsed:
            for position: Dictionary in positions:
                if _point_segment_dist2(position["x"], position["y"], x1, y1, projectile.x, projectile.y) <= pow(52.0 + projectile.radius, 2):
                    projectile.ringReturnCharged = true
                    projectile.color = "#fff59d"
                    current_world.effects.append({"type": "synergyArc", "x1": position["x"], "y1": position["y"], "x2": projectile.x, "y2": projectile.y, "color": "#d1ff8a", "ttl": 0.18, "maxTtl": 0.18})
                    break
        if trail != null:
            trail.cut_furnaces_along_segment(x1, y1, projectile.x, projectile.y, s["damage"] * current_world.mods["damageMult"] * 0.45, current_world, projectile.furnaceCuts)
        elif not cut_active:
            projectile.furnaceCuts.clear()
        projectile.synergyPrevX = projectile.x
        projectile.synergyPrevY = projectile.y


func _try_ring_return(projectile, enemy, current_world) -> bool:
    if not projectile.ringReturnCharged or projectile.ringReturnUsed:
        return false
    projectile.ringReturnCharged = false
    projectile.ringReturnUsed = true
    var target = null
    var best_d2: float = 360.0 * 360.0
    for candidate in current_world.enemies:
        if candidate.dead or candidate == enemy:
            continue
        var d2: float = UtilsScript.dist2(projectile.x, projectile.y, candidate.x, candidate.y)
        if d2 < best_d2:
            target = candidate
            best_d2 = d2
    var dx: float = target.x - projectile.x if target != null else -projectile.vx
    var dy: float = target.y - projectile.y if target != null else -projectile.vy
    var distance: float = maxf(0.0001, sqrt(dx * dx + dy * dy))
    projectile.vx = dx / distance * projectile.speed
    projectile.vy = dy / distance * projectile.speed
    projectile.angle = atan2(dy, dx)
    projectile.hitSet = {enemy.get_instance_id(): true}
    projectile.hitCount = 0
    projectile.lifetime = maxf(projectile.lifetime, 0.8)
    projectile.color = "#c6ff70"
    current_world.record_synergy_trigger.call("sword-ring-return", 1)
    return true


static func _point_segment_dist2(x: float, y: float, x1: float, y1: float, x2: float, y2: float) -> float:
    var dx: float = x2 - x1
    var dy: float = y2 - y1
    var length2: float = dx * dx + dy * dy
    if length2 <= 0.0001:
        return UtilsScript.dist2(x, y, x1, y1)
    var t: float = clampf(((x - x1) * dx + (y - y1) * dy) / length2, 0.0, 1.0)
    return UtilsScript.dist2(x, y, x1 + dx * t, y1 + dy * t)


func _spawn_flying_sword(current_world) -> void:
    flying_swords.append({
        "x": current_world.player.x, "y": current_world.player.y, "angle": Rng.next() * TAU,
        "orbit_r": 48.0 + (flying_swords.size() % 3) * 12.0, "ttl": 15.0, "atk_timer": 0.4,
        "state": "orbit", "target": null, "dir_x": 0.0, "dir_y": 1.0, "travel": 0.0,
        "chains": 0, "leg_travel": 0.0, "leg_length": 0.0, "visited": {}, "hit_set": {},
    })


func _update_flying_swords(dt: float, current_world, s: Dictionary) -> void:
    if flying_swords.is_empty():
        return
    var px: float = current_world.player.x
    var py: float = current_world.player.y
    var fly_damage: float = s["damage"] * current_world.mods["damageMult"] * 0.3
    for flying: Dictionary in flying_swords:
        flying["ttl"] -= dt
        flying["atk_timer"] -= dt
        if flying["ttl"] <= 0.0:
            continue
        if flying["state"] == "orbit":
            flying["angle"] += dt * 2.4
            var tx: float = px + cos(flying["angle"]) * flying["orbit_r"]
            var ty: float = py + sin(flying["angle"]) * flying["orbit_r"]
            flying["x"] += (tx - flying["x"]) * minf(1.0, dt * 10.0)
            flying["y"] += (ty - flying["y"]) * minf(1.0, dt * 10.0)
            if flying["atk_timer"] <= 0.0:
                var target = BaseScript.nearest_enemy(current_world.enemies, px, py, s["flyRange"] * s["flyRange"])
                if target == null:
                    flying["atk_timer"] = 0.15
                else:
                    _start_flying_leg(flying, target, s["flyInterval"])
        elif flying["state"] == "strike":
            var target = flying["target"]
            if target != null and not target.dead:
                var dx: float = target.x - flying["x"]
                var dy: float = target.y - flying["y"]
                var distance: float = maxf(0.0001, sqrt(dx * dx + dy * dy))
                flying["dir_x"] = dx / distance
                flying["dir_y"] = dy / distance
            var step: float = 640.0 * dt
            flying["x"] += flying["dir_x"] * step
            flying["y"] += flying["dir_y"] * step
            flying["travel"] += step
            flying["leg_travel"] += step
            for enemy in current_world.enemies:
                var key: int = enemy.get_instance_id()
                if enemy.dead or flying["hit_set"].has(key):
                    continue
                if UtilsScript.dist2(flying["x"], flying["y"], enemy.x, enemy.y) <= pow(enemy.radius + 8.0, 2):
                    flying["hit_set"][key] = true
                    current_world.damage_enemy.call(enemy, fly_damage, {"sourceWeaponId": "sword", "sourceAction": "flying-sword"})
                    _on_damage_hit(enemy, current_world, s, false, "flyingSword")
                    if not enemy.dead:
                        current_world.apply_dot.call(enemy, "bleed", 9.0 * current_world.mods["damageMult"], 2.5)
            if flying["leg_travel"] >= flying["leg_length"] + 16.0:
                var next = _next_flying_target(flying, current_world, s)
                if next == null:
                    flying["state"] = "return"
                    flying["target"] = null
                else:
                    _start_flying_leg(flying, next, flying["atk_timer"], false)
            if flying["travel"] > 1600.0 or UtilsScript.dist2(flying["x"], flying["y"], px, py) > 460.0 * 460.0:
                flying["state"] = "return"
                flying["target"] = null
        else:
            var tx: float = px + cos(flying["angle"]) * flying["orbit_r"]
            var ty: float = py + sin(flying["angle"]) * flying["orbit_r"]
            var dx: float = tx - flying["x"]
            var dy: float = ty - flying["y"]
            var distance: float = maxf(0.0001, sqrt(dx * dx + dy * dy))
            var step: float = 700.0 * dt
            if distance <= step:
                flying["x"] = tx
                flying["y"] = ty
                flying["state"] = "orbit"
            else:
                flying["x"] += dx / distance * step
                flying["y"] += dy / distance * step
    flying_swords = flying_swords.filter(func(flying: Dictionary) -> bool: return flying["ttl"] > 0.0)


func _start_flying_leg(flying: Dictionary, target, attack_timer: float, first: bool = true) -> void:
    flying["state"] = "strike"
    flying["target"] = target
    if first:
        flying["chains"] = 1
        flying["travel"] = 0.0
        flying["visited"] = {}
        flying["atk_timer"] = attack_timer
    else:
        flying["chains"] += 1
    flying["visited"][target.get_instance_id()] = true
    flying["hit_set"] = {}
    flying["leg_travel"] = 0.0
    var dx: float = target.x - flying["x"]
    var dy: float = target.y - flying["y"]
    flying["leg_length"] = maxf(48.0, sqrt(dx * dx + dy * dy))
    var distance: float = maxf(0.0001, flying["leg_length"])
    flying["dir_x"] = dx / distance
    flying["dir_y"] = dy / distance


func _next_flying_target(flying: Dictionary, current_world, s: Dictionary):
    if flying["chains"] >= s.get("flyChain", 1):
        return null
    var best = null
    var best_d2: float = pow(s.get("flyChainRange", 240), 2)
    for enemy in current_world.enemies:
        if enemy.dead or flying["visited"].has(enemy.get_instance_id()):
            continue
        var d2: float = UtilsScript.dist2(flying["x"], flying["y"], enemy.x, enemy.y)
        if d2 < best_d2:
            best = enemy
            best_d2 = d2
    if best != null:
        return best
    for enemy in current_world.enemies:
        if enemy.dead or enemy == flying["target"]:
            continue
        var d2: float = UtilsScript.dist2(flying["x"], flying["y"], enemy.x, enemy.y)
        if d2 < best_d2:
            best = enemy
            best_d2 = d2
    return best if best != null else flying["target"]
