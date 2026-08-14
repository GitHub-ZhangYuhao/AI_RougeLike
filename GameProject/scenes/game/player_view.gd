extends Node2D

const PlayerSpriteFramesScript: GDScript = preload('res://scenes/game/player_sprite_frames.gd')
const WALK_SCALE: float = 0.152
const IDLE_SCALE: float = 0.285
const FALLBACK_SCALE: float = 0.22
const SPRITE_FOOT_OFFSET: float = -48.0
const FALLBACK_FOOT_OFFSET: float = -43.0
const VISIBLE_STATES: Array[String] = ['opening', 'playing', 'choice', 'extraction', 'dead', 'summary']

enum State { IDLE, MOVE, DEAD }
enum Direction { DOWN, DOWN_RIGHT, RIGHT, UP_RIGHT, UP, UP_LEFT, LEFT, DOWN_LEFT }

var state: State = State.IDLE
var direction: Direction = Direction.DOWN
var animation_time: float = 0.0
var simulation_active: bool = false
var _animated_assets_ready: bool = false

@export var show_collision: bool = false
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var fallback_sprite: Sprite2D = $StaticSprite
@onready var shadow: Polygon2D = $Shadow


func _ready() -> void:
  sprite.sprite_frames = PlayerSpriteFramesScript.build()
  sprite.position.y = SPRITE_FOOT_OFFSET
  fallback_sprite.position.y = FALLBACK_FOOT_OFFSET
  fallback_sprite.scale = Vector2.ONE * FALLBACK_SCALE
  _animated_assets_ready = _has_required_animations(sprite.sprite_frames)
  _refresh_visual(true)
  queue_redraw()


func _process(delta: float) -> void:
  if not visible:
    return
  if simulation_active:
    animation_time += delta
  var movement_phase: float = animation_time * (12.0 if state == State.MOVE else 3.0)
  shadow.scale = Vector2(1.0 + sin(movement_phase) * 0.035, 1.0 - sin(movement_phase) * 0.025)
  if fallback_sprite.visible:
    fallback_sprite.position.y = FALLBACK_FOOT_OFFSET + sin(movement_phase) * (3.0 if state == State.MOVE else 1.5)
    fallback_sprite.rotation = sin(movement_phase * 0.5) * (0.025 if state == State.MOVE else 0.012)


func sync_from(player, game_state: String, screen_position: Vector2) -> void:
  position = screen_position
  visible = game_state in VISIBLE_STATES
  simulation_active = game_state == 'playing'
  if not visible:
    sprite.pause()
    return
  var next_state := State.DEAD if game_state == 'dead' else (State.MOVE if player.moving else State.IDLE)
  if player.moving:
    direction = direction_from_angle(player.facing)
  _transition(next_state)
  _refresh_visual()
  if simulation_active and state != State.DEAD:
    sprite.speed_scale = 1.0
    if sprite.visible and not sprite.is_playing():
      sprite.play()
  else:
    sprite.pause()
  modulate = Color(0.72, 0.77, 0.82, 1.0) if state == State.DEAD else Color.WHITE


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
    sprite.scale = Vector2.ONE * IDLE_SCALE
    _play_if_changed(&'idle', force)
    return
  sprite.scale = Vector2.ONE * WALK_SCALE
  sprite.flip_h = direction == Direction.LEFT
  _play_if_changed(animation_for_direction(direction), force)


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
  if show_collision:
    draw_circle(Vector2.ZERO, 14.0, Color(0.31, 0.76, 0.97, 0.18))
    draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.31, 0.76, 0.97, 0.9), 1.0)
