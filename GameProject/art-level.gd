extends Node2D

const MAP_SIZE := Vector2(4608.0, 3456.0)
const TILE_SIZE := 512.0
const ENVIRONMENT_ROOT := '../ArtAsset/Image/Environment/MapDesign/'
const GROUND_ROOT := ENVIRONMENT_ROOT + 'v09_crisp_cartoon_ground_refinement/final/'
const PROP_ROOT := ENVIRONMENT_ROOT + 'v03_components_black/'
const GROUND_FILE := GROUND_ROOT + 'grass_warm_meadow_crisp.png'
const TREES := [
  PROP_ROOT + '01_trees/peach_tree_large.png',
  PROP_ROOT + '01_trees/peach_tree_medium.png',
  PROP_ROOT + '01_trees/peach_tree_sapling.png',
]
const ROCKS := [
  PROP_ROOT + '02_rocks/moss_rock_crescent_cluster.png',
  PROP_ROOT + '02_rocks/moss_rock_single.png',
  PROP_ROOT + '02_rocks/moss_rock_small_cluster.png',
]
const PLANTS := [
  PROP_ROOT + '03_plants/flower_clump_pink.png',
  PROP_ROOT + '03_plants/flower_clump_white_yellow.png',
  PROP_ROOT + '03_plants/grass_tuft_teal.png',
  PROP_ROOT + '03_plants/grass_tuft_warm.png',
]

@onready var ground: Node2D = $Ground
@onready var ground_details: Node2D = $GroundDetails
@onready var props: Node2D = $Props
@onready var boundaries: Node2D = $Boundaries
@onready var player = $Props/Player
@onready var asset_warning: Label = $Interface/AssetWarning

var rng := RandomNumberGenerator.new()
var texture_cache: Dictionary = {}
var missing_assets: Array[String] = []
var keyed_material: ShaderMaterial

func _ready() -> void:
  rng.seed = 20260813
  keyed_material = _create_keyed_material()
  _build_ground()
  _build_ground_details()
  _build_boundaries()
  _build_landmarks()
  _scatter_plants()
  _configure_player_and_camera()
  asset_warning.text = '' if missing_assets.is_empty() else '部分外部美术资源未找到，当前使用程序化占位：' + str(missing_assets.size())

func _build_ground() -> void:
  var texture := _load_external_texture(GROUND_FILE)
  var columns := ceili(MAP_SIZE.x / TILE_SIZE)
  var rows := ceili(MAP_SIZE.y / TILE_SIZE)
  for row in range(rows):
    for column in range(columns):
      var center := Vector2(
        -MAP_SIZE.x * 0.5 + TILE_SIZE * (column + 0.5),
        -MAP_SIZE.y * 0.5 + TILE_SIZE * (row + 0.5)
      )
      if texture:
        var tile := Sprite2D.new()
        tile.texture = texture
        tile.position = center
        tile.scale = Vector2(TILE_SIZE / texture.get_width(), TILE_SIZE / texture.get_height())
        tile.flip_h = (column + row) % 2 == 1
        tile.flip_v = row % 3 == 1
        ground.add_child(tile)
      else:
        var fallback := Polygon2D.new()
        fallback.polygon = _rectangle_polygon(Vector2(TILE_SIZE, TILE_SIZE))
        fallback.position = center
        fallback.color = Color('#78966f') if (column + row) % 2 == 0 else Color('#718d68')
        ground.add_child(fallback)

