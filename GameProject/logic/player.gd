extends RefCounted
## ← js/player.js：玩家实体。字段名与原型一致（camelCase，便于逐键 diff）。

var x: float
var y: float
var radius: float = 14.0
var speed: float = 230.0
var hp: float = 100.0
var maxHp: float = 100.0
var iFrames: float = 0.0
var lastHurtAt: float = -1.0
var facing: float = 0.0
var moving: bool = false


func _init(x0: float = 0.0, y0: float = 0.0) -> void:
    x = x0
    y = y0
    radius = Config.CONFIG["player"]["radius"]
    speed = Config.CONFIG["player"]["speed"]
    hp = Config.CONFIG["player"]["maxHp"]
    maxHp = Config.CONFIG["player"]["maxHp"]


## 欧拉积分移动；iFrames 递减。
func update(input, dt: float) -> void:
    var axis: Dictionary = input.axis()
    moving = axis["x"] != 0.0 or axis["y"] != 0.0
    if moving:
        x += axis["x"] * speed * dt
        y += axis["y"] * speed * dt
        facing = atan2(axis["y"], axis["x"])
    if iFrames > 0.0:
        iFrames -= dt


## 返回 true 表示真的受到了伤害（没被无敌帧挡掉）。
func hurt(damage: float) -> bool:
    if iFrames > 0.0:
        return false
    hp -= damage
    iFrames = Config.CONFIG["player"]["hurtIFrames"]
    return true
