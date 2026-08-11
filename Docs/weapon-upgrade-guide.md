# 武器升级系统 · SubAgent 实现规范

> 项目：暗夜幸存者（Vampire Survivors-like）。纯 HTML5 Canvas + 原生 JS（ES Modules，零依赖零构建）。
> 本文件是 6 个武器实现 Agent 的唯一契约。**每个 Agent 只允许修改自己的武器文件** `js/weapons/<id>.js`，禁止改任何其他文件。

## 一、任务总述

把武器从 5 级纯数值升级，改造为 6 级路线：Lv1/3/5 数值成长，Lv2/4 解锁机制，Lv6 最终质变。
设计已定稿（见本文件「各武器规格」节，与 Notion 一致），直接实现，不要改设计。

## 二、文件与代码约定

- 你的文件已包含当前 Lv1-5 的完整实现（武器类 + CARD 定义），在其基础上扩展。
- `CARD.maxLevel` 改为 6，`CARD.levels` 扩为 6 条。
- **levels 每条是完整快照**：机制开关（布尔 flag）解锁后，后续所有等级都要带上。
  例：Lv2 解锁灼烧，则 levels[1]~levels[5] 都要有 `burn: true`。数值也要逐级递增写全。
- 机制 flag 命名自己定（如 `swordQi`、`shock`、`chain`），代码里用 `this.stats.xxx` 读取。
- 可选：把 `CARD.desc` 补充一句机制说明（保持一两句，别写小作文）。
- 注释用中文。临时特效（剑气环、冲击波、闪电链等）存在武器实例自己的数组里，在 `draw()` 里画，**不要**给 game 的 effects 加新类型。
- 允许 import：`./base.js`、`../utils.js`、`../projectile.js`、`../config.js`。禁止 import 其他武器文件或 game。

## 三、world API（update(dt, world) 的第二个参数）

```
world.player      { x, y, radius, hp, maxHp, facing, moving, lastHurtAt }
world.enemies     敌人数组（字段见下）
world.projectiles / world.trails / world.summons / world.effects   实体数组，可 push
world.mods        { damageMult, areaMult, attackSpeedMult, cooldownMult, projectileBonus, moveSpeedMult, xpMult }
world.elapsed     游戏时间（秒）
world.kills       累计击杀数
world.killLog     最近击杀记录数组，条目 { id, x, y, burned }（burned=死亡时是否带火系debuff）
world.damageEnemy(e, dmg)         统一伤害入口（击杀计数/掉宝石必须走它）
world.healPlayer(amount)          治疗（自动 clamp 到上限）
world.dropPickup(x, y, kind='hp') 掉血包（同屏上限系统自动控制）
world.applyDot(e, type, dps, duration)   挂 debuff。type: 'burn'|'bleed'|'poison'，不叠加只刷新
world.applySlow(e, factor, duration)     减速。factor=0.25 即减速25%
world.applyFreeze(e, duration)           冰冻
world.hasDot(e, type)                    查询 debuff
```

敌人字段：`e.x e.y e.radius e.hp e.maxHp e.dead e.hitFlash`，状态字段 `e.dots e.slowTimer e.frozenTimer`。
击飞/位移：直接改 `e.x/e.y` 即可。

**击杀日志消费模式**（爆燃、百鬼夜行、击杀计数质变用这个）：

```js
// constructor 里：this.lastKillId = 0;
for (const k of world.killLog) {
  if (k.id <= this.lastKillId) continue;
  this.lastKillId = k.id;
  // 处理这次击杀：k.x, k.y, k.burned
}
```

**受击监听**（玉环 Lv6 用）：`world.player.lastHurtAt` 是玩家最近一次真正受击的 elapsed 时刻（初始 -1）。自己记一个 lastSeen 对比即可。

乘数用法约定：伤害 ×damageMult；半径/范围 ×areaMult；攻击间隔 ÷attackSpeedMult；内置 CD ×cooldownMult。

## 四、DoT 数值参考（dps = 每秒伤害）

- burn（灼烧/烈焰）：dps ≈ 10~16，持续 2s（参考：披风 Lv2 每 0.5s 打 7）
- bleed（流血）：dps ≈ 6~12，持续 2.5s
- poison（尸毒）：dps ≈ 6~10，持续 3s

## 五、各武器规格（定稿）

