---
name: tower-defense
description: >
  构建塔防游戏：敌人沿路线寻路、波次生成、自动索敌并开火的防御塔、经济和生命值。
  适用于塔防/波次防守游戏，或平衡波次与经济。
---

# 塔防游戏

塔防游戏开发指南——涵盖敌人寻路、波次生成、防御塔索敌以及将这些系统联系起来的经济。
这是一项**组合式**技能：将寻路、AI 和 UI 编排成塔防循环。它不再重复讲解寻路，
而是定义决定塔防紧张刺激还是轻而易举的系统和平衡杠杆（DPS、HP 与收入的关系）。

## 何时使用

- 构建玩家**放置防御塔**来自动攻击沿路径前进的**敌人波次**，花费赚取的货币扩建/升级，
  并在漏过太多敌人时失败的游戏时使用。
- 设计波次构成/节奏、防御塔索敌优先级或金币经济时使用。

**何时_不_使用：**玩家直接操控射击角色 → `fps-shooter`。带生存需求的自由基地建设 →
`survival-crafting`。寻路算法本身请使用 `game-ai`。

## 核心循环

**准备（用当前金币放置/升级防御塔）→ 开始波次 → 敌人向目标前进且防御塔自动开火 →
通过击杀赚取金币 → 挺过波次 → 面对更难的波次并重复。**其张力来自规划谜题：
当前 DPS 是否足以应对即将到来的敌人，我能否负担解决方案？

## 必备系统

1. **敌人路径**——航点路线，或迷宫塔防使用网格 + 寻路（参考资料）。
2. **波次生成器**——按时间执行、由脚本定义的敌人类型序列，并逐波缩放。
3. **防御塔**——射程、射速、伤害、投射物/命中扫描、范围伤害；放置有效性。
4. **索敌**——每座塔的优先级（最前/最后/最近/最强/最弱）（参考资料）。
5. **经济**——击杀金币 + 波次奖励；防御塔/升级费用；出售返还。
6. **生命 / 漏怪**——敌人抵达目标会扣除生命；降至 0 = 游戏结束。
7. **波次/准备 UI**——生命、金币、下一波预览、开始下一波控件。

## 设计参数

| 参数                      | 影响                  | 说明                                    |
| ------------------------- | ----------------------- | ---------------------------------------- |
| 每波敌人 HP 增长          | 升级压力                | 几何增长约 1.1–1.2×（参考资料）。        |
| 收入与 HP 曲线            | 难度                    | 玩家每波都应当_差一点_才能轻松负担。      |
| 防御塔 DPS / 射程 / 费用  | 防御塔特色              | 低价+广覆盖与高价+高强度的取舍。          |
| 索敌优先级                | 最优放置                | 对玩法的影响大于原始属性。                |
| 敌人多样性                | 克制单一构筑通关        | 快速 / 护甲 / 飞行 / 集群 / Boss。        |
| 漏怪惩罚                  | 风险                    | 同时损失生命_和_赏金。                    |
| 升级与新建经济            | 策略深度                | 升级收益递减。                            |
| 波次节奏                  | 张力曲线                | 高峰 → 缓冲 → 高峰，而非单调增长。         |

## 模式

### 1. 波次生成器（定时、数据驱动）

```python
# Pseudocode. A wave is data: a list of (enemy_type, count, spacing). Spawn over time.
wave = [ ("grunt", 10, 0.5), ("runner", 5, 0.3), ("tank", 2, 1.0) ]

def run_wave(wave):
    for enemy_type, count, spacing in wave:
        for _ in range(count):
            spawn_enemy(enemy_type, at=path[0])   # enter at the path start
            wait(spacing)                          # seconds between spawns (use a timer/coroutine)
    # wave clears when all spawned enemies are dead or have leaked
```

### 2. 防御塔索敌（筛选射程内目标，再按优先级选择）

```python
# Pseudocode. "First" (furthest along path) is the standard default for stopping leaks.
def acquire_target(tower, enemies, mode="first"):
    in_range = [e for e in enemies if distance(tower.pos, e.pos) <= tower.range]
    if not in_range: return None
    if mode == "first":    return max(in_range, key=lambda e: e.progress)   # furthest along path (stop leaks)
    if mode == "last":     return min(in_range, key=lambda e: e.progress)   # least progress (guard the entrance)
    if mode == "closest":  return min(in_range, key=lambda e: distance(tower.pos, e.pos))
    if mode == "strongest":return max(in_range, key=lambda e: e.hp)         # burn down tanks first
    if mode == "weakest":  return min(in_range, key=lambda e: e.hp)         # secure kills / last-hit bounty
    return in_range[0]
```

### 3. “这条路线守得住吗？”合理性检查（DPS 与 HP）

```python
# Pseudocode. One tower's damage to one enemy crossing its range.
tower_dps     = tower.damage * tower.fire_rate
time_in_range = tower.range_coverage_length / enemy.speed
damage_dealt  = tower_dps * time_in_range
# Lane holds if summed damage_dealt from covering towers >= enemy.hp (per enemy). See refs.
```

## 陷阱 / 失败模式

- **敌人 HP 增长慢于玩家收入/DPS** → 几波后游戏变得轻而易举。对照收入曲线调整 HP 曲线（参考资料）。
- **存在唯一主导防御塔/策略** → 没有决策空间。加入强力克制构筑的敌人类型
  （护甲克制高射速、飞行克制仅地面攻击）和递减的升级收益。
- **迷宫塔防可以完全堵死目标** → 敌人被卡住/软锁。禁止切断路径的放置；防御塔变化时重新计算路径（参考资料）。
- **没有下一波预告** → 特殊敌人显得随机且不公平。预览即将到来的构成。
- **逐帧移动未按 `dt` 缩放** → 速度随帧率变化。转向按 `dt` 缩放。
- **漏怪只扣生命，不损失金币** → 漏怪有时反而是最优选择。让漏怪同时损失赏金。
- **难度单调增长** → 令人疲惫。交替安排高峰和缓冲。

## 组合方式（由以下技能构建）

- **寻路：**`game-ai` 用于 A\*/流场/转向；固定路线可简单跟随航点。
- **敌人移动：**`godot-2d-movement`（或引擎等效技能）用于沿路径移动；`unity-navmesh` 用于基于导航的寻路。
- **地图：**`godot-tilemap` / `unity-tilemap-2d` 用于网格/路线；`level-design` 用于地图布局。
- **数据：**`godot-resources` / `unity-scriptableobjects` 将防御塔、敌人和波次定义为资产。
- **UI：**`game-ui-ux` 用于 HUD 布局、缩放和建造菜单；`godot-ui-control` 用于具体控件（生命、金币、波次预览）。
- **润色：**`audio-design` 用于开火/命中/漏怪提示音。

## 参考资料

- 有关路径表示（航点 / A\* / 流场）、索敌模式、DPS 与经济计算、敌人缩放和波次节奏，
  请阅读 `references/balancing.md`。
