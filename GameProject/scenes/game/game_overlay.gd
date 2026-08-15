extends Node2D

const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")
const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const UI_FONT: Font = preload('res://assets/fonts/ui_font_round.tres')
const PLAYER_PORTRAIT: Texture2D = preload('res://assets/sprites/player/player_static.png')
const HUD_PORTRAIT: Texture2D = preload('res://assets/ui/peach_night/atomic/portrait_character.png')
const UI_BLOSSOM_CLUSTER: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/blossom_cluster.svg')
const UI_PORTRAIT_RING: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/portrait_ring.svg')
const UI_ICON_HEART: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/icon_heart.svg')
const UI_ICON_HOURGLASS: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/icon_hourglass.svg')
const UI_ICON_CRYSTAL: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/icon_crystal.svg')
const UI_ICON_PAUSE: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/icon_pause.svg')
const UI_ICON_SPIRIT: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/icon_spirit.svg')
const UI_ICON_KILL: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/icon_kill.svg')
const CARD_PAPER_TILE: Texture2D = preload('res://assets/ui/peach_night/atomic/card_paper_tile.png')
const CARD_CORNER_BLOSSOM: Texture2D = preload('res://assets/ui/peach_night/atomic/clean/card_corner_blossom.svg')

const INK: Color = Color('4b2f2a')
const INK_SOFT: Color = Color('72524a')
const PAPER: Color = Color('f7e8c7')
const PAPER_LIGHT: Color = Color('fff6de')
const PAPER_DEEP: Color = Color('e6c995')
const JADE: Color = Color('2a9079')
const GOLD: Color = Color('e8b34c')
const BONE: Color = Color('f1dfbd')
const MUTED: Color = Color('a99080')
const CINNABAR: Color = Color('ef624f')
const CORAL: Color = Color('ef624f')
const CORAL_DARK: Color = Color('9f352f')
const MINT: Color = Color('79d9b7')
const PLUM: Color = Color('714766')
const TEAL_DEEP: Color = Color('155a52')
const NIGHT: Color = Color('0c1628')
const NIGHT_SOFT: Color = Color('172944')
const NIGHT_MID: Color = Color('203a55')
const WALNUT: Color = Color('4a2c24')
const ANTIQUE_GOLD: Color = Color('b57b36')
const SPIRIT_GLOW: Color = Color('79e1bd')
const UI_SCALE: float = 0.7
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
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(UI_SCALE, UI_SCALE))
		_draw_hud(size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var inv_s: float = 1.0 / UI_SCALE
	if run.state == "opening" or run.state == "choice":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(inv_s, inv_s))
		_draw_choice(size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif run.state == "extraction":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(inv_s, inv_s))
		_draw_extraction(size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif run.state == "dead":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(inv_s, inv_s))
		_draw_dead(size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif run.state == "summary":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(inv_s, inv_s))
		_draw_summary(size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(inv_s, inv_s))
	_draw_announcements(size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hud(size: Vector2) -> void:
	_draw_composed_hud(size)


func _draw_composed_hud(size: Vector2) -> void:
	var character_rect := Rect2(14.0, 14.0, 342.0, 116.0)
	_draw_atomic_hud_shell(character_rect)
	var portrait_center := character_rect.position + Vector2(58.0, 57.0)
	draw_circle(portrait_center + Vector2(0.0, 4.0), 45.0, Color(0.01, 0.03, 0.06, 0.78))
	_draw_texture_centered(HUD_PORTRAIT, portrait_center - Vector2(0.0, 2.0), 94.0)
	_draw_texture_centered(UI_PORTRAIT_RING, portrait_center, 112.0)
	var level_center := portrait_center + Vector2(37.0, 37.0)
	draw_circle(level_center + Vector2(0.0, 2.0), 18.0, Color(NIGHT, 0.88))
	draw_circle(level_center, 16.0, WALNUT)
	draw_circle(level_center, 13.0, Color('15313b'))
	draw_arc(level_center, 14.5, 0.0, TAU, 24, GOLD, 1.5)
	draw_string(UI_FONT, level_center + Vector2(-14.0, 5.0), str(run.level), HORIZONTAL_ALIGNMENT_CENTER, 28.0, 13, PAPER_LIGHT)

	var xp_need: float = run.xp_to_next()
	var xp_ratio: float = clampf(run.xp / xp_need if xp_need > 0.0 else 0.0, 0.0, 1.0)
	var hp_ratio: float = clampf(run.player.hp / run.player.maxHp, 0.0, 1.0)
	var content_x: float = character_rect.position.x + 112.0
	draw_string(UI_FONT, Vector2(content_x, character_rect.position.y + 29.0), '桃源守夜者', HORIZONTAL_ALIGNMENT_LEFT, 212.0, 19, PAPER_LIGHT)
	draw_string(UI_FONT, Vector2(content_x, character_rect.position.y + 45.0), '境界 · 凡尘一阶', HORIZONTAL_ALIGNMENT_LEFT, 212.0, 10, Color('cdb99f'))
	_draw_compact_hud_meter(
		Rect2(content_x, character_rect.position.y + 50.0, 214.0, 25.0),
		UI_ICON_HEART,
		'生命',
		'%d/%d' % [ceili(maxf(run.player.hp, 0.0)), ceili(run.player.maxHp)],
		hp_ratio,
		Color('dc513e'),
		Color('4b2a2d')
	)
	_draw_compact_hud_meter(
		Rect2(content_x, character_rect.position.y + 80.0, 214.0, 22.0),
		null,
		'悟道',
		'%d/%d' % [floori(run.xp), ceili(xp_need)],
		xp_ratio,
		Color('39b783'),
		Color('18333a')
	)

	var wave_rect := Rect2(size.x * 0.5 - 195.0, 14.0, 390.0, 86.0)
	_draw_atomic_hud_shell(wave_rect)
	var night_center := wave_rect.position + Vector2(38.0, 43.0)
	draw_circle(night_center + Vector2(0.0, 2.0), 25.0, Color(NIGHT, 0.88))
	draw_circle(night_center, 23.0, WALNUT)
	draw_circle(night_center, 19.0, Color('19363d'))
	draw_arc(night_center, 21.0, 0.0, TAU, 28, GOLD, 1.8)
	draw_string(UI_FONT, night_center + Vector2(-17.0, 6.0), '夜', HORIZONTAL_ALIGNMENT_CENTER, 34.0, 16, GOLD)
	var max_wave: int = Config.CONFIG['waves']['maxWave']
	draw_string(UI_FONT, wave_rect.position + Vector2(72.0, 31.0), '第 %d / %d 波' % [run.waveDirector.wave, max_wave], HORIZONTAL_ALIGNMENT_LEFT, 190.0, 20, PAPER_LIGHT)
	draw_string(UI_FONT, wave_rect.position + Vector2(266.0, 28.0), _format_time(run.elapsed), HORIZONTAL_ALIGNMENT_RIGHT, 104.0, 13, MINT)
	var wave_status: String = '剩余 %s' % _format_time(ceili(maxf(0.0, run.waveDirector.timeRemaining)))
	if run.waveDirector.phase == 'rest':
		wave_status = '休整 %.1fs' % maxf(0.0, run.waveDirector.restTimer)
	elif run.waveDirector.phase == 'overtime':
		wave_status = '首领超时'
	elif run.waveDirector.isBossWave:
		wave_status += ' · 首领波'
	draw_string(UI_FONT, wave_rect.position + Vector2(72.0, 51.0), wave_status, HORIZONTAL_ALIGNMENT_LEFT, 190.0, 11, Color('d6c4a9'))
	draw_string(UI_FONT, wave_rect.position + Vector2(266.0, 50.0), '守夜时间', HORIZONTAL_ALIGNMENT_RIGHT, 104.0, 10, Color('b8cdbf'))
	var duration: float = maxf(1.0, Config.CONFIG['waves']['duration'])
	var wave_ratio: float = clampf(1.0 - run.waveDirector.timeRemaining / duration, 0.0, 1.0)
	if run.waveDirector.phase == 'rest':
		wave_ratio = 1.0
	_draw_bar(Rect2(wave_rect.position + Vector2(72.0, 62.0), Vector2(298.0, 10.0)), wave_ratio, Color('36ad96'), Color('153a3c'))

	_draw_composed_weapon_slots(size)
	_draw_boss_bar(size)
	_draw_task_panel(size)
	_draw_inventory(size)

func _draw_atomic_hud_shell(rect: Rect2) -> void:
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.01, 0.025, 0.72)
	shadow.set_corner_radius_all(20)
	shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	shadow.shadow_size = 7
	shadow.shadow_offset = Vector2(0.0, 4.0)
	draw_style_box(shadow, rect)
	_draw_panel(rect, Color('0b1728f2'), Color('9e6b36'), 3.0, 18.0)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color.TRANSPARENT
	inner.border_color = Color('d19b48aa')
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(13)
	draw_style_box(inner, Rect2(rect.position + Vector2(6.0, 6.0), rect.size - Vector2(12.0, 12.0)))
	draw_line(rect.position + Vector2(18.0, 7.0), rect.position + Vector2(rect.size.x - 18.0, 7.0), Color(GOLD, 0.28), 1.0)
	_draw_texture_centered(UI_BLOSSOM_CLUSTER, rect.end - Vector2(22.0, rect.size.y - 18.0), 42.0, PI, Color(1.0, 1.0, 1.0, 0.36))

