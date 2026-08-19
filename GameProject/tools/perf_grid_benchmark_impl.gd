extends RefCounted
## M6 焦点 1 测量工具：敌人分离与邻域查询，线性扫描 vs 空间网格（spatial_grid.gd）对比。
## 确定性约定：固定 RNG 种子；每次计时 pass 前恢复位置快照，保证两种路径输入完全一致。
## 用法入口见 res://tools/perf_grid_benchmark.gd（headless 两段式）。

const EnemyScript: GDScript = preload("res://logic/enemy.gd")
const SpatialGridScript: GDScript = preload("res://logic/systems/spatial_grid.gd")

const SEED: int = 20260819
const DT: float = 1.0 / 60.0
const WARMUP: int = 3
const ITERS: int = 30
const AREA_W: float = 900.0
const AREA_H: float = 600.0
const SIZES: Array = [60, 120, 180, 240]
const PROJECTILE_COUNT: int = 48
const PROJECTILE_RADIUS: float = 12.0

var _rng := RandomNumberGenerator.new()


func run() -> void:
    print("[perf-grid] separate_enemies: linear vs grid (dt=%.4f, area %.0fx%.0f, warmup %d, iters %d)" % [DT, AREA_W, AREA_H, WARMUP, ITERS])
    print("N\tlinear_us\tgrid_us\tspeedup\trebuild_us\tequiv_max_delta")
    for n in SIZES:
        _bench_separation(int(n))
    print("")
    print("[perf-grid] 邻域查询（投射物命中测试代理，P=%d，pr=%.0f）" % [PROJECTILE_COUNT, PROJECTILE_RADIUS])
    print("N\tscan_us\tgrid_us\tspeedup\thits(scan/grid)")
    for n in SIZES:
        _bench_query(int(n))


func _spawn(n: int) -> Array:
    _rng.seed = SEED
    var enemies: Array = []
    for i in n:
        var x: float = _rng.randf_range(-AREA_W * 0.5, AREA_W * 0.5)
        var y: float = _rng.randf_range(-AREA_H * 0.5, AREA_H * 0.5)
        enemies.append(EnemyScript.create_chaser(x, y, 0.0))
    return enemies


func _snapshot(enemies: Array) -> Array:
    var out: Array = []
    for e in enemies:
        out.append(Vector2(e.x, e.y))
    return out


func _restore(enemies: Array, snap: Array) -> void:
    for i in enemies.size():
        enemies[i].x = snap[i].x
        enemies[i].y = snap[i].y


func _bench_separation(n: int) -> void:
    var enemies: Array = _spawn(n)
    var snap: Array = _snapshot(enemies)
    var grid = SpatialGridScript.new()

    # 等价性：同一初始状态各跑一次，最终位置必须逐字一致（候选升序保证遍历顺序相同）。
    _restore(enemies, snap)
    EnemyScript.separate_enemies(enemies, DT, null)
    var linear_end: Array = _snapshot(enemies)
    _restore(enemies, snap)
    grid.rebuild(enemies)
    EnemyScript.separate_enemies(enemies, DT, grid)
    var max_delta: float = 0.0
    for i in enemies.size():
        max_delta = maxf(max_delta, absf(enemies[i].x - linear_end[i].x) + absf(enemies[i].y - linear_end[i].y))

    # 线性路径计时。
    for w in WARMUP:
        _restore(enemies, snap)
        EnemyScript.separate_enemies(enemies, DT, null)
    var t0: int = Time.get_ticks_usec()
    for it in ITERS:
        _restore(enemies, snap)
        EnemyScript.separate_enemies(enemies, DT, null)
    var linear_us: float = float(Time.get_ticks_usec() - t0) / ITERS

    # 网格路径计时（rebuild + separate，接入后的真实每帧成本）。
    for w in WARMUP:
        _restore(enemies, snap)
        grid.rebuild(enemies)
        EnemyScript.separate_enemies(enemies, DT, grid)
    t0 = Time.get_ticks_usec()
    for it in ITERS:
        _restore(enemies, snap)
        grid.rebuild(enemies)
        EnemyScript.separate_enemies(enemies, DT, grid)
    var grid_us: float = float(Time.get_ticks_usec() - t0) / ITERS

    # 单独 rebuild 成本。
    _restore(enemies, snap)
    t0 = Time.get_ticks_usec()
    for it in ITERS:
        grid.rebuild(enemies)
    var rebuild_us: float = float(Time.get_ticks_usec() - t0) / ITERS

    print("%d\t%.1f\t%.1f\tx%.2f\t%.1f\t%.6f" % [n, linear_us, grid_us, linear_us / maxf(grid_us, 0.001), rebuild_us, max_delta])


func _bench_query(n: int) -> void:
    var enemies: Array = _spawn(n)
    var grid = SpatialGridScript.new()
    grid.rebuild(enemies)

    var px: Array = []
    var py: Array = []
    for p in PROJECTILE_COUNT:
        px.append(_rng.randf_range(-AREA_W * 0.5, AREA_W * 0.5))
        py.append(_rng.randf_range(-AREA_H * 0.5, AREA_H * 0.5))

    # 命中数一致性：两条路径对同一批投射物必须数出相同命中。
    var scan_hits: int = _scan_hits(enemies, px, py)
    var grid_hits: int = _grid_hits(enemies, grid, px, py)

    for w in WARMUP:
        _scan_hits(enemies, px, py)
    var t0: int = Time.get_ticks_usec()
    for it in ITERS:
        _scan_hits(enemies, px, py)
    var scan_us: float = float(Time.get_ticks_usec() - t0) / ITERS

    for w in WARMUP:
        _grid_hits(enemies, grid, px, py)
    t0 = Time.get_ticks_usec()
    for it in ITERS:
        _grid_hits(enemies, grid, px, py)
    var grid_us: float = float(Time.get_ticks_usec() - t0) / ITERS

    print("%d\t%.1f\t%.1f\tx%.2f\t%d/%d" % [n, scan_us, grid_us, scan_us / maxf(grid_us, 0.001), scan_hits, grid_hits])


func _scan_hits(enemies: Array, px: Array, py: Array) -> int:
    var hits: int = 0
    for p in px.size():
        for i in enemies.size():
            var e = enemies[i]
            if e.dead:
                continue
            var dx: float = e.x - px[p]
            var dy: float = e.y - py[p]
            var r: float = e.radius + PROJECTILE_RADIUS
            if dx * dx + dy * dy <= r * r:
                hits += 1
    return hits


func _grid_hits(enemies: Array, grid, px: Array, py: Array) -> int:
    var hits: int = 0
    for p in px.size():
        for j in grid.query_indices(px[p], py[p], PROJECTILE_RADIUS + SpatialGridScript.MAX_ENTITY_RADIUS):
            var e = enemies[j]
            if e.dead:
                continue
            var dx: float = e.x - px[p]
            var dy: float = e.y - py[p]
            var r: float = e.radius + PROJECTILE_RADIUS
            if dx * dx + dy * dy <= r * r:
                hits += 1
    return hits
