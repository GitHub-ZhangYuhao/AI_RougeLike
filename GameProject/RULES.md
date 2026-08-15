# RULES.md — 游戏规则真值规范（HTML 原型 → Godot 移植）

**定位**：本文件是把根目录 HTML 原型（`js/`）移植到 Godot（本目录 `GameProject/`）时的**唯一规则真值**。移植产生的 `logic/` 代码必须与本文件逐条对应。

**真值优先级**：`js/` 运行代码 > `Docs/` 策划文档 > `DESIGN.md`。文档与代码矛盾时一律以代码为准（见附录 B 矛盾裁决表）。

**约束**：
- 所有公式、数值、时机、概率权重、**随机数调用顺序**均按 `js/` 代码 1:1 抄录，移植时不得"顺手优化"、取整或合并。
- 若原型代码后续变更，须同步更新本文件，再改 Godot 实现。
- 本文件只描述"规则是什么"，不描述"Godot 怎么实现"；实现方式见 `PORT_PLAN.md`，仓库约定见 `AGENTS.md`。

## 目录

1. 全局状态机与一局流程
2. 主循环与 update 顺序
3. 玩家、输入、相机
4. 属性计算（mods / recomputeMods）
5. 伤害管线与碰撞
6. 状态效果（DoT / 减速 / 冻结）
7. 敌人系统（基类、成长、7 种敌人）
8. 波次与刷怪器
9. 宝石、经验与升级
10. 拾取物与稀有物品
11. 卡牌系统
12. 武器系统（6 种 × 6 级）
13. 联动（Synergy）系统
14. 任务系统
15. 局外 Meta（掉落 / 商城 / 仓库 / 存档）
16. 调试系统
17. 渲染、HUD 与 UI 布局
- 附录 A：CONFIG 全量（已并入 BALANCE.md）
- 附录 B：矛盾裁决表
- 附录 C：smoke 测试章节对照表

---

## 1. 全局状态机与一局流程

### 1.1 状态集合

`menu | shop | storage | opening | playing | choice | extraction | summary | dead`

- `opening` 与 `choice` 期间**世界完全暂停**（不推进 elapsed、敌人、波次），update 只处理选卡输入。
- `menu / shop / storage / extraction / summary` 各自有独立的 update 分支，处理完后直接返回，不进入战斗更新。

### 1.2 状态转换

| 从 | 到 | 触发条件与动作 |
| --- | --- | --- |
| menu | opening | Enter / Space / 点击"开始游戏" → `startRun()`。仅接受从 menu 发起。依次执行：`stats.runs++` → `persistSave()` → `reset()`（清空局内）→ `state='opening'` → 应用局外生命：按商城 maxHp 等级 n 调 `increaseMaxHp(20*n, 20*n)` |
| menu | shop / storage | 点击对应按钮 |
| shop / storage | menu | Escape |
| opening | choice | 展示 `openingOffers()` = 全部 6 张武器卡（type 'new'），任选 1 张 |
| choice | playing | `_finishChoice()`（见 §11.5） |
| playing | choice | 升级（pendingChoices>0）或任务奖励队列非空（见 §2 步骤 4/5） |
| playing | dead | hp≤0 → `_onDeath()` |
| dead | menu | KeyR → `backToMenu()` |
| playing | extraction | Boss 波清空且 wave<25（`onBossWaveCleared`） |
| playing | summary | 第 25 波 Boss 清空 → `_finishRun(true)`（不经过 extraction） |
| extraction | summary | KeyE / 点击"撤离" → `chooseExtraction(true)` → `_finishRun(false)` |
| extraction | playing | KeyC / 点击"继续" → `chooseExtraction(false)` → `state='playing'` + `waveDirector.beginRest()` |
| summary | menu | Enter / 点击"返回主菜单" |

### 1.3 关键流程函数

**`onBossWaveCleared()`**（Boss 波结束）：
1. `enemies.length = 0`（清空全场敌人）；`hostileProjectiles.length = 0`。
2. `rollBossDrops(bossesDefeated)` → 掉落物放入 `tempBackpack`（临时背包，见 §15）。
3. wave ≥ 25 → `onFinalWaveCleared()` → `_finishRun(true)`；否则 `state = 'extraction'`。

**`_finishRun(completed)`**：
1. `darkCrystals += round(wave × 1.5)`（waveRewardMult）。
2. `tempBackpack` 全部转入 `save.storage`，然后临时背包清零 `{shard:0, essence:0, soulCrystal:0}`。
3. `stats.extractions++`；completed 为真时 `stats.completions++`；`bestWave = max(bestWave, wave)`。
4. `persistSave()`；写 `lastRunSummary = {completed, wave, kills, level, bossesDefeated, elapsed, darkCrystalsGained, itemsBanked}`；`state = 'summary'`。

**`_onDeath()`**：
1. `lastDeathLoss = {...tempBackpack}`（记录本局损失，用于死亡界面展示）。
2. `tempBackpack` 清零（死亡 = 临时背包全损；仓库不受影响）。
3. 更新 `bestWave`；`persistSave()`；`state = 'dead'`。

**`reset()`**：清空一局内的全部运行时状态（玩家、敌人、武器、attrStacks、宝石、拾取、任务、联动等）；`metaStacks = {...save.metaLevels}`（局外属性每级等效 1 层属性卡）。DebugRuntime 独立于 reset 存活，并在 `onGameReset` 时重新应用其设置。

---
## 2. 主循环与 update 顺序

### 2.1 循环结构

- 固定步长 `STEP = 1/60` 秒（60Hz 逻辑帧）。
- 帧驱动：每帧 `frameDt = min(0.25, 实际帧间隔)`，累加器累计；只要累加器 ≥ STEP 就执行一次 `game.update(STEP, viewW, viewH)` + `input.endFrame()`。
- 渲染每帧执行，与逻辑帧解耦。
- `viewW / viewH` 未指定时回退 **1280 × 720**。
- F2 切换调试面板；`globalThis.__game` 暴露游戏实例（供控制台调试）。

### 2.2 `update(dt)` 内部顺序（必须严格保持）

1. 若 state ∈ {menu, shop, storage, extraction, summary}：执行对应 update 分支后 **return**。
2. 若 state ∈ {opening, choice}：只执行 `_handleChoice()`（含开局选卡）后 **return**。
3. 若 state == dead：KeyR → 返回主菜单；**return**。
4. `pendingTaskRewards` 非空：取出队首 → 进入 choice（origin 'task'）；**return**。
5. `pendingChoices > 0`：`generateOffers()`；池为空 → `pendingChoices = 0`（留在 playing）；否则进入 choice（origin 'levelup'）；**return**。
6. `_handleWeaponBuildClick()`（武器槽点击，切换联动作战选择；在调试暂停检查之前，因此暂停时仍可操作）。
7. 调试暂停（debug.paused）→ **return**。
8. `elapsed += dt`。
9. `synergies.update(dt)`（公告 ttl 递减等）。
10. 重算玩家速度：`player.speed = 230 × mods.moveSpeedMult × playerMoveSpeedBonusMult()`。
11. `updatePlayer(dt)`（移动 + 拾取判定在碰撞阶段）。
12. `camera.follow(player, dt, lerp=8)`。
13. `waveDirector.update(dt)`（含 spawner）。
14. `taskDirector.update(dt)`。
15. 每个敌人：`tickStatus(e, dt)` 结算 DoT → 若 dotDamage>0 调 `damageEnemy(e, dotDamage)`（击杀归属记入 DoT）。
16. 每个敌人：`updateEnemy(e, dt)`（各类型 AI）。
17. `separateEnemies(dt)`（敌人间分离）。
18. 每把武器：`w.update(dt, world)`。
19. 更新 projectiles / hostileProjectiles / trails。
20. effects 与 corpses 的 ttl -= dt。
21. `_handleCollisions()`（敌人接触、敌方弹、我方弹）。
22. `_updateGems(dt)`。
23. `_updatePickups(dt)`。
24. 清理死亡/过期对象：enemies、projectiles、hostileProjectiles、trails、summons、gems、pickups 过滤 dead；corpses 保留 ttl>0；effects 保留 ttl>0。
25. hitShake、rareMessage 计时器递减。

