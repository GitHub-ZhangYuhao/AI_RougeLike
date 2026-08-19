---
name: level-design
description: >
  设计与构建可玩关卡——从白模/灰盒到可玩的流程、玩家指标与网格布局、节奏与流（紧张/休息曲线）、门控机制及关键路径，以及遭遇设计。引擎无关的实践。当用户提及关卡设计、白模/灰盒/黑盒、关卡布局、关卡节奏、遭遇设计或关卡中的关键路径时使用此技能。
---

# 关卡设计

关卡是通过空间呈现的**一系列有意设计的体验**。优秀的关卡设计是一种*过程*：定义移动所构建的基础指标，使用基本几何体进行白模，试玩后再添加细节——绝不可颠倒顺序。这项技能是引擎无关的实践；请使用 `godot-tilemap`/`unity-tilemap-2d` 来布置 2D 网格和 3D 的网格地图。

## 何时使用

- 用于规划关卡结构：关键路径、节奏、门控机制、遭遇，以及玩家学习与被测试的位置。
- 使用 **白模 → 试玩 → 迭代 → 细化** 的工作流来构建一个在艺术存在之前就能良好运行的关卡。
- 用于从角色移动中推导关卡**指标**，确保几何体可到达且公平。

**何时*不*应使用：** 若要算法生成关卡，请使用 `procedural-gen`（创作设计与程序化设计是互补的）。对于引擎的瓷砖/网格绘制工具，请使用 `godot-tilemap` / `unity-tilemap-2d`。对于产生这些指标的移动能力，那是引擎的移动技能 + `input-systems`。

## 核心工作流

1. **首先推导指标。** 测量角色：最大跳跃高度和距离、奔跑速度、攻击范围、相机视野。每一个间隙、边缘和走廊都应以这些单位为尺寸标准。在构建几何体之前锁定它们。
2. **白模（灰盒/黑盒）。** 使用正确比例的非纹理基本体构建整个关卡。当变更成本低时，验证流程、视线范围和可达性。此时尚无艺术资产。
3. **定义关键路径**（起点 → 终点）以及你期望大多数玩家走的**黄金路径**。在其上分层可选或秘密路径。
4. **安排体验节奏。** 在 deliberate curve 中交替紧张与休息；不要进行战斗 - 战斗 - 战斗的循环。给予玩家喘息和预判的空间。
5. **先教学，后测试。** 在每个安全空间中引入每个机制，让玩家练习，然后在压力下进行测试。难度呈锯齿状上升，而非直线上升。
6. **有意门控。** 使用锁/钥匙、能力和单向跌落来控制顺序与节奏；利用光线、引导线和地标进行指引，而非墙壁。
7. **试玩并迭代。** 观察真实玩家：他们在哪里迷路、卡住、感到无聊或被不公平地击杀？修复白模问题；仅在玩法良好时才添加细节。

## 模式

### 1. 玩家指标驱动所有维度

```gdscript
# Measure the character ONCE, then size geometry in these units. If the jump
# changes, gaps must be re-derived — never eyeball reachability.
const RUN_SPEED      := 240.0   # px/s (or m/s in 3D)
const MAX_JUMP_H     := 96.0    # peak height of a full jump
const MAX_JUMP_DIST  := 200.0   # horizontal distance of a running jump
const SAFE_GAP       := MAX_JUMP_DIST * 0.7   # comfortable, not pixel-perfect
const HARD_GAP       := MAX_JUMP_DIST * 0.95  # a deliberate skill check
# Build platforms so required jumps use SAFE_GAP; reserve HARD_GAP for optional reward.
```
一个可到达的关卡源于诚实的指标。距离 `MAX_JUMP_DIST + 1` 放置的平台是不可能的；位于 `SAFE_GAP` 处的平台则是公平的。将这些常量放在关卡数据旁边，以便设计师和开发者达成一致意见。

### 2. 遭遇/节奏作为数据（紧张度时间线）

```gdscript
# Author the level as a sequence of beats with an intended intensity (0..1).
# This makes the pacing curve explicit and reviewable before you build rooms.
const BEATS := [
    { "room": "entry",      "type": "teach",   "intensity": 0.1 },
    { "room": "hall_1",     "type": "combat",  "intensity": 0.5 },
    { "room": "vista",      "type": "rest",    "intensity": 0.1 },  # breather + reward
    { "room": "gauntlet",   "type": "combat",  "intensity": 0.8 },
    { "room": "save_room",  "type": "rest",    "intensity": 0.2 },  # before the boss
    { "room": "boss",       "type": "climax",  "intensity": 1.0 },
]
# Read the intensity column top-to-bottom: it should rise overall but dip for rests
# (a sawtooth), never flatline high. Drive spawns/music intensity from this.
```
### 3. 门控与关键路径（一个小图）

```gdscript
# Model the level as rooms + gated connections. Validate that the goal is
# reachable with the keys/abilities the player can actually obtain in order.
const ROOMS := {
    "entry":   { "exits": [ { "to": "hall_1" } ] },
    "hall_1":  { "exits": [ { "to": "vista", "needs": "double_jump" },
                            { "to": "side_room" } ] },           # optional branch
    "side_room": { "exits": [ { "to": "hall_1" } ], "grants": "double_jump" },
    "vista":   { "exits": [ { "to": "boss", "needs": "red_key" } ] },
}
# Validation (do this!): from "entry", can the player reach "boss" given that
# "double_jump" is granted in "side_room" before "vista" requires it? A flood
# fill that only traverses an exit when its `needs` is already satisfiable
# proves the critical path isn't soft-locked.
```
## 陷阱

- **未试玩先细化。** 对未经验证的白模添加细节会浪费最昂贵的劳动在即将改变的布局上。应先灰盒并测试。
- **忽略指标的几何体：** 跳跃无法跨越的间隙、低于伸手可及范围的边缘、比相机所需更窄的走廊。一切应以玩家单位为尺寸标准。
- **平铺节奏。** 墙壁对墙壁的战斗（或墙壁对墙壁的平静）会让玩家麻木。交替紧张与休息；在高潮前放置一个喘息点和存档点。
- **教学前先测试机制。** 玩家在致命地点首次遭遇危险。应安全引入，让玩家练习后再进行测试。
- **软锁定和死胡同。** 门控需要仅在通过该门后才能获得的技能/钥匙。验证关键路径的钥匙/能力顺序，而不仅仅是连通性。
- **缺乏可读性与指引。** 当没有任何东西吸引视线时玩家会迷路。利用光线、引导线、颜色和地标来指向路径。
- **无标记的单向跌落**会让或惊吓玩家。预告不可逆的移动。
- **混淆程序化与创作设计。** 生成提供多样性，而非创作的节奏感。使用 `procedural-gen` 获取多样性；手动创作以实现意图。

## 引用

- `references/pacing-and-flow.md` —— 深入探讨难度/紧张度曲线、教学循环设计（引入→发展→转折→测试）、可读性与指引技巧、2D vs 3D 布局考量，以及白模审查清单。

## 相关技能

- `godot-tilemap`, `unity-tilemap-2d` —— 绘制 2D 关卡网格；3D 使用网格地图。
- `procedural-gen` —— 生成多样性以补充创作结构。
- `game-ai` —— 让敌人导航你构建的空间。
- `platformer`, `puzzle`, `roguelike` —— 由本技能构成的游戏类型。
