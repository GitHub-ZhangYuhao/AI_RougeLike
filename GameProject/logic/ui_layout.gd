extends RefCounted
## ← js/ui-cards.js + js/hud.js：渲染与命中检测共用布局。


static func get_card_rects(view_w: float, view_h: float, count: int) -> Array[Dictionary]:
    var rects: Array[Dictionary] = []
    if count <= 3:
        var total: float = count * 210.0 + (count - 1) * 24.0
        var start_x: float = (view_w - total) / 2.0
        var y: float = (view_h - 292.0) / 2.0 + 8.0
        for i in count:
            rects.append({"x": start_x + i * 234.0, "y": y, "w": 210.0, "h": 292.0})
        return rects
    var cols: int = ceili(count / 2.0)
    var total_w: float = cols * 200.0 + (cols - 1) * 24.0
    var start_x: float = (view_w - total_w) / 2.0
    var start_y: float = (view_h - 528.0) / 2.0 + 16.0
    for i in count:
        var row: int = i / cols
        var col: int = i % cols
        var in_row: int = count - cols if row == 1 else cols
        var row_off: float = (cols - in_row) * 224.0 / 2.0 if row == 1 else 0.0
        rects.append({"x": start_x + row_off + col * 224.0, "y": start_y + row * 276.0, "w": 200.0, "h": 252.0})
    return rects


static func get_weapon_slot_rects() -> Array[Dictionary]:
    var rects: Array[Dictionary] = []
    for i in Config.CONFIG["cards"]["maxWeaponSlots"]:
        rects.append({"x": 14.0 + i * 54.0, "y": 84.0, "w": 46.0, "h": 52.0})
    return rects
