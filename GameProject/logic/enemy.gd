extends RefCounted
## ← js/enemy.js：M1 追击者与两两分离。

const EnemyBaseScript: GDScript = preload("res://logic/enemies/base.gd")
const SpatialGridScript: GDScript = preload("res://logic/systems/spatial_grid.gd")


static func create_chaser(x: float, y: float, elapsed: float = 0.0, options: Dictionary = {}):
    var merged: Dictionary = {"type": options.get("type", "chaser"), "rank": options.get("rank", "normal")}
    for key: Variant in options:
        merged[key] = options[key]
    return EnemyBaseScript.new(x, y, elapsed, merged)


## grid 可选（logic/systems/spatial_grid.gd）：传入时只查邻域候选索引，
## 查询窗口已按 MAX_ENTITY_RADIUS 外扩，重叠对不可能漏检；不传则保持原线性扫描。
static func separate_enemies(enemies: Array, dt: float, grid = null) -> void:
    var scale: float = minf(1.0, 60.0 * dt)
    for i in enemies.size():
        var a = enemies[i]
        if a.dead:
            continue
        var candidates = grid.query_indices(a.x, a.y, a.radius + SpatialGridScript.MAX_ENTITY_RADIUS) if grid != null else range(i + 1, enemies.size())
        for j in candidates:
            if j <= i:
                continue
            var b = enemies[j]
            if b.dead:
                continue
            var dx: float = b.x - a.x
            var dy: float = b.y - a.y
            var d2: float = dx * dx + dy * dy
            var min_d: float = a.radius + b.radius
            if d2 <= 0.0001 or d2 >= min_d * min_d:
                continue
            var distance: float = sqrt(d2)
            var push: float = ((min_d - distance) / distance) * 0.5 * scale
            a.x -= dx * push
            a.y -= dy * push
            b.x += dx * push
            b.y += dy * push
