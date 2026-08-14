extends Node2D

const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")
const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const UI_FONT: Font = preload('res://assets/fonts/noto_sans_sc.ttf')

const INK: Color = Color(0.035, 0.065, 0.055, 0.94)
const INK_SOFT: Color = Color(0.055, 0.095, 0.075, 0.88)
const JADE: Color = Color("8eaa78")
const GOLD: Color = Color("e0bf6c")
const BONE: Color = Color("e8eadb")
const MUTED: Color = Color("aab8a7")
const CINNABAR: Color = Color("d85c45")
const CARD_COLORS: Dictionary = {
	"sword": Color("9fd8e8"), "cloak": Color("e97b52"), "talisman": Color("e6ca62"),
	"trail": Color("d95b3c"), "ring": Color("acd77b"), "staff": Color("aa85d8"),
	"damage": Color("df6b55"), "armor": Color("94a7a9"), "magnet": Color("6fc9d8"),
	"xp": Color("c5a1df"), "maxHp": Color("d9838b"), "moveSpeed": Color("79c99b"),
}
const CARD_SIGILS: Dictionary = {
	"sword": "剑", "cloak": "衣", "talisman": "雷", "trail": "火", "ring": "环", "staff": "灵",
	"damage": "攻", "armor": "甲", "magnet": "引", "xp": "悟", "maxHp": "生", "moveSpeed": "速",
}
const CARD_DESCRIPTIONS: Dictionary = {
	"sword": "御剑破阵，远程贯穿敌群",
	"cloak": "烈焰护体，持续灼烧近敌",
	"talisman": "雷弹索敌，引雷并弹射",
	"trail": "移动留火，闭环化为丹炉",
	"ring": "寒玉绕身，触敌造成伤害",
	"staff": "召来魂仆，追猎并引爆",
	"damage": "本局伤害提高 15%",
	"armor": "本局护甲提高 15",
	"magnet": "拾取范围扩大 50px",
	"xp": "经验获取提高 15%",
	"maxHp": "最大生命提高 20",
	"moveSpeed": "移动速度提高 6%",
}
const TYPE_LABELS: Dictionary = {
	"new": "新武器", "upgrade": "武器升级", "attr": "属性强化",
	"taskWeapon": "任务武器", "taskStat": "任务强化", "taskBlessing": "任务祝福",
}

var run = null


func bind_run(game_run) -> void:
	run = game_run
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if run == null or run.state == "menu" or run.state == "shop" or run.state == "storage":
		return
	var size: Vector2 = get_viewport_rect().size
	if run.state != "opening":
		_draw_hud(size)
	if run.state == "opening" or run.state == "choice":
		_draw_choice(size)
	elif run.state == "extraction":
		_draw_extraction(size)
	elif run.state == "dead":
		_draw_dead(size)
	elif run.state == "summary":
		_draw_summary(size)
	_draw_announcements(size)


