extends Node2D

const PlayerSpriteFramesScript: GDScript = preload('res://scenes/game/player_sprite_frames.gd')
# 增大人物缩放，使其在屏幕上可见
const WALK_SCALE: float = 0.8
const IDLE_SCALE: float = 0.75
const FALLBACK_SCALE: float = 0.6
## WALK_SCALE / IDLE_SCALE 是按序列帧图集的默认导入分辨率标定的——注意不是源文件原生的
## 2048x2048，而是 assets/sprites/player/*.png.import 里恒定的 process/size_limit=512
## （桌面/Android 等所有非小游戏导出都走这份默认导入设置）。小游戏导出会在此基础上再按
## tools/minigame_size_limit.gd 的 slim 档（224）进一步压缩，AtlasTexture 的帧区域按压缩后
## 的实际像素动态裁切（正确），但固定的 *_SCALE 倍数不会跟着联动，导致贴图压得越狠角色显示越
## 小。运行时按"参考分辨率（默认导入档 512）/ 实际图集分辨率"算一个补偿系数，抵消掉小游戏导出
## 额外压缩的影响，使人物视觉大小与桌面端默认导入档一致。
const REFERENCE_ATLAS_SIZE: float = 512.0
var _atlas_scale_correction: float = 1.0
const SPRITE_FOOT_OFFSET: float = -22.0
const FALLBACK_FOOT_OFFSET: float = -18.0
const VISIBLE_STATES: Array[String] = ['opening', 'playing', 'choice', 'extraction', 'dead', 'summary']

enum State { IDLE, MOVE, DEAD }
enum Direction { DOWN, DOWN_RIGHT, RIGHT, UP_RIGHT, UP, UP_LEFT, LEFT, DOWN_LEFT }

var state: State = State.IDLE
var direction: Direction = Direction.DOWN
var animation_time: float = 0.0
var simulation_active: bool = false
var facing_angle: float = 0.0
var hurt_flash_timer: float = 0.0
var last_hp: float = -1.0
var _animated_assets_ready: bool = false

@export var show_collision: bool = false
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var fallback_sprite: Sprite2D = $StaticSprite
@onready var shadow: Polygon2D = $Shadow


func _ready() -> void:
  sprite.sprite_frames = PlayerSpriteFramesScript.build()
  _atlas_scale_correction = _compute_atlas_scale_correction(sprite.sprite_frames)
  sprite.position.y = SPRITE_FOOT_OFFSET
  fallback_sprite.position.y = FALLBACK_FOOT_OFFSET
  fallback_sprite.scale = Vector2.ONE * FALLBACK_SCALE
  # 将阴影贴花向下偏移，使其对齐序列帧角色的脚底
  shadow.position.y = 12.0
  _animated_assets_ready = _has_required_animations(sprite.sprite_frames)
  _refresh_visual(true)
  queue_redraw()


func _process(delta: float) -> void:
  if not visible:
    return
  if simulation_active:
    animation_time += delta
    hurt_flash_timer = maxf(0.0, hurt_flash_timer - delta)
  var movement_phase: float = animation_time * (12.0 if state == State.MOVE else 3.0)
  shadow.scale = Vector2(1.0 + sin(movement_phase) * 0.035, 1.0 - sin(movement_phase) * 0.025)
  if fallback_sprite.visible:
    fallback_sprite.position.y = FALLBACK_FOOT_OFFSET + sin(movement_phase) * (3.0 if state == State.MOVE else 1.5)
    fallback_sprite.rotation = sin(movement_phase * 0.5) * (0.025 if state == State.MOVE else 0.012)
  # 只在需要时重绘，减少性能开销
  if state == State.MOVE or hurt_flash_timer > 0.0:
    queue_redraw()


func sync_from(player, game_state: String, screen_position: Vector2) -> void:
  position = screen_position
  visible = game_state in VISIBLE_STATES
  simulation_active = game_state == 'playing'
  if not visible:
    sprite.pause()
    return
  var next_state := State.DEAD if game_state == 'dead' else (State.MOVE if player.moving else State.IDLE)
  if last_hp >= 0.0 and player.hp < last_hp:
    hurt_flash_timer = 0.22
  last_hp = player.hp
  facing_angle = player.facing
  if player.moving:
    direction = direction_from_angle(player.facing)
  _transition(next_state)
  _refresh_visual()
  if simulation_active and state != State.DEAD:
    sprite.speed_scale = 3.0
    if sprite.visible and not sprite.is_playing():
      sprite.play()
  else:
    sprite.pause()
  if state == State.DEAD:
    modulate = Color(0.72, 0.77, 0.82, 1.0)
  elif hurt_flash_timer > 0.0:
    var flash: float = clampf(hurt_flash_timer / 0.22, 0.0, 1.0)
    modulate = Color(1.0, 0.48 + (1.0 - flash) * 0.52, 0.42 + (1.0 - flash) * 0.58, 1.0)
  else:
    modulate = Color.WHITE


static func direction_from_angle(angle: float) -> Direction:
  match wrapi(roundi(angle / (PI / 4.0)), 0, 8):
    0: return Direction.RIGHT
    1: return Direction.DOWN_RIGHT
    2: return Direction.DOWN
    3: return Direction.DOWN_LEFT
    4: return Direction.LEFT
    5: return Direction.UP_LEFT
    6: return Direction.UP
    _: return Direction.UP_RIGHT


