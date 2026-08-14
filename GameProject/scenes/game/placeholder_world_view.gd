extends Node2D

const ENEMY_COLORS: Dictionary = {
    "chaser": Color("d95d55"),
    "enhancedChaser": Color("b83a2f"),
    "charger": Color("ef7d32"),
    "ranged": Color("9c5cc4"),
    "bomber": Color("d9a620"),
    "shield": Color("607d8b"),
    "boss": Color("6840a8"),
}
const ENEMY_LABELS: Dictionary = {
    "chaser": "追",
    "enhancedChaser": "强",
    "charger": "冲",
    "ranged": "远",
    "bomber": "爆",
    "shield": "盾",
    "boss": "王",
}
const WEAPON_COLORS: Dictionary = {
    "sword": Color("c5f3ff"),
    "talisman": Color("ffe066"),
    "cloak": Color("ff7043"),
    "trail": Color("ff5722"),
    "ring": Color("b7e778"),
    "staff": Color("b388ff"),
}

var run = null


func bind_run(game_run) -> void:
    run = game_run
    queue_redraw()


func refresh() -> void:
    queue_redraw()


func _draw() -> void:
    if run == null:
        return
    _draw_tasks()
    _draw_weapon_zones()
    _draw_trails()
    _draw_gems()
    _draw_pickups()
    _draw_enemies()
    _draw_summons()
    _draw_player_projectiles()
    _draw_hostile_projectiles()
    _draw_effects()


func _draw_tasks() -> void:
    if run.taskDirector == null or run.taskDirector.current == null:
        return
    var task: Dictionary = run.taskDirector.current
    if task["state"] == "offered":
        _draw_marker(_point(task["beacon"]), Config.CONFIG["tasks"]["beaconRadius"], Color("4dd0e1"), "任务")
        return
    if task["state"] != "active":
        return
    var payload: Dictionary = task["payload"]
    match task["type"]:
        "guard": _draw_marker(_point(payload["center"]), payload["radius"], Color("66bb6a"), "守卫")
        "delivery": _draw_marker(_point(payload["destination"]), Config.CONFIG["tasks"]["delivery"]["destinationRadius"], Color("42a5f5"), "护送")


func _draw_marker(position: Vector2, radius: float, color: Color, label: String) -> void:
    draw_circle(position, radius, Color(color, 0.08))
    draw_arc(position, radius, 0.0, TAU, 48, Color(color, 0.9), 3.0)
    draw_arc(position, radius * 0.72, 0.0, TAU, 32, Color(color, 0.35), 1.0)
    draw_string(ThemeDB.fallback_font, position + Vector2(-34.0, -radius - 10.0), label,
        HORIZONTAL_ALIGNMENT_CENTER, 68.0, 14, color)


func _draw_weapon_zones() -> void:
    for weapon in run.weapons:
        var id: String = weapon.card["id"]
        if id == "cloak":
            var radius: float = weapon.stats["radius"]
            draw_circle(Vector2(run.player.x, run.player.y), radius, Color(1.0, 0.22, 0.08, 0.035))
            draw_arc(Vector2(run.player.x, run.player.y), radius, 0.0, TAU, 64, Color(1.0, 0.36, 0.16, 0.38), 2.0)
            for shock: Dictionary in weapon.shocks:
                var progress: float = clampf(shock["t"] / shock["ttl"], 0.0, 1.0)
                draw_arc(Vector2(shock["x"], shock["y"]), shock["max_r"] * progress, 0.0, TAU, 64,
                    Color(1.0, 0.55, 0.2, 1.0 - progress), 4.0)
        elif id == "ring":
            var stats: Dictionary = weapon.stats
            var orbit_radius: float = stats["orbitRadius"] + weapon.expand_factor * stats.get("expandRadius", 0.0)
            for i in stats["count"]:
                var angle: float = weapon.angle + i * TAU / stats["count"]
                var position := Vector2(run.player.x + cos(angle) * orbit_radius, run.player.y + sin(angle) * orbit_radius)
                draw_circle(position, 9.0, Color("d8f59b"))
                draw_arc(position, 13.0, 0.0, TAU, 20, Color("668c45"), 2.0)
        elif id == "trail":
            for zone: Dictionary in weapon.furnaces:
                _draw_zone(zone, Color(1.0, 0.2, 0.04, 0.2), Color("ff7043"))
            for zone: Dictionary in weapon.hot_zones:
                _draw_zone(zone, Color(1.0, 0.65, 0.12, 0.15), Color("ffca28"))
            for zone: Dictionary in weapon.cut_zones:
                var alpha: float = clampf(zone["life"] / zone["maxLife"], 0.0, 1.0)
                draw_line(Vector2(zone["x1"], zone["y1"]), Vector2(zone["x2"], zone["y2"]),
                    Color(1.0, 0.35, 0.08, alpha), zone["width"])


