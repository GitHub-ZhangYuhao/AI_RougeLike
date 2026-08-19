extends Node2D

const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const FlipbookScript: GDScript = preload('res://logic/systems/flipbook.gd')
const RareItemsScript: GDScript = preload('res://logic/rare_items.gd')
const UI_FONT: Font = preload('res://assets/fonts/ui_font_round.tres')
const WEAPON_COLORS: Dictionary = {
	'sword': Color('c5f3ff'),
	'talisman': Color('ffe066'),
	'cloak': Color('ff7043'),
	'trail': Color('ff5722'),
	'ring': Color('b7e778'),
	'staff': Color('b388ff'),
	'status': Color('d7c7ff'),
}
const IMPACT_TEXTURE_KEYS: Dictionary = {
	'sword': 'swordSlash',
	'talisman': 'talismanLightning',
	'cloak': 'cloakFireBurst',
	'trail': 'furnaceFlame',
	'ring': 'jadeRingTrail',
	'staff': 'staffSpiritBolt',
	'status': 'impact',
}
const STAFF_LINK_RADIUS: float = 260.0
const DETAILED_IMPACT_BUDGET: int = 32
const DAMAGE_NUMBER_BUDGET: int = 24
const DETAILED_DOT_BUDGET: int = 48
const DAMAGE_NUMBER_OFFSETS: Array[Vector2] = [
	Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0),
	Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5),
]
# 序列帧图集常量（规格见 logic/systems/flipbook.gd 与 PRODUCTION_REPORT.md）
const FLAME_FPS: float = 8.823529
const FLAME_LOOP_FRAMES: int = 25
const BURST_FRAME_COUNT: int = 25

var run = null
var animation_time: float = 0.0
# 缓存 AtlasTexture —— 避免每帧为每个敌人创建新对象（主要性能瓶颈）
var _atlas_cache: Dictionary = {}
# 上一帧编号，用于失效缓存
var _last_frame_index: int = -1


func bind_run(game_run) -> void:
	run = game_run
	queue_redraw()


func refresh(delta: float = 0.0) -> void:
	animation_time += delta
	# 动画帧变化时清理 atlas 缓存（每帧只失效一次，而不是每敌一次）
	var total_frames: int = ArtCatalog.ENEMY_SHEET_COLS * ArtCatalog.ENEMY_SHEET_ROWS
	var current_frame: int = int(animation_time * ArtCatalog.ENEMY_SHEET_FPS) % total_frames
	if current_frame != _last_frame_index:
		_last_frame_index = current_frame
		_atlas_cache.clear()
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	_draw_ambient_motes()
	_draw_tasks()
	_draw_weapon_zones()
	_draw_weapon_loadout()
	_draw_sword_rings()
	_draw_trails()
	_draw_gems()
	_draw_pickups()
	_draw_enemies()
	_draw_staff_effects()
	_draw_summons()
	_draw_flying_swords()
	_draw_player_projectiles()
	_draw_hostile_projectiles()
	_draw_talisman_effects()
	_draw_effects()


func _draw_ambient_motes() -> void:
	if run.state not in ['opening', 'playing', 'choice', 'extraction', 'dead']:
		return
	var camera_cell := Vector2i(floori(run.camera.x / 180.0), floori(run.camera.y / 180.0))
	for grid_y in range(camera_cell.y - 3, camera_cell.y + 4):
		for grid_x in range(camera_cell.x - 5, camera_cell.x + 6):
			var mote_seed: int = absi(grid_x * 92821 + grid_y * 68917)
			if mote_seed % 4 == 0:
				continue
			var phase: float = animation_time * (0.42 + float(mote_seed % 7) * 0.035) + float(mote_seed % 31)
			var mote_position := Vector2(
				grid_x * 180.0 + float(mote_seed % 127) - 63.0 + sin(phase) * 13.0,
				grid_y * 180.0 + float(floori(float(mote_seed) / 17.0) % 113) - 56.0 + cos(phase * 0.73) * 8.0
			)
			var mote_alpha: float = 0.07 + float(mote_seed % 5) * 0.012
			var mote_color := Color(0.9, 0.84, 0.55, mote_alpha)
			draw_line(mote_position - Vector2(4.0, 1.5), mote_position + Vector2(4.0, 1.5), mote_color, 1.1, true)
			draw_circle(mote_position, 1.3 + float(mote_seed % 3) * 0.35, Color(1.0, 0.94, 0.72, mote_alpha * 0.72))


func _draw_tasks() -> void:
	if run.taskDirector == null or run.taskDirector.current == null:
		return
	var task: Dictionary = run.taskDirector.current
	var texture: Texture2D = ArtCatalog.TASK_TEXTURES.get(task['type'], ArtCatalog.TASK_TEXTURES['guard'])
	if task['state'] == 'offered':
		_draw_marker(_point(task['beacon']), Config.CONFIG['tasks']['beaconRadius'], Color('4dd0e1'), texture)
		return
	if task['state'] != 'active':
		return
	var payload: Dictionary = task['payload']
	match task['type']:
		'guard':
			var center := _point(payload['center'])
			_draw_marker(center, payload['radius'], Color('66bb6a'), texture)
			# 只在离开守护圈时引导回去，圈内不加视觉噪音
			if Vector2(run.player.x, run.player.y).distance_to(center) > payload['radius']:
				_draw_task_guidance(center, Color('66bb6a'), texture)
		'delivery':
			var destination := _point(payload['destination'])
			_draw_marker(destination, Config.CONFIG['tasks']['delivery']['destinationRadius'], Color('42a5f5'), texture)
			_draw_task_guidance(destination, Color('42a5f5'), texture)
		'bounty':
			var target = payload.get('target')
			if target != null and not target.dead:
				_draw_task_guidance(Vector2(target.x, target.y), Color('ef5350'), texture)


func _draw_marker(marker_position: Vector2, radius: float, color: Color, texture: Texture2D) -> void:
	var pulse: float = 0.5 + sin(animation_time * 3.0) * 0.5
	draw_circle(marker_position, radius, Color(color, 0.06 + pulse * 0.025))
	draw_arc(marker_position, radius + pulse * 3.0, 0.0, TAU, 64, Color(color, 0.75), 2.5)
	draw_arc(marker_position, radius * 0.72, 0.0, TAU, 48, Color(color, 0.28), 1.0)
	_draw_sprite(ArtCatalog.VFX_TEXTURES['taskBeacon'], marker_position - Vector2(0.0, 24.0), minf(radius * 1.15, 104.0), 0.0, false, Color(1.0, 1.0, 1.0, 0.56 + pulse * 0.24))
	_draw_sprite(texture, marker_position - Vector2(0.0, radius + 20.0), 42.0 + pulse * 3.0)


# 任务目标引导：地面导引线 + 目标在屏内时的光柱 / 屏外时的边缘箭头
func _draw_task_guidance(target_position: Vector2, color: Color, texture: Texture2D) -> void:
	var player_position := Vector2(run.player.x, run.player.y)
	var to_target: Vector2 = target_position - player_position
	var distance: float = to_target.length()
	if distance < 24.0:
		return
	var direction: Vector2 = to_target / distance
	var pulse: float = 0.5 + sin(animation_time * 3.0) * 0.5
	# 导引线只画靠玩家的一段，长目标距离下不会糊满屏幕
	var guide_length: float = minf(distance - 20.0, 176.0)
	if guide_length > 34.0:
		var guide_start: Vector2 = player_position + direction * 28.0
		var guide_end: Vector2 = player_position + direction * guide_length
		_draw_dashed_line(guide_start, guide_end, Color(color, 0.38), 2.5, 14.0, 10.0)
		var flow: float = fmod(animation_time * 0.85, 1.0)
		draw_circle(guide_start.lerp(guide_end, flow), 4.0 + pulse * 1.6, Color(color, 0.34 + pulse * 0.2))
		# 末端箭头，明确方向而不是只有一条线
		var perpendicular: Vector2 = direction.rotated(PI * 0.5)
		draw_line(guide_end, guide_end - direction * 13.0 + perpendicular * 8.0, Color(color, 0.72), 2.5, true)
		draw_line(guide_end, guide_end - direction * 13.0 - perpendicular * 8.0, Color(color, 0.72), 2.5, true)
	if _is_on_screen(target_position, 40.0):
		_draw_light_column(target_position, color, pulse)
	else:
		_draw_offscreen_task_arrow(target_position, color, texture, distance, pulse)


# 目标点光柱：让护送终点在远处也能被看到
func _draw_light_column(base_position: Vector2, color: Color, pulse: float) -> void:
	var height: float = 190.0 + pulse * 26.0
	var half_width: float = 15.0 + pulse * 2.5
	for layer in 3:
		var layer_ratio: float = 1.0 - float(layer) * 0.3
		var layer_alpha: float = (0.16 - float(layer) * 0.04) + pulse * 0.05
		var points := PackedVector2Array([
			base_position + Vector2(-half_width * layer_ratio, 0.0),
			base_position + Vector2(half_width * layer_ratio, 0.0),
			base_position + Vector2(half_width * layer_ratio * 0.42, -height * layer_ratio),
			base_position + Vector2(-half_width * layer_ratio * 0.42, -height * layer_ratio),
		])
		draw_colored_polygon(points, Color(color, layer_alpha))
	draw_line(base_position, base_position - Vector2(0.0, height * 0.94), Color(1.0, 1.0, 1.0, 0.24 + pulse * 0.16), 2.0, true)
	_draw_ellipse_shape(base_position, Vector2(half_width * 1.7, half_width * 0.62), Color(color, 0.26 + pulse * 0.12))
	# 上升光点
	for i in 4:
		var rise: float = fmod(animation_time * 0.42 + float(i) * 0.25, 1.0)
		var mote_position: Vector2 = base_position - Vector2(sin(rise * TAU + float(i)) * half_width * 0.5, rise * height)
		draw_circle(mote_position, 2.6 * (1.0 - rise * 0.6), Color(1.0, 1.0, 1.0, (1.0 - rise) * 0.5))


