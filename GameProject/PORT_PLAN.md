# PORT_PLAN.md — HTML 原型 → Godot 移植实施计划

目标：把根目录 HTML 原型（`js/`，浏览器幸存者类 Roguelike）1:1 移植到 Godot 4.7.1（`GameEngine/Godot.exe`，标准版，**GDScript only**）。第一阶段追求**数值与行为完全对齐**（以原型 smoke 测试的同构复刻为验收标准），美术与手感优化在之后迭代。

规则真值见 `RULES.md`；仓库约定见 `AGENTS.md`。

## 1. 实现决策（已定案）

1. **GDScript only**：不使用 .NET/C#（当前 Godot 为标准版）。
2. **逻辑 / 表现彻底分离**：
   - `logic/` 全部为纯 `RefCounted` 类，不继承 Node、不引用 SceneTree，可在 `--headless` 下运行；
   - `scenes/` 是薄输入/渲染壳，只允许单向依赖 scenes → logic；
   - 表现层事件（特效、震屏、公告、音效钩子）经 `autoload/events.gd` 信号总线广播，逻辑层不感知表现。
3. **不使用 Godot 物理/碰撞/导航**：全部手动欧拉积分 + 距离判定，与 JS 数值逐帧对齐（物理引擎会引入不可控的求解差异）。
4. **固定步长**：`game_view.gd` 在 `_physics_process` 中以累加器调用 `run.step(1.0/60.0)`（对应 RULES.md §2）；帧 dt 钳制 0.25s。
5. **RNG 注入**：原型所有 `Math.random()` → `Rng.next()`（autoload/rng.gd，内部可替换为常量函数）。smoke 场景按原型 headless-smoke.mjs 的 8 个覆盖点（第 420/538/576/807/973/1032/1067/1251 行）注入确定性序列。
6. **Config autoload**：`autoload/config.gd` 为 js/config.js 的 1:1 Dictionary 镜像，**键名保留 JS camelCase**（对照 BALANCE.md）。
7. **统一伤害入口**：所有伤害走 `GameRun.damage_enemy(e, dmg, opts)` / `hurt_player(dmg)`（RULES.md §5），禁止旁路改 hp。
8. **输入模型复刻**：`logic/input_state.gd` 为纯数据快照（pressed 边沿集合 + mouseClicked + 轴）；表现层从 Godot `Input` 填充，测试直接构造。卡牌/按钮点击矩形在 `logic/ui_layout.gd` 复刻 `getCardRects / getWeaponSlotRects / meta 按钮布局`，供输入与 smoke 共用。
9. **渲染**：窗口 1280×720、stretch 关闭；逻辑层 viewW/viewH 常量 1280/720（= JS 回退值）。第一阶段程序化占位渲染（_draw / Polygon2D / Label），还原布局与信息即可。
10. **存档**：`user://save.json`，结构与 JS 版完全一致（version=1，RULES.md §15.5），由 `autoload/meta_save.gd` 读写。
11. **调试系统**：原型 DebugRuntime/DebugPanel（DOM）在 M6 移植为游戏内 debug overlay（F2）+ 同一 settings 结构；`serialize/applySerialized` 保留。
12. **零第三方依赖**：不引入 addon；测试运行器为自研 SceneTree 脚本。

## 2. 目录结构（M0 搭建）

```
GameProject/
├─ project.godot            # 60Hz physics tick；1280×720 无 stretch；autoload 注册
├─ AGENTS.md                # 本目录仓库规范
├─ RULES.md                 # 游戏规则真值（已完成）
├─ PORT_PLAN.md             # 本文件
├─ .gitignore               # 忽略 build/（.godot/ 由根 .gitignore 兜底）
├─ assets/                  # 定稿素材：sprites/ audio/ fonts/ …（连同 .import 一起提交）
├─ autoload/
│  ├─ config.gd             # ← js/config.js（camelCase 键，1:1）
│  ├─ rng.gd                # 可注入随机源（next()）
│  ├─ events.gd             # 表现层信号总线
│  ├─ meta_save.gd          # ← js/meta/save.js（user://save.json）
│  └─ audio_manager.gd      # BGM/SFX 播放层（只读逻辑状态，M6 音频框架）
├─ logic/                   # 纯 RefCounted，可无头运行，与 js/ 一一对应
│  ├─ utils.gd              # ← js/utils.js
│  ├─ game_run.gd           # ← js/game.js（状态机/update 顺序/伤害管线）
│  ├─ player.gd             # ← js/player.js
│  ├─ enemy.gd              # ← js/enemy.js（EnemyBase + 分离）
│  ├─ projectile.gd         # ← js/projectile.js
│  ├─ camera.gd             # ← js/camera.js
│  ├─ input_state.gd        # ← js/input.js（纯快照）
│  ├─ cards.gd              # ← js/cards.js（computeMods/卡池/属性卡）
│  ├─ gems.gd               # ← js/gems.js
│  ├─ spawner.gd            # ← js/spawner.js
│  ├─ rare_items.gd         # ← js/rare-items.js
│  ├─ ui_layout.gd          # ← js/ui-cards.js 的矩形计算 + meta 按钮布局（输入/测试共用）
│  ├─ debug_runtime.gd      # ← js/debug-runtime.js
│  ├─ enemies/              # ← js/enemies/（base/enhanced_chaser/charger/ranged/bomber/shield/boss/hostile_projectile + enemy_factory.gd ← index.js）
│  ├─ weapons/              # ← js/weapons/（weapon_base.gd ← base.js，sword/cloak/talisman/trail/ring/staff + weapon_factory.gd ← index.js）
│  ├─ systems/              # ← js/systems/（waves/status/synergies/tasks）
│  └─ meta/                 # ← js/meta/（drops/items/shop；save 提升到 autoload）
├─ scenes/                  # 表现层（只依赖 logic）
│  ├─ main.tscn
│  ├─ game/                 # game_view.gd（驱动定步长/相机/震屏）、实体视图（对象池）、debug_overlay.gd（F2，M6）
│  └─ ui/                   # hud.gd、card_choice.gd、pause_overlay.gd、meta_screens.gd
├─ tests/
│  ├─ smoke_runner.gd       # 场景注册 + 汇总 + 退出码
│  └─ scenarios/            # [0]–[22] + debug，一章一个 .gd（[0]–[21] 同构复刻 headless-smoke.mjs，[22] 为 Godot 侧音频章节）
└─ tools/
   └─ run_smoke.gd          # SceneTree 脚本：Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd
```

