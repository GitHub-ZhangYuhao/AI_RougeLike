extends Node2D

const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")
const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const UI_FONT: Font = preload('res://assets/fonts/ui_font_round.tres')
const PLAYER_PORTRAIT: Texture2D = preload('res://assets/sprites/player/player_static.png')

const INK: Color = Color('4b2f2a')
const INK_SOFT: Color = Color('72524a')
const PAPER: Color = Color('fff6de')
const PAPER_LIGHT: Color = Color('fffaf0')
const PAPER_DEEP: Color = Color('f3deae')
const JADE: Color = Color('2a8f76')
const GOLD: Color = Color('ffc65c')
const BONE: Color = Color('4b2f2a')
const MUTED: Color = Color('98786d')
const CINNABAR: Color = Color('ff6b5f')
const CORAL: Color = Color('ff6b5f')
const CORAL_DARK: Color = Color('b73f3b')
const MINT: Color = Color('78d6b2')
const PLUM: Color = Color('6e3f68')
const TEAL_DEEP: Color = Color('174d46')
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
var animation_time: float = 0.0


func bind_run(game_run) -> void:
	run = game_run
	queue_redraw()


func refresh(delta: float = 0.0) -> void:
	animation_time += delta
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
	var hp_ratio: float = clampf(run.player.hp / run.player.maxHp, 0.0, 1.0)
	# === Background vignette (subtle top/bottom darkening) ===
	for vi in 8:
		var alpha: float = 0.02 * (8 - vi)
		draw_rect(Rect2(0.0, vi * 8.0, size.x, 8.0), Color(0.03, 0.08, 0.06, alpha))
		draw_rect(Rect2(0.0, size.y - (vi + 1) * 6.0, size.x, 6.0), Color(0.03, 0.08, 0.06, alpha * 0.8))
	# === Player panel (top-left) with decorations ===
	var player_panel := Rect2(16.0, 16.0, 310.0, 122.0)
	_draw_panel(player_panel, Color(PAPER, 0.98), INK, 3.0, 26.0)
	_draw_card_corners(player_panel, Color(CORAL, 0.45))
	# Portrait area with ornamental ring
	draw_circle(Vector2(74.0, 78.0), 42.0, INK)
	draw_circle(Vector2(74.0, 78.0), 38.0, Color('ffe9c4'))
	_draw_texture_centered(PLAYER_PORTRAIT, Vector2(74.0, 76.0), 74.0)
	draw_circle(Vector2(74.0, 78.0), 39.0, CORAL, false, 3.5)
	draw_arc(Vector2(74.0, 78.0), 41.0, PI * 1.1, PI * 1.9, 16, GOLD, 2.0)
	# Decorative charm below portrait
	draw_circle(Vector2(74.0, 122.0), 6.0, INK)
	draw_circle(Vector2(74.0, 122.0), 3.5, GOLD)
	# Name and title
	draw_string(UI_FONT, Vector2(116.0, 42.0), '桃源守夜者', HORIZONTAL_ALIGNMENT_LEFT, 130.0, 20, INK)
	_draw_panel(Rect2(250.0, 26.0, 62.0, 28.0), Color('d8fff0'), JADE, 2.0, 14.0)
	draw_string(UI_FONT, Vector2(254.0, 46.0), 'Lv %d' % run.level, HORIZONTAL_ALIGNMENT_CENTER, 54.0, 13, JADE)
	draw_string(UI_FONT, Vector2(116.0, 62.0), '境界 · 凡尘一阶', HORIZONTAL_ALIGNMENT_LEFT, 186.0, 11, INK_SOFT)
	# HP bar with label
	_draw_panel(Rect2(116.0, 72.0, 36.0, 17.0), Color(CORAL, 0.18), CORAL_DARK, 1.0, 9.0)
	draw_string(UI_FONT, Vector2(119.0, 85.0), '生命', HORIZONTAL_ALIGNMENT_CENTER, 30.0, 11, CORAL_DARK)
	_draw_bar(Rect2(156.0, 72.0, 152.0, 17.0), hp_ratio, CINNABAR, Color('713e37'))
	draw_string(UI_FONT, Vector2(160.0, 85.0), '%d / %d' % [ceili(maxf(0.0, run.player.hp)), ceili(run.player.maxHp)], HORIZONTAL_ALIGNMENT_CENTER, 144.0, 10, PAPER_LIGHT)
	# XP bar with label
	_draw_panel(Rect2(116.0, 96.0, 36.0, 17.0), Color(JADE, 0.15), JADE, 1.0, 9.0)
	draw_string(UI_FONT, Vector2(119.0, 109.0), '悟道', HORIZONTAL_ALIGNMENT_CENTER, 30.0, 11, JADE)
	_draw_bar(Rect2(156.0, 96.0, 152.0, 12.0), xp_ratio, MINT, Color('d2e8dc'))
	draw_string(UI_FONT, Vector2(252.0, 126.0), '%d%%' % roundi(xp_ratio * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 56.0, 10, JADE)
	# === Wave panel (top-center) with decorations ===
	var center_x: float = size.x * 0.5
	var wave_panel := Rect2(center_x - 175.0, 14.0, 350.0, 76.0)
	_draw_panel(wave_panel, Color('fff0c8'), INK, 3.0, 26.0)
	_draw_card_corners(wave_panel, Color(GOLD, 0.5))
	# Wave medallion with ornament
	draw_circle(wave_panel.position + Vector2(42.0, 38.0), 27.0, INK)
	draw_circle(wave_panel.position + Vector2(42.0, 38.0), 23.0, GOLD)
	draw_arc(wave_panel.position + Vector2(42.0, 38.0), 25.0, PI * 0.15, PI * 0.85, 14, Color(GOLD, 0.6), 2.0)
	draw_string(UI_FONT, wave_panel.position + Vector2(24.0, 45.0), '夜', HORIZONTAL_ALIGNMENT_CENTER, 36.0, 18, INK)
	draw_string(UI_FONT, wave_panel.position + Vector2(78.0, 32.0), '第 %d / %d 波' % [run.waveDirector.wave, Config.CONFIG['waves']['maxWave']], HORIZONTAL_ALIGNMENT_LEFT, 244.0, 21, INK)
	draw_string(UI_FONT, wave_panel.position + Vector2(78.0, 52.0), _wave_phase_text(), HORIZONTAL_ALIGNMENT_LEFT, 244.0, 12, JADE)
	_draw_bar(Rect2(wave_panel.position + Vector2(78.0, 60.0), Vector2(246.0, 8.0)), clampf(float(run.waveDirector.wave) / float(Config.CONFIG['waves']['maxWave']), 0.0, 1.0), CORAL, Color('ead9b2'))
	# Decorative divider dots
	for di in 3:
		draw_circle(wave_panel.position + Vector2(72.0 + di * 86.0, 68.0), 2.0, Color(GOLD, 0.5))
	# === Kill stats panel (top-right) with seal decoration ===
	var right_panel := Rect2(size.x - 232.0, 14.0, 216.0, 118.0)
	_draw_panel(right_panel, Color('e4faef'), INK, 3.0, 24.0)
	_draw_card_corners(right_panel, Color(JADE, 0.4))
	# Header with task seal
	_draw_panel(Rect2(right_panel.position + Vector2(8.0, 6.0), Vector2(200.0, 30.0)), Color(JADE, 0.12), Color(JADE, 0.5), 1.0, 15.0)
	_draw_texture_centered(ArtCatalog.UI_TEXTURES['sealTask'], right_panel.position + Vector2(188.0, 20.0), 38.0)
	draw_string(UI_FONT, right_panel.position + Vector2(16.0, 26.0), '讨妖簿', HORIZONTAL_ALIGNMENT_LEFT, 140.0, 18, INK)
	# Stats pills
	var alive: int = run.enemies.filter(func(enemy) -> bool: return not enemy.dead).size()
	_draw_stat_pill(Rect2(right_panel.position + Vector2(10.0, 46.0), Vector2(94.0, 28.0)), '斩敌', str(run.kills), CORAL)
	_draw_stat_pill(Rect2(right_panel.position + Vector2(112.0, 46.0), Vector2(94.0, 28.0)), '妖物', str(alive), JADE)
	_draw_stat_pill(Rect2(right_panel.position + Vector2(10.0, 82.0), Vector2(196.0, 28.0)), '首领', str(run.bossesDefeated), PLUM)
	# Decorative line under header
	draw_line(right_panel.position + Vector2(14.0, 40.0), right_panel.position + Vector2(202.0, 40.0), Color(JADE, 0.3), 1.0)
	# === Weapon slots, boss bar, task panel, inventory ===
	_draw_weapon_slots(size)
	_draw_boss_bar(size)
	_draw_task_panel(size)
	_draw_inventory(size)
	# === Bottom decorative border ===
	var bottom_bar := Rect2(size.x * 0.5 - 320.0, size.y - 12.0, 640.0, 6.0)
	_draw_panel(bottom_bar, Color(INK, 0.45), INK, 1.0, 3.0)

func _draw_weapon_slots(size: Vector2) -> void:
	var rects: Array[Dictionary] = UiLayoutScript.get_weapon_slot_rects()
	var selected_ids: Array[String] = run.synergies.selected_weapon_ids
	var dock_w: float = rects.size() * 72.0 + (rects.size() - 1) * 12.0 + 36.0 if rects.size() > 0 else 452.0
	var dock := Rect2(size.x * 0.5 - dock_w * 0.5, size.y - 92.0, dock_w, 82.0)
	_draw_panel(dock, Color(PAPER, 0.98), INK, 3.0, 28.0)
	_draw_panel(Rect2(dock.position + Vector2(14.0, -14.0), Vector2(100.0, 28.0)), CORAL, INK, 2.0, 14.0)
	draw_string(UI_FONT, dock.position + Vector2(20.0, 5.0), '法器组', HORIZONTAL_ALIGNMENT_CENTER, 88.0, 12, PAPER_LIGHT)
	for i in rects.size():
		var data: Dictionary = rects[i]
		var rect := Rect2(data['x'], data['y'], data['w'], data['h'])
		var weapon = run.weapons[i] if i < run.weapons.size() else null
		var selected: bool = weapon != null and selected_ids.has(weapon.card['id'])
		var fill: Color = Color('fff0c8') if weapon != null else Color('dcece4')
		var border: Color = CORAL if selected else INK
		_draw_panel(rect, fill, border, 3.0 if selected else 2.0, 18.0)
		if selected:
			draw_line(rect.position + Vector2(10.0, 5.0), rect.position + Vector2(rect.size.x - 10.0, 5.0), GOLD, 4.0)
		# Key number badge (top-right)
		draw_circle(rect.position + Vector2(rect.size.x - 10.0, 11.0), 11.0, INK)
		draw_string(UI_FONT, rect.position + Vector2(rect.size.x - 18.0, 16.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 11, PAPER_LIGHT)
		if weapon == null:
			draw_string(UI_FONT, rect.position + Vector2(0.0, 42.0), '+', HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 26, Color(JADE, 0.55))
			continue
		var id: String = weapon.card['id']
		var icon_accent: Color = CARD_COLORS.get(id, MINT)
		# Larger icon badge for Q-style feel
		_draw_icon_badge(ArtCatalog.WEAPON_ICONS.get(id), rect.position + Vector2(rect.size.x * 0.5, 32.0), 56.0, 42.0, icon_accent, selected)
		draw_string(UI_FONT, rect.position + Vector2(0.0, rect.size.y - 7.0), 'Lv%d' % weapon.level, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, CORAL_DARK if selected else INK)

func _draw_boss_bar(size: Vector2) -> void:
	var boss = null
	for enemy in run.enemies:
		if not enemy.dead and enemy.rank == "boss":
			boss = enemy
			break
	if boss == null:
		return
	var width: float = minf(540.0, size.x * 0.50)
	var panel := Rect2((size.x - width) * 0.5, 100.0, width, 54.0)
	_draw_panel(panel, Color('fff0dc'), PLUM, 3.0, 24.0)
	_draw_card_corners(panel, Color(PLUM, 0.5))
	# Boss medallion with flame ring
	_draw_icon_badge(ArtCatalog.UI_TEXTURES['boss'], panel.position + Vector2(34.0, 27.0), 52.0, 38.0, PLUM, true)
	draw_string(UI_FONT, panel.position + Vector2(66.0, 22.0), boss.name if not boss.name.is_empty() else '暗夜领主', HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 82.0, 14, PLUM)
	var ratio: float = clampf(boss.hp / boss.maxHp, 0.0, 1.0)
	_draw_bar(Rect2(panel.position + Vector2(66.0, 30.0), Vector2(panel.size.x - 82.0, 14.0)), ratio, PLUM if ratio > 0.5 else CORAL, Color('67364f'))
	# Decorative skulls/dots along the bar
	var bar_left: float = panel.position.x + 66.0
	var bar_right: float = panel.position.x + panel.size.x - 16.0
	for di in 4:
		var dot_x: float = bar_left + float(di) * (bar_right - bar_left) / 3.0
		draw_circle(Vector2(dot_x, panel.position.y + 50.0), 1.8, Color(PLUM, 0.35))

func _draw_task_panel(size: Vector2) -> void:
	if run.taskDirector == null or run.taskDirector.current == null:
		return
	var task: Dictionary = run.taskDirector.current
	var type_names: Dictionary = {"guard": "镇守", "delivery": "护送", "bounty": "悬赏"}
	var state_names: Dictionary = {"offered": "等待接取", "active": "进行中", "result": "已结束"}
	var rect := Rect2(size.x - 248.0, 146.0, 230.0, 78.0)
	_draw_panel(rect, Color('e0f8ee'), JADE, 2.0, 22.0)
	_draw_card_corners(rect, Color(JADE, 0.35))
	# Task header decoration
	_draw_panel(Rect2(rect.position + Vector2(6.0, 6.0), Vector2(rect.size.x - 12.0, 26.0)), Color(JADE, 0.10), Color(JADE, 0.3), 1.0, 13.0)
	_draw_icon_badge(ArtCatalog.TASK_TEXTURES.get(task['type']), rect.position + Vector2(38.0, 46.0), 52.0, 38.0, MINT, task['state'] == 'active')
	draw_string(UI_FONT, rect.position + Vector2(72.0, 24.0), '奇遇 · %s  T%d' % [type_names.get(task['type'], task['type']), task['tier']], HORIZONTAL_ALIGNMENT_LEFT, 148.0, 14, INK)
	_draw_panel(Rect2(rect.position + Vector2(72.0, 42.0), Vector2(124.0, 25.0)), Color('fff6de'), JADE, 1.5, 13.0)
	draw_string(UI_FONT, rect.position + Vector2(78.0, 60.0), state_names.get(task['state'], task['state']), HORIZONTAL_ALIGNMENT_CENTER, 112.0, 12, JADE)
	# Active task pulse indicator
	if task['state'] == 'active':
		var pulse: float = 0.5 + sin(animation_time * 3.0) * 0.5
		draw_circle(rect.position + Vector2(rect.size.x - 14.0, 14.0), 4.0 + pulse * 2.0, Color(JADE, 0.4 + pulse * 0.3))
		draw_circle(rect.position + Vector2(rect.size.x - 14.0, 14.0), 2.5, JADE)

func _draw_inventory(size: Vector2) -> void:
	var entries: Array[Dictionary] = []
	for id: String in run.rareInventory:
		var count: int = run.rareInventory[id]
		if count > 0:
			entries.append({"id": id, "label": "%s ×%d" % [_rare_name(id), count]})
	if not entries.is_empty():
		var height: float = 44.0 + entries.size() * 28.0
		var rect := Rect2(16.0, 152.0, 196.0, height)
		_draw_panel(rect, Color(PAPER, 0.96), INK, 2.0, 22.0)
		_draw_card_corners(rect, Color(GOLD, 0.35))
		# Header decoration
		_draw_panel(Rect2(rect.position + Vector2(6.0, 6.0), Vector2(rect.size.x - 12.0, 24.0)), Color(GOLD, 0.12), Color(GOLD, 0.4), 1.0, 12.0)
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['sealBlessing'], rect.position + Vector2(170.0, 18.0), 32.0)
		draw_string(UI_FONT, rect.position + Vector2(14.0, 24.0), '稀有收藏', HORIZONTAL_ALIGNMENT_LEFT, 140.0, 14, CORAL_DARK)
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var center := rect.position + Vector2(24.0, 50.0 + i * 28.0)
			_draw_icon_badge(ArtCatalog.RARE_TEXTURES.get(entry['id']), center, 30.0, 22.0, GOLD)
			draw_string(UI_FONT, rect.position + Vector2(44.0, 54.0 + i * 28.0), entry['label'], HORIZONTAL_ALIGNMENT_LEFT, 140.0, 12, INK)
	var backpack: Array[String] = []
	for id: String in run.tempBackpack:
		if run.tempBackpack[id] > 0:
			backpack.append('%s×%d' % [_material_name(id), run.tempBackpack[id]])
	if not backpack.is_empty():
		var copy := '临时行囊  ' + '  '.join(backpack)
		_draw_panel(Rect2(size.x - 396.0, size.y - 44.0, 378.0, 30.0), Color('eee1f5'), PLUM, 1.5, 15.0)
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['warehouse'], Vector2(size.x - 382.0, size.y - 29.0), 22.0)
		draw_string(UI_FONT, Vector2(size.x - 368.0, size.y - 24.0), copy, HORIZONTAL_ALIGNMENT_RIGHT, 340.0, 11, PLUM)