# 目标在屏幕外时，在可视边缘贴一个指向箭头 + 图标 + 距离
func _draw_offscreen_task_arrow(target_position: Vector2, color: Color, texture: Texture2D, distance: float, pulse: float) -> void:
	if run.camera == null:
		return
	var camera_position := Vector2(run.camera.x, run.camera.y)
	var edge_direction: Vector2 = target_position - camera_position
	if edge_direction.length_squared() <= 0.0001:
		return
	edge_direction = edge_direction.normalized()
	# 与 _is_on_screen 用同一套半屏尺寸（含 0.82 相机缩放），再向内收 66px 放图标
	var half_width: float = maxf(run.viewport_size.x * 0.5 / 0.82 - 66.0, 48.0)
	var half_height: float = maxf(run.viewport_size.y * 0.5 / 0.82 - 66.0, 48.0)
	var reach: float = minf(half_width / maxf(absf(edge_direction.x), 0.0001), half_height / maxf(absf(edge_direction.y), 0.0001))
	var arrow_position: Vector2 = camera_position + edge_direction * reach
	var perpendicular: Vector2 = edge_direction.rotated(PI * 0.5)
	var tip: Vector2 = arrow_position + edge_direction * (20.0 + pulse * 4.0)
	draw_circle(arrow_position, 26.0, Color(color, 0.16 + pulse * 0.08))
	draw_colored_polygon(PackedVector2Array([
		tip,
		arrow_position - edge_direction * 8.0 + perpendicular * 13.0,
		arrow_position - edge_direction * 8.0 - perpendicular * 13.0,
	]), Color(color, 0.78 + pulse * 0.18))
	_draw_sprite(texture, arrow_position - edge_direction * 30.0, 38.0, 0.0, false, Color(1.0, 1.0, 1.0, 0.9))
	var label: String = '%d m' % roundi(distance / 10.0)
	draw_string(UI_FONT, arrow_position - edge_direction * 30.0 + Vector2(-24.0, 32.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 48.0, 12, Color(1.0, 0.96, 0.86, 0.92))


func _draw_weapon_zones() -> void:
	for weapon in run.weapons:
		var id: String = weapon.card['id']
		if id == 'cloak':
			var radius: float = weapon.stats['radius']
			var player_position := Vector2(run.player.x, run.player.y)
			draw_circle(player_position, radius, Color(1.0, 0.22, 0.08, 0.025))
			draw_arc(player_position, radius, 0.0, TAU, 64, Color(1.0, 0.36, 0.16, 0.28), 1.5)
			for shock: Dictionary in weapon.shocks:
				var progress: float = clampf(shock['t'] / shock['ttl'], 0.0, 1.0)
				var shock_position := Vector2(shock['x'], shock['y'])
				var enhanced: bool = shock.get('enhanced', false)
				var shock_alpha: float = 1.0 - progress
				var shock_radius: float = shock['max_r'] * progress
				# 使用高亮暖色模拟 Additive 混合模式，避免 alpha 抠像问题
				var tint := Color(1.0, 0.72, 0.28, shock_alpha * 0.9) if enhanced else Color(1.0, 0.82, 0.45, shock_alpha * 0.85)
				var burst_texture: Texture2D = ArtCatalog.VFX_TEXTURES.get('cloakFireBurstAnim')
				if burst_texture != null:
					var burst_frame: int = FlipbookScript.frame_for_progress(progress, BURST_FRAME_COUNT)
					_draw_sprite_region(burst_texture, FlipbookScript.frame_region(burst_frame), shock_position, shock_radius * 2.6, 0.0, tint)
				else:
					_draw_sprite(ArtCatalog.VFX_TEXTURES['cloakFireBurst'], shock_position, shock_radius * 2.6, 0.0, false, tint)
				# 叠加内圈高亮核心，模拟 additive 叠加
				draw_circle(shock_position, shock_radius * 0.6, Color(1.0, 0.9, 0.5, shock_alpha * 0.25))
				if enhanced:
					draw_circle(shock_position, shock_radius, Color(1.0, 0.35, 0.08, shock_alpha * 0.08))
					draw_arc(shock_position, shock_radius, 0.0, TAU, 72, Color(1.0, 0.92, 0.52, shock_alpha * 0.92), 4.5)
					draw_arc(shock_position, shock_radius * 0.82, 0.0, TAU, 64, Color(0.92, 0.28, 0.42, shock_alpha * 0.62), 2.5)
		elif id == 'ring':
			var stats: Dictionary = weapon.stats
			var orbit_radius: float = stats['orbitRadius'] + weapon.expand_factor * stats.get('expandRadius', 0.0)
			var frenzy: bool = weapon.frenzy_timer > 0.0
			var player_position := Vector2(run.player.x, run.player.y)
			if frenzy:
				var frenzy_pulse: float = 0.5 + sin(animation_time * 14.0) * 0.5
				draw_circle(player_position, orbit_radius + 42.0, Color(0.4, 0.82, 1.0, 0.035 + frenzy_pulse * 0.025))
				draw_arc(player_position, orbit_radius + 20.0 + frenzy_pulse * 8.0, 0.0, TAU, 72, Color(1.0, 0.42, 0.2, 0.5), 3.0)
				draw_arc(player_position, orbit_radius + 32.0 - frenzy_pulse * 6.0, 0.0, TAU, 72, Color(0.55, 0.9, 1.0, 0.42), 2.0)
			for i in stats['count']:
				var angle: float = weapon.angle + i * TAU / stats['count']
				var ring_position := player_position + Vector2(cos(angle), sin(angle)) * orbit_radius
				var trail_color := Color('ffb56b') if frenzy else Color('8ef7df')
				_draw_ring_orbit_trail(player_position, orbit_radius, angle, trail_color, frenzy)
				if frenzy:
					draw_circle(ring_position, 30.0, Color(1.0, 0.32, 0.12, 0.1))
				var display_size: float = 88.0 if frenzy else 76.0
				_draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['ring'], ring_position, display_size, 0.0,
					false, Color(1.0, 0.82, 0.68, 1.0) if frenzy else Color.WHITE)
			for fx: Dictionary in weapon.counter_fx:
				var counter_progress: float = clampf(fx['t'] / maxf(fx['dur'], 0.001), 0.0, 1.0)
				var counter_alpha: float = 1.0 - counter_progress
				var counter_position := Vector2(fx.get('x', run.player.x), fx.get('y', run.player.y))
				var counter_radius: float = fx['r'] * (0.12 + counter_progress * 0.88)
				draw_circle(counter_position, counter_radius, Color(0.45, 0.82, 1.0, counter_alpha * 0.055))
				draw_arc(counter_position, counter_radius, 0.0, TAU, 96, Color(0.72, 0.94, 1.0, counter_alpha * 0.9), 4.0)
				draw_arc(counter_position, counter_radius * 0.82, 0.0, TAU, 80, Color(0.3, 0.65, 1.0, counter_alpha * 0.62), 2.0)
				_draw_sprite(ArtCatalog.VFX_TEXTURES['freeze'], counter_position, 92.0 + counter_progress * 70.0,
					animation_time * 0.25, false, Color(0.78, 0.94, 1.0, counter_alpha * 0.82))
		elif id == 'trail':
			for zone: Dictionary in weapon.furnaces:
				_draw_zone(zone, Color(1.0, 0.2, 0.04, 0.1), Color('ff7043'))
				_draw_flame_anim(_point(zone['center']), 78.0, Color(1.0, 1.0, 1.0, _zone_alpha(zone)))
				_draw_furnace_open_effect(zone)
			for zone: Dictionary in weapon.hot_zones:
				_draw_zone(zone, Color(1.0, 0.65, 0.12, 0.1), Color('ffca28'))
			for zone: Dictionary in weapon.cut_zones:
				var alpha: float = clampf(zone['life'] / zone['maxLife'], 0.0, 1.0)
				var p1 := Vector2(zone['x1'], zone['y1'])
				var p2 := Vector2(zone['x2'], zone['y2'])
				# 切炉联动特效——燃烧剑痕：外发光 + 明亮核心 + 火星
				draw_line(p1, p2, Color(1.0, 0.25, 0.04, alpha * 0.3), zone['width'] * 2.5)
				draw_line(p1, p2, Color(1.0, 0.55, 0.12, alpha * 0.6), zone['width'] * 1.4)
				draw_line(p1, p2, Color(1.0, 0.9, 0.5, alpha * 0.9), zone['width'] * 0.5)
				# 沿线撒火星
				var mid := (p1 + p2) * 0.5
				var flicker: float = 0.5 + sin(animation_time * 12.0 + zone['x1'] * 0.1) * 0.5
				draw_circle(mid, zone['width'] * 0.8 * (0.6 + flicker * 0.4), Color(1.0, 0.7, 0.2, alpha * 0.5))


# ---------- 武器装载（loadout）绘制 ----------


func _draw_weapon_loadout() -> void:
	if run.weapons.is_empty():
		return
	var player_position := Vector2(run.player.x, run.player.y)
	var count: int = run.weapons.size()
	# 根据武器数量决定环绕半径
	var orbit_radius: float = 44.0 if count <= 3 else 52.0
	var slow_spin: float = animation_time * 0.25
	var icon_positions: Dictionary = {}
	for i in count:
		var angle: float = slow_spin + float(i) * TAU / float(count)
		icon_positions[run.weapons[i].card['id']] = player_position + Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius - 18.0)
	var primary = run.synergies.primary_definition()
	if primary != null:
		var first_position: Vector2 = icon_positions.get(primary['weaponIds'][0], player_position)
		var second_position: Vector2 = icon_positions.get(primary['weaponIds'][1], player_position)
		var link_pulse: float = 0.5 + sin(animation_time * 7.0) * 0.5
		draw_line(first_position, second_position, Color(0.18, 0.95, 0.82, 0.2 + link_pulse * 0.16), 10.0, true)
		draw_line(first_position, second_position, Color(1.0, 0.8, 0.34, 0.66 + link_pulse * 0.24), 2.2, true)
		draw_arc(player_position, orbit_radius + 16.0 + link_pulse * 4.0, 0.0, TAU, 64, Color(0.3, 1.0, 0.84, 0.26 + link_pulse * 0.16), 2.2)
		_draw_sprite(ArtCatalog.VFX_TEXTURES['synergyArc'], (first_position + second_position) * 0.5, first_position.distance_to(second_position) * 1.5, (second_position - first_position).angle(), false, Color(1.0, 1.0, 1.0, 0.34 + link_pulse * 0.2))
		if run.synergies.activation_flash_ttl > 0.0:
			var activation_alpha: float = clampf(run.synergies.activation_flash_ttl / 1.8, 0.0, 1.0)
			var activation_progress: float = 1.0 - activation_alpha
			var activation_radius: float = 70.0 + activation_progress * 230.0
			draw_circle(player_position, activation_radius, Color(0.22, 1.0, 0.84, activation_alpha * 0.1))
			draw_arc(player_position, activation_radius, animation_time, animation_time + TAU, 96, Color(0.35, 1.0, 0.88, activation_alpha), 5.0)
			draw_arc(player_position, activation_radius * 0.72, -animation_time * 1.4, -animation_time * 1.4 + PI * 1.7, 72, Color(1.0, 0.72, 0.26, activation_alpha * 0.92), 3.5)
			for burst_index in 12:
				var burst_angle: float = float(burst_index) * TAU / 12.0 + animation_time * 0.35
				var burst_inner := player_position + Vector2.RIGHT.rotated(burst_angle) * activation_radius * 0.3
				var burst_outer := player_position + Vector2.RIGHT.rotated(burst_angle) * activation_radius * 0.92
				draw_line(burst_inner, burst_outer, Color(0.82, 1.0, 0.92, activation_alpha * 0.72), 2.5, true)
	for i in count:
		var weapon = run.weapons[i]
		var weapon_id: String = weapon.card['id']
		var texture: Texture2D = ArtCatalog.WEAPON_ICONS.get(weapon_id)
		if texture == null:
			continue
		var icon_position: Vector2 = icon_positions[weapon_id]
		var level: int = weapon.level
		var awakened: bool = level >= 4
		var ultimate: bool = level >= 6
		var icon_size: float = 29.0 if ultimate else (24.0 if awakened else 20.0)
		var color: Color = WEAPON_COLORS.get(weapon_id, Color('ffe082'))
		var level_pulse: float = 0.5 + sin(animation_time * (5.5 if ultimate else 3.5) + i) * 0.5
		# 底部小光晕
		draw_circle(icon_position, icon_size * (0.82 + level_pulse * 0.16), Color(color, 0.12 + level_pulse * (0.16 if awakened else 0.05)))
		draw_arc(icon_position, icon_size * (0.9 + level_pulse * 0.12), animation_time, animation_time + TAU, 28, Color(color, 0.48 if awakened else 0.28), 2.8 if ultimate else (1.8 if awakened else 1.0))
		if awakened:
			draw_arc(icon_position, icon_size * 1.16, -animation_time * 1.4, -animation_time * 1.4 + PI * 1.5, 28, Color(1.0, 0.76, 0.28, 0.72), 2.0)
		if ultimate:
			for spark_index in 4:
				var spark_angle: float = animation_time * 1.8 + float(spark_index) * TAU / 4.0
				var spark_position := icon_position + Vector2.RIGHT.rotated(spark_angle) * icon_size * 1.18
				draw_circle(spark_position, 2.5 + level_pulse * 1.5, Color(color, 0.82))
		# 武器图标
		_draw_sprite(texture, icon_position, icon_size * 2.0, 0.0, false, Color(1.0, 0.96, 0.82, 1.0 if awakened else 0.92))
		# 武器等级徽章（右上角）
		if level > 1:
			var badge_pos := icon_position + Vector2(icon_size * 0.6, -icon_size * 0.6)
			draw_circle(badge_pos, 9.0 if ultimate else 8.0, Color(color, 0.92))
			draw_circle(badge_pos, 6.5 if ultimate else 6.0, Color(0.25, 0.1, 0.08, 0.94))
			draw_string(UI_FONT, badge_pos + Vector2(-4.0, 5.0), str(level), HORIZONTAL_ALIGNMENT_LEFT, 12.0, 9, Color.WHITE)


