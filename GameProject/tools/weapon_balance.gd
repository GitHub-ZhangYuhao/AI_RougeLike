extends SceneTree
## 武器强度对比 harness 入口（独立工具，不进 smoke 注册）：
##   GameEngine\Godot.exe --headless --path GameProject --script res://tools/weapon_balance.gd
## 实现见 res://tools/weapon_balance_impl.gd；方法与数据记录在 BALANCE.md「第六轮」。
## （与 run_smoke.gd 相同的两段式：--script 主脚本在 autoload 注册前编译，
##  不能直接引用 autoload 标识符，故实现体用 load() 运行时加载。）

func _initialize() -> void:
    var script: GDScript = load("res://tools/weapon_balance_impl.gd")
    if script == null:
        printerr("[weapon-balance] cannot load res://tools/weapon_balance_impl.gd")
        quit(1)
        return
    var impl: RefCounted = script.new()
    impl.run()
    quit(0)