> 注意：第 15 步的 DoT 伤害通过统一入口 `damageEnemy` 结算（可触发联动、记 killLog）；第 16 步敌人 AI 内部也可能调用 hurtPlayer。顺序不可交换。

---

## 3. 玩家、输入、相机

### 3.1 玩家基础属性

| 字段 | 值 | 说明 |
| --- | --- | --- |
| radius | 14 | 碰撞半径 |
| speed | 230 | 基础移速（px/s） |
| maxHp | 100 | 基础生命 |
| hurtIFrames | 0.8 | 受击无敌帧（秒） |
| color | #4fc3f7 | 原型渲染色 |

### 3.2 输入模型（input.js）

- `keydown`：若该键未处于按下状态则记入 pressed（边沿触发）；Space / 方向键 preventDefault。
- 移动轴：WASD 与方向键；对角线归一化 **÷√2**。
- `wasPressed(code)`：当帧边沿查询；`mouseClicked`：当帧单击标志。
- `endFrame()`：每个逻辑帧末尾清空 pressed 与 mouseClicked。

### 3.3 移速合成

每逻辑帧（update 第 10 步）：

```
player.speed = 230 × mods.moveSpeedMult × playerMoveSpeedBonusMult()
```

- `setPlayerMoveSpeedBonus(source, mult, duration=0.12)`：以 source 为键写入 `{multiplier, expiresAt = elapsed + duration}`；同名 source 覆盖。
- `playerMoveSpeedBonusMult()`：所有未过期条目 multiplier 连乘；过期条目惰性删除。

### 3.4 受伤

`hurtPlayer(dmg)`：
1. 调试无敌（debug.invincible）→ 跳过。
2. `dmg ×= (1 − mods.damageReduction)`。
3. `player.hurtPlayer(dmg)`：若处于无敌帧（0.8s 内）返回 false，本次不生效。
4. 生效时：`hitShake = 0.25`；`lastHurtAt = elapsed`（玉环反制等系统监听该字段变化）。
5. hp ≤ 0 → hp = 0 → `_onDeath()`。

### 3.5 相机

`camera.follow(player, dt, lerp=8)`：向玩家位置插值跟随，系数 8（`CONFIG.camera.lerp`）。正式关卡中跟随结果继续按当前视口半宽/半高约束，禁止相机显示到 4096×4096 地形之外。

### 3.6 正式关卡边界（Godot 表现正式化扩展）

- 当前正式关卡为以世界原点为中心的 4096×4096 草甸，边界 `left/top=-2048`、`right/bottom=2048`。
- 边界判定全部由 `logic/level_geometry.gd` 完成，不使用 Godot 物理节点；headless 与实际画面共享同一几何真值。
- 玩家按 `radius 14 + 视觉安全边距 36` 钳制，避免角色序列帧在屏幕边缘被裁切。
- 敌人按自身 radius 钳制；屏外刷怪点额外内收 32px。
- 玩家与敌方弹道的圆形范围一旦接触/越过边界即销毁。
- 随机任务信标、护送目的地、悬赏目标和拦截者生成点至少内收 80px。
- 地形贴图内的石块属于可行走细节；后续独立树木、岩石障碍必须在逻辑层登记几何，场景碰撞节点不能成为玩法真值。

---

## 4. 属性计算（mods / recomputeMods）

### 4.1 computeMods(attrStacks, metaStacks)

基础对象：

```
{
  damageMult: 1, xpMult: 1, moveSpeedMult: 1,
  armor: 0, damageReduction: 0, magnetRadiusBonus: 0, maxHpBonus: 0,
  // 中性兼容字段（旧存档/外部调试用，武器已不消费）：
  projectileBonus: 0, areaMult: 1, attackSpeedMult: 1, cooldownMult: 1,
}
```

- 对每张属性卡：`n = (attrStacks[id] || 0) + (metaStacks[id] || 0)`（**局外商城每级等效 1 层，加法叠加**）；n>0 时执行 `card.apply(mods, n)`。
- 最后 `damageReduction = min(0.5, armor / (armor + 100))`。

### 4.2 recomputeMods()（game.js:121）

1. `mods = computeMods(attrStacks, metaStacks)`。
2. `damageMult ×= rareBonuses.damageMult × (1 + taskBonuses.damageMult) × debug.player.damageMult`。
3. `xpMult` 同模式：`×= rareBonuses.xpMult × (1 + taskBonuses.xpMult) × debug.player.xpMult`。
4. `moveSpeedMult` 同模式：`×= rareBonuses.moveSpeedMult × (1 + taskBonuses.moveSpeedMult) × debug.player.moveSpeedMult`。
5. `armor += taskBonuses.armor + debug.player.armorBonus`。
6. `magnetRadiusBonus += taskBonuses.magnetRadiusBonus`。
7. 重算 `damageReduction = min(0.5, armor / (armor + 100))`。
8. `debug.syncPlayerMaxHp()`（保持当前 hp/maxHp 比例）。

### 4.3 宝石磁吸半径

```
gemMagnetRadius = (180 + mods.magnetRadiusBonus + rareBonuses.magnetRadiusBonus) × debug.player.pickupRangeMult
```

（180 = `CONFIG.gems.magnetRadius`；注意 rareBonuses.magnetRadiusBonus 不并入 mods，而是在此式直接相加。）

---
## 5. 伤害管线与碰撞

### 5.1 damageEnemy(e, dmg, opts) —— 唯一敌人受伤入口

opts 字段：`sourceWeaponId, sourceAction, sourceTags, synergyId, noSynergy, noSummon`。

1. `e.dead` → return。
2. 精英/Boss（rank 为 'elite' 或 'boss'）：`dmg ×= (1 + taskBonuses.eliteBossDamageMult)`。
3. `dmg = e.modifyIncomingDamage(dmg)`（shield 敌形态减伤钩子；默认原样返回）。
4. `dmg ≤ 0` → return（不产生 hitFlash、不触发联动）。
5. `e.hp -= dmg`；`e.hitFlash = 0.08`。
6. `e.hp ≤ 0` → `_killEnemy(e, opts)`。
7. `opts.noSynergy` 为假 → `synergies.onDamage(event, world)`（event 携带目标与 opts 信息）。

### 5.2 _killEnemy(e, opts)

1. `kills++`。
2. 掉落 1 颗宝石（`_dropGem`，见 §9）。
3. 精英（rank 'elite'）→ 掉 1 个稀有拾取物（除非敌人带 `suppressRareDrop` 标记，如悬赏目标）。
4. Boss（rank 'boss'）→ `bossesDefeated++`；`stats.totalBossKills++`；`persistSave()`；在 (x−14, y) 与 (x+14, y) 各掉 1 个稀有拾取物。
5. killLog 追加一条：`{id, x, y, burned: hasDot(e,'burn'), blazed: hasDot(e,'blaze'), sourceWeaponId, sourceAction, synergyId, noSynergy, noSummon}`；上限 256，超出移除最旧。
6. `taskDirector.onEnemyKilled(e)`（悬赏判定）。
7. 尸体污渍：ttl 3 秒；上限 80，超出移除最旧。

### 5.3 碰撞处理（_handleCollisions，update 第 21 步）

- **敌人接触**：`dist ≤ e.radius + 14` → `hurtPlayer(e.damage)`；hurt 生效则 `e.hitCooldown = 0.6`。
- **敌方弹道**：命中玩家即消耗（**即使玩家处于无敌帧也消耗弹体**，只是不掉血）。
- **我方弹道**：跳过已命中集合（hitSet）中的敌人 → `damageEnemy(p.damage, p.damageOptions)` → `p.onHit(e)`；穿透（pierce）→ 加入 hitSet 且 hitCount 对比 maxHits（可为 Infinity），否则 `p.dead = true`。

### 5.4 治疗

`healPlayer(v)`：hp = min(maxHp, hp + v)。来源：血玉、法杖连接、丹火九转热域、任务祝福等。

---

## 6. 状态效果（DoT / 减速 / 冻结）

### 6.1 DoT

