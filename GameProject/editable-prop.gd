@tool
extends Node2D

@export var asset_path := ''
@export var display_height := 400.0
@export var collision_radius := 0.0
@export var flip_h := false
@export var key_black_background := true
@export var tint := Color.WHITE

var _signature := ''
var _generated: Array[Node] = []

func _ready() -> void:
  _refresh()

func _process(_delta: float) -> void:
  if Engine.is_editor_hint():
    var signature := '%s|%s|%s|%s|%s|%s' % [asset_path, display_height, collision_radius, flip_h, key_black_background, tint]
    if signature != _signature:
      _refresh()

func _refresh() -> void:
  if not is_inside_tree():
    return
  for child in _generated:
    if is_instance_valid(child):
      remove_child(child)
      child.queue_free()
  _generated.clear()
  _signature = '%s|%s|%s|%s|%s|%s' % [asset_path, display_height, collision_radius, flip_h, key_black_background, tint]
  var texture := _load_texture(asset_path)
  if texture:
    var sprite := Sprite2D.new()
    sprite.name = 'Preview'
    sprite.texture = texture
    sprite.modulate = tint
    var prop_scale := display_height / float(texture.get_height())
    sprite.scale = Vector2(-prop_scale if flip_h else prop_scale, prop_scale)
    sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)
    if key_black_background:
      sprite.material = _create_keyed_material()
    add_child(sprite, false, Node.INTERNAL_MODE_BACK)
    _generated.append(sprite)
  else:
    var fallback := Polygon2D.new()
    fallback.name = 'MissingAsset'
    fallback.polygon = PackedVector2Array([
      Vector2(-display_height * 0.22, 0.0),
      Vector2(0.0, -display_height),
      Vector2(display_height * 0.22, 0.0),
    ])
    fallback.color = Color(0.82, 0.18, 0.24, 0.75)
    add_child(fallback, false, Node.INTERNAL_MODE_BACK)
    _generated.append(fallback)
  if collision_radius > 0.0:
    var body := StaticBody2D.new()
    body.name = 'Collision'
    body.collision_layer = 1
    body.collision_mask = 2
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = collision_radius
    collision.shape = shape
    collision.position = Vector2(0.0, -collision_radius * 0.45)
    body.add_child(collision)
    add_child(body, false, Node.INTERNAL_MODE_BACK)
    _generated.append(body)

func _load_texture(relative_path: String) -> Texture2D:
  var project_root := ProjectSettings.globalize_path('res://')
  var absolute_path := project_root.path_join(relative_path).simplify_path()
  var image := Image.new()
  if image.load(absolute_path) != OK:
    return null
  image.generate_mipmaps()
  return ImageTexture.create_from_image(image)

func _create_keyed_material() -> ShaderMaterial:
  var shader := Shader.new()
  shader.code = """
shader_type canvas_item;
void fragment() {
  vec4 color = texture(TEXTURE, UV);
  float brightness = max(color.r, max(color.g, color.b));
  float alpha = smoothstep(0.008, 0.045, brightness);
  color.rgb /= max(alpha, 0.22);
  color.a *= alpha;
  COLOR = color;
}
"""
  var material := ShaderMaterial.new()
  material.shader = shader
  return material