func _draw_zone(zone: Dictionary, fill: Color, outline: Color) -> void:
    var points := PackedVector2Array()
    for point: Dictionary in zone["points"]:
        points.append(_point(point))
    if points.size() < 3:
        return
    var alpha: float = clampf(zone["life"] / zone["maxLife"], 0.0, 1.0)
    draw_colored_polygon(points, Color(fill, fill.a * alpha))
    for i in points.size():
        draw_line(points[i], points[(i + 1) % points.size()], Color(outline, alpha), 3.0)


func _draw_trails() -> void:
    for trail: Dictionary in run.trails:
        if trail["dead"]:
            continue
        var alpha: float = clampf(trail["life"] / trail["maxLife"], 0.0, 1.0)
        var position := Vector2(trail["x"], trail["y"])
        draw_circle(position, trail["radius"], Color(1.0, 0.18, 0.02, 0.07 * alpha))
        draw_arc(position, trail["radius"], 0.0, TAU, 24, Color(1.0, 0.35, 0.08, 0.35 * alpha), 1.5)


func _draw_gems() -> void:
    for gem: Dictionary in run.gems:
        if gem["dead"]:
            continue
        var position := Vector2(gem["x"], gem["y"])
        var color := Color(gem["color"])
        var diamond := PackedVector2Array([
            position + Vector2(0.0, -7.0), position + Vector2(5.0, 0.0),
            position + Vector2(0.0, 7.0), position + Vector2(-5.0, 0.0),
        ])
        draw_colored_polygon(diamond, color)
        if gem["magnetized"]:
            draw_arc(position, 10.0, 0.0, TAU, 16, Color(color, 0.55), 1.5)


func _draw_pickups() -> void:
    for pickup: Dictionary in run.pickups:
        if pickup.get("dead", false):
            continue
        var position := Vector2(pickup["x"], pickup["y"])
        if pickup.get("kind") == "rare":
            var color := _rare_color(pickup.get("itemId", ""))
            draw_colored_polygon(_regular_polygon(position, 11.0, 6, PI / 6.0), color)
            draw_arc(position, 15.0, 0.0, TAU, 24, Color(color, 0.55), 2.0)
        else:
            draw_circle(position, 10.0, Color("ef9a9a"))
            draw_rect(Rect2(position - Vector2(2.0, 7.0), Vector2(4.0, 14.0)), Color.WHITE)
            draw_rect(Rect2(position - Vector2(7.0, 2.0), Vector2(14.0, 4.0)), Color.WHITE)


func _draw_enemies() -> void:
    for enemy in run.enemies:
        if enemy.dead:
            continue
        _draw_enemy(enemy)