func _draw_compact_hud_meter(rect: Rect2, icon: Texture2D, label: String, value: String, ratio: float, fill: Color, background: Color) -> void:
	_draw_panel(rect, Color('0f2035ee'), Color('a97539'), 1.3, rect.size.y * 0.42)
	var text_x: float = rect.position.x + 8.0
	if icon != null:
		_draw_texture_centered(icon, rect.position + Vector2(12.0, rect.size.y * 0.45), minf(17.0, rect.size.y * 0.72))
		text_x += 14.0
	draw_string(UI_FONT, Vector2(text_x, rect.position.y + rect.size.y * 0.57), label, HORIZONTAL_ALIGNMENT_LEFT, 48.0, maxi(9, roundi(rect.size.y * 0.38)), Color('e5d2b5'))
	draw_string(UI_FONT, Vector2(rect.position.x + 116.0, rect.position.y + rect.size.y * 0.57), value, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 124.0, maxi(9, roundi(rect.size.y * 0.36)), PAPER_LIGHT)
	_draw_bar(Rect2(rect.position + Vector2(8.0, rect.size.y - 7.0), Vector2(rect.size.x - 16.0, 5.0)), ratio, fill, background)


func _draw_hud_meter(rect: Rect2, icon: Texture2D, label: String, value: String, ratio: float, fill: Color, background: Color) -> void:
	_draw_panel(rect, Color('0f2035f7'), Color('a97539'), 2.0, rect.size.y * 0.42)
	draw_line(rect.position + Vector2(12.0, 5.0), rect.position + Vector2(rect.size.x - 12.0, 5.0), Color(GOLD, 0.34), 1.0)
	var icon_space: float = 42.0 if icon != null else 8.0
	if icon != null:
		var icon_center := rect.position + Vector2(22.0, rect.size.y * 0.5)
		draw_circle(icon_center, minf(18.0, rect.size.y * 0.40), Color(fill, 0.18))
		draw_arc(icon_center, minf(17.0, rect.size.y * 0.38), 0.0, TAU, 28, Color(GOLD, 0.56), 1.0)
		_draw_texture_centered(icon, icon_center, minf(30.0, rect.size.y * 0.68))
	var label_w: float = 58.0
	var label_rect := Rect2(rect.position + Vector2(icon_space, rect.size.y * 0.20), Vector2(label_w - 4.0, rect.size.y * 0.60))
	_draw_panel(label_rect, Color(fill, 0.14), Color(fill, 0.48), 1.0, label_rect.size.y * 0.5)
	draw_string(UI_FONT, label_rect.position + Vector2(1.0, label_rect.size.y * 0.72), label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 2.0, maxi(12, roundi(rect.size.y * 0.31)), PAPER_LIGHT)
	var value_w: float = 86.0
	var bar_x: float = label_rect.end.x + 8.0
	var bar_rect := Rect2(bar_x, rect.position.y + rect.size.y * 0.31, rect.end.x - value_w - 12.0 - bar_x, rect.size.y * 0.38)
	_draw_bar(bar_rect, ratio, fill, background)
	var value_rect := Rect2(rect.end.x - value_w - 7.0, rect.position.y + rect.size.y * 0.18, value_w, rect.size.y * 0.64)
	draw_string(UI_FONT, value_rect.position + Vector2(0.0, value_rect.size.y * 0.72), value, HORIZONTAL_ALIGNMENT_CENTER, value_rect.size.x, maxi(11, roundi(rect.size.y * 0.31)), PAPER_LIGHT)


