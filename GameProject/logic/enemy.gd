extends RefCounted
## ← js/enemy.js：M1 追击者与两两分离。

const EnemyBaseScript: GDScript = preload("res://logic/enemies/base.gd")


static func create_chaser(x: float, y: float, elapsed: float = 0.0, options: Dictionary = {}):
    var merged: Dictionary = {"type": options.get("type", "chaser"), "rank": options.get("rank", "normal")}
    for key: Variant in options:
        merged[key] = options[key]
    return EnemyBaseScript.new(x, y, elapsed, merged)


static func separate_enemies(enemies: Array, dt: float) -> void:
    var scale: float = minf(1.0, 60.0 * dt)
    for i in enemies.size():
        var a = enemies[i]
        if a.dead:
            continue
        for j in range(i + 1, enemies.size()):
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
