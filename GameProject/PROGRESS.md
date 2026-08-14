# PROGRESS.md — Godot 移植统一进度计划

> 本项目**唯一的进度管理文档**（single source of truth for progress）。
> 分工：`RULES.md` 管"规则是什么"，`PORT_PLAN.md` 管"打算怎么做"，本文件管"**做到哪了**"。
> **更新纪律**：任务状态每变化一次，必须在**同一个提交**里同步更新本文件，并在 §6 变更历史追加一行。禁止在别处（PR 描述、聊天、其他文档）另立进度台账。

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
- smoke 章节移植：**22 / 23**（矩阵见 §4）
- 每次全绿检查：Godot smoke 与根目录 `npm run smoke` 必须双绿。

## 2. 当前焦点（最多 3 项，随进度滚动）

1. **M6 调试 / 性能 / 打磨**：玩家动画、正式草甸关卡和统一占位符表现已接入；继续补 Debug Runtime、对象池与全量 23 章节回归。
2. **关卡组件扩展**：逐步加入独立树木、岩石等场景组件，并在纯逻辑层登记对应障碍几何。
3. **角色表现扩展**：沿用 PlayerView 管线接入普通敌人移动动画与 Boss 专用状态机。

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
- [x] 玩家 PlayerView：Idle/Move 序列帧、八方向映射、16 FPS 移动动画与表现状态机
- [x] 正式草甸关卡：节点式地形材质挂载 `main.tscn`，预览场景保留为材质调试工具
- [x] 关卡边界逻辑：玩家/敌人/弹道/相机/刷怪点/任务点统一约束，玩家保留视觉安全边距
- [x] 统一占位符表现：敌人类型、玩家/敌方弹道、经验、掉落、召唤物、武器区域、任务点与联动特效均可识别
- [ ] 玩家源序列帧资源修订：当前画面异常已确认来自源素材，图集解析、方向映射与状态机逻辑验证通过
- [ ] `logic/debug_runtime.gd`（跨 reset 存活 + serialize）
- [ ] `scenes/game/debug_overlay.gd`（F2，替代原型 DOM 面板）
- [ ] 实体视图对象池、特效与震屏打磨
- [ ] 性能检查（140 存活上限下帧率）

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
| [Debug] | Debug Runtime | M6 | ⬜ |
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
| 1 | 2026-08-14 | 玩家源序列帧存在画面或帧间连贯性问题；非 PlayerView 状态机或方向映射缺陷 | 影响主角最终动画品质，不影响移动逻辑 | 已定位 | 后续直接替换 `assets/sprites/player/` 对应 PNG/JSON，并按需调整帧率、缩放和脚底偏移 |

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
| 2026-08-14 | M6 | 新增集中式 PlaceholderWorld：补齐七类敌人、弹道、经验、掉落、召唤、披风/玉环/丹火区域、任务标记和联动特效的临时可读表现；Godot 315 项、原型 smoke 双绿 | 待提交 |