extends SceneTree
## 冒烟测试入口（SceneTree 脚本，headless 运行）：
##   GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd
## 退出码约定与原型 tools/headless-smoke.mjs 一致：全绿打印 OK、退出码 0；
## 任一失败打印 FAILED、退出码 1（原型侧以抛错达成同等效果）。
## 场景注册与断言汇总在 tests/smoke_runner.gd。

func _initialize() -> void:
    # 延后到第一帧再跑：_initialize 阶段根窗口尚未进入场景树，
    # 场景类章节（如 [23]）实例化的主场景无法完成 add_child/_ready，@onready 全为空。
    process_frame.connect(_run_smoke, CONNECT_ONE_SHOT)


func _run_smoke() -> void:
    var script: GDScript = load("res://tests/smoke_runner.gd")
    if script == null:
        printerr("[smoke] cannot load res://tests/smoke_runner.gd")
        print("FAILED")
        quit(1)
        return
    var runner: RefCounted = script.new()
    var all_passed: bool = runner.run_all()
    runner = null
    script = null
    if all_passed:
        print("OK")
        _finish(0)
    else:
        print("FAILED")
        _finish(1)


## 延迟若干帧再 quit：让 AudioServer 完成对已 stop/free 的 BGM 播放对象的回收，
## 否则 headless 退出会误报 ObjectDB 泄漏（bgm ogg 播放链）。单帧窗口不稳定，
## 给混音线程 10 帧窗口（实测 1 帧时泄漏必现）。
var _exit_code: int = 0
var _drain_frames: int = 0


func _finish(code: int) -> void:
    _exit_code = code
    _drain_frames = 10
    process_frame.connect(_drain_then_quit)


func _drain_then_quit() -> void:
    _drain_frames -= 1
    if _drain_frames <= 0:
        process_frame.disconnect(_drain_then_quit)
        quit(_exit_code)
