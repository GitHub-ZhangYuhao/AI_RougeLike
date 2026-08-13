@tool
extends Node2D

@export var asset_path := '../ArtAsset/Image/Environment/GroundTextures/Production/v09_crisp_cartoon_ground_refinement/final/grass_warm_meadow_crisp.png'
@export var map_size := Vector2(4608.0, 3456.0)
@export var tile_size := 768.0
@export var alternate_flip := true
@export var tint := Color.WHITE
@export var shader_enabled := true

const GROUND_SHADER_PATH := 'res://ground-shader.gdshader'

var _signature := ''
var _tiles: Array[Node] = []

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var signature := '%s|%s|%s|%s|%s|%s' % [asset_path, map_size, tile_size, alternate_flip, tint, shader_enabled]
		if signature != _signature:
			_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	for tile in _tiles:
		if is_instance_valid(tile):
			remove_child(tile)
			tile.queue_free()
	_tiles.clear()
	_signature = '%s|%s|%s|%s|%s|%s' % [asset_path, map_size, tile_size, alternate_flip, tint, shader_enabled]
	var texture := _load_texture(asset_path)
	var ground_material := _create_ground_material()
	var columns := ceili(map_size.x / tile_size)
	var rows := ceili(map_size.y / tile_size)
	for row in range(rows):
		for column in range(columns):
			var center := Vector2(
				-map_size.x * 0.5 + tile_size * (column + 0.5),
				-map_size.y * 0.5 + tile_size * (row + 0.5)
			)
			if texture:
				var sprite := Sprite2D.new()
				sprite.texture = texture
				sprite.position = center
				sprite.scale = Vector2(tile_size / texture.get_width(), tile_size / texture.get_height())
				sprite.flip_h = alternate_flip and (column + row) % 2 == 1
				sprite.flip_v = alternate_flip and row % 3 == 1
				sprite.modulate = tint
				if ground_material:
					sprite.material = ground_material
				add_child(sprite, false, Node.INTERNAL_MODE_BACK)
				_tiles.append(sprite)
			else:
				var fallback := Polygon2D.new()
				fallback.polygon = _rectangle_polygon(Vector2(tile_size, tile_size))
				fallback.position = center
				fallback.color = Color('#78966f') if (column + row) % 2 == 0 else Color('#718d68')
				add_child(fallback, false, Node.INTERNAL_MODE_BACK)
				_tiles.append(fallback)

func _create_ground_material() -> ShaderMaterial:
	if not shader_enabled:
		return null
	var shader := load(GROUND_SHADER_PATH) as Shader
	if shader == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _load_texture(relative_path: String) -> Texture2D:
	var project_root := ProjectSettings.globalize_path('res://')
	var absolute_path := project_root.path_join(relative_path).simplify_path()
	var image := Image.new()
	if image.load(absolute_path) != OK:
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _rectangle_polygon(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
