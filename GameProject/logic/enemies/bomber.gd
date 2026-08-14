extends "res://logic/enemies/base.gd"
## ← js/enemies/bomber.js. 被击杀不会触发爆炸（RULES.md §7.6）。

var state: String = "approach"
var windupTimer: float = 0.0
var exploded: bool = false
var triggerDistance: float
var windupDuration: float
var blastRadius: float

func _init(x0: float, y0: float, elapsed: float = 0.0) -> void:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["bomber"]
    super(x0, y0, elapsed, {"type": "bomber", "rank": "enhanced-minion", "hpMult": config["hpMult"],
        "speedMult": config["speedMult"], "damageMult": config["damageMult"]})
    triggerDistance = config["triggerDistance"]
    windupDuration = config["windup"]
    blastRadius = config["blastRadius"]

func update(player, dt: float, world = null) -> void:
    if dead or hp <= 0.0 or exploded:
        return
    tick_common(dt)
    if state == "approach":
        if distance_to(player) <= triggerDistance:
            state = "windup"
            windupTimer = 0.0
        else:
            self.move_toward(player, dt)
        return
    windupTimer += dt
    if windupTimer < windupDuration:
        return
    exploded = true
    if world is Dictionary:
        if distance_to(player) <= blastRadius and world.has("hurt_player"):
            world["hurt_player"].call(damage)
        if world.has("spawn_enemy_blast"):
            world["spawn_enemy_blast"].call({"x": x, "y": y, "radius": blastRadius, "color": "#ff8a50"})
    dead = true
