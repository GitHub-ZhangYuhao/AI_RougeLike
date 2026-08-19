---
name: survival-crafting
description: >
  构建生存制作游戏：资源采集、物品栏、制作与科技树、生存需求（饥饿/口渴/温度）
  以及基地建设。适用于生存游戏或制作/基地建设游戏。
---

# 生存制作游戏

生存制作游戏开发指南——涵盖采集 → 制作 → 建造循环、生存需求、制作/科技成长和基地建设。
这是一项**组合式**技能：编排物品栏数据、世界内容、持久化和威胁。它不再重复讲解这些基础要素，
而是定义让生存体验紧张而非繁琐的循环和压力系统（需求、稀缺、升级）。

## 何时使用

- 玩家需要**采集资源、制作物品/结构、管理生存需求，并建设基地**来抵御不断升级的威胁时使用：
  生存沙盒、制作/基地建设游戏。
- 设计生存需求（饥饿/口渴/温度）、制作科技树、采集循环或基地放置/建设时使用。

**何时*不*使用：**制作只是 RPG 的次要功能 → `rpg`。永久死亡的网格地牢 →
`roguelike`。将物品栏/物品制成数据资产时使用 `godot-resources` /
`unity-scriptableobjects`；世界生成使用 `procedural-gen`。

## 核心循环

**采集原始资源 → 制作工具/物品 → 建设和升级基地 → 管理生存需求 →
前往更远处探索更优质的资源 → 熬过不断升级的威胁 → 在更高层级重复循环。**
每轮循环都应解锁*下一轮*循环（更好的工具 → 到达新生物群系 → 新资源 →
更好的制作品）。当这条阶梯断裂时，游戏就会变成重复刷取。

## 必备系统

1. **资源节点 + 采集**——可收获的世界对象；工具要求/层级；重生。
2. **物品栏**——堆叠、容量（槽位或重量）、丢弃/转移、快捷栏。
3. **制作**——配方（输入 → 输出）、制作站/科技门槛、科技树。
4. **生存需求**——饥饿、口渴、温度、耐力、生命值，以及衰减 + 后果。
5. **基地建设**——可放置结构、建造网格/吸附、储存设施、制作站。
6. **世界 + 昼夜**——生物群系/资源（通常程序化生成）；驱动威胁的时间循环。
7. **威胁**——不断升级的敌对生物/天气/事件；战斗或规避。
8. **保存/加载**——世界状态、物品栏、基地、需求、成长；大型世界持久化。

## 设计参数

| 参数 | 影响 | 说明 |
|------|--------|-------|
| 需求衰减速率 | 压力节奏 | 慢到足以探索，快到具有意义。 |
| 需求耗尽后果 | 风险 | 持续伤害，而非立即死亡。 |
| 资源稀缺度 / 重生 | 推动探索 | 基地附近资源稀缺 → 前往远处寻找。 |
| 工具层级 / 门槛 | 成长阶梯 | 更好的工具 → 新节点类型。 |
| 配方复杂度 / 科技深度 | 长期目标 | 采用多步链条，而非平铺列表。 |
| 物品栏限制（槽位/重量） | 物流压力 | 强迫玩家返回基地并使用储存设施。 |
| 威胁升级曲线 | 随时间增长的难度 | 夜晚/季节/事件逐级提升。 |
| 一天的长度 | 节奏 | 白天 = 采集，夜晚 = 防守。 |

## 模式

### 1. 带分级后果的需求衰减

```python
# Pseudocode in the per-frame/per-tick update. dt = seconds. Needs fall; failure bleeds HP.
def update_needs(p, dt):
    p.hunger = max(0, p.hunger - HUNGER_RATE * dt)
    p.thirst = max(0, p.thirst - THIRST_RATE * dt)
    p.temp   = approach(p.temp, ambient_temperature(p), TEMP_RATE * dt)

    # Consequences are graded, not binary: warnings, then attrition — never instant death.
    if p.hunger == 0 or p.thirst == 0:
        p.hp -= STARVE_DAMAGE * dt          # damage over time creates urgency with recovery room
    if p.temp < COLD_THRESHOLD or p.temp > HEAT_THRESHOLD:
        p.hp -= EXPOSURE_DAMAGE * dt
    if p.hunger > 0 and p.thirst > 0 and not exposed(p):
        p.hp = min(p.max_hp, p.hp + REGEN_RATE * dt)   # safe + fed => heal
```