func _build_ground_details() -> void:
  var path := Line2D.new()
  path.width = 150.0
  path.default_color = Color(0.48, 0.35, 0.22, 0.52)
  path.joint_mode = Line2D.LINE_JOINT_ROUND
  path.begin_cap_mode = Line2D.LINE_CAP_ROUND
  path.end_cap_mode = Line2D.LINE_CAP_ROUND
  path.points = PackedVector2Array([
    Vector2(-2200.0, 580.0), Vector2(-1450.0, 280.0), Vector2(-760.0, 360.0),
    Vector2(-120.0, 80.0), Vector2(620.0, 40.0), Vector2(1320.0, -360.0), Vector2(2200.0, -520.0),
  ])
  ground_details.add_child(path)

  var stream := Line2D.new()
  stream.width = 190.0
  stream.default_color = Color(0.28, 0.58, 0.62, 0.62)
  stream.joint_mode = Line2D.LINE_JOINT_ROUND
  stream.begin_cap_mode = Line2D.LINE_CAP_ROUND
  stream.end_cap_mode = Line2D.LINE_CAP_ROUND
  stream.points = PackedVector2Array([
    Vector2(-1180.0, -1720.0), Vector2(-980.0, -1060.0), Vector2(-1120.0, -420.0),
    Vector2(-880.0, 220.0), Vector2(-1020.0, 930.0), Vector2(-700.0, 1720.0),
  ])
  ground_details.add_child(stream)

  for position in [Vector2(-980.0, -620.0), Vector2(-970.0, 720.0)]:
    var bridge := Polygon2D.new()
    bridge.polygon = _rectangle_polygon(Vector2(260.0, 110.0))
    bridge.position = position
    bridge.rotation = -0.12
    bridge.color = Color('#a98250')
    ground_details.add_child(bridge)

  var border := Line2D.new()
  border.width = 18.0
  border.default_color = Color(0.22, 0.34, 0.24, 0.82)
  border.closed = true
  border.points = PackedVector2Array([
    Vector2(-MAP_SIZE.x * 0.5, -MAP_SIZE.y * 0.5),
    Vector2(MAP_SIZE.x * 0.5, -MAP_SIZE.y * 0.5),
    Vector2(MAP_SIZE.x * 0.5, MAP_SIZE.y * 0.5),
    Vector2(-MAP_SIZE.x * 0.5, MAP_SIZE.y * 0.5),
  ])
  ground_details.add_child(border)

func _build_landmarks() -> void:
  var tree_layout := [
    [Vector2(-1960, -1320), 650.0, 58.0, 0], [Vector2(-1360, -1410), 520.0, 48.0, 1],
    [Vector2(-260, -1460), 610.0, 56.0, 0], [Vector2(920, -1360), 470.0, 42.0, 1],
    [Vector2(1880, -1180), 620.0, 56.0, 0], [Vector2(2080, -120), 500.0, 46.0, 1],
    [Vector2(1970, 1260), 640.0, 58.0, 0], [Vector2(970, 1430), 450.0, 40.0, 2],
    [Vector2(-180, 1500), 560.0, 50.0, 1], [Vector2(-1500, 1390), 650.0, 58.0, 0],
    [Vector2(-2100, 680), 460.0, 42.0, 2], [Vector2(420, -620), 540.0, 48.0, 1],
  ]
  for entry in tree_layout:
    _add_prop(TREES[entry[3]], entry[0], entry[1], entry[2], true)

  var rock_layout := [
    [Vector2(-1650, -520), 190.0, 48.0, 0], [Vector2(-530, -980), 150.0, 38.0, 2],
    [Vector2(1250, -820), 210.0, 52.0, 0], [Vector2(1610, 420), 145.0, 36.0, 1],
    [Vector2(830, 1050), 180.0, 45.0, 2], [Vector2(-1420, 980), 205.0, 50.0, 0],
  ]
  for entry in rock_layout:
    _add_prop(ROCKS[entry[3]], entry[0], entry[1], entry[2], true)

func _scatter_plants() -> void:
  for index in range(70):
    var position := Vector2(
      rng.randf_range(-MAP_SIZE.x * 0.46, MAP_SIZE.x * 0.46),
      rng.randf_range(-MAP_SIZE.y * 0.45, MAP_SIZE.y * 0.45)
    )
    if position.distance_to(Vector2.ZERO) < 230.0:
      continue
    var target_height := rng.randf_range(54.0, 105.0)
    _add_prop(PLANTS[index % PLANTS.size()], position, target_height, 0.0, false)