- 类型集合 `DOT_TYPES = ['burn', 'blaze', 'bleed', 'poison']`，**互相独立**（burn 与 blaze 是两种不同效果，killLog 分别记录 burned/blazed）。
- `applyDot(e, type, dps, duration)`：**不叠层** —— `dps = max(现有, 新值)`，`timer = max(现有, 新值)`。
- `hasDot(e, type)`：`timer > 0`。

### 6.2 减速与冻结

- `applySlow(e, factor, duration)`：`slowFactor = max(旧, factor)`；`slowTimer = max(旧, duration)`。
- `applyFreeze(e, duration)`：`frozenTimer = max(旧, duration)`。

### 6.3 tickStatus(e, dt)（update 第 15 步，每敌人调用）

1. 遍历 DOT_TYPES：`timer -= dt`；timer ≤ 0 → 删除该 DoT；否则 `dotDamage += dps × dt`。
2. `slowTimer -= dt`、`frozenTimer -= dt`（不低于 0 语义由判断处理）。
3. 返回 dotDamage 总量；由游戏层统一调 `damageEnemy` 结算（保证击杀归属与联动触发一致）。

### 6.4 移速系数

`speedMultOf(e)`：frozenTimer > 0 → **0**；slowTimer > 0 → **1 − slowFactor**；否则 1。所有 moveToward / moveAwayFrom / 冲锋位移都乘该系数。

---
## 7. 敌人系统

### 7.1 EnemyBase 构造（enemy.js）

构造参数含生成时刻 `elapsed` 与类型倍率 `hpMult / speedMult / damageMult`：

```
minutes = elapsed / 60
jitter  = 1 + rand(-0.25, +0.25)        # 类型 speedVariance:false 时 jitter = 1
maxHp   = (45 + 10 × minutes) × hpMult   # hp = maxHp
speed   = 76 × jitter × (1 + 0.015 × minutes) × speedMult
damage  = (7 + 2.2 × minutes) × damageMult
```

初始字段：`hitCooldown=0, hitFlash=0, ringCd=0, dots={}, slowTimer=0, slowFactor=0, frozenTimer=0`。

- `moveToward / moveAwayFrom`：位移 × `speedMultOf(e)`。
- `tickCommon(dt)`：递减 hitCooldown / hitFlash / ringCd。
- `modifyIncomingDamage(dmg)`：默认原样返回（shield 覆写）。

### 7.2 波次成长 applyWaveScaling(e, wave)

每个敌人只应用一次（`waveScalingApplied` 标志），在 `createEnemyByType` 构造后调用：

```
step  = wave - 1
early = min(step, 5)
mid   = min(max(0, step - early), 5)
late  = step - early - mid
hpMult     = min(3, 1 + 0.10×early + 0.12×mid + 0.10×late)
damageMult = 1 + 0.06×early + 0.14×mid + 0.18×late
speedProgress = min(step, 19) / 19              # speedCapStartWave 20 → 步长上限 19
speedMult  = 1.35 + (1.6 - 1.35) × speedProgress    # baseSpeedMult 1.35 → speedWaveCap 1.6
```

应用时保持当前 hp/maxHp 比例不变（先缩放 maxHp 再按比例调整 hp）。

> CONFIG 中 `hpPerWave:0.10 / damagePerWave:0.06` 为前期段；`midWaveStart:7` 起用 `hpPerWaveMid:0.12 / damagePerWaveMid:0.14`；`lateWaveStart:12` 起用 `hpPerWaveLate:0.10 / damagePerWaveLate:0.18`；上面三段式代码即该配置的实现形态。

### 7.3 分离 separateEnemies(dt)

两两配对：若 `0.0001 < d² < (ra+rb)²`，沿连线推开，位移量 `((minD - d) / d) × 0.5 × min(1, 60×dt)`（minD = ra+rb）。

### 7.4 类型选择 chooseEnemyType（每次刷怪调用）

1. `aliveByType`：按 type 统计存活敌人。
2. `rangedWaveCap`：本波 quota 有限 → `max(1, floor(quota × 0.12))`；否则 ∞。
3. `replacementRatio`（强化追击者替换普通追击者的比例）：wave<8 → 0；wave 8 → 0.15；wave 9 → 0.35；wave 10 → 0.65；wave ≥ 11 → 1。
4. 遍历 `CONFIG.enemyTypes`，**跳过 boss 与 enhancedChaser**：
   - 遍历到 chaser：加入两个候选 —— chaser（weight × (1−ratio)）与 enhancedChaser（weight = chaser 的 62 × ratio）。enhancedChaser 配置 weight 为 0，**只通过这条拆分进入候选池**。
   - 其余类型按自身 weight 加入。
   - 每个候选的准入过滤：`weight > 0`、`elapsed ≥ unlockAt`、`alive < maxAlive`。
   - ranged 额外条件：**Boss 波不刷**、且本波 `spawnedByType.ranged < rangedWaveCap`。
5. 加权抽取：`r = rand(0, totalWeight)`，累计权重命中。
6. 候选为空 → 回退：wave ≥ 11 → enhancedChaser，否则 chaser。

`createEnemyByType(type)`：未知类型走同样回退；构造完成后调用 `applyWaveScaling`。

### 7.5 档位（rank）

| rank | 敌人 |
| --- | --- |
| normal | chaser |
| enhanced-minion | enhancedChaser、ranged、bomber |
| enhanced | charger |
| elite | shield |
| boss | boss |

elite/boss 档享受任务增伤（§5.1 步骤 2）；elite 死亡掉稀有拾取物；boss 死亡掉 2 个。

---
### 7.6 各类型行为（js/enemies/）

**chaser（追击者，normal）**：直线追击玩家；接触伤害（hitCooldown 0.6s）。

**enhancedChaser（强化追击者，enhanced-minion）**：半径 15（其余半径默认 13）。`hp ≤ maxHp × 0.5`（enrageHpRatio）时进入**预警** 0.45s（warningDuration，期间移速 ×0.3），随后**永久狂暴**：移速 ×1.5、伤害 ×1.35。

**charger（冲撞者，enhanced）**：状态机 `chase → windup → dash → recovery → chase`。
- 追击中与玩家距离 ≤ 260（chargeRange）且 chargeCooldown ≤ 0 → windup 0.65s，**锁定冲锋方向**。
- dash 0.55s（dashDuration），速度 400（dashSpeed）× speedMultOf，沿锁定方向直线位移。
- recovery 0.85s 后回到 chase，`chargeCooldown = 1.7`（cooldown）。

**ranged（远程者，enhanced-minion）**：距离保持（ε=12）：`dist > 260+12` 靠近；`dist < 170`（retreatDistance）后退；区间内不动。
- `fireCooldown` 初始即 1.7（fireInterval），归零且目标可见时射击：弹从 `半径 + 弹半径 + 3` 的枪口位置发出。
- 弹道 `{speed 175, radius 5, damage = this.damage, lifetime 4}`；射击后 shotFlash 0.16s、fireCooldown 重置 1.7。

**bomber（自爆者，enhanced-minion）**：接近至 `dist ≤ 58`（triggerDistance）→ windup；`windupTimer ≥ 0.9`（windup）→ **先置 `exploded = true`**，然后若 `dist ≤ 88`（blastRadius）调 `hurtPlayer(damage)`，生成爆炸视觉（spawnEnemyBlast，半径 88），`dead = true`。
- **被击杀 ≠ 爆炸**：引爆前被打死不会爆炸（exploded 标志防重复）。

**shield（护盾者，elite）**：`shielded`（3s）↔ `open`（1.5s）循环切换；用 while 循环一次性追平跨过的多个周期。
- `modifyIncomingDamage`：shielded 期 ×0.35（shieldDamageMult），open 期 ×1.25（openDamageMult）。
- 始终 moveToward 玩家。

**boss（暗夜领主，boss）**：半径 34（覆盖默认 13），speedVariance false（jitter=1）。
- `attackCooldown` 初始 1.6s。攻击流程：windup 0.85s → 环形弹幕：弹数 12（狂暴 18）、弹速 180（狂暴 205）、弹半径 7、弹存活 5s、伤害 = boss.damage × 0.72、角度偏移 = 当前 rotation；附带爆炸视觉效果（半径 = 弹半径 × 2.4，ttl 0.45s）。
- 下次攻击间隔 = 2.9（attackInterval）× (狂暴 ? 0.72 : 1)。
- 狂暴（hp ≤ 50%）：旋转速度 1.25 → 2.2；移动速度 ×1.2。

