# PROGRESS.md — Godot 移植统一进度计划

> 本项目**唯一的进度管理文档**（single source of truth for progress）。
> 分工：`RULES.md` 管"规则是什么"，`PORT_PLAN.md` 管"打算怎么做"，本文件管"**做到哪了**"。
> **更新纪律**：任务状态每变化一次，必须在**同一个提交**里同步更新本文件，并在 §6 变更历史追加一行。禁止在别处（PR 描述、聊天、其他文档）另立进度台账。
> 美术资源配置、缺口和占位符清单统一维护在 `ART_ASSET_CONFIG.md`；该文档不替代本进度台账。

## 1. 进度总览

| 里程碑 | 主题 | 验收（Godot 侧 smoke 章节） | 状态 | 完成日期 |
| --- | --- | --- | --- | --- |
| M0 | 工程脚手架 | runner 空跑 OK | ✅ 完成 | 2026-08-13 |
| M1 | 核心循环 | [0][1][2][3][4][5][7] | ✅ 完成 | 2026-08-14 |
| M2 | 六武器 | [6] | ✅ 完成 | 2026-08-14 |
| M3 | 敌人 / Boss / 局流程 | [8][9][10][11][12][13][14][17] | ✅ 完成 | 2026-08-14 |
| M4 | 联动系统 | [18][19][20] | ✅ 完成 | 2026-08-14 |
| M5 | 商城 / 仓库 / 任务 | [15][16][21] | ✅ 完成 | 2026-08-14 |
| M6 | 调试 / 性能 / 打磨 | [Debug] + 全部回归 | 🟨 进行中 | — |

状态图例：⬜ 未开始 ｜ 🟨 进行中 ｜ ✅ 完成 ｜ ⛔ 受阻（必须同步登记到 §5）

- 里程碑完成度：**6 / 7**
- smoke 章节移植：**26 / 26**（矩阵见 §4，含 Godot 侧新增的 [22] 音频、[23] 触屏选卡与 [24] 序列帧章节）
- 每次全绿检查：Godot smoke 与根目录 `npm run smoke` 必须双绿。

## 2. 当前焦点（最多 3 项，随进度滚动）

1. **180 敌人性能与对象池**：逻辑侧空间网格 + 弹道对象池已落地（`3b47af2`，基准 harness `17720a5`）；剩余为 `WorldArtView` 实体/VFX 视图侧池化、VFX 预算与压力场景检查。
2. **正式音频**：AudioManager 框架已落地（`autoload/audio_manager.gd` + s22 冒烟章节），SFX 24 条 ogg 入库（覆盖 `SFX_PATHS` 全部 23 键），BGM 3/6（menu/battle/boss）；剩余：BGM 3 条（rest/extraction/summary）；SFX 事件映射与 BGM 音量/交叉淡化参数已落库（`0bc9de9`），音频层保持单向读取逻辑状态。
3. **最终回归与导出检查**：微信小游戏打包达标（全量档总包 29.05MB ≤ 30MB 限额，分支 perf/minigame-etc2）；剩余：全量 verify / 键鼠 UI 流程复核、抖音 slim 档 0.7MB 差额、两端真机验证与提审准备。

> 打磨类待办（敌人预警、稀有物数值、序列帧、死资源等）不占用上面三项焦点，
> 清单维护在 `OPTIMIZATION_TRACKER.md` §第八轮候选，数值待校准项在 `BALANCE.md` §待校准项。

## 3. 里程碑任务分解

