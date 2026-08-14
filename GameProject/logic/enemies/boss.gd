extends "res://logic/enemies/base.gd"
## ← js/enemies/boss.js

var state: String = "chase"
var attackCooldown: float = 1.6
var windupTimer: float = 0.0
var rotation: float = 0.0
var enraged: bool:
    get: return hp / maxHp <= Config.CONFIG["enemyTypes"]["boss"]["enragedHpRatio"]

func _init(x0: float, y0: float, elapsed: float = 0.0) -> void:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["boss"]
    super(x0, y0, elapsed, {"type": "boss", "rank": "boss", "radius": config["radius"], "hpMult": config["hpMult"],
        "speedMult": config["speedMult"], "damageMult": config["damageMult"], "speedVariance": false})
    name = "暗夜领主"

func update(player, dt: float, world = null) -> void:
    if dead:
        return
    tick_common(dt)
    var config: Dictionary = Config.CONFIG["enemyTypes"]["boss"]
    rotation += dt * (2.2 if enraged else 1.25)
    if state == "windup":
        windupTimer += dt
        if windupTimer >= config["windup"]:
            _fire_radial_burst(world)
            state = "chase"
            attackCooldown = config["attackInterval"] * (0.72 if enraged else 1.0)
        return
    attackCooldown -= dt
    self.move_toward(player, dt, speed * (1.2 if enraged else 1.0))
    if attackCooldown <= 0.0:
        state = "windup"
        windupTimer = 0.0

func _fire_radial_burst(world) -> void:
    if not world is Dictionary:
        return
    var config: Dictionary = Config.CONFIG["enemyTypes"]["boss"]
    var count: int = config["enragedProjectileCount"] if enraged else config["projectileCount"]
    var projectile_speed: float = config["enragedProjectileSpeed"] if enraged else config["projectileSpeed"]
    if world.has("spawn_hostile_projectile"):
        for i in count:
            world["spawn_hostile_projectile"].call({"x": x, "y": y, "angle": rotation + i * TAU / count,
                "speed": projectile_speed, "radius": config["projectileRadius"], "damage": damage * 0.72,
                "lifetime": config["projectileLifetime"], "color": "#ff5252" if enraged else "#b388ff"})
    if world.has("spawn_enemy_blast"):
        world["spawn_enemy_blast"].call({"x": x, "y": y, "radius": radius * 2.4,
            "color": "#ff1744" if enraged else "#7c4dff", "ttl": 0.45})