func _draw_choice(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.13, 0.13, 0.78))
	var offers: Array = run.currentOffers
	var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(size.x, size.y, offers.size())
	var top_y: float = rects[0]['y'] if not rects.is_empty() else size.y * 0.5
	var title: String = '选择初始武器' if run.state == 'opening' else ('奇遇完成 · 选择奖励' if run.choiceOrigin == 'task' else '境界突破 · 选择一项强化')
	var title_rect := Rect2(size.x * 0.5 - 260.0, top_y - 78.0, 520.0, 48.0)
	_draw_panel(title_rect, Color(PAPER_LIGHT, 0.99), INK, 3.0, 24.0)
	draw_string(UI_FONT, Vector2(title_rect.position.x, title_rect.position.y + 34.0), title, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, 28, INK)
	var hint_rect := Rect2(size.x * 0.5 - 180.0, top_y - 24.0, 360.0, 22.0)
	_draw_panel(hint_rect, Color('d8fff0'), JADE, 1.0, 11.0)
	draw_string(UI_FONT, Vector2(hint_rect.position.x, hint_rect.position.y + 16.0), '点击卡牌或按数字键 1-%d' % offers.size(), HORIZONTAL_ALIGNMENT_CENTER, hint_rect.size.x, 12, JADE)
	var mouse := Vector2(run.input.mouse_x, run.input.mouse_y)
	for i in offers.size():
		_draw_choice_card(offers[i], rects[i], mouse, i)