static func animation_for_direction(value: Direction) -> StringName:
  match value:
    Direction.DOWN: return &'walk_down'
    Direction.DOWN_RIGHT: return &'walk_down_right'
    Direction.RIGHT, Direction.LEFT: return &'walk_right'
    Direction.UP_RIGHT: return &'walk_up_right'
    Direction.UP: return &'walk_up'
    Direction.UP_LEFT: return &'walk_up_left'
    Direction.DOWN_LEFT: return &'walk_down_left'
  return &'walk_down'


func _transition(next_state: State) -> void:
  if state == next_state:
    return
  state = next_state


func _refresh_visual(force: bool = false) -> void:
  sprite.visible = _animated_assets_ready
  fallback_sprite.visible = not _animated_assets_ready
  if not _animated_assets_ready:
    fallback_sprite.flip_h = direction in [Direction.LEFT, Direction.UP_LEFT, Direction.DOWN_LEFT]
    var back_facing: bool = direction in [Direction.UP, Direction.UP_LEFT, Direction.UP_RIGHT]
    fallback_sprite.modulate = Color(0.88, 0.94, 0.9, 1.0) if back_facing else Color.WHITE
    return
  sprite.flip_h = false
  if state == State.IDLE or state == State.DEAD:
    sprite.scale = Vector2.ONE * IDLE_SCALE * _atlas_scale_correction
    _play_if_changed(&'idle', force)
    return
  sprite.scale = Vector2.ONE * WALK_SCALE * _atlas_scale_correction
  sprite.flip_h = direction == Direction.LEFT
  _play_if_changed(animation_for_direction(direction), force)


## 序列帧图集在小游戏导出中会被压缩到不同分辨率（见上方常量注释）；用当前图集的实际像素尺寸
## 相对参考分辨率算出补偿系数，抵消导入尺寸对显示大小的影响。
func _compute_atlas_scale_correction(frames: SpriteFrames) -> float:
  if frames == null or not frames.has_animation(&'idle') or frames.get_frame_count(&'idle') == 0:
    return 1.0
  var tex: Texture2D = frames.get_frame_texture(&'idle', 0)
  if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
    var atlas: Texture2D = (tex as AtlasTexture).atlas
    var atlas_size: float = maxf(atlas.get_width(), atlas.get_height())
    if atlas_size > 0.0:
      return REFERENCE_ATLAS_SIZE / atlas_size
  return 1.0


func _play_if_changed(animation: StringName, force: bool = false) -> void:
  if not force and sprite.animation == animation:
    return
  sprite.play(animation)


func _has_required_animations(frames: SpriteFrames) -> bool:
  if frames == null:
    return false
  for animation: StringName in [&'idle', &'walk_down', &'walk_down_right', &'walk_right', &'walk_up_right', &'walk_up', &'walk_up_left', &'walk_down_left']:
    if not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
      push_warning('Player animation unavailable: %s; using static fallback.' % animation)
      return false
  return true


func _draw() -> void:
  # 性能优化：减少不必要的绘制调用
  var pulse: float = 0.5 + sin(animation_time * 2.8) * 0.5
  var aura_color := Color(0.37, 0.88, 0.76, 0.045 + pulse * 0.025)
  if state == State.DEAD:
    aura_color = Color(0.4, 0.45, 0.5, 0.035)
  
  # 基础光环绘制（减少精度）
  draw_circle(Vector2.ZERO, 17.0 + pulse * 1.5, aura_color)
  draw_arc(Vector2.ZERO, 15.0 + pulse * 1.0, 0.0, TAU, 24, Color(0.72, 0.96, 0.76, 0.16 + pulse * 0.1), 1.3)
  
  # 移动时的尘土效果（减少绘制次数）
  if state == State.MOVE:
    var backward := -Vector2.RIGHT.rotated(facing_angle)
    for i in 2:  # 从4减少到2，减少绘制调用
      var side := Vector2(-backward.y, backward.x) * (float(i) - 0.5) * 6.0
      var distance: float = 12.0 + float(i) * 8.0 + fmod(animation_time * 24.0, 7.0)
      var dust_position := backward * distance + side + Vector2(0.0, 4.0)
      draw_circle(dust_position, 3.0 - float(i) * 0.3, Color(0.92, 0.83, 0.58, 0.1 - float(i) * 0.02))
      draw_line(dust_position, dust_position + backward * 6.0, Color(0.8, 0.94, 0.77, 0.1), 1.0, true)
  
  # 受击效果（减少精度）
  if hurt_flash_timer > 0.0:
    var hurt_alpha: float = clampf(hurt_flash_timer / 0.22, 0.0, 1.0)
    draw_circle(Vector2.ZERO, 20.0 * (1.25 - hurt_alpha * 0.25), Color(1.0, 0.18, 0.12, hurt_alpha * 0.12))
    draw_arc(Vector2.ZERO, 24.0 + (1.0 - hurt_alpha) * 9.0, 0.0, TAU, 24, Color(1.0, 0.46, 0.28, hurt_alpha * 0.88), 3.0)
  
  # 碰撞调试显示（仅在需要时绘制）
  if show_collision:
    draw_circle(Vector2.ZERO, 14.0, Color(0.31, 0.76, 0.97, 0.18))
    draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.31, 0.76, 0.97, 0.9), 1.0)
