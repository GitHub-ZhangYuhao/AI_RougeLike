# BALANCE.md — 数值配置全表（Godot 侧真值）

> **文档定位（先读）**
> - 本文件是游戏数值配置的**唯一文档真值**。`autoload/config.gd` 的 `CONFIG` 字典与本表逐键一致（键名保留 JS camelCase，见 AGENTS.md 的 CONFIG 例外条款）。
> - 原型 `js/config.js` 为基线、**不回改**。下表在 Godot 有意差异的 25 个键上标注「js 原值」或「Godot 新增」；裁决过程见 RULES.md 附录 B #9/#10/#11/#12。
> - 改数流程：先改 `autoload/config.gd` → 同步本表 → 跑 `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` 验证。
> - RULES.md 只保留规则与公式（§7/§8 等），不再重复数值表；原 RULES.md 附录 A 于 2026-08-15 全量并入本文件。
> - 表中 `INF` 表示无穷大（js 的 Infinity）。

## 调参历史（2026-08-15 至 2026-08-18，五轮）

**第一轮**（手感：人物偏大、镜头偏近、敌人偏小、怪物偏快/偏厚/偏少，裁决见 RULES.md 附录 B #9）：
`enemy.speed` 85→76、`enemy.hp` 50→45、`spawner.startMaxAlive` 20→30、`spawner.maxAlivePerWave` 8→10、`spawner.maxAliveCap` 140→180、`waves.baseQuota` 16→24、`waves.quantityPerWave` 0.5→0.8。

**第二轮**（血太厚 / 移速增长过快 / 数量太少，裁决见 RULES.md 附录 B #10）：
`enemy.hpPerMin` 54→10、`enemy.speedPerMin` 0.08→0.015、`enemy.hpPerWave` 0.16→0.10、`enemy.hpPerWaveMid` 0.30→0.12、`enemy.hpPerWaveLate` 0.28→0.10、`enemy.hpWaveCap` 7→3、`enemy.baseSpeedMult` 1.5→1.35、`enemy.speedWaveCap` 2→1.6、`spawner.startMaxAlive` 30→40、`spawner.maxAlivePerWave` 10→12、`waves.baseQuota` 24→30、`waves.quantityPerWave` 0.8→1.2、`waves.quantityWaveCap` 11.25→14。`maxAliveCap` 保持 180（M6 性能焦点 #1 的压测指标，分离算法 O(n²)，对象池优化落地后再议上调）。同轮将 `logic/enemies/base.gd` 的 `apply_wave_scaling` 由硬编码改为 Config 驱动（对齐 js/enemies/base.js）。

**第三轮**（单局时长与后期容错，2026-08-17）：每波 90→60 秒，25 波基础战斗时长压缩为 25 分钟；`enemy.damagePerMin` 2.2→1.0、`damagePerWaveMid` 0.14→0.09、`damagePerWaveLate` 0.18→0.09；死亡按所在波正常暗晶的 35%保底结算。

**第三轮后曲线速览（chaser，按波开始时间估算）**：w1 45 HP / 7 伤害 → w5 ~119 HP / ~14 伤害 → w10 ~267 HP / ~27 伤害 → w20 ~705 HP / ~67 伤害 → w25 ~855 HP / ~93 伤害。W25 Boss 普通弹约 161 原始伤害，后续通过实机与受击遥测继续校准。

**第四轮**（拾取可读性与操作容错，2026-08-17）：`gems.magnetRadius` 180→240、`gems.pickupRadius` 22→30、`pickups.pickupRadius` 22→30、`pickups.rarePickupRadius` 30→42；同步放大世界图标并补充靠近说明和拾取结果说明。前三项中普通拾取与宝石拾取同值，差异键按配置路径计为 4 项。

**第五轮**（稀有拾取仍然难捡，2026-08-18）：`pickups.rarePickupRadius` 42→58（js 原值 30）；
世界表现同步放大——稀有图标 46→68、拾取光晕 62→80，并新增按 `rarePickupRadius` 实际半径绘制的脉动外环，
让「已进入拾取范围」可见。同轮修正 `logic/weapons/sword.gd` 的道剑 Lv2–5 `maxHits` 2/2/2/4 → 全部 `INF`，
恢复与原型 `js/weapons/sword.js` 的一致（原型 smoke 一直断言全等级无限贯穿），该项属移植缺陷修复而非平衡调整。

