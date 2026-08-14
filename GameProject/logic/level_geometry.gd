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
