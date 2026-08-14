extends Node2D

const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const PROPS: Array[Dictionary] = [
  {'key': 'peachTreeLarge', 'position': Vector2(-1780, -1690), 'size': 420.0, 'flip': false},
  {'key': 'peachTreeMedium', 'position': Vector2(-1180, -1840), 'size': 330.0, 'flip': true},
  {'key': 'peachTreeLarge', 'position': Vector2(1690, -1740), 'size': 405.0, 'flip': true},
  {'key': 'peachTreeSmall', 'position': Vector2(1080, -1860), 'size': 230.0, 'flip': false},
  {'key': 'peachTreeMedium', 'position': Vector2(-1810, 1600), 'size': 350.0, 'flip': false},
  {'key': 'peachTreeLarge', 'position': Vector2(1710, 1690), 'size': 430.0, 'flip': true},
  {'key': 'peachTreeSmall', 'position': Vector2(-1040, 1860), 'size': 225.0, 'flip': true},
  {'key': 'boulderCluster', 'position': Vector2(-1850, -780), 'size': 245.0, 'flip': false},
  {'key': 'boulderCluster', 'position': Vector2(1840, 760), 'size': 230.0, 'flip': true},
  {'key': 'boulderCluster', 'position': Vector2(760, 1840), 'size': 210.0, 'flip': false},
  {'key': 'boundaryStone', 'position': Vector2(-1950, 0), 'size': 150.0, 'flip': false},
  {'key': 'boundaryStone', 'position': Vector2(1950, -120), 'size': 150.0, 'flip': true},
  {'key': 'boundaryPillar', 'position': Vector2(-1560, -1960), 'size': 190.0, 'flip': false},
  {'key': 'boundaryPillar', 'position': Vector2(1560, -1960), 'size': 190.0, 'flip': true},
  {'key': 'boundaryPillar', 'position': Vector2(-1560, 1960), 'size': 190.0, 'flip': true},
  {'key': 'boundaryPillar', 'position': Vector2(1560, 1960), 'size': 190.0, 'flip': false},
  {'key': 'roadsideShrine', 'position': Vector2(-620, -1480), 'size': 235.0, 'flip': false},
  {'key': 'lanternPost', 'position': Vector2(-410, -1420), 'size': 180.0, 'flip': false},
  {'key': 'roadsideShrine', 'position': Vector2(1160, 1300), 'size': 220.0, 'flip': true},
  {'key': 'lanternPost', 'position': Vector2(960, 1350), 'size': 170.0, 'flip': true},
  {'key': 'shrub', 'position': Vector2(-1320, -1070), 'size': 170.0, 'flip': false},
  {'key': 'shrub', 'position': Vector2(1430, -1040), 'size': 175.0, 'flip': true},
  {'key': 'shrub', 'position': Vector2(-1440, 970), 'size': 165.0, 'flip': true},
  {'key': 'shrub', 'position': Vector2(1420, 1080), 'size': 180.0, 'flip': false},
  {'key': 'grassTuft', 'position': Vector2(-760, -940), 'size': 105.0, 'flip': false},
  {'key': 'grassTuft', 'position': Vector2(820, -1120), 'size': 115.0, 'flip': true},
  {'key': 'grassTuft', 'position': Vector2(-920, 820), 'size': 100.0, 'flip': true},
  {'key': 'grassTuft', 'position': Vector2(720, 970), 'size': 105.0, 'flip': false},
  {'key': 'wildflowers', 'position': Vector2(-280, -1110), 'size': 125.0, 'flip': false},
  {'key': 'wildflowers', 'position': Vector2(330, 1160), 'size': 130.0, 'flip': true},
  {'key': 'fallenPetals', 'position': Vector2(-520, -1280), 'size': 175.0, 'flip': false},
  {'key': 'fallenPetals', 'position': Vector2(1040, 1470), 'size': 170.0, 'flip': true},
  {'key': 'fallenPetals', 'position': Vector2(120, 430), 'size': 150.0, 'flip': false},
]


func _ready() -> void:
  queue_redraw()


func _draw() -> void:
  for prop: Dictionary in PROPS:
    _draw_prop(prop)


func _draw_prop(prop: Dictionary) -> void:
  var texture: Texture2D = ArtCatalog.ENVIRONMENT_TEXTURES[prop['key']]
  var position: Vector2 = prop['position']
  var size: float = prop['size']
  if prop['key'] != 'fallenPetals':
    var shadow_width: float = size * (0.33 if 'Tree' in prop['key'] else 0.27)
    draw_set_transform(position + Vector2(0.0, size * 0.18), 0.0, Vector2(shadow_width, size * 0.08))
    draw_circle(Vector2.ZERO, 1.0, Color(0.025, 0.04, 0.028, 0.19))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
  var texture_size: Vector2 = texture.get_size()
  var factor: float = size / maxf(texture_size.x, texture_size.y)
  var scale := Vector2(-factor if prop['flip'] else factor, factor)
  draw_set_transform(position - Vector2(0.0, size * 0.2), 0.0, scale)
  draw_texture(texture, -texture_size * 0.5, Color.WHITE)
  draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