func _draw_choice_card(offer: Dictionary, data: Dictionary, mouse: Vector2, index: int) -> void:
	var card: Dictionary = offer['card']
	var id: String = card.get('id', '')
	var hit_rect := Rect2(data['x'], data['y'], data['w'], data['h'])
	var hover: bool = hit_rect.has_point(mouse)
	var lift: float = -10.0 if hover else 0.0
	var rect := Rect2(hit_rect.position + Vector2(0.0, lift), hit_rect.size)
	var accent: Color = CARD_COLORS.get(id, _type_color(offer.get('type', '')))
	var card_radius: float = 26.0
	# Outer glow on hover
	if hover:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(accent, 0.22)
		glow.set_corner_radius_all(roundi(card_radius + 6.0))
		draw_style_box(glow, Rect2(rect.position - Vector2(6.0, 6.0), rect.size + Vector2(12.0, 12.0)))
	# Card shadow
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.05, 0.12, 0.10, 0.42)
	shadow.set_corner_radius_all(roundi(card_radius))
	shadow.shadow_color = Color(0.03, 0.08, 0.06, 0.35)
	shadow.shadow_size = 12 if hover else 8
	shadow.shadow_offset = Vector2(0.0, 6.0 if hover else 4.0)
	draw_style_box(shadow, rect)
	# Card background
	var bg := StyleBoxFlat.new()
	bg.bg_color = PAPER_LIGHT if hover else PAPER
	bg.border_color = accent if hover else INK
	bg.set_border_width_all(3 if hover else 2)
	bg.set_corner_radius_all(roundi(card_radius))
	bg.corner_detail = 12
	draw_style_box(bg, rect)
	# Inner highlight line
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color.TRANSPARENT
	highlight.border_color = Color(1.0, 1.0, 1.0, 0.5 if hover else 0.3)
	highlight.set_border_width_all(1)
	highlight.set_corner_radius_all(roundi(card_radius - 4.0))
	draw_style_box(highlight, Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)))
	# Header banner with accent color
	var header_h: float = 48.0
	var header_rect := Rect2(rect.position + Vector2(6.0, 6.0), Vector2(rect.size.x - 12.0, header_h))
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(accent, 0.28 if hover else 0.20)
	header_style.set_corner_radius_all(roundi(card_radius - 8.0))
	header_style.corner_detail_top_left = roundi(card_radius - 8.0)
	header_style.corner_detail_top_right = roundi(card_radius - 8.0)
	draw_style_box(header_style, header_rect)
	# Card number badge
	var badge_size: float = 34.0
	var badge_pos := header_rect.position + Vector2(8.0, 7.0)
	draw_circle(badge_pos + Vector2(badge_size * 0.5, badge_size * 0.5), badge_size * 0.5, INK)
	draw_circle(badge_pos + Vector2(badge_size * 0.5, badge_size * 0.5), badge_size * 0.5 - 2.0, accent)
	draw_string(UI_FONT, badge_pos + Vector2(2.0, 24.0), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, badge_size - 4.0, 15, PAPER_LIGHT)
	# Type label in header
	var type_text: String = TYPE_LABELS.get(offer.get('type', ''), '奖励')
	draw_string(UI_FONT, header_rect.position + Vector2(badge_size + 14.0, 30.0), type_text, HORIZONTAL_ALIGNMENT_LEFT, header_rect.size.x - badge_size - 22.0, 13, INK)
	# Hover cursor
	if hover:
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['focusCursor'], header_rect.position + Vector2(header_rect.size.x - 18.0, 16.0), 36.0)
	# Icon badge (larger, more prominent)
	var icon_center_y: float = header_rect.position.y + header_h + 52.0
	var icon_center := rect.position + Vector2(rect.size.x * 0.5, icon_center_y - rect.position.y)
	var icon_badge_size: float = minf(120.0, rect.size.y * 0.30)
	_draw_icon_badge(_choice_texture(id, offer.get('type', '')), icon_center, icon_badge_size, icon_badge_size * 0.70, accent, hover)
	# Card name (larger, more prominent)
	var name_y: float = icon_center_y + icon_badge_size * 0.5 + 12.0
	draw_string(UI_FONT, rect.position + Vector2(12.0, name_y - rect.position.y), card.get('name', '未知奖励'), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24.0, 22, INK)
	# Decorative divider line
	var divider_y: float = name_y + 8.0
	var divider_w: float = rect.size.x * 0.6
	var divider_x: float = rect.position.x + (rect.size.x - divider_w) * 0.5
	draw_line(Vector2(divider_x, divider_y), Vector2(divider_x + divider_w, divider_y), Color(accent, 0.5), 1.5)
	draw_circle(Vector2(divider_x, divider_y), 2.5, accent)
	draw_circle(Vector2(divider_x + divider_w, divider_y), 2.5, accent)
	# Level info pill
	var level_y: float = divider_y + 10.0
	var level_rect := Rect2(rect.position.x + (rect.size.x - 160.0) * 0.5, level_y, 160.0, 28.0)
	_draw_panel(level_rect, Color('d8fff0'), JADE, 1.5, 14.0)
	draw_string(UI_FONT, Vector2(level_rect.position.x + 4.0, level_rect.position.y + 20.0), _level_info(offer), HORIZONTAL_ALIGNMENT_CENTER, level_rect.size.x - 8.0, 12, JADE)
	# Description text
	var desc_y: float = level_rect.position.y + level_rect.size.y + 10.0
	var lines: Array[String] = _wrap_text(card.get('desc', CARD_DESCRIPTIONS.get(id, '本局持续生效')), 15)
	for line_index in mini(lines.size(), 2):
		draw_string(UI_FONT, rect.position + Vector2(16.0, desc_y - rect.position.y + line_index * 17.0), lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32.0, 12, INK_SOFT)
	# Action button at bottom
	var btn_h: float = 30.0
	var btn_y: float = rect.position.y + rect.size.y - btn_h - 10.0
	var btn_rect := Rect2(rect.position.x + 20.0, btn_y, rect.size.x - 40.0, btn_h)
	var btn_fill: Color = accent if hover else Color('fff0c8')
	var btn_border: Color = INK
	_draw_panel(btn_rect, btn_fill, btn_border, 2.0, 15.0)
	if hover:
		var btn_highlight := StyleBoxFlat.new()
		btn_highlight.bg_color = Color.TRANSPARENT
		btn_highlight.border_color = Color(1.0, 1.0, 1.0, 0.6)
		btn_highlight.set_border_width_all(1)
		btn_highlight.set_corner_radius_all(13)
		draw_style_box(btn_highlight, Rect2(btn_rect.position + Vector2(2.0, 2.0), btn_rect.size - Vector2(4.0, 4.0)))
	draw_string(UI_FONT, Vector2(btn_rect.position.x + 4.0, btn_rect.position.y + 21.0), '点击选择', HORIZONTAL_ALIGNMENT_CENTER, btn_rect.size.x - 8.0, 12, PAPER_LIGHT if hover else INK)
	# Corner ornaments
	_draw_card_corners(rect, Color(accent, 0.7 if hover else 0.4))


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
	var line1 := "抵达第 %d 波   境界 Lv%d   斩敌 %d" % [summary.get("wave", run.waveDirector.wave), summary.get("level", run.level), summary.get("kills", run.kills)]
	var body := line1 + "\n×"  # placeholder second line; real line 2 drawn with gem icon
	_draw_modal(size, title, body, Color("79c99b"))
	# Draw second line with gem icon replacing "暗晶" text
	var rect := Rect2(size.x * 0.5 - 320.0, size.y * 0.5 - 154.0, 640.0, 308.0)
	var line2_y: float = rect.position.y + 166.0 + 31.0
	var font_size: int = 17
	var icon_size: float = 22.0
	var gap: float = 5.0
	var crystals: int = summary.get("darkCrystalsGained", 0)
	var prefix := "获得 "
	var prefix_w: float = UI_FONT.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var num_str := "%d" % crystals
	var num_w: float = UI_FONT.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var suffix := "   击败首领 %d" % summary.get("bossesDefeated", run.bossesDefeated)
	var suffix_w: float = UI_FONT.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total_w: float = prefix_w + icon_size + gap + num_w + suffix_w
	var cx: float = rect.position.x + 30.0 + (rect.size.x - 60.0 - total_w) * 0.5
	var baseline_y: float = line2_y + font_size * 0.25
	UI_FONT.draw_string(get_canvas_item(), Vector2(cx, line2_y), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	_draw_texture_centered(ArtCatalog.PICKUP_TEXTURES["gem"], Vector2(cx + prefix_w + icon_size * 0.5, baseline_y), icon_size)
	UI_FONT.draw_string(get_canvas_item(), Vector2(cx + prefix_w + icon_size + gap, line2_y), num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	UI_FONT.draw_string(get_canvas_item(), Vector2(cx + prefix_w + icon_size + gap + num_w, line2_y), suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	_draw_key_button(Rect2(size.x * 0.5 - 110.0, size.y * 0.62, 220.0, 52.0), "Enter", "返回主菜单", Color("79c99b"))


func _draw_modal(size: Vector2, title: String, body: String, accent: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.13, 0.13, 0.78))
	var rect := Rect2(size.x * 0.5 - 320.0, size.y * 0.5 - 154.0, 640.0, 308.0)
	_draw_panel(rect, PAPER_LIGHT, INK, 3.0, 30.0)
	_draw_panel(Rect2(rect.position + Vector2(190.0, 20.0), Vector2(260.0, 66.0)), Color(accent, 0.18), accent, 2.0, 26.0)
	_draw_texture_centered(_modal_texture(title), rect.position + Vector2(rect.size.x * 0.5, 52.0), 66.0)
	draw_string(UI_FONT, Vector2(rect.position.x, rect.position.y + 123.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, accent)
	var lines: PackedStringArray = body.split('
')
	for i in lines.size():
		draw_string(UI_FONT, Vector2(rect.position.x + 30.0, rect.position.y + 166.0 + i * 31.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60.0, 17, INK)

func _draw_key_button(rect: Rect2, key: String, label: String, accent: Color) -> void:
	_draw_panel(rect, Color(PAPER, 0.99), INK, 3.0, 20.0)
	_draw_panel(Rect2(rect.position + Vector2(9.0, 9.0), Vector2(48.0, rect.size.y - 18.0)), accent, INK, 2.0, 14.0)
	draw_string(UI_FONT, rect.position + Vector2(12.0, 35.0), key, HORIZONTAL_ALIGNMENT_CENTER, 42.0, 13, PAPER_LIGHT)
	draw_string(UI_FONT, rect.position + Vector2(63.0, 35.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 73.0, 17, INK)

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


func _draw_panel(rect: Rect2, fill: Color, border: Color, width: float = 1.0, radius: float = 18.0) -> void:
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.07, 0.16, 0.14, 0.28)
	shadow.set_corner_radius_all(roundi(radius))
	draw_style_box(shadow, Rect2(rect.position + Vector2(4.0, 6.0), rect.size))
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(roundi(width))
	style.set_corner_radius_all(roundi(radius))
	style.corner_detail = 10
	draw_style_box(style, rect)
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color.TRANSPARENT
	highlight.border_color = Color(1.0, 1.0, 1.0, 0.42)
	highlight.set_border_width_all(1)
	highlight.set_corner_radius_all(maxi(2, roundi(radius - 4.0)))
	draw_style_box(highlight, Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)))

func _draw_bar(rect: Rect2, ratio: float, fill: Color, background: Color) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = background
	back.border_color = INK
	back.set_border_width_all(1)
	back.set_corner_radius_all(roundi(rect.size.y * 0.5))
	draw_style_box(back, rect)
	if ratio <= 0.0:
		return
	var inner := Rect2(rect.position + Vector2(2.0, 2.0), Vector2(maxf(2.0, (rect.size.x - 4.0) * ratio), rect.size.y - 4.0))
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(roundi(inner.size.y * 0.5))
	draw_style_box(front, inner)
	if inner.size.x > 8.0:
		draw_line(inner.position + Vector2(4.0, 2.0), inner.position + Vector2(inner.size.x - 4.0, 2.0), Color(1.0, 1.0, 1.0, 0.56), 2.0)

func _draw_stat_pill(rect: Rect2, label: String, value: String, accent: Color) -> void:
	_draw_panel(rect, Color(PAPER_LIGHT, 0.92), Color(accent, 0.8), 1.0, rect.size.y * 0.5)
	draw_string(UI_FONT, rect.position + Vector2(7.0, 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.55, 10, INK_SOFT)
	draw_string(UI_FONT, rect.position + Vector2(rect.size.x * 0.48, 18.0), value, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x * 0.42, 12, accent)


func _wave_phase_text() -> String:
	var director = run.waveDirector
	if director.phase == 'rest':
		return '休整 %.1fs  ·  已坚持 %s' % [maxf(0.0, director.restTimer), _format_time(run.elapsed)]
	if director.phase == 'overtime':
		return '首领超时  ·  已坚持 %s' % _format_time(run.elapsed)
	return '%s  ·  已坚持 %s' % [_format_time(ceili(director.timeRemaining)), _format_time(run.elapsed)]


func _draw_card_corners(rect: Rect2, color: Color) -> void:
	var texture: Texture2D = ArtCatalog.UI_TEXTURES['panelCorner']
	var alpha: float = clampf(color.a, 0.25, 0.92)
	_draw_texture_centered(texture, rect.position + Vector2(18.0, 18.0), 46.0, 0.0, Color(1.0, 1.0, 1.0, alpha))
	_draw_texture_centered(texture, rect.position + Vector2(rect.size.x - 18.0, 18.0), 46.0, PI * 0.5, Color(1.0, 1.0, 1.0, alpha))
	_draw_texture_centered(texture, rect.position + Vector2(rect.size.x - 18.0, rect.size.y - 18.0), 46.0, PI, Color(1.0, 1.0, 1.0, alpha))
	_draw_texture_centered(texture, rect.position + Vector2(18.0, rect.size.y - 18.0), 46.0, -PI * 0.5, Color(1.0, 1.0, 1.0, alpha))


func _draw_icon_badge(texture: Texture2D, center: Vector2, badge_size: float, icon_size: float, accent: Color, emphasized: bool = false) -> void:
	var radius: float = badge_size * 0.5
	var lift: Vector2 = Vector2(0.0, -3.0) if emphasized else Vector2(0.0, -1.0)
	var badge_center: Vector2 = center + lift
	var shadow_offset := Vector2(0.0, maxf(2.5, badge_size * 0.06))
	# Outer glow for emphasized badges
	if emphasized:
		draw_circle(badge_center, radius + 6.0, Color(CORAL, 0.20))
		draw_circle(badge_center, radius + 4.0, Color(GOLD, 0.28))
	# Shadow
	draw_circle(badge_center + shadow_offset, radius + 1.5, Color(INK, 0.26))
	# Outer ring (thicker, more playful)
	draw_circle(badge_center, radius, INK)
	# Accent ring (warm gradient feel)
	draw_circle(badge_center, radius - 2.5, accent.lightened(0.08))
	# Inner cream ring
	draw_circle(badge_center, radius - 5.5, PAPER_LIGHT)
	# Subtle warm tint on inner area
	draw_circle(badge_center + Vector2(0.0, 1.0), radius - 8.0, Color('fff4d6'))
	# Top highlight arc (more pronounced for Q feel)
	var arc_radius: float = maxf(3.0, radius - 10.0)
	draw_arc(badge_center + Vector2(0.0, -1.5), arc_radius, PI * 1.08, PI * 1.92, 20, Color(1.0, 1.0, 1.0, 0.82), maxf(1.5, badge_size * 0.03))
	# Bottom charm decoration
	if badge_size >= 36.0:
		var charm_center := badge_center + Vector2(-radius * 0.60, radius * 0.52)
		draw_circle(charm_center, maxf(3.5, radius * 0.15), INK)
		draw_circle(charm_center, maxf(2.0, radius * 0.09), GOLD)
	if badge_size >= 50.0:
		var charm2 := badge_center + Vector2(radius * 0.62, radius * 0.48)
		draw_circle(charm2, maxf(2.5, radius * 0.10), INK)
		draw_circle(charm2, maxf(1.5, radius * 0.06), Color(accent, 0.8))
	# Golden ring for emphasized
	if emphasized:
		draw_arc(badge_center, radius + 1.5, PI * 0.06, PI * 0.94, 20, GOLD, maxf(2.5, badge_size * 0.04))
	# Icon texture (slightly larger for Q style)
	_draw_texture_centered(texture, badge_center + Vector2(0.0, 1.0), icon_size * 1.08)


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
