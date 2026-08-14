extends RefCounted

const PLAYER_ASSET_ROOT: String = "res://assets/sprites/player"
const IDLE_FPS: float = 12.0
const MOVE_FPS: float = 16.0
const IDLE_COLUMNS: int = 6
const IDLE_ROWS: int = 6
const MOVE_ANIMATIONS: Dictionary = {
    "walk_down": "walk_down",
    "walk_down_right": "walk_right_down",
    "walk_right": "walk_right",
    "walk_up_right": "walk_right_up",
    "walk_up": "walk_up",
    "walk_up_left": "walk_left_up",
    "walk_down_left": "walk_left_down",
}


static func build() -> SpriteFrames:
    var sprite_frames := SpriteFrames.new()
    sprite_frames.remove_animation("default")
    _add_grid_animation(sprite_frames, "idle", "idle", IDLE_COLUMNS, IDLE_ROWS, IDLE_FPS)
    for animation_name: String in MOVE_ANIMATIONS:
        _add_atlas_animation(sprite_frames, animation_name, MOVE_ANIMATIONS[animation_name])
    return sprite_frames


static func _add_grid_animation(sprite_frames: SpriteFrames, animation_name: String,
        asset_name: String, columns: int, rows: int, fps: float) -> void:
    var atlas: Texture2D = load("%s/%s.png" % [PLAYER_ASSET_ROOT, asset_name])
    sprite_frames.add_animation(animation_name)
    sprite_frames.set_animation_loop(animation_name, true)
    sprite_frames.set_animation_speed(animation_name, fps)
    for row in rows:
        var top := floori(float(row) * atlas.get_height() / rows)
        var bottom := floori(float(row + 1) * atlas.get_height() / rows)
        for column in columns:
            var left := floori(float(column) * atlas.get_width() / columns)
            var right := floori(float(column + 1) * atlas.get_width() / columns)
            var texture := AtlasTexture.new()
            texture.atlas = atlas
            texture.region = Rect2(left, top, right - left, bottom - top)
            sprite_frames.add_frame(animation_name, texture)


static func _add_atlas_animation(sprite_frames: SpriteFrames, animation_name: String,
        asset_name: String) -> void:
    var metadata_path := "%s/%s.json" % [PLAYER_ASSET_ROOT, asset_name]
    var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
    if not metadata is Dictionary or not metadata.has("frames"):
        push_error("Invalid player animation metadata: %s" % metadata_path)
        return
    var atlas: Texture2D = load("%s/%s.png" % [PLAYER_ASSET_ROOT, asset_name])
    sprite_frames.add_animation(animation_name)
    sprite_frames.set_animation_loop(animation_name, true)
    sprite_frames.set_animation_speed(animation_name, MOVE_FPS)
    var atlas_width: float = atlas.get_width()
    var atlas_height: float = atlas.get_height()
    for frame: Dictionary in metadata["frames"]:
        var texture := AtlasTexture.new()
        texture.atlas = atlas
        if frame.has("uv_min_x") and frame.has("uv_max_x") and frame.has("uv_min_y") and frame.has("uv_max_y"):
            var left: float = round(frame["uv_min_x"] * atlas_width)
            var top: float = round(frame["uv_min_y"] * atlas_height)
            var right: float = round(frame["uv_max_x"] * atlas_width)
            var bottom: float = round(frame["uv_max_y"] * atlas_height)
            texture.region = Rect2(left, top, right - left, bottom - top)
        else:
            texture.region = Rect2(
                frame["pixel_min_x"], frame["pixel_min_y"],
                frame["pixel_max_x"] - frame["pixel_min_x"],
                frame["pixel_max_y"] - frame["pixel_min_y"]
            )
        sprite_frames.add_frame(animation_name, texture)
