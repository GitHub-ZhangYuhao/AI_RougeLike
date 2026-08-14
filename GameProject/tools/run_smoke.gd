extends SceneTree
## 冒烟测试入口（SceneTree 脚本，headless 运行）：
##   GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd
## 退出码约定与原型 tools/headless-smoke.mjs 一致：全绿打印 OK、退出码 0；
## 任一失败打印 FAILED、退出码 1（原型侧以抛错达成同等效果）。
## 场景注册与断言汇总在 tests/smoke_runner.gd。

func _initialize() -> void:
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
		quit(0)
	else:
		print("FAILED")
		quit(1)
