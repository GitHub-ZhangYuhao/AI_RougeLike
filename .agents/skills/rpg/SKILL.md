---
name: rpg
description: >
  构建 RPG：属性与升级、物品栏与装备、任务、分支对话、保存/加载和战斗。
  适用于 RPG/JRPG，或设计属性、物品栏、任务或战斗系统。
---

# RPG

角色扮演游戏开发指南——涵盖属性与成长、物品栏/装备、任务、对话和战斗。
这是一项**组合式**技能：将数据驱动内容、对话和存档结合起来。它不再重复讲解这些基础要素，
而是定义让成长与选择富有意义的系统，并指向实现各部分的技能。

## 何时使用

- 构建 RPG/JRPG/动作 RPG 时使用：玩家拥有**会成长的属性**、**物品栏**、
  **任务**、**对话**和持久进度。
- 设计升级曲线、伤害公式、物品栏/装备模型或任务状态机时使用。

**何时*不*使用：**没有持久角色的永久死亡地牢单局 → `roguelike`。
纯对话/分支故事 → `visual-novel`。开放世界需求/制作/基地建设 →
`survival-crafting`。对话引擎本身请使用 `dialogue-systems`。

## 核心循环

**探索 → 遭遇（战斗 / 交谈 / 解谜）→ 获得奖励（XP、战利品、剧情）→ 成长
（升级、提升装备、解锁）→ 挑战更难的内容。**其幻想核心是*变得更强并塑造自己的角色*；
每个系统都应服务于成长与选择循环。

## 必备系统

1. **属性 + 升级**——基础属性、派生战斗属性、XP 曲线、升级收益。
2. **物品栏 + 装备**——数据定义的物品、堆叠、槽位、属性修正。
3. **战斗**——回合制或动作制；伤害公式、状态效果、胜负。
4. **任务**——目标、状态机（可接→进行中→完成→已交付）、奖励。
5. **对话**——分支台词、基于游戏状态的条件、真正有影响的选择。
6. **保存/加载**——持久化角色、物品栏、任务进度、世界标记，并支持版本控制。
7. **经济 + 成长门槛**——金币/商店；以等级/任务/区域限制强度。
8. **UI**——HUD、物品栏、任务日志、对话框、角色面板。

## 设计参数

| 参数 | 影响 | 说明 |
|------|--------|-------|
| XP 曲线形状 | 强度成长节奏 | 前期快，后期慢（参见参考资料）。 |
| 属性→派生值缩放 | 构筑多样性 | 不应由单一属性主导。 |
| 伤害公式 | 战术手感 | 减法减伤与比例减伤（参见参考资料）。 |
| 随机浮动 / 暴击 | 波动性 | ±10% 和约 1.5× 暴击是安全默认值。 |
| 掉率 / 经济 | 奖励频率 | 避免战利品让商店失去意义。 |
| 强度门槛 | 难度门槛 | 等级/区域/任务锁定。 |
| 可逆修正 | 增益/装备正确性 | 分层应用修正；绝不修改基础属性。 |
| 选择后果 | 角色扮演分量 | 任务/对话标记应产生不同结果。 |

## 模式

### 1. 从基础属性计算派生属性（重新计算，绝不作为事实存储）

```python
# Pseudocode. Base attributes are the only "truth"; combat stats are derived each time.
def derive(base, mods):
    s = apply_modifiers(base, mods)          # base + flat adds + percent, then clamp
    return {
        "max_hp":  20 + s["VIT"] * 8,
        "attack":  s["STR"] * 2,
        "defense": s["VIT"] + s["AGI"] * 0.5,
    }
# Equipping pushes a modifier; unequipping pops it. HP/attack recompute automatically.
```

### 2. XP 曲线 + 升级

```python
# Pseudocode. Quadratic curve: fast early levels, long late ones.
def xp_to_next(level, base=100): return base * level * level

def gain_xp(actor, amount):
    actor.xp += amount
    while actor.xp >= xp_to_next(actor.level):
        actor.xp -= xp_to_next(actor.level)
        actor.level += 1
        actor.base["STR"] += 2; actor.base["VIT"] += 2   # grant gains / skill points
        on_level_up(actor)                                # heal, unlock, notify
```

### 3. 由游戏事件驱动任务目标更新

```python
# Pseudocode. Game events advance matching objectives; completion grants rewards.
def on_event(kind, data):
    for q in active_quests:
        for obj in q.objectives:
            if obj.event == kind and matches(obj, data) and not obj.done:
                obj.count += 1
                if obj.count >= obj.needed: obj.done = True
        if all(o.done for o in q.objectives):
            q.state = "complete"                # turn-in grants xp/gold/items
```

## 陷阱 / 失败模式

- **为了增益/装备修改基础属性** → 数值漂移，并在保存/加载时损坏。保留修正层；
  对其进行压入/弹出（模式 1）。
- **将派生属性作为事实存储** → 属性变化后不同步。根据基础属性重新计算。
- **XP/伤害数值失控** → 要么是无上限的指数曲线，要么是在巨额数值上使用减法公式。
  应有意识地选择曲线和公式类型（参见参考资料）。
- **将内容写成代码** → 每个物品/任务都硬编码。将物品、敌人和任务定义为**数据**
  （`godot-resources` / `unity-scriptableobjects`）。
- **存档格式没有版本字段** → 更新后旧存档损坏。从第一天起就加入 `version` 和迁移路径
  （参见 `save-systems`）。
- **选择没有后果** → 立即重新汇合的对话分支会显得空洞。设置真正改变后续任务/世界状态的标记。
- **任务进度未持久化** → 重新加载会丢失任务中途状态。保存任务状态，而不只是完成情况。

## 组合方式（由以下技能构建）

- **对话：**`dialogue-systems`（Yarn Spinner / Ink）——分支台词、条件、变量。
- **持久化：**`save-systems`——角色、物品栏、任务标记、世界状态、版本控制。
- **内容数据：**`godot-resources` / `unity-scriptableobjects`——将物品、敌人、任务和技能作为资产。
- **战斗 AI：**`game-ai` 用于敌人行为；回合顺序可复用 `roguelike` 中的调度器思路。
- **UI：**`game-ui-ux` 用于 HUD/菜单布局、分辨率缩放和控制器/键盘导航；`godot-ui-control` 用于具体的物品栏、任务日志、角色面板和对话框。
- **世界：**`level-design` 加上所用引擎的瓦片地图/3D 技能（`godot-tilemap`、`godot-3d-essentials`）。

## 参考资料

- 有关属性/伤害公式、升级曲线、回合制与动作制战斗时间线、物品栏/装备数据形态
  和任务状态模型，请阅读 `references/stats-combat-quests.md`。
