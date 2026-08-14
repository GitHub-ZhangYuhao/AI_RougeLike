extends "res://logic/enemies/base.gd"
## ← js/enemies/enhanced-chaser.js

var enrageTriggered: bool = false
var enraged: bool = false
var warningTimer: float = 0.0
var warningDuration: float

func _init(x0: float, y0: float, elapsed: float = 0.0) -> void:
    var config: Dictionary = Config.CONFIG["enemyTypes"]["enhancedChaser"]
    super(x0, y0, elapsed, {"type": "enhancedChaser", "rank": "enhanced-minion", "radius": Config.CONFIG["enemy"]["radius"] + 2,
        "hpMult": config["hpMult"], "speedMult": config["speedMult"], "damageMult": config["damageMult"]})
    warningDuration = config["warningDuration"]

func update(player, dt: float, _world = null) -> void:
    tick_common(dt)
    var config: Dictionary = Config.CONFIG["enemyTypes"]["enhancedChaser"]
    if not enrageTriggered and hp <= maxHp * config["enrageHpRatio"]:
        enrageTriggered = true
        warningTimer = warningDuration
    if warningTimer > 0.0:
        warningTimer = maxf(0.0, warningTimer - dt)
        self.move_toward(player, dt, speed * 0.3)
        if warningTimer <= 0.0:
            _enter_enrage()
        return
    self.move_toward(player, dt)

func _enter_enrage() -> void:
    if enraged:
        return
    var config: Dictionary = Config.CONFIG["enemyTypes"]["enhancedChaser"]
    enraged = true
    speed *= config["enragedSpeedMult"]
    damage *= config["enragedDamageMult"]
