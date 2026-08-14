extends Node2D

const PlayerSpriteFramesScript: GDScript = preload("res://scenes/game/player_sprite_frames.gd")
const ENTRIES: Array[Array] = [
    ["idle", "Idle", 0.285],
    ["walk_down", "Down", 0.152],
    ["walk_down_right", "Down Right", 0.152],
    ["walk_right", "Right", 0.152],
    ["walk_up_right", "Up Right", 0.152],
    ["walk_up", "Up", 0.152],
    ["walk_up_left", "Up Left", 0.152],
    ["walk_down_left", "Down Left", 0.152],
]


func _ready() -> void:
    var frames: SpriteFrames = PlayerSpriteFramesScript.build()
    for index: int in ENTRIES.size():
        var column: int = index % 4
        var row: int = index / 4
        var center := Vector2(190.0 + column * 300.0, 205.0 + row * 300.0)
        var sprite := AnimatedSprite2D.new()
        sprite.sprite_frames = frames
        sprite.animation = ENTRIES[index][0]
        sprite.position = center
        sprite.scale = Vector2.ONE * ENTRIES[index][2]
        sprite.play()
        add_child(sprite)
        var label := Label.new()
        label.text = ENTRIES[index][1]
        label.position = center + Vector2(-70.0, 92.0)
        label.size = Vector2(140.0, 28.0)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 16)
        add_child(label)
