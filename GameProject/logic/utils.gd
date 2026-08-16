extends RefCounted
## ← js/utils.js：通用小工具（纯静态函数）。
## rand/point_around 的随机源一律走注入的 Rng.next()（禁止系统随机）。


static func clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else (hi if v > hi else v)


static func lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


static func dist2(ax: float, ay: float, bx: float, by: float) -> float:
    var dx: float = bx - ax
    var dy: float = by - ay
    return dx * dx + dy * dy


static func dist(ax: float, ay: float, bx: float, by: float) -> float:
    return sqrt(dist2(ax, ay, bx, by))


## JS Math.round 对齐（half up）：7.5→8、37.5→38；M3 结算复用。
static func js_round(x: float) -> int:
    return int(floor(x + 0.5))


static func rand_range(lo: float, hi: float) -> float:
    return lo + Rng.next() * (hi - lo)


## 两个角度之间的最小夹角（弧度）。
static func angle_diff(a: float, b: float) -> float:
    var d: float = fmod(a - b, TAU)
    if d > PI:
        d -= TAU
    if d < -PI:
        d += TAU
    return absf(d)


## 围绕 (cx, cy) 半径 r 的随机点（角度用 1 次 Rng.next()）。
static func point_around(cx: float, cy: float, r: float) -> Dictionary:
    var ang: float = Rng.next() * TAU
    return {"x": cx + cos(ang) * r, "y": cy + sin(ang) * r}


static func format_time(t: float) -> String:
    var m: int = int(floor(t / 60.0))
    var s: int = int(floor(fmod(t, 60.0)))
    return "%02d:%02d" % [m, s]
