extends RefCounted
## ← js/projectile.js：玩家弹道纯逻辑数据。

var x: float
var y: float
var vx: float
var vy: float
var speed: float
var damage: float
var radius: float
var lifetime: float
var pierce: bool
var maxHits: float
var hitCount: int = 0
var dead: bool = false
var hitSet: Dictionary = {}
var onHit: Callable = Callable()
var damageOptions: Dictionary = {}
var attackSeq: int = 0
var swordQi: bool = false
var angle: float = 0.0
var color: String = ""
var synergyPrevX: float = 0.0
var synergyPrevY: float = 0.0
var ringReturnCharged: bool = false
var ringReturnUsed: bool = false
var furnaceCuts: Dictionary = {}


func _init(x0: float, y0: float, initial_angle: float, options: Dictionary = {}) -> void:
    x = x0
    y = y0
    angle = initial_angle
    color = options.get("color", "")
    speed = options.get("speed", 0.0)
    vx = cos(initial_angle) * speed
    vy = sin(initial_angle) * speed
    damage = options.get("damage", 0.0)
    radius = options.get("radius", 5.0)
    lifetime = options.get("lifetime", 4.0)
    maxHits = options.get("maxHits", 1.0)
    pierce = maxHits > 1.0
    damageOptions = options.get("damageOptions", {})
    onHit = options.get("onHit", Callable())


func update(dt: float) -> void:
    x += vx * dt
    y += vy * dt
    lifetime -= dt
    if lifetime <= 0.0:
        dead = true


func record_hit(target) -> void:
    hitSet[target.get_instance_id()] = true
    hitCount += 1
    if onHit.is_valid():
        onHit.call(target)
    # maxHits 是配置上限，不是剩余次数；无限穿透依赖其保持 INF。
    if hitCount >= maxHits:
        dead = true
