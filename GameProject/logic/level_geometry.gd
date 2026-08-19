extends RefCounted

const LEFT: float = -2048.0
const TOP: float = -2048.0
const RIGHT: float = 2048.0
const BOTTOM: float = 2048.0
const PLAYER_INSET: float = 36.0
const SPAWN_INSET: float = 32.0
const TASK_INSET: float = 80.0


static func bounds() -> Dictionary:
    return {"left": LEFT, "top": TOP, "right": RIGHT, "bottom": BOTTOM}


static func clamp_circle(x: float, y: float, radius: float) -> Dictionary:
    return {
        "x": clampf(x, LEFT + radius, RIGHT - radius),
        "y": clampf(y, TOP + radius, BOTTOM - radius),
    }


static func clamp_point(point: Dictionary, inset: float = 0.0) -> Dictionary:
    return {
        "x": clampf(point["x"], LEFT + inset, RIGHT - inset),
        "y": clampf(point["y"], TOP + inset, BOTTOM - inset),
    }


static func clamp_camera(x: float, y: float, view_w: float, view_h: float) -> Dictionary:
    var half_w := minf(view_w * 0.5, (RIGHT - LEFT) * 0.5)
    var half_h := minf(view_h * 0.5, (BOTTOM - TOP) * 0.5)
    return {
        "x": clampf(x, LEFT + half_w, RIGHT - half_w),
        "y": clampf(y, TOP + half_h, BOTTOM - half_h),
    }


static func is_outside_circle(x: float, y: float, radius: float = 0.0) -> bool:
    return x - radius < LEFT or x + radius > RIGHT or y - radius < TOP or y + radius > BOTTOM

# ---------------------------------------------------------------------------
# 可行走区域（RULES.md §3.6）：草甸关卡在矩形边界之上叠加的不规则多边形限制。
# 几何唯一真值是 scenes/game/meadow_level.tscn 的 WalkableBoundary（Polygon2D）节点，
# 顶点可在编辑器直接拖动；运行时由 game_view 与 headless smoke 各自读取该节点并
# 经 set_walkable_polygon() 登记（世界坐标 = 局部顶点 × 节点 transform）。
# WALKABLE_DEFAULT_POLYGON 仅是未登记时的兜底形状，不得当作编辑入口。
# ---------------------------------------------------------------------------
const WALKABLE_DEFAULT_POLYGON: Array = [
    {"x": 394.0, "y": -105.0},
    {"x": 877.0, "y": -225.0},
    {"x": 1025.0, "y": -264.0},
    {"x": 1063.0, "y": -839.0},
    {"x": -272.0, "y": -1018.0},
    {"x": -853.0, "y": -935.0},
    {"x": -988.0, "y": -64.0},
    {"x": -851.0, "y": 1064.0},
    {"x": -529.0, "y": 1018.0},
    {"x": -329.0, "y": 828.0},
    {"x": -249.0, "y": 439.0},
    {"x": -13.0, "y": 374.0},
    {"x": 303.0, "y": 260.0},
]

static var _walkable_polygon: Array = []


## 登记可行走区域多边形（世界坐标顶点 {x, y} Dictionary 数组）；少于 3 个顶点拒绝登记。
static func set_walkable_polygon(points: Array) -> bool:
    if points.size() < 3:
        push_error("walkable polygon needs at least 3 points")
        return false
    _walkable_polygon = points.duplicate()
    return true


## 当前生效的可行走区域多边形；未登记时回退 WALKABLE_DEFAULT_POLYGON。
static func walkable_polygon() -> Array:
    if _walkable_polygon.size() >= 3:
        return _walkable_polygon
    return WALKABLE_DEFAULT_POLYGON


## 把 Polygon2D 局部顶点按节点 transform 换算为逻辑世界坐标（场景登记入口共用）。
static func points_from_polygon(local_points: PackedVector2Array, local_transform: Transform2D) -> Array:
    var points: Array = []
    for local_point in local_points:
        var world_point: Vector2 = local_transform * local_point
        points.append({"x": world_point.x, "y": world_point.y})
    return points

const _WALKABLE_MARGIN: float = 0.001


