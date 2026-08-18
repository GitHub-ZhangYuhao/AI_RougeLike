# 仓库规范（GameProject — Godot 移植子项目）

本目录是根目录 HTML 原型（`js/`）的 Godot 4.7.1 移植项目。**GDScript only（标准版 Godot，无 .NET）**。规则真值在 `RULES.md`，数值真值在 `BALANCE.md`，实现规划在 `PORT_PLAN.md`，进度管理在 `PROGRESS.md`。根目录的 `AGENTS.md` 仍然管辖原型侧代码；本文件只管辖 `GameProject/` 内部。

## 项目结构与模块组织

- `project.godot` — 项目入口：60Hz 逻辑帧；窗口 1280×720、不开 stretch；注册 autoload。
- `autoload/` — 全局单例：`config.gd`（← js/config.js，1:1 Dictionary，**保留 JS camelCase 键名**以便与 `BALANCE.md` 逐键对照）、`rng.gd`（可注入随机源）、`events.gd`（表现层信号总线）、`meta_save.gd`（← js/meta/save.js，user:// JSON）、`audio_manager.gd`（BGM/SFX 播放层：状态机切歌、SFX 池与节流，只读逻辑状态）。
- `logic/` — **纯 GDScript 类（RefCounted），不依赖 Node/SceneTree，可无头运行**。与根目录 `js/` 一一对应：顶层文件对应 `js/*.js`；`enemies/ weapons/ systems/ meta/` 对应 `js/` 同名子目录；`index.js` 移植为工厂（`*_factory.gd`）。数值、公式、时序、RNG 顺序必须与 `RULES.md` 一致。
- `scenes/` — 表现层（Node/场景）：`main.tscn`、`game/`（game_view 驱动定步长、实体视图对象池、debug_overlay）、`ui/`（hud、card_choice、pause_overlay、meta_screens）。**只允许单向依赖 scenes → logic**，禁止 logic 引用任何 Node。
- `tests/` — `smoke_runner.gd` + `scenarios/`（原型 headless-smoke.mjs 的 23 个章节逐章复刻 + Godot 侧新增 [22] 音频章节，一个 .gd 一个章节）。
- `tools/run_smoke.gd` — SceneTree 脚本入口，供 `--headless` 运行。
- `ART_ASSET_CONFIG.md` — 美术资源配置台账；记录已配置、待修订、未配置和集中式占位符，资源状态变化时同步更新。
- 原型侧文件（`js/`、`index.html`、`tools/headless-smoke.mjs` 等）**只读参照，禁止在移植工作中修改**。

## 文档索引与更新纪律

| 文档 | 角色 | 更新纪律 |
| --- | --- | --- |
| `RULES.md` | 游戏规则真值：机制、公式、时序、RNG 顺序（§1–§17）；附录 B 矛盾裁决表；附录 C smoke 章节对照 | 规则变化必须同步；不放数值表（原附录 A 已全量并入 BALANCE.md，现为重定向） |
| `BALANCE.md` | 数值配置唯一文档真值：CONFIG 全量表格（与 `autoload/config.gd` 逐键一致）、21 处 Godot 差异项与调参历史 | 改数流程：先改 `autoload/config.gd` → 同步本表 → 跑 headless smoke 验证 |
| `PROGRESS.md` | 里程碑进度与时间线（§6 表格） | 状态变化只追加一行，不回改历史行 |
| `PORT_PLAN.md` | JS↔GDScript 移植映射、命名对照与关键决策 | 移植约定变化时同步 |
| `PLANS/` | 里程碑计划拆解（M1/M2/M3-plan.md） | 按里程碑维护 |
| `ART_ASSET_CONFIG.md` | 美术资源台账（已配置/待修订/未配置/集中式占位符） | 资源状态变化时同步 |
| `OPTIMIZATION_TRACKER.md` | 优化迭代台账：按轮记录问题、修复与验收 | 新轮追加、不回改旧轮；发现历史记录失真时加「复核」注记而不是改写原文 |
## 工作目录管理

### 全仓库目录归属（谁可以写哪里）

| 目录 / 文件 | 归属 | 移植期间可写性 |
| --- | --- | --- |
| `index.html`、`js/`、`tools/`、`package.json` | HTML 原型 | ❌ 只读参照。改动原型 = 原型演进，必须独立提交并同步 RULES.md，不得夹带在移植提交里 |
| `Docs/` | 策划/设计文档 | ❌ 移植期间不改；矛盾一律按 RULES.md 附录 B 裁决 |
| `GameEngine/` | 本地 Godot 4.7.1 引擎（gitignored） | 只放引擎本体；不放项目文件，GameProject 内不得反向引用引擎目录 |
| `GameProject/` | **Godot 移植唯一工作区** | ✅ 全部 Godot 代码、场景、测试、文档只落在这里 |
| `ArtAsset/` | 美术素材源库（CharacterAnimation / Image / Video） | 只读参照；定稿素材**复制**进 `GameProject/assets/` 后再提交 |
| `Experimental/` | 生成媒体实验区（gitignored） | 临时产物工作区；不进 git，不被 GameProject 引用 |
| `.agents/` | Codex skills 配置 | ❌ 移植期间不改 |

