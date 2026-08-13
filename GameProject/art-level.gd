extends Node2D

@export var map_size := Vector2(4608.0, 3456.0)

@onready var player = $Props/Player

func _ready() -> void:
  var map_rect := Rect2(-map_size * 0.5, map_size)
  player.configure_bounds(map_rect)
  var camera := player.get_node('Camera2D') as Camera2D
  camera.limit_left = int(map_rect.position.x)
  camera.limit_top = int(map_rect.position.y)
  camera.limit_right = int(map_rect.end.x)
  camera.limit_bottom = int(map_rect.end.y)