static func point_in_walkable(x: float, y: float) -> bool:
    var poly: Array = walkable_polygon()
    var inside := false
    var count := poly.size()
    var prev: Dictionary = poly[count - 1]
    for i in count:
        var cur: Dictionary = poly[i]
        if (cur["y"] > y) != (prev["y"] > y):
            var cross_x: float = cur["x"] + (y - cur["y"]) / (prev["y"] - cur["y"]) * (prev["x"] - cur["x"])
            if x < cross_x:
                inside = not inside
        prev = cur
    return inside


## 把半径为 radius 的圆钳制进可行走区域。from_x/from_y 给出本帧移动前的合法
## 位置时沿阻挡边/凹角顶点圆弧滑动（不会瞬移）；缺省时走遗留投影路径。
static func clamp_walkable_circle(x: float, y: float, radius: float, from_x: float = INF, from_y: float = INF) -> Dictionary:
    if _circle_in_walkable(x, y, radius):
        return {"x": x, "y": y}
    if is_finite(from_x) and is_finite(from_y) and _circle_in_walkable(from_x, from_y, radius):
        var slid: Dictionary = _slide_clamp(from_x, from_y, x, y, radius)
        if _circle_in_walkable(slid["x"], slid["y"], radius):
            return slid
        return _furthest_valid_along(from_x, from_y, x, y, radius)
    return _legacy_walkable_clamp(x, y, radius)


static func _segment_closest(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> Dictionary:
    var abx: float = bx - ax
    var aby: float = by - ay
    var denom: float = abx * abx + aby * aby
    var t := 0.0
    if denom > 0.0:
        t = clampf(((px - ax) * abx + (py - ay) * aby) / denom, 0.0, 1.0)
    var cx: float = ax + abx * t
    var cy: float = ay + aby * t
    return {"dist": sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy)), "cx": cx, "cy": cy, "t": t}


static func _nearest_walkable_edge(x: float, y: float) -> Dictionary:
    var best: Dictionary = {"dist": INF, "cx": 0.0, "cy": 0.0, "edge": 0, "t": 0.0}
    var poly: Array = walkable_polygon()
    var count := poly.size()
    for i in count:
        var cur: Dictionary = poly[i]
        var nxt: Dictionary = poly[(i + 1) % count]
        var info: Dictionary = _segment_closest(x, y, cur["x"], cur["y"], nxt["x"], nxt["y"])
        if info["dist"] < best["dist"]:
            best = {"dist": info["dist"], "cx": info["cx"], "cy": info["cy"], "edge": i, "t": info["t"]}
    return best


static func _circle_in_walkable(x: float, y: float, radius: float) -> bool:
    if not point_in_walkable(x, y):
        return false
    var poly: Array = walkable_polygon()
    var count := poly.size()
    for i in count:
        var cur: Dictionary = poly[i]
        var nxt: Dictionary = poly[(i + 1) % count]
        if _segment_closest(x, y, cur["x"], cur["y"], nxt["x"], nxt["y"])["dist"] < radius:
            return false
    return true


static func _furthest_valid_along(ax: float, ay: float, bx: float, by: float, radius: float) -> Dictionary:
    if _circle_in_walkable(bx, by, radius):
        return {"x": bx, "y": by}
    var lo := 0.0
    var hi := 1.0
    for k in 24:
        var mid: float = (lo + hi) * 0.5
        if _circle_in_walkable(ax + (bx - ax) * mid, ay + (by - ay) * mid, radius + _WALKABLE_MARGIN):
            lo = mid
        else:
            hi = mid
    return {"x": ax + (bx - ax) * lo, "y": ay + (by - ay) * lo}