# 绘制道剑剑阵特效（ring effect）
func _draw_sword_rings() -> void:
	var sword = null
	for weapon in run.weapons:
		if weapon.card['id'] == 'sword':
			sword = weapon
			break
	if sword == null:
		return
	var sword_rings: Array = sword.rings
	if sword_rings.is_empty():
		return
	for ring: Dictionary in sword.rings:
		var ring_position := Vector2(ring['x'], ring['y'])
		var radius: float = ring['r']
		var alpha: float = clampf(ring['ttl'] / 0.28, 0.0, 1.0)
		var progress: float = 1.0 - alpha
		# 外圈扩散光环
		draw_circle(ring_position, radius * (0.5 + progress * 0.5), Color(1.0, 0.72, 0.25, alpha * 0.08))
		draw_arc(ring_position, radius * (0.8 + progress * 0.4), 0.0, TAU, 48, Color(1.0, 0.82, 0.35, alpha * 0.55), 2.5)
		draw_arc(ring_position, radius * (0.6 + progress * 0.3), 0.0, TAU, 36, Color(1.0, 0.92, 0.55, alpha * 0.35), 1.5)
		# 剑阵符文粒子
		for rune_i in 8:
			var rune_angle: float = float(rune_i) * TAU / 8.0 + animation_time * 1.5
			var rune_pos := ring_position + Vector2(cos(rune_angle), sin(rune_angle)) * radius * 0.75
			var rune_size: float = 3.0 + sin(animation_time * 6.0 + float(rune_i)) * 1.0
			draw_circle(rune_pos, rune_size, Color(1.0, 0.88, 0.45, alpha * 0.6))


func _draw_flying_swords() -> void:
	var sword = null
	for weapon in run.weapons:
		if weapon.card['id'] == 'sword':
			sword = weapon
			break
	if sword == null:
		return
	var player_position := Vector2(run.player.x, run.player.y)
	for flying: Dictionary in sword.flying_swords:
		var sword_position := Vector2(flying['x'], flying['y'])
		if not _is_on_screen(sword_position, 100.0):
			continue
		var state: String = flying.get('state', 'orbit')
		var direction: Vector2
		if state == 'strike':
			direction = Vector2(flying.get('dir_x', 1.0), flying.get('dir_y', 0.0))
		elif state == 'return':
			direction = player_position - sword_position
		else:
			var orbit_angle: float = flying.get('angle', 0.0)
			direction = Vector2(-sin(orbit_angle), cos(orbit_angle))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		var alpha: float = clampf(flying.get('ttl', 1.0), 0.0, 1.0)
		var strike_pulse: float = 0.5 + sin(animation_time * 10.0) * 0.5
		var blade_size: float = 96.0 if state == 'strike' else 80.0
		var tail_length: float = 104.0 if state == 'strike' else 62.0
		# 外层灵光：出击时更亮，让 10 把飞剑在混战里也能一眼看到
		draw_circle(sword_position, blade_size * 0.5, Color(0.55, 0.9, 1.0, alpha * (0.16 + strike_pulse * 0.07)))
		draw_circle(sword_position, blade_size * 0.3, Color(0.85, 0.98, 1.0, alpha * 0.14))
		draw_line(sword_position - direction * tail_length, sword_position, Color(0.45, 0.86, 1.0, alpha * 0.42), 13.0, true)
		draw_line(sword_position - direction * tail_length * 0.76, sword_position, Color(0.88, 0.97, 1.0, alpha * 0.85), 4.5, true)
		draw_line(sword_position - direction * tail_length * 0.5, sword_position, Color(0.9, 0.12, 0.2, alpha * 0.5), 2.0, true)
		_draw_sprite(ArtCatalog.VFX_TEXTURES['flyingSword'], sword_position, blade_size, direction.angle(), false,
			Color(1.0, 1.0, 1.0, alpha))
		draw_circle(sword_position + direction * blade_size * 0.22, 4.5 + strike_pulse * 1.5, Color(1.0, 0.96, 0.94, alpha))


func _draw_zone(zone: Dictionary, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array()
	for point: Dictionary in zone['points']:
		points.append(_point(point))
	if points.size() < 3:
		return
	var alpha: float = _zone_alpha(zone)
	draw_colored_polygon(points, Color(fill, fill.a * alpha))
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], Color(outline, alpha * 0.7), 2.0)


func _draw_furnace_open_effect(zone: Dictionary) -> void:
	var fx_time: float = zone.get('openFx', 0.0)
	if fx_time <= 0.0:
		return
	var max_time: float = maxf(zone.get('openFxMax', 0.45), 0.001)
	var alpha: float = clampf(fx_time / max_time, 0.0, 1.0)
	var progress: float = 1.0 - alpha
	var center := _point(zone['center'])
	var points := PackedVector2Array()
	var visual_radius: float = 0.0
	for point: Dictionary in zone['points']:
		var point_position := _point(point)
		points.append(point_position)
		visual_radius = maxf(visual_radius, center.distance_to(point_position))
	if points.size() >= 3:
		var flash_color := Color(1.0, 0.82, 0.26, alpha * 0.2) if zone.get('openNineTurn', false) else Color(1.0, 0.28, 0.05, alpha * 0.18)
		draw_colored_polygon(points, flash_color)
	var ring_color := Color(1.0, 0.88, 0.4, alpha * 0.95) if zone.get('openNineTurn', false) else Color(1.0, 0.42, 0.12, alpha * 0.9)
	var burst_radius: float = visual_radius * (0.25 + progress * 0.9)
	draw_arc(center, burst_radius, 0.0, TAU, 72, ring_color, 5.0)
	draw_arc(center, burst_radius * 0.72, 0.0, TAU, 64, Color(1.0, 0.96, 0.72, alpha * 0.62), 2.5)
	_draw_flame_anim(center, maxf(80.0, visual_radius * (1.1 + progress * 0.45)), Color(1.0, 0.86, 0.58, alpha * 0.88), animation_time * 0.45)


func _zone_alpha(zone: Dictionary) -> float:
	return clampf(zone.get('life', 1.0) / maxf(zone.get('maxLife', 1.0), 0.001), 0.0, 1.0)


func _draw_trails() -> void:
	var fire_tex: Texture2D = ArtCatalog.VFX_TEXTURES.get('furnaceFlameAnim')
	for trail: Dictionary in run.trails:
		if trail['dead']:
			continue
		var alpha: float = clampf(trail['life'] / trail['maxLife'], 0.0, 1.0)
		var pos := Vector2(trail['x'], trail['y'])
		var display_size: float = trail['radius'] * 3.0
		# 脉动尺寸
		var pulse: float = 0.88 + sin(animation_time * 8.0 + pos.x * 0.07 + pos.y * 0.05) * 0.12
		display_size *= pulse
		if fire_tex != null:
			# 使用丹火序列帧图集（2048×2048、5×5 网格，与丹火炉 / 丹火核心共用新图集）
			var phase: float = fposmod(pos.x * 0.031 + pos.y * 0.017, 1.0) * float(FLAME_LOOP_FRAMES)
			var frame: int = int(floor(animation_time * FLAME_FPS + phase)) % FLAME_LOOP_FRAMES
			_draw_sprite_region(fire_tex, FlipbookScript.frame_region(frame, 5, 2048, 393, 8), pos, display_size, 0.0, Color(1.0, 1.0, 1.0, alpha))
		else:
			# 后备：纯几何火球
			var r: float = display_size * 0.5
			draw_circle(pos, r * 1.2, Color(1.0, 0.4, 0.05, alpha * 0.25))
			draw_circle(pos, r * 0.85, Color(1.0, 0.65, 0.15, alpha * 0.7))
			draw_circle(pos, r * 0.5, Color(1.0, 0.9, 0.4, alpha * 0.9))


func _draw_gems() -> void:
	for gem: Dictionary in run.gems:
		if gem['dead']:
			continue
		var gem_position := Vector2(gem['x'], gem['y'])
		if not _is_on_screen(gem_position, 52.0):
			continue
		var bob := Vector2(0.0, sin(animation_time * 4.0 + gem['x'] * 0.01) * 2.6)
		var gem_color := Color(gem['color'])
		var display_position: Vector2 = gem_position + bob
		var gem_size: float = 34.0 + float(gem.get('value', 1) - 1) * 2.0
		if gem['magnetized']:
			_draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], gem_position, 48.0, animation_time, false, Color(0.75, 1.0, 1.0, 0.72))
		draw_circle(display_position, 17.0, Color(gem_color, 0.20))
		_draw_ellipse_shape(display_position + Vector2(0.0, 9.0), Vector2(10.0, 4.0), Color(0.0, 0.0, 0.0, 0.18))
		_draw_sprite(ArtCatalog.PICKUP_TEXTURES['gem'], display_position, gem_size)


func _draw_pickups() -> void:
	var nearest = null
	var nearest_distance_squared: float = 260.0 * 260.0
	for candidate: Dictionary in run.pickups:
		if candidate.get('dead', false):
			continue
		var candidate_distance: float = Vector2(candidate['x'], candidate['y']).distance_squared_to(Vector2(run.player.x, run.player.y))
		if candidate_distance < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = candidate_distance
	for pickup: Dictionary in run.pickups:
		if pickup.get('dead', false):
			continue
		var pickup_position := Vector2(pickup['x'], pickup['y'])
		if not _is_on_screen(pickup_position, 72.0):
			continue
		var bob := Vector2(0.0, sin(animation_time * 3.4 + pickup['x'] * 0.015) * 3.2)
		var is_rare: bool = pickup.get('kind') == 'rare'
		var rare_pulse: float = 0.5 + sin(animation_time * 3.2 + pickup['x'] * 0.02) * 0.5
		if is_rare:
			_draw_sprite(ArtCatalog.VFX_TEXTURES['rarePickupGlow'], pickup_position, 110.0 + rare_pulse * 8.0, -animation_time * 0.35, false, Color(1.0, 1.0, 1.0, 0.6 + rare_pulse * 0.16))
			var item_id: String = pickup.get('itemId', '')
			var accent := Color(RareItemsScript.RARE_ITEM_BY_ID.get(item_id, {}).get('color', '#e8b34c'))
			# 脉动外环：把放大的拾取半径直接画出来，避免玩家靠近了却不知道已进范围
			var rare_radius: float = Config.CONFIG['pickups']['rarePickupRadius']
			draw_arc(pickup_position, rare_radius, 0.0, TAU, 40, Color(accent, 0.18 + rare_pulse * 0.16), 2.0)
			draw_arc(pickup_position, 44.0 + rare_pulse * 6.0, 0.0, TAU, 36, Color(accent, 0.34 + rare_pulse * 0.24), 2.5)
			var texture: Texture2D = ArtCatalog.RARE_TEXTURES.get(item_id, ArtCatalog.RARE_TEXTURES['warRune'])
			_draw_sprite(texture, pickup_position + bob, 68.0)
			if pickup == nearest:
				var item: Dictionary = RareItemsScript.RARE_ITEM_BY_ID.get(item_id, {})
				_draw_pickup_label(pickup_position + Vector2(0.0, 52.0), item.get('name', '稀有遗物'), item.get('description', '拾取后强化本局'), accent)
		else:
			_draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], pickup_position, 56.0, -animation_time * 0.5, false, Color(1.0, 1.0, 1.0, 0.52))
			_draw_sprite(ArtCatalog.PICKUP_TEXTURES['health'], pickup_position + bob, 42.0)
			if pickup == nearest:
				_draw_pickup_label(pickup_position + Vector2(0.0, 36.0), '生命精华', '拾取后回复 %d 生命' % Config.CONFIG['pickups']['hpValue'], Color('ef624f'))