### 7.7 敌方弹道（hostile-projectile.js）

`spawnHostileProjectile` 默认值：`{speed 150, radius 5, damage 6, lifetime 4}`（调用方可覆盖，如 boss/ranged）。直线飞行；lifetime 倒计时归零死亡；命中玩家即消耗（见 §5.3）。

---

## 8. 波次与刷怪器

### 8.1 Spawner（spawner.js）

- 刷怪间隔：`requestedInterval = options.spawnInterval ?? (startInterval − (wave − 1) × 0.12)`；`interval = max(0.14, requestedInterval) × intervalMult`（intervalMult 下限 0.01）。
- 存活上限：`maxAlive = aliveCap ?? min(180, 40 + (wave − 1) × 12)`。
- `spawnLimit`（默认 ∞）；调试 `spawn.paused` → 不刷。
- update：`while timer ≤ 0 && spawned < limit`：存活 ≥ maxAlive → `timer = 0` 并跳出；否则 `timer += interval`，按 `forceType ?? chooseEnemyType()` 生成。
- **生成位置（环形边缘）**：以相机为中心，半边长 `viewW/2 + 80` / `viewH/2 + 80` 的矩形框（margin 80）；随机取 4 边之一（floor(rand(0,4))），`t = rand(−1,1)` 在该边上线性取点。

### 8.2 WaveDirector（systems/waves.js）

初始：`wave = 1, phase = 'wave', waveTimer = 90, bannerTimer = 2.4`。

**配额（quota）**：`quota = round(30 × quotaMult)`
- 普通波：`quotaMult = min(14, 1 + (wave − 1) × 1.2)`。
- Boss 波（wave % 5 == 0）：`quotaMult = (1 + reinforcements) / 30`；reinforcements：wave 5 → 4；wave 10 → 6；其余 → `min(12, 6 + floor((wave − 10) / 5) × 2)`。
- `spawnInterval = 90 / max(1, quota − (isBossWave ? 1 : 0))`（90 = 波时长）。
- 调试 `spawn.quotaMult` 生效方式：`quota = max(spawned, round(baseQuota × quotaMult))`，Boss 波最低 1。

**update(dt)**：
1. `bannerTimer -= dt`。
2. phase 'rest'：`restTimer -= dt`，归零 → `_startNextWave()`。
3. phase 'overtime'：Boss 已死 → `game.onBossWaveCleared()`。
4. phase 'wave'：`waveTimer = max(0, waveTimer − dt)`。

**普通波流程**：
- `wave % 3 == 0`（eliteEvery）→ 波开始先强制刷 1 只 shield（精英保底；spawned++，timer = spawnInterval）。
- 其余按 spawnInterval 节奏刷怪；`waveTimer ≤ 0` → 进入下一波（**存活敌人延续，不清场**）。

**Boss 波流程（wave % 5 == 0）**：
- 波开始先刷 Boss（spawned = 1，timer = spawnInterval）。
- 增援全部 `forceType = 'enhancedChaser'`。
- `timer ≤ 0 && bossSpawned`：Boss 存活 → phase 'overtime'（banner 重置）；Boss 已死 → `onBossWaveCleared()`。

**波推进**：
- `_startNextWave()`：wave ≥ 25 → `game.onFinalWaveCleared()`；否则 `startWave(wave + 1)`（spawner.timer = 0，立即开始刷）。
- `beginRest()`（撤离界面选"继续"后）：phase 'rest'，restTimer = 3.5（restDuration），banner 重置。

---
## 9. 宝石、经验与升级

### 9.1 宝石（gems.js）

- 品阶按 `elapsed` 判定：`< 90s` → tier 1（value 1，#5ac8fa）；`< 180s` → tier 2（value 2，#66bb6a）；否则 tier 3（value 3，#ff8a65）。
- 生成：散射角 `rand × 2π`，初速 `20 + rand × 35`。
- **磁吸为锁定式**：`dist² ≤ magnetRadius²`（§4.3）时置 `magnetized = true`，并记录 `magnetSpeed = max(300, 当前速度)`；之后 `speed = min(680, speed + 900 × dt)`，速度方向持续指向玩家。
- 未磁吸时摩擦：`speed ×= max(0, 1 − 5 × dt)`。
- 拾取：`dist² ≤ 22²`（pickupRadius，× debug.player.pickupRangeMult）→ `gainXp(value)`。
- 总数上限 300：超出时**自动收取最旧的一颗**（走 gainXp）。

### 9.2 经验与升级

```
gainXp(v):
  若 applyMultiplier 不为 false: v ×= mods.xpMult
  while xp ≥ xpToNext(level):
      xp -= xpToNext; level++; pendingChoices++
  xpToNext(level) = 6 + (level − 1) × 4     # CONFIG.xp.base=6, perLevel=4
```

- 每次升级 pendingChoices +1；选卡在 update 第 5 步统一进入 choice 状态（世界暂停）。
- 调试 `grantXp` 使用 `applyMultiplier: false`。

---

## 10. 拾取物与稀有物品

### 10.1 生命拾取

- 恢复 15（hpValue）；拾取半径 22；hp 类拾取同屏上限 5（maxAlive）。

### 10.2 稀有拾取物（rare-items.js）

- 拾取半径 30；拾取 → `applyRareItem` + 中央提示 rareMessage（ttl 3.5s）。
- 5 种，**等概率**（`floor(rand × 5)`）：

| id | 效果 |
| --- | --- |
| warRune | `rareBonuses.damageMult ×= 1.2` |
| bloodJade | maxHp + 25 并立即治疗 25 |
| magnetCore | `rareBonuses.magnetRadiusBonus += 80` |
| spiritBook | `rareBonuses.xpMult ×= 1.25` |
| windFeather | `rareBonuses.moveSpeedMult ×= 1.1` |

- 拾取后 `rareInventory[id]++` 并 `recomputeMods()`。
- 掉落来源：精英 1 个、Boss 2 个（x±14，见 §5.2）。

---

## 11. 卡牌系统

### 11.1 约束

- 武器槽上限 3（maxWeaponSlots）；每次选择展示 3 张（choicesCount）；属性卡叠层上限 5（attrMaxStack）。

### 11.2 开局选卡

`openingOffers()` = 全部 6 张武器卡，type 均为 'new'（不随机，任选其一）。

### 11.3 升级候选池 generateOffers(game)

1. 已持有武器的升级卡（`level < maxLevel`）。
2. 新武器卡：**仅当 `weapons.length < 3`** 时加入未持有的武器卡。
3. 未叠满（<5）的属性卡。
4. Fisher-Yates 洗牌（Math.random），取前 3 张；池为空 → `pendingChoices = 0`（不进入选卡）。

### 11.4 应用选项 _applyOffer

- 任务奖励 offer：执行 `offer.apply(game)`（见 §14.6）。
- 武器 type 'new'：`card.create(game)` 入槽。
- 武器 type 'upgrade'：`weapon.level++`（不超 maxLevel），随后 `synergies.refresh(weapons, elapsed)`。
- 属性卡：叠层达 5 时忽略（直接返回）；否则层数 +1、`card.onAcquire(game)`（maxHp 卡触发 increaseMaxHp(20, 20)）、`recomputeMods()`。

### 11.5 结束选卡 _finishChoice(origin)

1. origin 'levelup' → `pendingChoices--`。
2. `pendingTaskRewards` 非空 → 立即弹出下一个任务奖励进入 choice（origin 'task'）。
3. 否则 `pendingChoices > 0` → 重新 generateOffers（为空 → pendingChoices = 0 → playing），留在 choice。
4. 否则 → `state = 'playing'`。

### 11.6 输入与布局

- 键盘：Digit1–9 / Numpad1–9 优先于鼠标。
- 卡牌矩形 `getCardRects(viewW, viewH, count)`：
  - ≤3 张：210 × 292，间距 24，`y = (viewH − 292)/2 + 8`，整行水平居中。
  - >3 张：两行 200 × 252，间距 24，第二行水平居中。