### M0 工程脚手架 ｜ ✅ 完成（2026-08-13）
验收：`GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` 打印 OK、退出码 0；根目录 `npm run smoke` 无回归。
- [x] `project.godot`（60Hz physics tick；1280×720 无 stretch；autoload 注册）
- [x] `.gitignore` 生效验证（`.godot/`、`build/` 不进 git）
- [x] `autoload/config.gd`（与 BALANCE.md 逐键一致，camelCase）
- [x] `autoload/rng.gd`（可注入随机源）
- [x] `autoload/events.gd`（表现层信号总线）
- [x] `autoload/meta_save.gd`（user://save.json，结构见 RULES.md §15.5）
- [x] 目录骨架：logic/（含 enemies/ weapons/ systems/ meta/）、scenes/（game/ ui/）、tests/scenarios/、tools/、assets/（空）
- [x] `tools/run_smoke.gd` + `tests/smoke_runner.gd` 空跑（0 场景也算 OK）

### M1 核心循环 ｜ ✅ 完成（2026-08-14）
验收：Godot 侧 [0][1][2][3][4][5][7] 全绿。
- [x] `logic/utils.gd`、`logic/input_state.gd`、`logic/player.gd`、`logic/camera.gd`
- [x] `logic/game_run.gd`：状态机 + update 25 步顺序 + 伤害管线（RULES.md §1/§2/§5）
- [x] `logic/cards.gd`（computeMods / 开局与升级卡池 / 6 属性卡）+ `logic/ui_layout.gd`（卡牌/武器槽/meta 按钮矩形）
- [x] `logic/gems.gd`（锁定式磁吸 + 升级公式）
- [x] `logic/spawner.gd` + `logic/systems/waves.gd`（定时波，先不含精英/Boss 分支的敌人部分）
- [x] `scenes/main.tscn` + `scenes/game/game_view.gd` 定步长驱动 + 占位渲染 + 输入填充
- [x] `tests/scenarios/`：[0][1][2][3][4][5][7]

### M2 六武器 ｜ ✅ 完成（2026-08-14）
验收：Godot 侧 [6] 全绿。
- [x] `logic/weapons/weapon_base.gd` + sword / cloak / talisman / trail / ring / staff + `weapon_factory.gd`
- [x] 六武器 × 6 级数值表与 RULES.md §12 逐条对齐（含附录 B 裁决项）
- [x] `tests/scenarios/`：[6]

### M3 敌人 / Boss / 局流程 ｜ ✅ 完成（2026-08-14）
验收：Godot 侧 [8][9][10][11][12][13][14][17] 全绿。
- [x] `logic/enemy.gd`（EnemyBase + 分离 + 波次成长）+ `logic/systems/status.gd`
- [x] `logic/enemies/` 7 类型 + `enemy_factory.gd` + 敌方弹道
- [x] 类型选择权重与 replacementRatio（RULES.md §7.4）
- [x] Boss 波全流程：增援 / overtime / 清场 / 掉落
- [x] `logic/meta/drops.gd`、`logic/meta/items.gd`（RNG 顺序严格按 RULES.md §15.2）
- [x] 撤离 / 继续深入 / 死亡 / 25 波通关 / summary
- [x] `tests/scenarios/`：[8][9][10][11][12][13][14][17]

### M4 联动系统 ｜ ✅ 完成（2026-08-14）
验收：Godot 侧 [18][19][20] 全绿。
- [x] `logic/systems/synergies.gd`（refresh 签名 / selectedPairKey / 公告）
- [x] 各武器内嵌联动效果（15 组，RULES.md §13）
- [x] 作战选择（武器槽点击 toggleBuildWeapon）
- [x] `tests/scenarios/`：[18][19][20]

### M5 商城 / 仓库 / 任务 ｜ ✅ 完成（2026-08-14）
验收：Godot 侧 [15][16][21] 全绿。
- [x] `logic/meta/shop.gd`（价格曲线 + 购买约束）+ 仓库卖出
- [x] `logic/systems/tasks.gd`（guard/delivery/bounty + 奖励池）
- [x] meta 界面（scenes/ui/meta_screens.gd：menu/shop/storage/extraction/summary/dead）
- [x] `tests/scenarios/`：[15][16][21]

