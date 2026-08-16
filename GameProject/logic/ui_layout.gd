extends RefCounted
## ← js/ui-cards.js + js/hud.js：渲染与命中检测共用布局。


static func get_card_rects(view_w: float, view_h: float, count: int) -> Array[Dictionary]:
	var rects: Array[Dictionary] = []
	if count <= 3:
		var row_card_w: float = 290.0
		var row_card_h: float = 430.0
		var row_gap: float = 45.0
		var row_total: float = count * row_card_w + (count - 1) * row_gap
		var row_start_x: float = (view_w - row_total) / 2.0
		var row_y: float = maxf(176.0, (view_h - row_card_h) / 2.0 + 35.0)
		for i in count:
			rects.append({"x": row_start_x + i * (row_card_w + row_gap), "y": row_y, "w": row_card_w, "h": row_card_h})
		return rects
	var card_w: float = 205.0
	var card_h: float = 285.0
	var gap_x: float = 24.0
	var gap_y: float = 12.0
	var cols: int = ceili(count / 2.0)
	var total_w: float = cols * card_w + (cols - 1) * gap_x
	var start_x: float = (view_w - total_w) / 2.0
	var start_y: float = 98.0
	for i in count:
		var row: int = floori(float(i) / float(cols))
		var col: int = i % cols
		var in_row: int = count - cols if row == 1 else cols
		var row_off: float = (cols - in_row) * (card_w + gap_x) / 2.0 if row == 1 else 0.0
		rects.append({"x": start_x + row_off + col * (card_w + gap_x), "y": start_y + row * (card_h + gap_y), "w": card_w, "h": card_h})
	return rects


static func get_weapon_slot_rects(view_w: float = 1280.0, view_h: float = 720.0) -> Array[Dictionary]:
	var rects: Array[Dictionary] = []
	var slot_w: float = 70.0
	var slot_h: float = 62.0
	var gap: float = 10.0
	var total: float = Config.CONFIG["cards"]["maxWeaponSlots"] * slot_w + (Config.CONFIG["cards"]["maxWeaponSlots"] - 1) * gap
	var start_x: float = (view_w - total) * 0.5
	var base_y: float = view_h - 92.0
	for i in Config.CONFIG["cards"]["maxWeaponSlots"]:
		rects.append({"x": start_x + i * (slot_w + gap), "y": base_y, "w": slot_w, "h": slot_h})
	return rects
