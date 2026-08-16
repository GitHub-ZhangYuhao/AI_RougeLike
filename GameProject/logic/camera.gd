extends RefCounted
## ← js/camera.js：指数平滑跟随目标。位置用 float x/y（逻辑层禁 Vector2）。

var x: float
var y: float


func _init(x0: float = 0.0, y0: float = 0.0) -> void:
    x = x0
    y = y0


func snap_to(t) -> void:
    x = t.x
    y = t.y


func follow(target, dt: float, lerp_rate: float) -> void:
    var t: float = 1.0 - exp(-lerp_rate * dt)
    x += (target.x - x) * t
    y += (target.y - y) * t
