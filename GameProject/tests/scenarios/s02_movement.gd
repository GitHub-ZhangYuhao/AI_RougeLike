extends RefCounted

const PlayerViewScript: GDScript = preload("res://scenes/game/player_view.gd")
const PlayerSpriteFramesScript: GDScript = preload("res://scenes/game/player_sprite_frames.gd")
const LevelGeometryScript: GDScript = preload("res://logic/level_geometry.gd")

func title() -> String:
    return "[2] 移动"

func run(runner) -> void:
    var game = runner.harness.ensure_game()
    var start_x: float = game.player.x
    runner.harness.key_down("KeyD")
    runner.harness.pump(60)
    runner.harness.key_up("KeyD")
    runner.check(game.player.x - start_x > 100.0, "[2] 玩家移动异常")
    runner.check(PlayerViewScript.direction_from_angle(0.0) == PlayerViewScript.Direction.RIGHT, "[2] 玩家表现右朝向")
    runner.check(PlayerViewScript.direction_from_angle(PI * 0.5) == PlayerViewScript.Direction.DOWN, "[2] 玩家表现下朝向")
    runner.check(PlayerViewScript.direction_from_angle(PI) == PlayerViewScript.Direction.LEFT, "[2] 玩家表现左朝向")
    runner.check(PlayerViewScript.direction_from_angle(PI * 0.75) == PlayerViewScript.Direction.DOWN_LEFT, "[2] 玩家表现左下朝向")
    runner.check(PlayerViewScript.direction_from_angle(-PI * 0.5) == PlayerViewScript.Direction.UP, "[2] 玩家表现上朝向")
    runner.check(PlayerViewScript.animation_for_direction(PlayerViewScript.Direction.DOWN_LEFT) == &"walk_down_left", "[2] 左下方向应使用独立移动动画")
    runner.check(PlayerViewScript.animation_for_direction(PlayerViewScript.Direction.LEFT) == &"walk_right", "[2] 正左方向应镜像右向动画")
    var player_scene: PackedScene = load("res://scenes/game/player_view.tscn")
    var player_view = player_scene.instantiate()
    player_view._ready()
    var animated_sprite := player_view.get_node_or_null("Sprite") as AnimatedSprite2D
    runner.check(animated_sprite != null, "[2] 玩家场景应包含 AnimatedSprite2D")
    runner.check(animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.get_frame_count("walk_down") == 36, "[2] 玩家动画图集应在主场景加载")
    runner.check(player_view.get_node_or_null("StaticSprite") is Sprite2D, "[2] 玩家静态回退贴图应继续保留")
    player_view.free()
    var sprite_frames: SpriteFrames = PlayerSpriteFramesScript.build()
    runner.check(sprite_frames.get_frame_count("idle") == 36, "[2] Idle 应包含 36 帧")
    runner.check(sprite_frames.get_frame_count("walk_down_left") == 36, "[2] 左下移动应包含 36 帧")
    var left_down_frame: AtlasTexture = sprite_frames.get_frame_texture("walk_down_left", 35)
    runner.check(left_down_frame.region.end.x <= left_down_frame.atlas.get_width() and left_down_frame.region.end.y <= left_down_frame.atlas.get_height(), "[2] 左下移动帧不得越界")
    runner.check(load("res://scenes/game/meadow_level.tscn") != null, "[2] 正式草甸关卡应可加载")
    runner.check(load("res://scenes/game/world_art_view.gd") != null, "[2] 正式世界美术表现应可加载")
    runner.check(load("res://assets/sprites/player/player_static.png") != null, "[2] 玩家正式静态立绘应可加载")
    runner.check(load("res://assets/icons/weapon_sword.png") != null, "[2] 武器正式图标应可加载")
    runner.check(load("res://assets/fonts/noto_sans_sc.ttf") != null, "[2] 中文 UI 字体应可加载")
    var clamped: Dictionary = LevelGeometryScript.clamp_circle(9999.0, -9999.0, game.player.radius)
    runner.check(clamped["x"] == LevelGeometryScript.RIGHT - game.player.radius, "[2] 关卡右边界碰撞")
    runner.check(clamped["y"] == LevelGeometryScript.TOP + game.player.radius, "[2] 关卡上边界碰撞")
    runner.check(LevelGeometryScript.is_outside_circle(LevelGeometryScript.RIGHT - 2.0, 0.0, 5.0), "[2] 弹道接触关卡边界应出界")
    runner.check(LevelGeometryScript.point_in_walkable(0.0, 0.0), "[2] 出生点应在可行走区域内")
    runner.check(LevelGeometryScript.point_in_walkable(300.0, 0.0), "[2] 可行走区域应覆盖出生点右侧")
    runner.check(not LevelGeometryScript.point_in_walkable(9999.0, 0.0), "[2] 远离关卡的点应判为可行走区域外")
    var walkable_clamped: Dictionary = LevelGeometryScript.clamp_walkable_circle(9999.0, 0.0, game.player.radius)
    runner.check(LevelGeometryScript.point_in_walkable(walkable_clamped["x"], walkable_clamped["y"]), "[2] 区域外的圆应被钳制回可行走区域")
    var walkable_again: Dictionary = LevelGeometryScript.clamp_walkable_circle(walkable_clamped["x"], walkable_clamped["y"], game.player.radius)
    runner.check(walkable_again["x"] == walkable_clamped["x"] and walkable_again["y"] == walkable_clamped["y"], "[2] 可行走钳制结果应幂等")
    var camera_clamped: Dictionary = LevelGeometryScript.clamp_camera(LevelGeometryScript.RIGHT + 500.0, 0.0, 1280.0, 720.0)
    runner.check(camera_clamped["x"] == LevelGeometryScript.RIGHT - 640.0, "[2] 相机不能越出正式关卡")
    var old_x: float = game.player.x
    var old_y: float = game.player.y
    game.player.x = 300.0
    game.player.y = 0.0
    game.camera.snap_to(game.player)
    runner.harness.key_down("KeyD")
    runner.harness.pump(60)
    runner.check(game.player.x > 320.0, "[2] 玩家应能沿可行走区域边界滑动")
    runner.harness.key_up("KeyD")
    runner.check(LevelGeometryScript.point_in_walkable(game.player.x, game.player.y), "[2] 玩家不能越出可行走区域")
    game.player.x = old_x
    game.player.y = old_y
    game.camera.snap_to(game.player)
    game.player.maxHp = 100000.0
    game.player.hp = 100000.0