func _draw_hud(size: Vector2) -> void:
	var xp_need: float = run.xp_to_next()
	var xp_ratio: float = clampf(run.xp / xp_need if xp_need > 0.0 else 0.0, 0.0, 1.0)
	draw_rect(Rect2(0.0, 0.0, size.x, 9.0), Color(0.02, 0.04, 0.035, 0.85))
	draw_rect(Rect2(0.0, 0.0, size.x * xp_ratio, 9.0), Color("67bfd1"))
	draw_line(Vector2(0.0, 9.0), Vector2(size.x, 9.0), Color(JADE, 0.65), 1.0)
	var status_panel := Rect2(12.0, 20.0, 252.0, 132.0)
	_draw_panel(status_panel, INK, Color(JADE, 0.72))
	draw_string(UI_FONT, Vector2(26.0, 47.0), "境界  Lv %d" % run.level, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, GOLD)
	var hp_ratio: float = clampf(run.player.hp / run.player.maxHp, 0.0, 1.0)
	draw_rect(Rect2(26.0, 58.0, 220.0, 16.0), Color(0.02, 0.03, 0.025, 0.9))
	draw_rect(Rect2(27.0, 59.0, 218.0 * hp_ratio, 14.0), Color("6fa66a") if hp_ratio > 0.35 else CINNABAR)
	draw_string(UI_FONT, Vector2(28.0, 91.0), "生命  %d / %d" % [ceili(maxf(0.0, run.player.hp)), ceili(run.player.maxHp)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, BONE)
	_draw_weapon_slots()
	var center_x: float = size.x * 0.5
	var wave_panel := Rect2(center_x - 176.0, 16.0, 352.0, 52.0)
	_draw_panel(wave_panel, Color(0.025, 0.05, 0.043, 0.9), Color(JADE, 0.58), 2.0)
	_draw_card_corners(wave_panel, Color(GOLD, 0.28))
	draw_string(UI_FONT, Vector2(center_x - 100.0, 38.0), _format_time(run.elapsed), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 23, BONE)
	draw_string(UI_FONT, Vector2(center_x - 170.0, 59.0), _wave_text(), HORIZONTAL_ALIGNMENT_CENTER, 340.0, 14, GOLD if run.waveDirector.isBossWave else MUTED)
	var right_panel := Rect2(size.x - 206.0, 20.0, 194.0, 92.0)
	_draw_panel(right_panel, INK, Color(JADE, 0.6), 2.0)
	_draw_card_corners(right_panel, Color(GOLD, 0.28))
	var alive: int = run.enemies.filter(func(enemy) -> bool: return not enemy.dead).size()
	draw_string(UI_FONT, Vector2(size.x - 192.0, 48.0), "斩敌  %d" % run.kills, HORIZONTAL_ALIGNMENT_LEFT, 170.0, 16, BONE)
	draw_string(UI_FONT, Vector2(size.x - 192.0, 72.0), "妖物  %d" % alive, HORIZONTAL_ALIGNMENT_LEFT, 170.0, 15, MUTED)
	draw_string(UI_FONT, Vector2(size.x - 192.0, 95.0), "暗夜领主  %d" % run.bossesDefeated, HORIZONTAL_ALIGNMENT_LEFT, 170.0, 14, Color("c6a6dc"))
	_draw_boss_bar(size)
	_draw_task_panel(size)
	_draw_inventory(size)
	draw_string(UI_FONT, Vector2(18.0, size.y - 17.0), "WASD / 方向键移动   ·   武器自动攻击   ·   点击武器槽选择联动", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(MUTED, 0.72))


func _draw_weapon_slots() -> void:
	var rects: Array[Dictionary] = UiLayoutScript.get_weapon_slot_rects()
	var selected_ids: Array[String] = run.synergies.selected_weapon_ids
	for i in rects.size():
		var data: Dictionary = rects[i]
		var rect := Rect2(data["x"] + 12.0, data["y"] + 16.0, data["w"] + 4.0, data["h"] + 4.0)
		var weapon = run.weapons[i] if i < run.weapons.size() else null
		var selected: bool = weapon != null and selected_ids.has(weapon.card["id"])
		if selected:
			draw_rect(Rect2(rect.position - Vector2.ONE * 3.0, rect.size + Vector2.ONE * 6.0), Color(GOLD, 0.12))
		_draw_panel(rect, Color(0.04, 0.075, 0.06, 0.94), GOLD if selected else Color(JADE, 0.55), 2.0 if selected else 1.0)
		draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(rect.size.x - 6.0, 3.0)), Color(GOLD if selected else JADE, 0.7))
		draw_string(UI_FONT, rect.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 14.0, 9, Color(MUTED, 0.72))
		if weapon == null:
			draw_string(UI_FONT, rect.position + Vector2(0.0, 33.0), "空", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color(MUTED, 0.45))
			continue
		var id: String = weapon.card["id"]
		_draw_texture_centered(
			ArtCatalog.WEAPON_ICONS.get(id),
			rect.position + Vector2(rect.size.x * 0.5, 23.0),
			38.0,
			0.0,
			Color(1.0, 1.0, 1.0, 0.98)
		)
		draw_string(UI_FONT, rect.position + Vector2(0.0, rect.size.y - 7.0), "Lv%d" % weapon.level, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, GOLD)


