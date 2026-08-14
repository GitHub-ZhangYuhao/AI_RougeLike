extends RefCounted
## ← js/ui-cards.js + js/hud.js：渲染与命中检测共用布局。


static func get_card_rects(view_w: float, view_h: float, count: int) -> Array[Dictionary]:
    var rects: Array[Dictionary] = []
    if count <= 3:
        var card_w: float = 250.0
        var card_h: float = 330.0
        var gap: float = 28.0
        var total: float = count * card_w + (count - 1) * gap
        var start_x: float = (view_w - total) / 2.0
        var y: float = (view_h - card_h) / 2.0 + 18.0
        for i in count:
            rects.append({"x": start_x + i * (card_w + gap), "y": y, "w": card_w, "h": card_h})
        return rects
    var card_w: float = 218.0
    var card_h: float = 280.0
    var gap_x: float = 22.0
    var gap_y: float = 12.0
    var cols: int = ceili(count / 2.0)
    var total_w: float = cols * card_w + (cols - 1) * gap_x
    var start_x: float = (view_w - total_w) / 2.0
    var start_y: float = (view_h - (card_h * 2.0 + gap_y)) / 2.0 + 8.0
    for i in count:
        var row: int = i / cols
        var col: int = i % cols
        var in_row: int = count - cols if row == 1 else cols
        var row_off: float = (cols - in_row) * (card_w + gap_x) / 2.0 if row == 1 else 0.0
        rects.append({"x": start_x + row_off + col * (card_w + gap_x), "y": start_y + row * (card_h + gap_y), "w": card_w, "h": card_h})
    return rects


static func get_weapon_slot_rects() -> Array[Dictionary]:
    var rects: Array[Dictionary] = []
    var start_x: float = 437.0
    for i in Config.CONFIG["cards"]["maxWeaponSlots"]:
        rects.append({"x": start_x + i * 70.0, "y": 650.0, "w": 58.0, "h": 54.0})
    return rects
