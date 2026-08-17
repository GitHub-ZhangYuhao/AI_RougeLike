extends "res://logic/weapons/weapon_base.gd"
## ← js/weapons/trail.js：移动铺火、闭环成炉与九转热域。


const LOOP_MIN_LENGTH: float = 260.0
const LOOP_MIN_AREA: float = 9000.0
const LOOP_CLOSE_RADIUS: float = 55.0
const LOOP_MIN_AGE: float = 1.2
const LOOP_COOLDOWN: float = 1.5
const FURNACE_TICK: float = 0.4
const FURNACE_FUEL: float = 9.0
const PATH_POINT_CAP: int = 180
const FURNACE_CAP: int = 6
const HOT_ZONE_CAP: int = 8

const CARD: Dictionary = {"id": "trail", "kind": "weapon", "name": "丹火", "maxLevel": 6, "levels": [
    {"damage": 7, "radius": 40, "life": 3.5, "dropInterval": 0.22},
    {"damage": 10, "radius": 44, "life": 4.5, "dropInterval": 0.22, "burn": true, "burnDps": 12},
    {"damage": 14, "radius": 48, "life": 5.5, "dropInterval": 0.18, "burn": true, "burnDps": 14},
    {"damage": 16, "radius": 52, "life": 7.0, "dropInterval": 0.18, "burn": true, "burnDps": 14, "furnace": true, "furnaceLife": 6, "furnaceAreaScale": 1.0, "furnacePull": 25.0, "furnaceTickMult": 1.25, "furnaceOpenMult": 6.0},
    {"damage": 21, "radius": 57, "life": 8.5, "dropInterval": 0.18, "burn": true, "burnDps": 14, "furnace": true, "enhancedFurnace": true, "furnaceLife": 7.5, "furnaceAreaScale": 1.15, "furnacePull": 35.0, "furnaceTickMult": 1.5, "furnaceOpenMult": 7.0},
    {"damage": 26, "radius": 62, "life": 10.0, "dropInterval": 0.18, "burn": true, "burnDps": 14, "furnace": true, "enhancedFurnace": true, "nineTurn": true, "furnaceLife": 9, "hotZoneLife": 5, "furnaceAreaScale": 1.15, "furnacePull": 35.0, "furnaceTickMult": 1.5, "furnaceOpenMult": 7.0},
]}

var path_points: Array = []
var furnaces: Array = []
var hot_zones: Array = []
var cut_zones: Array = []
var loop_cooldown: float = 0.0
var heal_timer: float = 0.0
var last_drop_at: float = -INF
var next_cut_id: int = 1


func update(dt: float, current_world) -> void:
    world = current_world
    var s: Dictionary = stats
    loop_cooldown = maxf(0.0, loop_cooldown - dt)
    _update_cut_zones(dt, current_world)
    _update_furnaces(dt, current_world, s)
    _update_hot_zones(dt, current_world, s)
    timer = maxf(0.0, timer - dt)
    if timer > 0.0 or not current_world.player.moving:
        return
    timer = s["dropInterval"]
    if current_world.elapsed - last_drop_at > 0.7:
        path_points.clear()
    last_drop_at = current_world.elapsed
    var trail: Dictionary = {
        "x": current_world.player.x, "y": current_world.player.y, "radius": s["radius"],
        "damage": s["damage"] * current_world.mods["damageMult"], "life": s["life"], "maxLife": s["life"],
        "tickTimer": 0.0, "tick": 0.4, "burnDps": s.get("burnDps", 0.0) * current_world.mods["damageMult"], "dead": false,
        "damageOptions": {"sourceWeaponId": "trail", "sourceAction": "trail"},
    }
    current_world.trails.append(trail)
    while current_world.trails.size() > 80:
        current_world.trails.pop_front()
    path_points.append({"x": trail["x"], "y": trail["y"], "at": current_world.elapsed, "trail": trail})
    if path_points.size() > PATH_POINT_CAP:
        path_points.pop_front()
    if s.get("furnace", false) and loop_cooldown <= 0.0:
        _try_create_furnace(current_world, s)


