extends Node2D

const PlayerSpriteFramesScript: GDScript = preload("res://scenes/game/player_sprite_frames.gd")
const WALK_SCALE: float = 0.152
const IDLE_SCALE: float = 0.285
const SPRITE_FOOT_OFFSET: float = -48.0
const VISIBLE_STATES: Array[String] = ["opening", "playing", "choice", "extraction", "dead", "summary"]

enum State { IDLE, MOVE }
enum Direction { DOWN, DOWN_RIGHT, RIGHT, UP_RIGHT, UP, UP_LEFT, LEFT, DOWN_LEFT }

var state: State = State.IDLE
var direction: Direction = Direction.DOWN

@export var show_collision: bool = false
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
    sprite.sprite_frames = PlayerSpriteFramesScript.build()
    sprite.position.y = SPRITE_FOOT_OFFSET
    _refresh_animation()
    queue_redraw()


func sync_from(player, game_state: String, screen_position: Vector2) -> void:
    position = screen_position
    visible = game_state in VISIBLE_STATES
    if not visible:
        sprite.pause()
        return
    var next_state: State = State.MOVE if player.moving else State.IDLE
    if player.moving:
        direction = direction_from_angle(player.facing)
    _transition(next_state)
    _refresh_animation()
    if game_state == "playing":
        if not sprite.is_playing():
            sprite.play()
    else:
        sprite.pause()


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


func _transition(next_state: State) -> void:
    if state == next_state:
        return
    state = next_state


func _refresh_animation() -> void:
    if state == State.IDLE:
        sprite.scale = Vector2.ONE * IDLE_SCALE
        sprite.flip_h = false
        _play_if_changed(&"idle")
        return
    sprite.scale = Vector2.ONE * WALK_SCALE
    sprite.flip_h = direction == Direction.LEFT
    var animation: StringName
    match direction:
        Direction.DOWN: animation = &"walk_down"
        Direction.DOWN_RIGHT: animation = &"walk_down_right"
        Direction.RIGHT, Direction.LEFT: animation = &"walk_right"
        Direction.UP_RIGHT: animation = &"walk_up_right"
        Direction.UP: animation = &"walk_up"
        Direction.UP_LEFT: animation = &"walk_up_left"
        Direction.DOWN_LEFT: animation = &"walk_down_left"
    _play_if_changed(animation)


func _play_if_changed(animation: StringName) -> void:
    if sprite.animation == animation:
        return
    sprite.play(animation)


func _draw() -> void:
    if show_collision:
        draw_circle(Vector2.ZERO, 14.0, Color(0.31, 0.76, 0.97, 0.18))
        draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.31, 0.76, 0.97, 0.9), 1.0)