- 武器槽矩形 `getWeaponSlotRects`：pad 14，槽 46 × 52，间距 8，`y = 8 + 30 + 14 + 32 = 84`；点击切换联动作战选择（`toggleBuildWeapon`，见 §13.3）。

### 11.7 属性卡（6 张，叠层 ≤5）

n = 局内层数 + 局外等级（§4.1），apply 效果：

| id | 效果 |
| --- | --- |
| damage | damageMult +0.15 × n |
| armor | armor +15 × n |
| magnet | magnetRadiusBonus +50 × n |
| xp | xpMult +0.15 × n |
| maxHp | maxHpBonus +20 × n；onAcquire 时 increaseMaxHp(20, 20)（加 20 上限并治疗 20） |
| moveSpeed | moveSpeedMult +0.06 × n |

---
## 12. 武器系统（6 种 × 6 级）

### 12.0 通用约定

- 每把武器状态 `{id, level}`；每帧 `w.update(dt, world)`（update 第 18 步）。
- 注入的 `world` 上下文（game._world()）字段：
  `player, enemies, projectiles, hostileProjectiles, trails, summons, effects, weapons, synergies, mods, elapsed, kills, killLog, hasSynergy(id), getWeapon(id), recordSynergyTrigger, damageEnemy, hurtPlayer, spawnHostileProjectile, spawnEnemyBlast, healPlayer, setPlayerMoveSpeedBonus, dropPickup, applyDot, applySlow, applyFreeze, hasDot`。
- 所有武器 maxLevel = 6；等级数值以 CARD.levels 为唯一真值（下表逐字抄录）。

### 12.1 sword 道剑

| Lv | damage | 其他关键字段 |
| --- | --- | --- |
| 1 | 16 | 近战：meleeRange 125，interval 1.15，arc 120° |
| 2 | 20 | 转弹道：range 520，speed 500，interval 1.08，穿透 ∞ |
| 3 | 26 | range 550，speed 560，interval 1.00 |
| 4 | 32 | range 570，speed 580，interval 0.94；drawSlash，ringRadius 350，ringBleedDps 10 |
| 5 | 40 | range 600，speed 620，interval 0.87；drawSlash，ringRadius 380，ringBleedDps 11 |
| 6 | 48 | range 640，speed 660，interval 0.80；drawSlash，ringRadius 344，ringBleedDps 12；swordIntent，flyMax 10，flyInterval 1.2，flyRange 260，flyChain 6，flyChainRange 240 |

机制：
- Lv1 近战扇形挥砍；Lv2+ 发射弹道（弹半径 11，maxHits = Infinity 无限穿透）。
- **drawSlash（Lv4+）**：每命中 **3 次命中**（空挥不计，attackCount 只在命中时 +1）→ 下一帧释放环形斩：伤害 ×2.5，半径 ringRadius，附带流血 DoT（dps = ringBleedDps，持续 2.5s）。
- **swordIntent（Lv6）**：每命中 10 次生成 1 把飞剑；**飞剑自身命中不计数**（countIntent = false）。飞剑：环绕半径 `48 + (n%3) × 12`，存活 15s，出击速度 640，伤害 ×0.3，命中附流血（dps 9，2.5s）；连锁 ≤6 次，优先 240px 内未命中过的目标；飞行总距离 > 1600 或离目标 > 460 时强制返回；返回速度 700。
- 联动常量：御剑号令标记 3s；焚刃火焰斩 cd 0.4 / 伤害 ×0.4 / 长 145 / 宽 34；剑环折返触发距离 52 / 搜索 360；切炉伤害 ×0.45。

### 12.2 cloak 炽热披风

| Lv | damage | radius | burn(dps) | 其他 |
| --- | --- | --- | --- | --- |
| 1 | 5 | 145 | — | — |
| 2 | 7 | 165 | 10 | — |
| 3 | 10 | 185 | 12 | — |
| 4 | 12 | 205 | 14 | shock：cd 5.5，ticks 6，radMult 1.7 |
| 5 | 15 | 225 | 16 | shock：cd 5.2，ticks 6，radMult 1.7 |
| 6 | 18 | 250 | 16 | shock：cd 3，ticks 6，radMult 1.8；shockSlow；enhancedKillShock |

机制：
- 光环每 **0.5s** tick 一次，对半径内敌人造成 damage；Lv2+ 附带 burn（2s）。
- **shock（Lv4+）**：冲击伤害 = damage × ticks + 附带 burn；命中减速 0.3，2s（Lv6 shockSlow 强化变体）。
- **enhancedKillShock（Lv6）**：每 100 次击杀追加一次强化冲击（半径 ×1.8、8 ticks、减速 3s），**不重置普通 shock 的冷却**。
- 共享常量：DEFAULT_BURN_DPS = 12，BURN_DURATION = 2。

---
### 12.3 talisman 雷符咒

| Lv | damage | interval | speed | range | 特性 |
| --- | --- | --- | --- | --- | --- |
| 1 | 12 | 1.0 | 460 | 520 | — |
| 2 | 15 | 0.95 | 460 | 520 | thunder |
| 3 | 19 | 0.88 | 460 | 520 | thunder |
| 4 | 23 | 0.81 | 460 | 520 | chain，bounces 2 |
| 5 | 27 | 0.75 | 460 | 520 | chain，bounces 2 |
| 6 | 31 | 0.70 | 490 | 550 | thunderFirst，thunderAoE，chain，bounces 3 |

机制：
- 弹道半径 5；`lifetime = range / speed + 0.3`。
- **thunder**：落雷伤害 = damage × 1.5；每目标 2 次命中计数器（WeakMap 实现，目标死亡/离场即失效，不得跨目标泄漏）。
- **thunderFirst（Lv6）**：每波第一击必定落雷。**thunderAoE（Lv6）**：落雷附带半径 95 的范围伤害。
- **chain（Lv4+）**：弹命中后跳跃，链伤 ×0.5；搜索半径 **180px**（代码 `R2 = 180×180`；注释中的 160 为过时值，见附录 B）；最多 bounces 次命中；玉环环体/尸体可作为中继点（各计一次，**不消耗跳跃次数**）。
- `triggerSwordThunder`（联动用）：伤害 ×0.6，携带 noSynergy / noSummon。

### 12.4 trail 丹火

| Lv | damage | radius | life | drop间隔 | 特性 |
| --- | --- | --- | --- | --- | --- |
| 1 | 7 | 40 | 3.5 | 0.22 | — |
| 2 | 10 | 44 | 4.5 | 0.22 | burn 12 |
| 3 | 14 | 48 | 5.5 | 0.18 | burn 14 |
| 4 | 16 | 52 | 7.0 | 0.18 | furnace，furnaceLife 6 |
| 5 | 21 | 57 | 8.5 | 0.18 | enhancedFurnace，furnaceLife 7.5 |
| 6 | 26 | 62 | 10.0 | 0.18 | nineTurn，furnaceLife 9，hotZoneLife 5 |

机制：
- 火径每 **0.4s** tick 一次，对半径内敌人造成 damage 并施加 **blaze** DoT（dps = burnDps，2s）；Lv2+ 另附 burn。
- 滴落条件：玩家必须在移动；两次滴落间隔 > 0.7s 则重置路径；路径点上限 PATH_POINT_CAP = 180。
- **闭环成炉判定**：首尾闭合 ≤ 55px、路径年龄 ≥ 1.2s、点数 ≥ 4、周长 ≥ 260、面积 ≥ 9000、成炉冷却 1.5s。
- **furnace（Lv4+）**：持续 furnaceLife（6 / 7.5 / 9；常量 FURNACE_DURATION = 4.5 仅作兜底）；tick 0.4s，伤害 ×1.25；点火延长 ×4；吸引强度 25（核心 +65）；燃料：击杀 +1，精英/Boss 每 1s +1；燃料达 9 **开炉**：伤害 ×6、life = min(8, life+2)、openCd 0.75、maxOpens 1（Lv5 enhanced 为 2）。
- **nineTurn（Lv6）**：九转热域伤害 = damage ×1.25 ×1.5，持续 hotZoneLife 5s；玩家在域内每 0.5s 回复 1 hp，移速 ×1.12（0.12s 刷新）。
- 对象上限：trails 80、furnaces 6、热域 8、切炉区 8（life 2.2，tick 0.35，半宽 24）、effects 16。

