extends RefCounted
## ← js/projectile.js：玩家弹道纯逻辑数据。
## setup/kill 成对出现：setup 是对象池复用入口，kill 负责断开武器 Callable 与容器引用。

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
    setup(x0, y0, initial_angle, options)


## 对象池复用入口：重置全部字段，等效于一次全新构造。
func setup(x0: float, y0: float, initial_angle: float, options: Dictionary = {}) -> void:
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
    hitCount = 0
    dead = false
    hitSet.clear()
    attackSeq = 0
    swordQi = false
    synergyPrevX = 0.0
    synergyPrevY = 0.0
    ringReturnCharged = false
    ringReturnUsed = false
    furnaceCuts.clear()


## 幂等死亡：置 dead 之外立即断开引用，对象池回收与泄漏检查都依赖它。
func kill() -> void:
    dead = true
    onHit = Callable()
    hitSet.clear()
    damageOptions = {}
    furnaceCuts.clear()


func update(dt: float) -> void:
    x += vx * dt
    y += vy * dt
    lifetime -= dt
    if lifetime <= 0.0:
        kill()


func record_hit(target) -> void:
    hitSet[target.get_instance_id()] = true
    hitCount += 1
    if onHit.is_valid():
        onHit.call(target)
    # maxHits 是配置上限，不是剩余次数；无限穿透依赖其保持 INF。
    if hitCount >= maxHits:
        kill()