func _draw_enemy(enemy) -> void:
    var position := Vector2(enemy.x, enemy.y)
    var radius: float = maxf(enemy.radius, 10.0)
    var color: Color = ENEMY_COLORS.get(enemy.type, Color("d95d55"))
    if enemy.frozenTimer > 0.0:
        color = Color("81d4fa")
    elif enemy.hitFlash > 0.0:
        color = Color.WHITE
    draw_circle(position + Vector2(0.0, radius * 0.55), radius * 0.9, Color(0.06, 0.05, 0.07, 0.3))
    match enemy.type:
        "enhancedChaser": draw_colored_polygon(_regular_polygon(position, radius, 4, PI / 4.0), color)
        "charger": draw_colored_polygon(PackedVector2Array([
            position + Vector2(radius, 0.0), position + Vector2(-radius * 0.8, -radius * 0.8),
            position + Vector2(-radius * 0.35, 0.0), position + Vector2(-radius * 0.8, radius * 0.8),
        ]), color)
        "ranged":
            draw_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
            draw_circle(position, radius * 0.35, Color("f3e5f5"))
        "bomber":
            draw_colored_polygon(_regular_polygon(position, radius, 6, PI / 6.0), color)
            draw_line(position - Vector2(radius * 0.55, 0.0), position + Vector2(radius * 0.55, 0.0), Color("4e342e"), 2.0)
            draw_line(position - Vector2(0.0, radius * 0.55), position + Vector2(0.0, radius * 0.55), Color("4e342e"), 2.0)
        "shield":
            draw_circle(position, radius, color)
            draw_arc(position, radius + 5.0, -PI * 0.75, PI * 0.75, 20, Color("cfd8dc"), 4.0)
        "boss":
            draw_colored_polygon(_regular_polygon(position, radius, 8, PI / 8.0), color)
            draw_arc(position, radius + 8.0, 0.0, TAU, 32, Color("ffd54f"), 4.0)
        _: draw_circle(position, radius, color)
    var label: String = ENEMY_LABELS.get(enemy.type, "敌")
    draw_string(ThemeDB.fallback_font, position + Vector2(-radius, 4.0), label,
        HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 11, Color.WHITE)
    if enemy.rank == "elite":
        draw_arc(position, radius + 5.0, 0.0, TAU, 24, Color("ffd54f"), 3.0)
    if enemy.slowTimer > 0.0:
        draw_arc(position, radius + 9.0, 0.0, TAU, 24, Color("80cbc4"), 2.0)
    if not enemy.dots.is_empty():
        draw_circle(position + Vector2(radius, -radius), 4.0, Color("ff7043"))
    if enemy.taskRole != null:
        draw_colored_polygon(PackedVector2Array([
            position + Vector2(0.0, -radius - 13.0), position + Vector2(-6.0, -radius - 23.0),
            position + Vector2(6.0, -radius - 23.0),
        ]), Color("4dd0e1"))
    if enemy.hp < enemy.maxHp or enemy.rank == "elite" or enemy.rank == "boss":
        var width: float = maxf(30.0, radius * 2.2)
        var ratio: float = clampf(enemy.hp / enemy.maxHp, 0.0, 1.0)
        var top_left := position + Vector2(-width * 0.5, -radius - 10.0)
        draw_rect(Rect2(top_left, Vector2(width, 4.0)), Color(0.05, 0.04, 0.06, 0.75))
        draw_rect(Rect2(top_left, Vector2(width * ratio, 4.0)), Color("66bb6a") if ratio > 0.35 else Color("ef5350"))


func _draw_summons() -> void:
    for summon: Dictionary in run.summons:
        if summon.get("dead", false):
            continue
        var position := Vector2(summon["x"], summon["y"])
        var radius: float = summon.get("radius", 11.0)
        var color := Color("7e57c2") if summon.get("corpse", false) else Color("b388ff")
        draw_circle(position + Vector2(0.0, radius * 0.55), radius * 0.9, Color(0.06, 0.05, 0.07, 0.28))
        draw_colored_polygon(_regular_polygon(position, radius, 5, -PI * 0.5), color)
        draw_circle(position + Vector2(-3.5, -2.0), 1.5, Color.WHITE)
        draw_circle(position + Vector2(3.5, -2.0), 1.5, Color.WHITE)
        if summon.get("guardianWardActive", false):
            draw_arc(position, radius + 6.0, 0.0, TAU, 24, Color("d8f59b"), 3.0)
        if summon.get("ghostfireActive", false):
            draw_arc(position, radius + 10.0, 0.0, TAU, 24, Color("ff7043"), 2.0)


