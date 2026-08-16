extends Node2D

const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
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

var run = null
var animation_time: float = 0.0


func bind_run(game_run) -> void:
  run = game_run
  queue_redraw()


func refresh(delta: float = 0.0) -> void:
  animation_time += delta
  queue_redraw()


func _draw() -> void:
  if run == null:
    return
  _draw_ambient_motes()
  _draw_tasks()
  _draw_weapon_zones()
  _draw_trails()
  _draw_gems()
  _draw_pickups()
  _draw_enemies()
  _draw_summons()
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
      var seed: int = absi(grid_x * 92821 + grid_y * 68917)
      if seed % 4 == 0:
        continue
      var phase: float = animation_time * (0.42 + float(seed % 7) * 0.035) + float(seed % 31)
      var position := Vector2(
        grid_x * 180.0 + float(seed % 127) - 63.0 + sin(phase) * 13.0,
        grid_y * 180.0 + float((seed / 17) % 113) - 56.0 + cos(phase * 0.73) * 8.0
      )
      var mote_alpha: float = 0.07 + float(seed % 5) * 0.012
      var mote_color := Color(0.9, 0.84, 0.55, mote_alpha)
      draw_line(position - Vector2(4.0, 1.5), position + Vector2(4.0, 1.5), mote_color, 1.1, true)
      draw_circle(position, 1.3 + float(seed % 3) * 0.35, Color(1.0, 0.94, 0.72, mote_alpha * 0.72))


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
    'guard': _draw_marker(_point(payload['center']), payload['radius'], Color('66bb6a'), texture)
    'delivery': _draw_marker(_point(payload['destination']), Config.CONFIG['tasks']['delivery']['destinationRadius'], Color('42a5f5'), texture)


func _draw_marker(position: Vector2, radius: float, color: Color, texture: Texture2D) -> void:
  var pulse: float = 0.5 + sin(animation_time * 3.0) * 0.5
  draw_circle(position, radius, Color(color, 0.06 + pulse * 0.025))
  draw_arc(position, radius + pulse * 3.0, 0.0, TAU, 64, Color(color, 0.75), 2.5)
  draw_arc(position, radius * 0.72, 0.0, TAU, 48, Color(color, 0.28), 1.0)
  _draw_sprite(ArtCatalog.VFX_TEXTURES['taskBeacon'], position - Vector2(0.0, 24.0), minf(radius * 1.15, 104.0), 0.0, false, Color(1.0, 1.0, 1.0, 0.56 + pulse * 0.24))
  _draw_sprite(texture, position - Vector2(0.0, radius + 20.0), 42.0 + pulse * 3.0)


func _draw_weapon_zones() -> void:
  for weapon in run.weapons:
    var id: String = weapon.card['id']
    if id == 'cloak':
      var radius: float = weapon.stats['radius']
      draw_circle(Vector2(run.player.x, run.player.y), radius, Color(1.0, 0.22, 0.08, 0.025))
      draw_arc(Vector2(run.player.x, run.player.y), radius, 0.0, TAU, 64, Color(1.0, 0.36, 0.16, 0.28), 1.5)
      for shock: Dictionary in weapon.shocks:
        var progress: float = clampf(shock['t'] / shock['ttl'], 0.0, 1.0)
        _draw_sprite(ArtCatalog.VFX_TEXTURES['cloakFireBurst'], Vector2(shock['x'], shock['y']), shock['max_r'] * progress * 2.1, 0.0, false, Color(1.0, 1.0, 1.0, 1.0 - progress))
    elif id == 'ring':
      var stats: Dictionary = weapon.stats
      var orbit_radius: float = stats['orbitRadius'] + weapon.expand_factor * stats.get('expandRadius', 0.0)
      for i in stats['count']:
        var angle: float = weapon.angle + i * TAU / stats['count']
        var position := Vector2(run.player.x + cos(angle) * orbit_radius, run.player.y + sin(angle) * orbit_radius)
        _draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['ring'], position, 76.0, angle)
    elif id == 'trail':
      for zone: Dictionary in weapon.furnaces:
        _draw_zone(zone, Color(1.0, 0.2, 0.04, 0.1), Color('ff7043'))
        _draw_sprite(ArtCatalog.VFX_TEXTURES['furnaceFlame'], _point(zone['center']), 78.0, 0.0, false, Color(1.0, 1.0, 1.0, _zone_alpha(zone)))
      for zone: Dictionary in weapon.hot_zones:
        _draw_zone(zone, Color(1.0, 0.65, 0.12, 0.1), Color('ffca28'))
      for zone: Dictionary in weapon.cut_zones:
        var alpha: float = clampf(zone['life'] / zone['maxLife'], 0.0, 1.0)
        draw_line(Vector2(zone['x1'], zone['y1']), Vector2(zone['x2'], zone['y2']), Color(1.0, 0.35, 0.08, alpha), zone['width'])


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


