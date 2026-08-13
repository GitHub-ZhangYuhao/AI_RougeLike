# M1 实施计划 — 核心循环（smoke [0][1][2][3][4][5][7]）

> 规划子Agent 产出（2026-08-14）。上游文档：`GameProject/PORT_PLAN.md`（实现决策）、`GameProject/RULES.md`（规则真值）、`GameProject/PROGRESS.md`（任务台账）。
> 冲突裁决原则：本计划与 RULES.md 冲突时以 RULES.md + 附录 B 裁决项为准；与原型代码/smoke 行为冲突时按「代码/smoke 为准」记录裁决（见下文）。

## 1. 范围与验收

**范围**：原型核心循环 —— 状态机（menu/opening/playing/choice 全实现，dead/extraction/summary 留状态位）、输入与移动、相机、经验/升级、选卡（键盘 Digit1-3 + 鼠标点击）、属性卡与 computeMods、定时波与刷怪、宝石磁吸、开局卡池与 generateOffers 卡池规则、占位渲染壳。

**验收口径（双绿）**：
1. Godot 侧：在仓库根 `C:\WorkSpace\AIGame` 执行 `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd`，输出 `All smoke tests passed` 且退出码 0；注册场景恰为 7 个，[0][1][2][3][4][5][7] 按注册顺序逐行打印 OK。
2. 根目录 `npm run smoke` 全绿（原型只读，`git status` 确认 `js/`、`tools/headless-smoke.mjs`、`index.html` 零改动）。

**裁决记录（依赖前置拉入）**：PROGRESS.md §3 把敌人/武器实现列在 M2/M3，但 [3] 要求 `kills>0`（需要敌人被击杀）、[4] 的「new 武器」分支要求武器可实例化，因此 M1 必须拉入敌人与武器的**最小骨架**（子任务表 #6-#11、#14-#16）。这些文件在 M2/M3 中只做「增强」，不重建。

## 2. 有序子任务表（按依赖顺序）