> 目录说明：`.godot/` 为 Godot 编辑器自动生成的缓存目录（gitignored，可随时删除重建，禁止手改/提交）；`build/` 为导出产物统一输出目录（gitignored）。目录归属、写入纪律与素材入库流程见 `AGENTS.md`「工作目录管理」章。

## 3. js → gd 文件映射

| 原型（js/） | Godot（GameProject/） | 说明 |
| --- | --- | --- |
| config.js | autoload/config.gd | camelCase 键 1:1 |
| utils.js | logic/utils.gd | dist/angle/lerp/pointAround 等 |
| main.js | scenes/game/game_view.gd + autoload 注册 | 定步长驱动移入表现层 |
| game.js | logic/game_run.gd | 状态机、update 顺序、碰撞、_world() |
| input.js | logic/input_state.gd | 纯快照，表现层填充 |
| player.js / enemy.js / projectile.js / camera.js | logic/ 同名 .gd | 1:1 |
| cards.js | logic/cards.gd | computeMods/openingOffers/generateOffers/ATTR_CARDS |
| gems.js / spawner.js / rare-items.js | logic/ 同名 .gd | 1:1 |
| enemies/*.js | logic/enemies/*.gd | index.js → enemy_factory.gd |
| weapons/*.js | logic/weapons/*.gd | base.js → weapon_base.gd；index.js → weapon_factory.gd |
| systems/waves,status,synergies,tasks.js | logic/systems/*.gd | 1:1 |
| meta/drops,items,shop.js | logic/meta/*.gd | save.js → autoload/meta_save.gd |
| hud.js | scenes/ui/hud.gd | 布局契约见 RULES.md §17 |
| ui-cards.js | logic/ui_layout.gd + scenes/ui/card_choice.gd | 矩形计算入逻辑层（smoke 需要） |
| ui/meta-screens.js | scenes/ui/meta_screens.gd + logic/ui_layout.gd | 同上 |
| debug-runtime.js | logic/debug_runtime.gd | 跨 reset 存活 |
| debug-panel.js | scenes/game/debug_overlay.gd | DOM → 游戏内 overlay（M6） |
| tools/headless-smoke.mjs | tests/smoke_runner.gd + tests/scenarios/*.gd | 23 章节逐章复刻 + [22] 音频（Godot 侧新增，共 24 章节） |

## 4. 里程碑与验收

每个里程碑的验收 = **对应 smoke 场景在 Godot 侧全绿** + 根目录 `npm run smoke` 无回归（原型不被触碰）。

里程碑的实时状态（当前焦点、任务勾选、风险日志、变更历史）维护在 `PROGRESS.md`；本节表格只定义范围与验收口径。

| 里程碑 | 内容 | 验收场景 |
| --- | --- | --- |
| M0 | 工程脚手架：project.godot、.gitignore、autoload 四件套、目录骨架（含空 assets/）、run_smoke.gd 空跑 | runner 打印 OK 并退出码 0 |
| M1 | 核心循环：状态机、输入、移动、相机、经验/升级、选卡（键盘+鼠标）、属性卡、波次计时 | [0][1][2][3][4][5][7] |
| M2 | 六武器全部机制与等级表 | [6] |
| M3 | 敌人全类型、Boss 战、撤离/继续/死亡、25 波通关、Meta 掉落 | [8][9][10][11][12][13][14][17] |
| M4 | 联动系统（15 组 + 作战选择） | [18][19][20] |
| M5 | 商城、仓库、任务系统 | [15][16][21] |
| M6 | 调试 overlay、性能与打磨（对象池、特效） | [Debug] + 全部章节回归绿 |

## 5. 验证策略与风险

- **同构 smoke**：tests/scenarios 与 headless-smoke.mjs 逐断言对应，断言文案保留 `[章节号]` 前缀，便于两边 diff。
- **RNG 顺序是硬约束**：尤其 rollBossDrops（RULES.md §15.2）与任务抽取；实现时逐调用点对照。
- **浮点**：GDScript float 与 JS Number 同为 IEEE 754 double，数值对齐可行；避免在逻辑层引入 float32（Vector2 默认 float32，逻辑层位置用 float/Dictionary 存储，或统一以 float64 计算后再交给渲染）。
- **WeakMap 语义**（雷符每目标 2 连击计数）：用"以敌人对象为键的 Dictionary"或对象内嵌字段模拟，目标死亡即失效。
- **Infinity 语义**：GDScript 用 `INF`；maxAlive/maxHits 等逐处对照。
- **每里程碑结束**：跑本目录 smoke + 根目录 `npm run smoke`，双绿后合并。