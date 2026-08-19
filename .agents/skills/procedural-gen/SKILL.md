---
name: procedural-gen
description: >
  生成游戏内容——带种子的确定性随机数发生器，用于地形和高度图的 Perlin/Simplex 噪声值、网格迷宫生成（房间 + 走廊、BSP、随机游走），以及加权掉落表；这些为引擎无关算法。当用户提及程序化生成、Perlin/Simplex 噪声、随机种子、迷宫生成器、高度图/地形或掉落表时使用此技能。
---

# 程序化生成

基于紧凑规则和种子生成关卡、地形和物品。优秀的程序生成的核心贯穿线是**确定性**：单个种子能复现相同的世界，因此错误可重复出现且玩家可以分享种子。本技能掌握核心算法——噪声、带种子的随机数发生器、迷宫布局、加权表；`roguelike` 和 `survival-crafting` 等流派依赖它进行消费。

## 何时使用

- 用于生成地图、迷宫、地形高度图、物品掉落或任何您不希望手动创作的内容。
- 当结果必须**从种子复现**时使用（调试、每日挑战、可分享的世界）。
- 用于选择加权随机结果（物品稀有度、刷怪表）。

**何时*不*使用：** 若需引擎的瓦片 API *绘制*结果，请使用 `godot-tilemap` 或 `unity-tilemap-2d`。若要路由 AI 穿过生成的地图，请使用 `game-ai`。对于精心设计的节奏关卡，请使用 `level-design`——程序化生成与人工设计是互补关系，而非可互换关系。

## 核心工作流

1. **掌控您的随机性。** 创建一个带种子的 RNG 实例并传递给所有地方。不要在生成代码中调用全局/静态随机数发生器——这会使结果不可复现且依赖顺序。
2. **根据内容选择技术。** 连续地形/高度图 → 噪声算法。离散房间/走廊 → 空间分割或基于代理的雕刻。具有稀有度的结果 → 加权表。
3. **先生成到普通数据网格/数组中**，与渲染解耦。生成过程填充 `int[][]` 或字典；随后进行单独的绘制步骤。
4. **在将结果交付给玩家之前验证。** 每个房间是否可达？出生点是否安全？是否有通往出口的路径？拒绝或修复失败的布局；不要让玩家面对破碎的地图。
5. **固定种子进行调整**，以便每次参数变更都能独立可见，然后遍历多个种子以检查分布情况，而不仅仅是依赖一张幸运地图。

## 模式

### 1. 带种子的确定性随机数发生器（基础）

```python
import random
rng = random.Random(seed)        # a dedicated instance — NOT the global random.*
room_count = rng.randint(5, 12)  # same seed -> same sequence, every run
# RIGHT: thread `rng` through every function that makes a choice.
# WRONG: calling random.randint(...) (global state) — order-dependent, unseedable.
```
引擎等价实现：Godot `var rng = RandomNumberGenerator.new(); rng.seed = s`; Unity `var rng = new System.Random(seed)`（或 `UnityEngine.Random.InitState`）。将种子存储在存档文件中，以便世界可重新生成。

### 2. 用于高度图的分形 (fBm) 噪声

```python
# Sum several octaves: each higher octave has higher frequency, lower amplitude.
def fbm(noise, x, y, octaves=5, lacunarity=2.0, gain=0.5):
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for _ in range(octaves):
        total += amp * noise(x * freq, y * freq)   # noise() returns ~0..1
        norm  += amp                                # track total amplitude
        amp   *= gain                               # each octave contributes less
        freq  *= lacunarity                         # ...at a higher frequency
    return total / norm                             # normalize back into 0..1

# Redistribute to carve flat valleys / sharpen peaks: higher exp -> more lowland.
elevation = pow(fbm(noise, nx, ny), 2.2)
```
使用真实的噪声库（`FastNoiseLite`, `opensimplex`, `Unity.Mathematics.noise`, 或 `Mathf.PerlinNoise`）——不要自己实现梯度噪声。**为高程和湿度分别设置不同的种子**，这样基于两个字段的生物群系查找才不会完全相关。完整的生物群系查找和岛屿塑形在 `references/noise.md` 中。

### 3. 加权物品掉落表（稀有度校正选择）

```python
# Roll proportional to weight: common drops far more often than legendary.
def weighted_pick(rng, table):           # table: list of (item, weight)
    total = sum(w for _, w in table)
    roll = rng.uniform(0, total)          # a point on the cumulative line
    upto = 0.0
    for item, w in table:
        upto += w
        if roll < upto:                   # first bucket the roll falls into
            return item
    return table[-1][0]                   # float-safety fallback

loot = weighted_pick(rng, [("common", 70), ("rare", 25), ("legendary", 5)])
```
权重无需求和为 100——它们是相对的。为防止坏运气连击，使用“保底”/背包系统（见 `references/dungeon-generation.md` 中关于分布的说明）。

### 4. 房间与走廊迷宫 (草图)

```python
# 1. Place non-overlapping rooms; 2. connect them; 3. carve into the grid.
rooms = []
for _ in range(attempts):
    r = Rect(rng.randint(1, W-w-1), rng.randint(1, H-h-1), w, h)
    if not any(r.intersects(o.expand(1)) for o in rooms):  # keep a 1-tile gap
        rooms.append(r)
for a, b in zip(rooms, rooms[1:]):       # connect each room to the next
    carve_l_corridor(grid, a.center, b.center, rng)   # horizontal then vertical
```
完整的生成器（BSP 分割、L-走廊、可达性检查以及随机游走洞穴）在 `references/dungeon-generation.md` 中。

## 陷阱

- **使用全局 RNG**：在生成过程中会导致世界不可复现，且一旦调用顺序改变就会出错。始终传递带种子的实例。
- **相关噪声场**：从*相同*的种子/偏移采样高程和湿度会产生成带状排列的生物群系。对每个字段进行偏移或重新设置种子。
- **八度频伪影**：累加八度频而不归一化会将值推离 `0..1` 范围；除以求和振幅（并注意库的输出范围——有些返回 `-1..1`，有些为 `0..1`）。
- **无连通性检查**：房间或洞穴可能会变得孤立。从出生点执行泛洪填充并在游戏前丢弃/重连不可达区域。
- **无界放置循环**：“尝试直到 N 个房间合适”在小网格上可能无限旋转。限制尝试次数并接受较少的房间数量。
- **一次性全局设置种子，然后依赖帧时间**：任何非确定性输入（时间、物理、哈希随机化）泄漏到生成过程中都会破坏复现性。

## 引用

- `references/noise.md` —— 八度频/lacunarity/gain、重新分布、岛屿塑形、双轴生物群系查找、蓝噪声对象散射。
- `references/dungeon-generation.md` —— BSP、房间 + 走廊、随机游走洞穴、细胞自动机平滑、连通性验证、分布/保底表。

## 相关技能

- `godot-tilemap`, `unity-tilemap-2d`——将生成的网格绘制到引擎中。
- `game-ai`——在生成图上进行寻路。
- `level-design`——程序化生成补充的节奏和人工结构。
- `roguelike`, `survival-crafting`——组合此技能的游戏流派。