### 目录纪律

- **仓库根目录不再新增任何散落文件或目录**：移植相关新文档进 `GameProject/`，设计类新文档进 `Docs/`，Godot 侧工具进 `GameProject/tools/`（根目录 `tools/` 只服务原型）。
- `GameProject/` 是自包含 Godot 工程：`project.godot` 位于其根，一切被引用的资源必须在目录内部（Godot 只能引用 `res://` 路径）。
- 路径与目录命名：小写 ASCII、snake_case、无空格、无中文（headless CLI 与跨平台兼容）；文件名与类名对应（`GameRun` ↔ `game_run.gd`）。
- 临时脚本、试验场景、草稿一律放 `Experimental/` 或系统临时目录，**不得**落在 `GameProject/` 内。

### Godot 生成目录与构建产物

| 路径 | 性质 | 规则 |
| --- | --- | --- |
| `GameProject/.godot/` | 编辑器缓存 / 导入产物 | 自动生成；根 `.gitignore` 已忽略（`/GameProject/.godot/`）；禁止手改、禁止提交，可随时整目录删除重建 |
| `GameProject/build/` | 导出构建产物 | 统一导出目录；由 `GameProject/.gitignore` 忽略；禁止提交 |
| `assets/**/**.import` | 导入参数 sidecar | **随素材一起提交**（保证各机器导入设置一致） |
| `user://`（save.json、debug 设置） | Godot 用户数据目录 | 在仓库之外，永不进 git |

### 素材入库流程

`ArtAsset/` 或 `Experimental/` 产物 → 选定定稿 → 复制进 `GameProject/assets/<类别>/`（`sprites/`、`audio/`、`fonts/` 等）→ 连同生成的 `.import` 一起提交 → 场景中以 `res://assets/...` 引用。禁止以相对路径引用 GameProject 之外的文件。

---

## 构建、测试与开发命令

- 冒烟测试（在仓库根目录执行）：
  `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd`
- 原型回归（确认移植没有影响原型）：`npm run smoke`
- 编辑器：用 Godot 4.7.1 打开 `GameProject/project.godot`；运行主场景 F5（main.tscn）。
- 无编译/打包步骤；不引入第三方 addon（测试运行器自研）。

## 代码风格与命名规范

- 遵循 Godot 官方 GDScript 风格：4 空格缩进；变量与函数 snake_case（`damage_enemy`）；类名 PascalCase 且与文件名一致（`GameRun` → `game_run.gd`）；常量 UPPER_SNAKE（`RING_HIT_COOLDOWN`）；信号 snake_case；尽量使用静态类型标注。
- **CONFIG 例外**：`autoload/config.gd` 的 Dictionary 键保留 JS camelCase（`startInterval`、`hpPerWaveMid`），与 BALANCE.md 逐键可对照；除此之外禁止在 GDScript 标识符里用 camelCase。
- 逻辑类方法与字段命名尽量映射 JS 原型（`damage_enemy(e, dmg, opts)` ↔ `damageEnemy(e, dmg, opts)`），便于 diff 式核对；映射表见 PORT_PLAN。
- 保持"逻辑 / 表现 / 配置"三类职责分离；表现层不得改写逻辑状态，只能通过逻辑层公开方法驱动。
- 只在机制或约束不明显时才添加注释（例如" bombers 被击杀不爆炸""磁力为锁定式"这类反直觉规则必须注释，并注明 RULES.md 章节号）。

## 测试规范

- 每次提交前运行冒烟测试命令；全绿才可提交。
- 修改战斗、卡牌、波次、输入或状态转换时，必须同步扩展 `tests/scenarios/` 对应章节（保持与原型 headless-smoke.mjs 同构）。
- 测试必须确定性：随机一律通过 `Rng` 注入常量序列，禁止依赖系统随机源；失败时以带描述的 `push_error`/抛出报告。
- 涉及画面或 UI 的改动，还需在编辑器中运行验证：键盘、鼠标、HUD、暂停、死亡、重开。

## 提交与 PR 规范

- Conventional Commit 祈使句，带作用域，例如 `feat(weapons): port talisman chain lightning`。
- 不相关的改动分开提交；一个里程碑内的移植按系统拆分提交（敌人/武器/联动分别提交）。
- PR 说明对玩法的影响、列出已执行的验证步骤（冒烟章节清单）、关联 RULES.md 章节；数值差异与有意保留的局限必须明确标注。
- 任何与 RULES.md 不一致的实现都视为 bug：要么修代码，要么先走"原型变更 → 更新 RULES.md → 再改 Godot"的流程。
- 里程碑 / 任务状态变化（开始或完成里程碑、勾选任务、关闭风险）必须在同一提交里同步更新 `PROGRESS.md`（总览表、当前焦点、任务清单、变更历史），保持其为进度的唯一入口。
---

## 经验沉淀（踩坑记录）

> 规则：每轮 bug 修复完成后，把**通用性**经验追加到本节；只记会再犯的坑，不记一次性细节。每条注明日期与里程碑。

### 2026-08-13 ｜ M0