func _try_create_furnace(current_world, s: Dictionary) -> void:
    if path_points.is_empty():
        return
    var current: Dictionary = path_points.back()
    for i in range(path_points.size() - 2, -1, -1):
        var old: Dictionary = path_points[i]
        if current["at"] - old["at"] < LOOP_MIN_AGE:
            continue
        if UtilsScript.dist2(current["x"], current["y"], old["x"], old["y"]) > LOOP_CLOSE_RADIUS * LOOP_CLOSE_RADIUS:
            continue
        var points: Array = []
        for j in range(i, path_points.size()):
            points.append({"x": path_points[j]["x"], "y": path_points[j]["y"]})
        if points.size() < 4 or _path_length(points) < LOOP_MIN_LENGTH:
            continue
        var area: float = _polygon_area(points)
        if area < LOOP_MIN_AREA:
            continue
        for j in range(i, path_points.size()):
            path_points[j]["trail"]["dead"] = true
        path_points.resize(i)
        loop_cooldown = LOOP_COOLDOWN
        _create_furnace(points, area, current_world, s)
        return


func _create_furnace(points: Array, _area: float, current_world, s: Dictionary) -> void:
    var life: float = s.get("furnaceLife", 4.5)
    var center: Dictionary = _polygon_center(points)
    var zone_points: Array = _scaled_polygon(points, center, s.get("furnaceAreaScale", 1.0))
    var zone: Dictionary = {
        "points": zone_points, "center": center, "area": _polygon_area(zone_points), "life": life, "maxLife": life,
        "tickTimer": FURNACE_TICK, "damage": s["damage"] * current_world.mods["damageMult"],
        "pullSpeed": s.get("furnacePull", 25.0), "tickDamageMult": s.get("furnaceTickMult", 1.25),
        "openDamageMult": s.get("furnaceOpenMult", 6.0), "fuel": 0.0, "opens": 0,
        "maxOpens": 2 if s.get("enhancedFurnace", false) else 1,
        "openCooldown": 0.0, "openFx": 0.0, "openFxMax": 0.45, "openNineTurn": false,
        "eliteFuelAt": {}, "dead": false,
    }
    furnaces.append(zone)
    while furnaces.size() > FURNACE_CAP:
        furnaces.pop_front()
    _damage_zone(zone, current_world, zone["damage"] * 4.0, true, "furnace-ignite")
    _try_open(zone, current_world, s)


func _update_furnaces(dt: float, current_world, s: Dictionary) -> void:
    for zone: Dictionary in furnaces:
        zone["life"] -= dt
        zone["openCooldown"] = maxf(0.0, zone["openCooldown"] - dt)
        zone["openFx"] = maxf(0.0, zone.get("openFx", 0.0) - dt)
        if zone["life"] <= 0.0:
            zone["dead"] = true
            continue
        var cloak = current_world.get_weapon.call("cloak") if _has_synergy(current_world, "cloak-trail-core") else null
        var has_core_target: bool = false
        for enemy in current_world.enemies:
            if enemy.dead or not _circle_touches_polygon(enemy.x, enemy.y, enemy.radius, zone["points"]):
                continue
            var in_core: bool = cloak != null and UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) <= pow(cloak.stats["radius"] + enemy.radius, 2)
            has_core_target = has_core_target or in_core
            var dx: float = zone["center"]["x"] - enemy.x
            var dy: float = zone["center"]["y"] - enemy.y
            var distance: float = sqrt(dx * dx + dy * dy)
            if distance > 1.0:
                var step: float = minf(distance, (zone["pullSpeed"] + (65.0 if in_core else 0.0)) * dt)
                enemy.x += dx / distance * step
                enemy.y += dy / distance * step
        if not zone.has("coreTickTimer"):
            zone["coreTickTimer"] = 0.0
        if cloak != null:
            zone["coreTickTimer"] -= dt
            if has_core_target and zone["coreTickTimer"] <= 0.0:
                zone["coreTickTimer"] = 0.8
                var hits: int = 0
                for enemy in current_world.enemies:
                    if not enemy.dead and _circle_touches_polygon(enemy.x, enemy.y, enemy.radius, zone["points"]) and UtilsScript.dist2(current_world.player.x, current_world.player.y, enemy.x, enemy.y) <= pow(cloak.stats["radius"] + enemy.radius, 2):
                        current_world.damage_enemy.call(enemy, zone["damage"] * 1.5, {"sourceWeaponId": "trail", "sourceAction": "inner-outer-core", "synergyId": "cloak-trail-core", "noSynergy": true})
                        hits += 1
                if hits > 0:
                    current_world.record_synergy_trigger.call("cloak-trail-core", hits)
        else:
            zone["coreTickTimer"] = 0.0
        zone["tickTimer"] -= dt
        if zone["tickTimer"] <= 0.0:
            zone["tickTimer"] += FURNACE_TICK
            _damage_zone(zone, current_world, zone["damage"] * zone.get("tickDamageMult", 1.25), true, "furnace-tick")
            _try_open(zone, current_world, s)
    furnaces = furnaces.filter(func(zone: Dictionary) -> bool: return not zone["dead"])