### M6 调试 / 性能 / 打磨 ｜ 🟨 进行中
验收：Godot 侧 [Debug] 绿 + 全部 26 章节回归绿。
- [x] 玩家动画状态机恢复：主游戏重新接入 `AnimatedSprite2D` / `player_sprite_frames.gd`，支持 Idle、Move、Dead 与八方向动画映射；正左方向镜像、左上/左下独立图集，`player_static.png` 保留为资源缺失回退
- [x] 正式草甸关卡：节点式地形材质挂载 `main.tscn`，预览场景保留为材质调试工具
- [x] 关卡边界逻辑：玩家/敌人/弹道/相机/刷怪点/任务点统一约束，玩家保留视觉安全边距
- [x] 正式世界美术：`WorldArtView` 取代 `PlaceholderWorld`，七类敌人、六武器、弹道、掉落、召唤物、任务和战斗 VFX 全部使用正式资源
- [x] 静态图片质量升级：经验宝石、玉环、玉卫、鬼火和骷髅尸体使用独立世界图片；16 张单帧 VFX 与 11 张现代 UI 装饰完成手绘替换；动态闪电、拖尾、序列帧和视频延期
- [x] 环境装饰：桃树、岩石、边界石/柱、神龛、灯笼、灌木、草花和落花挂入草甸关卡
- [x] 完整 UI：HUD、卡牌、Boss、任务、稀有物、模态框、菜单、商城、仓库及按钮焦点/禁用状态完成正式资源替换
- [x] 桃夜巡 UI 方向：主菜单按批准稿还原；局内 HUD 与开局/升级卡牌拆为背板、边框、头像环、状态条、图标、花饰、法器槽和标签等原子组件动态拼装，法器视觉槽与点击命中区域统一，六卡/三卡/悬停状态完成画面复核
- [x] 第三轮玩法优化：60 秒强制波次、后期伤害容错、死亡暗晶保底、单一主联动及常驻反馈、武器升级收益说明
- [x] 武器质变表现：六武器 Lv4 觉醒、Lv6 终极蜕变专属演出；Build 成型横幅、镜头冲击、世界爆发与持续法器连线
- [x] 正式中文字体：`Noto Sans SC` 与 OFL 许可进入工程，应用于游戏内 UI 和 Meta UI
- [x] `logic/debug_runtime.gd`（跨 reset 存活 + serialize）
- [x] `scenes/game/debug_overlay.gd`（右上角常驻“调试台 F2”入口；面板打开时暂停世界，支持按钮/F2/Esc/遮罩关闭，并完整保留倍率、生命、刷怪、波次、武器与配置存取功能）
- [ ] 实体视图对象池、VFX 预算与性能检查（180 存活上限；逻辑侧空间网格 + 弹道池已落地 `3b47af2`，确定性基准 harness `17720a5`）
- [ ] 正式音频资源与音频表现层（AudioManager 框架已落地，SFX 24 条覆盖 23 键、BGM 3/6；SFX 事件映射与 BGM 音量/交叉淡化参数已落库 `0bc9de9`，仅剩 BGM 3 条 rest/extraction/summary，清单见 ART_ASSET_CONFIG.md §9）
- [ ] Windows 导出与最终人工回归

## 4. smoke 章节移植矩阵