func _zone_alpha(zone: Dictionary) -> float:
  return clampf(zone.get('life', 1.0) / maxf(zone.get('maxLife', 1.0), 0.001), 0.0, 1.0)


func _draw_trails() -> void:
  for trail: Dictionary in run.trails:
    if trail['dead']:
      continue
    var alpha: float = clampf(trail['life'] / trail['maxLife'], 0.0, 1.0)
    var position := Vector2(trail['x'], trail['y'])
    _draw_sprite(ArtCatalog.VFX_TEXTURES['furnaceFlame'], position, trail['radius'] * 2.1, 0.0, false, Color(1.0, 1.0, 1.0, alpha * 0.55))


func _draw_gems() -> void:
  for gem: Dictionary in run.gems:
    if gem['dead']:
      continue
    var position := Vector2(gem['x'], gem['y'])
    var bob := Vector2(0.0, sin(animation_time * 4.0 + gem['x'] * 0.01) * 2.0)
    var gem_color := Color(gem['color'])
    var display_position: Vector2 = position + bob
    if gem['magnetized']:
      _draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], position, 34.0, animation_time, false, Color(0.75, 1.0, 1.0, 0.65))
    draw_circle(display_position, 13.0, Color(gem_color, 0.16))
    _draw_ellipse_shape(display_position + Vector2(0.0, 7.0), Vector2(7.5, 3.0), Color(0.0, 0.0, 0.0, 0.16))
    _draw_sprite(ArtCatalog.PICKUP_TEXTURES['gem'], display_position, 27.0)


func _draw_pickups() -> void:
  for pickup: Dictionary in run.pickups:
    if pickup.get('dead', false):
      continue
    var position := Vector2(pickup['x'], pickup['y'])
    var bob := Vector2(0.0, sin(animation_time * 3.4 + pickup['x'] * 0.015) * 2.5)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], position, 40.0, -animation_time * 0.5, false, Color(1.0, 1.0, 1.0, 0.42))
    if pickup.get('kind') == 'rare':
      var texture: Texture2D = ArtCatalog.RARE_TEXTURES.get(pickup.get('itemId', ''), ArtCatalog.RARE_TEXTURES['warRune'])
      _draw_sprite(texture, position + bob, 31.0)
    else:
      _draw_sprite(ArtCatalog.PICKUP_TEXTURES['health'], position + bob, 29.0)


func _draw_enemies() -> void:
  for enemy in run.enemies:
    if enemy.dead:
      continue
    _draw_enemy(enemy)


# Returns an AtlasTexture for the current animation frame from a sprite sheet
func _get_animated_frame(sheet: Texture2D, _enemy_key: String) -> AtlasTexture:
  var atlas := AtlasTexture.new()
  atlas.atlas = sheet
  var cols: int = ArtCatalog.ENEMY_SHEET_COLS
  var rows: int = ArtCatalog.ENEMY_SHEET_ROWS
  var total_frames: int = cols * rows
  var frame_index: int = int(animation_time * ArtCatalog.ENEMY_SHEET_FPS) % total_frames
  var col: int = frame_index % cols
  var row: int = frame_index / cols
  var frame_w: float = sheet.get_width() / float(cols)
  var frame_h: float = sheet.get_height() / float(rows)
  atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
  return atlas


