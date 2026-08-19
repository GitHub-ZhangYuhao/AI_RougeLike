extends RefCounted

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const UiLayoutScript: GDScript = preload("res://logic/ui_layout.gd")

const VIEW_W: float = 1280.0
const VIEW_H: float = 720.0
const STEP: float = 1.0 / 60.0

func title() -> String:
    return "[23] 触屏选卡（触摸→鼠标桥接）"

func run(runner) -> void:
    Rng.set_seed(2301)
    var tree := Engine.get_main_loop() as SceneTree
    runner.check(tree != null and tree.root != null, "[23] 无法取得 SceneTree/根窗口")
    if tree == null or tree.root == null:
        Rng.clear_source()
        return
    var view = MainScene.instantiate()
    tree.root.add_child(view)
    runner.check(view.run != null and view.run.state == "menu", "[23] 主场景实例应以 menu 状态初始化，实际 %s" % str(view.run.state))
    runner.check(view.run.currentOffers.size() == 6, "[23] 开局应有 6 张武器卡，实际 %d" % view.run.currentOffers.size())
    view.run.state = "opening"

    # a) 单指触摸按下 → 等效鼠标左键单击（坐标 + 点击标志）。
    var touch := InputEventScreenTouch.new()
    touch.index = 0
    touch.position = Vector2(640.0, 360.0)
    touch.pressed = true
    view._input(touch)
    runner.check(view.run.input.mouse_clicked(), "[23] 触摸按下应桥接为鼠标点击")
    runner.check(is_equal_approx(view.run.input.mouse_x, 640.0) and is_equal_approx(view.run.input.mouse_y, 360.0), "[23] 触摸坐标应写入 mouse_x/mouse_y")
    view.run.input.end_frame()

    # b) 触摸拖拽 → 仅更新坐标，不产生点击。
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = Vector2(500.0, 300.0)
    view._input(drag)
    runner.check(is_equal_approx(view.run.input.mouse_x, 500.0) and is_equal_approx(view.run.input.mouse_y, 300.0), "[23] 触摸拖拽应更新鼠标坐标")
    runner.check(not view.run.input.mouse_clicked(), "[23] 触摸拖拽不应产生点击")

    # c) 第二根手指不参与桥接（index != 0 忽略）。
    var second := InputEventScreenTouch.new()
    second.index = 1
    second.position = Vector2(100.0, 100.0)
    second.pressed = true
    view._input(second)
    runner.check(is_equal_approx(view.run.input.mouse_x, 500.0) and is_equal_approx(view.run.input.mouse_y, 300.0), "[23] 第二根手指不应改变鼠标坐标")

    # d) 开局面板：触摸点选第 2 张卡，进入 playing 且对应武器入槽。
    var expected_id: String = view.run.currentOffers[1]["card"]["id"]
    var rects: Array[Dictionary] = UiLayoutScript.get_card_rects(VIEW_W, VIEW_H, view.run.currentOffers.size())
    var target: Dictionary = rects[1]
    var click := InputEventScreenTouch.new()
    click.index = 0
    click.position = Vector2(target["x"] + target["w"] / 2.0, target["y"] + target["h"] / 2.0)
    click.pressed = true
    view._input(click)
    _pump_view(view, 3)
    runner.check(view.run.state == "playing", "[23] 触摸选卡后应进入 playing，实际 %s" % str(view.run.state))
    runner.check(view.run.weapons.size() == 1 and view.run.weapons[0].card["id"] == expected_id, "[23] 第 2 张卡对应武器应入槽")

    view.run.release_runtime_refs()
    tree.root.remove_child(view)
    view.free()
    # AudioManager 是常驻 autoload：bind_run 会把本场景的 run 与 BGM 流留在缓存里，
    # 测试收尾解除引用并清空缓存，避免 headless 退出报 ObjectDB 泄漏 / resources still in use。
    AudioManager.run = null
    AudioManager._bgm_cache.clear()
    # 直接释放 BGM 播放器节点（run=null 后 AudioManager._process 提前返回，不会再触碰），
    # 随节点回收 Ogg 播放链，避免 headless 退出误报泄漏。
    AudioManager._bgm_player_a.free()
    AudioManager._bgm_player_b.free()
    AudioManager._current_bgm_player = null
    AudioManager._next_bgm_player = null
    Rng.clear_source()


## 推进 view 独立对局 n 个逻辑帧：与 game_view._physics_process 一致传入
## 被 CAMERA_ZOOM 除过的尺寸，使 _handle_choice 的卡牌命中矩形还原为
## 1280×720 屏幕坐标（常量单一事实源见 ui_layout.gd）。
func _pump_view(view, n: int) -> void:
    for i in n:
        view.run.step(STEP, VIEW_W / UiLayoutScript.CAMERA_ZOOM, VIEW_H / UiLayoutScript.CAMERA_ZOOM)
        view.run.input.end_frame()