func _draw_boss_bar(size: Vector2) -> void:
	var boss = null
	for enemy in run.enemies:
		if not enemy.dead and enemy.rank == "boss":
			boss = enemy
			break
	if boss == null:
		return
	var width: float = minf(540.0, size.x * 0.52)
	var rect := Rect2((size.x - width) * 0.5, 96.0, width, 19.0)
	var boss_panel := Rect2(rect.position - Vector2(5.0, 20.0), rect.size + Vector2(10.0, 38.0))
	_draw_panel(boss_panel, Color(0.055, 0.035, 0.07, 0.94), Color("b99b52"), 2.0)
	_draw_card_corners(boss_panel, Color(GOLD, 0.32))
	_draw_texture_centered(ArtCatalog.UI_TEXTURES['boss'], rect.position + Vector2(22.0, -1.0), 52.0)
	var ratio: float = clampf(boss.hp / boss.maxHp, 0.0, 1.0)
	draw_rect(rect, Color(0.02, 0.02, 0.025, 0.95))
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, rect.size.y - 2.0)), Color("7652aa") if ratio > 0.5 else CINNABAR)
	draw_string(UI_FONT, Vector2(rect.position.x, rect.position.y - 5.0), boss.name if not boss.name.is_empty() else "暗夜领主", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, Color("ead69c"))