---

## 1. 视图 view

| 键 | 值 | 说明 |
| --- | --- | --- |
| background | `#0e0e16` | 背景色 |
| gridSize | 64 | 网格尺寸 |

## 2. 玩家 player

| 键 | 值 | 说明 |
| --- | --- | --- |
| radius | 14 | 碰撞半径 |
| speed | 230 | 移速（px/s） |
| maxHp | 100 | 生命上限 |
| hurtIFrames | 0.8 | 受击无敌时间（秒） |
| color | `#4fc3f7` | 占位色（正式美术已接入） |

## 3. 相机 camera

| 键 | 值 | 说明 |
| --- | --- | --- |
| lerp | 8 | 跟随插值系数 |

## 4. 刷怪器 spawner

| 键 | 值 | js 原值 | 说明 |
| --- | --- | --- | --- |
| startInterval | 1.0 | | 初始刷怪间隔（秒） |
| minInterval | 0.14 | | 刷怪间隔下限 |
| intervalPerWave | 0.12 | | 每波间隔递减量 |
| startMaxAlive | **40** | 20 | 初始存活上限 |
| maxAlivePerWave | **12** | 8 | 每波存活上限增量 |
| maxAliveCap | **180** | 140 | 存活上限封顶（M6 性能压测指标，暂不上调） |
| spawnMargin | 80 | | 屏外出生边距 |

> 公式：刷怪间隔 `max(0.14, startInterval − (wave−1)×intervalPerWave) × intervalMult`；存活上限 `min(maxAliveCap, startMaxAlive + (wave−1)×maxAlivePerWave)`。详见 RULES.md §8.1。

## 5. 敌人基础 enemy

| 键 | 值 | js 原值 | 说明 |
| --- | --- | --- | --- |
| radius | 13 | | 默认碰撞半径 |
| speed | **76** | 85 | 基础移速 |
| baseSpeedMult | **1.35** | 1.5 | 第 1 波移速倍率（波次成长起点） |
| speedVariance | 0.25 | | 移速随机浮动 ±25% |
| hp | **45** | 50 | 基础 HP |
| damage | 7 | | 基础接触伤害 |
| hpPerMin | **10** | 54 | 每分钟 HP 成长（时间项） |
| damagePerMin | **1.0** | 2.2 | 每分钟伤害成长 |
| speedPerMin | **0.015** | 0.08 | 每分钟移速成长 |
| hpPerWave | **0.10** | 0.16 | 前期每波 HP 成长（1~6 波段） |
| damagePerWave | 0.06 | | 前期每波伤害成长 |
| midWaveStart | 7 | | 中期段起始波 |
| hpPerWaveMid | **0.12** | 0.30 | 中期每波 HP 成长（7~11 波段） |
| damagePerWaveMid | **0.09** | 0.14 | 中期每波伤害成长 |
| lateWaveStart | 12 | | 后期段起始波 |
| hpPerWaveLate | **0.10** | 0.28 | 后期每波 HP 成长（12+ 波段） |
| damagePerWaveLate | **0.09** | 0.18 | 后期每波伤害成长 |
| hpWaveCap | **3** | 7 | 波次 HP 倍率封顶 |
| speedWaveCap | **1.6** | 2 | 波次移速倍率封顶 |
| speedCapStartWave | 20 | | 移速倍率到达封顶的波次 |
| separation | 60 | | 敌人分离强度 |
| color | `#ef5350` | | 占位色 |

> 公式：构造 `maxHp = (hp + hpPerMin×minutes) × 类型hpMult`、`speed = speed × jitter × (1+speedPerMin×minutes) × 类型speedMult`；波次成长三段式与封顶见 RULES.md §7.1 / §7.2。

## 6. 敌人类型 enemyTypes

**通用字段**（`—` 表示该类型无此键，按 1.0 处理）：

