extends RefCounted
## ← js/input.js：键盘 + 鼠标输入快照（纯数据，不依赖 Node/Input）。
## down = 按住集合；pressed = 本帧刚按下的边沿集合，每帧末清空；
## 原型 mousedown 仅置 _clicked = true（无鼠标按住状态）。
## Dictionary 当集合用（键 = code，值为 true）。

var down: Dictionary = {}
var pressed: Dictionary = {}
var mouse_x: float = 0.0
var mouse_y: float = 0.0
var _clicked: bool = false


func key_down(code: String) -> void:
    if not down.has(code):
        pressed[code] = true
    down[code] = true


func key_up(code: String) -> void:
    down.erase(code)


func mouse_move(x: float, y: float) -> void:
    mouse_x = x
    mouse_y = y


func mouse_down() -> void:
    _clicked = true


## 返回归一化移动轴 {x, y}；WASD/方向键；对角线 ÷√2。
func axis() -> Dictionary:
    var x: float = 0.0
    var y: float = 0.0
    if down.has("KeyA") or down.has("ArrowLeft"):
        x -= 1.0
    if down.has("KeyD") or down.has("ArrowRight"):
        x += 1.0
    if down.has("KeyW") or down.has("ArrowUp"):
        y -= 1.0
    if down.has("KeyS") or down.has("ArrowDown"):
        y += 1.0
    if x != 0.0 and y != 0.0:
        var inv: float = 1.0 / sqrt(2.0)
        x *= inv
        y *= inv
    return {"x": x, "y": y}


func is_down(code: String) -> bool:
    return down.has(code)


func was_pressed(code: String) -> bool:
    return pressed.has(code)


func mouse_clicked() -> bool:
    return _clicked


func end_frame() -> void:
    pressed.clear()
    _clicked = false