func _damage_zone(zone: Dictionary, current_world, damage: float, grants_fuel: bool, action: String) -> void:
    for enemy in current_world.enemies:
        if enemy.dead or not _circle_touches_polygon(enemy.x, enemy.y, enemy.radius, zone["points"]):
            continue
        var was_alive: bool = not enemy.dead
        current_world.damage_enemy.call(enemy, damage, {"sourceWeaponId": "trail", "sourceAction": action})
        if not grants_fuel:
            continue
        if was_alive and enemy.dead:
            zone["fuel"] += 1.0
        elif enemy.rank == "elite" or enemy.rank == "boss":
            var key: int = enemy.get_instance_id()
            if current_world.elapsed >= zone["eliteFuelAt"].get(key, -INF):
                zone["fuel"] += 1.0
                zone["eliteFuelAt"][key] = current_world.elapsed + 1.0


func _try_open(zone: Dictionary, current_world, s: Dictionary) -> void:
    if zone["fuel"] < FURNACE_FUEL or zone["opens"] >= zone["maxOpens"] or zone["openCooldown"] > 0.0:
        return
    zone["fuel"] -= FURNACE_FUEL
    zone["opens"] += 1
    zone["openCooldown"] = 0.75
    zone["openFx"] = zone.get("openFxMax", 0.45)
    zone["openNineTurn"] = s.get("nineTurn", false)
    _damage_zone(zone, current_world, zone["damage"] * zone.get("openDamageMult", 6.0), false, "furnace-open")
    zone["life"] += 2.0
    zone["maxLife"] = maxf(zone["maxLife"], zone["life"])
    if s.get("nineTurn", false):
        hot_zones.append({
            "points": zone["points"].duplicate(true), "center": zone["center"].duplicate(true),
            "life": s.get("hotZoneLife", 3.0), "maxLife": s.get("hotZoneLife", 3.0),
            "tickTimer": 0.0, "damage": zone["damage"] * 1.25 * 1.5, "dead": false,
        })
        while hot_zones.size() > HOT_ZONE_CAP:
            hot_zones.pop_front()


func _update_hot_zones(dt: float, current_world, s: Dictionary) -> void:
    var player_inside: bool = false
    for zone: Dictionary in hot_zones:
        zone["life"] -= dt
        if zone["life"] <= 0.0:
            zone["dead"] = true
            continue
        if _circle_touches_polygon(current_world.player.x, current_world.player.y, current_world.player.radius, zone["points"]):
            player_inside = true
        zone["tickTimer"] -= dt
        if zone["tickTimer"] <= 0.0:
            zone["tickTimer"] += FURNACE_TICK
            for enemy in current_world.enemies:
                if not enemy.dead and _circle_touches_polygon(enemy.x, enemy.y, enemy.radius, zone["points"]):
                    current_world.damage_enemy.call(enemy, zone["damage"], {"sourceWeaponId": "trail", "sourceAction": "hot-zone"})
    hot_zones = hot_zones.filter(func(zone: Dictionary) -> bool: return not zone["dead"])
    if not s.get("nineTurn", false) or not player_inside:
        heal_timer = 0.0
        return
    if current_world.has("set_player_move_speed_bonus") and current_world.set_player_move_speed_bonus.is_valid():
        current_world.set_player_move_speed_bonus.call(self, 1.12, 0.12)
    heal_timer -= dt
    if heal_timer <= 0.0:
        current_world.heal_player.call(1.0)
        heal_timer = 0.5


# M4 联动稳定 hooks；M2 内可安全独立调用。
func find_furnace_at(x: float, y: float, radius: float = 0.0):
    var best = null
    var best_d2: float = INF
    for zone: Dictionary in furnaces:
        if zone["dead"] or zone["opens"] >= zone["maxOpens"] or not _circle_touches_polygon(x, y, radius, zone["points"]):
            continue
        var d2: float = UtilsScript.dist2(x, y, zone["center"]["x"], zone["center"]["y"])
        if d2 < best_d2:
            best = zone
            best_d2 = d2
    return best