func _draw_pickup_label(position: Vector2, title: String, detail: String, accent: Color) -> void:
	var rect := Rect2(position - Vector2(88.0, 0.0), Vector2(176.0, 38.0))
	draw_rect(rect, Color(0.03, 0.07, 0.12, 0.90), true)
	draw_rect(rect, Color(accent, 0.86), false, 1.5)
	draw_string(UI_FONT, rect.position + Vector2(8.0, 15.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0, 12, Color('fff0c9'))
	draw_string(UI_FONT, rect.position + Vector2(8.0, 31.0), detail, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0, 10, Color('c9d9cf'))


func _draw_enemies() -> void:
	# ===== 分批次绘制（instance 风格）=====
	# 收集所有可见敌人，按绘制层分组；相同纹理的精灵连续绘制，引擎可自动合批
	var visible_enemies: Array = []
	for enemy in run.enemies:
		if enemy.dead:
			continue
		if not _is_on_screen(Vector2(enemy.x, enemy.y), 180.0):
			continue
		visible_enemies.append(enemy)
	if visible_enemies.is_empty():
		return

	# --- Pass 1: 地面阴影（统一 draw_circle/ellipse） ---
	for enemy in visible_enemies:
		var pos := Vector2(enemy.x, enemy.y)
		var r: float = maxf(enemy.radius, 10.0)
		_draw_ellipse_shape(pos + Vector2(0.0, r * 0.72), Vector2(r * 1.22, r * 0.5), Color(0.03, 0.025, 0.035, 0.38))

	# --- Pass 2: 光环 / Boss 光效 ---
	for enemy in visible_enemies:
		var pos := Vector2(enemy.x, enemy.y)
		var r: float = maxf(enemy.radius, 10.0)
		var is_boss: bool = enemy.type == 'boss'
		var pulse: float = 0.5 + sin(animation_time * (2.4 if is_boss else 3.6) + enemy.y * 0.006) * 0.5
		if is_boss:
			draw_circle(pos, r * (1.55 + pulse * 0.12), Color(0.34, 0.12, 0.42, 0.08 + pulse * 0.04))
			draw_arc(pos, r * (1.6 + pulse * 0.08), 0.0, TAU, 48, Color(0.76, 0.42, 0.95, 0.22 + pulse * 0.16), 2.0)
		elif enemy.rank == 'elite':
			draw_circle(pos, r * 1.35, Color(1.0, 0.72, 0.18, 0.07 + pulse * 0.03))

	# --- Pass 3: Boss 怒气 / 冰冻 / 受击精灵（按纹理分组连续绘制，引擎自动合批） ---
	for enemy in visible_enemies:
		var pos := Vector2(enemy.x, enemy.y)
		var r: float = maxf(enemy.radius, 10.0)
		var is_boss: bool = enemy.type == 'boss'
		var pulse: float = 0.5 + sin(animation_time * (2.4 if is_boss else 3.6) + enemy.y * 0.006) * 0.5
		var display_size: float = r * (6.6 if is_boss else 6.2)
		if enemy.type == 'charger':
			display_size *= 1.12
		elif enemy.type == 'shield':
			display_size *= 1.08
		var bob: float = sin(animation_time * (2.2 if is_boss else 4.2) + enemy.x * 0.008) * (1.2 if is_boss else 2.0)
		if is_boss and enemy.enraged:
			_draw_sprite(ArtCatalog.VFX_TEXTURES['bossEnraged'], pos, display_size * (1.45 + pulse * 0.08), animation_time * 0.15, false, Color(1.0, 1.0, 1.0, 0.72))
		var hit_ratio: float = clampf(enemy.hitFlash / 0.14, 0.0, 1.0)
		var enemy_tint := Color.WHITE
		if enemy.frozenTimer > 0.0:
			enemy_tint = Color(0.65, 0.9, 1.0, 0.94)
			_draw_sprite(ArtCatalog.VFX_TEXTURES['freeze'], pos, display_size * 0.85, 0.0, false, Color(1.0, 1.0, 1.0, 0.46))
		elif hit_ratio > 0.0:
			enemy_tint = Color(1.35, 1.2, 0.95, 1.0)
			display_size *= 1.0 + hit_ratio * 0.08
		var flip_h: bool = run.player.x < enemy.x
		# 取精灵纹理（使用缓存的 atlas）
		var enemy_type_key: String = enemy.type if enemy.type != 'enhanced_chaser' else 'enhancedChaser'
		# 敌人是 RefCounted：Object 没有 has()，get() 也只接受 1 个参数；属性存在性一律用 in 判断
		if enemy_type_key == 'boss' and 'state' in enemy and enemy.state == 'windup':
			enemy_type_key = 'bossIdle'
		var sheet: Texture2D = ArtCatalog.ENEMY_SPRITE_SHEETS.get(enemy_type_key)
		var texture: Texture2D
		if sheet != null:
			texture = _get_animated_frame(sheet, enemy_type_key)
		else:
			texture = ArtCatalog.ENEMY_TEXTURES.get(enemy.type, ArtCatalog.ENEMY_TEXTURES['chaser'])
		_draw_sprite(texture, pos + Vector2(0.0, bob - display_size * 0.31), display_size, 0.0, flip_h, enemy_tint)

	# --- Pass 4: 叠加效果（受击弧、精英标识、减速、冲锋、dot、任务、血条） ---
	var dot_enemy_total: int = 0
	for enemy in visible_enemies:
		if _has_active_enemy_dot(enemy.dots):
			dot_enemy_total += 1
	var dot_enemy_index: int = 0
	for enemy in visible_enemies:
		var pos := Vector2(enemy.x, enemy.y)
		var r: float = maxf(enemy.radius, 10.0)
		var is_boss: bool = enemy.type == 'boss'
		var pulse: float = 0.5 + sin(animation_time * (2.4 if is_boss else 3.6) + enemy.y * 0.006) * 0.5
		var display_size: float = r * (6.6 if is_boss else 6.2)
		if enemy.type == 'charger':
			display_size *= 1.12
		elif enemy.type == 'shield':
			display_size *= 1.08
		var hit_ratio: float = clampf(enemy.hitFlash / 0.14, 0.0, 1.0)
		if hit_ratio > 0.0:
			draw_arc(pos, r * (1.0 + (1.0 - hit_ratio) * 0.6), 0.0, TAU, 24, Color(1.0, 0.9, 0.55, hit_ratio * 0.78), 2.5)
			_draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], pos - Vector2(0.0, r * 0.25), display_size * (0.42 + (1.0 - hit_ratio) * 0.18), animation_time * 0.6, false, Color(1.0, 1.0, 1.0, hit_ratio * 0.88))
		if enemy.rank == 'elite':
			draw_arc(pos, r + 7.0 + pulse * 2.0, 0.0, TAU, 32, Color(1.0, 0.84, 0.31, 0.72 + pulse * 0.22), 2.5)
			_draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], pos, r * (3.4 + pulse * 0.18), animation_time * 0.3, false, Color(1.0, 0.86, 0.38, 0.24 + pulse * 0.1))
		if enemy.slowTimer > 0.0:
			draw_arc(pos, r + 9.0, 0.0, TAU, 24, Color('80cbc4'), 2.0)
		if enemy.type == 'charger' and 'state' in enemy and (enemy.state == 'windup' or enemy.state == 'dash'):
			_draw_charge_indicator(pos, r, enemy)
		if enemy.type == 'bomber' and 'state' in enemy and enemy.state == 'windup':
			_draw_bomber_windup_warning(pos, r, enemy)
		if enemy.type == 'enhanced_chaser' and 'warningTimer' in enemy and enemy.warningTimer > 0.0 and not enemy.enraged:
			_draw_chaser_enrage_warning(pos, r, enemy)
		if is_boss and 'state' in enemy and enemy.state == 'windup':
			_draw_boss_windup_warning(pos, r, enemy)
		if enemy.type == 'ranged' and 'fireCooldown' in enemy:
			_draw_ranged_charge_warning(pos, r, enemy)
		if _has_active_enemy_dot(enemy.dots):
			var detailed_dot: bool = is_budget_sample(dot_enemy_index, dot_enemy_total, DETAILED_DOT_BUDGET)
			_draw_enemy_dots(pos, r, enemy.dots, pulse, detailed_dot)
			dot_enemy_index += 1
		if enemy.taskRole != null:
			_draw_sprite(ArtCatalog.TASK_TEXTURES['bounty'], pos - Vector2(0.0, r + 24.0), 30.0 + pulse * 2.0)
		if enemy.hp < enemy.maxHp or enemy.rank == 'elite' or enemy.rank == 'boss':
			_draw_health_bar(pos, r, enemy.hp, enemy.maxHp, is_boss)


# Returns an AtlasTexture for the current animation frame from a sprite sheet
# 使用缓存，避免每帧每个敌人创建新的 AtlasTexture 对象

# Returns an AtlasTexture for the current animation frame from a sprite sheet
# 使用缓存，避免每帧每个敌人创建新的 AtlasTexture 对象


func _get_animated_frame(sheet: Texture2D, enemy_key: String) -> AtlasTexture:
	var cols: int = ArtCatalog.ENEMY_SHEET_COLS
	var rows: int = ArtCatalog.ENEMY_SHEET_ROWS
	var total_frames: int = cols * rows
	var frame_index: int = int(animation_time * ArtCatalog.ENEMY_SHEET_FPS) % total_frames
	var cache_key: String = enemy_key + str(frame_index)
	var cached = _atlas_cache.get(cache_key)
	if cached != null:
		return cached
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var col: int = frame_index % cols
	var row: int = floori(float(frame_index) / float(cols))
	var frame_w: float = sheet.get_width() / float(cols)
	var frame_h: float = sheet.get_height() / float(rows)
	atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
	_atlas_cache[cache_key] = atlas
	return atlas


# 判断一个世界坐标点是否在可见范围内（带额外边距以容纳大型精灵）
func _is_on_screen(world_pos: Vector2, margin: float = 120.0) -> bool:
	if run.camera == null:
		return true
	var half_w: float = run.viewport_size.x * 0.5 / 0.82 + margin
	var half_h: float = run.viewport_size.y * 0.5 / 0.82 + margin
	var dx: float = world_pos.x - run.camera.x
	var dy: float = world_pos.y - run.camera.y
	return dx > -half_w and dx < half_w and dy > -half_h and dy < half_h


func _effect_point_on_screen(effect: Dictionary, margin: float = 120.0) -> bool:
	if not effect.has('x') or not effect.has('y'):
		return true
	return _is_on_screen(Vector2(effect['x'], effect['y']), margin)


static func _has_active_enemy_dot(dots: Dictionary) -> bool:
	return (
		(dots.has('burn') and dots['burn'].get('timer', 0.0) > 0.0)
		or (dots.has('bleed') and dots['bleed'].get('timer', 0.0) > 0.0)
		or (dots.has('poison') and dots['poison'].get('timer', 0.0) > 0.0)
	)


static func is_budget_sample(index: int, total: int, budget: int) -> bool:
	if index < 0 or index >= total or budget <= 0:
		return false
	if total <= budget:
		return true
	var current_bucket: int = floori(float(index) * float(budget) / float(total))
	var next_bucket: int = floori(float(index + 1) * float(budget) / float(total))
	return current_bucket != next_bucket


func _draw_health_bar(bar_position: Vector2, radius: float, hp: float, max_hp: float, is_boss: bool) -> void:
	var width: float = maxf(34.0, radius * (2.6 if is_boss else 2.2))
	var ratio: float = clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var top_left := bar_position + Vector2(-width * 0.5, -radius - (18.0 if is_boss else 11.0))
	draw_rect(Rect2(top_left, Vector2(width, 5.0)), Color(0.025, 0.02, 0.03, 0.84))
	draw_rect(Rect2(top_left + Vector2.ONE, Vector2((width - 2.0) * ratio, 3.0)), Color('66bb6a') if ratio > 0.35 else Color('ef5350'))


