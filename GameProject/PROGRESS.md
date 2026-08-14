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
- smoke 章节移植：**23 / 23**（矩阵见 §4）
- 每次全绿检查：Godot smoke 与根目录 `npm run smoke` 必须双绿。

## 2. 当前焦点（最多 3 项，随进度滚动）

1. **140 敌人性能与对象池**：评估 `WorldArtView` 实体/VFX 分配，补齐压力场景和必要的降级策略。
2. **正式音频**：补充 BGM、武器、受击、掉落、UI 与 Boss 音效，并保持音频层单向读取逻辑状态。
3. **最终回归与导出检查**：完成全量 verify、键鼠/UI 流程复核和 Windows 导出验收。

## 3. 里程碑任务分解

### M0 工程脚手架 ｜ ✅ 完成（2026-08-13）
验收：`GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` 打印 OK、退出码 0；根目录 `npm run smoke` 无回归。
- [x] `project.godot`（60Hz physics tick；1280×720 无 stretch；autoload 注册）
- [x] `.gitignore` 生效验证（`.godot/`、`build/` 不进 git）
- [x] `autoload/config.gd`（与 RULES.md 附录 A 逐键一致，camelCase）
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
验收：Godot 侧 [Debug] 绿 + 全部 23 章节回归绿。
- [x] 玩家动画状态机恢复：主游戏重新接入 `AnimatedSprite2D` / `player_sprite_frames.gd`，支持 Idle、Move、Dead 与八方向动画映射；正左方向镜像、左上/左下独立图集，`player_static.png` 保留为资源缺失回退
- [x] 正式草甸关卡：节点式地形材质挂载 `main.tscn`，预览场景保留为材质调试工具
- [x] 关卡边界逻辑：玩家/敌人/弹道/相机/刷怪点/任务点统一约束，玩家保留视觉安全边距
- [x] 正式世界美术：`WorldArtView` 取代 `PlaceholderWorld`，七类敌人、六武器、弹道、掉落、召唤物、任务和战斗 VFX 全部使用正式资源
- [x] 环境装饰：桃树、岩石、边界石/柱、神龛、灯笼、灌木、草花和落花挂入草甸关卡
- [x] 完整 UI：HUD、卡牌、Boss、任务、稀有物、模态框、菜单、商城、仓库及按钮焦点/禁用状态完成正式资源替换
- [x] 正式中文字体：`Noto Sans SC` 与 OFL 许可进入工程，应用于游戏内 UI 和 Meta UI
- [x] `logic/debug_runtime.gd`（跨 reset 存活 + serialize）
- [x] `scenes/game/debug_overlay.gd`（右上角常驻“调试台 F2”入口；面板打开时暂停世界，支持按钮/F2/Esc/遮罩关闭，并完整保留倍率、生命、刷怪、波次、武器与配置存取功能）
- [ ] 实体视图对象池、VFX 预算与性能检查（140 存活上限）
- [ ] 正式音频资源与音频表现层
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