func _draw_enemy(enemy) -> void:
  var position := Vector2(enemy.x, enemy.y)
  var radius: float = maxf(enemy.radius, 10.0)
  var enemy_type_key: String = enemy.type if enemy.type != 'enhanced_chaser' else 'enhancedChaser'
  # Boss: use idle sheet during windup/attack, walk sheet otherwise
  if enemy_type_key == 'boss':
    if enemy.has('state') and enemy.state == 'windup':
      enemy_type_key = 'bossIdle'
  var sheet_texture: Texture2D = ArtCatalog.ENEMY_SPRITE_SHEETS.get(enemy_type_key)
  var texture: Texture2D
  if sheet_texture != null:
    texture = _get_animated_frame(sheet_texture, enemy_type_key)
  else:
    texture = ArtCatalog.ENEMY_TEXTURES.get(enemy.type, ArtCatalog.ENEMY_TEXTURES['chaser'])
  var is_boss: bool = enemy.type == 'boss'
  var display_size: float = radius * (6.6 if is_boss else 6.2)
  if enemy.type == 'charger':
    display_size *= 1.12
  elif enemy.type == 'shield':
    display_size *= 1.08
  var bob: float = sin(animation_time * (2.2 if is_boss else 4.2) + enemy.x * 0.008) * (1.2 if is_boss else 2.0)
  var pulse: float = 0.5 + sin(animation_time * (2.4 if is_boss else 3.6) + enemy.y * 0.006) * 0.5
  _draw_ellipse_shape(position + Vector2(0.0, radius * 0.72), Vector2(radius * 1.22, radius * 0.5), Color(0.03, 0.025, 0.035, 0.38))
  if is_boss:
    draw_circle(position, radius * (1.55 + pulse * 0.12), Color(0.34, 0.12, 0.42, 0.08 + pulse * 0.04))
    draw_arc(position, radius * (1.6 + pulse * 0.08), 0.0, TAU, 48, Color(0.76, 0.42, 0.95, 0.22 + pulse * 0.16), 2.0)
  elif enemy.rank == 'elite':
    draw_circle(position, radius * 1.35, Color(1.0, 0.72, 0.18, 0.07 + pulse * 0.03))
  if is_boss and enemy.enraged:
    _draw_sprite(ArtCatalog.VFX_TEXTURES['bossEnraged'], position, display_size * (1.45 + pulse * 0.08), animation_time * 0.15, false, Color(1.0, 1.0, 1.0, 0.72))
  var hit_ratio: float = clampf(enemy.hitFlash / 0.14, 0.0, 1.0)
  var modulate := Color.WHITE
  if enemy.frozenTimer > 0.0:
    modulate = Color(0.65, 0.9, 1.0, 0.94)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['freeze'], position, display_size * 0.85, 0.0, false, Color(1.0, 1.0, 1.0, 0.46))
  elif hit_ratio > 0.0:
    modulate = Color(1.35, 1.2, 0.95, 1.0)
    display_size *= 1.0 + hit_ratio * 0.08
  # Shield enemy: shield side faces the player
  var flip_h: bool = run.player.x < enemy.x
  _draw_sprite(texture, position + Vector2(0.0, bob - display_size * 0.31), display_size, 0.0, flip_h, modulate)
  if hit_ratio > 0.0:
    draw_arc(position, radius * (1.0 + (1.0 - hit_ratio) * 0.6), 0.0, TAU, 24, Color(1.0, 0.9, 0.55, hit_ratio * 0.78), 2.5)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], position - Vector2(0.0, radius * 0.25), display_size * (0.42 + (1.0 - hit_ratio) * 0.18), animation_time * 0.6, false, Color(1.0, 1.0, 1.0, hit_ratio * 0.88))
  if enemy.rank == 'elite':
    draw_arc(position, radius + 7.0 + pulse * 2.0, 0.0, TAU, 32, Color(1.0, 0.84, 0.31, 0.72 + pulse * 0.22), 2.5)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], position, radius * (3.4 + pulse * 0.18), animation_time * 0.3, false, Color(1.0, 0.86, 0.38, 0.24 + pulse * 0.1))
  if enemy.slowTimer > 0.0:
    draw_arc(position, radius + 9.0, 0.0, TAU, 24, Color('80cbc4'), 2.0)
  if enemy.type == 'charger' and enemy.get('state', '') == 'windup':
    _draw_charge_indicator(position, radius, enemy)
  if not enemy.dots.is_empty():
    _draw_enemy_dots(position, radius, enemy.dots, pulse)
  if enemy.taskRole != null:
    _draw_sprite(ArtCatalog.TASK_TEXTURES['bounty'], position - Vector2(0.0, radius + 24.0), 30.0 + pulse * 2.0)
  if enemy.hp < enemy.maxHp or enemy.rank == 'elite' or enemy.rank == 'boss':
    _draw_health_bar(position, radius, enemy.hp, enemy.maxHp, is_boss)


func _draw_health_bar(position: Vector2, radius: float, hp: float, max_hp: float, is_boss: bool) -> void:
  var width: float = maxf(34.0, radius * (2.6 if is_boss else 2.2))
  var ratio: float = clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
  var top_left := position + Vector2(-width * 0.5, -radius - (18.0 if is_boss else 11.0))
  draw_rect(Rect2(top_left, Vector2(width, 5.0)), Color(0.025, 0.02, 0.03, 0.84))
  draw_rect(Rect2(top_left + Vector2.ONE, Vector2((width - 2.0) * ratio, 3.0)), Color('66bb6a') if ratio > 0.35 else Color('ef5350'))


func _draw_summons() -> void:
  for summon: Dictionary in run.summons:
    if summon.get('dead', false):
      continue
    var position := Vector2(summon['x'], summon['y'])
    var radius: float = summon.get('radius', 11.0)
    var is_corpse: bool = summon.get('corpse', false)
    var texture: Texture2D = ArtCatalog.SUMMON_TEXTURES['corpse'] if is_corpse else ArtCatalog.SUMMON_TEXTURES['normal']
    _draw_ellipse_shape(position + Vector2(0.0, radius * 0.7), Vector2(radius, radius * 0.38), Color(0.03, 0.025, 0.035, 0.28))
    if is_corpse:
      _draw_sprite(texture, position - Vector2(0.0, radius * 0.18), radius * 4.3)
    else:
      _draw_sprite(texture, position - Vector2(0.0, radius * 1.05), radius * 4.1, 0.0, run.player.x < summon['x'])
    if summon.get('guardianWardActive', false):
      _draw_sprite(ArtCatalog.SUMMON_TEXTURES['ward'], position + Vector2(radius * 1.35, -radius * 0.35), radius * 3.4, -0.08, false, Color(1.0, 1.0, 1.0, 0.82))
    if summon.get('ghostfireActive', false):
      _draw_sprite(ArtCatalog.SUMMON_TEXTURES['wisp'], position + Vector2(-radius * 1.25, -radius * 1.85), radius * 3.0, sin(animation_time * 2.4) * 0.08)


