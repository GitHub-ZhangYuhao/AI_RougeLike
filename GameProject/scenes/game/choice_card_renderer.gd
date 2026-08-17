extends RefCounted
## Concept-matched card-choice renderer. The approved mockup is the visual source of truth.

const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")
const ArtCatalog: GDScript = preload("res://scenes/art_catalog.gd")
const UI_FONT: Font = preload("res://assets/fonts/ui_font_round.tres")
const CARD_FRAME: Texture2D = preload("res://assets/ui/peach_night/choice_card_concept_blank.png")
const UI_BLOSSOM_CLUSTER: Texture2D = preload("res://assets/ui/peach_night/atomic/clean/blossom_cluster.svg")
const ILLUSTRATION_SWORD: Texture2D = preload("res://assets/ui/peach_night/choice_illustration_sword.png")
const ILLUSTRATION_CLOAK: Texture2D = preload("res://assets/ui/peach_night/choice_illustration_cloak.png")
const ILLUSTRATION_XP: Texture2D = preload("res://assets/ui/peach_night/choice_illustration_xp.png")

const NIGHT: Color = Color("071321")
const NIGHT_MID: Color = Color("123143")
const INK: Color = Color("35221c")
const INK_SOFT: Color = Color("66483e")
const PAPER_LIGHT: Color = Color("fff0c9")
const GOLD: Color = Color("e6b45a")
const GOLD_DEEP: Color = Color("a86e2f")
const JADE: Color = Color("3ac59b")
const MINT: Color = Color("8af0c5")
const CINNABAR: Color = Color("a93624")
const HEADER_GREEN: Color = Color("145349")

const CARD_COLORS: Dictionary = {
	"sword": Color("77d9eb"), "cloak": Color("ef704a"), "talisman": Color("e4c85c"),
	"trail": Color("e15d3d"), "ring": Color("91d3a8"), "staff": Color("b89ae4"),
	"damage": Color("df6c57"), "armor": Color("9db3bb"), "magnet": Color("75cbd7"),
	"xp": Color("91d6ad"), "maxHp": Color("df8a94"), "moveSpeed": Color("79cc9e"),
}
const CARD_DESCRIPTIONS: Dictionary = {
	"sword": "御剑回旋，自动追击附近敌人", "cloak": "烈焰护体，灼烧靠近的敌人",
	"talisman": "雷弹索敌，引雷并连续弹射", "trail": "移动留火，闭环化为丹炉",
	"ring": "寒玉绕身，触敌造成持续伤害", "staff": "召来魂仆，追猎并引爆敌群",
	"damage": "本局伤害提高 15%", "armor": "本局护甲提高 15",
	"magnet": "拾取范围扩大 50px", "xp": "心境澄明，更快参悟天地灵机",
	"maxHp": "最大生命提高 20", "moveSpeed": "移动速度提高 6%",
}
const TYPE_LABELS: Dictionary = {
	"new": "新法器", "upgrade": "法器精进", "attr": "道行强化",
	"taskWeapon": "奇遇法器", "taskStat": "奇遇强化", "taskBlessing": "奇遇赐福",
}
const ILLUSTRATIONS: Dictionary = {
	"sword": ILLUSTRATION_SWORD,
	"cloak": ILLUSTRATION_CLOAK,
	"xp": ILLUSTRATION_XP,
}

var _panel: StyleBoxFlat = StyleBoxFlat.new()
var _glow: StyleBoxFlat = StyleBoxFlat.new()


func draw(canvas: CanvasItem, run, size: Vector2, animation_time: float) -> void:
	var offers: Array = run.currentOffers
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.055, 0.78))
	_draw_backdrop(canvas, size, animation_time)
	canvas.draw_rect(Rect2(0.0, size.y - 82.0, size.x, 82.0), Color(NIGHT, 0.90))
	_draw_heading(canvas, run, size, offers.size())
	if offers.is_empty():
		return
	var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(size.x, size.y, offers.size())
	var mouse := Vector2(run.input.mouse_x, run.input.mouse_y)
	var hovered_index: int = -1
	for index in offers.size():
		var hit_rect := _rect_from_data(rects[index])
		if hit_rect.has_point(mouse):
			hovered_index = index
			break
	for index in offers.size():
		if index != hovered_index:
			_draw_card(canvas, run, offers[index], rects[index], index, false, animation_time)
	if hovered_index >= 0:
		_draw_card(canvas, run, offers[hovered_index], rects[hovered_index], hovered_index, true, animation_time)