func _draw_hud_capsule(rect: Rect2, icon: Texture2D, value: String, caption: String) -> void:
	_draw_panel(rect, Color('101e31f7'), Color('a97539'), 2.0, 14.0)
	draw_line(rect.position + Vector2(42.0, 6.0), rect.position + Vector2(rect.size.x - 10.0, 6.0), Color(GOLD, 0.32), 1.0)
	var icon_center := rect.position + Vector2(24.0, rect.size.y * 0.5)
	draw_circle(icon_center, minf(19.0, rect.size.y * 0.38), Color('153440'))
	draw_arc(icon_center, minf(17.0, rect.size.y * 0.34), 0.0, TAU, 28, Color(GOLD, 0.50), 1.0)
	_draw_texture_centered(icon, icon_center, minf(31.0, rect.size.y * 0.62))
	draw_string(UI_FONT, rect.position + Vector2(45.0, rect.size.y * 0.50), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 51.0, maxi(15, roundi(rect.size.y * 0.35)), PAPER_LIGHT)
	draw_string(UI_FONT, rect.position + Vector2(45.0, rect.size.y * 0.81), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 51.0, maxi(9, roundi(rect.size.y * 0.18)), Color('d6c4a9'))

func _draw_hud_pause_button(rect: Rect2) -> void:
	var radius: float = minf(rect.size.x, rect.size.y) * 0.48
	draw_circle(rect.get_center() + Vector2(0.0, 2.0), radius, Color(0.0, 0.01, 0.03, 0.72))
	draw_circle(rect.get_center(), radius * 0.94, WALNUT)
	draw_circle(rect.get_center(), radius * 0.78, Color('15343d'))
	draw_arc(rect.get_center(), radius * 0.86, 0.0, TAU, 30, GOLD, 1.7)
	_draw_texture_centered(UI_ICON_PAUSE, rect.get_center(), radius * 0.92)
	if rect.size.y >= 64.0:
		draw_string(UI_FONT, rect.position + Vector2(0.0, rect.size.y - 4.0), 'P 暂停', HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, PAPER_LIGHT)