func _draw_player_projectiles() -> void:
  for projectile in run.projectiles:
    if projectile.dead:
      continue
    var position := Vector2(projectile.x, projectile.y)
    var source: String = projectile.damageOptions.get('sourceWeaponId', 'sword')
    var texture: Texture2D = ArtCatalog.PROJECTILE_TEXTURES.get(source, ArtCatalog.PROJECTILE_TEXTURES['sword'])
    var color: Color = Color(projectile.color) if not projectile.color.is_empty() else WEAPON_COLORS.get(source, Color.WHITE)
    var velocity := Vector2(projectile.vx, projectile.vy)
    var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT.rotated(projectile.angle)
    var angle: float = direction.angle()
    var size: float = maxf(26.0, projectile.radius * (6.5 if projectile.swordQi else 4.8))
    var tail_length: float = size * (2.8 if projectile.swordQi else 1.8)
    if source == 'sword' and projectile.swordQi:
      # Enhanced sword qi rendering — layered xianxia blade effect
      # Outer aura glow
      draw_circle(position, size * 1.0, Color(color, 0.10))
      draw_circle(position, size * 0.6, Color(color, 0.18))
      # Long trailing energy tail (dual color)
      draw_line(position - direction * tail_length * 1.3, position - direction * tail_length * 0.3, Color(color, 0.15), maxf(2.0, projectile.radius * 1.2), true)
      draw_line(position - direction * tail_length, position, Color(color, 0.35), maxf(4.0, projectile.radius * 2.8), true)
      draw_line(position - direction * tail_length * 0.7, position, Color(1.0, 1.0, 1.0, 0.5), maxf(2.0, projectile.radius * 1.0), true)
      # Side wisps (仙气)
      var perp := direction.rotated(PI * 0.5)
      for wisp_i in 3:
        var wisp_t: float = 0.3 + float(wisp_i) * 0.25
        var wisp_pos := position - direction * tail_length * wisp_t
        var wisp_offset := perp * sin(animation_time * 12.0 + float(wisp_i) * 2.0) * size * 0.25
        draw_circle(wisp_pos + wisp_offset, 2.0 + float(wisp_i), Color(color, 0.25 - float(wisp_i) * 0.06))
      # Sword qi sprite (improved texture)
      _draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['swordQi'], position, size * 1.4, angle, false, color)
      # Inner bright core
      draw_circle(position, size * 0.22, Color(1.0, 1.0, 1.0, 0.7))
    else:
      # Standard projectile rendering
      draw_circle(position, size * 0.8, Color(color, 0.12))
      draw_line(position - direction * tail_length, position, Color(color, 0.28), maxf(3.0, projectile.radius * 2.4), true)
      draw_line(position - direction * tail_length * 0.62, position, Color(1.0, 1.0, 1.0, 0.45), maxf(1.5, projectile.radius * 0.9), true)
      if source == 'ring':
        _draw_sprite(ArtCatalog.VFX_TEXTURES['jadeRingTrail'], position - direction * size * 0.45, size * 1.6, angle, false, Color(1.0, 1.0, 1.0, 0.55))
      elif source == 'staff':
        _draw_sprite(ArtCatalog.VFX_TEXTURES['staffSpiritBolt'], position - direction * size * 0.28, size * 1.7, angle, false, Color(1.0, 1.0, 1.0, 0.5))
      _draw_sprite(texture, position, size, angle, false, color)


