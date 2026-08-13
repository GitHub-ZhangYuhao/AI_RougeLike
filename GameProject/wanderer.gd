extends CharacterBody2D

@export var move_speed := 300.0

var map_rect := Rect2(-2304.0, -1728.0, 4608.0, 3456.0)
var facing := Vector2.DOWN

func _ready() -> void:
  var collision := CollisionShape2D.new()
  var shape := CircleShape2D.new()
  shape.radius = 18.0
  collision.shape = shape
  collision.position = Vector2(0.0, -18.0)
  add_child(collision)
  queue_redraw()

func _physics_process(_delta: float) -> void:
  var direction := Input.get_vector('move_left', 'move_right', 'move_up', 'move_down')
  if direction.length_squared() > 0.0:
    facing = direction.normalized()
  velocity = direction * move_speed
  move_and_slide()
  global_position.x = clampf(global_position.x, map_rect.position.x + 48.0, map_rect.end.x - 48.0)
  global_position.y = clampf(global_position.y, map_rect.position.y + 70.0, map_rect.end.y - 48.0)
  queue_redraw()

func configure_bounds(rect: Rect2) -> void:
  map_rect = rect

func _draw() -> void:
  draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
  draw_circle(Vector2(0.0, 2.0), 24.0, Color(0.02, 0.03, 0.025, 0.32))
  draw_set_transform(Vector2.ZERO)
  draw_circle(Vector2(0.0, -20.0), 18.0, Color('#f2d6b3'))
  draw_circle(Vector2(0.0, 4.0), 22.0, Color('#64a58c'))
  draw_colored_polygon(PackedVector2Array([
    Vector2(-23.0, 8.0), Vector2(23.0, 8.0), Vector2(15.0, 38.0), Vector2(-15.0, 38.0),
  ]), Color('#477d6d'))
  draw_circle(Vector2(0.0, -29.0), 20.0, Color('#263d38'))
  draw_arc(Vector2.ZERO + facing * 11.0, 6.0, 0.0, TAU, 20, Color(0.96, 0.87, 0.61, 0.92), 3.0)