func _draw_composed_weapon_slots(size: Vector2) -> void:
	var rects: Array[Dictionary] = UiLayoutScript.get_weapon_slot_rects(size.x, size.y)
	var selected_ids: Array[String] = run.synergies.selected_weapon_ids
	if rects.is_empty():
		return
	var first: Dictionary = rects[0]
	var last: Dictionary = rects[rects.size() - 1]
	var dock_rect := Rect2(
		first['x'] - 16.0,
		first['y'] - 34.0,
		last['x'] + last['w'] - first['x'] + 32.0,
		first['h'] + 54.0
	)
	_draw_atomic_hud_shell(dock_rect)
	var label_rect := Rect2(first['x'], first['y'] - 27.0, last['x'] + last['w'] - first['x'], 22.0)
	_draw_panel(label_rect, Color('153c3af0'), Color('78c9a7'), 1.0, 11.0)
	draw_string(UI_FONT, label_rect.position + Vector2(0.0, 16.0), '法器阵列', HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, 11, Color('baf0d6'))
	for i in rects.size():
		var data: Dictionary = rects[i]
		var slot_rect := Rect2(data['x'], data['y'], data['w'], data['h'])
		var weapon = run.weapons[i] if i < run.weapons.size() else null
		var selected: bool = weapon != null and selected_ids.has(weapon.card['id'])
		if selected:
			draw_circle(slot_rect.get_center(), slot_rect.size.x * 0.54, Color(SPIRIT_GLOW, 0.17))
		_draw_panel(Rect2(slot_rect.position + Vector2(0.0, 3.0), slot_rect.size), Color('050b13b8'), Color.TRANSPARENT, 0.0, 11.0)
		_draw_panel(slot_rect, Color('102633f7') if weapon != null else Color('101d2be8'), CINNABAR if selected else Color('a97539'), 3.0 if selected else 2.0, 11.0)
		draw_line(slot_rect.position + Vector2(8.0, 5.0), slot_rect.position + Vector2(slot_rect.size.x - 8.0, 5.0), Color(GOLD, 0.66), 2.0)
		if weapon != null:
			var id: String = weapon.card['id']
			_draw_texture_centered(ArtCatalog.WEAPON_ICONS.get(id), slot_rect.position + Vector2(slot_rect.size.x * 0.5, 27.0), 42.0)
			var pip_gap: float = 4.0
			var pip_width: float = (slot_rect.size.x - 20.0 - pip_gap * 4.0) / 5.0
			for pip in 5:
				var pip_rect := Rect2(slot_rect.position + Vector2(10.0 + pip * (pip_width + pip_gap), slot_rect.size.y - 11.0), Vector2(pip_width, 5.0))
				_draw_panel(pip_rect, Color('6bd19b') if pip < mini(weapon.level, 5) else Color('294044'), Color('153128'), 1.0, 2.0)
		else:
			var empty_pulse: float = 0.5 + sin(animation_time * 2.4 + i * 0.8) * 0.5
			var empty_center := slot_rect.get_center() - Vector2(0.0, 2.0)
			draw_circle(empty_center, 19.0, Color(SPIRIT_GLOW, 0.05 + empty_pulse * 0.05))
			draw_string(UI_FONT, slot_rect.position + Vector2(0.0, 42.0), '+', HORIZONTAL_ALIGNMENT_CENTER, slot_rect.size.x, 25, Color(SPIRIT_GLOW, 0.52 + empty_pulse * 0.18))
		var key_center := slot_rect.position + Vector2(slot_rect.size.x * 0.5, slot_rect.size.y + 7.0)
		draw_circle(key_center + Vector2(0.0, 2.0), 13.0, Color(NIGHT, 0.84))
		draw_circle(key_center, 12.0, WALNUT)
		draw_circle(key_center, 9.5, Color('172c38'))
		draw_arc(key_center, 10.5, 0.0, TAU, 22, GOLD, 1.3)
		draw_string(UI_FONT, key_center + Vector2(-9.0, 4.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 10, PAPER_LIGHT)

func _draw_composed_boss_plaque(hud_rect: Rect2) -> void:
	var plaque_rect := Rect2(hud_rect.position + Vector2(784.0, 101.0), Vector2(224.0, 62.0))
	var boss = _active_boss()
	var border: Color = CINNABAR if boss != null else Color('5cb79b')
	_draw_panel(plaque_rect, Color('151d2cf5'), border, 2.0, 14.0)
	draw_line(plaque_rect.position + Vector2(58.0, 8.0), plaque_rect.position + Vector2(plaque_rect.size.x - 12.0, 8.0), Color(GOLD, 0.36), 1.0)
	if boss != null:
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['boss'], plaque_rect.position + Vector2(34.0, 31.0), 50.0)
		draw_string(UI_FONT, plaque_rect.position + Vector2(62.0, 29.0), '首领来袭', HORIZONTAL_ALIGNMENT_CENTER, 146.0, 18, Color('ff7a61'))
		draw_string(UI_FONT, plaque_rect.position + Vector2(62.0, 49.0), '斩妖镇夜', HORIZONTAL_ALIGNMENT_CENTER, 146.0, 11, Color('d6b69b'))
	else:
		draw_circle(plaque_rect.position + Vector2(34.0, 31.0), 23.0, Color('153d3a'))
		_draw_texture_centered(UI_ICON_SPIRIT, plaque_rect.position + Vector2(34.0, 31.0), 35.0)
		draw_string(UI_FONT, plaque_rect.position + Vector2(62.0, 29.0), '夜巡中', HORIZONTAL_ALIGNMENT_CENTER, 146.0, 18, MINT)
		draw_string(UI_FONT, plaque_rect.position + Vector2(62.0, 49.0), '桃灯未熄', HORIZONTAL_ALIGNMENT_CENTER, 146.0, 11, Color('b8cdbf'))

func _active_boss():
	for enemy in run.enemies:
		if not enemy.dead and enemy.rank == 'boss':
			return enemy
	return null