func _draw_player_projectiles() -> void:
    for projectile in run.projectiles:
        if projectile.dead:
            continue
        var position := Vector2(projectile.x, projectile.y)
        var source: String = projectile.damageOptions.get("sourceWeaponId", "")
        var color: Color = Color(projectile.color) if not projectile.color.is_empty() else WEAPON_COLORS.get(source, Color("e0f7fa"))
        var velocity := Vector2(projectile.vx, projectile.vy)
        var direction := velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT.rotated(projectile.angle)
        draw_line(position - direction * 16.0, position, Color(color, 0.5), maxf(2.0, projectile.radius * 0.7))
        if projectile.swordQi:
            draw_colored_polygon(_regular_polygon(position, maxf(6.0, projectile.radius), 4, projectile.angle), color)
        else:
            draw_circle(position, maxf(4.0, projectile.radius), color)


func _draw_hostile_projectiles() -> void:
    for projectile in run.hostileProjectiles:
        if projectile.dead:
            continue
        var position := Vector2(projectile.x, projectile.y)
        draw_circle(position, projectile.radius + 2.0, Color("ff7043"))
        draw_arc(position, projectile.radius + 5.0, 0.0, TAU, 16, Color("ffcc80"), 2.0)


func _draw_effects() -> void:
    for effect: Dictionary in run.effects:
        var ttl: float = effect.get("ttl", 0.0)
        var max_ttl: float = maxf(effect.get("maxTtl", ttl), 0.0001)
        var alpha: float = clampf(ttl / max_ttl, 0.0, 1.0)
        match effect.get("type", ""):
            "synergyArc":
                draw_line(Vector2(effect["x1"], effect["y1"]), Vector2(effect["x2"], effect["y2"]), Color(effect.get("color", "80deea"), alpha), 3.0)
            "synergyFlameBlade":
                draw_line(Vector2(effect["x1"], effect["y1"]), Vector2(effect["x2"], effect["y2"]), Color(1.0, 0.25, 0.05, alpha), effect.get("width", 20.0))
            "synergyCommandMark":
                var position := Vector2(effect["x"], effect["y"] - 24.0)
                draw_colored_polygon(_regular_polygon(position, 10.0, 4, PI / 4.0), Color(0.75, 0.5, 1.0, alpha))
            "slash":
                draw_arc(Vector2(effect["x"], effect["y"]), effect.get("range", 50.0), effect.get("angle", 0.0) - effect.get("arc", 1.0) * 0.5,
                    effect.get("angle", 0.0) + effect.get("arc", 1.0) * 0.5, 20, Color(0.88, 0.97, 1.0, alpha), 5.0)
            _:
                if effect.has("x") and effect.has("y") and effect.has("radius"):
                    draw_arc(Vector2(effect["x"], effect["y"]), effect["radius"], 0.0, TAU, 32,
                        Color(effect.get("color", "ff8a50"), alpha), 3.0)


func _rare_color(item_id: String) -> Color:
    match item_id:
        "warRune": return Color("ffca28")
        "bloodJade": return Color("ef5350")
        "magnetCore": return Color("40c4ff")
        "spiritBook": return Color("b388ff")
        "windFeather": return Color("69f0ae")
        _: return Color("ffd54f")


func _regular_polygon(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in sides:
        var angle: float = rotation + i * TAU / sides
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    return points


func _point(value: Dictionary) -> Vector2:
    return Vector2(value["x"], value["y"])
