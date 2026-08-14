extends RefCounted
## ← js/enemies/hostile-projectile.js：M1 敌方弹道骨架。

var x: float
var y: float
var vx: float
var vy: float
var damage: float
var radius: float
var lifetime: float
var dead: bool = false


func _init(options: Dictionary = {}) -> void:
    x = options.get("x", 0.0)
    y = options.get("y", 0.0)
    var angle: float = options.get("angle", 0.0)
    var speed: float = options.get("speed", 150.0)
    vx = cos(angle) * speed
    vy = sin(angle) * speed
    damage = options.get("damage", 6.0)
    radius = options.get("radius", 5.0)
    lifetime = options.get("lifetime", 4.0)


func update(dt: float) -> void:
    x += vx * dt
    y += vy * dt
    lifetime -= dt
    if lifetime <= 0.0:
        dead = true


static func create_hostile_projectile(options: Dictionary = {}):
    return new(options)


static func update_hostile_projectile(projectile, dt: float) -> void:
    projectile.update(dt)
