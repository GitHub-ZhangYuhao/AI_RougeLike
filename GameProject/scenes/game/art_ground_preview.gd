extends Node2D

@export var pan_speed: float = 900.0
@export var zoom_step: float = 0.12
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.5

@onready var camera: Camera2D = $Camera2D


func _process(delta: float) -> void:
    var direction := Vector2(
        Input.get_axis("ui_left", "ui_right"),
        Input.get_axis("ui_up", "ui_down")
    )
    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    camera.position += direction * pan_speed * delta / camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(camera.zoom.x + zoom_step)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(camera.zoom.x - zoom_step)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
        camera.position = Vector2.ZERO
        _set_zoom(0.5)


func _set_zoom(value: float) -> void:
    var clamped: float = clampf(value, min_zoom, max_zoom)
    camera.zoom = Vector2(clamped, clamped)
