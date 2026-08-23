extends RefCounted
## ← js/weapons/base.js：武器公共状态与索敌/AoE 工具。

const UtilsScript: GDScript = preload("res://logic/utils.gd")
const SpatialGridScript: GDScript = preload("res://logic/systems/spatial_grid.gd")

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


## 空间网格优化版：通过 grid 查询局部候选集，把 O(N) 降到 O(k)（k=局部邻居数）。
## 用于 ring/cloak/trail 等范围伤害武器，避免每武器每帧全量扫描敌人。
static func hit_enemies_in_radius_optimized(current_world, x: float, y: float, radius: float, damage: float,
		on_hit: Callable = Callable(), damage_options: Dictionary = {}, grid = null) -> int:
	if grid == null:
		return hit_enemies_in_radius(current_world, x, y, radius, damage, on_hit, damage_options)
	var hits: int = 0
	var candidates: Array = grid.query_entities(x, y, radius + SpatialGridScript.MAX_ENTITY_RADIUS, current_world.enemies)
	for enemy in candidates:
		if enemy.dead:
			continue
		if UtilsScript.dist2(x, y, enemy.x, enemy.y) <= pow(radius + enemy.radius, 2):
			current_world.damage_enemy.call(enemy, damage, damage_options)
			if on_hit.is_valid():
				on_hit.call(enemy)
			hits += 1
	return hits
