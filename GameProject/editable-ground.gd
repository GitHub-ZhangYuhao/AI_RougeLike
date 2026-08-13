@tool
extends Node2D
## 可编辑地面：按尺寸生成平铺瓦片，引用外部配置的 Shader 实例。
##
## - asset_path：地面贴图路径（相对 GameProject）。留空则用纯色回退瓦片。
## - ground_shader：引用的着色器（GroundShader.tres 或场景内嵌的 VisualShader 均可）。
##   脚本把它包成一个 ShaderMaterial，所有瓦片（含回退色块）共享这一个实例，
##   在任何地方修改它都会实时作用到整片地面。留空则不使用材质。

@export var asset_path := '../ArtAsset/Image/Environment/GroundTextures/Production/v09_crisp_cartoon_ground_refinement/final/grass_warm_meadow_crisp.png'
@export var map_size := Vector2(4608.0, 3456.0)
@export var tile_size := 768.0
@export var alternate_flip := true
@export var tint := Color.WHITE
@export var ground_shader: Shader

var _signature := ''
var _tiles: Array[Node] = []

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _signature_string() != _signature:
		_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	_clear_tiles()
	_signature = _signature_string()
	var texture: Texture2D = _load_texture() if asset_path != '' else null
	var material := _create_material()
	var columns := ceili(map_size.x / tile_size)
	var rows := ceili(map_size.y / tile_size)
	for row in range(rows):
		for column in range(columns):
			var tile := _make_tile(column, row, texture, material)
			add_child(tile, false, Node.INTERNAL_MODE_BACK)
			_tiles.append(tile)

func _clear_tiles() -> void:
	for tile in _tiles:
		if is_instance_valid(tile):
			remove_child(tile)
			tile.queue_free()
	_tiles.clear()

func _make_tile(column: int, row: int, texture: Texture2D, material: ShaderMaterial) -> Node2D:
	var tile: Node2D
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2(tile_size / texture.get_width(), tile_size / texture.get_height())
		sprite.flip_h = alternate_flip and (column + row) % 2 == 1
		sprite.flip_v = alternate_flip and row % 3 == 1
		tile = sprite
	else:
		var fallback := Polygon2D.new()
		fallback.polygon = _rectangle_polygon(Vector2(tile_size, tile_size))
		fallback.color = Color('#78966f') if (column + row) % 2 == 0 else Color('#718d68')
		tile = fallback
	tile.position = Vector2(
		-map_size.x * 0.5 + tile_size * (column + 0.5),
		-map_size.y * 0.5 + tile_size * (row + 0.5)
	)
	tile.modulate = tint
	if material:
		tile.material = material
	return tile

func _create_material() -> ShaderMaterial:
	if ground_shader == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = ground_shader
	return material

func _signature_string() -> String:
	return '%s|%s|%s|%s|%s|%s' % [
		asset_path, map_size, tile_size, alternate_flip, tint,
		str(ground_shader),
	]

func _load_texture() -> Texture2D:
	var project_root := ProjectSettings.globalize_path('res://')
	var absolute_path := project_root.path_join(asset_path).simplify_path()
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