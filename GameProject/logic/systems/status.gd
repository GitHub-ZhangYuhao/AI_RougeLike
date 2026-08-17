extends RefCounted
## ← js/systems/status.js：共享状态效果。

const DOT_TYPES: Array[String] = ["burn", "bleed", "poison"]


static func _normalize_dot_type(type: String) -> String:
    return "burn" if type == "blaze" else type


static func apply_dot(enemy, type: String, dps: float, duration: float) -> void:
    var normalized_type: String = _normalize_dot_type(type)
    var old: Dictionary = enemy.dots.get(normalized_type, {"dps": 0.0, "timer": 0.0})
    enemy.dots[normalized_type] = {"dps": maxf(old["dps"], dps), "timer": duration}


static func apply_slow(enemy, factor: float, duration: float) -> void:
    enemy.slowFactor = maxf(enemy.slowFactor, factor)
    enemy.slowTimer = maxf(enemy.slowTimer, duration)


static func apply_freeze(enemy, duration: float) -> void:
    enemy.frozenTimer = maxf(enemy.frozenTimer, duration)


static func has_dot(enemy, type: String) -> bool:
    var normalized_type: String = _normalize_dot_type(type)
    return enemy.dots.has(normalized_type) and enemy.dots[normalized_type]["timer"] > 0.0


static func tick_status(enemy, dt: float) -> float:
    var damage: float = 0.0
    for type: String in DOT_TYPES:
        if not enemy.dots.has(type):
            continue
        var dot: Dictionary = enemy.dots[type]
        dot["timer"] -= dt
        if dot["timer"] <= 0.0:
            enemy.dots.erase(type)
        else:
            damage += dot["dps"] * dt
            enemy.dots[type] = dot
    enemy.slowTimer -= dt
    enemy.frozenTimer -= dt
    return damage


static func speed_mult_of(enemy) -> float:
    if enemy.frozenTimer > 0.0:
        return 0.0
    if enemy.slowTimer > 0.0:
        return 1.0 - enemy.slowFactor
    return 1.0