---
### 12.5 ring 玉环

| Lv | damage | count | orbit | speed | 特性 |
| --- | --- | --- | --- | --- | --- |
| 1 | 12 | 2 | 56 | 2.6 | — |
| 2 | 16 | 2 | 66 | 2.8 | coldJade |
| 3 | 20 | 3 | 78 | 3.0 | — |
| 4 | 26 | 4 | 92 | 3.3 | bloodDrop，expand 80 |
| 5 | 32 | 5 | 106 | 3.6 | expand 95 |
| 6 | 40 | 6 | 120 | 4.0 | expand 110，ultimate，counterDamage 200，counterRadius 300，counterCd 16 |

机制：
- 环体接触判定半径 RING_RADIUS = 42；每敌人共享命中冷却 RING_HIT_COOLDOWN = 0.34s；同一帧一个环只命中一个敌人一次。
- 伤害倍率：狂暴 ×2、扩张 ×2（可叠乘至 ×4）。
- **coldJade（Lv2+）**：命中施加 applySlow(0.35, 1.6)。
- **bloodDrop（Lv4+）**：呼吸周期 3.2s，扩张/收缩各 1s（扩张量 expand），狂暴时呼吸速度 ×2。
- **Lv6 狂暴**：每 50 次击杀（FRENZY_KILL_STEP = 50）触发 4s 狂暴（dropT 重置）。
- **Lv6 反制**：监听 `lastHurtAt` 变化且 cd 就绪 → 冻结攻击者 2s + 以 counterRadius 300 范围造成 counterDamage 200 × damageMult 伤害；cd = counterCd 16（字段缺省回退：damage 130 / radius 240 / cd 16）。
- 丹炉充能爆发：CHARGED_BURST_RADIUS = 55，伤害 ×0.75。

### 12.6 staff 死灵法杖

| Lv | damage | count | life | cd | speed | leash | 特性 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 7 | 1 | 6 | 4 | 170 | 260 | — |
| 2 | 9 | 2 | 6.8 | 3.6 | 180 | 260 | poison |
| 3 | 12 | 2 | 7.5 | 3.2 | 190 | 260 | — |
| 4 | 14 | 2 | 8.2 | 2.8 | 200 | 260 | blast，blastRadius 85 |
| 5 | 17 | 3 | 9 | 2.5 | 210 | 260 | blastRadius 125 |
| 6 | 20 | 3 | 9.8 | 2.2 | 220 | 280 | nightParade，blastRadius 125 |

机制：
- 召唤槽状态机：`cd → ready（需要 leash 内有敌人）→ active`；首个槽初始 cd 0.5。
- 召唤体半径：night 17 / corpse 12 / normal 11；接触距离：night 22 / normal 14 + 目标半径；hitTimer 0.5s；night 形态伤害 ×1.5。
- **poison（Lv2+）**：POISON_DPS 8，POISON_DUR 3s，溅射半径 50。
- **blast（Lv4+）**：伤害 ×2，半径 blastRadius（CARD 数值 85 / 125 为准；Lv4 卡面注释"半径 70"过时，见附录 B），携带 noSummon。
- **nightParade（Lv6）**：从 killLog 转化亡灵 —— CONVERT_CHANCE 0.2，保底 PITY_KILLS 10，尸体形态存活 CORPSE_LIFE 10s；上限 REGULAR_CAP 3 / CORPSE_CAP 5 / TOTAL_CAP 8（超限替换最旧）。
- **连接回复**：`min(2, 1 + 0.5 × (存活召唤数 − 1))` HP/s（封顶 2，见附录 B）。
- night 增益：NIGHT_DMG_MULT 1.5，NIGHT_SPD_MULT 1.3。
- 联动常量：鬼火半径 55、tick 0.5、伤害 ×0.35、残留 0.5s；尸火燃料 1.5；护法玉守卫上限 min(2, 玉环数量, 存活召唤数)、轮换 2.4s、接触减速 0.35/1.6s、环绕半径 25 / 光环 34。

---
## 13. 联动（Synergy）系统

### 13.1 15 组联动（全部 implemented: true，minLevel 4）

pairKey = 两个武器 id 排序后以 `+` 连接。

| pairKey | id | 名称 |
| --- | --- | --- |
| sword+talisman | sword-talisman-mark | 雷剑引雷 |
| sword+ring | sword-ring-return | 剑环折返 |
| sword+cloak | sword-cloak-flame | 焚刃 |
| sword+trail | sword-trail-cut | 切炉 |
| sword+staff | sword-staff-command | 御剑号令 |
| ring+talisman | talisman-ring-relay | 雷环中继 |
| cloak+talisman | talisman-cloak-burst | 雷火震荡 |
| talisman+trail | talisman-fire-alchemy | 雷火炼化 |
| staff+talisman | talisman-staff-corpse-relay | 尸雷跳板 |
| cloak+ring | ring-cloak-burning | 灼热玉环 |
| ring+trail | ring-trail-charge | 蓄炉玉 |
| ring+staff | ring-staff-guardian | 护法玉 |
| cloak+trail | cloak-trail-core | 内外火域 |
| cloak+staff | cloak-staff-ghostfire | 鬼火护卫 |
| staff+trail | trail-staff-corpse-fire | 尸火炼丹 |

### 13.2 激活判定 refresh(weapons, elapsed)

- 签名 = 各武器按 id 排序的 `${id}:${level}` 拼接 + `#${selectedPairKey}`；与上次相同 → 返回 false（不重算）。
- 激活条件：pair 中两把武器都持有且等级 ≥ 4（minLevel）。
- `selectedPairKey`（玩家手动指定的作战）非空时，**只保留该组**激活。
- 新激活 → 公告 `{text: '联动激活·' + name, ttl: 3}`。

### 13.3 作战选择 toggleBuildWeapon(id)

- 选中列表最多 2 把；超过 2 把移除最旧；每次切换强制 refresh；公告 ttl 2.5。
- 入口：武器槽点击（§11.6），在 update 第 6 步处理（调试暂停时也可用）。

### 13.4 onDamage(event, world)

入口过滤：`sourceWeaponId == 'talisman'` 且 `sourceTags` 含 `'lightning'` 且非 noSynergy。其余 13 组联动的效果在各武器内部通过 `hasSynergy(pairKey)` 自行实现。

- **talisman-cloak-burst 雷火震荡**：sourceAction 'thunder' + 目标 burn 剩余 > 0 + 该目标独立 cd（synergyCooldowns.talismanCloakBurst）0.9s 就绪 → 半径 80 AoE 伤害 ×0.45（noSynergy / noSummon）；生成效果 'synergyBurst'（lightningFire，ttl 0.32）。
- **talisman-fire-alchemy 雷火炼化**：sourceAction 'thunder' → 充能 2；'chain' → 充能 0.75；全局 cd 0.18s；调用 `trail.chargeFurnaceAt(目标位置)`，伴随 arc + burst 特效。

### 13.5 运行时查询

`synergies.getRuntime(pairKey)` 提供 `active / triggerCount` 等（smoke 用）；`recordSynergyTrigger` 由武器侧调用累计。

---

## 14. 任务系统（systems/tasks.js）

### 14.1 触发

- 任务波：`[3, 8, 13, 18, 23]`，tier = 波在数组中的下标 + 1（1~5）。
- 波开始同步时抽取 `triggerAt = randomRange(rng, 35, 45)`（triggerWindow）；phase 'wave' 且本波已过时间 ≥ triggerAt 时发布。

### 14.2 发布与接单

- 类型：从 guard / delivery / bounty 中随机（**排除上一次的任务类型** lastTaskType）。
- 信标点 = `pointAround(player, 300~440)`（beaconDistance）；state 'offered'，offerRemaining = 12s。
- 接单：在信标半径 60（beaconRadius）内累计站 1s（acceptDuration）；**离开进度清零**。
- 12s 未接 → result 'expired'。

### 14.3 guard 守卫