| 章节 | 标题 | 里程碑 | 状态 |
| --- | --- | --- | --- |
| [0] | Weapon card structure | M1 | ✅ |
| [1] | 主菜单 → 开局选卡 | M1 | ✅ |
| [2] | 移动 | M1 | ✅ |
| [3] | 站桩 60 秒定时波 | M1 | ✅ |
| [4] | 鼠标点击选卡 | M1 | ✅ |
| [5] | 属性卡 / 护甲 / 生命上限 | M1 | ✅ |
| [6] | 六武器机制与上限 | M2 | ✅ |
| [7] | generateOffers 卡池规则 | M1 | ✅ |
| [8] | 敌人基类与特殊机制 | M3 | ✅ |
| [9] | 波次 / Boss / 精英掉落 / 磁吸 | M3 | ✅ |
| [Debug] | Debug Runtime | M6 | ✅ |
| [10] | 死亡与 R 返回 | M3 | ✅ |
| [11] | Boss 掉落概率边界 | M3 | ✅ |
| [12] | 撤离流程 | M3 | ✅ |
| [13] | 继续深入 | M3 | ✅ |
| [14] | 死亡损失 | M3 | ✅ |
| [15] | 商城 | M5 | ✅ |
| [16] | 仓库卖出与局外属性 | M5 | ✅ |
| [17] | 25 波通关 | M3 | ✅ |
| [18] | synergy 基础设施 + 15 Builds | M4 | ✅ |
| [19] | Build batches 1-2 | M4 | ✅ |
| [20] | Build batch 3 | M4 | ✅ |
| [21] | 局内随机任务与奖励 | M5 | ✅ |
| [22] | 音频系统（AudioManager） | M6 | ✅ |
| [23] | 触屏选卡（触摸→鼠标桥接） | M6 | ✅ |
| [24] | 序列帧图集裁帧（flipbook） | M6 | ✅ |

## 5. 阻塞问题与风险登记

| # | 日期 | 问题/风险 | 影响 | 状态 | 处置 |
| --- | --- | --- | --- | --- | --- |
| 1 | 2026-08-14 | 旧玩家序列帧曾因正式静态图替换而退出主场景，动画状态机出现回归 | 影响角色移动方向与动画反馈 | 已解决 | 主游戏恢复 `AnimatedSprite2D`、八方向 SpriteFrames 与 Idle/Move/Dead 状态映射；静态图仅作为资源缺失回退 |
| 2 | 2026-08-14 | 当前 `main` 缺少仓库规范提到的 `GameProject/tools/verify.ps1` 与根目录 `gdlintrc`；按备份配置运行全量 gdlint 暴露 263 个未清零问题（包含既有基线与本轮表现层） | 不影响本轮运行时验收，但无法宣称一键 verify/gdlint 全绿 | 待处理 | 本轮已直接完成 Godot 导入、356 项 Godot smoke 与原型 smoke；工具链恢复和全库 lint 作为独立改动处理 |

> 任何里程碑被卡住超过 1 天，必须在此登记并调整 §2 当前焦点。

## 6. 变更历史

