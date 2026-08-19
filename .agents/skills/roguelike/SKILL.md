---
name: roguelike
description: >
  构建 Roguelike：回合制网格移动、程序化地牢、永久死亡、视野和掉落表。
  适用于 Roguelike/Roguelite，或采用程序化关卡的回合制网格地牢探索游戏。
---

# Roguelike

Roguelike 开发指南——涵盖回合引擎、程序化地牢、视野、永久死亡和单局经济。
这是一项**组合式**技能：将程序化生成、瓦片地图、存档处理和 AI 编排成局制游戏。
它不再重复讲解噪声/RNG 或瓦片地图 API，而是定义让一*局*游戏引人入胜的循环和系统。

## 何时使用

- 构建**回合制、网格制**地牢探索游戏，每次死亡都会结束本局并重新生成世界时使用——
  Roguelike 或带局外成长的“Roguelite”。
- 设计程序化地牢、FOV/战争迷雾、永久死亡风险或掉落表时使用。

**何时*不*使用：**仅套用 Roguelike *外观*的实时动作游戏 → 构建动作类型
（`platformer`/`fps-shooter`）并叠加 `procedural-gen`。没有永久死亡而专注深度属性/任务/对话 →
`rpg`。开放世界需求/制作 → `survival-crafting`。

## Roguelike 的构成要素（设计锚点）

社区参考标准是 **Berlin Interpretation**（RogueBasin，IRDC 2008）：它是一组“类 Rogue 程度”
因素，而不是核对清单。其中价值较高的因素可作为设计目标：**随机环境生成、永久死亡、回合制、
网格制、非模态**（所有行动处于同一模式）、**复杂性**（大量物品/怪物交互）、**资源管理**、
**砍杀**以及**探索与发现**。强化这些因素会更具 Roguelike 感；应有意识地选择要保留的因素。
“Roguelite”通常通过局外成长放宽永久死亡。

## 核心循环

**执行一回合（移动 / 战斗 / 使用）→ 世界结算其回合 → 查看新状态 → 深入 / 搜刮 / 生存 →
死亡并在全新地牢中重新开始。**可重玩性来自每局*世界*的变化，而非玩家记住固定布局。

## 必备系统

1. **回合调度器**——能量/先攻系统，使高速单位更频繁行动（模式 2）。
2. **网格地图 + 移动**——瓦片坐标；碰撞即攻击；阻挡/可行走查询。
3. **程序化地牢生成器**——房间 + 走廊，或 BSP/元胞方法；保证连通性。
4. **视野 + 已探索记忆**——当前可见与曾经见过的区域（模式 3 / 参考资料）。
5. **战斗 + 实体**——HP、攻击/防御、状态；怪物与玩家遵循相同规则。
6. **战利品 + 掉落表**——按权重和深度缩放的物品/怪物生成（参考资料）。
7. **永久死亡 +（可选）局外成长**——清空本局；只保留解锁项/分数。
8. **消息日志 + 清晰 UI**——玩家根据文本/状态推理；显示数值和事件。

## 设计参数

| 参数 | 影响 | 说明 |
|------|--------|-------|
| 地牢大小 / 房间数量 | 单局时长、密度 | 随深度扩展。 |
| 连通性保证 | 避免不可达房间 | 生成后始终验证可达性。 |
| 怪物密度 / 深度曲线 | 难度增长 | 按深度加权表生成。 |
| 战利品稀有度权重 | 强度方差 | 越稀有，波动越大；鉴定机制增加发现感。 |
| FOV 半径 / 照明 | 紧张感、信息量 | 半径越小越恐怖，节奏越慢。 |
| 资源稀缺度（食物/HP/弹药） | 深入压力 | 经典 RL 的核心张力杠杆。 |
| 永久死亡与局外成长 | 单局风险与留存的取舍 | Roguelite 会缓和门槛。 |
| 鉴定 / 未知物品 | 探索价值 | 未鉴定物品鼓励试验。 |
| 可设种子的 RNG | 每日挑战、调试 | 始终允许固定种子（参见 `procedural-gen`）。 |

## 模式

### 1. 确定性、可设种子的单局 RNG

```python
# Pseudocode. One seeded RNG per run makes dungeons reproducible (daily runs, bug repro).
run_seed = chosen_seed or random_seed()
rng = Rng(run_seed)                 # use your engine's seedable RNG, not global random
dungeon = generate_dungeon(rng, depth)   # same seed + depth => same dungeon
# Persist run_seed in the save so a crash can resume the same world (see save-systems).
```

### 2. 基于能量的回合调度器（速度各异）

```python
# Pseudocode. Each actor gains energy each tick and acts when it has enough.
# Faster actors gain more per tick, so they act more often — no fixed "player then enemies".
TURN_COST = 100
def next_actor(actors):
    while True:
        for a in actors:                 # stable order avoids ties favoring one side
            a.energy += a.speed          # e.g. speed 100 = normal, 150 = hasted
            if a.energy >= TURN_COST:
                a.energy -= TURN_COST
                return a                 # this actor takes exactly one action now
```

### 3. 视野 + 已探索记忆

```python
# Pseudocode. Recompute visibility from the player each time they move.
visible = compute_fov(map, player.pos, radius=8)   # symmetric shadowcasting (see refs)
for cell in visible:
    explored.add(cell)                  # remember it forever (dim "fog of war")
# Render: visible -> lit; explored-but-not-visible -> dim; never-seen -> hidden.
```

使用成熟的 FOV 算法（递归阴影投射或对称阴影投射）。不要自行采用逐单元格的朴素射线检测——
它会产生不对称、“闪烁”的视野。参见参考资料。

## 陷阱 / 失败模式

- **地牢不连通** → 出现玩家无法抵达的房间。始终执行连通性/洪水填充检查，
  并开凿走廊，直至每个可行走单元格都可达。
- **朴素 FOV** → 视野闪烁或不对称（你能看到对方，对方却看不到你）。使用阴影投射；测试对称性。
- **伪装成回合制的实时循环** → 输入竞争和重复移动。每次结算一个离散回合；输入排队。
- **难度平坦** → 缺乏深入压力。按深度缩放怪物/战利品，并保持资源稀缺。
- **永久死亡清除了局外解锁** → 令人沮丧。保存时分离*单局*状态（清空）与*档案*状态
  （解锁项、分数）（参见 `save-systems`）。
- **在“永久死亡”游戏中读档作弊** → 若要真正的永久死亡，应在加载时删除或作废单局存档；
  只保留档案。
- **状态难以理解** → 玩家无法规划。显示 HP、回合结果和消息日志。

## 组合方式（由以下技能构建）

- **生成：**`procedural-gen`（噪声、带种子 RNG、地牢/房间算法）——可重玩性的引擎。
- **地图渲染：**`godot-tilemap` / `unity-tilemap-2d` 用于网格；`level-design` 用于特殊房间/宝库。
- **敌人：**`game-ai` 用于怪物决策（网格中通常很简单：追击/逃跑/巡逻）。
- **持久化：**`save-systems` 用于继续单局、档案/局外成长和真正的永久死亡清档。
- **脚本/数据：**`godot-resources` / `unity-scriptableobjects` 将物品、怪物和掉落表定义为数据。
- **UI：**`godot-ui-control` 用于消息日志、物品栏和 HUD。
- **手感：**`game-feel` 用于命中/死亡表现——通过屏幕震动和命中停顿强化回合制网格中的冲击感。

## 参考资料

- 有关地牢生成算法（房间与走廊、BSP、元胞自动机、连通性）、FOV（阴影投射）
  以及加权战利品/生成表，请阅读 `references/generation-fov-loot.md`。
