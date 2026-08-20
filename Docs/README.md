# Docs/ — 文档地图与更新纪律

> 状态：维护中 ｜ 更新：2026-08-20
> 本目录存放策划/设计文档。**玩法规则真值在 `GameProject/RULES.md`**：本文档与 RULES.md 冲突时一律以 RULES.md 为准。

## 更新纪律

1. **代码与文档同提交**：改动玩法/数值/资产的提交必须在同一 commit 内同步对应文档。
2. **设计先行**：设计变更先落文档（Godot 规则 → `GameProject/RULES.md`；新系统 → 本目录规划文档），再动代码。
3. **追加式不回改**：文档失效不改写历史表述，而是加带日期的「复核注记」或在 `CHANGELOG.md` 记录更正。
4. **数值改动流程**：改配置（`js/config.js` 或 `GameProject/logic/config.gd`）→ 同步 `GameProject/BALANCE.md` 台账 → 原型与 Godot 双 smoke 全绿。

## 本目录文件清单

| 文件 | 主题 | 状态 |
| --- | --- | --- |
| `weapon-upgrade-guide.md` | 武器升级系统 SubAgent 实现规范（原型） | 历史契约：6 武器 Lv1–6 已实现，仅作实现依据存档 |
| `weapon-synergy-system-plan.md` | 武器联动系统规划（原型） | 部分失效：Godot 已改为单一主联动（RULES.md 附录 B #11） |
| `in-run-task-system-plan.md` | 局内动态任务系统规划 | 已实现（原型 `19a33fc` / Godot M5 `00a224a`） |
| `extraction-shop-implementation-plan.md` | Boss 撤离 + 局外商城实现方案 | 已实现（原型 `76004d0` / Godot M5 `00a224a`） |
| `boss-extraction-shop-dynamic-tasks.md` | Boss 撤离/局外商城/动态任务原始设计稿 | 历史草稿，以实现方案为准 |
| `research/minigame-publish-research.md` | 微信/抖音小游戏打包发布调研（引擎路线/包体预算/合规流程） | 定稿 v1（2026-08-20） |

## GameProject/ 文档（同仓库真值层）

| 文件 | 职责 |
| --- | --- |
| `RULES.md` | 游戏规则唯一真值（公式/数值/时机/随机序） |
| `PROGRESS.md` | 移植进度、里程碑分解、smoke 章节矩阵 |
| `BALANCE.md` | 数值平衡台账（每轮调参记录） |
| `OPTIMIZATION_TRACKER.md` | 优化轮次记录、候选待办 |
| `ART_ASSET_CONFIG.md` | 美术资源状态台账（已配置/待修订/未配置/占位） |
| `PORT_PLAN.md` | 移植总体计划与章节映射 |
| `PLANS/` | 各里程碑实施计划（M2/M3 等，历史存档） |
| `AGENTS.md` | Godot 侧开发规范与踩坑记录 |

根级文档：`README.md`（入口）、`CHANGELOG.md`（版本史）、`AGENTS.md`（仓库规范）。

## 删除记录

| 日期 | 文件 | 原因 |
| --- | --- | --- |
| 2026-08-19 | 根 `DESIGN.md` | 进度记录与武器方案已被 RULES.md / BALANCE.md / PROGRESS.md 承接 |
| 2026-08-19 | `Docs/wave-difficulty-table.md` | 波次难度数值真值已在 RULES.md / BALANCE.md |
| 2026-08-19 | `Docs/project-status-summary.md` | 状态快照已被 PROGRESS.md 与本 README 取代 |
| 2026-08-19 | `Docs/art-resource-refresh-2026-08-16.md` | 一次性刷新记录，已被 ART_ASSET_CONFIG.md 取代 |
