# M2 开发计划 —— 六武器系统（logic/weapons/）

> 规划子Agent-M2M3 产出。范围：js/weapons/* → GameProject/logic/weapons/*（GDScript only，纯 RefCounted 逻辑层）。
> 真值依据：GameProject/RULES.md §12（L517-640）+ 附录 B 裁决表（L1049-1064）+ tools/headless-smoke.mjs 章节 [6]（L261-437）。

## 1. 目标与验收口径

把原型 6 种武器（sword/cloak/talisman/trail/ring/staff）连同 6 级数值表、武器基类与工厂 1:1 移植到 Godot 4.7.1；smoke 章节 [6] 全绿且 M1 章节无回归。

验收命令（两条都必须绿）：

1. `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` —— 全部已注册场景通过（M2 新增 [6]；[0]~[5]、[7] 无回归）。
2. `npm run smoke` —— 原型冒烟无回归（M2 不修改根目录 js/，应天然通过；作为基线确认）。

## 2. 有序子任务表

| # | 新建/修改文件 | 实现要点 | 依赖 | smoke |
|---|---|---|---|---|
| M2-1 | 新建 `logic/weapons/weapon_base.gd` | WeaponBase（extends RefCounted）：`card: Dictionary`、`level=1`、`timer=0.0`；`get_stats() -> card.levels[level-1]`；`update(dt, world)` 虚方法。模块级索敌/AoE 辅助：`nearest_enemy(enemies,x,y,max_dist2=INF)`、`nearest_n(...)`、`hit_enemies_in_radius(world,x,y,radius,damage,on_hit: Callable,damage_options: Dictionary) -> int`（伤害一律走 `world.damage_enemy`，跳过 `e.dead`）。 | 假设 M1 API：`game_run._world()` 已按 RULES §12.0 字段清单提供 world 上下文契约 | [6] |
| M2-2 | 新建 `logic/weapons/talisman.gd` | CARD 表逐字抄 RULES §12.3（damage 12/15/19/23/27/31，interval 1.0→0.70，speed 460(Lv6 490)，range 520(Lv6 550)，bounces Lv4/5=2、Lv6=3）。弹半径 5，`lifetime = range/speed + 0.3`。Lv1 起每次冷却到点发射**恰好 1 枚**弹道。**thunder**：每目标 2 次命中计数（`thunder_counters: Dictionary` 以敌人实例为键，原型 WeakMap 语义：目标死亡/离场清除，不得跨目标泄漏；第 2 次命中 → 落雷 `world.damage_enemy(target, damage*1.5, opts)`）；`_on_projectile_hit(target, projectile)` 供碰撞回调。Lv6 thunderFirst（每波第一击必落雷）/ thunderAoE（落雷附半径 95 AoE）。chain Lv4+：链伤 ×0.5，搜索半径 **180px**（R2=180*180，附录 B#5），玉环环体/尸体可作中继且不消耗跳跃次数。联动预留 `trigger_sword_thunder`（×0.6，noSynergy/noSummon）接口占位。 | M2-1 | [6] |
| M2-3 | 新建 `logic/weapons/sword.gd` | CARD 表 §12.1（damage 16/20/26/32/40/48；Lv1 meleeRange 125/arc 120°/interval 1.15；Lv2+ range 520→640、speed 500→660、interval 1.08→0.80）。Lv1 近战扇形；Lv2+ 发射**单枚**弹道（弹半径 11，`max_hits = INF` 无限穿透）。**drawSlash Lv4+**：`attack_count` 只在命中时 +1（空挥不计数、不充能），每 3 次命中 → 下一次 update 释放环形斩 `rings`：伤害 ×2.5、半径 ringRadius（350/380/344）、经 `world.apply_dot(e, "bleed", ring_bleed_dps, 2.5)` 挂流血（dps 10/11/12）。**swordIntent Lv6**：每 10 次命中生成 1 把飞剑（`_spawn_flying_sword(world)`；飞剑自身命中不计充能 count_intent=false）；环绕半径 48+(n%3)*12、存活 15s、出击 640、伤害 ×0.3、命中挂流血 9/2.5s、连锁 ≤6（flyChain 6，优先 240px 内未命中目标，`flying_swords[i].chains` 计数）、总飞行 >1600 或离目标 >460 强制返回（返回 700）。 | M2-1 | [6] |
| M2-4 | 新建 `logic/weapons/cloak.gd` | CARD 表 §12.2（damage 5/7/10/12/15/18；radius 145→250；burn dps —/10/12/14/16/16）。光环每 0.5s tick 半径内敌人；Lv2+ 附 burn 2s。shock Lv4+：`shock_timer` 冷却 5.5/5.2/3，ticks 6、radMult 1.7/1.8，伤害 = damage×ticks + burn；命中减速 0.3/2s（Lv6 shockSlow 3s）。**enhancedKillShock Lv6（附录 B#7）**：以 `world.kills` 计数每满 100 杀**追加**一次强化冲击（`shocks` 数组记录 `{enhanced=true, radius×1.8, ticks 8, 减速 3s}`），**不重置普通 shock 冷却**（断言 shock_timer > 2.7）。 | M2-1 | [6] |
| M2-5 | 新建 `logic/weapons/trail.gd` | CARD 表 §12.4（**damage 7/10/14/16/21/26 为 [6] 硬断言**；radius 40→62；life 3.5→10；drop 间隔 0.22/0.22/0.18×3；furnaceLife 6/7.5/9）。滴落需玩家移动、间隔 >0.7s 重置路径、PATH_POINT_CAP 180；路径点 `{x, y, at, trail}`。火径每 0.4s tick：damage + **blaze** DoT（与 cloak 的 burn 严格区分，killLog blazed/burned 由此而来）；Lv2+ 另附 burn。**闭环成炉**：首尾 ≤55px、年龄 ≥1.2s、点 ≥4、周长 ≥260、面积 ≥9000、`loop_cooldown` 1.5s → `_try_create_furnace(world, stats)` 生成 furnace。furnace：tick 0.4s 伤害 ×1.25、点火延长 ×4、吸引 25（核心 65）、燃料（击杀 +1；精英/Boss 每 1s +1）、`fuel >= 9` → `_try_open(furnace, world, stats)`：`opens`+1（maxOpens Lv4=1/Lv5+=2）、伤害 ×6、life=min(8,life+2)、openCd 0.75、Lv6 生成 hot_zone。**nineTurn Lv6**：`_update_hot_zones(dt, world, stats)` 热域伤害 damage×1.25×1.5 持续 5s；玩家在域内每 0.5s `world.heal_player(1)`，并经 `world.set_player_move_speed_bonus(source, 1.12)` 给 ×1.12 移速（0.12s 刷新）。上限：trails 80 / furnaces 6 / 热域 8。 | M2-1；killLog burned/blazed 标记依赖 M1 `_kill_enemy` 实现 | [6] |
| M2-6 | 新建 `logic/weapons/ring.gd` | CARD 表 §12.5（damage 12/16/20/26/32/40；count 2/2/3/4/5/6；orbit 56→120；speed 2.6→4.0；expand 80/95/110）。环体接触半径 RING_RADIUS 42；每敌共享命中冷却 0.34s；同帧一环对一敌只命中一次。倍率：狂暴 ×2、扩张 ×2（叠乘 ×4）。coldJade Lv2+ `apply_slow(e, 0.35, 1.6)`（附录 B#1）；bloodDrop Lv4+ 呼吸 3.2s、扩张/收缩各 1s、狂暴呼吸 ×2；Lv6 每 50 杀狂暴 4s（FRENZY_KILL_STEP=50，附录 B#6）；Lv6 反制：监听 `player.lastHurtAt` 变化且 cd 就绪 → 冻结攻击者 2s + 半径 300 伤害 200×damage_mult，cd 16；丹炉充能爆发半径 55 ×0.75。 | M2-1 | [0]（结构）；行为断言在 M4 [19]/[20] |
| M2-7 | 新建 `logic/weapons/staff.gd` | CARD 表 §12.6（damage 7/9/12/14/17/20；count 1/2/2/2/3/3；life 6→9.8；cd 4→2.2；speed 170→220；leash 260/260/260/260/260/280；blastRadius —/—/—/85/125/125 附录 B#8）。召唤槽状态机 cd→ready（leash 内有敌）→active，首槽初始 cd 0.5；召唤体半径 night 17/corpse 12/normal 11；接触 night 22/normal 14+目标半径；hitTimer 0.5；night ×1.5。poison Lv2+（dps 8、3s、溅射 50）。blast Lv4+ 伤害 ×2 携带 `noSummon=true`。**nightParade Lv6**：读 `world.kill_log`（跳过 `noSummon` 条目），转化概率 CONVERT_CHANCE 0.2 用 **Rng.next()**（原型 Math.random，测试注入常量 1.0 时必须全部失败），保底 PITY_KILLS 10，CORPSE_LIFE 10s；上限 REGULAR_CAP 3 / CORPSE_CAP 5 / TOTAL_CAP 8（超限替换最旧；`corpses` 数组断言长度 5）。连接回复 `min(2.0, 1 + 0.5*(存活-1))` HP/s（附录 B#2）。`detonate(corpse_pos, stats, world)` → `world.damage_enemy(e, dmg, {noSummon=true})`。 | M2-1；killLog 结构依赖 M1 | [6] |
| M2-8 | 新建 `logic/weapons/weapon_factory.gd`；新建 `tests/scenarios/s06_weapon_mechanics.gd`；修改 `tests/smoke_runner.gd`（SCENARIO_PATHS 追加） | 工厂：`WEAPON_CARDS: Array`（sword/cloak/talisman/trail/ring/staff 顺序）、`card_by_id(id) -> Dictionary`、`create_weapon(id) -> WeaponBase`（等价原型 `CARD.create()`：new 武器类并注入 card）。s06 逐条复刻 [6]（见 §3）。注册顺序注意：原型章节 [6] 在 [7] 之前，SCENARIO_PATHS 中 s06 须插在 M1 的 s05 与 s07 之间（与 M1 子Agent协调，避免合并冲突）。 | M2-1~7；M1 的 compute_mods/碰撞/killLog | [6][0] |

## 3. smoke 逐章复刻要点

### [6] Weapon mechanic changes（headless-smoke.mjs L261-437）

场景构造：自建 `base_world()` 测试 double（RefCounted），字段与 RULES §12.0 一致：`player={x,y,radius,facing,moving,lastHurtAt}`、`enemies`、`projectiles`、`trails`、`summons`、`effects`、`kill_log`、`mods`（= M1 `compute_mods({projectile:5, area:5, attackSpeed:5, cooldown:5})`，假设 M1 API）、`elapsed`、`kills`，以及回调 `damage_enemy/heal_player/drop_pickup/apply_dot/apply_slow/apply_freeze/set_player_move_speed_bonus`（Callable/闭包计数）。武器经 `WeaponFactory.create_weapon(id)` 创建。

断言清单（全部保留 `[6]` 前缀文案）：

1. talisman：Lv1 `update(1/60.0, world)`（1 个距离 120 的敌人）→ `world.projectiles.size() == 1`。
2. talisman 雷符计数：level=2，`weapon.world = {enemies:[A,B], damage_enemy:计数}`；`_on_projectile_hit(A, {damage=10, attack_seq=1})`、`_on_projectile_hit(B, 同)` → thunderHits==0（不跨目标泄漏）；再 `_on_projectile_hit(A)` → thunderHits==1。
3. sword：Lv2~6 每级 `timer=0` 后 update → 恰好 1 枚弹道且 `max_hits == INF`。
4. 弹道穿透上限（走 M1 `run._handle_collisions()`）：`max_hits=2, pierce=true` 打 3 敌 → 自身 dead、2 敌 hp-10；`max_hits=INF` → 自身不死、3 敌全 hp-10。
5. sword Lv4 拔剑斩：敌人 x=20，循环 3 次「update(2, world) + `world.projectiles.back().on_hit(enemy)`」→ 再 update → `rings.size()==1` 且 apply_dot('bleed') 恰好 1 次；无怪空挥 6 次 → `rings` 空且 `attack_count==0`。
6. sword Lv6 飞剑：`_spawn_flying_sword(world)`，3 敌 x=100/220/340，跑 180 帧 → 3 敌 hp 全 <1000，`peak_chains >= 3`。
7. cloak Lv6：update(0.1) 后 `world.kills=100` 再 update(0.1) → `shocks` 含 enhanced；`shock_timer > 2.7`。
8. burn/blaze 归属：对敌 apply_dot('burn') 后经 `run.damage_enemy` 击杀 → killLog 末条 burned=true、blazed=false；blaze 同理 → blazed=true（依赖 M1 killLog + M2-5/M2-4 的 DoT 类型名）。
9. trail 数值曲线：`levels.map(damage).join(",") == "7,10,14,16,21,26"`。
10. trail Lv6 闭环：手填 `path_points`（5 点成正方形回原点，at 0~1.3s），`elapsed=1.3` → `_try_create_furnace` → furnaces==1 且 `loop_cooldown>0`；`furnace.fuel=9` → `_try_open` → `opens==1`、hot_zones==1；`_update_hot_zones(0.5)` → 治疗累计 1、speedBonus==1.12（±1e-6）。
11. staff Lv6：kill_log 预置 10 条 noSummon → **Rng.set_source(func(): return 1.0)** → update(0) → corpses 空；再塞 60 条普通击杀 → update(0) → corpses==5；`clear_source()`。
12. staff 引爆：`detonate({x=0,y=0,damage=10}, stats, world)` → damage_enemy 收到的 opts `noSummon==true`。

RNG 注入：对应原型 headless-smoke.mjs L420 的 `Math.random = () => 1`，Godot 侧用 `Rng.set_source()` 常量源，用后必须 `Rng.clear_source()`。

## 4. 关键 API 清单（GDScript 伪代码）

```gdscript
# logic/weapons/weapon_base.gd（extends RefCounted；跨脚本引用一律 preload，不依赖 class_name 缓存）
var card: Dictionary; var level: int = 1; var timer: float = 0.0
func get_stats() -> Dictionary:            # card.levels[level-1]
func update(_dt: float, _world) -> void:   # 每帧由 game_run update 第 18 步调用
static func nearest_enemy(enemies: Array, x: float, y: float, max_dist2: float = INF):
static func nearest_n(enemies: Array, x: float, y: float, n: int, max_dist2: float = INF) -> Array:
static func hit_enemies_in_radius(world, x: float, y: float, radius: float, damage: float,
    on_hit: Callable = Callable(), damage_options: Dictionary = {}) -> int:

# logic/weapons/weapon_factory.gd
const WEAPON_CARDS: Array                  # 6 张 CARD（Dictionary：id/name/kind/maxLevel/levels）
static func card_by_id(id: String) -> Dictionary:
static func create_weapon(id: String):     # 未注册 id 返回 null

# 各武器类（sword.gd 示例，余同）
class SwordWeapon extends WeaponBase:      # 实例字段按武器而异
    var attack_count: int = 0              # 只计命中（拔剑斩充能）
    var rings: Array = []                  # 环形斩实例
    var flying_swords: Array = []          # {chains:int, ...} Lv6
    func _spawn_flying_sword(world) -> void:
class TalismanWeapon:
    var thunder_counters: Dictionary = {}  # 敌人实例 -> int（WeakMap 等价）
    func _on_projectile_hit(target, projectile: Dictionary) -> void:
class CloakWeapon:
    var shocks: Array = []; var shock_timer: float
class TrailWeapon:
    var path_points: Array = []; var furnaces: Array = []; var hot_zones: Array = []
    var loop_cooldown: float = 0.0
    func _try_create_furnace(world, stats: Dictionary) -> void:
    func _try_open(furnace: Dictionary, world, stats: Dictionary) -> void:
    func _update_hot_zones(dt: float, world, stats: Dictionary) -> void:
class StaffWeapon:
    var corpses: Array = []
    func detonate(corpse: Dictionary, stats: Dictionary, world) -> void:
```

world 契约（消费方，假设 M1 API：`game_run._world()` 按 RULES §12.0 提供）：数据字段 `player/enemies/projectiles/trails/summons/effects/weapons/mods/elapsed/kills/kill_log`；回调 `damage_enemy(e,dmg,opts)/hurt_player/heal_player/spawn_hostile_projectile/spawn_enemy_blast/drop_pickup/apply_dot/apply_slow/apply_freeze/has_dot/set_player_move_speed_bonus`。若 M1 实际命名有出入，以 M1 交付为准并在 M2-1 中集中适配一处。

## 5. 风险与坑

1. **WeakMap 语义**：雷符每目标 2 连击计数原型用 WeakMap（目标回收即失效）。GDScript 用「敌人实例为 Dictionary 键」会持强引用——必须显式清理：目标 `dead` 或离开 enemies 数组时删除对应键（update 开头按 world.enemies 做一次键清洗），否则跨波泄漏，断言 2 直接失败。备选：计数器内嵌到弹道命中事件的 target 字段上。
2. **INF 语义**：sword Lv2+ `max_hits = INF`、索敌 `max_dist2 = INF`；碰撞侧（M1）比较 `hit_count < max_hits` 时 INF 必须生效。CONFIG 中 chaser.maxAlive 等同为 INF。
3. **RNG 红线**：staff 转化概率、trail 无随机、talisman 无随机——staff 必须走 `Rng.next()`（原型 Math.random，smoke L420 覆盖点）；禁止 logic/ 内 `randf()`。
4. **空挥不充能**（附录 B#4）：`attack_count` 只在本帧至少命中 1 敌时累加；update 里先判定命中再计数。
5. **enhancedKillShock 不重置普通 CD**（附录 B#7）：强化冲击单独发射，`shock_timer` 不动。
6. **burn vs blaze**：两种 DoT 类型名是 killLog burned/blazed 的判据，字符串必须与 js/systems/status.js 完全一致。
7. **SCENARIO_PATHS 合并顺序**：[6] 位于 [7] 之前；M1/M2 同时改 smoke_runner.gd，需约定插入位置。
8. **world double vs 真实 world**：s06 大量使用自建 base_world，武器代码不得假定 world 一定是 game_run 实例（duck typing，字段缺失要有默认分支，如 `set_player_move_speed_bonus` 可缺省）。
9. 假设：M1 的 `_handle_collisions` 已实现 hitSet/hit_count/max_hits(含 INF)/on_hit 回调链（RULES §5.3）；若 M1 未覆盖 INF 分支，M2-8 需与其同步修复。

## 6. Definition of Done

- [ ] `logic/weapons/` 下 weapon_base + 6 武器 + weapon_factory 共 8 个 .gd 落地，纯 RefCounted、无 Node/SceneTree、无渲染逻辑。
- [ ] 六武器 × 6 级数值表与 RULES.md §12 逐字一致，附录 B 的 8 条裁决全部按代码侧实现（#1 环玉减速 0.35/1.6、#2 连接回复封顶 2、#3 furnaceLife 6/7.5/9、#4 飞剑每 10 次命中、#5 链搜索 180px、#6 玉环每 50 杀狂暴 4s/冻结 2s/cd16、#7 披风击杀冲击不重置 CD、#8 爆炸半径 85/125/125）。
- [ ] `tests/scenarios/s06_weapon_mechanics.gd` 注册进 SCENARIO_PATHS，断言文案带 `[6]` 前缀，跨脚本引用全部 preload。
- [ ] `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` 全绿（含 M1 章节无回归）。
- [ ] `npm run smoke` 无回归。
- [ ] 未修改 GameProject/ 内本计划范围外的文件；未触碰根目录 js/、DESIGN.md（2026-08-19 已删除）、Docs/。