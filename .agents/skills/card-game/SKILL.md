---
name: card-game
description: >
  构建卡牌游戏：卡牌数据、牌库/手牌/弃牌区、抽牌/洗牌/重新洗牌、回合结构、
  费用和效果结算。适用于牌组构筑游戏、TCG/CCG 或 Roguelike 牌组构筑游戏。
---

# 卡牌游戏

卡牌游戏开发指南——涵盖卡牌数据、牌库/手牌/弃牌区、回合结构以及卡牌效果的
结算方式。这是一项**组合式**技能：将卡牌建模为数据并接入 UI。它不再重复讲解数据资产或
UI 节点，而是定义区域模型、抽牌机制和效果结算规则，确保卡牌游戏正确运行且避免缺陷。

## 何时使用

- 构建以**卡牌**在不同区域间移动为核心的任何游戏时使用
  （牌库 → 手牌 → 打出区 → 弃牌区）：牌组构筑游戏、TCG/CCG、接龙、Roguelike 牌组构筑游戏。
- 设计抽牌/洗牌/重新洗牌、回合结构、卡牌费用或效果结算方式时使用。

**何时*不*使用：**采用匹配规则的棋盘/格子状态 → `puzzle`。仅附带卡牌战斗的 RPG →
从 `rpg` 开始。将卡牌定义为资产时使用 `godot-resources` / `unity-scriptableobjects`；
处理手牌/拖拽 UI 时使用 `godot-ui-control`。

## 核心循环

**抽牌入手 → 消耗资源打出卡牌 → 结算效果并改变场面 → 结束回合（清理/弃牌）→
对手/下一阶段 → 重复直至满足胜利条件。**深度来自手牌所支持的各种*组合*；引擎的职责是
毫无歧义地结算它们。

## 必备系统

1. **卡牌数据**——id、名称、费用、类型、文本和效果规格（数据，而非代码）。
2. **区域**——牌库（抽牌堆）、手牌、打出区/场面、弃牌区、放逐区/移除区；每张牌只能存在于一个区域。
3. **抽牌 + 洗牌 + 重新洗牌**——从牌库抽到手牌；牌库为空时将弃牌重新洗入牌库。
4. **回合结构**——以状态机表示各阶段（重置/抽牌/主要/战斗/结束）。
5. **资源系统**——用法力/能量/行动点限制每回合可执行的操作量。
6. **效果结算**——按规定顺序应用卡牌效果；处理目标和触发器。
7. **胜负条件**——生命总值、牌库耗尽、目标。
8. **UI**——手牌布局、拖放或点击出牌、区域数量和目标选择提示。

## 设计参数

| 参数 | 影响 | 说明 |
|------|--------|-------|
| 初始手牌 / 每回合抽牌数 | 节奏、稳定性 | 抽牌越多，方差越小。 |
| 手牌上限 | 囤积与使用的取舍 | 回合结束时弃至上限。 |
| 牌库大小（下限） | 稳定性 | 越小越容易稳定形成连招。 |
| 资源曲线 | 何时能打出哪些牌 | “法力曲线”控制强度节奏。 |
| 卡牌稀有度 / 强度预算 | 平衡性 | 卡牌越强，费用越高或越稀有。 |
| 确定性与随机性 | 技巧与局势波动 | 洗牌 + 随机效果会增加方差。 |
| 重新洗牌规则 | 牌库耗尽、疲劳 | 重新洗入弃牌，或惩罚空牌库。 |
| 移除手段 / 应对牌 | 反制空间 | 卡池中的每种威胁都需要应对手段。 |

## 模式

### 1. 区域 + 自动重新洗牌的抽牌机制

```python
# Pseudocode. A card is in exactly one zone at a time; moving = remove here, add there.
def draw(n):
    for _ in range(n):
        if not deck:
            if not discard:          # truly empty: deck-out (lose, or take fatigue)
                on_deck_out(); return
            deck.extend(discard)     # reshuffle discard into deck
            discard.clear()
            shuffle(deck, rng)       # use a seeded RNG (see save-systems for replays)
        hand.append(deck.pop())
```

### 2. 卡牌数据 + 效果结算

```python
# Pseudocode. Effects are a data list interpreted by the engine — not bespoke code per card.
card = {
    "id": "fireball", "cost": 3, "type": "spell",
    "effects": [ {"op": "damage", "amount": 6, "target": "chosen_enemy"} ],
}
def play(card, caster):
    if resources[caster] < card.cost: return False     # can't afford
    resources[caster] -= card.cost
    move(card, from_zone=hand, to_zone=play_or_discard(card))
    for fx in card.effects:
        resolve_effect(fx, caster)                      # one interpreter handles every card
    return True
```

### 3. 以阶段状态机表示回合结构

```python
# Pseudocode. Fixed phases keep timing windows (triggers, priority) unambiguous.
PHASES = ["untap", "draw", "main", "combat", "end"]
def take_turn(player):
    for phase in PHASES:
        enter_phase(player, phase)        # fire "on_phase" triggers here
        if phase == "draw":   draw(1)
        if phase == "main":   await player_plays_cards()
        if phase == "combat": resolve_combat()
        if phase == "end":    discard_to_hand_limit(player); clear_temporary_effects()
```

## 陷阱 / 失败模式

- **一张牌同时存在于两个区域** → 导致复制/丢失缺陷。强制“一牌一区”；
  移动 = 先移除再添加，并断言任何卡牌都不会重复出现。
- **忘记重新洗牌** → 牌库为空时抽牌无声失败或崩溃。重新洗入弃牌，
  或明确规定牌库耗尽/疲劳机制（模式 1）。
- **每张牌一个函数** → 无法维护和测试。将效果制成由少量操作解释的**数据**
  （模式 2）。
- **效果顺序 / 同时触发含糊不清** → 结果不确定。按规定顺序（队列或栈）结算；
  记录采用 LIFO 还是 FIFO（参见参考资料）。
- **需要回放/撤销的游戏采用无种子洗牌** → 无法复现。使用带种子的 RNG。
- **没有手牌上限 / 没有应对牌** → 导致无意义囤牌或无法战胜的威胁。设置手牌上限，
  并确保每类威胁都有对应的移除手段。
- **目标选择状态泄漏** → 取消出牌后场面仍停留在目标选择中。让出牌成为原子操作：
  先验证费用 + 目标，再提交操作。

## 组合方式（由以下技能构建）

- **卡牌内容：**`godot-resources` / `unity-scriptableobjects`——将每张卡牌定义为数据资产。
- **UI：**`game-ui-ux` 用于布局、缩放和焦点导航；`godot-ui-control` 用于手牌布局、拖放、区域数量和目标选择提示。
- **持久化/回放：**`save-systems` 用于收藏、局内状态（Roguelike 牌组构筑游戏）和带种子的回放。
- **对手 AI：**`game-ai` 用于评估可打出的卡牌并选择目标的 AI。
- **动画/反馈：**使用引擎动画技能处理卡牌移动；使用 `audio-design` 处理提示音。
- **脚本：**`godot-gdscript` / `unity-csharp-scripting` 用于效果解释器。

## 参考资料

- 有关效果队列/栈、关键字/触发器、目标选择、牌组构筑与构筑赛制原型的差异以及洗牌公平性，
  请阅读 `references/effect-resolution.md`。