func _draw_staff_effects() -> void:
	var staff = null
	for weapon in run.weapons:
		if weapon.card['id'] == 'staff':
			staff = weapon
			break
	if staff == null:
		return
	var player_position := Vector2(run.player.x, run.player.y)
	if staff.stats.get('nightParade', false):
		var linked_count: int = 0
		for summon: Dictionary in run.summons:
			if summon.get('dead', false):
				continue
			var summon_position := Vector2(summon['x'], summon['y'])
			if summon_position.distance_squared_to(player_position) > STAFF_LINK_RADIUS * STAFF_LINK_RADIUS:
				continue
			linked_count += 1
			_draw_dashed_line(summon_position, player_position, Color(0.72, 0.46, 1.0, 0.52), 2.0, 9.0, 7.0)
			var flow: float = fmod(animation_time * 0.72 + float(linked_count) * 0.17, 1.0)
			var flow_position: Vector2 = summon_position.lerp(player_position, flow)
			draw_circle(flow_position, 5.0, Color(0.72, 1.0, 0.68, 0.24))
			draw_circle(flow_position, 2.2, Color(0.88, 1.0, 0.82, 0.88))
		if linked_count > 0:
			var pulse: float = 0.5 + sin(animation_time * 5.0) * 0.5
			draw_arc(player_position, 30.0 + pulse * 5.0, 0.0, TAU, 36, Color(0.62, 1.0, 0.58, 0.28 + pulse * 0.16), 2.0)
			_draw_sprite(ArtCatalog.VFX_TEXTURES['healing'], player_position, 68.0 + pulse * 8.0,
				animation_time * 0.18, false, Color(0.75, 1.0, 0.68, 0.24 + pulse * 0.12))
	for blast: Dictionary in staff.blasts:
		var max_t: float = maxf(blast.get('maxT', 0.35), 0.001)
		var blast_alpha: float = clampf(blast['t'] / max_t, 0.0, 1.0)
		var blast_progress: float = 1.0 - blast_alpha
		var blast_position := Vector2(blast['x'], blast['y'])
		var blast_radius: float = blast['maxR'] * (0.22 + blast_progress * 0.88)
		draw_circle(blast_position, blast_radius, Color(0.38, 0.08, 0.52, blast_alpha * 0.14))
		draw_arc(blast_position, blast_radius, 0.0, TAU, 48, Color(0.72, 0.4, 1.0, blast_alpha * 0.9), 4.0)
		draw_arc(blast_position, blast_radius * 0.72, 0.0, TAU, 40, Color(0.5, 1.0, 0.46, blast_alpha * 0.58), 2.0)
		_draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], blast_position, blast_radius * 2.25,
			animation_time * 0.7, false, Color(0.82, 0.62, 1.0, blast_alpha * 0.88))


func _draw_summons() -> void:
	for summon: Dictionary in run.summons:
		if summon.get('dead', false):
			continue
		var summon_position := Vector2(summon['x'], summon['y'])
		if not _is_on_screen(summon_position, 120.0):
			continue
		var radius: float = summon.get('radius', 11.0)
		var is_corpse: bool = summon.get('corpse', false)
		var texture: Texture2D = ArtCatalog.SUMMON_TEXTURES['corpse'] if is_corpse else ArtCatalog.SUMMON_TEXTURES['normal']
		_draw_ellipse_shape(summon_position + Vector2(0.0, radius * 0.7), Vector2(radius, radius * 0.38), Color(0.03, 0.025, 0.035, 0.28))
		if is_corpse:
			_draw_sprite(texture, summon_position - Vector2(0.0, radius * 0.18), radius * 4.3)
		else:
			_draw_sprite(texture, summon_position - Vector2(0.0, radius * 1.05), radius * 4.1, 0.0, run.player.x < summon['x'])
		if summon.get('guardianWardActive', false):
			_draw_sprite(ArtCatalog.SUMMON_TEXTURES['ward'], summon_position + Vector2(radius * 1.35, -radius * 0.35), radius * 3.4, -0.08, false, Color(1.0, 1.0, 1.0, 0.82))
		if summon.get('ghostfireActive', false):
			_draw_sprite(ArtCatalog.SUMMON_TEXTURES['wisp'], summon_position + Vector2(-radius * 1.25, -radius * 1.85), radius * 3.0, sin(animation_time * 2.4) * 0.08)


func _draw_player_projectiles() -> void:
	for projectile in run.projectiles:
		if projectile.dead:
			continue
		var projectile_position := Vector2(projectile.x, projectile.y)
		if not _is_on_screen(projectile_position, 80.0):
			continue
		var source: String = projectile.damageOptions.get('sourceWeaponId', 'sword')
		var texture: Texture2D = ArtCatalog.PROJECTILE_TEXTURES.get(source, ArtCatalog.PROJECTILE_TEXTURES['sword'])
		var color: Color = Color(projectile.color) if not projectile.color.is_empty() else WEAPON_COLORS.get(source, Color.WHITE)
		var velocity := Vector2(projectile.vx, projectile.vy)
		var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT.rotated(projectile.angle)
		var angle: float = direction.angle()
		var size: float = maxf(26.0, projectile.radius * (6.5 if projectile.swordQi else 4.8))
		if source == 'talisman':
			size *= 1.45
		var tail_length: float = size * (1.65 if projectile.swordQi else 1.1)
		if source == 'sword' and projectile.swordQi:
			# Enhanced sword qi rendering — layered xianxia blade effect
			# Outer aura glow
			draw_circle(projectile_position, size * 0.7, Color(color, 0.055))
			draw_circle(projectile_position, size * 0.42, Color(color, 0.10))
			# Long trailing energy tail (dual color)
			_draw_soft_projectile_trail(projectile_position, direction, tail_length, maxf(5.0, projectile.radius * 1.35), color, 0.0)
			# Side wisps (仙气)
			var perp := direction.rotated(PI * 0.5)
			for wisp_i in 2:
				var wisp_t: float = 0.38 + float(wisp_i) * 0.3
				var wisp_pos := projectile_position - direction * tail_length * wisp_t
				var wisp_offset := perp * sin(animation_time * 7.0 + float(wisp_i) * 2.4) * size * 0.12
				draw_line(wisp_pos + wisp_offset - direction * size * 0.13, wisp_pos + wisp_offset + direction * size * 0.04, Color(color, 0.12), 1.2, true)
			# Sword qi sprite (improved texture)
			# 贴图刀尖朝右上（约 -45°），补 +45° 顺时针偏移才能对准飞行方向
			_draw_sprite(ArtCatalog.VFX_TEXTURES['swordProjectileLv2'], projectile_position, size * 1.4, angle + PI * 0.25, false, color)
			# Inner bright core
			draw_circle(projectile_position, size * 0.14, Color(1.0, 1.0, 1.0, 0.58))
		else:
			# Standard projectile rendering
			draw_circle(projectile_position, size * 0.52, Color(color, 0.065))
			_draw_soft_projectile_trail(projectile_position, direction, tail_length, maxf(3.0, projectile.radius * 0.95), color, 1.7)
			if source == 'ring':
				_draw_sprite(ArtCatalog.VFX_TEXTURES['jadeRingTrail'], projectile_position - direction * size * 0.3, size * 1.4, angle, false, Color(1.0, 1.0, 1.0, 0.42))
			elif source == 'staff':
				_draw_sprite(ArtCatalog.VFX_TEXTURES['staffSpiritBolt'], projectile_position - direction * size * 0.2, size * 1.5, angle, false, Color(1.0, 1.0, 1.0, 0.4))
			_draw_sprite(texture, projectile_position, size, angle, false, color)


func _draw_ring_orbit_trail(center: Vector2, orbit_radius: float, angle: float, color: Color, frenzy: bool) -> void:
	var inner_color: Color = color.lerp(Color.WHITE, 0.72)
	var sweep: float = 1.15 if frenzy else 0.9
	var width: float = 24.0 if frenzy else 17.0
	var segment_count: int = 6
	for segment_index in segment_count:
		var t0: float = float(segment_index) / float(segment_count)
		var t1: float = float(segment_index + 1) / float(segment_count)
		var taper: float = pow(t1, 1.4)
		var segment_start: float = angle - sweep * (1.0 - t0)
		var segment_end: float = angle - sweep * (1.0 - t1)
		draw_arc(center, orbit_radius, segment_start, segment_end, 5, Color(color, 0.025 + taper * 0.18), maxf(1.0, width * (0.16 + taper * 0.84)), true)
		if segment_index >= 1:
			draw_arc(center, orbit_radius, segment_start, segment_end, 5, Color(inner_color, taper * 0.42), maxf(0.8, width * (0.08 + taper * 0.2)), true)


func _draw_soft_projectile_trail(projectile_position: Vector2, direction: Vector2, length: float, width: float, color: Color, phase: float) -> void:
	var perpendicular := direction.rotated(PI * 0.5)
	var inner_color: Color = color.lerp(Color.WHITE, 0.68)
	var segment_count: int = 7
	for segment_index in segment_count:
		var t0: float = float(segment_index) / float(segment_count)
		var t1: float = float(segment_index + 1) / float(segment_count)
		var start_offset: float = sin(animation_time * 5.0 + phase + t0 * PI) * width * 0.08 * sin(t0 * PI)
		var end_offset: float = sin(animation_time * 5.0 + phase + t1 * PI) * width * 0.08 * sin(t1 * PI)
		var segment_start := projectile_position - direction * length * (1.0 - t0) + perpendicular * start_offset
		var segment_end := projectile_position - direction * length * (1.0 - t1) + perpendicular * end_offset
		var taper: float = pow(t1, 1.35)
		draw_line(segment_start, segment_end, Color(color, 0.025 + taper * 0.105), maxf(0.8, width * (0.12 + taper * 0.88)), true)
		if segment_index >= 2:
			draw_line(segment_start, segment_end, Color(inner_color, taper * 0.22), maxf(0.65, width * (0.08 + taper * 0.24)), true)


func _draw_hostile_projectiles() -> void:
	for projectile in run.hostileProjectiles:
		if projectile.dead:
			continue
		var projectile_position := Vector2(projectile.x, projectile.y)
		if not _is_on_screen(projectile_position, 60.0):
			continue
		var velocity := Vector2(projectile.vx, projectile.vy)
		var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT
		var angle: float = direction.angle()
		var size: float = maxf(46.0, projectile.radius * 8.4)
		# 不再画程序化圆形光晕：新贴图自带暗紫外圈，叠圆圈会在弹头前方露出一圈多余的盘子
		# Trailing energy (darker, thicker)
		draw_line(projectile_position - direction * size * 1.6, projectile_position, Color(0.5, 0.05, 0.02, 0.22), maxf(3.0, projectile.radius * 2.0), true)
		draw_line(projectile_position - direction * size * 1.0, projectile_position, Color(1.0, 0.35, 0.12, 0.3), maxf(2.0, projectile.radius * 1.2), true)
		# Core energy lines
		draw_line(projectile_position - direction * size * 0.5, projectile_position, Color(1.0, 0.65, 0.3, 0.45), maxf(1.5, projectile.radius * 0.6), true)
		# Projectile sprite (improved texture)
		_draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['hostile'], projectile_position, size, angle)


