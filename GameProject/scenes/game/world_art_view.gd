extends Node2D

const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const WEAPON_COLORS: Dictionary = {
  'sword': Color('c5f3ff'),
  'talisman': Color('ffe066'),
  'cloak': Color('ff7043'),
  'trail': Color('ff5722'),
  'ring': Color('b7e778'),
  'staff': Color('b388ff'),
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
  _draw_tasks()
  _draw_weapon_zones()
  _draw_trails()
  _draw_gems()
  _draw_pickups()
  _draw_enemies()
  _draw_summons()
  _draw_player_projectiles()
  _draw_hostile_projectiles()
  _draw_effects()


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
        _draw_sprite(ArtCatalog.WEAPON_ICONS['ring'], position, 32.0, angle)
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
    if gem['magnetized']:
      _draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], position, 34.0, animation_time, false, Color(0.75, 1.0, 1.0, 0.65))
    _draw_sprite(ArtCatalog.PICKUP_TEXTURES['gem'], position + bob, 22.0, 0.0, false, Color(gem['color']))


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


func _draw_enemy(enemy) -> void:
  var position := Vector2(enemy.x, enemy.y)
  var radius: float = maxf(enemy.radius, 10.0)
  var texture: Texture2D = ArtCatalog.ENEMY_TEXTURES.get(enemy.type, ArtCatalog.ENEMY_TEXTURES['chaser'])
  var is_boss: bool = enemy.type == 'boss'
  var display_size: float = radius * (5.2 if is_boss else 4.7)
  if enemy.type == 'charger':
    display_size *= 1.12
  elif enemy.type == 'shield':
    display_size *= 1.08
  var bob: float = sin(animation_time * (2.2 if is_boss else 4.2) + enemy.x * 0.008) * (1.2 if is_boss else 2.0)
  _draw_ellipse_shape(position + Vector2(0.0, radius * 0.72), Vector2(radius * 1.15, radius * 0.48), Color(0.03, 0.025, 0.035, 0.34))
  if is_boss and enemy.enraged:
    _draw_sprite(ArtCatalog.VFX_TEXTURES['bossEnraged'], position, display_size * 1.45, animation_time * 0.15, false, Color(1.0, 1.0, 1.0, 0.72))
  var modulate := Color.WHITE
  if enemy.frozenTimer > 0.0:
    modulate = Color(0.65, 0.9, 1.0, 0.94)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['freeze'], position, display_size * 0.85, 0.0, false, Color(1.0, 1.0, 1.0, 0.46))
  elif enemy.hitFlash > 0.0:
    modulate = Color(1.45, 1.35, 1.15, 1.0)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], position - Vector2(0.0, radius * 0.4), display_size * 0.45, 0.0, false, Color(1.0, 1.0, 1.0, minf(1.0, enemy.hitFlash * 7.0)))
  var flip_h: bool = run.player.x < enemy.x
  _draw_sprite(texture, position + Vector2(0.0, bob - display_size * 0.31), display_size, 0.0, flip_h, modulate)
  if enemy.rank == 'elite':
    draw_arc(position, radius + 7.0, 0.0, TAU, 32, Color('ffd54f'), 2.5)
    _draw_sprite(ArtCatalog.VFX_TEXTURES['pickup'], position, radius * 3.4, animation_time * 0.3, false, Color(1.0, 0.86, 0.38, 0.28))
  if enemy.slowTimer > 0.0:
    draw_arc(position, radius + 9.0, 0.0, TAU, 24, Color('80cbc4'), 2.0)
  if not enemy.dots.is_empty():
    _draw_sprite(ArtCatalog.VFX_TEXTURES['dot'], position - Vector2(0.0, radius + 10.0), 26.0, 0.0, false, Color(1.0, 1.0, 1.0, 0.78))
  if enemy.taskRole != null:
    _draw_sprite(ArtCatalog.TASK_TEXTURES['bounty'], position - Vector2(0.0, radius + 24.0), 30.0)
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
    var texture: Texture2D = ArtCatalog.SUMMON_TEXTURES['corpse'] if summon.get('corpse', false) else ArtCatalog.SUMMON_TEXTURES['normal']
    _draw_ellipse_shape(position + Vector2(0.0, radius * 0.7), Vector2(radius, radius * 0.38), Color(0.03, 0.025, 0.035, 0.28))
    _draw_sprite(texture, position - Vector2(0.0, radius * 1.05), radius * 4.1, 0.0, run.player.x < summon['x'])
    if summon.get('guardianWardActive', false):
      _draw_sprite(ArtCatalog.SUMMON_TEXTURES['ward'], position, radius * 3.6, 0.0, false, Color(1.0, 1.0, 1.0, 0.72))
    if summon.get('ghostfireActive', false):
      _draw_sprite(ArtCatalog.SUMMON_TEXTURES['wisp'], position - Vector2(0.0, radius * 1.8), radius * 2.4, animation_time * 0.2)


func _draw_player_projectiles() -> void:
  for projectile in run.projectiles:
    if projectile.dead:
      continue
    var position := Vector2(projectile.x, projectile.y)
    var source: String = projectile.damageOptions.get('sourceWeaponId', 'sword')
    var texture: Texture2D = ArtCatalog.PROJECTILE_TEXTURES.get(source, ArtCatalog.PROJECTILE_TEXTURES['sword'])
    var color: Color = Color(projectile.color) if not projectile.color.is_empty() else WEAPON_COLORS.get(source, Color.WHITE)
    var velocity := Vector2(projectile.vx, projectile.vy)
    var angle: float = velocity.angle() if velocity.length_squared() > 0.0 else projectile.angle
    var size: float = maxf(18.0, projectile.radius * (4.8 if projectile.swordQi else 3.5))
    _draw_sprite(texture, position, size, angle, false, color)


func _draw_hostile_projectiles() -> void:
  for projectile in run.hostileProjectiles:
    if projectile.dead:
      continue
    var position := Vector2(projectile.x, projectile.y)
    var angle: float = Vector2(projectile.vx, projectile.vy).angle()
    _draw_sprite(ArtCatalog.PROJECTILE_TEXTURES['hostile'], position, maxf(20.0, projectile.radius * 4.0), angle)


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
      'slash':
        _draw_sprite(ArtCatalog.VFX_TEXTURES['swordSlash'], Vector2(effect['x'], effect['y']), effect.get('range', 50.0) * 2.1, effect.get('angle', 0.0), false, Color(1.0, 1.0, 1.0, alpha))
      'enemyBlast':
        _draw_sprite(ArtCatalog.VFX_TEXTURES['explosion'], Vector2(effect['x'], effect['y']), effect.get('radius', 40.0) * 2.25, 0.0, false, Color(1.0, 1.0, 1.0, alpha))
      'synergyBurst':
        var texture: Texture2D = ArtCatalog.VFX_TEXTURES['talismanLightning'] if effect.get('style') == 'lightningFire' else ArtCatalog.VFX_TEXTURES['synergyArc']
        _draw_sprite(texture, Vector2(effect['x'], effect['y']), effect.get('radius', 34.0) * 2.3, animation_time * 0.15, false, Color(1.0, 1.0, 1.0, alpha))
      _:
        if effect.has('x') and effect.has('y') and effect.has('radius'):
          _draw_sprite(ArtCatalog.VFX_TEXTURES['impact'], Vector2(effect['x'], effect['y']), effect['radius'] * 2.0, 0.0, false, Color(effect.get('color', 'ff8a50'), alpha))


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