| 类型 | unlockAt(秒) | weight | maxAlive | hpMult | speedMult | damageMult |
| --- | --- | --- | --- | --- | --- | --- |
| chaser | 0 | 62 | INF | — | — | — |
| enhancedChaser | 0 | 0（仅经 chaser 拆分入池） | INF | 2.2 | 1.05 | 1.45 |
| charger | 45 | 18 | 8 | 1.7 | 1.05 | 1.1 |
| ranged | 90 | 11 | 8 | 0.8 | 0.8 | 0.95 |
| bomber | 135 | 14 | 6 | 0.85 | 1.25 | 1.6 |
| shield | 180 | 4 | 1 | 2.6 | 0.8 | 1.15 |
| boss | 0 | 0（Boss 波强制刷出） | 1 | 24 | 0.68 | 2.4 |

**各类型专属字段**：

| enhancedChaser | 值 | | charger | 值 |
| --- | --- | --- | --- | --- |
| enrageHpRatio | 0.5 | | chargeRange | 260 |
| warningDuration | 0.45 | | windup | 0.65 |
| enragedSpeedMult | 1.5 | | dashSpeed | 400 |
| enragedDamageMult | 1.35 | | dashDuration | 0.55 |
| | | | recovery | 0.85 |
| | | | cooldown | 1.7 |

| ranged | 值 | | bomber | 值 |
| --- | --- | --- | --- | --- |
| preferredDistance | 260 | | triggerDistance | 58 |
| retreatDistance | 170 | | windup | 0.9 |
| fireInterval | 1.7 | | blastRadius | 88 |
| projectileSpeed | 175 | | | |
| projectileRadius | 5 | | | |
| projectileLifetime | 4 | | | |

| shield | 值 | | boss | 值 |
| --- | --- | --- | --- | --- |
| shieldDuration | 3 | | radius | 34 |
| openDuration | 1.5 | | attackInterval | 2.9 |
| shieldDamageMult | 0.35 | | windup | 0.85 |
| openDamageMult | 1.25 | | projectileCount | 12 |
| | | | projectileSpeed | 180 |
| | | | projectileRadius | 7 |
| | | | projectileLifetime | 5 |
| | | | enragedHpRatio | 0.5 |
| | | | enragedProjectileCount | 18 |
| | | | enragedProjectileSpeed | 205 |

> 选型规则（权重、解锁、enhancedChaser 替换比例、ranged 波内上限）见 RULES.md §7.4；各类型行为见 §7.6。

## 7. 波次 waves

| 键 | 值 | js 原值 | 说明 |
| --- | --- | --- | --- |
| maxWave | 25 | | 最大波次 |
| duration | **60** | 90 | 每波时长（秒） |
| baseQuota | **30** | 16 | 配额基数 |
| quantityPerWave | **1.2** | 0.5 | 每波配额增长 |
| quantityWaveCap | **14** | 11.25 | 普通波配额倍率封顶 |
| restDuration | 3.5 | | 波间休息时长（秒） |
| bossEvery | 5 | | Boss 波间隔 |
| eliteEvery | 3 | | 精英（shield）保底间隔 |
| bannerDuration | 2.4 | | 波次横幅时长（秒） |

> 公式：普通波 `quota = round(baseQuota × min(quantityWaveCap, 1+(wave−1)×quantityPerWave))`（w12+ 达 420/波）；Boss 波配额 = 1+增援数（5/7/9/11/13，与 baseQuota 无关）。详见 RULES.md §8.2。

## 8. 卡牌 cards

| 键 | 值 | 说明 |
| --- | --- | --- |
| maxWeaponSlots | 3 | 武器槽上限 |
| choicesCount | 3 | 选卡选项数 |
| attrMaxStack | 5 | 属性卡堆叠上限 |

## 9. 局内任务 tasks

**通用**：

| 键 | 值 | 说明 |
| --- | --- | --- |
| waves | [3, 8, 13, 18, 23] | 任务触发波 |
| triggerWindow | [35, 45] | 波内触发时间窗（秒） |
| offerDuration | 12 | 任务卡展示时长（秒） |
| acceptDuration | 1 | 接受判定时长（秒） |
| beaconRadius | 60 | 信标半径 |
| beaconDistance | [300, 440] | 信标距离范围 |
| resultDuration | 3.5 | 结果展示时长（秒） |

**guard（守卫，5 档）**：durations `[18, 20, 22, 24, 26]`；radii `[130, 125, 120, 115, 110]`；leaveGrace `[1, 1, 0.9, 0.9, 0.8]`。