static func _contact_slide_dir(rx: float, ry: float, rem_x: float, rem_y: float, radius: float) -> Variant:
    var n: Dictionary = _nearest_walkable_edge(rx, ry)
    if n["dist"] > radius + 0.5:
        return null
    var eps_t := 1e-3
    if n["t"] > eps_t and n["t"] < 1.0 - eps_t:
        var poly: Array = walkable_polygon()
        var cur: Dictionary = poly[n["edge"]]
        var nxt: Dictionary = poly[(int(n["edge"]) + 1) % poly.size()]
        var dx: float = nxt["x"] - cur["x"]
        var dy: float = nxt["y"] - cur["y"]
        var el: float = sqrt(dx * dx + dy * dy)
        if el < 1e-6:
            return null
        var sx: float = (nxt["x"] - cur["x"]) / el
        var sy: float = (nxt["y"] - cur["y"]) / el
        if rem_x * sx + rem_y * sy < 0.0:
            sx = -sx
            sy = -sy
        if rem_x * sx + rem_y * sy <= 0.0:
            return null
        if not _circle_in_walkable(rx + sx * 0.5, ry + sy * 0.5, radius):
            return null
        return {"sx": sx, "sy": sy}
    var rxv: float = rx - n["cx"]
    var ryv: float = ry - n["cy"]
    var rl: float = sqrt(rxv * rxv + ryv * ryv)
    if rl < 1e-6:
        return null
    rxv /= rl
    ryv /= rl
    var order: Array
    if rem_x * (-ryv) + rem_y * rxv >= rem_x * ryv + rem_y * (-rxv):
        order = [[-ryv, rxv], [ryv, -rxv]]
    else:
        order = [[ryv, -rxv], [-ryv, rxv]]
    for cand in order:
        var d: float = rem_x * cand[0] + rem_y * cand[1]
        if d <= 0.0:
            continue
        if _circle_in_walkable(rx + cand[0] * 0.5, ry + cand[1] * 0.5, radius):
            return {"sx": cand[0], "sy": cand[1]}
    return null


static func _slide_clamp(fx: float, fy: float, tx: float, ty: float, radius: float) -> Dictionary:
    var px := fx
    var py := fy
    var vx := tx - fx
    var vy := ty - fy
    for pass_i in 3:
        var gx: float = px + vx
        var gy: float = py + vy
        if _circle_in_walkable(gx, gy, radius):
            return {"x": gx, "y": gy}
        var reached: Dictionary = _furthest_valid_along(px, py, gx, gy, radius)
        var rem_x: float = gx - reached["x"]
        var rem_y: float = gy - reached["y"]
        var dir: Variant = _contact_slide_dir(reached["x"], reached["y"], rem_x, rem_y, radius)
        if dir == null:
            return reached
        var slide: float = rem_x * dir["sx"] + rem_y * dir["sy"]
        if slide < 1e-4:
            return reached
        px = reached["x"]
        py = reached["y"]
        vx = dir["sx"] * slide
        vy = dir["sy"] * slide
    return _furthest_valid_along(px, py, px + vx, py + vy, radius)


static func _legacy_walkable_clamp(x: float, y: float, radius: float) -> Dictionary:
    var cx := x
    var cy := y
    for iteration in 8:
        if _circle_in_walkable(cx, cy, radius):
            return {"x": cx, "y": cy}
        var n: Dictionary = _nearest_walkable_edge(cx, cy)
        if n["dist"] < 1e-4:
            cx = n["cx"] * 0.99
            cy = n["cy"] * 0.99
            continue
        if point_in_walkable(cx, cy):
            var push: float = radius - n["dist"]
            cx += (cx - n["cx"]) / n["dist"] * push
            cy += (cy - n["cy"]) / n["dist"] * push
        else:
            cx = n["cx"] + (n["cx"] - cx) / n["dist"] * radius
            cy = n["cy"] + (n["cy"] - cy) / n["dist"] * radius
    if _circle_in_walkable(cx, cy, radius):
        return {"x": cx, "y": cy}
    return _walkable_fallback(cx, cy, radius)


static func _walkable_fallback(tx: float, ty: float, radius: float) -> Dictionary:
    var lo := 0.0
    var hi := 1.0
    for i in 8:
        var t: float = float(i + 1) / 8.0
        if not _circle_in_walkable(tx * t, ty * t, radius):
            hi = t
            lo = float(i) / 8.0
            break
    for k in 24:
        var mid: float = (lo + hi) * 0.5
        if _circle_in_walkable(tx * mid, ty * mid, radius):
            lo = mid
        else:
            hi = mid
    return {"x": tx * lo, "y": ty * lo}

