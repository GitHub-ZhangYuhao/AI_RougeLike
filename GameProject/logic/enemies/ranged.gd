extends "res://logic/enemies/base.gd"
## ← js/enemies/ranged.js

var preferredDistance: float
var retreatDistance: float
var fireInterval: float
var fireCooldown: float
var projectileSpeed: float
var projectileRadius: float
var projectileLifetime: float
var shotFlash: float = 0.0
var aimAngle: float = 0.0

func _init(x0: float, y0: float, elapsed: float = 0.0) -> void:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["ranged"]
    super(x0, y0, elapsed, {"type": "ranged", "rank": "enhanced-minion", "hpMult": config["hpMult"],
        "speedMult": config["speedMult"], "damageMult": config["damageMult"]})
    preferredDistance = config["preferredDistance"]
    retreatDistance = config["retreatDistance"]
    fireInterval = config["fireInterval"]
    fireCooldown = fireInterval
    projectileSpeed = config["projectileSpeed"]
    projectileRadius = config["projectileRadius"]
    projectileLifetime = config["projectileLifetime"]

func update(player, dt: float, world = null) -> void:
    tick_common(dt)
    shotFlash = maxf(0.0, shotFlash - dt)
    var direction: Dictionary = direction_to(player)
    aimAngle = atan2(direction["y"], direction["x"])
    if direction["distance"] > preferredDistance + 12.0:
        self.move_toward(player, dt)
    elif direction["distance"] < retreatDistance:
        self.move_away_from(player, dt)
    fireCooldown -= dt
    if fireCooldown > 0.0:
        return
    if world is Dictionary and world.has("spawn_hostile_projectile"):
        var muzzle: float = radius + projectileRadius + 3.0
        world["spawn_hostile_projectile"].call({"x": x + direction["x"] * muzzle, "y": y + direction["y"] * muzzle,
            "angle": aimAngle, "speed": projectileSpeed, "radius": projectileRadius, "damage": damage,
            "lifetime": projectileLifetime, "color": "#ffb74d"})
        shotFlash = 0.16
    fireCooldown = fireInterval