**delivery（护送，5 档）**：distances `[[1500,1750],[1600,1850],[1700,1950],[1800,2050],[1900,2200]]`；timeLimits `[22, 22, 21, 21, 20]`；interceptorCounts `[[1,2],[2,2],[2,2],[2,3],[3,3]]`；interceptorIntervals `[6, 5.5, 5, 4.5, 4]`；destinationRadius `72`。

**bounty（悬赏）**：spawnDistance `[450, 650]`；hpMultipliers `[2.5, 3, 3.5, 4, 4.5]`；damageMultipliers `[1.1, 1.15, 1.2, 1.25, 1.3]`；timeLimits `[40, 40, 38, 38, 36]`。

**rewards（奖励）**：choicesCount `3`；weights 武器 `0.4` / 属性 `0.35` / 祝福 `0.25`。

## 10. 宝石 gems

| 键 | 值 | 说明 |
| --- | --- | --- |
| magnetRadius | 240（js 原值 180） | 磁吸半径 |
| magnetStartSpeed | 300 | 磁吸初速 |
| magnetAcceleration | 900 | 磁吸加速度 |
| magnetMaxSpeed | 680 | 磁吸最大速度 |
| pickupRadius | 30（js 原值 22） | 拾取半径 |
| cap | 300 | 场上宝石上限 |

**档位 tiers**：

| until(秒) | value | color |
| --- | --- | --- |
| 90 | 1 | `#5ac8fa` |
| 180 | 2 | `#66bb6a` |
| INF | 3 | `#ff8a65` |

## 11. 经验 / 击杀记录 / 尸体 / 拾取物 / HUD

| 组 | 键 | 值 | 说明 |
| --- | --- | --- | --- |
| xp | base | 6 | 升级基础经验 |
| xp | perLevel | 4 | 每级经验增量 |
| killLog | cap | 256 | 击杀记录上限 |
| corpses | stainTtl | 3 | 尸体残留时长（秒） |
| corpses | cap | 80 | 尸体上限 |
| pickups | hpValue | 15 | 血包回复量 |
| pickups | pickupRadius | 30（js 原值 22） | 普通拾取半径 |
| pickups | rarePickupRadius | 58（js 原值 30） | 稀有拾取半径 |
| pickups | maxAlive | 5 | 血包场上上限 |
| hud | font | `16px "Segoe UI", "Microsoft YaHei", sans-serif` | HUD 字体（非数值） |

## 12. 局外 meta

| 键 | 值 | 说明 |
| --- | --- | --- |
| dropChance | base 0.08 / perTier 0.03 / cap 0.20 | Boss 材料掉落率 |
| tierWeights | 见下表 | 掉落阶位权重 [T1,T2,T3] |
| dropCount | 见下表 | 掉落数量 [min,max] |
| guaranteedMinTier | 3阶Boss→2、5阶Boss→3 | 保底最低材料阶（取 ≤bossTier 的最大键；1~2 阶无保底即 1） |
| waveRewardMult | 1.5 | 波次奖励倍率 |
| deathRewardMult | 0.35 | 死亡时保留正常波数暗晶的比例 |
| shopMaxLevel | 10 | 商城等级上限 |
| shopPrice | base 20 / growth 1.6 | 商城价格曲线 |
| saveKey | `ai-roguelike-meta-save-v1` | 存档键（非数值） |

**tierWeights / dropCount**（5 阶及以上 Boss 一律用第 5 档）：

| Boss 阶 | tierWeights [T1,T2,T3] | dropCount [min,max] |
| --- | --- | --- |
| 1 | [100, 0, 0] | [1, 1] |
| 2 | [70, 30, 0] | [1, 1] |
| 3 | [45, 45, 10] | [1, 2] |
| 4 | [25, 45, 30] | [1, 2] |
| 5 | [10, 40, 50] | [2, 2] |

---

## 附：相关规则索引（RULES.md）

- 敌人构造与波次成长公式：§7.1 / §7.2
- 敌人类型选择 chooseEnemyType：§7.4
- 各类型行为：§7.6
- Spawner 刷怪节奏与存活上限：§8.1
- WaveDirector 配额与波流程：§8.2
- 数值矛盾裁决（含三轮调参记录）：附录 B #9 / #10 / #11