func _draw_weapon_slots(size: Vector2) -> void:
	var rects: Array[Dictionary] = UiLayoutScript.get_weapon_slot_rects(size.x, size.y)
	var selected_ids: Array[String] = run.synergies.selected_weapon_ids
	var dock_w: float = rects.size() * 72.0 + (rects.size() - 1) * 12.0 + 36.0 if rects.size() > 0 else 452.0
	var dock := Rect2(size.x * 0.5 - dock_w * 0.5, size.y - 92.0, dock_w, 82.0)
	_draw_panel(dock, Color(NIGHT, 0.97), ANTIQUE_GOLD, 3.0, 28.0)
	_draw_panel(Rect2(dock.position + Vector2(14.0, -14.0), Vector2(100.0, 28.0)), CORAL, INK, 2.0, 14.0)
	draw_string(UI_FONT, dock.position + Vector2(20.0, 5.0), '法器组', HORIZONTAL_ALIGNMENT_CENTER, 88.0, 12, PAPER_LIGHT)
	for i in rects.size():
		var data: Dictionary = rects[i]
		var rect := Rect2(data['x'], data['y'], data['w'], data['h'])
		var weapon = run.weapons[i] if i < run.weapons.size() else null
		var selected: bool = weapon != null and selected_ids.has(weapon.card['id'])
		var fill: Color = Color(PAPER, 0.98) if weapon != null else Color(NIGHT_MID, 0.92)
		var border: Color = CORAL if selected else ANTIQUE_GOLD
		_draw_panel(rect, fill, border, 3.0 if selected else 2.0, 18.0)
		if selected:
			draw_line(rect.position + Vector2(10.0, 5.0), rect.position + Vector2(rect.size.x - 10.0, 5.0), GOLD, 4.0)
		# Key number badge (top-right)
		draw_circle(rect.position + Vector2(rect.size.x - 10.0, 11.0), 11.0, INK)
		draw_string(UI_FONT, rect.position + Vector2(rect.size.x - 18.0, 16.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 11, PAPER_LIGHT)
		if weapon == null:
			draw_string(UI_FONT, rect.position + Vector2(0.0, 42.0), '+', HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 26, Color(SPIRIT_GLOW, 0.72))
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
	var panel := Rect2((size.x - width) * 0.5, 108.0, width, 54.0)
	_draw_panel(panel, Color('21162d'), CORAL, 3.0, 24.0)
	_draw_card_corners(panel, Color(PLUM, 0.5))
	# Boss medallion with flame ring
	_draw_icon_badge(ArtCatalog.UI_TEXTURES['boss'], panel.position + Vector2(34.0, 27.0), 52.0, 38.0, PLUM, true)
	draw_string(UI_FONT, panel.position + Vector2(66.0, 22.0), boss.name if not boss.name.is_empty() else '暗夜领主', HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 82.0, 14, PAPER_LIGHT)
	var ratio: float = clampf(boss.hp / boss.maxHp, 0.0, 1.0)
	_draw_bar(Rect2(panel.position + Vector2(66.0, 30.0), Vector2(panel.size.x - 82.0, 14.0)), ratio, PLUM if ratio > 0.5 else CORAL, Color('67364f'))
	# Decorative skulls/dots along the bar
	var bar_left: float = panel.position.x + 66.0
	var bar_right: float = panel.position.x + panel.size.x - 16.0
	for di in 4:
		var dot_x: float = bar_left + float(di) * (bar_right - bar_left) / 3.0
		draw_circle(Vector2(dot_x, panel.position.y + 50.0), 1.8, Color(PLUM, 0.35))

func _draw_mini_stat(rect: Rect2, icon: Texture2D, text: String, accent: Color) -> void:
	_draw_panel(rect, Color('101e31e8'), Color(accent, 0.72), 1.0, rect.size.y * 0.5)
	_draw_texture_centered(icon, rect.position + Vector2(13.0, rect.size.y * 0.5), 17.0)
	draw_string(UI_FONT, rect.position + Vector2(24.0, rect.size.y * 0.69), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 28.0, 9, PAPER_LIGHT)


func _draw_task_panel(size: Vector2) -> void:
	var rect := Rect2(size.x - 314.0, 14.0, 300.0, 116.0)
	_draw_atomic_hud_shell(rect)
	_draw_panel(Rect2(rect.position + Vector2(8.0, 8.0), Vector2(rect.size.x - 68.0, 26.0)), Color(TEAL_DEEP, 0.82), Color(SPIRIT_GLOW, 0.34), 1.0, 13.0)
	draw_string(UI_FONT, rect.position + Vector2(16.0, 27.0), '奇遇簿', HORIZONTAL_ALIGNMENT_LEFT, 112.0, 16, PAPER_LIGHT)
	_draw_hud_pause_button(Rect2(rect.end.x - 54.0, rect.position.y + 7.0, 44.0, 44.0))
	var task = run.taskDirector.current if run.taskDirector != null else null
	if task != null:
		var type_names: Dictionary = {'guard': '镇守', 'delivery': '护送', 'bounty': '悬赏'}
		var state_names: Dictionary = {'offered': '等待接取', 'active': '进行中', 'result': '已结束'}
		_draw_icon_badge(ArtCatalog.TASK_TEXTURES.get(task['type']), rect.position + Vector2(30.0, 60.0), 40.0, 29.0, MINT, task['state'] == 'active')
		draw_string(UI_FONT, rect.position + Vector2(55.0, 58.0), '%s · T%d' % [type_names.get(task['type'], task['type']), task['tier']], HORIZONTAL_ALIGNMENT_LEFT, 150.0, 13, PAPER_LIGHT)
		draw_string(UI_FONT, rect.position + Vector2(55.0, 75.0), state_names.get(task['state'], task['state']), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 10, MINT)
		if task['state'] == 'active':
			var pulse: float = 0.5 + sin(animation_time * 3.0) * 0.5
			draw_circle(rect.position + Vector2(218.0, 59.0), 4.0 + pulse * 2.0, Color(JADE, 0.4 + pulse * 0.3))
			draw_circle(rect.position + Vector2(218.0, 59.0), 2.5, JADE)
	else:
		_draw_texture_centered(UI_ICON_SPIRIT, rect.position + Vector2(30.0, 61.0), 34.0)
		draw_string(UI_FONT, rect.position + Vector2(55.0, 60.0), '夜巡中', HORIZONTAL_ALIGNMENT_LEFT, 150.0, 13, MINT)
		draw_string(UI_FONT, rect.position + Vector2(55.0, 76.0), '暂无奇遇任务', HORIZONTAL_ALIGNMENT_LEFT, 150.0, 10, Color('b8cdbf'))
	_draw_mini_stat(Rect2(rect.position + Vector2(10.0, 84.0), Vector2(84.0, 24.0)), UI_ICON_KILL, '击破 %d' % run.kills, CINNABAR)
	_draw_mini_stat(Rect2(rect.position + Vector2(100.0, 84.0), Vector2(92.0, 24.0)), UI_ICON_CRYSTAL, '暗晶 %d' % run.save.get('darkCrystals', 0), PLUM)
	var boss = _active_boss()
	_draw_mini_stat(Rect2(rect.position + Vector2(198.0, 84.0), Vector2(92.0, 24.0)), ArtCatalog.UI_TEXTURES['boss'] if boss != null else UI_ICON_SPIRIT, '首领' if boss != null else '平静', CINNABAR if boss != null else JADE)

func _draw_inventory(size: Vector2) -> void:
	var entries: Array[Dictionary] = []
	for id: String in run.rareInventory:
		var count: int = run.rareInventory[id]
		if count > 0:
			entries.append({'id': id, 'count': count})
	if not entries.is_empty():
		var rect := Rect2(size.x - 314.0, 138.0, 300.0, 48.0)
		_draw_panel(rect, Color(NIGHT_SOFT, 0.94), ANTIQUE_GOLD, 2.0, 18.0)
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['sealBlessing'], rect.position + Vector2(24.0, 24.0), 30.0)
		draw_string(UI_FONT, rect.position + Vector2(42.0, 28.0), '稀有收藏', HORIZONTAL_ALIGNMENT_LEFT, 62.0, 11, Color('e7c06e'))
		var available_width: float = rect.size.x - 112.0
		var step: float = minf(38.0, available_width / entries.size())
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var center := rect.position + Vector2(116.0 + step * i + step * 0.5, 24.0)
			_draw_icon_badge(ArtCatalog.RARE_TEXTURES.get(entry['id']), center, 29.0, 21.0, GOLD)
			draw_circle(center + Vector2(10.0, 10.0), 7.0, Color('4a2c24'))
			draw_string(UI_FONT, center + Vector2(4.0, 14.0), str(entry['count']), HORIZONTAL_ALIGNMENT_CENTER, 12.0, 8, PAPER_LIGHT)
	var backpack: Array[String] = []
	for id: String in run.tempBackpack:
		if run.tempBackpack[id] > 0:
			backpack.append('%s×%d' % [_material_name(id), run.tempBackpack[id]])
	if not backpack.is_empty():
		var copy := '临时行囊  ' + '  '.join(backpack)
		_draw_panel(Rect2(size.x - 396.0, size.y - 44.0, 378.0, 30.0), Color(NIGHT_SOFT, 0.95), PLUM, 1.5, 15.0)
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['warehouse'], Vector2(size.x - 382.0, size.y - 29.0), 22.0)
		draw_string(UI_FONT, Vector2(size.x - 368.0, size.y - 24.0), copy, HORIZONTAL_ALIGNMENT_RIGHT, 340.0, 11, PAPER_LIGHT)

