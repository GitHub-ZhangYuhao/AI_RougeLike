---
name: godot-tilemap
description: >
  使用 TileMapLayer 和 TileSet 在 Godot 4.7 中构建和编辑基于图块的 2D 关卡：
  绘制图层，为图块设置碰撞/导航/自定义数据，使用地形集自动铺设图块，并通过代码
  读写单元格（set_cell、get_cell_tile_data、local_to_map）。适用于使用 TileMapLayer
  节点、.tres TileSets、自动铺设图块，或将已弃用的 TileMap 节点迁移到 TileMapLayer。
---

# Godot TileMap (4.7 TileMapLayer)

使用 `TileMapLayer` + `TileSet` 创建基于图块的关卡，添加逐图块碰撞和自定义数据，
通过地形自动铺设图块，并在运行时操作单元格。目标版本为 **Godot 4.7**，其中
`TileMapLayer` 取代了现已弃用的 `TileMap` 节点。

## 何时使用

- 适用于通过图块网格设计 2D 关卡、配置 `TileSet`（碰撞、导航、自定义数据、地形），
  或通过代码读写图块。
- 适用于将 `TileMap` 节点（单个节点、多个图层）迁移为多个 `TileMapLayer` 节点
  （每个节点一个图层）。

**不适用的情况：** 让玩家在图块上移动 → `godot-2d-movement`；通用物理体/射线检测 →
`godot-physics`；程序化地图_生成_算法 → `procedural-gen`；关卡_设计_实践 → `level-design`。

## 核心工作流

1. **添加 `TileMapLayer` 节点**（每个视觉/逻辑图层一个：背景、墙壁、前景）。每个节点只保存
   一个图块图层。
2. **在图层的 `tile_set` 属性上创建或分配 `TileSet`。** 在 TileSet 编辑器中添加图集源
   （切割为图块的纹理）。将 TileSet 保存为外部 `.tres`，以供多个图层/关卡复用。
3. **在 TileSet 编辑器中添加图块数据：** 物理层（碰撞多边形）、导航层、遮挡，以及
   **自定义数据层**（类型化的逐图块值，如 `damage` 或 `is_ladder`）。
4. **在 TileMap 底部面板中绘制**（Paint/Line/Rectangle/Bucket）。对于自动连接的图块，
   定义**地形集**并使用 Connect/Path 模式绘制。
5. **通过图层的 `collision_enabled` / `navigation_enabled` 属性启用逐层碰撞/导航。**
6. **通过代码读写：** 使用 `local_to_map`、`set_cell`、`get_cell_source_id`，以及
   `get_cell_tile_data(...).get_custom_data(...)`。

## 模式

### 1. 将鼠标位置转换为单元格并读取其自定义数据

```gdscript
extends TileMapLayer

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        # local_to_map expects local coords; convert from global first.
        var cell := local_to_map(to_local(event.position))
        var data := get_cell_tile_data(cell)   # TileData or null
        if data:
            var dmg: int = data.get_custom_data("damage")  # custom data layer
            print("Cell %s deals %d damage" % [cell, dmg])
```

### 2. 在运行时放置和擦除图块

```gdscript
# set_cell(coords, source_id, atlas_coords, alternative_tile = 0)
func place_wall(cell: Vector2i) -> void:
    set_cell(cell, 0, Vector2i(2, 1))   # source 0, atlas tile at column 2, row 1

func dig(cell: Vector2i) -> void:
    erase_cell(cell)                    # same as set_cell(cell, -1)

func clear_level() -> void:
    clear()                             # remove every tile on this layer
```

### 3. 使用地形集自动铺设区域

```gdscript
# Paint a filled area with terrain `terrain` of terrain set `terrain_set`;
# Godot picks the correct edge/corner tiles to connect them.
func fill_with_grass(cells: Array[Vector2i]) -> void:
    var terrain_set := 0
    var grass_terrain := 0
    set_cells_terrain_connect(cells, terrain_set, grass_terrain, true)
```

### 4. 遍历已放置图块（例如查找所有出生图块）

```gdscript
func find_spawns() -> Array[Vector2i]:
    var spawns: Array[Vector2i] = []
    for cell in get_used_cells():
        var data := get_cell_tile_data(cell)
        if data and data.get_custom_data("is_spawn"):
            spawns.append(cell)
    return spawns
```

## 常见陷阱

- **`TileMap` 节点在 4.3 中已弃用。** 使用 `TileMapLayer` 节点（每个节点一个图层）；
  将它们归组到父 `Node2D` 下。旧 `TileMap` 中接收 `layer` 参数的调用
  （`set_cell(layer, ...)`）不适用于 `TileMapLayer`。
- **`local_to_map` 需要局部坐标。** 必须先使用 `to_local(...)` 转换鼠标/全局位置，
  否则单元格会发生偏移。
- 对于空单元格或非图集源，**`get_cell_tile_data` 返回 `null`**——在调用
  `get_custom_data` 前始终进行 null 检查。
- **自定义数据带有类型。** 声明为 `int` 的层会返回 `int`；按错误类型读取或引用不存在的层名
  会报错。请先在 TileSet 中定义该层。
- **地形需要定义每一种组合。** 如果 TileSet 的地形位掩码相邻关系不完整，
  `set_cells_terrain_connect` 会产生异常结果。
- **运行时编辑会批处理到帧末。** 如果必须在 `set_cell` 后立即读取更新后的内部状态，请调用
  `update_internals()`（开销很大——避免在循环中使用）。
- **碰撞不工作？** 检查图层的 `collision_enabled`、图块是否具有含多边形的物理层，
  以及 TileSet 的物理层遮罩是否与你的物理体匹配。

## 参考资料

- 关于 TileSet 设置（图集源、物理/导航/自定义数据层、地形位掩码）、场景图块、Y 排序，
  以及运行时图块数据重写（`_use_tile_data_runtime_update`），请阅读
  `references/tileset-and-terrains.md`。

## 相关技能

- `godot-2d-movement` — 在这些图块上行走的角色。
- `godot-physics` — 图块碰撞所参与的碰撞层/遮罩。
- `procedural-gen` — 通过噪声/RNG 生成 tilemaps。
- `level-design` / `roguelike` — 设计实践和基于网格的游戏类型。
