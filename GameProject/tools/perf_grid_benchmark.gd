extends SceneTree
## 空间网格性能基准 harness 入口（独立工具，不进 smoke 注册）：
##   GameEngine\Godot.exe --headless --path GameProject --script res://tools/perf_grid_benchmark.gd
## 实现见 res://tools/perf_grid_benchmark_impl.gd；用于 M6 焦点 1（180 敌人性能）
## 中 spatial_grid 接入前后对比测量（PROGRESS.md 2 当前焦点、OPTIMIZATION_TRACKER 第八轮）。
## （与 run_smoke.gd 相同的两段式：--script 主脚本在 autoload 注册前编译，
##  不能直接引用 autoload 标识符，故实现体用 load() 运行时加载。）

func _initialize() -> void:
    var script: GDScript = load("res://tools/perf_grid_benchmark_impl.gd")
    if script == null:
        printerr("[perf-grid] cannot load res://tools/perf_grid_benchmark_impl.gd")
        quit(1)
        return
    var impl: RefCounted = script.new()
    impl.run()
    quit(0)