func _draw_choice(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.045, 0.10, 0.88))
	var offers: Array = run.currentOffers
	var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(size.x, size.y, offers.size())
	var top_y: float = rects[0]['y'] if not rects.is_empty() else size.y * 0.5
	var title: String = '选择初始武器' if run.state == 'opening' else ('奇遇完成 · 选择奖励' if run.choiceOrigin == 'task' else '境界突破 · 选择一项强化')
	var compact_grid: bool = offers.size() > 3
	var title_height: float = 44.0 if compact_grid else 58.0
	var title_y: float = 3.0 if compact_grid else top_y - 100.0
	var title_rect := Rect2(size.x * 0.5 - 220.0, title_y, 440.0, title_height)
	_draw_panel(title_rect, Color('512b23f5'), Color('d49a46'), 3.0, 18.0)
	draw_line(title_rect.position + Vector2(58.0, 9.0), title_rect.end - Vector2(58.0, title_rect.size.y - 9.0), Color('ffcf70aa'), 1.0)
	_draw_texture_centered(UI_BLOSSOM_CLUSTER, title_rect.position + Vector2(28.0, 20.0), 54.0)
	_draw_texture_centered(UI_BLOSSOM_CLUSTER, title_rect.end - Vector2(28.0, 18.0), 54.0, PI)
	draw_string(UI_FONT, Vector2(title_rect.position.x, title_rect.position.y + (31.0 if compact_grid else 39.0)), title, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, 23 if compact_grid else 26, PAPER_LIGHT)
	var hint_rect := Rect2(size.x * 0.5 - 180.0, 49.0 if compact_grid else top_y - 38.0, 360.0, 18.0 if compact_grid else 22.0)
	_draw_panel(hint_rect, Color(TEAL_DEEP, 0.94), Color(SPIRIT_GLOW, 0.68), 1.0, hint_rect.size.y * 0.5)
	draw_string(UI_FONT, Vector2(hint_rect.position.x, hint_rect.position.y + (14.0 if compact_grid else 17.0)), '点击卡牌或按数字键 1-%d' % offers.size(), HORIZONTAL_ALIGNMENT_CENTER, hint_rect.size.x, 11 if compact_grid else 12, SPIRIT_GLOW)
	var mouse := Vector2(run.input.mouse_x, run.input.mouse_y)
	for i in offers.size():
		_draw_choice_card(offers[i], rects[i], mouse, i)