func _draw_hostile_projectiles() -> void:
  for projectile in run.hostileProjectiles:
    if projectile.dead:
      continue
    var position := Vector2(projectile.x, projectile.y)
    var velocity := Vector2(projectile.vx, projectile.vy)
    var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.0 else Vector2.RIGHT
    var angle: float = direction.angle()
    var size: float = maxf(26.0, projectile.radius * 5.2)
    # Outer glow (dark energy halo)
    draw_circle(position, size * 0.85, Color(0.6, 0.08, 0.05, 0.18))
    # Trailing energy (darker, thicker)
    draw_line(position - direction * size * 1.6, position, Color(0.5, 0.05, 0.02, 0.22), maxf(3.0, projectile.radius * 2.0), true)
    draw_line(position - direction * size * 1.0, position, Color(1.0, 0.35, 0.12, 0.3), maxf(2.0, projectile.radius * 1.2), true)
    # Core energy lines
    draw_line(position - direction * size * 0.5, position, Color(1.0, 0.65, 0.3, 0.45), maxf(1.5, projectile.radius * 0.6), true)
    # Projectile sprite (improved texture)
    _draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['hostile'], position, size, angle)
    # Inner bright core
    draw_circle(position, projectile.radius * 0.7, Color(1.0, 0.85, 0.5, 0.3))


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
    var position := Vector2(fx['x'], fx['y'])
    var alpha: float = clampf(fx['ttl'] / 0.22, 0.0, 1.0)
    var is_aoe: bool = fx.get('aoe', false)
    var is_sword: bool = fx.get('swordSynergy', false)
    # Ground impact glow
    var impact_r: float = 45.0 if is_aoe else 28.0
    draw_circle(position, impact_r * (1.0 + (1.0 - alpha) * 0.5), Color(0.5, 0.7, 1.0, alpha * 0.2))
    draw_circle(position, impact_r * 0.5, Color(0.8, 0.9, 1.0, alpha * 0.35))
    # Lightning bolt from above
    var bolt_top := position + Vector2(0.0, -180.0)
    var bolt_color := Color(0.6, 0.8, 1.0, alpha * 0.7) if not is_sword else Color(0.9, 0.7, 1.0, alpha * 0.7)
    var core_color := Color(1.0, 1.0, 1.0, alpha * 0.9)
    # Jagged lightning path
    var segments := PackedVector2Array()
    var current_pos := bolt_top
    segments.append(current_pos)
    var step_count: int = 6
    var seg_h: float = 180.0 / float(step_count)
    for seg_i in step_count:
      var jitter_x: float = sin(float(seg_i) * 7.3 + animation_time * 30.0) * 14.0
      current_pos = Vector2(position.x + jitter_x, bolt_top.y + float(seg_i + 1) * seg_h)
      segments.append(current_pos)
    # Draw outer glow line
    for seg_i in range(segments.size() - 1):
      draw_line(segments[seg_i], segments[seg_i + 1], bolt_color, 5.0, true)
    # Draw core line (thinner, brighter)
    for seg_i in range(segments.size() - 1):
      draw_line(segments[seg_i], segments[seg_i + 1], core_color, 2.0, true)
    # Branch lightning
    for branch_i in 3:
      var branch_start_idx: int = 1 + branch_i * 2
      if branch_start_idx >= segments.size():
        continue
      var branch_start := segments[branch_start_idx]
      var branch_angle: float = float(branch_i) * 1.2 - 1.2 + sin(animation_time * 20.0) * 0.3
      var branch_end := branch_start + Vector2(cos(branch_angle), sin(branch_angle) * 0.5 + 0.5).normalized() * 25.0
      draw_line(branch_start, branch_end, Color(0.6, 0.8, 1.0, alpha * 0.4), 1.5, true)
    # Impact texture
    _draw_sprite(ArtCatalog.VFX_TEXTURES.get('thunderStrike', ArtCatalog.VFX_TEXTURES['talismanLightning']), position, 70.0 + (1.0 - alpha) * 20.0, 0.0, false, Color(1.0, 1.0, 1.0, alpha * 0.85))
    if is_aoe:
      draw_arc(position, 95.0 * (1.0 + (1.0 - alpha) * 0.3), 0.0, TAU, 32, Color(0.5, 0.7, 1.0, alpha * 0.4), 2.5)
  # Draw chain lightning arcs
  for fx: Dictionary in talisman.chain_fx:
    var start := Vector2(fx['x1'], fx['y1'])
    var finish := Vector2(fx['x2'], fx['y2'])
    var alpha: float = clampf(fx['ttl'] / 0.15, 0.0, 1.0)
    var is_relay: bool = fx.get('relay', false)
    var chain_color := Color(0.4, 0.7, 1.0, alpha * 0.6) if not is_relay else Color(0.6, 0.4, 1.0, alpha * 0.5)
    # Jagged chain path
    var diff := finish - start
    var seg_count: int = 5
    var prev := start
    for seg_i in range(1, seg_count + 1):
      var t: float = float(seg_i) / float(seg_count)
      var point := start + diff * t
      if seg_i < seg_count:
        var perp := Vector2(-diff.y, diff.x).normalized()
        var jitter: float = sin(float(seg_i) * 11.0 + animation_time * 25.0) * 12.0
        point += perp * jitter
      draw_line(prev, point, chain_color, 2.5, true)
      draw_line(prev, point, Color(1.0, 1.0, 1.0, alpha * 0.5), 1.0, true)
      prev = point
    # Small spark at endpoints
    draw_circle(finish, 4.0, Color(0.7, 0.85, 1.0, alpha * 0.5))