### 道剑 sword.js
1. 伤害 + 范围（数值）
2. + 剑气：挥砍命中时额外发射穿透弹道（可穿过目标打后面的敌人），飞行一段距离，路径上敌人受击；建议作为一次性的直线 AoE 结算或特殊弹道，伤害 = 挥砍伤害
3. 数值
4. + 拔剑斩：每第 3 次挥砍追加一次以玩家为中心的 360° 剑气环，2.5 倍伤害
5. 数值
6. 质变「剑意」：拔剑斩带击飞（短距离，直接位移敌人 ~40px，用于解围）；每击杀 10 个敌人 +1 飞剑（上限 10）；飞剑环绕/自动攻击玩家附近敌人并挂 bleed；飞剑 15 秒后消失

### 炽热披风 cloak.js
1. 数值
2. + 灼烧：tick 命中的敌人挂 burn
3. 数值
4. + 震荡冲击：内置 CD 5~6s（×cooldownMult），从玩家中心向外扩散的大范围冲击，伤害 ≈ 6~8 个 tick，附加 burn；冲击半径 = 披风半径 ×1.5~1.8（吃 areaMult）
5. 数值
6. 质变：震荡冲击 CD 降至 ~3s；每击杀 100 个敌人立即重置震荡冲击 CD；被冲击命中的敌人减速 2s（factor 0.3 左右）

### 雷符咒 talisman.js
1. 数值
2. + 引雷：按弹道命中次数计数，每命中 2 次，被命中的那个目标被雷劈一次（伤害 = 弹道 ×1.5）。注意计数按命中次数，弹道数量卡会加速触发
3. 数值
4. + 闪电链：弹道命中后额外弹射 2 次到附近敌人，每次 50% 伤害；同一条链不重复命中同一目标；弹射搜索半径 ≤160px
5. 数值
6. 质变：闪电链弹射 3 个目标；每次攻击命中的第一个目标必定触发引雷（不占计数）；引雷变为范围伤害（半径 ≤80px）

### 丹火 trail.js
1. 数值
2. + 烈焰：地面 tick 命中的敌人挂 burn
3. 数值
4. + 爆燃：消费 killLog，带 burned 的击杀在死亡点爆炸（半径 60~70，伤害 ≈ 地面 tick ×2，对附近敌人）；每次击杀只爆一次（killLog 天然保证）
5. 数值
6. 质变：玩家站在自己的丹火地面上回血（1 点/0.5s，用 world.healPlayer）；爆燃放血包：爆炸击杀的敌人 20% 概率 world.dropPickup（系统有同屏上限，直接调即可）；爆燃半径 +50%

### 玉环 ring.js
1. 数值
2. 寒玉：命中敌人减速 25% 持续 1.2s（applySlow(e, 0.25, 1.2)）
3. 数值 + 环数加一
4. 血滴子：周期性所有玉环外扩再收回（扩张段伤害 ×1.5）；自己定周期（如 4s 一次，扩张 1s）
5. 数值 + 环数加一
6. 质变：每击杀 100 个敌人，血滴子狂暴 3s（扩张速度 ×2、伤害 ×2）；玩家受击后（lastHurtAt）冻住大范围敌人 1.5s（applyFreeze）并造成一次高额伤害；该反制内置 CD ≥20s

### 死灵法杖 staff.js
现有结构：slots 槽位循环（cd -> 召唤 -> 存活 -> cd），召唤物数据在 summon 对象。
1. 仆从伤害提升 + 仆从移速提升（数值）
2. 召唤 CD 减少 + 召唤数量 +1（共 2）+ 尸毒：仆从每次攻击命中时，对目标小范围内敌人挂 poison
3. 仆从伤害提升 + 存活时间变长 + 召唤 CD 减少
4. 仆从伤害提升 + 仆从存活结束时自爆（半径 ~70 范围伤害）
5. 召唤数量 +1（共 3，槽位上限）+ 自爆半径 +50% + 存活时间变长
6. 质变「百鬼夜行」：消费 killLog，每次击杀 20% 概率把死者转化为尸体仆从（每 10 杀保底 1 个，自己维护计数）；尸体仆从上限 3~5（超出顶掉最旧的）；尸体仆从与召唤仆从共用行为（追击/leash/接触攻击），到期同样自爆；你与仆从的连接持续回血：1 点/秒 + 每多 1 个仆从 +0.5，封顶 3 点/秒（按当前存活仆从总数，用 world.healPlayer）；百鬼夜行期间所有仆从强化：体型更大（drawSummon 已支持 su.radius 字段，默认 11）、攻击范围与伤害、移速大幅提升。尸体仆从可设 su.corpse = true（drawSummon 会换色）

## 六、自检

改完后运行 `node tools/headless-smoke.mjs`（会 import 全部武器文件，语法错误会暴露；8 项冒烟必须全绿）。
不要新增测试文件，不要改冒烟测试。

## 七、汇报格式

最终回复列出：修改的文件路径、每级机制的实现要点（每级一行）、用到的数值、有没有觉得不平衡的地方。