func _draw_choice_card(offer: Dictionary, data: Dictionary, mouse: Vector2, index: int) -> void:
	_draw_approved_choice_card(offer, data, mouse, index)


func _draw_approved_choice_card(offer: Dictionary, data: Dictionary, mouse: Vector2, index: int) -> void:
	var card: Dictionary = offer['card']
	var id: String = card.get('id', '')
	var hit_rect := Rect2(data['x'], data['y'], data['w'], data['h'])
	var hover: bool = hit_rect.has_point(mouse)
	var rect := Rect2(hit_rect.position + Vector2(0.0, -9.0 if hover else 0.0), hit_rect.size)
	var accent: Color = CARD_COLORS.get(id, _type_color(offer.get('type', '')))
	if hover:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(accent, 0.20)
		glow.set_corner_radius_all(25)
		draw_style_box(glow, Rect2(rect.position - Vector2(7.0, 7.0), rect.size + Vector2(14.0, 14.0)))
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.01, 0.02, 0.04, 0.82)
	shadow.set_corner_radius_all(20)
	shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.68)
	shadow.shadow_size = 8 if hover else 5
	shadow.shadow_offset = Vector2(0.0, 4.0)
	draw_style_box(shadow, rect)
	_draw_panel(rect, Color('14253af8'), accent if hover else Color('ba7d35'), 4.0 if hover else 3.0, 20.0)
	var paper_rect := Rect2(rect.position + Vector2(9.0, 52.0), rect.size - Vector2(18.0, 61.0))
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color('fff0cf') if hover else Color('f4dfb8')
	paper_style.border_color = Color('6c452d')
	paper_style.set_border_width_all(2)
	paper_style.set_corner_radius_all(14)
	draw_style_box(paper_style, paper_rect)
	draw_texture_rect(CARD_PAPER_TILE, Rect2(paper_rect.position + Vector2(3.0, 3.0), paper_rect.size - Vector2(6.0, 6.0)), false, Color(1.0, 1.0, 1.0, 0.28))
	var inner_line := StyleBoxFlat.new()
	inner_line.bg_color = Color.TRANSPARENT
	inner_line.border_color = Color('d6a45b88')
	inner_line.set_border_width_all(1)
	inner_line.set_corner_radius_all(15)
	draw_style_box(inner_line, Rect2(rect.position + Vector2(5.0, 5.0), rect.size - Vector2(10.0, 10.0)))

	var header_rect := Rect2(rect.position + Vector2(14.0, 9.0), Vector2(rect.size.x - 28.0, 48.0))
	_draw_panel(header_rect, Color(accent.darkened(0.48), 0.98), Color('e0aa4e'), 2.0, 13.0)
	draw_line(header_rect.position + Vector2(48.0, 7.0), header_rect.position + Vector2(header_rect.size.x - 12.0, 7.0), Color('ffd47aaa'), 1.0)
	var header_text: String = '初始法器' if run.state == 'opening' else TYPE_LABELS.get(offer.get('type', ''), '奇遇奖励')
	draw_string(UI_FONT, header_rect.position + Vector2(44.0, 32.0), header_text, HORIZONTAL_ALIGNMENT_CENTER, header_rect.size.x - 88.0, maxi(14, roundi(rect.size.x * 0.062)), PAPER_LIGHT)
	var number_center := header_rect.position + Vector2(24.0, 24.0)
	draw_circle(number_center, 17.0, WALNUT)
	draw_circle(number_center, 13.0, accent)
	draw_arc(number_center, 15.0, 0.0, TAU, 24, Color('ffd47a'), 1.0)
	draw_string(UI_FONT, number_center + Vector2(-10.0, 5.0), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 13, PAPER_LIGHT)
	if hover:
		_draw_texture_centered(ArtCatalog.UI_TEXTURES['focusCursor'], header_rect.position + Vector2(header_rect.size.x - 21.0, 22.0), 31.0)

	var tag_rect := Rect2(rect.end.x - 45.0, rect.position.y + 66.0, 31.0, 82.0)
	_draw_panel(tag_rect, Color('166657f5') if offer.get('type', '') in ['upgrade', 'taskWeapon', 'taskBlessing'] else Color('8b3e31f5'), Color('d6a34e'), 2.0, 11.0)
	draw_circle(tag_rect.position + Vector2(tag_rect.size.x * 0.5, 9.0), 3.0, GOLD)
	var rarity_text: String = '初\n契' if run.state == 'opening' else ('精\n良' if offer.get('type', '') in ['upgrade', 'taskWeapon', 'taskBlessing'] else '奇\n遇')
	var rarity_lines: PackedStringArray = rarity_text.replace('\\n', '\n').split('\n')
	for tag_index in rarity_lines.size():
		draw_string(UI_FONT, tag_rect.position + Vector2(0.0, 32.0 + tag_index * 24.0), rarity_lines[tag_index], HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, maxi(13, roundi(rect.size.x * 0.057)), PAPER_LIGHT)

	var icon_center := rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.30)
	for aura_index in 3:
		var aura_radius: float = rect.size.x * (0.18 + aura_index * 0.025)
		draw_arc(icon_center, aura_radius, PI * 0.10, PI * 1.90, 32, Color(SPIRIT_GLOW, 0.22 - aura_index * 0.05), 2.0)
	_draw_icon_badge(_choice_texture(id, offer.get('type', '')), icon_center, rect.size.x * 0.34, rect.size.x * 0.23, accent, hover)

	var name_y: float = rect.position.y + rect.size.y * 0.52
	draw_string(UI_FONT, Vector2(rect.position.x + 22.0, name_y), card.get('name', '未知奖励'), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 44.0, maxi(19, roundi(rect.size.x * 0.084)), INK)
	var divider_y: float = rect.position.y + rect.size.y * 0.575
	draw_line(Vector2(rect.position.x + rect.size.x * 0.18, divider_y), Vector2(rect.end.x - rect.size.x * 0.18, divider_y), Color(WALNUT, 0.52), 1.5)
	draw_circle(Vector2(rect.get_center().x, divider_y), 3.0, ANTIQUE_GOLD)

	var level_rect := Rect2(rect.position + Vector2(rect.size.x * 0.18, rect.size.y * 0.605), Vector2(rect.size.x * 0.64, rect.size.y * 0.088))
	_draw_panel(level_rect, Color('e1eed4f5'), JADE, 1.0, level_rect.size.y * 0.5)
	draw_string(UI_FONT, level_rect.position + Vector2(3.0, level_rect.size.y * 0.70), _level_info(offer), HORIZONTAL_ALIGNMENT_CENTER, level_rect.size.x - 6.0, maxi(12, roundi(rect.size.x * 0.052)), TEAL_DEEP)

	var description: String = card.get('desc', CARD_DESCRIPTIONS.get(id, '本局持续生效'))
	var lines: Array[String] = _wrap_text(description, 13 if rect.size.x < 250.0 else 15)
	var desc_rect := Rect2(rect.position + Vector2(14.0, rect.size.y * 0.71), Vector2(rect.size.x - 28.0, rect.size.y * 0.13))
	_draw_panel(desc_rect, Color('f8e7c9ed'), Color('9f714f99'), 1.0, 8.0)
	var line_height: float = 19.0
	var text_height: float = mini(lines.size(), 2) * line_height
	var desc_y: float = desc_rect.position.y + (desc_rect.size.y - text_height) * 0.5 + 14.0
	for line_index in mini(lines.size(), 2):
		draw_string(UI_FONT, Vector2(desc_rect.position.x + 5.0, desc_y + line_index * line_height), lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, desc_rect.size.x - 10.0, maxi(13, roundi(rect.size.x * 0.054)), INK)

	var button_rect := Rect2(rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.855), Vector2(rect.size.x * 0.72, rect.size.y * 0.105))
	_draw_panel(button_rect, Color(accent.darkened(0.22)) if hover else Color('9e4a35'), Color('f0b553'), 2.0, button_rect.size.y * 0.5)
	draw_line(button_rect.position + Vector2(13.0, 5.0), button_rect.position + Vector2(button_rect.size.x - 13.0, 5.0), Color('ffd27aaa'), 1.0)
	draw_string(UI_FONT, button_rect.position + Vector2(0.0, button_rect.size.y * 0.72), '%d · 点击选择' % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x, maxi(12, roundi(rect.size.x * 0.052)), PAPER_LIGHT)

	_draw_texture_centered(CARD_CORNER_BLOSSOM, rect.position + Vector2(rect.size.x - 18.0, 18.0), 38.0, PI * 0.25)
	_draw_texture_centered(CARD_CORNER_BLOSSOM, rect.end - Vector2(17.0, 19.0), 52.0, PI)

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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.045, 0.10, 0.88))
	var rect := Rect2(size.x * 0.5 - 320.0, size.y * 0.5 - 154.0, 640.0, 308.0)
	_draw_panel(rect, Color(NIGHT, 0.99), ANTIQUE_GOLD, 4.0, 30.0)
	_draw_panel(Rect2(rect.position + Vector2(12.0, 12.0), rect.size - Vector2(24.0, 24.0)), PAPER_LIGHT, WALNUT, 2.0, 24.0)
	_draw_panel(Rect2(rect.position + Vector2(190.0, 20.0), Vector2(260.0, 66.0)), Color(NIGHT_SOFT, 0.98), accent, 2.0, 26.0)
	_draw_texture_centered(_modal_texture(title), rect.position + Vector2(rect.size.x * 0.5, 52.0), 66.0)
	draw_string(UI_FONT, Vector2(rect.position.x, rect.position.y + 123.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, accent)
	var lines: PackedStringArray = body.split('
')
	for i in lines.size():
		draw_string(UI_FONT, Vector2(rect.position.x + 30.0, rect.position.y + 166.0 + i * 31.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 60.0, 17, INK)

func _draw_key_button(rect: Rect2, key: String, label: String, accent: Color) -> void:
	_draw_panel(rect, Color(PAPER, 0.99), ANTIQUE_GOLD, 3.0, 20.0)
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
	shadow.bg_color = Color(0.0, 0.02, 0.07, 0.56)
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
	back.border_color = WALNUT
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
	draw_circle(badge_center + shadow_offset, radius + 1.5, Color(NIGHT, 0.58))
	# Outer ring (thicker, more playful)
	draw_circle(badge_center, radius, WALNUT)
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
		draw_circle(charm_center, maxf(3.5, radius * 0.15), WALNUT)
		draw_circle(charm_center, maxf(2.0, radius * 0.09), GOLD)
	if badge_size >= 50.0:
		var charm2 := badge_center + Vector2(radius * 0.62, radius * 0.48)
		draw_circle(charm2, maxf(2.5, radius * 0.10), WALNUT)
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