### 2. 制作：先验证，再以原子方式消耗输入

```python
# Pseudocode. Recipes are data: inputs -> output, with an optional station/tech requirement.
recipe = {"id": "stone_axe",
          "inputs": {"wood": 3, "stone": 2}, "output": ("stone_axe", 1),
          "station": "workbench", "requires_tech": "basic_tools"}

def can_craft(recipe, inv, tech, station):
    if recipe.get("requires_tech") and recipe["requires_tech"] not in tech: return False
    if recipe.get("station") and recipe["station"] != station: return False
    return all(inv.count(item) >= n for item, n in recipe["inputs"].items())

def craft(recipe, inv, tech, station):
    if not can_craft(recipe, inv, tech, station): return False
    for item, n in recipe["inputs"].items(): inv.remove(item, n)   # consume all, then add
    inv.add(*recipe["output"])                                     # atomic: no partial craft
    return True
```

### 3. 由工具层级限制采集

```python
# Pseudocode. A node yields only if the held tool meets its required tier.
def harvest(node, tool):
    if tool.tier < node.required_tier:
        return notify("Need a better tool")        # e.g. stone node needs a pickaxe, not fists
    node.hp -= tool.power
    if node.hp <= 0:
        spawn_drops(node.drop_table)               # weighted drops (see roguelike loot pattern)
        node.start_respawn(node.respawn_time)      # node returns later; world isn't depleted forever
```

## 陷阱 / 失败模式

- **需求耗尽后立即死亡** → 导致挫败和读档作弊。让失败造成持续伤害，并提供清晰警告和恢复路径（模式 1）。
- **没有成长阶梯的刷取** → 采集永远无法解锁新的采集内容。每个层级都必须开启下一层
  （更好的工具 → 新节点 → 新资源 → 更好的制作品）。
- **非原子制作** → 边缘情况下输入已消耗但未获得输出。先验证，再将消耗和添加作为一步执行（模式 2）。
- **物品栏没有限制** → 没有物流压力，也不需要基地/储存设施。按槽位或重量设置上限。
- **世界资源永久耗尽** → 玩家搜刮完整张地图后离开游戏。让节点重生或让资源随时间再生。
- **逐帧衰减未按 `dt` 缩放** → 不同硬件上的需求消耗速度不同。按 `dt` 缩放。
- **大型世界没有存档 / 存档脆弱** → 一次崩溃毁掉数小时进度。增量持久化世界 + 基地 + 需求，
  并进行版本控制（参见 `save-systems`）。
- **威胁曲线平坦** → 后期没有压力。通过夜晚/季节/事件层级逐步升级。

## 组合方式（由以下技能构建）

- **将物品/配方制成数据：**`godot-resources` / `unity-scriptableobjects`——物品、配方、科技树、掉落表。
- **世界：**`procedural-gen` 用于生物群系/资源放置；`level-design` 用于手工区域。
- **持久化：**`save-systems` 用于大型世界状态、基地、物品栏、需求和版本控制。
- **威胁：**`game-ai` 用于生物；引擎物理技能用于近战/碰撞。
- **建造/放置：**`godot-tilemap` / `unity-tilemap-2d`（2D）或 `godot-3d-essentials`（3D），再加 UI 吸附。
- **UI：**`game-ui-ux` 用于物品栏/制作/HUD 布局和缩放；`godot-ui-control` 用于具体的物品栏、制作菜单、需求 HUD 和建造模式。

## 参考资料

- 有关完整需求模型和阈值、制作科技树图、采集/重生调整、基地建设网格和威胁升级，
  请阅读 `references/needs-and-crafting.md`。
