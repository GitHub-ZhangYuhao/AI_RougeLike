---
name: unity-tilemap-2d
description: >
  在 Unity 6.3 LTS 中构建 2D 瓦片地图并编写脚本：Grid + Tilemap 组件、Tile Palette、
  瓦片地图碰撞体、规则瓦片以及运行时 SetTile/GetTile 绘制。适用于绘制瓦片关卡、
  添加 TilemapCollider2D、使用规则或动画瓦片、通过代码生成瓦片地图，或用户提到
  Unity tilemap、tile palette、rule tile 或 Grid 时。
---

# Unity 2D Tilemap

在 Unity 6.3 LTS 中使用 `Grid`/`Tilemap` 系统、Tile Palette、碰撞体和运行时绘制功能，
创作基于瓦片的 2D 关卡并编写脚本。面向 **Unity 6.3 LTS (6000.3)**。

> **包说明：**核心 Tilemap（`Grid`、`Tilemap`、`Tile`、`TilemapCollider2D`）内置于 Unity。
> **Rule Tiles、Animated Tiles 和 Tile Palette 笔刷位于单独的“2D Tilemap Extras”包
>（`com.unity.2d.tilemap.extras`）中**——使用 `RuleTile` 前请通过 Package Manager 安装它。

## 何时使用

- 适用于通过绘制瓦片布置 2D 关卡、设置 `Grid` + `Tilemap`、为地图添加碰撞、
  使用自动拼接的 Rule Tiles，或通过脚本生成/编辑瓦片时。
- 适用于场景包含带 `Tilemap` 子对象的 `Grid`，或包含 `*.asset` 瓦片/调色板文件时。

**何时不应使用：***关卡设计*实践（节奏、灰盒、布局原则）→ `level-design`。
3D 瓦片/网格放置 → Unity 自身的 3D 工具（ProBuilder / grid brushes；此处没有专用技能）。
在瓦片上移动的平台跳跃角色 → `platformer` / `unity-physics`。

## 核心工作流

1. **创建网格：**GameObject → 2D Object → Tilemap → Rectangular。这会创建一个 `Grid`，
   其子对象为 `Tilemap`（和 `TilemapRenderer`）。每层使用一个 Tilemap（背景、地面、前景），
   并设置每个 Renderer 的排序。
2. **打开 Tile Palette**（Window → 2D → Tile Palette），拖入切片后的精灵表以创建
   `Tile` 资源，然后使用笔刷工具绘制。
3. **为实体层添加碰撞：**`TilemapCollider2D`。如需单个合并的碰撞体（开销低得多且无缝隙），
   还需添加 `CompositeCollider2D`（以及设置为 **Static** 的 `Rigidbody2D`），并在
   Tilemap Collider 上启用 *Used By Composite*。
4. **使用 Rule Tiles 自动拼接**（2D Tilemap Extras），使边缘/角落自动选择正确的精灵，
   而不必手动放置每个变体。
5. **在运行时通过脚本编辑**，使用单元格坐标（`Vector3Int`）：`SetTile`、`GetTile`、
   `SetTilesBlock`，并通过 `Grid`/`Tilemap` 在世界坐标与单元格坐标间转换。
6. **在 Play 模式下验证**：确认碰撞（Physics Debugger）、排序顺序，以及批量编辑后
   `RefreshAllTiles` 已运行。

## 模式

### 1. 在运行时绘制瓦片（单元格坐标）

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;

public class TilePainter : MonoBehaviour
{
    [SerializeField] private Tilemap tilemap;   // assign the target Tilemap
    [SerializeField] private TileBase groundTile;

    // World position -> cell, then place a tile.
    public void PaintAt(Vector3 worldPos)
    {
        Vector3Int cell = tilemap.WorldToCell(worldPos);
        tilemap.SetTile(cell, groundTile);
    }

    public bool IsSolid(Vector3 worldPos)
        => tilemap.GetTile(tilemap.WorldToCell(worldPos)) != null;
}
```

### 2. 批量填充区域（比逐单元格 `SetTile` 更快）

```csharp
// SetTilesBlock writes a whole BoundsInt in one call — use it for procedural rooms/floors.
public void FillFloor(Tilemap map, TileBase tile, int width, int height)
{
    var bounds = new BoundsInt(0, 0, 0, width, height, 1);
    var tiles  = new TileBase[width * height];
    for (int i = 0; i < tiles.Length; i++) tiles[i] = tile;
    map.SetTilesBlock(bounds, tiles);
}
```

### 3. 清除与刷新

```csharp
tilemap.SetTile(cell, null);   // null erases the tile at that cell
tilemap.RefreshTile(cell);     // re-evaluate just this cell's rule/animated neighbors (cheap)
// RefreshAllTiles() re-evaluates the ENTIRE map — reserve it for full regenerations, not per-edit.
```

## 常见陷阱

- **找不到 `RuleTile` 类型**——它不是内置类型。请通过 Package Manager 安装
  **2D Tilemap Extras** 包（`com.unity.2d.tilemap.extras`）。
- **每个瓦片一个碰撞体会严重影响性能/留下接缝**——添加带静态 `Rigidbody2D` 的
  `CompositeCollider2D`，并启用 *Used By Composite*，将整层合并成一个平滑形状。
- **混淆世界坐标与单元格坐标**——`SetTile`/`GetTile` 接收 `Vector3Int` *单元格*，
  而不是世界位置。始终使用 `WorldToCell` / `CellToWorld` 转换。
- **瓦片意外渲染在精灵后方/前方**——设置每个 `TilemapRenderer` 的 Sorting Layer 和
  Order in Layer；多个 Tilemap 需要显式排序。
- **脚本编辑后规则/动画瓦片不更新**——写入后刷新，但少量编辑应优先使用定向的
  `RefreshTile(cell)`；`RefreshAllTiles()` 会重新计算地图上的每个瓦片，并导致大型关卡卡顿。
  仅在重新生成整张地图时执行完整刷新。
- **绘制到错误的层**——Tile Palette 中的活动目标 Tilemap 决定绘制位置；
  请检查“Active Tilemap”下拉框。

## 参考资料

- 主要文档：Unity Manual“Tilemaps”
  （`https://docs.unity3d.com/Manual/tilemaps/work-with-tilemaps/tilemap-reference.html`）、
  `ScriptReference/Tilemaps.Tilemap`，以及有关 Rule Tiles 的 2D Tilemap Extras 包手册
  （`https://docs.unity3d.com/Packages/com.unity.2d.tilemap.extras@1.6/manual/index.html`）。

## 相关技能

- `level-design`——与引擎无关的灰盒、节奏和瓦片布局实践。
- `procedural-gen`——生成提供给 `SetTilesBlock` 的瓦片数据（噪声、RNG、地下城）。
- `platformer` / `roguelike`——将本技能与移动和生成组合的游戏类型。
