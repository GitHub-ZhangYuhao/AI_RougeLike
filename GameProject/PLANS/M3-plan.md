# M3 开发计划 —— 敌人 / Boss / 局流程（logic/enemies、logic/meta、run 收尾）

> 规划子Agent-M2M3 产出。范围：敌人体系（7 类型 + 基类 + 工厂 + 敌方弹道）、状态效果补全、Boss 掉落/稀有物品、死亡/撤离/深入/25 波通关全流程。
> 真值依据：RULES.md §5（L210）、§6（L246）、§7（L270，§7.4 权重/replacementRatio L313）、§8（L374）、§10（L440）、§15（L737，§15.2 RNG 顺序 L747）、附录 B（L1049）；tools/headless-smoke.mjs 章节 [8]L460、[9]L591、[10]L906、[11]L931、[12]L957、[13]L1010、[14]L1093、[17]L1221。

## 1. 目标与验收口径

把 js/enemy.js、js/enemies/*、js/systems/status.js、js/projectile.js、js/meta/drops.js、js/meta/items.js、js/rare-items.js 1:1 移植为 Godot GDScript 逻辑层，并在 M1 的 game_run 上补全死亡/撤离/继续深入/通关状态转换与 Boss 波全流程。

验收命令（两条都必须绿）：

1. `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` —— [8][9][10][11][12][13][14][17] 全绿，且 M1/M2 已注册章节无回归。
2. `npm run smoke` —— 原型冒烟无回归（M3 不修改根目录 js/，作为基线确认）。

## 2. 有序子任务表

文件映射说明：按 1:1 文件映射，原型 js/enemies/base.js 的 EnemyBase/applyWaveScaling 落 `logic/enemies/base.gd`；js/enemy.js 的 ChaserEnemy/separateEnemies/drawEnemy 落 `logic/enemy.gd`（任务书口径「enemy.gd = EnemyBase+分离+波次成长」在此拆为两文件，语义不丢失）。

| # | 新建/修改文件 | 实现要点 | 依赖 | smoke |
|---|---|---|---|---|
| M3-1 | 修改 `logic/systems/status.gd` | 补全到与 js/systems/status.js 完全等价：`DOT_TYPES=["burn","blaze","bleed","poison"]` 四种独立 DoT（不叠层：dps=max、timer=max）；`apply_dot/has_dot/apply_slow(取最强)/apply_freeze`；`tick_status(e,dt) -> float`（返回本帧 DoT 总伤，由 game 层统一 damage_enemy 结算）；`speed_mult_of(e)`（冻结=0、减速=1-factor）。假设 M1 已提供部分实现（M1 计划含 burn/blaze/bleed），M3 补 poison 与 tick/speed_mult 并逐条核对。 | M1 | [6][8][9] |
| M3-2 | 新建 `logic/enemies/base.gd` | EnemyBase（extends RefCounted）构造 `(x, y, elapsed=0.0, options={})`：minutes=elapsed/60；jitter=1+rand(-0.25,0.25)（`rand(a,b)=a+(b-a)*Rng.next()`，options.speedVariance==false 时 jitter=1）；maxHp=(50+54×minutes)×hpMult；speed=85×jitter×(1+0.08×minutes)×speedMult；damage=(7+2.2×minutes)×damageMult；字段 hit_cooldown/hit_flash/ring_cd/dead/dots/slow_timer/slow_factor/frozen_timer。方法：tick_common、distance_to、direction_to、move_toward/move_away_from（×speed_mult_of）、update(player,dt,world) 默认追击、modify_incoming_damage 原样返回。模块函数 `apply_wave_scaling(e, wave)`：只应用一次（wave_scaling_applied）；step=wave-1，early=min(step,5)、mid=min(max(0,step-early),5)、late=剩余；hpMult=min(7, 1+0.16e+0.30m+0.28l)、damageMult=1+0.06e+0.14m+0.18l、speedMult=1.5+(2-1.5)×min(step,19)/19；按当前 hp/maxHp 比例同步缩放 hp。 | M3-1 | [8] |
| M3-3 | 新建 `logic/enemy.gd` | ChaserEnemy（extends EnemyBase，type='chaser'、rank='normal'）；兼容工厂 create_enemy(x,y,elapsed)；update_enemy 透传；`separate_enemies(enemies, dt)`：两两配对，0.0001<d²<(ra+rb)² 时沿连线推开 push=((minD-d)/d)×0.5×min(1, 60×dt)；draw_enemy 不移植（渲染归 M6，见 §3 [9] 说明）。 | M3-2 | [8] |
| M3-4 | 新建 `logic/enemies/enhanced_chaser.gd` | rank='enhanced-minion'，半径 15，hpMult 2.2/speedMult 1.05/damageMult 1.45（经 options 传入基类）；hp ≤ maxHp×0.5 → 预警 warning_timer 0.45s（移速 ×0.3、不狂暴）；预警结束永久狂暴：移速 ×1.5、伤害 ×1.35（enraged 标志）。 | M3-2 | [8] |
| M3-5 | 新建 `logic/enemies/charger.gd` | rank='enhanced'；状态机 chase→windup→dash→recovery→chase：追击距离 ≤260 且 charge_cooldown≤0 → windup 0.65s 并**锁定冲锋方向**；dash 0.55s、速度 400×speed_mult_of 沿锁定方向；recovery 0.85s 后 charge_cooldown=1.7。 | M3-2 | [8] |
| M3-6 | 新建 `logic/enemies/ranged.gd` + `logic/enemies/hostile_projectile.gd` | ranged：rank='enhanced-minion'；距离保持 ε=12（>272 靠近、<170 后退）；fire_cooldown 初始 1.7，归零且可见 → 经 `world.spawn_hostile_projectile({x,y,angle,speed=175,radius=5,damage=this.damage,lifetime=4})` 发射（枪口=半径+弹半径+3），shot_flash 0.16。hostile_projectile：create_hostile_projectile(options) 默认 {speed150,radius5,damage6,lifetime4,color}，预算 vx/vy；update_hostile_projectile(p,dt) 直线飞行+lifetime 归零 dead。 | M3-2；world.spawn_hostile_projectile 见 M3-11 | [8] |
| M3-7 | 新建 `logic/enemies/bomber.gd` | rank='enhanced-minion'；dist≤58 → windup；windup_timer≥0.9 → **先置 exploded=true**，dist≤88 时 `world.hurt_player(damage)` 恰好一次 + `world.spawn_enemy_blast(x,y,88)` 恰好一次 + dead=true。被击杀≠爆炸（exploded 防重复）。 | M3-2 | [8] |
| M3-8 | 新建 `logic/enemies/shield.gd` | rank='elite'；shielded(3s)↔open(1.5s) 循环（while 追平多周期）；modify_incoming_damage：shielded ×0.35、open ×1.25；始终 move_toward。 | M3-2 | [8][9] |
| M3-9 | 新建 `logic/enemies/boss.gd` | rank='boss'、半径 34、speedVariance=false、hpMult 24/speedMult 0.68/damageMult 2.4；attack_cooldown 初始 1.6；windup 0.85s → 环形弹幕：弹数 12（狂暴 18）、弹速 180（狂暴 205）、弹半径 7、lifetime 5、伤害=boss.damage×0.72、角度偏移=rotation，经 world.spawn_hostile_projectile 逐枚发射 + spawn_enemy_blast 视觉占位（半径=弹半径×2.4、ttl 0.45）；下次间隔=2.9×(狂暴?0.72:1)；狂暴（hp≤50%）旋转 1.25→2.2、移速 ×1.2。 | M3-2、M3-6 | [9][12][13][17] |
| M3-10 | 新建 `logic/enemy_factory.gd` | ENEMY_CLASSES 7 类型表；`create_enemy_by_type(type,x,y,elapsed=0,wave=1)`：未知类型回退（wave≥11→enhancedChaser 否则 chaser），构造后 apply_wave_scaling（wave 先 floor+max(1,·) 归一）；`choose_enemy_type(elapsed=0, enemies=[], options={wave,quota,spawnedByType,bossWave})`：①aliveByType 统计；②rangedWaveCap=max(1,floor(quota×0.12))（quota 非有限→INF）；③replacementRatio：wave<8→0、8→0.15、9→0.35、10→0.65、≥11→1；④遍历 CONFIG.enemyTypes（跳过 boss/enhancedChaser 直选）：chaser 拆成 chaser（weight×(1-ratio)）+ enhancedChaser（chaser 的 weight 62×ratio）两候选；候选准入：weight>0、elapsed≥unlockAt、alive<maxAlive；ranged 额外：Boss 波不刷 + spawnedByType.ranged<rangedWaveCap；⑤`r=Rng.next()*totalWeight` 累计命中；⑥候选空回退（wave≥11→'enhancedChaser' 否则 'chaser'）。 | M3-2~9 | [8] |
| M3-11 | 修改 `logic/game_run.gd`（M1 文件）：战斗入口扩展 | ①`spawn_hostile_projectile(options)` 追加进 hostileProjectiles；②`spawn_enemy_blast(x,y,radius,ttl)` 逻辑占位（effects 记录，渲染 M6）；③`_handle_collisions` 补全（假设 M1 API：骨架已有，M3 补齐三块）：敌方弹道命中玩家**即使无敌帧也消耗弹体**（只是不掉血），伤害经 `hurt_player(p.damage)`（DR 在 hurt_player 内，M1）；玩家死亡判定移至此（hp≤0 → state='dead'、hp=0、_apply_death_loss、persist）；我方弹道 pierce/hitSet/max_hits(含 INF)/on_hit 由 M1 保证，M3 复核；④`_update_pickups(dt)`：稀有拾取半径 30 拾取 → apply_rare_item + rareMessage(ttl 3.5)；hp 拾取恢复 15、同屏上限 5。 | M1、M3-6、M3-13 | [8][9][10] |
| M3-12 | 新建 `logic/meta/items.gd` + `logic/meta/drops.gd` | items：META_ITEMS（shard 卖 5 / essence 卖 20 / soulCrystal 卖 80，tier 1/2/3）、META_ITEM_LIST、ITEM_BY_TIER。drops（纯函数，rng 可注入）：`drop_chance_for(t)=min(0.08+0.03×(max(1,t)-1), 0.20)`；`min_tier_for(t)`=guaranteedMinTier{3:2,5:3} 中 ≤t 的最大键，缺省 1；`roll_boss_drops(boss_tier, rng: Callable = 空则 Rng.next)`，**RNG 顺序严格 §15.2**：r1≥概率→[]；tierKey=clamp(t,1,5)；count=min+floor(r2×(max-min+1))；逐件 roll_weighted_tier(tierWeights[tierKey])（每次恰好 1 次 rng：roll=rng()*total，逐项减权重）→ tier=max(掷得, min_tier_for) → ITEM_BY_TIER[tier].id。 | M1（Config/Rng） | [11][12][13][17] |
| M3-13 | 新建 `logic/rare_items.gd` | 5 种稀有物品等概率（floor(Rng.next()×5)）：warRune rareBonuses.damageMult×1.2 / bloodJade maxHp+25 并治 25 / magnetCore 吸附+80 / spiritBook xpMult×1.25 / windFeather 移速×1.1；RARE_ITEM_BY_ID；roll_rare_item()；create_rare_pickup(x,y,item=null)→{x,y,kind='rare',item_id,pulse,dead}；apply_rare_item(run,pickup)：apply + rare_inventory[id]+=1 + recompute_mods。rareBonuses 字段若 M1 未建则补。 | M1 recompute_mods | [9][10] |
| M3-14 | 修改 `logic/systems/waves.gd` + `logic/spawner.gd`（M1 文件）：Boss 波全流程 | waves（假设 M1 API：已有定时波骨架 start_wave/_quota_for/quantity_multiplier_for）：补 Boss 分支——is_boss_wave(wave%5==0)；reinforcements：5→4、10→6、其余 min(12, 6+floor((wave-10)/5)×2)；quota=round(16×(1+reinf)/16)（5/10/15/20/25 波 → 5/7/9/11/13）；spawn_interval=90/max(1,quota-1)；波开始先 spawnType('boss')（spawned=1），增援全部 forceType='enhancedChaser'；waveTimer≤0 且 boss_spawned：Boss 活→phase='overtime'（banner 重置），已死→game.on_boss_wave_cleared()；overtime 每帧查 Boss 死→on_boss_wave_cleared()；`begin_rest()`：phase='rest'、rest_timer=3.5，归零→_start_next_wave；`_start_next_wave`：wave≥25→game.on_final_wave_cleared()，否则 start_wave(wave+1)；start_wave 钳制 maxWave 25 并**返回实际波号**。普通波：wave%3==0 先强刷 1 shield（精英保底）；清场不推进、倒计时结束才进下一波、存活敌人延续。spawner：支持 force_type 透传 chooseEnemyType 之外的强制类型、spawned/quota 上限。 | M1、M3-9、M3-10 | [9][12][13][17] |
| M3-15 | 修改 `logic/game_run.gd`：局收尾状态机 | `_kill_enemy` 补全（假设 M1 API：已有 kills++/掉宝石骨架）：精英掉 1 稀有拾取（suppress_rare_drop 标记豁免）；Boss：bosses_defeated+=1、stats.totalBossKills+=1、persist_save、(x±14,y) 各掉 1 稀有拾取（每次 roll_rare_item 各 1 次 Rng.next）；killLog 末条字段 burned/blazed/noSummon/sourceWeaponId 等（M2 消费）。`on_boss_wave_cleared()`：materials=roll_boss_drops(bosses_defeated)（Rng 注入点）→ temp_backpack[id]+=n → wave≥25 ? on_final_wave_cleared() : state='extraction'。`on_final_wave_cleared()`：幂等守卫（final_settled 标志）→ 暗晶 += round(25×1.5)=38、storage+=temp_backpack、temp_backpack 清零、stats.extractions+=1、stats.completions+=1、best_wave、last_run_summary={wave=25,dark_crystals_gained,completed=true}、persist、state='summary'。extraction 状态：KeyE→extract()（暗晶+=round(wave×1.5)、storage+=背包、背包清零、extractions+1、best_wave、last_run_summary.completed=false、persist、state='summary'）；KeyC→continue_deeper()（state='playing'、wave_director.begin_rest()、背包保留）。summary：Enter→menu。死亡：state='dead' 时 last_death_loss=temp_backpack 快照、temp_backpack 全清零（storage/暗晶不动）、persist；KeyR→menu 并整局重置（weapons=[]、level=1、kills=0、wave=1、rare_inventory={}、temp_backpack 清零）。输入入口假设 M1 API：`handle_key(code, pressed)`。 | M3-11~14、MetaSave | [10][12][13][14][17] |
| M3-16 | 新建 `tests/scenarios/` 8 个场景 + smoke_runner.gd 注册 | s08_enemy_base.gd、s09_waves_boss_drops.gd、s10_death_return.gd、s11_boss_drop_bounds.gd、s12_extraction.gd、s13_continue_deeper.gd、s14_death_loss.gd、s17_final_wave.gd；按原型线性顺序注册（s08/s09 在 s07 后，s10~s14 依次，s17 在 s14 后、Debug 之前）；跨脚本引用一律 preload；每个场景自建独立 GameRun（原型各章共享同一 game 实例的累积前置，Godot 侧必须显式重建：新局→开局选卡→playing，再布置场面；MetaSave 每场景重置为 default_save 保证确定性）。 | M3-1~15 | [8][9][10][11][12][13][14][17] |

## 3. smoke 逐章复刻要点

通用构造：场景内 `var run = GameRunScript.new()`（preload logic/game_run.gd）→ 模拟 Enter 开局 → 选卡进 playing（复用 M1 场景的选卡 helper 模式：state 为 opening/choice 时按 Digit1）；随机注入用 `Rng.set_source(func(): return X)` + 用后 `clear_source()`；帧推进用 `run.step(1.0/60.0, 1280, 720)`（假设 M1 API step 固定步长入口）。测试 double（假 player/target）必须是有 x/y 属性的 RefCounted（GDScript 对 Dictionary 的 `.x` 点访问语义不同，勿用裸 Dictionary 当坐标对象）。

### [8] 敌人基类与特殊机制（L460-590）
断言清单：
1. chaser 早/晚期：maxHp 随 elapsed 成长；继承 EnemyBase。
2. charger：rank='enhanced'；update(player={x:100,y:0}, 0.01) → state='windup'；再 update(dt=windup+0.01) → 'dash'；再 0.1s → x 增大（沿锁定方向）。
3. ranged：rank='enhanced-minion'；update(dt=fireInterval+0.01, world 收集 spawn_hostile_projectile) → 恰好 1 发、speed==175；CONFIG 权重 ranged(11) < charger(18)。
4. 敌方弹道管线：run.spawn_hostile_projectile({玩家位置, angle=0, speed=0, radius=5, damage=5, lifetime=1}) → run._handle_collisions() → 玩家 hp 减少 5×(1−mods.damageReduction)（±1e-6）且弹体 dead（无敌帧也消耗，本例 iFrames=0）。
5. bomber：3 次 update（0.01 / windup+0.01 / 1.0，玩家 x=10）→ dead、hurt_player 恰 1 次、spawn_enemy_blast 恰 1 次。
6. shield：rank='elite'；modify_incoming_damage(10)==10×0.35；update(dt=shieldDuration+0.01) → phase='open'；modify==10×1.25。
7. 波次成长（Rng.set_source 常量 0.5 → jitter=1）：create_enemy_by_type('chaser',0,0,0,1).max_hp==50；elapsed=60 时 speed/(85×1.08)==1.5；wave11/wave1 maxHp 比==3.3；wave25/wave1==7（上限）；wave11 damage 比==2.0；wave11 speed 比==1.5+0.5×10/19；wave20/wave25==2（封顶且不再增长）。
8. enhancedChaser：hp=50% → update → warning_timer>0 且未狂暴；再 update(warningDuration+0.01) → enraged 且 damage 增大。
9. choose_enemy_type（Rng 常量 0.01）：wave11/quota62 连抽 30 次 ≠'chaser'；wave8/quota12/spawnedByType{ranged:1} 连抽 30 次 ≠'ranged'。
RNG 注入：对应原型 L538（0.5）、L576（0.01）。

### [9] 波次/Boss/精英掉落/经验吸附（L591-710）
断言清单：
1. 宝石磁吸锁定（依赖 M1 gems 模块）：create_gem(180,0,0)、vx=500 → update_gem 后 magnetized 且 vx<0；玩家移到 x=700 → 仍 magnetized 且 vx>0（不脱锁）。
2. WaveDirector + 假 spawner double（spawn_type(type,elapsed,enemies) / update(dt,elapsed,enemies,camera,viewW,viewH,options)）：start_wave(fake,3)、quota=2 → update 出现 rank='elite'；全灭不推进（wave==3、phase=='wave'）；wave_timer=0.01 后 update(0.02) → wave==4、存活敌人延续；Config.CONFIG.waves.duration==90。
3. 配额函数：_quota_for(1)=16、(9)=80、(15)=9、(20)=11、(25)=13；quantity_multiplier_for(1)=1、(9)=5、(15)=0.5625、(22)=11.25。
4. Boss 波：start_wave(fake, CONFIG.waves.bossEvery) → 最后生成物 type=='boss' 且 boss_spawned；wave_timer=0 → phase='overtime'、onBossWaveCleared 未触发；boss.dead=true → update → bossCleared==1。
5. BossEnemy：attack_cooldown=0 → update(0.01) state='windup'；update(windup+0.01, world 收集) → 弹幕数==projectileCount(12)。
6. 精英掉落：ShieldEnemy 经 run.damage_enemy(elite, max_hp×10) → pickups +1 且末个 kind=='rare'；Boss 击杀 → pickups +2、bosses_defeated>0。
7. 稀有拾取：拾取物移到玩家位置 → run._update_pickups(1/60) → pickup.dead、rare_inventory 非空、rare_message 有值。
8. 原型 drawEnemy(ctxStub, elite) 一项为渲染兼容性断言——Godot 逻辑层无渲染，**本条不复刻**（渲染移植 M6 覆盖），场景内注释说明。
RNG：无专门覆盖点（宝石散开用 M1 固定种子链）。

### [10] 死亡与 R 返回主菜单（L906-930）
前置：从 M1 状态继续（本场景自建新局并打到 playing）。断言：hp=1、iFrames=0 → hurt_player(999) + _handle_collisions() → state=='dead'（死亡判定在碰撞末尾，两步语义必须保留）；KeyR → 'menu'，且 weapons 空、level==1、kills==0、waveDirector.wave==1、rare_inventory 空；Enter → 'opening'；选卡 → 'playing' 且 1 把武器。

### [11] Boss 掉落概率边界与保底（L931-956）
纯函数断言（不需要完整对局）：drop_chance_for(1)=0.08、(2)=0.11、(5)=0.20、(9)=0.20、(100)≤0.20；min_tier_for(1)=1、(2)=1、(3)=2、(4)=2、(5)=3、(9)=3；roll_boss_drops(tier, func(): 0.99) 对 tier 1~9 全为空；roll_boss_drops(1, 常量 0)=["shard"]、(3)=["essence"]、(5)=["soulCrystal","soulCrystal"]。

### [12] 撤离流程（L957-1009）
布置：pending_choices=0、清空 enemies/hostileProjectiles；start_wave(run, 5) 断言 is_boss_wave；手造 BossEnemy(player.x+60) 入 enemies，wave_director.boss_spawned=true、spawned=quota、wave_timer=0；Rng 常量 0.99 → run.damage_enemy(boss, max_hp×2) → 清 gems/pickups → step(1/60) → clear_source。断言：boss.dead；bosses_defeated+1；state=='extraction'；temp_backpack 全 0（0.99 不掉材料）；KeyE → 'summary'，darkCrystals += round(5×1.5)=8、stats.extractions+1、best_wave≥5、last_run_summary={wave:5, dark_crystals_gained:8}；MetaSave.load_save() 与内存一致；Enter → 'menu'。

### [13] 继续深入（L1010-1092）
新建局 → playing；同上布置 Boss 波 5；**Rng 常量 0**（必掉、数量取下限、保底抬升）击杀 → step → state=='extraction'；断言 temp_backpack：tierKey=clamp(bosses_defeated,1,5)，count=dropCount[tierKey][0]，物品=ITEM_BY_TIER[min_tier_for(bosses_defeated)]（首杀 → shard×1）；KeyC → 'playing'、wave_director.phase=='rest'、背包保留；再布置第 10 波 Boss（Rng 0.99 不掉新料）击杀 → 再次 'extraction'、旧背包仍在；KeyE → 'summary'：darkCrystals += round(10×1.5)=15、storage[item]+=count、temp_backpack 清零；Enter → 'menu'。

### [14] 死亡损失（L1093-1128）
新建局 → playing；temp_backpack={shard:2, essence:1, soulCrystal:1}；记录 storage/暗晶快照；hurt_player(999)+_handle_collisions → 'dead'；step(1/60)（死亡界面帧，验证损失展示的数据面）；断言 last_death_loss==背包快照、temp_backpack 全 0、storage 三项与暗晶**不变**；KeyR → 'menu'。

### [17] 25 波上限与最终通关（L1221-1288）
前置 playing；Config.CONFIG.waves.maxWave==25；start_wave(run, 26) 返回 25 且 wave==25、is_boss_wave；temp_backpack={shard:2,essence:1,soulCrystal:0}；手造 Boss、boss_spawned、spawned=quota、wave_timer=0；Rng 0.99 击杀 → step → boss.dead、state=='summary'（最终波**无撤离抉择**）、wave==25（不得进 26）、last_run_summary.completed==true、wave==25、奖励==round(25×1.5)=38；save.darkCrystals+38、extractions+1、completions+1、storage shard+2/essence+1/soulCrystal+0、temp_backpack 清零；load_save() 一致；**重复调用 on_final_wave_cleared() → 不得重复发奖**（幂等守卫）。

## 4. 关键 API 清单（GDScript 伪代码）

```gdscript
# logic/enemies/base.gd
class EnemyBase extends RefCounted:
    var x: float; var y: float; var radius: float; var type: String; var rank: String
    var max_hp: float; var hp: float; var speed: float; var damage: float
    var hit_cooldown: float; var hit_flash: float; var ring_cd: float; var dead: bool
    var dots: Dictionary; var slow_timer: float; var slow_factor: float; var frozen_timer: float
    var wave_scaling_applied: bool = false; var wave: int = 1
    func _init(x: float, y: float, elapsed: float = 0.0, options: Dictionary = {}) -> void:
    func tick_common(dt: float) -> void:
    func distance_to(target) -> float:
    func direction_to(target) -> Dictionary:          # {x,y,distance}
    func move_toward(target, dt: float, spd: float = -1) -> void:   # ×speed_mult_of
    func move_away_from(target, dt: float, spd: float = -1) -> void:
    func update(player, dt: float, world) -> void:    # 子类覆写
    func modify_incoming_damage(dmg: float) -> float:
static func apply_wave_scaling(enemy, wave: int = 1):

# logic/enemy.gd
class ChaserEnemy extends EnemyBase: ...
static func separate_enemies(enemies: Array, dt: float) -> void:

# logic/enemy_factory.gd
static func create_enemy_by_type(type: String, x: float, y: float, elapsed: float = 0.0, wave: int = 1):
static func choose_enemy_type(elapsed: float = 0.0, enemies: Array = [], options: Dictionary = {}) -> String:
static func enhanced_chaser_ratio(wave: int) -> float:

# logic/enemies/hostile_projectile.gd（同构的 logic/projectile.gd 由 M1/原型 projectile.js 对齐，M3 复核字段齐全）
static func create_hostile_projectile(options: Dictionary):
static func update_hostile_projectile(p, dt: float) -> void:

# logic/systems/status.gd
const DOT_TYPES: Array = ["burn", "blaze", "bleed", "poison"]
static func apply_dot(e, type: String, dps: float, duration: float) -> void:
static func has_dot(e, type: String) -> bool:
static func apply_slow(e, factor: float, duration: float) -> void:
static func apply_freeze(e, duration: float) -> void:
static func tick_status(e, dt: float) -> float:
static func speed_mult_of(e) -> float:

# logic/meta/items.gd / drops.gd
const META_ITEMS: Dictionary; const META_ITEM_LIST: Array; const ITEM_BY_TIER: Dictionary
static func drop_chance_for(boss_tier: int) -> float:
static func min_tier_for(boss_tier: int) -> int:
static func roll_boss_drops(boss_tier: int, rng: Callable = Callable()) -> Array:  # 元素为材料 id

# logic/rare_items.gd
const RARE_ITEMS: Array; const RARE_ITEM_BY_ID: Dictionary
static func roll_rare_item() -> Dictionary:
static func create_rare_pickup(x: float, y: float, item: Dictionary = {}) -> Dictionary:
static func apply_rare_item(run, pickup) -> Dictionary:

# logic/systems/waves.gd（M1 骨架上补全）
var wave: int; var phase: String; var wave_timer: float; var quota: int; var base_quota: int
var boss_spawned: bool; var spawned: int; var is_boss_wave: bool
func start_wave(game, wave: int) -> int:              # 钳制 maxWave，返回实际波号
func _quota_for(wave: int) -> int:
func quantity_multiplier_for(wave: int) -> float:
func begin_rest() -> void:
func update(dt: float, game, camera, view_w: float, view_h: float) -> void:

# logic/game_run.gd（M1 文件，M3 新增/补全；假设 M1 API 已有 damage_enemy/hurt_player/_handle_collisions/_update_pickups/step/handle_key/_world/save/tempBackpack 等字段）
func spawn_hostile_projectile(options: Dictionary) -> void:
func spawn_enemy_blast(x: float, y: float, radius: float, ttl: float = 0.45) -> void:
func on_boss_wave_cleared() -> void:                  # 掉材料入 temp_backpack → extraction 或最终结算
func on_final_wave_cleared() -> void:                 # 幂等
func extract() -> void:                               # KeyE
func continue_deeper() -> void:                       # KeyC → begin_rest
func _apply_death_loss() -> void:
```

### 与 M1/M2 的耦合面
- **M1 接口（直接调用，假设 M1 API）**：`game_run.damage_enemy(e, dmg, opts)`（唯一敌人受伤入口，opts 含 noSummon/sourceWeaponId 等）；`hurt_player(dmg)`（内含 damageReduction 与 iFrames，**不含死亡判定**——死亡判定由 M3 放在 _handle_collisions 末尾）；`_handle_collisions()`；`_update_pickups(dt)`；`step(dt, viewW, viewH)`；`handle_key(code, pressed)`；`gain_xp`；公共字段 state/weapons/kills/level/elapsed/player/enemies/projectiles/hostileProjectiles/gems/pickups/killLog/waveDirector/spawner/pendingChoices/rareInventory/rareMessage/tempBackpack/save/bossesDefeated/lastRunSummary/lastDeathLoss/mods；autoload：`Config.CONFIG`（camelCase 键）、`Rng.set_source/clear_source/next`、`MetaSave.default_save/persist_save/load_save`、`Events`。
- **M2 接口（互相消费）**：M3 的 killLog 条目必须携带 `burned/blazed/noSummon/sourceWeaponId`（M2 的 cloak/trail/staff 读取）；精英/Boss 掉稀有拾取发生在 `_kill_enemy`（M2 不感知）；staff 转化读取 killLog 的 noSummon；武器造成的击杀一律经 damage_enemy → M3 的 _kill_enemy 收尾，禁止武器侧绕过。
- **M1 的 waves/spawner 骨架**：M3-14 在 M1 定时波骨架上补 Boss 分支，若 M1 已实现部分（精英保底）则核对合并，勿重复实现。

### Boss 波完整时序（增援 → overtime → 清场 → 掉落）
1. `start_wave(game, 5/10/15/20/25)`：is_boss_wave=true；reinforcements={5:4, 10:6, 15:8, 20:10, 25:12}（公式 min(12, 6+floor((wave-10)/5)×2)，5/10 为特例）；quota=1+reinf（5/7/9/11/13）；spawn_interval=90/max(1,quota-1)。
2. 波开始立即刷 Boss（spawnType('boss')，spawned=1，timer=spawn_interval）；其后增援全部 forceType='enhancedChaser' 直到 spawned==quota。
3. phase 'wave'：wave_timer 从 90 倒计时（清场不推进）。
4. timer≤0 且 boss_spawned：Boss 存活 → phase='overtime'（banner 重置）；Boss 已死 → 直接 on_boss_wave_cleared()。
5. phase 'overtime'：每帧检查 Boss 死亡 → on_boss_wave_cleared()。
6. on_boss_wave_cleared：材料 roll_boss_drops(bosses_defeated) 逐件入 temp_backpack → wave≥25 ? on_final_wave_cleared()（直接 summary，无抉择）: state='extraction'（等 E/C）。
7. Boss 死亡本身在 _kill_enemy：bosses_defeated+=1、stats.totalBossKills+=1、persist_save、掉 2 个稀有拾取（x±14）。

### rollBossDrops 的 RNG 调用顺序（§15.2，硬约束）
1. `r1 = rng()` —— r1 ≥ dropChanceFor(tier) → 返回 []（仅消耗 1 次）。
2. `r2 = rng()` —— count = min + floor(r2 × (max−min+1))（tierKey=clamp(tier,1,5) 的 dropCount）。
3. 每件 1 次：`r = rng()` → roll=r×total，按 tierWeights[tierKey] 逐项减权重落档（恰好 1 次调用/件）；tier = max(落档, min_tier_for(bossTier))。
注意：击杀瞬间 _kill_enemy 的 2 次稀有拾物 roll（各 1 次 Rng.next）先于材料 roll 发生；场景注入常量源时三类调用全部命中同一常量，预期值按此推导。

### 状态转换（死亡/撤离/深入/通关）
- playing → **dead**：_handle_collisions 末尾 hp≤0 → hp=0、state='dead'、last_death_loss=temp_backpack 快照、temp_backpack 清零、persist（storage/暗晶不动）；KeyR → menu（整局重置）。
- playing → **extraction**：非最终 Boss 波清空（on_boss_wave_cleared 且 wave<25）；KeyE → extract() → **summary**（结算入库）；KeyC → continue_deeper() → playing + wave_director.begin_rest()（phase='rest'，3.5s 后下一波，背包保留）。
- extraction/summary：summary 状态 Enter → menu。
- playing → **summary（通关）**：wave 25 Boss 清空 → on_final_wave_cleared()（幂等）：暗晶 +round(25×1.5)、temp_backpack 自动入库并清零、extractions+1、completions+1、completed=true、persist → summary → Enter → menu。

## 5. 风险与坑

1. **hurt_player 无死亡判定的两步语义**（M1 裁决）：场景 [10]/[14] 先 hurt_player(999) 再 _handle_collisions() 才死；死亡判定只能放碰撞末尾，勿在 hurt_player 内抢跑。
2. **RNG 顺序零容忍**：jitter（rand(-0.25,0.25)）、choose_enemy_type、roll_rare_item、roll_boss_drops 的调用次数与顺序必须与原型一致；常量源（0.5/0.01/0/0.99）下每个覆盖点（原型 L538/576/973/1032/1067/1251）逐一对照。roll_boss_drops 必须支持显式 rng: Callable 注入（[11] 直接传参），其余调用点走 Rng.next()。
3. **GDScript round/floor**：JS Math.round 对 .5 向上（round(7.5)=8）——GDScript round() 为四舍五入远离零，正数域一致；取整用 int(round(x))、floori()。maxWave 奖励 round(25×1.5)=38、wave5=8、wave10=15。
4. **场景独立性**：原型 [10]~[17] 共享同一 game 实例累积状态；Godot 每场景必须自建新局并显式重建前置（含 MetaSave 重置为 default_save，避免 user:// 存档跨场景泄漏）。
5. **测试 double 类型**：敌人 update(player, dt, world) 的 player/world 在场景里用带 x/y 属性的 RefCounted 小类，不要用 Dictionary 传坐标对象。
6. **Dictionary 对象键**：talisman 之外，M3 的 spawnedByType/aliveByType 均为字符串键无此问题；但敌人实例作键的场景（如后续联动）注意强引用。
7. **ranged 约束**：Boss 波不刷 ranged；rangedWaveCap=floor(quota×0.12) 至少 1；enhancedChaser 只经 chaser 拆分进入候选池（CONFIG weight=0）。
8. **无敌帧消耗弹体**：敌方弹道命中即 dead（无论是否掉血），勿写成 iFrames 时穿透。
9. **on_boss_wave_cleared/on_final_wave_cleared 幂等**：phase 切换后不得重复触发；[17] 末尾显式重复调用 on_final_wave_cleared 验证。
10. **start_wave 返回实际波号**：[17] 断言请求 26 返回 25；wave 25 也是 Boss 波（is_boss_wave 判定在钳制后）。
11. **与 M1 的文件冲突**：game_run.gd/waves.gd/spawner.gd/status.gd 均为 M1 文件，M3 为增量修改；开工前先读 M1 交付代码，凡 M1 已实现的（如精英保底、碰撞骨架）只补全不重写。
12. **渲染断言取舍**：[9] drawEnemy(ctxStub) 一项不移植（M6），场景注释留痕；其余断言逐条保留 `[N]` 前缀文案。
13. 假设：gems 模块（create_gem/update_gem）为 M1 交付（[3] 需要击杀→经验→升级）；若未交付则升级为 M3 前置阻塞项。

## 6. Definition of Done

- [ ] logic/enemy.gd、logic/enemies/（base + 7 类型 + hostile_projectile）、logic/enemy_factory.gd、logic/systems/status.gd（补全）、logic/projectile.gd（复核）、logic/meta/drops.gd、logic/meta/items.gd、logic/rare_items.gd 全部落地；纯 RefCounted、无 Node/SceneTree。
- [ ] game_run.gd 补全死亡/撤离/深入/通关状态机与 Boss 掉落入账；waves.gd/spawner.gd 补全 Boss 波（增援/overtime/清场/掉落）；on_final_wave_cleared 幂等。
- [ ] rollBossDrops RNG 顺序与 §15.2 逐字一致；choose_enemy_type 权重/replacementRatio/ranged 上限与 §7.4 一致；波次成长与 §7.2 数值一致（wave11 HP ×3.3、wave25 ×7 上限、speed 1.5→2 封顶）。
- [ ] 8 个场景（s08/s09/s10/s11/s12/s13/s14/s17）注册进 SCENARIO_PATHS 且按原型线性顺序；断言文案带 `[N]` 前缀；全部 preload。
- [ ] `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` 全绿（含 M1/M2 章节无回归）。
- [ ] `npm run smoke` 无回归。
- [ ] 未修改 GameProject/ 内本计划范围外的文件（M1 文件的增量修改除外）；未触碰根目录 js/、DESIGN.md、Docs/。