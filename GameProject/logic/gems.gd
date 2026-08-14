extends RefCounted
## ← js/gems.js：宝石散射、锁定式磁吸。


static func create_gem(x: float, y: float, elapsed: float) -> Dictionary:
    var tier: Dictionary = Config.CONFIG["gems"]["tiers"][-1]
    for candidate: Dictionary in Config.CONFIG["gems"]["tiers"]:
        if elapsed < candidate["until"]:
            tier = candidate
            break
    var angle: float = Rng.next() * TAU
    var speed: float = 20.0 + Rng.next() * 35.0
    return {"x": x, "y": y, "vx": cos(angle) * speed, "vy": sin(angle) * speed,
        "value": tier["value"], "color": tier["color"], "magnetized": false,
        "magnetSpeed": 0.0, "dead": false}


static func update_gem(gem: Dictionary, player, dt: float, magnet_radius: float) -> void:
    if gem["dead"]:
        return
    var dx: float = player.x - gem["x"]
    var dy: float = player.y - gem["y"]
    var d2: float = dx * dx + dy * dy
    # RULES.md §9.1：一旦进入范围即锁定，不因越界解除。
    if not gem["magnetized"] and d2 <= magnet_radius * magnet_radius:
        gem["magnetized"] = true
        gem["magnetSpeed"] = maxf(Config.CONFIG["gems"]["magnetStartSpeed"], sqrt(gem["vx"] * gem["vx"] + gem["vy"] * gem["vy"]))
    if gem["magnetized"]:
        var distance: float = sqrt(d2) if d2 > 0.0 else 1.0
        gem["magnetSpeed"] = minf(Config.CONFIG["gems"]["magnetMaxSpeed"], gem["magnetSpeed"] + Config.CONFIG["gems"]["magnetAcceleration"] * dt)
        gem["vx"] = dx / distance * gem["magnetSpeed"]
        gem["vy"] = dy / distance * gem["magnetSpeed"]
    else:
        var friction: float = maxf(0.0, 1.0 - 5.0 * dt)
        gem["vx"] *= friction
        gem["vy"] *= friction
    gem["x"] += gem["vx"] * dt
    gem["y"] += gem["vy"] * dt