func _draw_task_panel(size: Vector2) -> void:
	if run.taskDirector == null or run.taskDirector.current == null:
		return
	var task: Dictionary = run.taskDirector.current
	var type_names: Dictionary = {"guard": "镇守", "delivery": "护送", "bounty": "悬赏"}
	var state_names: Dictionary = {"offered": "等待接取", "active": "进行中", "result": "已结束"}
	var rect := Rect2(size.x - 286.0, 140.0, 274.0, 64.0)
	_draw_panel(rect, Color(0.035, 0.085, 0.08, 0.92), Color("57b8b5"))
	draw_string(UI_FONT, rect.position + Vector2(14.0, 25.0), "奇遇 · %s  T%d" % [type_names.get(task["type"], task["type"]), task["tier"]], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 74.0, 16, Color("74d5d0"))
	draw_string(UI_FONT, rect.position + Vector2(14.0, 48.0), state_names.get(task["state"], task["state"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 74.0, 13, MUTED)
	_draw_texture_centered(
		ArtCatalog.TASK_TEXTURES.get(task["type"]),
		rect.position + Vector2(rect.size.x - 32.0, rect.size.y * 0.5),
		46.0
	)


func _draw_inventory(size: Vector2) -> void:
	var entries: Array[Dictionary] = []
	for id: String in run.rareInventory:
		var count: int = run.rareInventory[id]
		if count > 0:
			entries.append({"id": id, "label": "%s ×%d" % [_rare_name(id), count]})
	if not entries.is_empty():
		var height: float = 34.0 + entries.size() * 24.0
		var rect := Rect2(12.0, 164.0, 202.0, height)
		_draw_panel(rect, Color(0.055, 0.07, 0.055, 0.88), Color(GOLD, 0.55))
		_draw_card_corners(rect, Color(GOLD, 0.34))
		draw_string(UI_FONT, rect.position + Vector2(12.0, 22.0), "稀有物品", HORIZONTAL_ALIGNMENT_LEFT, 176.0, 14, GOLD)
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var center := rect.position + Vector2(22.0, 43.0 + i * 24.0)
			_draw_texture_centered(ArtCatalog.RARE_TEXTURES.get(entry["id"]), center, 24.0)
			draw_string(UI_FONT, rect.position + Vector2(39.0, 47.0 + i * 24.0), entry["label"], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 12, BONE)
	var backpack: Array[String] = []
	for id: String in run.tempBackpack:
		if run.tempBackpack[id] > 0:
			backpack.append("%s×%d" % [_material_name(id), run.tempBackpack[id]])
	if not backpack.is_empty():
		draw_string(UI_FONT, Vector2(size.x - 360.0, size.y - 18.0), "临时行囊  " + "  ".join(backpack), HORIZONTAL_ALIGNMENT_RIGHT, 342.0, 13, Color("c7a6df"))


func _draw_choice(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.022, 0.78))
	var offers: Array = run.currentOffers
	var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(size.x, size.y, offers.size())
	var top_y: float = rects[0]["y"] if not rects.is_empty() else size.y * 0.5
	var title: String = "选择初始武器" if run.state == "opening" else ("奇遇完成 · 选择奖励" if run.choiceOrigin == "task" else "境界突破 · 选择一项强化")
	draw_string(UI_FONT, Vector2(0.0, top_y - 48.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 29, Color("f0dfaf"))
	draw_string(UI_FONT, Vector2(0.0, top_y - 20.0), "点击卡牌或按数字键 1-%d" % offers.size(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, MUTED)
	var mouse := Vector2(run.input.mouse_x, run.input.mouse_y)
	for i in offers.size():
		var data: Dictionary = rects[i]
		var rect := Rect2(data["x"], data["y"], data["w"], data["h"])
		var offer: Dictionary = offers[i]
		var card: Dictionary = offer["card"]
		var id: String = card.get("id", "")
		var hover: bool = rect.has_point(mouse)
		var accent: Color = CARD_COLORS.get(id, _type_color(offer.get("type", "")))
		draw_rect(Rect2(rect.position + Vector2(7.0, 9.0), rect.size), Color(0.0, 0.0, 0.0, 0.34))
		_draw_panel(rect, Color(0.035, 0.075, 0.06, 0.98) if hover else Color(0.025, 0.055, 0.045, 0.97), GOLD if hover else Color(accent, 0.72), 3.0 if hover else 1.5)
		draw_rect(Rect2(rect.position + Vector2(7.0, 7.0), rect.size - Vector2(14.0, 14.0)), Color(accent, 0.26), false, 1.0)
		draw_rect(Rect2(rect.position + Vector2(9.0, 42.0), Vector2(rect.size.x - 18.0, 4.0)), Color(accent, 0.68))
		_draw_card_corners(rect, Color(GOLD, 0.7 if hover else 0.42))
		if hover:
			_draw_texture_centered(ArtCatalog.UI_TEXTURES["focusCursor"], rect.position + Vector2(16.0, 16.0), 42.0, 0.0, Color(1.0, 1.0, 1.0, 0.92))
		draw_rect(Rect2(rect.position + Vector2(10.0, 10.0), Vector2(28.0, 26.0)), Color(0.12, 0.18, 0.14, 0.95))
		draw_string(UI_FONT, rect.position + Vector2(10.0, 30.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 28.0, 14, BONE)
		draw_string(UI_FONT, rect.position + Vector2(42.0, 28.0), TYPE_LABELS.get(offer.get("type", ""), "奖励"), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 54.0, 12, accent)
		var sigil_center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.32)
		draw_circle(sigil_center, minf(41.0, rect.size.y * 0.15), Color(accent, 0.15))
		draw_arc(sigil_center, minf(41.0, rect.size.y * 0.15), 0.0, TAU, 28, Color(accent, 0.72), 2.0)
		_draw_texture_centered(
			_choice_texture(id, offer.get("type", "")),
			sigil_center,
			minf(82.0, rect.size.y * 0.3),
			0.0,
			Color(1.0, 1.0, 1.0, 0.96)
		)
		draw_string(UI_FONT, rect.position + Vector2(10.0, rect.size.y * 0.53), card.get("name", "未知奖励"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 20, BONE)
		draw_string(UI_FONT, rect.position + Vector2(10.0, rect.size.y * 0.63), _level_info(offer), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20.0, 13, GOLD)
		var lines: Array[String] = _wrap_text(card.get("desc", CARD_DESCRIPTIONS.get(id, "本局持续生效")), 12 if rect.size.y > 270.0 else 11)
		for line_index in mini(lines.size(), 4):
			draw_string(UI_FONT, rect.position + Vector2(16.0, rect.size.y * 0.74 + line_index * 18.0), lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32.0, 12, Color(BONE, 0.76))
		draw_rect(Rect2(rect.position + Vector2(14.0, rect.size.y - 31.0), Vector2(rect.size.x - 28.0, 1.0)), Color(accent, 0.32))
		draw_string(UI_FONT, rect.position + Vector2(14.0, rect.size.y - 12.0), "点击选择" if hover else "奖励预览", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 28.0, 11, Color(GOLD if hover else MUTED, 0.88))


func _draw_extraction(size: Vector2) -> void:
	_draw_modal(size, "首领已伏", "此刻可携战利品安然撤离，亦可继续深入暗夜。", GOLD)
	var center_x: float = size.x * 0.5
	_draw_key_button(Rect2(center_x - 240.0, size.y * 0.59, 210.0, 54.0), "E", "安然撤离", Color("78c7a0"))
	_draw_key_button(Rect2(center_x + 30.0, size.y * 0.59, 210.0, 54.0), "C", "继续深入", CINNABAR)


func _draw_dead(size: Vector2) -> void:
	var loss_text: String = "临时行囊已散落"
	if run.lastDeathLoss != null:
		var losses: Array[String] = []
		for id: String in run.lastDeathLoss:
			if run.lastDeathLoss[id] > 0:
				losses.append("%s×%d" % [_material_name(id), run.lastDeathLoss[id]])
		if not losses.is_empty():
			loss_text = "损失  " + "  ".join(losses)
	_draw_modal(size, "魂灯熄灭", "存活 %s   境界 Lv%d   斩敌 %d\n%s" % [_format_time(run.elapsed), run.level, run.kills, loss_text], CINNABAR)
	_draw_key_button(Rect2(size.x * 0.5 - 110.0, size.y * 0.62, 220.0, 52.0), "R", "返回主菜单", CINNABAR)


func _draw_summary(size: Vector2) -> void:
	var summary: Dictionary = run.lastRunSummary if run.lastRunSummary != null else {}
	var title: String = "暗夜终结" if summary.get("completed", false) else "安然撤离"
	var body := "抵达第 %d 波   境界 Lv%d   斩敌 %d\n获得暗晶 %d   击败首领 %d" % [summary.get("wave", run.waveDirector.wave), summary.get("level", run.level), summary.get("kills", run.kills), summary.get("darkCrystalsGained", 0), summary.get("bossesDefeated", run.bossesDefeated)]
	_draw_modal(size, title, body, Color("79c99b"))
	_draw_key_button(Rect2(size.x * 0.5 - 110.0, size.y * 0.62, 220.0, 52.0), "Enter", "返回主菜单", Color("79c99b"))


func _draw_modal(size: Vector2, title: String, body: String, accent: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.02, 0.017, 0.76))
	var rect := Rect2(size.x * 0.5 - 350.0, size.y * 0.5 - 160.0, 700.0, 320.0)
	_draw_panel(rect, Color(0.035, 0.07, 0.057, 0.98), Color(accent, 0.85), 2.0)
	_draw_card_corners(rect, Color(GOLD, 0.62))
	_draw_texture_centered(_modal_texture(title), rect.position + Vector2(rect.size.x * 0.5, 48.0), 72.0, 0.0, Color(1.0, 1.0, 1.0, 0.88))
	draw_string(UI_FONT, Vector2(rect.position.x, rect.position.y + 104.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, accent)
	var lines: PackedStringArray = body.split("\n")
	for i in lines.size():
		draw_string(UI_FONT, Vector2(rect.position.x + 30.0, rect.position.y + 150.0 + i * 30.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60.0, 17, BONE)


func _draw_key_button(rect: Rect2, key: String, label: String, accent: Color) -> void:
	_draw_panel(rect, Color(0.055, 0.11, 0.085, 0.96), Color(accent, 0.85), 2.0)
	_draw_texture_centered(ArtCatalog.UI_TEXTURES['buttonCrest'], rect.position + Vector2(31.0, rect.size.y * 0.5), 43.0, 0.0, Color(1.0, 1.0, 1.0, 0.44))
	draw_string(UI_FONT, rect.position + Vector2(10.0, 33.0), "[%s]" % key, HORIZONTAL_ALIGNMENT_CENTER, 58.0, 14, GOLD)
	draw_string(UI_FONT, rect.position + Vector2(64.0, 34.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 74.0, 17, BONE)


func _draw_announcements(size: Vector2) -> void:
	if run.state == "playing" and run.waveDirector.bannerTimer > 0.0:
		var alpha: float = minf(1.0, run.waveDirector.bannerTimer * 1.5)
		var label: String = "休整片刻" if run.waveDirector.phase == "rest" else ("首领来袭" if run.waveDirector.isBossWave else "第 %d 波" % run.waveDirector.wave)
		draw_string(UI_FONT, Vector2(0.0, size.y * 0.23), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 31, Color(GOLD, alpha))
	var message = run.rareMessage if run.rareMessage != null else run.synergies.announcement
	if message == null:
		return
	var text: String = message.get("text", "")
	var detail: String = message.get("detail", "")
	var color := Color(message.get("color", "ffd54f"))
	draw_string(UI_FONT, Vector2(0.0, size.y * 0.28), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, color)
	if not detail.is_empty():
		draw_string(UI_FONT, Vector2(0.0, size.y * 0.28 + 25.0), detail, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, BONE)


func _draw_panel(rect: Rect2, fill: Color, border: Color, width: float = 1.0) -> void:
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position + Vector2.ONE * 0.5, rect.size - Vector2.ONE), border, false, width)


func _draw_card_corners(rect: Rect2, color: Color) -> void:
	var texture: Texture2D = ArtCatalog.UI_TEXTURES['panelCorner']
	var alpha: float = clampf(color.a, 0.25, 0.92)
	_draw_texture_centered(texture, rect.position + Vector2(18.0, 18.0), 46.0, 0.0, Color(1.0, 1.0, 1.0, alpha))
	_draw_texture_centered(texture, rect.position + Vector2(rect.size.x - 18.0, 18.0), 46.0, PI * 0.5, Color(1.0, 1.0, 1.0, alpha))
	_draw_texture_centered(texture, rect.position + Vector2(rect.size.x - 18.0, rect.size.y - 18.0), 46.0, PI, Color(1.0, 1.0, 1.0, alpha))
	_draw_texture_centered(texture, rect.position + Vector2(18.0, rect.size.y - 18.0), 46.0, -PI * 0.5, Color(1.0, 1.0, 1.0, alpha))


func _draw_texture_centered(texture: Texture2D, center: Vector2, display_size: float, rotation: float = 0.0, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	var factor: float = display_size / maxf(texture_size.x, texture_size.y)
	draw_set_transform(center, rotation, Vector2.ONE * factor)
	draw_texture(texture, -texture_size * 0.5, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _choice_texture(id: String, type: String) -> Texture2D:
	if ArtCatalog.WEAPON_ICONS.has(id):
		return ArtCatalog.WEAPON_ICONS[id]
	match type:
		'attr', 'taskStat': return ArtCatalog.UI_TEXTURES['sealAttribute']
		'taskBlessing': return ArtCatalog.UI_TEXTURES['sealBlessing']
		'taskWeapon': return ArtCatalog.UI_TEXTURES['sealTask']
		_: return ArtCatalog.UI_TEXTURES['sealAttribute']


func _modal_texture(title: String) -> Texture2D:
	if title == "首领已伏" or title == "暗夜终结":
		return ArtCatalog.UI_TEXTURES["boss"]
	if title == "安然撤离":
		return ArtCatalog.UI_TEXTURES["warehouse"]
	if title == "魂灯熄灭":
		return ArtCatalog.UI_TEXTURES["pause"]
	return ArtCatalog.UI_TEXTURES["buttonCrest"]


func _wave_text() -> String:
	var director = run.waveDirector
	if director.phase == "rest":
		return "第 %d/%d 波完成 · 休整 %.1fs" % [director.wave, Config.CONFIG["waves"]["maxWave"], maxf(0.0, director.restTimer)]
	if director.phase == "overtime":
		return "第 %d/%d 波 · 首领超时" % [director.wave, Config.CONFIG["waves"]["maxWave"]]
	return "第 %d/%d 波%s · %s" % [director.wave, Config.CONFIG["waves"]["maxWave"], " · 首领" if director.isBossWave else "", _format_time(ceili(director.timeRemaining))]


func _level_info(offer: Dictionary) -> String:
	if offer.has("levelInfo"):
		return str(offer["levelInfo"])
	var card: Dictionary = offer["card"]
	if card.get("kind") == "weapon":
		if offer.get("type") == "upgrade":
			for weapon in run.weapons:
				if weapon.card["id"] == card["id"]:
					return "Lv %d  →  Lv %d" % [weapon.level, weapon.level + 1]
		return "获得 Lv 1"
	var current: int = run.attrStacks.get(card.get("id", ""), 0)
	return "已叠 %d 层  ·  选后 %d/%d" % [current, current + 1, Config.CONFIG["cards"]["attrMaxStack"]]


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


func _format_time(value: float) -> String:
	var seconds: int = maxi(0, floori(value))
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _type_color(type: String) -> Color:
	match type:
		"upgrade", "taskWeapon": return Color("e0a35f")
		"attr", "taskStat": return Color("67bfd1")
		"taskBlessing": return Color("ba8bd1")
		_: return Color("79b879")


func _rare_name(id: String) -> String:
	match id:
		"warRune": return "战意符石"
		"bloodJade": return "血玉"
		"magnetCore": return "聚灵核心"
		"spiritBook": return "悟道残卷"
		"windFeather": return "疾风羽"
		_: return id


func _material_name(id: String) -> String:
	match id:
		"shard": return "碎片"
		"essence": return "辉光精华"
		"soulCrystal": return "灵魂结晶"
		_: return id
