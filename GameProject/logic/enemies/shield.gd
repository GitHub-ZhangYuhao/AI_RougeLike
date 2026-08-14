extends "res://logic/enemies/base.gd"
## ← js/enemies/shield.js

var phase: String = "shielded"
var phaseTimer: float

func _init(x0: float, y0: float, elapsed: float = 0.0) -> void:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["shield"]
    super(x0, y0, elapsed, {"type": "shield", "rank": "elite", "hpMult": config["hpMult"],
        "speedMult": config["speedMult"], "damageMult": config["damageMult"]})
    phaseTimer = config["shieldDuration"]

func update(player, dt: float, _world = null) -> void:
    tick_common(dt)
    var config: Dictionary = Config.CONFIG["enemyTypes"]["shield"]
    phaseTimer -= dt
    while phaseTimer <= 0.0:
        if phase == "shielded":
            phase = "open"
            phaseTimer += config["openDuration"]
        else:
            phase = "shielded"
            phaseTimer += config["shieldDuration"]
    self.move_toward(player, dt)

func modify_incoming_damage(value: float) -> float:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["shield"]
    return value * (config["shieldDamageMult"] if phase == "shielded" else config["openDamageMult"])