| 日期 | 里程碑 | 变更说明 | 提交 |
| --- | --- | --- | --- |
| 2026-08-13 | — | 立项：完成 RULES.md / AGENTS.md / PORT_PLAN.md / PROGRESS.md 四份规划文档；原型 `npm run smoke` 全绿基线 | 待提交 |
| 2026-08-13 | M0 | 脚手架完成：project.godot（60Hz tick、1280×720 无 stretch、Config/Rng/Events/MetaSave 四 autoload、main.tscn 指向）、config.gd 1:1 镜像附录 A、rng.gd 可注入源、events.gd 信号总线、meta_save.gd（user://save.json，§15.5 结构）、目录骨架、headless smoke 入口空跑 OK（45 项自检，注册表/失败/缺场景路径三种分支均已验证） | 待提交 |
| 2026-08-14 | M1 | M2/M3 实施计划定稿（PLANS/M2-plan.md、M3-plan.md）；M1 开发启动：tests/scenarios/_harness.gd 与 logic/{utils,input_state,camera,player}.gd 已落盘，smoke 未跑。本会话中断，开发进度详见 build/reports/M1-dev-notes.md（gitignore），下次会话继续 | 11f17f0 |
| 2026-08-14 | M1 | 核心循环完成：状态机、移动/相机、卡牌、宝石、定时波、场景驱动与 smoke [0][1][2][3][4][5][7] 全绿 | 待提交 |
| 2026-08-14 | M2 | 六武器完整机制、6 级数值、弹道/状态/world 契约与 smoke [6] 全绿 | 待提交 |
| 2026-08-14 | M3 | 7 类敌人、Boss 波、掉落、死亡/撤离/深入/25 波通关与 smoke [8][9][10][11][12][13][14][17] 全绿；Godot 189 项、原型 smoke 双绿 | 待提交 |
| 2026-08-14 | M4 | SynergySystem、15 组武器 Build、作战选择与 smoke [18][19][20] 全绿 | 待提交 |
| 2026-08-14 | M5 | 商城、仓库、局外属性、guard/delivery/bounty、任务奖励和独立 meta UI 场景完成；smoke [15][16][21] 全绿，Godot 共 299 项 | 待提交 |
| 2026-08-14 | M6 | 启动表现层打磨：接入玩家 Idle/Move 序列帧、八方向状态机、16 FPS 播放、暂停同步与独立 HUD 绘制层；Godot 307 项、原型 smoke 双绿 | 7db4f2a |
| 2026-08-14 | M6 | 将节点式草甸地形转为主游戏正式关卡；新增确定性地图边界，约束玩家、敌人、弹道、相机、刷怪与任务坐标；Godot 313 项、原型 smoke 双绿 | 7db4f2a |
| 2026-08-14 | M6 | 新增集中式 PlaceholderWorld：补齐七类敌人、弹道、经验、掉落、召唤、披风/玉环/丹火区域、任务标记和联动特效的临时可读表现；Godot 315 项、原型 smoke 双绿 | 1ab6e6b |
| 2026-08-14 | M6 | 完成 UI 正式化与 Debug 移植：GPT Image 2 标题徽记、HUD/卡牌/菜单/商城/仓库/局流程界面、F2 Debug Runtime/Overlay；Godot 340 项、23/23 章节与原型 smoke 双绿 | 待提交 |
| 2026-08-14 | M6 | 完成正式美术替换与 UI 收尾：`WorldArtView` 取代 `PlaceholderWorld`，接入七类敌人、六武器、弹道、掉落、召唤、任务、16 类 VFX、12 类环境装饰、12 类 UI ornament、正式玩家贴图、动画回退与 Noto Sans SC；Godot 346 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-14 | M6 | 恢复玩家 Idle/Move/Dead 八方向动画状态机；将 Debug 以常驻入口、自动暂停和主题化面板正式合入游戏；强化 HUD、武器槽、任务、卡牌与菜单标题资源；Godot smoke 356 项/23 场景全绿 | 待提交 |
| 2026-08-14 | M6 | 完成现代 Q 版 UI 重构：新增 13 类 SVG/PNG 图形资源，重排 Meta Header、功能卡、选卡、HUD/法器 Dock、商城、仓库与 Debug；统一奶油白、珊瑚红、薄荷绿、蜂蜜黄和深褐描边；Godot smoke 358 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-14 | M6 | 优化图标 UI 与草甸材质：选卡、法器 Dock、任务、稀有物和 Boss 图标统一为现代 Q 版圆章；接入四张无缝锐化 WebP、文本 Shader、mipmap 与各向异性过滤，移除旧采样造成的矩形分区并提升地表清晰度 | 待提交 |
| 2026-08-14 | M6 | 落地桃夜巡 B+A 视觉方向：主菜单按批准稿还原；局内 HUD 与卡牌改为 `assets/ui/peach_night/atomic/` 原子资源拼装，重排底部状态栏、法器槽、六卡开局与三卡升级选择，统一法器命中区域并完成 hover/选中态画面复核；Godot smoke 358 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-15 | M6 | 手感调参：相机 zoom 1.15→1.0、玩家视图缩小约 8%、敌人显示倍率 5.35/4.85→6.6/6.2（影子 ×0.92）；敌人速度 85→76、血量 50→45、存活上限 20/8/140→30/10/180、波配额基数 16→24、增长 0.5→0.8；RULES.md §7.1/§8/附录 A/B 与 config.gd 注释同步；Godot smoke 358 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-15 | M6 | 数值第二轮调参（血太厚/移速涨太快/怪太少）：enemy hpPerMin 54→10、hpPerWave 三段 0.16/0.30/0.28→0.10/0.12/0.10、hpWaveCap 7→3、speedPerMin 0.08→0.015、baseSpeedMult 1.5→1.35、speedWaveCap 2→1.6；存活上限 30/10→40/12（maxAliveCap 180 不动，M6 性能焦点 #1 压测指标）；波配额基数 24→30、增长 0.8→1.2、上限 11.25→14；apply_wave_scaling 由硬编码改为 Config 驱动（对齐 js/enemies/base.js）；RULES.md §7.1/§7.2/§8/附录 A/B#10 与 config.gd/smoke_runner/s08/s09 断言同步；Godot smoke 358 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-15 | M6 | 数值配置文档整合：RULES.md 附录 A 全量并入新建 BALANCE.md（分系统表格 + js 原值标注 + 调参历史），附录 A 改重定向，config.gd/smoke_runner.gd/AGENTS.md/PORT_PLAN.md/PROGRESS.md 引用同步；Godot smoke 359 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-15 | M6 | 文档体系固化：根 AGENTS.md 与 GameProject/AGENTS.md 新增「文档索引（真值与更新纪律）」章节，开篇/config.gd 条目同步 BALANCE.md 引用 | 待提交 |
| 2026-08-15 | M6 | 完成静态图片资源优化：重绘并接入经验宝石；新增玉环、玉卫、鬼火和骷髅尸体世界图片；替换 16 张第一代单帧 VFX 与 11 张现代 UI 装饰；更新美术台账并明确动态闪电、拖尾、动画和视频延期；修正 VFX 资源数断言，Godot smoke 359 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-17 | M6 | 第三轮玩法优化：完整局改为 25×60 秒；下调中后期敌人伤害；死亡保留 35%波数暗晶；联动改为单一主联动并增加常驻说明、统一触发灵光和数字键选择；普通/任务武器卡显示本级收益；Godot smoke 423 项/23 场景与原型 smoke 双绿 | 待提交 |
| 2026-08-17 | M6 | 强化成长高潮：六武器 Lv4/Lv6 分别获得专属觉醒/终极蜕变演出及常驻阶位光环；Build 成型增加专属横幅、青金世界爆发、镜头冲击、法器持续连线，并放大实际触发灵光；Godot smoke 403 项/23 场景全绿 | 待提交 |
| 2026-08-18 | M6 | 补齐 OPTIMIZATION_TRACKER 第四/五轮未落库缺口：修复 `world_art_view` 对 Object 误用 `has()`/双参 `get()` 导致的 Boss 与冲撞兵绘制 pass 中断；道剑 Lv2–5 `maxHits` 恢复 INF 对齐原型；新增任务目标引导（导引线/光柱/屏外箭头）、重做冲撞预警、放大稀有拾取与 Lv6 飞剑、去除远程兵多余光晕圆、Lv2 弹道贴图补 45° 偏移；新增 5 张 384×384 RGBA VFX（gpt-image-1.5）并补齐 `.import`；debug 新增发放暗晶；Godot smoke 405 项/23 场景与原型 smoke 双绿 | 0b05978 |
| 2026-08-18 | M6 | 复核记录：OPTIMIZATION_TRACKER 追加验收反馈调整与「第八轮候选」待办清单，BALANCE 新增「待校准项」（道剑穿透后武器强度重排、稀有物无上限叠加与盾兵掉落源过宽、rarePickupRadius 58 复核），ART_ASSET_CONFIG 修正盾兵/自爆兵/精英狂暴状态表现缺失的标注 | 待提交 |
| 2026-08-18 | M6 | 音频系统落地：新增 AudioManager autoload（BGM/SFX 状态机、武器与波次音效绑定、节流与清理），将视频生成音频转制为技能音效 sfx_cloak_burst / sfx_trail_blaze（ogg，WAV 母带存 ArtAsset/Audio/sfx），default_bus_layout 总线布局；新增 s22 音频冒烟场景，Godot smoke 415 项 24 场景与原型 smoke 双绿 | 4cf0420 |
| 2026-08-19 | M6 | 数值收敛（Hooke 轮）：盾兵基础阶位 elite→normal，精英仅由精英波（eliteEvery=3）产出，单局稀有掉落上限收敛至 18（精英 8 + Boss 5×2）；新增乘法类稀有加成硬上限（伤害≤1.8 / 经验≤2.0 / 移速≤1.35 / 磁吸≤240）；Godot rarePickupRadius 58→40；雷符咒 Lv1–3 改为 count 指向最近目标的多发雷弹（4/4/4/2/2/1，Lv3 DPS 30→118），丹火 Lv6 伤害 26→28；新增确定性武器校准工具 weapon_balance.gd，Lv3 DPS 离散度 4.61x→1.18x；BALANCE/RULES 同步更新，Godot smoke 415 项与原型 smoke 双绿 | 250a430 |
| 2026-08-19 | M6 | 两侧对齐：js talisman thunderAoE 半径 95→80，与 Godot/RULES 一致（第六轮遗留清零）；原型 smoke 绿 | 0e89026 |
| 2026-08-19 | M6 | 两套 25 帧序列帧图集入库：cloak_fire_burst_anim / furnace_flame_anim（MiniMax H3 视频→ComfyUI 抽帧→5×5 图集）+ .import；生产管线归档 ArtAsset/Image/VFX/gen_20260818_anim；art_catalog/world_art_view 抽帧集成待做 | 671cea9 |
| 2026-08-19 | M6 | 开炉 SFX：新增 sfx_furnace_open（视频生成音频转制 ogg，WAV 母带存 ArtAsset/Audio/sfx），audio_manager 监听丹火炉累计开炉数触发播放（高频节流 0.12s），s22 冒烟扩展；SFX 账面 3/23，Godot smoke 419 项 / 24 场景与原型 smoke 双绿（文档同提交纪律由 f764530 后补） | ab77e16 |
| 2026-08-19 | M6 | 序列帧运行时接入：新增 flipbook.gd 纯函数裁帧；cloakFireBurstAnim/furnaceFlameAnim 入库（VFX_TEXTURES 22→24），披风 Lv6 爆发一次性播放 + 丹炉/余烬/丹火循环火焰（世界坐标相位）；另补 4 类敌人预警（bomber 自爆蓄力/enhanced_chaser 狂暴前/Boss 弹幕蓄力/ranged 枪口蓄力点）；新增 s24_flipbook 章节，Godot smoke 436 项 / 25 场景与原型 smoke 双绿（文档补录） | cbab517 |
| 2026-08-19 | M6 | 音频资源批量入库：21 条 SFX + 3 条 BGM（battle/boss/menu），磁盘 SFX 24 条覆盖 SFX_PATHS 全部 23 键（部分键共用文件）、BGM 3/6；s22 抽查通过（文档补录） | ff44fac |
| 2026-08-19 | M6 | 披风火焰爆燃序列帧重抠像：BiRefNet 抠像侵蚀弥散火焰，改亮度阿尔法重键（remat_luma.py），图集原位重建、硬规格不变，覆盖率弧线恢复蓄力 53–72% → 爆发 82–88% → 单调消散；资产零回归（文档补录） | 12b1180 |
| 2026-08-19 | — | 仓库基建：引入 `.agents/skills` 本地化游戏开发 toolkit 并移除不适用的引擎/类型技能（非里程碑任务，outpaint 控件同步见 `2f48fe6`） | 7f31bfa / 42d58e4 |
| 2026-08-19 | M6 | 逻辑侧性能：空间网格邻域查询 + 弹道对象池打通 180 存活上限瓶颈（game_run/enemy/projectile/武器侧接入）；另新增确定性 spatial-grid 基准 harness | 3b47af2 / 17720a5 |
| 2026-08-19 | M6 | 音频事件映射落库：AudioManager 改听 Events.sfx_requested 与武器计数变化，BGM_VOLUME/BGM_CROSSFADE 参数入库；同提交火球序列帧图集；披风爆燃图集重抠像与 .uid 补齐 | 0bc9de9 / 4d6b7c9 |
| 2026-08-19 | M6 | 丹炉火焰 flipbook 图集重制（Krea-2 + MiniMax H3 + BiRefNet）、编码损坏修复与丹火绘制对齐 2048 新图集、行走 trail 火焰换用新图集；Lv6 武器蜕变 VFX 设计与音频收尾文档同步 | a260d55 / 095bef1 / e0f5ee6 / bae597e |
| 2026-08-19 | M6 | 草地关卡地面缩放与背景适配、边界碰撞改挂 Area2D 并精调多边形；新增 Windows Desktop 导出预设；gitignore Godot MCP 缓存目录 | 0687c04 / 31165e4 / 2f9da1f / 7b18faa |
| 2026-08-20 | M6 | 触屏输入：触屏点击桥接鼠标语义、支持直接点选卡牌；新增 s23_touch_choice 冒烟章节（Godot smoke 自此 26 场景）；smoke 退出前延长 10 帧回收窗口消除 Ogg 播放链误报泄漏 | bf81834 / 8efd960 / f970ccc |
| 2026-08-20 | M6 | 导出卫生与关卡编辑：导出排除 tests/tools/markdown；可行走边界改为场景多边形节点驱动、支持编辑器可视化拖动 | 22562f9 / d002290 |
| 2026-08-20 | M6 | 资产瘦身：行走图 atlas 分四批降至 2048²（8 方向）、WALK_SCALE 0.14→0.28 补偿视觉尺寸；中文字体子集化与子集再生工具 | 4fd5e98…ea2287d / 6b406d8 |
| 2026-08-20 | M6 | 草地地形贴图外扩至 4096² 并接入场景（同日为 APK 瘦身又收敛至 2048²，见 `744bc3e`） | c8c5e76 |
| 2026-08-20 | M6 | Android 导出链路：Android 导出预设 + ETC2 纹理压缩打包环境落地；release APK 瘦身至 121 MB（地形图 2048²、死资产排除、正式签名打包） | d00814d / 744bc3e |
| 2026-08-20 | — | 复核注记：§6 变更历史自 `12b1180` 起约 30 个提交未随提交同步登记，本批为集中补录；§1/§4 同步修正 smoke 基线为 459 项 / 26 场景，§2 焦点与 M6 任务状态按已提交事实更正 | （本次补录） |
| 2026-08-20 | M6 | 小游戏导出链路：Godot 4.5.1 并存 + godothub godot-minigame 插件；新增「微信小游戏」导出预设两个（全量/精简量尺寸），headless 导出 EXIT=0（全量 142.6MB / 精简 10.74MB）；新增 pck 体积审计工具（97% 为无损纹理）与发布准备清单文档 | 1de5bb4 |
| 2026-08-20 | M6 | 小游戏包体达标与打包工具链：全纹理切 ETC2（ctex 132.27→19.92MB，-85%）+ BGM 重编码（音频 2.41→1.52MB）+ 双预设统一 78 条死资产排除；preset.3 由「排除全部美术目录」重设计为 slim 导入尺寸档（整目录排除破坏 preload()，废弃）；新增 minigame_export.ps1（自动剥离/恢复 MCPRuntime + slim 档 .import 快照舞）/ minigame_size_limit.gd（default/slim 两档）/ exclude_check 与 unused_scan 工具；实测全量档总包 29.05MB（微信 30MB 达标）/ slim 档 20.69MB（抖音 20MB 微超 0.7MB），两档 pck 运行时验证零错误，双 smoke 459 项 / 26 场景全绿 | （本次提交） |