func _draw_talisman_effects() -> void:
	var talisman = null
	for weapon in run.weapons:
		if weapon.card['id'] == 'talisman':
			talisman = weapon
			break
	if talisman == null:
		return
	# Draw bolt strikes (thunder falling from sky)
	for fx: Dictionary in talisman.bolt_fx:
		var strike_position := Vector2(fx['x'], fx['y'])
		var alpha: float = clampf(fx['ttl'] / 0.22, 0.0, 1.0)
		var is_aoe: bool = fx.get('aoe', false)
		var is_sword: bool = fx.get('swordSynergy', false)
		# Ground impact glow
		var impact_r: float = 58.0 if is_aoe else 38.0
		draw_circle(strike_position, impact_r * (1.0 + (1.0 - alpha) * 0.5), Color(0.5, 0.7, 1.0, alpha * 0.22))
		draw_circle(strike_position, impact_r * 0.55, Color(0.8, 0.9, 1.0, alpha * 0.4))
		# Lightning bolt from above
		var bolt_height: float = 230.0
		var bolt_top := strike_position + Vector2(0.0, -bolt_height)
		var bolt_color := Color(0.6, 0.8, 1.0, alpha * 0.72) if not is_sword else Color(0.9, 0.7, 1.0, alpha * 0.72)
		var core_color := Color(1.0, 1.0, 1.0, alpha * 0.94)
		# Jagged lightning path
		var segments := PackedVector2Array()
		var current_pos := bolt_top
		segments.append(current_pos)
		var step_count: int = 7
		var seg_h: float = bolt_height / float(step_count)
		for seg_i in step_count:
			var jitter_x: float = sin(float(seg_i) * 7.3 + animation_time * 30.0) * 18.0
			current_pos = Vector2(strike_position.x + jitter_x, bolt_top.y + float(seg_i + 1) * seg_h)
			segments.append(current_pos)
		# Draw outer glow line
		for seg_i in range(segments.size() - 1):
			draw_line(segments[seg_i], segments[seg_i + 1], bolt_color, 7.5, true)
		# Draw core line (thinner, brighter)
		for seg_i in range(segments.size() - 1):
			draw_line(segments[seg_i], segments[seg_i + 1], core_color, 2.8, true)
		# Branch lightning
		for branch_i in 4:
			var branch_start_idx: int = 1 + branch_i * 2
			if branch_start_idx >= segments.size():
				continue
			var branch_start := segments[branch_start_idx]
			var branch_angle: float = float(branch_i) * 1.0 - 1.5 + sin(animation_time * 20.0) * 0.3
			var branch_end := branch_start + Vector2(cos(branch_angle), sin(branch_angle) * 0.5 + 0.5).normalized() * 36.0
			draw_line(branch_start, branch_end, Color(0.6, 0.8, 1.0, alpha * 0.46), 2.2, true)
		# Impact texture
		_draw_sprite(ArtCatalog.VFX_TEXTURES.get('thunderStrike', ArtCatalog.VFX_TEXTURES['talismanLightning']), strike_position, 104.0 + (1.0 - alpha) * 28.0, 0.0, false, Color(1.0, 1.0, 1.0, alpha * 0.9))
		if is_aoe:
			var aoe_radius: float = fx.get('radius', 80.0)
			draw_arc(strike_position, aoe_radius * (1.0 + (1.0 - alpha) * 0.3), 0.0, TAU, 40, Color(0.5, 0.7, 1.0, alpha * 0.5), 3.6)
		# Draw chain lightning arcs
	for fx: Dictionary in talisman.chain_fx:
		var start := Vector2(fx['x1'], fx['y1'])
		var finish := Vector2(fx['x2'], fx['y2'])
		var alpha: float = clampf(fx['ttl'] / 0.15, 0.0, 1.0)
		var is_relay: bool = fx.get('relay', false)
		var chain_color := Color(0.4, 0.7, 1.0, alpha * 0.6) if not is_relay else Color(0.6, 0.4, 1.0, alpha * 0.5)
		# Jagged chain path
		var diff := finish - start
		var seg_count: int = 6
		var prev := start
		for seg_i in range(1, seg_count + 1):
			var t: float = float(seg_i) / float(seg_count)
			var point := start + diff * t
			if seg_i < seg_count:
				var perp := Vector2(-diff.y, diff.x).normalized()
				var jitter: float = sin(float(seg_i) * 11.0 + animation_time * 25.0) * 16.0
				point += perp * jitter
			draw_line(prev, point, chain_color, 4.0, true)
			draw_line(prev, point, Color(1.0, 1.0, 1.0, alpha * 0.58), 1.6, true)
			prev = point
		# Small spark at endpoints
		draw_circle(finish, 6.0, Color(0.7, 0.85, 1.0, alpha * 0.58))


func _draw_effects() -> void:
	var visible_impact_total: int = 0
	for effect: Dictionary in run.effects:
		if effect.get('type', '') == 'weaponImpact' and _effect_point_on_screen(effect, 100.0):
			visible_impact_total += 1
	var visible_impact_index: int = 0
	var detailed_impact_count: int = 0
	for effect: Dictionary in run.effects:
		var ttl: float = effect.get('ttl', 0.0)
		var max_ttl: float = maxf(effect.get('maxTtl', ttl), 0.0001)
		var alpha: float = clampf(ttl / max_ttl, 0.0, 1.0)
		match effect.get('type', ''):
			'weaponEvolution':
				_draw_weapon_evolution(effect, alpha)
			'synergyArc':
				var start_position := Vector2(effect['x1'], effect['y1'])
				var finish_position := Vector2(effect['x2'], effect['y2'])
				var midpoint := (start_position + finish_position) * 0.5
				if _is_on_screen(start_position) or _is_on_screen(finish_position) or _is_on_screen(midpoint):
					_draw_sprite(ArtCatalog.VFX_TEXTURES['synergyArc'], midpoint, maxf(42.0, start_position.distance_to(finish_position) * 1.1), (finish_position - start_position).angle(), false, Color(1.0, 1.0, 1.0, alpha))
					draw_line(start_position, finish_position, Color(effect.get('color', '80deea'), alpha * 0.8), 2.0)
			'synergyFlameBlade':
				var start_position := Vector2(effect['x1'], effect['y1'])
				var finish_position := Vector2(effect['x2'], effect['y2'])
				var midpoint := (start_position + finish_position) * 0.5
				if _is_on_screen(start_position) or _is_on_screen(finish_position) or _is_on_screen(midpoint):
					_draw_sprite(ArtCatalog.VFX_TEXTURES['swordSlash'], midpoint, start_position.distance_to(finish_position) * 1.2, (finish_position - start_position).angle(), false, Color(1.0, 0.55, 0.35, alpha))
			'synergyCommandMark':
				if _effect_point_on_screen(effect, 60.0):
					_draw_sprite(ArtCatalog.UI_TEXTURES['sealWeapon'], Vector2(effect['x'], effect['y'] - 28.0), 30.0, 0.0, false, Color(0.9, 0.65, 1.0, alpha))
			'synergyTrigger':
				var trigger_radius: float = effect.get('radius', 54.0)
				if _effect_point_on_screen(effect, trigger_radius * 2.0):
					var trigger_position := Vector2(effect['x'], effect['y'])
					var trigger_progress: float = 1.0 - alpha
					draw_circle(trigger_position, trigger_radius * (0.45 + trigger_progress * 0.75), Color(0.28, 0.95, 0.82, alpha * 0.12))
					draw_arc(trigger_position, trigger_radius * (0.55 + trigger_progress * 0.95), 0.0, TAU, 48, Color(0.46, 0.95, 0.84, alpha * 0.92), 3.0)
					draw_arc(trigger_position, trigger_radius * (0.35 + trigger_progress * 0.65), animation_time, animation_time + PI * 1.45, 32, Color(1.0, 0.76, 0.30, alpha * 0.88), 2.0)
					_draw_sprite(ArtCatalog.VFX_TEXTURES['synergyArc'], trigger_position, trigger_radius * 1.7, animation_time * 0.4, false, Color(1.0, 1.0, 1.0, alpha * 0.65))
			'weaponImpact':
				if _effect_point_on_screen(effect, 100.0):
					var detailed: bool = is_budget_sample(visible_impact_index, visible_impact_total, DETAILED_IMPACT_BUDGET)
					if detailed:
						_draw_weapon_impact(effect, alpha, detailed_impact_count < DAMAGE_NUMBER_BUDGET)
						detailed_impact_count += 1
					else:
						_draw_compact_weapon_impact(effect, alpha)
					visible_impact_index += 1
			'enemyDefeat':
				if _effect_point_on_screen(effect, 160.0):
					_draw_enemy_defeat(effect, alpha)
			'slash':
				var slash_position := Vector2(effect['x'], effect['y'])
				var slash_range: float = effect.get('range', 50.0)
				if _is_on_screen(slash_position, slash_range):
					var slash_angle: float = effect.get('angle', 0.0)
					draw_circle(slash_position, slash_range * 0.6, Color(0.77, 0.95, 1.0, alpha * 0.15))
					_draw_sprite(ArtCatalog.VFX_TEXTURES['swordSlash'], slash_position, slash_range * 2.6, slash_angle, false, Color(1.0, 1.0, 1.0, alpha))
					_draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], slash_position, slash_range * 1.2, slash_angle, false, Color(0.77, 0.95, 1.0, alpha * 0.5))
			'enemyBlast':
				var blast_radius: float = effect.get('radius', 40.0) * 2.25
				if _effect_point_on_screen(effect, blast_radius):
					_draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], Vector2(effect['x'], effect['y']), blast_radius, 0.0, false, Color(1.0, 1.0, 1.0, alpha))
			'synergyBurst':
				var burst_radius: float = effect.get('radius', 34.0) * 2.3
				if _effect_point_on_screen(effect, burst_radius):
					var texture: Texture2D = ArtCatalog.VFX_TEXTURES['talismanLightning'] if effect.get('style') == 'lightningFire' else ArtCatalog.VFX_TEXTURES['synergyArc']
					_draw_sprite(texture, Vector2(effect['x'], effect['y']), burst_radius, animation_time * 0.15, false, Color(1.0, 1.0, 1.0, alpha))
			_:
				if effect.has('x') and effect.has('y') and effect.has('radius') and _effect_point_on_screen(effect, effect['radius'] * 2.0):
					_draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], Vector2(effect['x'], effect['y']), effect['radius'] * 2.0, 0.0, false, Color(effect.get('color', 'ff8a50'), alpha))


func _draw_weapon_evolution(effect: Dictionary, alpha: float) -> void:
	var position := Vector2(effect['x'], effect['y'])
	var weapon_id: String = effect.get('weaponId', 'sword')
	var ultimate: bool = effect.get('evolutionLevel', 4) >= 6
	var progress: float = 1.0 - alpha
	var pulse: float = sin(progress * PI)
	var radius: float = effect.get('radius', 190.0) * (0.18 + progress * 0.82)
	var color := Color(effect.get('color', '#fff176'))
	var ray_count: int = 20 if ultimate else 12
	var core_size: float = 150.0 if ultimate else 104.0
	draw_circle(position, radius, Color(color, alpha * (0.08 + pulse * 0.08)))
	draw_circle(position, radius * 0.52, Color(1.0, 0.96, 0.78, alpha * 0.08))
	draw_arc(position, radius, animation_time * 0.7, animation_time * 0.7 + TAU, 96, Color(color, alpha * 0.96), 5.0 if ultimate else 3.0)
	draw_arc(position, radius * 0.72, -animation_time, -animation_time + PI * 1.65, 72, Color(1.0, 0.88, 0.48, alpha * 0.82), 3.0)
	for ray_index in ray_count:
		var angle: float = float(ray_index) * TAU / float(ray_count) + animation_time * (0.34 if ultimate else 0.18)
		var inner := position + Vector2.RIGHT.rotated(angle) * radius * 0.28
		var outer := position + Vector2.RIGHT.rotated(angle) * radius * (0.84 + float(ray_index % 3) * 0.08)
		draw_line(inner, outer, Color(color, alpha * (0.38 + pulse * 0.4)), 3.0 if ultimate else 1.8, true)
	match weapon_id:
		'sword':
			for blade_index in (10 if ultimate else 6):
				var angle: float = float(blade_index) * TAU / float(10 if ultimate else 6) + animation_time * 0.55
				var blade_position := position + Vector2.RIGHT.rotated(angle) * radius * 0.56
				_draw_sprite(ArtCatalog.VFX_TEXTURES['swordSlash'], blade_position, core_size, angle + PI * 0.5, false, Color(color, alpha))
		'cloak':
			_draw_sprite(ArtCatalog.VFX_TEXTURES['cloakFireBurst'], position, radius * 2.1, animation_time * 0.25, false, Color(1.0, 0.86, 0.56, alpha))
			_draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], position, core_size * 1.35, -animation_time * 0.4, false, Color(1.0, 0.5, 0.24, alpha * 0.8))
		'talisman':
			for bolt_index in (8 if ultimate else 5):
				var angle: float = float(bolt_index) * TAU / float(8 if ultimate else 5) + animation_time * 0.45
				var bolt_position := position + Vector2.RIGHT.rotated(angle) * radius * 0.48
				_draw_sprite(ArtCatalog.VFX_TEXTURES['talismanLightning'], bolt_position, core_size, angle, false, Color(1.0, 0.96, 0.58, alpha))
		'trail':
			for flame_index in (9 if ultimate else 6):
				var angle: float = float(flame_index) * TAU / float(9 if ultimate else 6) - animation_time * 0.4
				var flame_position := position + Vector2.RIGHT.rotated(angle) * radius * 0.5
				_draw_flame_anim(flame_position, core_size * 0.72, Color(1.0, 0.72, 0.3, alpha), angle)
		'ring':
			for ring_index in (8 if ultimate else 5):
				var angle: float = float(ring_index) * TAU / float(8 if ultimate else 5) + animation_time * 0.8
				var ring_position := position + Vector2.RIGHT.rotated(angle) * radius * 0.5
				_draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['ring'], ring_position, core_size * 0.62, angle, false, Color(0.72, 1.0, 0.88, alpha))
		'staff':
			_draw_sprite(ArtCatalog.VFX_TEXTURES['synergyArc'], position, radius * 1.5, animation_time * 0.45, false, Color(0.88, 0.62, 1.0, alpha * 0.9))
			for spirit_index in (8 if ultimate else 5):
				var angle: float = float(spirit_index) * TAU / float(8 if ultimate else 5) - animation_time * 0.65
				var spirit_position := position + Vector2.RIGHT.rotated(angle) * radius * 0.48
				_draw_sprite(ArtCatalog.VFX_TEXTURES['staffSpiritBolt'], spirit_position, core_size * 0.65, angle, false, Color(0.9, 0.7, 1.0, alpha))
	_draw_sprite(ArtCatalog.WEAPON_ICONS.get(weapon_id), position, core_size * (0.78 + pulse * 0.18), 0.0, false, Color(1.0, 1.0, 1.0, alpha))