func _draw_effects() -> void:
  for effect: Dictionary in run.effects:
    var ttl: float = effect.get('ttl', 0.0)
    var max_ttl: float = maxf(effect.get('maxTtl', ttl), 0.0001)
    var alpha: float = clampf(ttl / max_ttl, 0.0, 1.0)
    match effect.get('type', ''):
      'synergyArc':
        var start := Vector2(effect['x1'], effect['y1'])
        var finish := Vector2(effect['x2'], effect['y2'])
        var midpoint := (start + finish) * 0.5
        _draw_sprite(ArtCatalog.VFX_TEXTURES['synergyArc'], midpoint, maxf(42.0, start.distance_to(finish) * 1.1), (finish - start).angle(), false, Color(1.0, 1.0, 1.0, alpha))
        draw_line(start, finish, Color(effect.get('color', '80deea'), alpha * 0.8), 2.0)
      'synergyFlameBlade':
        var start := Vector2(effect['x1'], effect['y1'])
        var finish := Vector2(effect['x2'], effect['y2'])
        _draw_sprite(ArtCatalog.VFX_TEXTURES['swordSlash'], (start + finish) * 0.5, start.distance_to(finish) * 1.2, (finish - start).angle(), false, Color(1.0, 0.55, 0.35, alpha))
      'synergyCommandMark':
        _draw_sprite(ArtCatalog.UI_TEXTURES['sealWeapon'], Vector2(effect['x'], effect['y'] - 28.0), 30.0, 0.0, false, Color(0.9, 0.65, 1.0, alpha))
      'weaponImpact':
        _draw_weapon_impact(effect, alpha)
      'enemyDefeat':
        _draw_enemy_defeat(effect, alpha)
      'slash':
        var slash_position := Vector2(effect['x'], effect['y'])
        var slash_range: float = effect.get('range', 50.0)
        var slash_angle: float = effect.get('angle', 0.0)
        # Draw outer glow for the slash
        draw_circle(slash_position, slash_range * 0.6, Color(0.77, 0.95, 1.0, alpha * 0.15))
        _draw_sprite(ArtCatalog.VFX_TEXTURES['swordSlash'], slash_position, slash_range * 2.6, slash_angle, false, Color(1.0, 1.0, 1.0, alpha))
        _draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], slash_position, slash_range * 1.2, slash_angle, false, Color(0.77, 0.95, 1.0, alpha * 0.5))
      'enemyBlast':
        _draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], Vector2(effect['x'], effect['y']), effect.get('radius', 40.0) * 2.25, 0.0, false, Color(1.0, 1.0, 1.0, alpha))
      'synergyBurst':
        var texture: Texture2D = ArtCatalog.VFX_TEXTURES['talismanLightning'] if effect.get('style') == 'lightningFire' else ArtCatalog.VFX_TEXTURES['synergyArc']
        _draw_sprite(texture, Vector2(effect['x'], effect['y']), effect.get('radius', 34.0) * 2.3, animation_time * 0.15, false, Color(1.0, 1.0, 1.0, alpha))
      _:
        if effect.has('x') and effect.has('y') and effect.has('radius'):
          _draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], Vector2(effect['x'], effect['y']), effect['radius'] * 2.0, 0.0, false, Color(effect.get('color', 'ff8a50'), alpha))


func _draw_weapon_impact(effect: Dictionary, alpha: float) -> void:
  var position := Vector2(effect['x'], effect['y'])
  var source: String = effect.get('sourceWeaponId', 'sword')
  var color: Color = WEAPON_COLORS.get(source, Color.WHITE)
  var progress: float = 1.0 - alpha
  var radius: float = maxf(effect.get('radius', 12.0), 10.0)
  var intensity: float = clampf(effect.get('damage', 1.0) / 80.0, 0.35, 1.0)
  var action: String = effect.get('sourceAction', 'hit')
  # Brighter, larger glow circle — all impacts are more visible now
  draw_circle(position, radius * (1.4 + progress * 2.0), Color(color, alpha * 0.32 * intensity))
  draw_circle(position, radius * (0.8 + progress * 1.2), Color(1.0, 1.0, 1.0, alpha * 0.18))
  draw_arc(position, radius * (1.0 + progress * 2.2), 0.0, TAU, 32, Color(color, alpha * (0.9 + intensity * 0.1)), 3.5 + intensity * 2.0)
  var texture_key: String = IMPACT_TEXTURE_KEYS.get(source, 'impact')
  var impact_size: float = radius * (8.0 + intensity * 4.5) * (0.9 + progress * 0.5)
  var rotation: float = effect.get('angle', 0.0)
  if source == 'sword':
    impact_size *= 1.6
  elif source == 'talisman':
    rotation += sin(float(effect.get('seed', 0))) * 0.3
  elif source == 'cloak' or source == 'trail':
    impact_size *= 1.5
    rotation = animation_time * 0.8
  elif source == 'ring':
    rotation = animation_time * 1.4
  elif source == 'staff':
    rotation += PI * 0.5
  _draw_sprite(ArtCatalog.VFX_TEXTURES[texture_key], position, impact_size, rotation, false, Color(1.0, 1.0, 1.0, alpha))
  _draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], position, radius * (4.0 + progress * 2.0), rotation * 0.25, false, Color(color, alpha * 0.95))
  _draw_impact_sparks(position, radius * 1.2, color, alpha, int(effect.get('seed', 0)), action)
  _draw_damage_number(effect, position, radius, color, alpha, progress, intensity)