1. **headless `--script` 没有全局类缓存**：`--headless --script res://...` 运行时不能按 `class_name` 直接按名引用其他脚本类；跨脚本类型引用一律写 `const Foo = preload("res://path/foo.gd")`（场景节点的脚本类型标注同理）。`tests/`、`tools/`、`scenes/` 下的脚本必须遵守。
2. **smoke runner 对"场景不可加载"必须显式失败**：宁可大声报错退出，也不能静默跳过，否则缺章节会被误判为全绿。
3. **config.js 是纯数据**：`autoload/config.gd` 只镜像数据键值（BALANCE.md 逐键 camelCase）；原型中不存在函数型配置，移植时不要为"配置函数"预留结构。
4. **MetaSave 做成纯函数库**：`load_save / persist_save / reset_save / merge_into / default_save`，不持有状态，便于 headless 场景直接调用与测试替换。

### 2026-08-14 ｜ M6

1. **Polygon2D 的 CanvasItem UV 依赖自身纹理**：Godot 4.7.1 中，仅设置 VisualShader 的贴图节点和 `Polygon2D.uv` 不够；`Polygon2D.texture` 为空时 Shader 收到的 UV 会全部为 `(0, 0)`。地形节点必须保留基础纹理，并按基础纹理像素尺寸配置 UV。
2. **序列帧区域优先使用归一化 UV**：动画 PNG 可能经过整体缩放，JSON 中的历史像素坐标会失效。构建 `AtlasTexture` 时优先使用 `uv_min_* / uv_max_* × atlas.get_width/height`，避免帧区域越界或动画中途空白。
3. **正式关卡碰撞仍属于纯逻辑层**：地形场景只负责绘制，地图边界、相机约束、刷怪点和任务点合法化统一放在 `logic/level_geometry.gd`；不要为表现升级引入 Godot 物理碰撞，避免破坏 headless 确定性。
4. **缺失美术统一走集中式占位渲染**：所有临时世界表现收敛到 `scenes/game/placeholder_world_view.gd`，不得把颜色、形状或动画状态写回 logic；正式资源到位后按对象类型逐项替换。
5. **双向 RefCounted 引用会泄漏**：`GameRun` 持有 `DebugRuntime` 时，Runtime 必须用 `weakref(game)` 回指宿主；禁止形成 GameRun ↔ Runtime 强引用环，headless 退出前应无 ObjectDB 泄漏。
6. **动态 Meta UI 只在签名变化时重建**：商城/仓库行项目根据 state、暗晶、等级、库存签名刷新，禁止每个物理帧销毁重建 Control 树。

### 2026-08-18 ｜ M6

1. **`logic/` 的实体是 RefCounted，不是 Dictionary——别用 Dictionary 的取值习惯**：`Object` 没有 `has()`，
   `Object.get()` **只接受 1 个参数**（2 参形式在静态类型下直接是 Parse Error，在 `Variant` 上是每帧运行时错误）。
   判断属性存在一律用 `'prop' in obj`。踩坑现场：`world_art_view.gd` 对 enemy 写了 `enemy.has('state')`
   和 `enemy.get('state','')`，导致 Boss 上屏就打断整个敌人绘制 pass、冲撞兵 windup 打断叠加层 pass
   （血条/DoT/任务图标一起消失），却被两轮「已修复」记录掩盖。**表现层遍历 logic 实体时，
   Dictionary（effects/summons/flying_swords 等纯数据）与 Object（enemy/projectile/weapon）要分清。**
2. **`--script` / `--check-only` 入口拿不到 autoload**：脚本顶层 `preload` + `_init()` 会在 autoload 注册前编译，
   引用 `Config` / `Rng` / `MetaSave` 一律报 `Identifier not found`。所以
   ①`--check-only` 不能用来验证任何引用 autoload 的脚本（会假报错，连未改动的 `sword.gd` 也报）；
   ②入口脚本要像 `tools/run_smoke.gd` 那样在 `_initialize()` 里用运行时 `load()` 取被测脚本。
   想快速验证编译，用 `--headless --import`（编辑器侧会真正编译且 autoload 已就绪）。
3. **进度表只写已落库的东西**：`OPTIMIZATION_TRACKER.md` 曾整轮（第五轮 11 项 + 6 张贴图）标 ✅ 而代码与资源
   都不在仓库里，git 历史也查不到，导致后续按「已完成」继续排期。**标 ✅ 前先 grep 代码 / `git log --all
   --diff-filter=A` 查资源；跨轮引用某个键名（如 `swordProjectileV3`）前先确认它真的存在。**
4. **贴图留白直接决定观感大小**：`_draw_sprite` 的 `factor = display_size / max(w, h)`，
   所以同一 `display_size` 下，留白多的图显示更小。新资源统一裁到 alpha 边界再留 ~4%；
   会被 `direction.angle()` 旋转的贴图（弹道、预警箭头）一律画成朝右（+X）。
5. **新贴图必须连 `.import` 一起入库**：只提交 PNG 时 `preload('res://assets/...')` 解析不到；
   补救是 `Godot --headless --path GameProject --import`，然后把生成的 `.import` 一并提交。
