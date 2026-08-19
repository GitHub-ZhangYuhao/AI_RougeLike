extends RefCounted
## Godot 侧新增：空间网格索引，碰撞检测与敌人分离用格子候选替代 O(n) 线性扫描。
## 实体只登记中心点所在格子；查询侧把窗口半径扩大 MAX_ENTITY_RADIUS，
## 任何可能相交（中心距 <= 半径之和）的实体必然落入查询窗口，调用方再做精确距离判定。
## 约束：参与实体半径不得超过 MAX_ENTITY_RADIUS（当前最大敌人为 boss 半径 34）。

const CELL_SIZE: float = 128.0
const MAX_ENTITY_RADIUS: float = 40.0

var _cells: Dictionary = {}


func rebuild(entities: Array) -> void:
    _cells.clear()
    for i in entities.size():
        var entity = entities[i]
        if entity.dead:
            continue
        var key: int = _cell_key(entity.x, entity.y)
        if _cells.has(key):
            _cells[key].append(i)
        else:
            _cells[key] = [i]


## 返回窗口内所有格子中的实体索引，升序去重（与线性扫描的遍历顺序一致）。
func query_indices(x: float, y: float, radius: float) -> Array:
    var min_cx: int = floori((x - radius) / CELL_SIZE)
    var max_cx: int = floori((x + radius) / CELL_SIZE)
    var min_cy: int = floori((y - radius) / CELL_SIZE)
    var max_cy: int = floori((y + radius) / CELL_SIZE)
    var result: Array = []
    for cx in range(min_cx, max_cx + 1):
        for cy in range(min_cy, max_cy + 1):
            var bucket = _cells.get(_pack(cx, cy))
            if bucket != null:
                result.append_array(bucket)
    result.sort()
    return result


static func _cell_key(x: float, y: float) -> int:
    return _pack(floori(x / CELL_SIZE), floori(y / CELL_SIZE))


## 双 int32 打包成单一 int64 键，cx/cy 在 int32 范围内是双射。
static func _pack(cx: int, cy: int) -> int:
    return ((cx & 0xFFFFFFFF) << 32) | (cy & 0xFFFFFFFF)