| # | 文件（GameProject/ 下） | 原型对应 | 核心职责 | 移植要点 |
| --- | --- | --- | --- | --- |
| 1 | `tests/smoke_runner.gd`（扩展）+ `tests/scenarios/_harness.gd`（新增） | tools/headless-smoke.mjs 公共脚手架 | 共享线性 harness | 原型 smoke 是单线性脚本共享同一个 game；Godot 场景分文件 → harness 提供：`ensure_game()` 懒加载建局（首次调用前先 `MetaSave.reset_save()`，模拟原型全新 localStorage）；`pump(n)` = n×{`game.step(1.0/60.0, 1280, 720)` + `game.input.end_frame()`}；`pump_with_choices(n, prefer: Callable)`（遇到 choice/opening 按 prefer(idx, offer) 选卡并注入对应 Digit 键 down+up；extraction 屏注入 KeyC；summary 屏注入 Enter）；`key_down/key_up/mouse_move/mouse_down/mouse_up` 直接写 `game.input`（InputState 快照）。场景文件跨脚本引用一律 `preload`。 |
| 2 | `logic/utils.gd` | js/utils.js | dist/angle/lerp/clamp/randRange/pointAround | 纯静态函数；新增 `js_round(x)` = `floori(x + 0.5)` 对齐 JS Math.round（7.5→8、37.5→38），M3 结算复用。 |
| 3 | `logic/input_state.gd` | js/input.js | 纯输入快照 | pressed/justPressed 边沿集合（Dictionary 当集合用）、mouseX/mouseY/mouseDown/mouseClicked、轴；`end_frame()` 清边沿。不依赖 Node/Input，由表现层或测试填充。 |
| 4 | `logic/camera.gd` | js/camera.js | 跟随 + 震屏 | 位置用 float x/y（禁 Vector2）；lerp 系数 CONFIG.camera.lerp=8；震屏幅度衰减。 |
| 5 | `logic/player.gd` | js/player.js | 玩家实体 | x/y/radius(14)/hp/maxHp/iFrames(0.8)/speed(230)/moving/facing；`move(dt, input)` 欧拉积分；lastHurtAt。 |
| 6 | `logic/projectile.gd` | js/projectile.js | 玩家弹 | x/y/vx/vy/damage/radius/pierce/maxHits（支持 INF）；命中后 maxHits−=1，归零移除；onHit 回调透传。 |
| 7 | `logic/enemies/hostile_projectile.gd` | js/enemies/hostile-projectile.js（M1 仅骨架） | 敌方弹 | x/y/vx/vy/damage(5)/radius/dead；M1 只保证可实例化与更新，碰撞消耗 M3 补全。 |
| 8 | `logic/systems/status.gd` | js/systems/status.js | 状态效果 | apply_dot（burn/blaze/bleed）/apply_slow/apply_freeze；dot 跳伤经 `game.damage_enemy`。M1 提供武器所需 API 面即可。 |
| 9 | `logic/weapons/weapon_base.gd` | js/weapons/base.js | 武器基类 | card/level/timer；`stats` getter = `card.levels[level-1]`（升级后立即生效）；预留 world 字段（M2 使用）。 |
| 10 | `logic/weapons/sword.gd`、`cloak.gd`、`talisman.gd`、`trail.gd`、`ring.gd`、`staff.gd` | js/weapons/*.js | 六武器骨架 | 每武器 6 级数值表必须完整且与 RULES.md §12 一致（[0] 断言依赖）；M1 只实现 sword Lv1 近战挥砍与 Lv2 无限穿透弹，其余五武器保证可实例化、update 不崩。 |
| 11 | `logic/weapons/weapon_factory.gd` | js/weapons/index.js | createWeaponByType | id→类映射，六 id 全覆盖。 |
| 12 | `logic/cards.gd` | js/cards.js | 卡池与属性 | WEAPON_CARDS（顺序 sword,cloak,talisman,trail,ring,staff，[1] 依赖该顺序）、ATTR_CARDS（6 个 id：damage/armor/magnet/xp/maxHp/moveSpeed）、CARD_BY_ID；`compute_mods(attr_stacks, meta_stacks = {})`（跳过未知 id）；`opening_offers(game)` 固定 6 张武器 new；`generate_offers(game)` —— **参数不做类型标注**（duck typing），只读 game.weapons + game.attrStacks，shuffle 后取前 CONFIG.cards.choicesCount 张。 |
| 13 | `logic/gems.gd` | js/gems.js | 宝石/经验 | update_gem：锁定式磁吸（一旦吸附，方向锁定不再翻转）；散开初速用 2 次 Rng.next()（角度+速率），调用顺序与原型 1:1。 |
| 14 | `logic/enemies/base.gd` | js/enemies/base.js | EnemyBase | hp/maxHp/speed/damage/radius/xpValue；`apply_wave_scaling(elapsed, wave)`（jitter 用 Rng.next()，调用顺序 1:1）。全部数值目标（wave 系数/cap）M3 校准，M1 按 [3] 需求实现。 |
| 15 | `logic/enemy.gd` | js/enemy.js | ChaserEnemy + 分离 | 追踪移动（朝向玩家、速度×dt）；`separate_enemies(enemies)` 双循环互推。 |
| 16 | `logic/enemies/enemy_factory.gd` | js/enemies/index.js | 类型选择与创建 | `choose_enemy_type(wave, spawned_by_type)` 完整实现（权重/配额/replacementRatio，RULES §7.4）；`create_enemy_by_type(type, x, y, elapsed, wave)` —— M1 未实装的类型**回退为 Chaser**（[8] 的特殊类型 M3 补齐）。 |
| 17 | `logic/rare_items.gd` | js/rare-items.js | 稀有掉落 | 稀有物表；pickup 拾取 → rareInventory+1 且 rareMessage 非空。 |
| 18 | `logic/spawner.gd` | js/spawner.js | 刷怪器 | spawnInterval；环形出生位置（2 次 Rng.next()：角度+半径抖动，顺序 1:1）；maxAlive 上限（CONFIG.spawner.maxAliveCap=140 与每类型 maxAlive，INF 语义）；spawnType 透传。 |
| 19 | `logic/systems/waves.gd` | js/systems/waves.js | WaveDirector | 定时波：duration=90、quota、`start_wave(wave)`（钳制并返回实际波号）、applySpawnSettings；精英（每 3 波）与 Boss 分支留接口，M3 补全。 |
| 20 | `logic/ui_layout.gd` | js/ui-cards.js + js/hud.js | 矩形布局 | `get_card_rects(viewW, viewH, n)` + `get_weapon_slot_rects(...)`，像素级对齐原型（RULES §17）；[4] 鼠标选卡与 M4 武器槽点击共用。 |
| 21 | `logic/game_run.gd` | js/game.js | 单局主体 | 状态机 menu/opening/playing/choice 全实现；RULES §2.2 的 25 步 update 顺序 1:1；`step(dt, viewW, viewH)` 固定步长入口；统一伤害入口 `damage_enemy(e, dmg, opts)` / `hurt_player(dmg)`（hurt_player 只扣血+设 iFrames，**不做死亡判定**，死亡判定在 `_handle_collisions` 末尾，M3 实装）；`gain_xp(raw)` 内部乘 mods.xpMult（[4] 依赖该语义）；pendingChoices/_apply_offer/_recompute_mods；`_world()` 对武器 API 面（M2 的 baseWorld 契约预留）；killLog；开局 Enter→opening 时 save.stats.runs+1 并 `MetaSave.persist_save`。公共字段与原型同名：state, weapons, attrStacks, metaStacks, mods, level, xp, kills, elapsed, player, camera, input, enemies, projectiles, hostileProjectiles, gems, pickups, killLog, waveDirector, spawner, currentOffers, pendingChoices, rareInventory, rareMessage, tempBackpack, save, bossesDefeated, lastRunSummary, lastDeathLoss。 |
| 22 | `scenes/main.tscn` + `scenes/game/game_view.gd` | js/main.js | 表现壳 | `_physics_process` 累加器 → `run.step(1.0/60.0)`，帧 dt 钳制 0.25s；从 Godot Input 填充 InputState（keydown/keyup 边沿、鼠标）；占位渲染（_draw 圆点/矩形/Label：玩家、敌人、宝石、HUD、卡牌）。只允许 scenes → logic 单向依赖；表现事件经 Events 信号。 |
| 23 | `tests/scenarios/` 7 个场景文件（s00_weapon_cards.gd、s01_menu_opening.gd、s02_movement.gd、s03_idle_wave.gd、s04_mouse_choice.gd、s05_attr_cards.gd、s07_generate_offers.gd） | headless-smoke.mjs 对应章节 | 场景断言 | 一章一个 .gd：`extends RefCounted` + `func title() -> String`（返回 `"[N] ..."`）+ `func run(runner) -> void`；断言文案保留 `[N]` 前缀；按原型线性执行顺序注册进 `tests/smoke_runner.gd` 的 `SCENARIO_PATHS`；跨脚本引用一律 preload。 |

## 3. 逐章 smoke 复刻要点

### [0] Weapon card structure（无 RNG 覆盖）
- 对每张 WEAPON_CARDS：`maxLevel == 6`；`levels.size() == 6`；每一级 `damage > 0`。
- RNG：本章无随机，无需注入。

### [1] 主菜单 → 开局选卡（无覆盖点，需固定种子）
- 新建局初始 `state == 'menu'`；menu 状态下 `currentOffers.size() == 6`（menu 预览也生成）。
- 注入 Enter → `state == 'opening'`；`save.stats.runs` 较之前 +1。
- 所有开局 offer：kind == 'weapon' 且 isNew。
- `pump_with_choices` prefer `offer.id != 'trail'` → 命中第一张即 sword（依赖 WEAPON_CARDS 顺序 sword,cloak,talisman,trail,ring,staff），按 Digit1。
- 选完 `state == 'playing'` 且 `weapons.size() == 1`。
- **RNG 注入**：本章受 shuffle 影响，场景开头 `Rng.set_seed(固定常量)`（或 set_source 常量序列），章节结束 `Rng.clear_source()`。

### [2] 移动（无覆盖点）
- 按住 KeyD 60 帧（pump(60)）：`player.x − 初始x > 100`（speed 230 ⇒ 约 230 px/s）。
- 随后设置 `hp = maxHp = 100000` 作弊（后续章节沿用，harness 共享局）。
- RNG：无。keydown/keyup 必须成对。

### [3] 站桩 60 秒定时波（无覆盖点，需固定种子贯穿）
- `pump_with_choices(3600)`（60s×60fps）后：`kills > 0`；`level >= 2`；`state` 保持 playing；`weapons.size() <= 3`；`wave == 1` 且剩余时间 < 31（duration 90 − 60）。
- **RNG 注入**：击杀/升级/选卡链很长，整章使用一个固定种子（调好一次后把种子值写进场景注释），章末恢复。种子值决定断言能否全过，禁止中途改动 RNG 调用顺序。

### [4] 鼠标点击选卡（无覆盖点，固定种子）
- 前置：`pendingChoices == 0`、`xp == 0`。
- `game.gain_xp(game.xp_to_next() / game.mods.xpMult + 0.001)`（gain_xp 内部再乘 xpMult ⇒ 恰好越线）；`pump(3)` → `state == 'choice'` 且 `pendingChoices == 1`。
- 矩形取 `ui_layout.get_card_rects(1280, 7280→720, currentOffers.size())`；mouse_move 到 rect[0] 中心 → mouse_down（+up）；`pump(3)` → 回 playing。
- 按实际 offer 三分支断言：isNew → weapons +1；武器升级 → 该武器 level+1；属性卡 → attrStacks[id]+1。
- RNG：沿用上章固定种子链。

### [5] 属性卡 / 护甲 / 生命上限（无覆盖点）
- ATTR_CARDS 的 id 集合 == damage, armor, magnet, xp, maxHp, moveSpeed；磁吸基准半径 180。
- `compute_mods({damage:2, armor:5, magnet:2, xp:3, maxHp:2, moveSpeed:1})`：damageMult 1.3、armor 75（DR = 75/(75+100)）、magnetRadius +100、xpMult 1.45、maxHp +40、moveSpeedMult 1.06（ε=1e-6）。
- armor 1000 → DR 封顶 0.5。
- maxHp 卡：每级 maxHp +20 且同步回血 +20。
- 恢复 mods = compute_mods({armor:5})；设 hp=100、iFrames=0，`hurt_player(100)` → 实扣走 DR：hp == 100 − 100×(1−DR)。
- compute_mods 必须**跳过未知 id**（M2 的 world 测试会传入 projectile/area/attackSpeed/cooldown 等额外字段）。

### [7] generateOffers 卡池规则（无覆盖点，纯函数）
- fake game `{weapons: 3 把 Lv1 武器, attrStacks: {}}` → `generate_offers(fake).size() > 0` 且**无** kind=='new' 的 offer（局内卡池不出新武器）。
- 全武器满级（level 6）+ 全属性 stack 5 → `generate_offers(fake).size() == 0`（池空）。
- fake 用未类型标注的 RefCounted 对象（字段访问），**不用 Dictionary**。

**M1 章节 RNG 总说明**：原型 8 个 Math.random 覆盖点（PORT_PLAN 决策 5）均不落在 M1 章节，M1 全部是「宽松章」——场景用 `Rng.set_seed(常量)` 或 `Rng.set_source(Callable)` 注入确定性源，章末必须 `Rng.clear_source()` 恢复。原型第 807 行覆盖点属于 [Debug] 章（M6），与 M1 无关（裁决/核实记录）。

## 4. 风险与坑（M1 特有）

1. **headless --script 无全局类缓存**（AGENTS.md 经验 #1）：场景/harness 引用任何逻辑脚本必须 `const X = preload("res://...")`；不要裸写类名，也不要依赖 class_name 跨脚本解析。
2. **逻辑层禁 Node/SceneTree/Vector2**：logic/ 全部纯 RefCounted；位置用 float x/y 存储（Vector2 默认 float32，会破坏与 JS float64 的数值对齐，PORT_PLAN §5）。
3. **RNG 调用顺序 1:1 是硬约束**：gems 散开、spawner 出生位置、apply_wave_scaling jitter、choose_enemy_type、cards shuffle 的 Rng.next() 次数与顺序必须与原型一致；[3] 的固定种子链对顺序零容忍。
4. **线性共享状态**：场景按注册顺序串行执行、共享 harness 单例 game（[2] 的 hp=100000 作弊要延续到 [3][4][5]）；场景不得自行 new 新局、不得 reset_save（harness 只在首次建局前 reset 一次）。
5. **hurt_player 无死亡判定**（裁决记录）：原型死亡（hp<=0 → hp=0、dead、lastDeathLoss）发生在 `_handle_collisions` 末尾；RULES §3.4 的受伤描述与此不完全一致 → 按附录 B 风格裁决「代码/smoke 为准」。M1 留好位置，M3 实装。
6. **duck typing**：`generate_offers(game)`、`WaveDirector.update(dt, game, camera, viewW, viewH)` 参数不标类型；测试 double 是 RefCounted 类（支持点访问），不能用 Dictionary。
7. **ui_layout 矩形契约**：[4] 依赖 get_card_rects 与原型像素级一致；布局参数以 RULES §17 / 原型 ui-cards.js 为准，禁止「差不多」近似。
8. **INF 语义**：chaser maxAlive、sword Lv2 maxHits 等用 GDScript `INF`；注意 `INF - 1 == INF`，与 JS Infinity 行为一致。
9. **CONFIG 键保留 camelCase**：`Config.CONFIG["enemyTypes"]["chaser"]["weight"]`；GDScript 变量 snake_case，但字典键不翻译。
10. **表现/逻辑分离**：smoke 场景不得实例化任何场景/Node；Events.emit 在 headless 无订阅者时必须安全；game_view.gd 只用于人工验证。

## 5. 完成定义（交付前自查清单）

- [ ] 仓库根执行 `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd`：打印 `registered scenarios: 7`、7 行 `[N] … OK`、`All smoke tests passed`，退出码 0。
- [ ] 仓库根执行 `npm run smoke` 全绿；`git status` 确认 `js/`、`tools/headless-smoke.mjs`、`index.html` 无改动。
- [ ] `SCENARIO_PATHS` 注册顺序 == [0][1][2][3][4][5][7]；所有断言文案带 `[N]` 前缀，可与原型逐条 diff。
- [ ] grep 自查：`logic/` 内无 `Vector2`、无 `Node`/`SceneTree` 引用；无系统随机（全部经 `Rng.next()`）；每个场景的 RNG 注入都有配对恢复（clear_source）。
- [ ] 人工验证 `GameEngine\Godot.exe --path GameProject`（main.tscn）：Enter 开局、WASD 移动、升级自动弹卡、Digit1-3 与鼠标点击选卡、HUD、暂停（Esc）、死亡占位表现均正常。
- [ ] 同一提交更新 PROGRESS.md：§3 M1 复选框勾选、§1 状态 ✅+日期、§2 当前焦点滚动、§6 变更历史追加一行。
- [ ] Conventional Commit 标题，如 `feat: port core loop M1 (smoke [0]-[5],[7])`。