func charge_furnace_at(x: float, y: float, amount: float, current_world):
    var zone = find_furnace_at(x, y)
    if zone == null:
        return null
    zone["fuel"] = minf(FURNACE_FUEL * 2.0, zone["fuel"] + amount)
    _try_open(zone, current_world, stats)
    return zone


func cut_furnaces_along_segment(x1: float, y1: float, x2: float, y2: float,
        damage: float, current_world, visited: Dictionary = {}) -> int:
    var distance: float = sqrt(UtilsScript.dist2(x1, y1, x2, y2))
    if distance <= 0.001:
        return 0
    var dx: float = (x2 - x1) / distance
    var dy: float = (y2 - y1) / distance
    var cuts: int = 0
    for zone: Dictionary in furnaces:
        if not zone.has("cutId"):
            zone["cutId"] = next_cut_id
            next_cut_id += 1
        var key: int = zone["cutId"]
        if zone["dead"] or visited.has(key) or not _segment_touches_polygon({"x": x1, "y": y1}, {"x": x2, "y": y2}, zone["points"]):
            continue
        visited[key] = true
        var half_length: float = 48.0
        for point: Dictionary in zone["points"]:
            half_length = maxf(half_length, sqrt(UtilsScript.dist2(point["x"], point["y"], zone["center"]["x"], zone["center"]["y"])) + 24.0)
        cut_zones.append({"x1": zone["center"]["x"] - dx * half_length, "y1": zone["center"]["y"] - dy * half_length, "x2": zone["center"]["x"] + dx * half_length, "y2": zone["center"]["y"] + dy * half_length, "width": 24.0, "damage": damage, "life": 2.2, "maxLife": 2.2, "tickTimer": 0.0, "dead": false})
        if cut_zones.size() > 8:
            cut_zones.pop_front()
        current_world.record_synergy_trigger.call("sword-trail-cut", 1)
        cuts += 1
    return cuts


func _update_cut_zones(dt: float, current_world) -> void:
    if not _has_synergy(current_world, "sword-trail-cut"):
        cut_zones.clear()
        return
    for zone: Dictionary in cut_zones:
        zone["life"] -= dt
        if zone["life"] <= 0.0:
            zone["dead"] = true
            continue
        zone["tickTimer"] -= dt
        if zone["tickTimer"] > 0.0:
            continue
        zone["tickTimer"] += 0.35
        for enemy in current_world.enemies:
            if not enemy.dead and _point_segment_dist2(enemy.x, enemy.y, {"x": zone["x1"], "y": zone["y1"]}, {"x": zone["x2"], "y": zone["y2"]}) <= pow(zone["width"] + enemy.radius, 2):
                current_world.damage_enemy.call(enemy, zone["damage"], {"sourceWeaponId": "sword", "sourceAction": "furnace-cut", "synergyId": "sword-trail-cut", "noSynergy": true, "noSummon": true})
    cut_zones = cut_zones.filter(func(zone: Dictionary) -> bool: return not zone["dead"])


static func _segment_touches_polygon(a: Dictionary, b: Dictionary, points: Array) -> bool:
    if _point_in_polygon(a["x"], a["y"], points) or _point_in_polygon(b["x"], b["y"], points):
        return true
    for i in points.size():
        if _segments_intersect(a, b, points[i], points[(i + 1) % points.size()]):
            return true
    return false


static func _segments_intersect(a: Dictionary, b: Dictionary, c: Dictionary, d: Dictionary) -> bool:
    var rx: float = b["x"] - a["x"]
    var ry: float = b["y"] - a["y"]
    var sx: float = d["x"] - c["x"]
    var sy: float = d["y"] - c["y"]
    var denominator: float = rx * sy - ry * sx
    if absf(denominator) <= 0.0001:
        return _point_segment_dist2(a["x"], a["y"], c, d) <= 0.25 or _point_segment_dist2(c["x"], c["y"], a, b) <= 0.25
    var qx: float = c["x"] - a["x"]
    var qy: float = c["y"] - a["y"]
    var t: float = (qx * sy - qy * sx) / denominator
    var u: float = (qx * ry - qy * rx) / denominator
    return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