func _draw_damage_number(effect: Dictionary, position: Vector2, radius: float, color: Color, alpha: float, progress: float, intensity: float) -> void:
  var damage: int = maxi(1, roundi(effect.get('damage', 1.0)))
  var text: String = str(damage)
  var text_position := position + Vector2(-34.0, -radius * 1.15 - progress * 26.0)
  var font_size: int = 18 + roundi(intensity * 8.0)
  var shadow := Color(0.22, 0.09, 0.045, alpha * 0.94)
  for offset: Vector2 in [Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0)]:
    draw_string(UI_FONT, text_position + offset, text, HORIZONTAL_ALIGNMENT_CENTER, 68.0, font_size, shadow)
  draw_string(UI_FONT, text_position, text, HORIZONTAL_ALIGNMENT_CENTER, 68.0, font_size, Color(1.0, 0.92, 0.62, alpha))
  if intensity >= 0.82:
    var tag_position := text_position + Vector2(48.0, 8.0)
    draw_circle(tag_position + Vector2(11.0, -7.0), 13.0, Color(0.48, 0.12, 0.08, alpha * 0.94))
    draw_string(UI_FONT, tag_position, '?!', HORIZONTAL_ALIGNMENT_CENTER, 22.0, 11, Color(1.0, 0.92, 0.68, alpha))


func _draw_enemy_dots(position: Vector2, radius: float, dots: Dictionary, pulse: float) -> void:
  var dot_y: float = position.y - radius - 14.0
  var dot_position := Vector2(position.x, dot_y)
  var has_burn: bool = dots.has('burn') and dots['burn'].get('timer', 0.0) > 0.0
  var has_poison: bool = dots.has('poison') and dots['poison'].get('timer', 0.0) > 0.0
  var flicker: float = sin(animation_time * 8.0) * 0.5 + 0.5
  if has_burn:
    var burn_size: float = 30.0 + pulse * 4.0 + flicker * 3.0
    draw_circle(dot_position, burn_size * 0.7, Color(1.0, 0.3, 0.05, 0.15 + flicker * 0.08))
    var frame_offset: float = sin(animation_time * 12.0) * 2.0
    draw_circle(dot_position + Vector2(0.0, frame_offset), burn_size * 0.45, Color(1.0, 0.55, 0.1, 0.5))
    draw_circle(dot_position + Vector2(0.0, frame_offset - 1.5), burn_size * 0.3, Color(1.0, 0.85, 0.3, 0.65))
    draw_circle(dot_position + Vector2(0.0, frame_offset - 3.0), burn_size * 0.15, Color(1.0, 1.0, 0.8, 0.8))
    _draw_sprite(ArtCatalog.VFX_TEXTURES.get('burnDot', ArtCatalog.VFX_TEXTURES['impact']), dot_position + Vector2(0.0, frame_offset), burn_size * 1.3, animation_time * 0.4, false, Color(1.0, 0.9, 0.7, 0.7 + flicker * 0.2))
  if has_poison:
    var poison_position := dot_position + Vector2(16.0 if has_burn else 0.0, 0.0)
    var poison_size: float = 22.0 + pulse * 2.0
    draw_circle(poison_position, poison_size * 0.5, Color(0.4, 1.0, 0.3, 0.18 + flicker * 0.06))
    _draw_sprite(ArtCatalog.VFX_TEXTURES['poison'], poison_position, poison_size, animation_time * 0.25, false, Color(0.7, 1.0, 0.6, 0.65 + flicker * 0.15))
  if not has_burn and not has_poison:
    _draw_sprite(ArtCatalog.VFX_TEXTURES['dot'], dot_position, 24.0 + pulse * 2.0, 0.0, false, Color(1.0, 1.0, 1.0, 0.7))