func _add_prop(file: String, position: Vector2, target_height: float, collision_radius: float, flip_allowed: bool) -> void:
  var root := Node2D.new()
  root.position = position
  props.add_child(root)
  var texture := _load_external_texture(file)
  if texture:
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.material = keyed_material
    var prop_scale := target_height / float(texture.get_height())
    sprite.scale = Vector2(prop_scale, prop_scale)
    sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)
    sprite.flip_h = flip_allowed and rng.randf() > 0.5
    root.add_child(sprite)
  else:
    var fallback := Polygon2D.new()
    fallback.polygon = PackedVector2Array([
      Vector2(-target_height * 0.22, 0.0), Vector2(0.0, -target_height), Vector2(target_height * 0.22, 0.0),
    ])
    fallback.color = Color('#496b4f')
    root.add_child(fallback)
  if collision_radius > 0.0:
    var body := StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 2
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = collision_radius
    collision.shape = shape
    collision.position = Vector2(0.0, -collision_radius * 0.45)
    body.add_child(collision)
    root.add_child(body)

func _build_boundaries() -> void:
  _add_boundary(Vector2(0.0, -MAP_SIZE.y * 0.5 - 32.0), Vector2(MAP_SIZE.x + 128.0, 96.0))
  _add_boundary(Vector2(0.0, MAP_SIZE.y * 0.5 + 32.0), Vector2(MAP_SIZE.x + 128.0, 96.0))
  _add_boundary(Vector2(-MAP_SIZE.x * 0.5 - 32.0, 0.0), Vector2(96.0, MAP_SIZE.y + 128.0))
  _add_boundary(Vector2(MAP_SIZE.x * 0.5 + 32.0, 0.0), Vector2(96.0, MAP_SIZE.y + 128.0))

func _add_boundary(position: Vector2, size: Vector2) -> void:
  var body := StaticBody2D.new()
  body.position = position
  body.collision_layer = 1
  body.collision_mask = 2
  var collision := CollisionShape2D.new()
  var shape := RectangleShape2D.new()
  shape.size = size
  collision.shape = shape
  body.add_child(collision)
  boundaries.add_child(body)

func _configure_player_and_camera() -> void:
  var map_rect := Rect2(-MAP_SIZE * 0.5, MAP_SIZE)
  player.configure_bounds(map_rect)
  player.position = Vector2(0.0, 260.0)
  var camera := player.get_node('Camera2D') as Camera2D
  camera.limit_left = int(map_rect.position.x)
  camera.limit_top = int(map_rect.position.y)
  camera.limit_right = int(map_rect.end.x)
  camera.limit_bottom = int(map_rect.end.y)

func _load_external_texture(relative_path: String) -> Texture2D:
  if texture_cache.has(relative_path):
    return texture_cache[relative_path]
  var absolute_path := ProjectSettings.globalize_path('res://' + relative_path)
  var image := Image.new()
  var error := image.load(absolute_path)
  if error != OK:
    missing_assets.append(relative_path)
    texture_cache[relative_path] = null
    return null
  image.generate_mipmaps()
  var texture := ImageTexture.create_from_image(image)
  texture_cache[relative_path] = texture
  return texture

func _create_keyed_material() -> ShaderMaterial:
  var shader := Shader.new()
  shader.code = """
shader_type canvas_item;
void fragment() {
  vec4 color = texture(TEXTURE, UV);
  float brightness = max(color.r, max(color.g, color.b));
  color.a *= smoothstep(0.008, 0.04, brightness);
  COLOR = color;
}
"""
  var material := ShaderMaterial.new()
  material.shader = shader
  return material

func _rectangle_polygon(size: Vector2) -> PackedVector2Array:
  var half := size * 0.5
  return PackedVector2Array([
    Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
    Vector2(half.x, half.y), Vector2(-half.x, half.y),
  ])