static func update_trail(trail: Dictionary, current_world, dt: float) -> void:
    if trail["dead"]:
        return
    trail["life"] -= dt
    if trail["life"] <= 0.0:
        trail["dead"] = true
        return
    trail["tickTimer"] -= dt
    if trail["tickTimer"] <= 0.0:
        trail["tickTimer"] += trail["tick"]
        for enemy in current_world.enemies:
            if enemy.dead or UtilsScript.dist2(trail["x"], trail["y"], enemy.x, enemy.y) > pow(trail["radius"] + enemy.radius, 2):
                continue
            # 丹火与披风共用 burn，同类 DoT 只刷新持续时间。
            if trail["burnDps"] > 0.0:
                current_world.apply_dot.call(enemy, "burn", trail["burnDps"], 2.0)
            current_world.damage_enemy.call(enemy, trail["damage"], trail["damageOptions"])


static func _scaled_polygon(points: Array, center: Dictionary, scale: float) -> Array:
    if is_equal_approx(scale, 1.0):
        return points.duplicate(true)
    var scaled: Array = []
    for point: Dictionary in points:
        scaled.append({"x": center["x"] + (point["x"] - center["x"]) * scale,
            "y": center["y"] + (point["y"] - center["y"]) * scale})
    return scaled


static func _polygon_area(points: Array) -> float:
    var sum: float = 0.0
    for i in points.size():
        var a: Dictionary = points[i]
        var b: Dictionary = points[(i + 1) % points.size()]
        sum += a["x"] * b["y"] - b["x"] * a["y"]
    return absf(sum) * 0.5


static func _polygon_center(points: Array) -> Dictionary:
    var cross_sum: float = 0.0
    var x_sum: float = 0.0
    var y_sum: float = 0.0
    for i in points.size():
        var a: Dictionary = points[i]
        var b: Dictionary = points[(i + 1) % points.size()]
        var cross: float = a["x"] * b["y"] - b["x"] * a["y"]
        cross_sum += cross
        x_sum += (a["x"] + b["x"]) * cross
        y_sum += (a["y"] + b["y"]) * cross
    if absf(cross_sum) < 0.001:
        var center: Dictionary = {"x": 0.0, "y": 0.0}
        for point: Dictionary in points:
            center["x"] += point["x"]
            center["y"] += point["y"]
        center["x"] /= points.size()
        center["y"] /= points.size()
        return center
    return {"x": x_sum / (3.0 * cross_sum), "y": y_sum / (3.0 * cross_sum)}


static func _path_length(points: Array) -> float:
    var length: float = 0.0
    for i in range(1, points.size()):
        length += sqrt(UtilsScript.dist2(points[i - 1]["x"], points[i - 1]["y"], points[i]["x"], points[i]["y"]))
    if points.size() > 1:
        length += sqrt(UtilsScript.dist2(points[0]["x"], points[0]["y"], points.back()["x"], points.back()["y"]))
    return length


static func _point_in_polygon(x: float, y: float, points: Array) -> bool:
    var inside: bool = false
    var j: int = points.size() - 1
    for i in points.size():
        var a: Dictionary = points[i]
        var b: Dictionary = points[j]
        if (a["y"] > y) != (b["y"] > y) and x < (b["x"] - a["x"]) * (y - a["y"]) / (b["y"] - a["y"] + 0.00001) + a["x"]:
            inside = not inside
        j = i
    return inside


static func _point_segment_dist2(x: float, y: float, a: Dictionary, b: Dictionary) -> float:
    var dx: float = b["x"] - a["x"]
    var dy: float = b["y"] - a["y"]
    var length2: float = dx * dx + dy * dy
    if length2 <= 0.0001:
        return UtilsScript.dist2(x, y, a["x"], a["y"])
    var t: float = clampf(((x - a["x"]) * dx + (y - a["y"]) * dy) / length2, 0.0, 1.0)
    return UtilsScript.dist2(x, y, a["x"] + dx * t, a["y"] + dy * t)


static func _circle_touches_polygon(x: float, y: float, radius: float, points: Array) -> bool:
    if _point_in_polygon(x, y, points):
        return true
    for i in points.size():
        if _point_segment_dist2(x, y, points[i], points[(i + 1) % points.size()]) <= radius * radius:
            return true
    return false
