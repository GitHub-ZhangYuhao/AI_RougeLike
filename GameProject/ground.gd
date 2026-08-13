@tool
extends Node2D
## 地面：一块覆盖整个地图的四边形，加载一个节点式材质（VisualShader）。
## 材质从 material_path 加载（默认 res://ground_material.tres）。
## 打开那个材质文件即可配置里面的节点和贴图，改动会实时作用到地面。

@export var map_size := Vector2(4608.0, 3456.0)
@export var material_path := 'res://ground_material.tres'
@export var tint := Color.WHITE

var _signature := ''
var _quad: Polygon2D = null

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _signature_string() != _signature:
		_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_quad):
		remove_child(_quad)
		_quad.queue_free()
		_quad = null
	_signature = _signature_string()
	_quad = _build_quad()
	add_child(_quad, false, Node.INTERNAL_MODE_BACK)

func _build_quad() -> Polygon2D:
	var quad := Polygon2D.new()
	var half := map_size * 0.5
	quad.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	quad.uv = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	quad.color = Color.WHITE
	quad.modulate = tint
	var material := load(material_path) as ShaderMaterial
	if material:
		quad.material = material
	return quad

func _signature_string() -> String:
	return '%s|%s|%s' % [map_size, material_path, tint]