func _draw_weapon_impact(effect: Dictionary, alpha: float, show_damage_number: bool) -> void:
	var impact_position := Vector2(effect['x'], effect['y'])
	var source: String = effect.get('sourceWeaponId', 'sword')
	var color: Color = WEAPON_COLORS.get(source, Color.WHITE)
	var progress: float = 1.0 - alpha
	var radius: float = maxf(effect.get('radius', 12.0), 10.0)
	var intensity: float = clampf(effect.get('damage', 1.0) / 80.0, 0.35, 1.0)
	var action: String = effect.get('sourceAction', 'hit')
	# 缩小后的光晕
	draw_circle(impact_position, radius * (0.9 + progress * 1.2), Color(color, alpha * 0.28 * intensity))
	draw_circle(impact_position, radius * (0.5 + progress * 0.7), Color(1.0, 1.0, 1.0, alpha * 0.14))
	draw_arc(impact_position, radius * (0.7 + progress * 1.3), 0.0, TAU, 24, Color(color, alpha * (0.7 + intensity * 0.1)), 2.0 + intensity * 1.2)
	var texture_key: String = IMPACT_TEXTURE_KEYS.get(source, 'impact')
	# 击中精灵整体缩小到原来的 ~45%
	var impact_size: float = radius * (3.5 + intensity * 2.0) * (0.9 + progress * 0.35)
	var impact_rotation: float = effect.get('angle', 0.0)
	if source == 'sword':
		impact_size *= 1.4
	elif source == 'talisman':
		impact_rotation += sin(float(effect.get('seed', 0))) * 0.3
	elif source == 'cloak' or source == 'trail':
		impact_size *= 1.3
		impact_rotation = animation_time * 0.8
	elif source == 'ring':
		impact_rotation = animation_time * 1.4
	elif source == 'staff':
		impact_rotation += PI * 0.5
	_draw_sprite(ArtCatalog.VFX_TEXTURES[texture_key], impact_position, impact_size, impact_rotation, false, Color(1.0, 1.0, 1.0, alpha))
	_draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], impact_position, radius * (2.4 + progress * 1.2), impact_rotation * 0.25, false, Color(color, alpha * 0.85))
	_draw_impact_sparks(impact_position, radius * 0.9, color, alpha, int(effect.get('seed', 0)), action)
	if show_damage_number:
		_draw_damage_number(effect, impact_position, radius, color, alpha, progress, intensity)


func _draw_compact_weapon_impact(effect: Dictionary, alpha: float) -> void:
	var impact_position := Vector2(effect['x'], effect['y'])
	var source: String = effect.get('sourceWeaponId', 'sword')
	var color: Color = WEAPON_COLORS.get(source, Color.WHITE)
	var radius: float = maxf(effect.get('radius', 12.0), 10.0)
	draw_circle(impact_position, radius * 0.72, Color(color, alpha * 0.24))
	_draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], impact_position, radius * 1.65, 0.0, false, Color(color, alpha * 0.68))


func _draw_damage_number(effect: Dictionary, impact_position: Vector2, radius: float, _color: Color, alpha: float, progress: float, intensity: float) -> void:
	var damage: int = maxi(1, roundi(effect.get('damage', 1.0)))
	var text: String = str(damage)
	var text_position := impact_position + Vector2(-38.0, -radius * 1.15 - progress * 22.0)
	var font_size: int = 22 + roundi(intensity * 10.0)
	# 更深的描边，确保数字清晰可见
	var shadow := Color(0.12, 0.05, 0.02, alpha * 0.98)
	for offset: Vector2 in DAMAGE_NUMBER_OFFSETS:
		draw_string(UI_FONT, text_position + offset, text, HORIZONTAL_ALIGNMENT_CENTER, 76.0, font_size, shadow)
	draw_string(UI_FONT, text_position, text, HORIZONTAL_ALIGNMENT_CENTER, 76.0, font_size, Color(1.0, 0.94, 0.68, alpha))
	if intensity >= 0.82:
		var tag_position := text_position + Vector2(54.0, 8.0)
		draw_circle(tag_position + Vector2(11.0, -7.0), 13.0, Color(0.48, 0.12, 0.08, alpha * 0.94))
		draw_string(UI_FONT, tag_position, '?!', HORIZONTAL_ALIGNMENT_CENTER, 22.0, 12, Color(1.0, 0.92, 0.68, alpha))


func _draw_enemy_dots(enemy_position: Vector2, radius: float, dots: Dictionary, pulse: float, detailed: bool = true) -> void:
	var has_burn: bool = dots.has('burn') and dots['burn'].get('timer', 0.0) > 0.0
	var has_bleed: bool = dots.has('bleed') and dots['bleed'].get('timer', 0.0) > 0.0
	var has_poison: bool = dots.has('poison') and dots['poison'].get('timer', 0.0) > 0.0
	var active_count: int = int(has_burn) + int(has_bleed) + int(has_poison)
	if active_count == 0:
		return
	var dot_y: float = enemy_position.y - radius - 14.0
	var spacing: float = 20.0
	var next_x: float = enemy_position.x - float(active_count - 1) * spacing * 0.5
	var flicker: float = sin(animation_time * 8.0) * 0.5 + 0.5
	if not detailed:
		var compact_radius: float = 3.8 + pulse * 0.7
		if has_burn:
			draw_circle(Vector2(next_x, dot_y), compact_radius, Color(1.0, 0.48, 0.08, 0.88))
			next_x += spacing
		if has_bleed:
			draw_circle(Vector2(next_x, dot_y), compact_radius, Color(0.92, 0.05, 0.12, 0.88))
			next_x += spacing
		if has_poison:
			draw_circle(Vector2(next_x, dot_y), compact_radius, Color(0.42, 1.0, 0.28, 0.88))
		return
	if has_burn:
		var burn_position := Vector2(next_x, dot_y)
		next_x += spacing
		var burn_size: float = 30.0 + pulse * 4.0 + flicker * 3.0
		draw_circle(burn_position, burn_size * 0.7, Color(1.0, 0.3, 0.05, 0.15 + flicker * 0.08))
		var frame_offset: float = sin(animation_time * 12.0) * 2.0
		draw_circle(burn_position + Vector2(0.0, frame_offset), burn_size * 0.45, Color(1.0, 0.55, 0.1, 0.5))
		draw_circle(burn_position + Vector2(0.0, frame_offset - 1.5), burn_size * 0.3, Color(1.0, 0.85, 0.3, 0.65))
		draw_circle(burn_position + Vector2(0.0, frame_offset - 3.0), burn_size * 0.15, Color(1.0, 1.0, 0.8, 0.8))
		_draw_sprite(ArtCatalog.VFX_TEXTURES.get('burnDot', ArtCatalog.VFX_TEXTURES['impact']), burn_position + Vector2(0.0, frame_offset), burn_size * 1.3, animation_time * 0.4, false, Color(1.0, 0.9, 0.7, 0.7 + flicker * 0.2))
	if has_bleed:
		var bleed_position := Vector2(next_x, dot_y)
		next_x += spacing
		var bleed_alpha: float = 0.58 + flicker * 0.26
		draw_circle(bleed_position, 12.0 + pulse * 1.5, Color(0.72, 0.02, 0.08, bleed_alpha * 0.2))
		draw_line(bleed_position + Vector2(-7.0, -5.0), bleed_position + Vector2(4.0, 7.0), Color(0.95, 0.08, 0.16, bleed_alpha), 3.0, true)
		draw_line(bleed_position + Vector2(1.0, -7.0), bleed_position + Vector2(8.0, 3.0), Color(1.0, 0.38, 0.38, bleed_alpha * 0.78), 2.0, true)
		draw_circle(bleed_position + Vector2(5.0, 8.0 + flicker * 2.0), 3.0, Color(0.78, 0.0, 0.08, bleed_alpha))
	if has_poison:
		var poison_position := Vector2(next_x, dot_y)
		var poison_size: float = 22.0 + pulse * 2.0
		draw_circle(poison_position, poison_size * 0.5, Color(0.4, 1.0, 0.3, 0.18 + flicker * 0.06))
		_draw_sprite(ArtCatalog.VFX_TEXTURES['poison'], poison_position, poison_size, animation_time * 0.25, false, Color(0.7, 1.0, 0.6, 0.65 + flicker * 0.15))


# 冲撞预警：把锁定方向、真实冲撞覆盖距离和剩余蓄力时间全部画出来。
# windup（0.65s）里危险区按进度充能，dash（0.55s）里保留并淡出，避免"一闪就没了看不见"。
func _draw_charge_indicator(enemy_position: Vector2, radius: float, enemy) -> void:
	var config: Dictionary = Config.CONFIG['enemyTypes']['charger']
	var dir := Vector2(enemy.lockedDirection.get('x', 1.0), enemy.lockedDirection.get('y', 0.0))
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var angle: float = dir.angle()
	var perpendicular: Vector2 = dir.rotated(PI * 0.5)
	var dashing: bool = enemy.state == 'dash'
	var dash_duration: float = maxf(0.001, float(config.get('dashDuration', 0.55)))
	var windup_total: float = maxf(0.001, float(config.get('windup', 0.65)))
	# 危险区长度取配置真值：dashSpeed × 剩余冲刺时间，就是它还能撞到的范围
	# （蓄力中按整段 dashDuration 预告，冲刺中随剩余时间收缩，终点始终落在真实撞击点）
	var remaining: float = enemy.stateTimer if dashing else dash_duration
	var lane_length: float = float(config.get('dashSpeed', 400.0)) * clampf(remaining, 0.0, dash_duration)
	var half_width: float = radius * 1.2
	var progress: float = 1.0 if dashing else clampf(1.0 - enemy.stateTimer / windup_total, 0.0, 1.0)
	var fade: float = clampf(enemy.stateTimer / dash_duration, 0.0, 1.0) if dashing else 1.0
	var pulse: float = 0.5 + sin(animation_time * 16.0) * 0.5
	var lane_start: Vector2 = enemy_position + dir * radius * 0.5
	var lane_end: Vector2 = lane_start + dir * lane_length
	var charged_end: Vector2 = lane_start.lerp(lane_end, progress)
	# 1) 整条危险区底色
	draw_colored_polygon(_lane_quad(lane_start, lane_end, perpendicular, half_width), Color(1.0, 0.24, 0.10, 0.10 * fade))
	# 2) 蓄力充能部分：越接近发动越亮，直观读出"还有多久撞过来"
	if progress > 0.01:
		draw_colored_polygon(_lane_quad(lane_start, charged_end, perpendicular, half_width),
			Color(1.0, 0.42, 0.12, (0.20 + progress * 0.26) * fade))
		draw_line(charged_end + perpendicular * half_width, charged_end - perpendicular * half_width,
			Color(1.0, 0.95, 0.7, (0.55 + pulse * 0.35) * fade), 3.0, true)
	# 3) 两侧护栏
	var rail_color := Color(1.0, 0.5 + pulse * 0.2, 0.15, (0.5 + progress * 0.4) * fade)
	draw_line(lane_start + perpendicular * half_width, lane_end + perpendicular * half_width, rail_color, 2.5, true)
	draw_line(lane_start - perpendicular * half_width, lane_end - perpendicular * half_width, rail_color, 2.5, true)
	# 4) 落点箭头
	var arrow_size: float = half_width * (1.1 + progress * 0.5)
	draw_colored_polygon(PackedVector2Array([
		lane_end + dir * arrow_size,
		lane_end + perpendicular * arrow_size,
		lane_end - perpendicular * arrow_size,
	]), Color(1.0, 0.62, 0.18, (0.62 + progress * 0.3) * fade))
	# 5) 倒计时环：随蓄力合拢，撞出瞬间刚好闭合
	draw_arc(enemy_position, radius * 1.9 + pulse * 3.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40,
		Color(1.0, 0.85, 0.4, (0.5 + pulse * 0.3) * fade), 4.0)
	draw_arc(enemy_position, radius * 1.9, 0.0, TAU, 32, Color(1.0, 0.3, 0.12, 0.3 * fade), 1.5)
	# 6) 预警图标贴在危险区中段，跟着锁定方向转
	_draw_sprite(ArtCatalog.VFX_TEXTURES['chargeIndicator'], lane_start.lerp(lane_end, 0.55),
		68.0 + progress * 26.0, angle, false, Color(1.0, 0.92, 0.7, (0.7 + progress * 0.3) * fade))