- 圆心 = 信标点；tier 对应：duration [18,20,22,24,26]，radius [130,125,120,115,110]，leaveGrace [1,1,0.9,0.9,0.8]。
- 出圈累计超过 leaveGrace → 失败；remaining ≤ 0 → 成功。

### 14.4 delivery 递送

- 目的地 = `pointAround(信标点, tier 距离)`，距离区间 [[1500,1750],[1600,1850],[1700,1950],[1800,2050],[1900,2200]]。
- 时限 [22,22,21,21,20]；进入目的地半径 72 → 成功；超时失败。
- 拦截者：每 tier 间隔 [6,5.5,5,4.5,4] 秒生成一波，数量取区间 [[1,2],[2,2],[2,2],[2,3],[3,3]] 内随机整数；类型：tier ≤1 → chaser，≤3 → enhancedChaser，否则 charger；生成在玩家周围 240~340。

### 14.5 bounty 悬赏

- 目标类型：tier 1 → enhancedChaser；tier 2 → 50/50 enhancedChaser|charger；tier 3+ → 50/50 charger|shield。
- 生成在玩家周围 450~650；hp × [2.5,3,3.5,4,4.5]、伤害 × [1.1,1.15,1.2,1.25,1.3]；时限 [40,40,38,38,36]。
- 目标标记 `taskId / taskRole='bountyTarget'`、`suppressRareDrop`、名称"悬赏目标"；`onEnemyKilled` 匹配 → 成功；超时 → 移除目标并失败。

### 14.6 失败条件与奖励

- 任务进行中切波 / phase 变化 → 失败；offered 状态切波 → expired。结果展示 resultDuration 3.5s。
- 成功 → `generateTaskRewardOffers(game, rng)` → `game.queueTaskReward`（pendingTaskRewards 队列，在 update 第 4 步弹出）。
- 奖励池 3 张（`removeAtRandom` 随机删到剩 3）：
  - 类别权重：weapon 0.4 / stat 0.35 / blessing 0.25。
  - weapon：已持有未满级武器升级；或槽位 <3 时的新武器。
  - stat 固定 6 种（写入 taskBonuses 并 recomputeMods）：damageMult +0.3 / armor +30 / magnetRadiusBonus +100 / xpMult +0.3 / maxHp +40 并治疗 / moveSpeedMult +0.12。
  - blessing 5 种（taskBlessings Set 去重）：hunter（eliteBossDamageMult +0.25）、tenacity（armor +20 且 maxHp +25 治疗）、swift-hunt（speed +0.1 且 magnet +80）、insight（xp +0.25 且 damage +0.1）、battle-spirit（damage +0.2 且 speed +0.06）。

### 14.7 随机数辅助

- `clampRandom`：钳制到 [0, 0.999999]；`randomInt(min,max)` = `floor(randomRange(min, max+1))`（闭区间）。
- 任务系统使用可注入 rng（smoke 中以常量函数覆盖）。

---
## 15. 局外 Meta（掉落 / 商城 / 仓库 / 存档）

### 15.1 材料

| id | 名称 | tier | 卖价 |
| --- | --- | --- | --- |
| shard | 碎片 🔹 | 1 | 5 |
| essence | 辉光精华 ✨ | 2 | 20 |
| soulCrystal | 灵魂结晶 💎 | 3 | 80 |

### 15.2 Boss 掉落 rollBossDrops(bossTier)

**随机数调用顺序是规则的一部分，移植必须严格一致：**

1. `r1 = rng()`；`r1 ≥ dropChance` → 返回空（不掉）。
2. `tierKey = clamp(bossTier, 1, 5)`；`[min, max] = dropCount[tierKey]`；`count = min + floor(rng() × (max − min + 1))`。
3. 逐件：`itemTier = rollWeightedTier(tierWeights[tierKey])`；`itemTier = max(itemTier, minTierFor(bossTier))`；取该 tier 对应材料。

参数：
- `dropChance = min(0.08 + 0.03 × (tier − 1), 0.20)`，其中 tier = max(1, bossTier)。
- `tierWeights`：1→[100,0,0]，2→[70,30,0]，3→[45,45,10]，4→[25,45,30]，5→[10,40,50]（权重对应 [T1,T2,T3]；5 阶及以上 Boss 一律用第 5 档）。
- `dropCount`：1→[1,1]，2→[1,1]，3→[1,2]，4→[1,2]，5→[2,2]。
- `minTierFor`：guaranteedMinTier {3:2, 5:3} 中取 ≤ bossTier 的最大键（1~2 阶无保底即 1）。
- 掉落物进入 `tempBackpack`；撤离/通关才入仓库，死亡全损（§1.3）。

### 15.3 商城（meta/shop.js）

- 属性列表 SHOP_ATTRS = ['damage','armor','magnet','xp','maxHp','moveSpeed']，与 save.metaLevels 键一一对应。
- 满级 10（shopMaxLevel）；`canBuy = level < 10 && darkCrystals ≥ priceForLevel(level + 1)`。
- `priceForLevel(k) = round(20 × 1.6^(k − 1))`（k < 1 → 0）。价格表：L1 20、L2 32、L3 51、L4 82、L5 131、L6 210、L7 336、L8 537、L9 859、L10 1374。
- 购买效果：metaLevels[attr] +1，局内按"每级等效 1 层属性卡"生效（§4.1）。

### 15.4 仓库

- `sellStorageItem(id)`：按 sellPrice 卖出该材料**全部**数量。
- `sellAllStorage()`：按 META_ITEM_LIST 顺序依次卖出。

### 15.5 存档（meta/save.js）

- 存储键 `'ai-roguelike-meta-save-v1'`（localStorage），内存 memoryBackup 兜底（Godot 移植为 user:// JSON，见 PORT_PLAN）。
- 默认结构：

```
{
  version: 1,
  darkCrystals: 0,
  storage: { shard: 0, essence: 0, soulCrystal: 0 },
  metaLevels: { damage: 0, armor: 0, magnet: 0, xp: 0, maxHp: 0, moveSpeed: 0 },
  stats: { runs: 0, extractions: 0, completions: 0, bestWave: 0, totalBossKills: 0 },
}
```

- `mergeInto` 深合并：只保留默认结构中存在的字段；`version` 必须等于 1，否则视为无效存档。
- persistSave 时机：开局、Boss 击杀、死亡、结算、商城购买、卖出。

---

## 16. 调试系统（原型形态；Godot 形态见 PORT_PLAN M6）

### 16.1 DebugRuntime（debug-runtime.js）

- **独立于 game.reset() 存活**，`onGameReset` 时重新应用。
- settings 结构：

```
{
  paused, invincible,
  player: { damageMult, xpMult, moveSpeedMult, maxHpMult, pickupRangeMult, armorBonus },
  enemy:  { hpMult, damageMult, speedMult },
  spawn:  { quotaMult, aliveCap, intervalMult, paused },
}
```

- 生效位置：damageMult/xpMult/moveSpeedMult/armorBonus → recomputeMods（§4.2）；maxHpMult → syncPlayerMaxHp（保持 hp 比例）；pickupRangeMult → 宝石/拾取半径；enemy 三项 → applyEnemyMultipliers（每敌人隐藏基值符号，保持 hp 比例）；spawn 四项 → WaveDirector/Spawner（§8）。
- API：`setWeaponLevel(id, level)`（level 0 = 移除武器；记忆基线等级便于还原）；`grantXp(v)`（applyMultiplier: false）；`setWave(n)`（clearEnemies + startWave）；`serialize() / applySerialized()`（version 1）。

### 16.2 DebugPanel（debug-panel.js）

- DOM 面板，F2 切换；打开时自动 `paused = true`；持久化键 `'ai-roguelike.debug.v1'`；200ms 刷新。
- 控制台入口：`__game.debug`。

---
## 17. 渲染、HUD 与 UI 布局

> 本节描述原型的呈现契约。Godot 移植第一阶段用程序化占位渲染复刻**布局与信息**，美术后补（见 PORT_PLAN）。

### 17.1 场景渲染

- Canvas 2D；背景 #0e0e16；网格 gridSize 64。
- hitShake：屏幕抖动计时器（受击置 0.25）。
- 尸体污渍、特效（effects）按 ttl 淡出。

### 17.2 HUD（hud.js）