func _draw_backdrop(canvas: CanvasItem, size: Vector2, animation_time: float) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.51)
	canvas.draw_circle(center, 330.0, Color(0.04, 0.27, 0.29, 0.12))
	for ring_index in 3:
		var pulse: float = sin(animation_time * 0.8 + ring_index) * 4.0
		canvas.draw_arc(center, 245.0 + ring_index * 118.0 + pulse, 0.0, TAU, 96, Color(JADE, 0.035), 1.0)
	for petal_index in 10:
		var phase: float = animation_time * (0.16 + petal_index * 0.007) + petal_index * 1.71
		var petal := Vector2(
			fposmod(82.0 + petal_index * 137.0 + phase * 17.0, size.x + 100.0) - 50.0,
			fposmod(120.0 + petal_index * 89.0 + phase * 24.0, size.y + 80.0) - 40.0
		)
		canvas.draw_circle(petal, 3.5, Color("ec7f87", 0.36))


func _draw_heading(canvas: CanvasItem, run, size: Vector2, offer_count: int) -> void:
	var dense: bool = offer_count > 4
	var title: String = "选择初始法器" if run.state == "opening" else ("奇遇已成 · 择取一礼" if run.choiceOrigin == "task" else "境界突破 · 择取一项")
	var title_size: int = 31 if dense else 43
	var title_y: float = 42.0 if dense else 92.0
	canvas.draw_string(UI_FONT, Vector2(2.0, title_y + 3.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, Color(0.0, 0.0, 0.0, 0.78))
	canvas.draw_string(UI_FONT, Vector2(0.0, title_y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, PAPER_LIGHT)
	if not dense:
		var ornament_y: float = title_y - 20.0
		canvas.draw_line(Vector2(size.x * 0.5 - 300.0, ornament_y), Vector2(size.x * 0.5 - 225.0, ornament_y), Color(GOLD, 0.82), 2.0)
		canvas.draw_line(Vector2(size.x * 0.5 + 225.0, ornament_y), Vector2(size.x * 0.5 + 300.0, ornament_y), Color(GOLD, 0.82), 2.0)
		_draw_texture(canvas, UI_BLOSSOM_CLUSTER, Rect2(size.x * 0.5 - 250.0, ornament_y - 19.0, 58.0, 40.0))
		_draw_texture(canvas, UI_BLOSSOM_CLUSTER, Rect2(size.x * 0.5 + 192.0, ornament_y - 19.0, 58.0, 40.0))
	var subtitle_y: float = 69.0 if dense else 137.0
	canvas.draw_line(Vector2(size.x * 0.5 - 240.0, subtitle_y - 8.0), Vector2(size.x * 0.5 - 95.0, subtitle_y - 8.0), Color(GOLD, 0.46), 1.0)
	canvas.draw_line(Vector2(size.x * 0.5 + 95.0, subtitle_y - 8.0), Vector2(size.x * 0.5 + 240.0, subtitle_y - 8.0), Color(GOLD, 0.46), 1.0)
	canvas.draw_string(UI_FONT, Vector2(0.0, subtitle_y), "✦  灵签择录 · 命数由心  ✦", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13 if dense else 18, Color(PAPER_LIGHT, 0.94))
	var hint_y: float = size.y - 18.0
	var hint: String = "按 1 / 2 / 3 快速选择  ·  鼠标悬停查看详情" if offer_count == 3 else "点击灵签或按数字键 1-%d" % offer_count
	canvas.draw_string(UI_FONT, Vector2(0.0, hint_y), "✤  %s  ✤" % hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13 if dense else 16, Color(GOLD, 0.94))


func _draw_card(canvas: CanvasItem, run, offer: Dictionary, data: Dictionary, index: int, hovered: bool, animation_time: float) -> void:
	var card: Dictionary = offer["card"]
	var id: String = card.get("id", "")
	var base_rect := _rect_from_data(data)
	var dense: bool = base_rect.size.y < 360.0
	var rect: Rect2 = base_rect
	if hovered:
		var grow := Vector2(12.0, 18.0) if not dense else Vector2(6.0, 8.0)
		rect = Rect2(base_rect.position - grow * 0.5 - Vector2(0.0, 9.0), base_rect.size + grow)
	var accent: Color = CARD_COLORS.get(id, _type_color(offer.get("type", "")))
	if hovered:
		_draw_hover_glow(canvas, rect, animation_time, index)
	_draw_texture(canvas, CARD_FRAME, rect)
	if dense:
		_draw_dense_content(canvas, run, offer, rect, id, index, hovered, accent)
	else:
		_draw_full_content(canvas, run, offer, rect, id, index, hovered, accent)


func _draw_full_content(canvas: CanvasItem, run, offer: Dictionary, rect: Rect2, id: String, index: int, hovered: bool, accent: Color) -> void:
	var card: Dictionary = offer["card"]
	var header_rect := Rect2(rect.position + Vector2(rect.size.x * 0.265, rect.size.y * 0.031), Vector2(rect.size.x * 0.47, rect.size.y * 0.085))
	_draw_panel(canvas, header_rect, HEADER_GREEN, Color(GOLD, 0.82), 1.0, 12.0)
	var type_text: String = "初始法器" if run.state == "opening" else TYPE_LABELS.get(offer.get("type", ""), "奇遇灵签")
	canvas.draw_string(UI_FONT, header_rect.position + Vector2(0.0, header_rect.size.y * 0.72), type_text, HORIZONTAL_ALIGNMENT_CENTER, header_rect.size.x, 17, PAPER_LIGHT)

	var stage_rect := Rect2(rect.position + Vector2(rect.size.x * 0.125, rect.size.y * 0.155), Vector2(rect.size.x * 0.75, rect.size.y * 0.41))
	_draw_illustration(canvas, id, offer.get("type", ""), stage_rect, accent, hovered)

	var name_y: float = rect.position.y + rect.size.y * 0.665
	canvas.draw_string(UI_FONT, Vector2(rect.position.x + 28.0, name_y), card.get("name", "未知灵签"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 56.0, 28, INK)
	var divider_y: float = name_y + 12.0
	canvas.draw_line(Vector2(rect.position.x + 58.0, divider_y), Vector2(rect.get_center().x - 14.0, divider_y), Color(GOLD_DEEP, 0.62), 1.0)
	canvas.draw_line(Vector2(rect.get_center().x + 14.0, divider_y), Vector2(rect.end.x - 58.0, divider_y), Color(GOLD_DEEP, 0.62), 1.0)
	canvas.draw_rect(Rect2(rect.get_center().x - 3.0, divider_y - 3.0, 6.0, 6.0), Color(GOLD_DEEP, 0.92), false, 1.0, true)

	var level_text: String = _level_info(run, offer)
	var level_y: float = divider_y + 29.0
	if offer.get("type", "") in ["upgrade", "attr", "taskStat", "taskWeapon", "taskBlessing"]:
		var pill_rect := Rect2(rect.get_center().x - rect.size.x * 0.26, divider_y + 9.0, rect.size.x * 0.52, 25.0)
		var pill_fill: Color = Color("a83b25", 0.96) if offer.get("type", "") in ["upgrade", "taskWeapon"] else Color("207f61", 0.96)
		_draw_panel(canvas, pill_rect, pill_fill, Color(GOLD, 0.88), 1.0, 12.0)
		canvas.draw_string(UI_FONT, pill_rect.position + Vector2(0.0, 18.0), level_text, HORIZONTAL_ALIGNMENT_CENTER, pill_rect.size.x, 14, PAPER_LIGHT)
	else:
		canvas.draw_string(UI_FONT, Vector2(rect.position.x + 30.0, level_y), level_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60.0, 17, INK)

	var description: String = offer.get("benefit", card.get("desc", CARD_DESCRIPTIONS.get(id, "本局持续生效")))
	if description.is_empty():
		description = CARD_DESCRIPTIONS.get(id, "本局持续生效")
	var desc_lines: Array[String] = _wrap_text(description, 18)
	var desc_y: float = rect.position.y + rect.size.y * 0.785
	for line_index in mini(3, desc_lines.size()):
		canvas.draw_string(UI_FONT, Vector2(rect.position.x + 20.0, desc_y + line_index * 17.0), desc_lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 40.0, 12, INK_SOFT)

	var button_rect := Rect2(rect.get_center().x - rect.size.x * 0.31, rect.end.y - rect.size.y * 0.12, rect.size.x * 0.62, rect.size.y * 0.085)
	_draw_panel(canvas, button_rect, CINNABAR if hovered else HEADER_GREEN, Color(GOLD, 0.92), 2.0 if hovered else 1.0, button_rect.size.y * 0.5)
	canvas.draw_string(UI_FONT, button_rect.position + Vector2(0.0, button_rect.size.y * 0.70), "[%d] 选择" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x, 17, PAPER_LIGHT)


func _draw_dense_content(canvas: CanvasItem, run, offer: Dictionary, rect: Rect2, id: String, index: int, hovered: bool, accent: Color) -> void:
	var card: Dictionary = offer["card"]
	var header_rect := Rect2(rect.position + Vector2(rect.size.x * 0.24, 8.0), Vector2(rect.size.x * 0.52, 27.0))
	_draw_panel(canvas, header_rect, HEADER_GREEN, Color(GOLD, 0.82), 1.0, 10.0)
	canvas.draw_string(UI_FONT, header_rect.position + Vector2(0.0, 19.0), "初始法器" if run.state == "opening" else TYPE_LABELS.get(offer.get("type", ""), "灵签"), HORIZONTAL_ALIGNMENT_CENTER, header_rect.size.x, 12, PAPER_LIGHT)
	var stage_rect := Rect2(rect.position + Vector2(22.0, 43.0), Vector2(rect.size.x - 44.0, rect.size.y * 0.39))
	_draw_illustration(canvas, id, offer.get("type", ""), stage_rect, accent, hovered)
	var name_y: float = stage_rect.end.y + 25.0
	canvas.draw_string(UI_FONT, Vector2(rect.position.x + 20.0, name_y), card.get("name", "未知灵签"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 40.0, 18, INK)
	canvas.draw_string(UI_FONT, Vector2(rect.position.x + 20.0, name_y + 23.0), _level_info(run, offer), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 40.0, 11, INK_SOFT)
	var benefit_lines: Array[String] = _wrap_text(offer.get("benefit", ""), 18)
	for line_index in mini(2, benefit_lines.size()):
		canvas.draw_string(UI_FONT, Vector2(rect.position.x + 14.0, name_y + 41.0 + line_index * 13.0), benefit_lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 28.0, 9, INK_SOFT)
	var button_rect := Rect2(rect.position.x + 34.0, rect.end.y - 38.0, rect.size.x - 68.0, 28.0)
	_draw_panel(canvas, button_rect, CINNABAR if hovered else HEADER_GREEN, Color(GOLD, 0.92), 1.0, 14.0)
	canvas.draw_string(UI_FONT, button_rect.position + Vector2(0.0, 20.0), "[%d] 选择" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x, 12, PAPER_LIGHT)


func _draw_illustration(canvas: CanvasItem, id: String, type: String, rect: Rect2, accent: Color, hovered: bool) -> void:
	if ILLUSTRATIONS.has(id):
		_draw_panel(canvas, Rect2(rect.position - Vector2(2.0, 2.0), rect.size + Vector2(4.0, 4.0)), Color(NIGHT, 0.98), Color(GOLD_DEEP, 0.88), 2.0, 12.0)
		_draw_texture(canvas, ILLUSTRATIONS[id], rect)
		return
	_draw_panel(canvas, rect, Color(NIGHT_MID, 0.98), Color(GOLD_DEEP, 0.82), 2.0, 12.0)
	var center := rect.get_center()
	canvas.draw_circle(center, minf(rect.size.x, rect.size.y) * 0.40, Color(accent, 0.12))
	canvas.draw_arc(center, minf(rect.size.x, rect.size.y) * 0.36, -PI * 0.1, PI * 1.35, 48, Color(accent, 0.78), 2.0)
	for spark_index in 8:
		var angle: float = float(spark_index) * TAU / 8.0
		var radius: float = minf(rect.size.x, rect.size.y) * (0.34 + float(spark_index % 2) * 0.07)
		canvas.draw_circle(center + Vector2.RIGHT.rotated(angle) * radius, 1.6, Color(PAPER_LIGHT, 0.75))
	var texture: Texture2D = _choice_texture(id, type)
	_draw_texture_centered(canvas, texture, center, minf(rect.size.x, rect.size.y) * (0.70 if hovered else 0.64))


func _draw_hover_glow(canvas: CanvasItem, rect: Rect2, animation_time: float, index: int) -> void:
	var pulse: float = 0.5 + sin(animation_time * 3.4 + index) * 0.5
	for glow_index in 4:
		var spread: float = 5.0 + glow_index * 5.0
		_glow.bg_color = Color(JADE, 0.11 - glow_index * 0.018 + pulse * 0.025)
		_glow.border_color = Color(MINT, 0.80 - glow_index * 0.15)
		_glow.set_border_width_all(2 if glow_index < 2 else 1)
		_glow.set_corner_radius_all(24 + glow_index * 3)
		canvas.draw_style_box(_glow, Rect2(rect.position - Vector2.ONE * spread, rect.size + Vector2.ONE * spread * 2.0))
	for spark_index in 18:
		var angle: float = float(spark_index) * TAU / 18.0 + animation_time * 0.12
		var radii := Vector2(rect.size.x * 0.56, rect.size.y * 0.55)
		var spark := rect.get_center() + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		canvas.draw_circle(spark, 1.2 + float(spark_index % 3) * 0.45, Color(MINT, 0.38 + pulse * 0.22))


func _draw_panel(canvas: CanvasItem, rect: Rect2, fill: Color, border: Color, width: float, radius: float) -> void:
	_panel.bg_color = fill
	_panel.border_color = border
	_panel.set_border_width_all(roundi(width))
	_panel.set_corner_radius_all(roundi(radius))
	_panel.corner_detail = 10
	canvas.draw_style_box(_panel, rect)


func _draw_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if texture != null:
		canvas.draw_texture_rect(texture, rect, false, tint)


func _draw_texture_centered(canvas: CanvasItem, texture: Texture2D, center: Vector2, display_size: float) -> void:
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	var factor: float = display_size / maxf(texture_size.x, texture_size.y)
	var draw_size: Vector2 = texture_size * factor
	canvas.draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false)


func _choice_texture(id: String, type: String) -> Texture2D:
	if ArtCatalog.WEAPON_ICONS.has(id):
		return ArtCatalog.WEAPON_ICONS[id]
	match type:
		"attr", "taskStat": return ArtCatalog.UI_TEXTURES["sealAttribute"]
		"taskBlessing": return ArtCatalog.UI_TEXTURES["sealBlessing"]
		"taskWeapon": return ArtCatalog.UI_TEXTURES["sealTask"]
		_: return ArtCatalog.UI_TEXTURES["sealAttribute"]


func _level_info(run, offer: Dictionary) -> String:
	if offer.has("levelInfo"):
		return str(offer["levelInfo"])
	var card: Dictionary = offer["card"]
	if card.get("kind") == "weapon":
		if offer.get("type") == "upgrade":
			for weapon in run.weapons:
				if weapon.card["id"] == card["id"]:
					return "Lv.%d  →  Lv.%d" % [weapon.level, weapon.level + 1]
		return "获得 Lv.1"
	var id: String = card.get("id", "")
	if id == "xp":
		return "经验获取 +15%"
	var current: int = run.attrStacks.get(id, 0)
	return "道行 +1  ·  %d/%d" % [current + 1, Config.CONFIG["cards"]["attrMaxStack"]]


func _type_color(type: String) -> Color:
	match type:
		"upgrade", "taskWeapon": return Color("df9c55")
		"attr", "taskStat": return Color("66c6d5")
		"taskBlessing": return Color("bb91d8")
		_: return Color("78c59b")


func _rect_from_data(data: Dictionary) -> Rect2:
	return Rect2(float(data["x"]), float(data["y"]), float(data["w"]), float(data["h"]))


func _wrap_text(text: String, max_chars: int) -> Array[String]:
	var result: Array[String] = []
	var line: String = ""
	for character in text:
		line += character
		if line.length() >= max_chars:
			result.append(line)
			line = ""
	if not line.is_empty():
		result.append(line)
	return result