static func _lane_quad(start: Vector2, finish: Vector2, perpendicular: Vector2, half_width: float) -> PackedVector2Array:
	return PackedVector2Array([
		start + perpendicular * half_width,
		finish + perpendicular * half_width,
		finish - perpendicular * half_width,
		start - perpendicular * half_width,
	])


func _draw_enemy_defeat(effect: Dictionary, alpha: float) -> void:
	var defeat_position := Vector2(effect['x'], effect['y'])
	var progress: float = 1.0 - alpha
	var radius: float = maxf(effect.get('radius', 12.0), 10.0)
	var source: String = effect.get('sourceWeaponId', 'status')
	var color: Color = WEAPON_COLORS.get(source, WEAPON_COLORS['status'])
	var is_boss: bool = effect.get('rank', '') == 'boss'
	var texture: Texture2D = ArtCatalog.ENEMY_TEXTURES.get(effect.get('enemyType', 'chaser'), ArtCatalog.ENEMY_TEXTURES['chaser'])
	var ghost_size: float = radius * (6.6 if is_boss else 6.2) * (1.0 + progress * 0.18)
	_draw_sprite(texture, defeat_position - Vector2(0.0, radius * 1.5 + progress * 18.0), ghost_size, progress * 0.08, effect.get('flipH', false), Color(1.0, 0.72 + progress * 0.2, 0.55 + progress * 0.25, alpha * 0.62))
	draw_circle(defeat_position, radius * (0.8 + progress * 2.8), Color(color, alpha * 0.13))
	draw_arc(defeat_position, radius * (0.65 + progress * 3.2), 0.0, TAU, 36, Color(color, alpha * 0.82), 3.2 if is_boss else 2.1)
	_draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], defeat_position, radius * (4.2 if is_boss else 3.2) * (0.8 + progress * 0.55), animation_time * 0.5, false, Color(1.0, 1.0, 1.0, alpha * 0.86))
	_draw_impact_sparks(defeat_position, radius * (1.55 if is_boss else 1.0), color, alpha, int(effect.get('seed', 0)) + 17, 'defeat')


func _draw_impact_sparks(impact_position: Vector2, radius: float, color: Color, alpha: float, spark_seed: int, action: String) -> void:
	var spark_count: int = 9 if action == 'defeat' else 6
	for i in spark_count:
		var angle: float = float(i) * TAU / float(spark_count) + float(spark_seed % 23) * 0.17
		var length: float = radius * (0.7 + float((spark_seed + i * 7) % 5) * 0.16)
		var inner := impact_position + Vector2.RIGHT.rotated(angle) * radius * 0.42
		var outer := impact_position + Vector2.RIGHT.rotated(angle) * length * (1.0 + (1.0 - alpha) * 0.8)
		draw_line(inner, outer, Color(color, alpha * 0.78), 1.6, true)
		draw_circle(outer, 1.3 + float(i % 2), Color(1.0, 0.96, 0.78, alpha * 0.75))


func _draw_dashed_line(start: Vector2, finish: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var delta: Vector2 = finish - start
	var length: float = delta.length()
	if length <= 0.001:
		return
	var direction: Vector2 = delta / length
	var cursor: float = -fmod(animation_time * 18.0, dash + gap)
	while cursor < length:
		var segment_start: float = maxf(cursor, 0.0)
		var segment_end: float = minf(cursor + dash, length)
		if segment_end > segment_start:
			draw_line(start + direction * segment_start, start + direction * segment_end, color, width, true)
		cursor += dash + gap


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- 序列帧（flipbook）绘制 ----------

## 从图集中裁出 region 区域、以 center 为中心绘制；display_size 为 region 长边的显示尺寸，rotation 绕中心。
func _draw_sprite_region(texture: Texture2D, region: Rect2, center: Vector2, display_size: float, texture_rotation: float = 0.0, tint: Color = Color.WHITE) -> void:
	if texture == null or display_size <= 0.0 or region.size.x <= 0.0 or region.size.y <= 0.0:
		return
	var factor: float = display_size / maxf(region.size.x, region.size.y)
	var rect_size := region.size * factor
	draw_set_transform(center, texture_rotation, Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(-rect_size * 0.5, rect_size), region, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 循环火焰动画（丹火炉 / trail 火苗 / 丹火核心共用）：帧 = floor(animation_time × FLAME_FPS) % 25，
## 叠加世界坐标导出的位置相位，避免所有火焰同一步调。
func _draw_flame_anim(center: Vector2, display_size: float, tint: Color = Color.WHITE, rotation: float = 0.0) -> void:
	var texture: Texture2D = ArtCatalog.VFX_TEXTURES.get('furnaceFlameAnim')
	if texture == null:
		_draw_sprite(ArtCatalog.VFX_TEXTURES['furnaceFlame'], center, display_size, rotation, false, tint)
		return
	var phase: float = fposmod(center.x * 0.031 + center.y * 0.017, 1.0) * float(FLAME_LOOP_FRAMES)
	var frame: int = int(floor(animation_time * FLAME_FPS + phase)) % FLAME_LOOP_FRAMES
	_draw_sprite_region(texture, FlipbookScript.frame_region(frame, 5, 2048, 393, 8), center, display_size, rotation, tint)


# ---------- 敌人攻击预警（纯显示，不改逻辑与数值） ----------

## bomber 自爆蓄力：红色光晕随进度加速闪烁 + 圆环从爆炸半径向本体收缩，预告 blastRadius 爆炸区。
func _draw_bomber_windup_warning(enemy_position: Vector2, radius: float, enemy) -> void:
	var duration: float = maxf(enemy.windupDuration, 0.001)
	var progress: float = clampf(enemy.windupTimer / duration, 0.0, 1.0)
	var blast_radius: float = maxf(enemy.blastRadius, radius * 1.2)
	# 闪烁频率 6Hz→16Hz 随进度加速，直观读出“接近起爆”
	var flash: float = 0.5 + sin(animation_time * TAU * (6.0 + progress * 10.0)) * 0.5
	draw_circle(enemy_position, blast_radius * (0.55 + progress * 0.45),
		Color(1.0, 0.16, 0.08, (0.06 + progress * 0.12) * (0.35 + flash * 0.65)))
	var ring_radius: float = lerpf(blast_radius, radius * 1.15, progress)
	draw_arc(enemy_position, ring_radius, 0.0, TAU, 48, Color(1.0, 0.24, 0.1, 0.35 + progress * 0.45), 2.5 + progress * 2.0)


## enhanced_chaser 狂暴前预警（warningTimer > 0）：红色脉动光环 + 旋转断口描边，与狂暴后的完整表现区分。
func _draw_chaser_enrage_warning(enemy_position: Vector2, radius: float, enemy) -> void:
	var duration: float = maxf(enemy.warningDuration, 0.001)
	var progress: float = clampf(1.0 - enemy.warningTimer / duration, 0.0, 1.0)
	var pulse: float = 0.5 + sin(animation_time * TAU * 5.0) * 0.5
	var intensity: float = 0.35 + progress * 0.4
	draw_circle(enemy_position, radius * (1.5 + pulse * 0.14), Color(1.0, 0.12, 0.1, intensity * 0.14))
	draw_arc(enemy_position, radius * 1.25 + pulse * 3.0, 0.0, TAU, 36,
		Color(1.0, 0.2, 0.14, intensity * (0.55 + pulse * 0.35)), 2.5)
	# 两段旋转断口外描边：区别于狂暴状态
	var spin: float = animation_time * 3.0
	draw_arc(enemy_position, radius * 1.6, spin, spin + PI * 0.8, 20, Color(1.0, 0.32, 0.18, intensity * 0.7), 2.0)
	draw_arc(enemy_position, radius * 1.6, spin + PI, spin + PI * 1.8, 20, Color(1.0, 0.32, 0.18, intensity * 0.7), 2.0)


## boss 弹幕蓄力：预警环随进度向外扩张暗示环形弹幕，另有贴身蓄力倒计时弧。
func _draw_boss_windup_warning(enemy_position: Vector2, radius: float, enemy) -> void:
	var windup_total: float = maxf(float(Config.CONFIG['enemyTypes']['boss'].get('windup', 0.85)), 0.001)
	var progress: float = clampf(enemy.windupTimer / windup_total, 0.0, 1.0)
	var pulse: float = 0.5 + sin(animation_time * TAU * 4.0) * 0.5
	var ring_radius: float = radius * (1.3 + progress * 2.2)
	draw_arc(enemy_position, ring_radius, 0.0, TAU, 56,
		Color(1.0, 0.3, 0.25, (0.3 + progress * 0.5) * (0.6 + pulse * 0.4)), 3.0 + progress * 2.5)
	draw_arc(enemy_position, radius * 1.9, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(1.0, 0.62, 0.3, 0.75), 4.0)


## ranged 枪口蓄力点：无 windup 状态，fireCooldown < fireInterval×25% 时画渐亮蓄力光点。
func _draw_ranged_charge_warning(enemy_position: Vector2, radius: float, enemy) -> void:
	var threshold: float = maxf(enemy.fireInterval, 0.001) * 0.25
	if enemy.fireCooldown >= threshold:
		return
	var charge: float = clampf(1.0 - enemy.fireCooldown / threshold, 0.0, 1.0)
	var pulse: float = 0.5 + sin(animation_time * TAU * 6.0) * 0.5
	var glow_alpha: float = charge * (0.5 + pulse * 0.3)
	draw_circle(enemy_position, radius * (0.7 + charge * 0.5), Color(1.0, 0.42, 0.12, glow_alpha * 0.22))
	var muzzle: Vector2 = enemy_position + Vector2.RIGHT.rotated(enemy.aimAngle) * (radius + 4.0)
	draw_circle(muzzle, 2.5 + charge * 4.5, Color(1.0, 0.85, 0.45, glow_alpha * 0.9))



func _draw_sprite(texture: Texture2D, center: Vector2, display_size: float, texture_rotation: float = 0.0, flip_h: bool = false, tint: Color = Color.WHITE) -> void:
	if texture == null or display_size <= 0.0:
		return
	var texture_size: Vector2 = texture.get_size()
	var factor: float = display_size / maxf(texture_size.x, texture_size.y)
	var texture_scale := Vector2(-factor if flip_h else factor, factor)
	draw_set_transform(center, texture_rotation, texture_scale)
	draw_texture(texture, -texture_size * 0.5, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _point(value: Dictionary) -> Vector2:
	return Vector2(value['x'], value['y'])
