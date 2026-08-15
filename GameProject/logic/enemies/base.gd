extends RefCounted
## ← js/enemies/base.js：敌人共享状态与波次成长。

const StatusScript: GDScript = preload("res://logic/systems/status.gd")

var x: float
var y: float
var radius: float
var type: String
var rank: String
var maxHp: float
var hp: float
var speed: float
var damage: float
var xpValue: float = 1.0
var hitCooldown: float = 0.0
var hitFlash: float = 0.0
var ringCd: float = 0.0
var dead: bool = false
var dots: Dictionary = {}
var slowTimer: float = 0.0
var slowFactor: float = 0.0
var frozenTimer: float = 0.0
var synergyMarks: Dictionary = {}
var synergyCooldowns: Dictionary = {}
var ghostfireCdUntil: float = -INF
var waveScalingApplied: bool = false
var wave: int = 1
var suppressRareDrop: bool = false
var taskId = null
var taskRole = null
var name: String = ""


func _init(x0: float, y0: float, elapsed: float = 0.0, options: Dictionary = {}) -> void:
    var config: Dictionary = Config.CONFIG["enemy"]
    var minutes: float = elapsed / 60.0
    var jitter: float = 1.0 if options.get("speedVariance", true) == false else 1.0 + (-config["speedVariance"] + Rng.next() * config["speedVariance"] * 2.0)
    x = x0
    y = y0
    radius = options.get("radius", config["radius"])
    type = options.get("type", "chaser")
    rank = options.get("rank", "normal")
    maxHp = (config["hp"] + config["hpPerMin"] * minutes) * options.get("hpMult", 1.0)
    hp = maxHp
    speed = config["speed"] * jitter * (1.0 + config["speedPerMin"] * minutes) * options.get("speedMult", 1.0)
    damage = (config["damage"] + config["damagePerMin"] * minutes) * options.get("damageMult", 1.0)


func apply_wave_scaling(requested_wave: int = 1):
    if waveScalingApplied:
        return self
    wave = maxi(1, requested_wave)
    var config: Dictionary = Config.CONFIG["enemy"]
    var step: int = wave - 1
    var early: int = mini(step, int(config["midWaveStart"]) - 2)
    var middle: int = mini(maxi(0, step - early), int(config["lateWaveStart"]) - int(config["midWaveStart"]))
    var late: int = maxi(0, step - early - middle)
    var hp_mult: float = minf(config["hpWaveCap"], 1.0 + config["hpPerWave"] * early + config["hpPerWaveMid"] * middle + config["hpPerWaveLate"] * late)
    var damage_mult: float = 1.0 + config["damagePerWave"] * early + config["damagePerWaveMid"] * middle + config["damagePerWaveLate"] * late
    var speed_cap_step: int = maxi(1, int(config["speedCapStartWave"]) - 1)
    var speed_progress: float = minf(step, speed_cap_step) / speed_cap_step
    var speed_mult: float = config["baseSpeedMult"] + (config["speedWaveCap"] - config["baseSpeedMult"]) * speed_progress
    var ratio: float = hp / maxHp if maxHp > 0.0 else 1.0
    maxHp *= hp_mult
    hp = maxHp * ratio
    damage *= damage_mult
    speed *= speed_mult
    waveScalingApplied = true
    return self


func distance_to(target) -> float:
    return sqrt(pow(target.x - x, 2) + pow(target.y - y, 2))


func direction_to(target) -> Dictionary:
    var dx: float = target.x - x
    var dy: float = target.y - y
    var distance: float = sqrt(dx * dx + dy * dy)
    if distance <= 0.0:
        distance = 1.0
    return {"x": dx / distance, "y": dy / distance, "distance": distance}


func move_toward(target, dt: float, requested_speed: float = -1.0) -> void:
    var multiplier: float = StatusScript.speed_mult_of(self)
    if multiplier <= 0.0:
        return
    var direction: Dictionary = direction_to(target)
    var move_speed: float = speed if requested_speed < 0.0 else requested_speed
    x += direction["x"] * move_speed * multiplier * dt
    y += direction["y"] * move_speed * multiplier * dt


func move_away_from(target, dt: float, requested_speed: float = -1.0) -> void:
    var multiplier: float = StatusScript.speed_mult_of(self)
    if multiplier <= 0.0:
        return
    var direction: Dictionary = direction_to(target)
    var move_speed: float = speed if requested_speed < 0.0 else requested_speed
    x -= direction["x"] * move_speed * multiplier * dt
    y -= direction["y"] * move_speed * multiplier * dt


func update(player, dt: float, _world = null) -> void:
    tick_common(dt)
    self.move_toward(player, dt)


func tick_common(dt: float) -> void:
    if hitCooldown > 0.0:
        hitCooldown -= dt
    if hitFlash > 0.0:
        hitFlash -= dt
    if ringCd > 0.0:
        ringCd -= dt


func modify_incoming_damage(value: float) -> float:
    return value