func _draw_charge_indicator(position: Vector2, radius: float, enemy) -> void:
  var dir_x: float = enemy.lockedDirection.get('x', 1.0)
  var dir_y: float = enemy.lockedDirection.get('y', 0.0)
  var dir := Vector2(dir_x, dir_y).normalized()
  var angle: float = dir.angle()
  var charge_length: float = radius * 3.5
  var windup_total: float = maxf(0.001, Config.CONFIG['enemyTypes']['charger'].get('windup', 0.8))
  var windup_progress: float = clampf(1.0 - enemy.stateTimer / windup_total, 0.0, 1.0)
  var pulse: float = sin(animation_time * 14.0) * 0.5 + 0.5
  draw_arc(position, radius * 1.6 + pulse * 4.0, 0.0, TAU, 32, Color(1.0, 0.35, 0.15, 0.25 + windup_progress * 0.35), 2.5)
  var tip := position + dir * charge_length
  var base_left := position + dir * radius * 0.8 + dir.rotated(PI * 0.5) * radius * 0.6
  var base_right := position + dir * radius * 0.8 - dir.rotated(PI * 0.5) * radius * 0.6
  var alpha: float = 0.4 + windup_progress * 0.5
  draw_line(position + dir * radius * 0.5, tip, Color(1.0, 0.45, 0.15, alpha), 3.0 + windup_progress * 2.0, true)
  draw_line(tip, base_left, Color(1.0, 0.55, 0.2, alpha * 0.9), 2.5, true)
  draw_line(tip, base_right, Color(1.0, 0.55, 0.2, alpha * 0.9), 2.5, true)
  draw_circle(tip, 5.0 + pulse * 3.0, Color(1.0, 0.7, 0.2, alpha * 0.6))
  _draw_sprite(ArtCatalog.VFX_TEXTURES.get('chargeIndicator', ArtCatalog.VFX_TEXTURES['impact']), tip, 36.0 + windup_progress * 16.0, angle, false, Color(1.0, 0.8, 0.4, alpha * 0.8))


func _draw_enemy_defeat(effect: Dictionary, alpha: float) -> void:
  var position := Vector2(effect['x'], effect['y'])
  var progress: float = 1.0 - alpha
  var radius: float = maxf(effect.get('radius', 12.0), 10.0)
  var source: String = effect.get('sourceWeaponId', 'status')
  var color: Color = WEAPON_COLORS.get(source, WEAPON_COLORS['status'])
  var is_boss: bool = effect.get('rank', '') == 'boss'
  var texture: Texture2D = ArtCatalog.ENEMY_TEXTURES.get(effect.get('enemyType', 'chaser'), ArtCatalog.ENEMY_TEXTURES['chaser'])
  var ghost_size: float = radius * (6.6 if is_boss else 6.2) * (1.0 + progress * 0.18)
  _draw_sprite(texture, position - Vector2(0.0, radius * 1.5 + progress * 18.0), ghost_size, progress * 0.08, effect.get('flipH', false), Color(1.0, 0.72 + progress * 0.2, 0.55 + progress * 0.25, alpha * 0.62))
  draw_circle(position, radius * (0.8 + progress * 2.8), Color(color, alpha * 0.13))
  draw_arc(position, radius * (0.65 + progress * 3.2), 0.0, TAU, 36, Color(color, alpha * 0.82), 3.2 if is_boss else 2.1)
  _draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], position, radius * (4.2 if is_boss else 3.2) * (0.8 + progress * 0.55), animation_time * 0.5, false, Color(1.0, 1.0, 1.0, alpha * 0.86))
  _draw_impact_sparks(position, radius * (1.55 if is_boss else 1.0), color, alpha, int(effect.get('seed', 0)) + 17, 'defeat')


func _draw_impact_sparks(position: Vector2, radius: float, color: Color, alpha: float, seed: int, action: String) -> void:
  var spark_count: int = 9 if action == 'defeat' else 6
  for i in spark_count:
    var angle: float = float(i) * TAU / float(spark_count) + float(seed % 23) * 0.17
    var length: float = radius * (0.7 + float((seed + i * 7) % 5) * 0.16)
    var inner := position + Vector2.RIGHT.rotated(angle) * radius * 0.42
    var outer := position + Vector2.RIGHT.rotated(angle) * length * (1.0 + (1.0 - alpha) * 0.8)
    draw_line(inner, outer, Color(color, alpha * 0.78), 1.6, true)
    draw_circle(outer, 1.3 + float(i % 2), Color(1.0, 0.96, 0.78, alpha * 0.75))


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
  draw_set_transform(center, 0.0, radii)
  draw_circle(Vector2.ZERO, 1.0, color)
  draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sprite(texture: Texture2D, center: Vector2, display_size: float, rotation: float = 0.0, flip_h: bool = false, modulate: Color = Color.WHITE) -> void:
  if texture == null or display_size <= 0.0:
    return
  var texture_size: Vector2 = texture.get_size()
  var factor: float = display_size / maxf(texture_size.x, texture_size.y)
  var scale := Vector2(-factor if flip_h else factor, factor)
  draw_set_transform(center, rotation, scale)
  draw_texture(texture, -texture_size * 0.5, modulate)
  draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _point(value: Dictionary) -> Vector2:
  return Vector2(value['x'], value['y'])
