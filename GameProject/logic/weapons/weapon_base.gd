extends RefCounted
## ← js/weapons/base.js：武器公共状态与索敌/AoE 工具。

const UtilsScript: GDScript = preload("res://logic/utils.gd")

var card: Dictionary
var level: int = 1
var timer: float = 0.0
var world = null

var stats: Dictionary:
    get:
        return get_stats()


func _init(card_data: Dictionary) -> void:
    card = card_data


func get_stats() -> Dictionary:
    return card["levels"][level - 1]


func update(_dt: float, _current_world) -> void:
    pass


func _has_synergy(current_world: Dictionary, id: String) -> bool:
    var callback: Callable = current_world.get("has_synergy", Callable())
    return callback.is_valid() and callback.call(id)


static func nearest_enemy(enemies: Array, x: float, y: float, max_dist2: float = INF):
    var best = null
    var best_d2: float = max_dist2
    for enemy in enemies:
        if enemy.dead:
            continue
        var d2: float = UtilsScript.dist2(x, y, enemy.x, enemy.y)
        if d2 < best_d2:
            best = enemy
            best_d2 = d2
    return best


static func nearest_n(enemies: Array, x: float, y: float, n: int, max_dist2: float = INF) -> Array:
    var candidates: Array = []
    for enemy in enemies:
        if enemy.dead:
            continue
        var d2: float = UtilsScript.dist2(x, y, enemy.x, enemy.y)
        if d2 <= max_dist2:
            candidates.append({"enemy": enemy, "d2": d2})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d2"] < b["d2"])
    var result: Array = []
    for i in mini(n, candidates.size()):
        result.append(candidates[i]["enemy"])
    return result


static func hit_enemies_in_radius(current_world, x: float, y: float, radius: float, damage: float,
        on_hit: Callable = Callable(), damage_options: Dictionary = {}) -> int:
    var hits: int = 0
    for enemy in current_world.enemies:
        if enemy.dead:
            continue
        if UtilsScript.dist2(x, y, enemy.x, enemy.y) <= pow(radius + enemy.radius, 2):
            current_world.damage_enemy.call(enemy, damage, damage_options)
            if on_hit.is_valid():
                on_hit.call(enemy)
            hits += 1
    return hits
