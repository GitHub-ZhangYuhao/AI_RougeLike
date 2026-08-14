extends "res://logic/enemies/base.gd"
## ← js/enemies/charger.js

var state: String = "chase"
var stateTimer: float = 0.0
var chargeCooldown: float = 0.0
var lockedDirection: Dictionary = {"x": 1.0, "y": 0.0}

func _init(x0: float, y0: float, elapsed: float = 0.0) -> void:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["charger"]
    super(x0, y0, elapsed, {"type": "charger", "rank": "enhanced", "hpMult": config["hpMult"],
        "speedMult": config["speedMult"], "damageMult": config["damageMult"]})

func update(player, dt: float, _world = null) -> void:
    tick_common(dt)
    chargeCooldown = maxf(0.0, chargeCooldown - dt)
    var config: Dictionary = Config.CONFIG["enemyTypes"]["charger"]
    if state == "windup":
        stateTimer -= dt
        if stateTimer <= 0.0:
            state = "dash"
            stateTimer = config["dashDuration"]
    elif state == "dash":
        var mult: float = StatusScript.speed_mult_of(self)
        x += lockedDirection["x"] * config["dashSpeed"] * mult * dt
        y += lockedDirection["y"] * config["dashSpeed"] * mult * dt
        stateTimer -= dt
        if stateTimer <= 0.0:
            state = "recovery"
            stateTimer = config["recovery"]
    elif state == "recovery":
        stateTimer -= dt
        if stateTimer <= 0.0:
            state = "chase"
            chargeCooldown = config["cooldown"]
    else:
        self.move_toward(player, dt)
        if chargeCooldown <= 0.0 and distance_to(player) <= config["chargeRange"]:
            lockedDirection = direction_to(player)
            state = "windup"
            stateTimer = config["windup"]