| 元素 | 规格 |
| --- | --- |
| 经验条 | 顶部整屏宽，高 8px；左侧 Lv 数字 |
| 生命条 | 220 × 14 |
| 武器槽 | 左上，矩形见 §11.6；被选中的联动作战高亮；作战连线 |
| 稀有物品栏 | 拾取过的稀有物品计数 |
| 时间 | 顶部居中（elapsed） |
| 波次状态 | rest / overtime / boss / normal 文案 |
| Boss 血条 | y = 78，宽 min(520, viewW × 0.54) |
| 右侧信息 | 击杀数 / 存活敌人数 / Boss 状态 |
| Banner | bannerTimer > 0 时绘制；alpha = min(1, timer × 1.5) |
| 中央消息 | rareMessage ?? synergies.announcement；alpha = min(1, ttl × 2, (maxTtl − ttl) × 4) |
| 临时背包 | 右下角（本局 shard/essence/soulCrystal） |
| 操作提示 | 左下角 |

字体：`16px "Segoe UI", "Microsoft YaHei", sans-serif`（CONFIG.hud.font）。

### 17.3 Meta 界面（ui/meta-screens.js）

- 按钮统一 240 × 52，纵向间距 18，水平居中。
- menu：开始游戏 / 商城 / 仓库（Enter 或 Space 也可开始）。
- shop：每项一行（名称、等级、价格、购买按钮）；余额不足/满级不可购；Escape 返回。
- storage：每项一行（数量、卖价、卖出按钮）+ 全部卖出；Escape 返回。
- extraction：撤离（KeyE）/ 继续深入（KeyC）+ 点击。
- summary：本局结算（lastRunSummary 各字段）+ 返回主菜单（Enter / 点击）。
- dead：损失展示（lastDeathLoss）+ KeyR 返回主菜单。

---

## 附录 A：CONFIG 全量（已并入 BALANCE.md）

> **本附录已重定向**：全量数值配置表于 2026-08-15 全量并入 `BALANCE.md`（Godot 侧真值），此处不再重复数值表。
>
> - 数值文档真值：`BALANCE.md`（分系统表格 + 16 处差异键的 js 原值标注 + 两轮调参历史）
> - 代码真值：`autoload/config.gd`（CONFIG 字典与 BALANCE.md 逐键一致）
> - 差异裁决过程：RULES.md 附录 B #9 / #10

---

## 附录 B：矛盾裁决表

以下条目中文档（主要是 `Docs/weapon-upgrade-guide.md`）与 `js/` 代码不一致，以及 Godot 侧与 `js/` 的有意差异。**裁决一律以代码为准**，移植按本表右列实现：

| # | 主题 | Docs 说法 | js/ 代码实际 | 裁决依据 |
| --- | --- | --- | --- | --- |
| 1 | 玉环寒玉减速 | applySlow(e, 0.25, 1.2) | applySlow(e, 0.35, 1.6) | ring.js + CARD L2 注释 |
| 2 | 死灵连接回血封顶 | 3 HP/s | min(2, 1 + 0.5×(存活−1))，封顶 2 | staff.js:234 |
| 3 | 丹炉火域持续 | 4.5s | CARD furnaceLife 6 / 7.5 / 9（4.5 仅兜底） | trail.js CARD |
| 4 | 道剑 Lv6 飞剑充能 | 每击杀 10 个敌人 | 每命中 10 次（飞剑命中不计，countIntent=false） | sword.js |
| 5 | 雷符闪电链搜索半径 | ≤160px（代码注释同） | R2 = 180×180 → 180px | talisman.js:120 |
| 6 | 玉环 Lv6 狂暴/反制 | 每 100 杀狂暴 3s；冻结 1.5s；CD ≥ 20s | 每 50 杀狂暴 4s；冻结 2s；counterCd 16 | ring.js FRENZY_KILL_STEP=50 + CARD |
| 7 | 披风 Lv6 击杀特效 | 每 100 杀重置震荡 CD | 每 100 杀追加强化冲击（半径 ×1.8 / 8 ticks / 减速 3s），不重置普通 CD | cloak.js + DESIGN.md |
| 8 | 法杖 Lv4 爆炸半径 | 卡面注释"半径 70" | CARD blastRadius = 85（Lv5/Lv6 = 125） | staff.js CARD |
| 9 | Godot 侧手感调参（2026-08-15） | js/config.js 原值：enemy.speed 85 / enemy.hp 50 / 存活上限 min(140, 20+8×(wave−1)) / quota round(16×mult)、增长 0.5 | Godot CONFIG：speed 76 / hp 45 / min(180, 30+10×(wave−1)) / quota round(24×mult)、增长 0.8 | 按实机反馈调参，Godot 侧为准；js 原型不回改，BALANCE.md（原附录 A）已同步为 Godot 真值 |
| 10 | Godot 侧第二轮数值调参（2026-08-15） | 第一轮后 Godot CONFIG：hpPerMin 54 / speedPerMin 0.08 / hpPerWave 三段 0.16/0.30/0.28 / hpWaveCap 7 / baseSpeedMult 1.5 / speedWaveCap 2 / startMaxAlive 30 / maxAlivePerWave 10 / baseQuota 24 / quantityPerWave 0.8 / quantityWaveCap 11.25 | hpPerMin 10 / speedPerMin 0.015 / hpPerWave 三段 0.10/0.12/0.10 / hpWaveCap 3 / baseSpeedMult 1.35 / speedWaveCap 1.6 / startMaxAlive 40 / maxAlivePerWave 12 / baseQuota 30 / quantityPerWave 1.2 / quantityWaveCap 14；maxAliveCap 保持 180；apply_wave_scaling 由硬编码改为 Config 驱动 | 按实机反馈"血太厚/移速涨太快/怪太少"调参，Godot 侧为准；js 原型不回改，BALANCE.md（原附录 A）已同步为 Godot 真值 |

---

## 附录 C：smoke 测试章节对照表

原型 `tools/headless-smoke.mjs` 共 23 个章节（`npm run smoke`）。Godot 移植须逐章复刻为 `tests/scenarios/`（见 PORT_PLAN）：

| 章节 | 标题 | 里程碑 |
| --- | --- | --- |
| [0] | Weapon card structure（6 武器均 6 级、每级 damage>0） | M1 |
| [1] | 主菜单 → 开局：全部武器卡任选一 | M1 |
| [2] | 移动（按住 D 一秒位移 >100px） | M1 |
| [3] | 站桩 60 秒：定时波不会提前推进 | M1 |
| [4] | 强制升级：鼠标点击选卡 | M1 |
| [5] | 基础属性 / 护甲减伤 / 生命上限卡 | M1 |
| [6] | Weapon mechanic changes（六武器机制与上限） | M2 |
| [7] | generateOffers 卡池规则 | M1 |
| [8] | 敌人基类与四种特殊机制 | M3 |
| [9] | 波次 / Boss / 精英掉落 / 经验锁定吸附 | M3 |
| [Debug] | Debug Runtime | M6 |
| [10] | 死亡与 R 返回主菜单 | M3 |
| [11] | Boss 掉落概率边界与保底品阶 | M3 |
| [12] | 撤离流程：Boss 波清空 → 撤离 → 结算 → 存档 | M3 |
| [13] | 继续深入：背包保留，下个 Boss 波再次抉择 | M3 |
| [14] | 死亡损失：临时背包全损、仓库不受影响 | M3 |
| [15] | 商城：价格曲线 / 购买 / 余额不足 / 满级 | M5 |
| [16] | 仓库卖出与局外属性生效 | M5 |
| [17] | 25 波上限与最终通关结算 | M3 |
| [18] | Weapon synergy infrastructure + all fifteen implemented Builds | M4 |
| [19] | First and second weapon Build batches | M4 |
| [20] | Third weapon Build batch | M4 |
| [21] | Randomized in-run tasks and rewards | M5 |

> RNG 覆盖点：smoke 在 headless-smoke.mjs 第 420 / 538 / 576 / 807 / 973 / 1032 / 1067 / 1251 行覆盖 `Math.random` 为常量函数。Godot 侧通过 `Rng.next()` 注入实现同等能力（PORT_PLAN §实现决策）。