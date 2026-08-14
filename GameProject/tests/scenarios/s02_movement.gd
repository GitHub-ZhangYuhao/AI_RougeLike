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
    var sprite_frames: SpriteFrames = PlayerSpriteFramesScript.build()
    runner.check(sprite_frames.get_frame_count("idle") == 36, "[2] Idle 应包含 36 帧")
    runner.check(sprite_frames.get_frame_count("walk_down_left") == 36, "[2] 左下移动应包含 36 帧")
    var left_down_frame: AtlasTexture = sprite_frames.get_frame_texture("walk_down_left", 35)
    runner.check(left_down_frame.region.end.x <= left_down_frame.atlas.get_width() and left_down_frame.region.end.y <= left_down_frame.atlas.get_height(), "[2] 左下移动帧不得越界")
    runner.check(load("res://scenes/game/meadow_level.tscn") != null, "[2] 正式草甸关卡应可加载")
    var clamped: Dictionary = LevelGeometryScript.clamp_circle(9999.0, -9999.0, game.player.radius)
    runner.check(clamped["x"] == LevelGeometryScript.RIGHT - game.player.radius, "[2] 关卡右边界碰撞")
    runner.check(clamped["y"] == LevelGeometryScript.TOP + game.player.radius, "[2] 关卡上边界碰撞")
    runner.check(LevelGeometryScript.is_outside_circle(LevelGeometryScript.RIGHT - 2.0, 0.0, 5.0), "[2] 弹道接触关卡边界应出界")
    var old_x: float = game.player.x
    var old_y: float = game.player.y
    game.player.x = LevelGeometryScript.RIGHT - game.player.radius - LevelGeometryScript.PLAYER_INSET - 1.0
    game.player.y = 0.0
    runner.harness.key_down("KeyD")
    runner.harness.pump(60)
    runner.harness.key_up("KeyD")
    runner.check(game.player.x == LevelGeometryScript.RIGHT - game.player.radius - LevelGeometryScript.PLAYER_INSET, "[2] 玩家不能越出正式关卡")
    runner.check(game.camera.x <= LevelGeometryScript.RIGHT - 640.0, "[2] 相机不能越出正式关卡")
    game.player.x = old_x
    game.player.y = old_y
    game.camera.snap_to(game.player)
    game.player.maxHp = 100000.0
    game.player.hp = 100000.0
