# 仓库规范

## 当前工作焦点（临时节，发布工作完成后删除本节）

> 更新 2026-08-21 ｜ 分支 `perf/minigame-etc2`

微信/抖音小游戏打包发布。现状：包体双达标（微信全量档总包 29.05MB ≤ 30MB、抖音 slim 档总包 19.37MB ≤ 20MB，均无需 CDN）；Godot 4.5.1（`GameEngine/4.5/`，4.7.1 保留不动）+ godothub godot-minigame 插件导出链路就绪；产物在 `GameProject/build/minigame/wx/`（微信）与 `wx-slim/`（抖音）。

续作时先读 `Docs/research/minigame-handoff.md` 交接快照（状态/TODO/命令/环境注记），长期真值在 `Docs/research/minigame-release-checklist.md`。TODO 首要：替换微信 AppID（`GameProject/export_presets.cfg` preset.2/3 两处插件 demo 值）→ 重导出两档 → 微信开发者工具导入验证；最大返工风险是抖音横屏（官方当前仅竖屏，TTSDK 1.0.2+ 有横屏导出，需真机验证）。

关键纪律：slim 导出档是临时 .import 状态，仓库恒回默认导入档，导出必须走 `GameProject/tools/minigame_export.ps1`（详见 `GameProject/AGENTS.md` 经验沉淀 2026-08-21 条）。

## 项目结构与模块组织

本仓库是一款类吸血鬼幸存者游戏，包含两部分：

- **HTML5 原型（根目录）**：零依赖浏览器游戏，Canvas + ES Modules。`index.html` 是入口，`js/main.js` 启动固定步长主循环。核心玩法模块在 `js/` 下，敌人在 `js/enemies/`，武器在 `js/weapons/`，共享玩法系统在 `js/systems/`，局外系统在 `js/meta/`。数值平衡配置统一集中在 `js/config.js`。
- **Godot 移植（`GameProject/`）**：Godot 4.7.1、GDScript only，是原型的正式版移植。该目录有自己的 `AGENTS.md` 管辖内部规范（结构、风格、测试、提交与踩坑记录），游戏规则真值在 `GameProject/RULES.md`。本地引擎放在 gitignore 的 `GameEngine/`。

其他目录：`ArtAsset/` 是源素材库（不进入游戏运行时引用，定稿后复制到 `GameProject/assets/`）；`Docs/` 是设计文档；`tools/` 是开发辅助工具；`Experimental/` 是被 gitignore 的媒体实验产物；`.agents/skills/` 是独立的媒体处理 skill/工具集。

## 文档体系与更新纪律

文档地图与删除记录见 `Docs/README.md`，版本史见根 `CHANGELOG.md`（追加式，最新在下）。核心纪律：

1. **代码与文档同提交**：改动玩法/数值/资产的 commit 必须同步更新对应文档。
2. **设计先行**：设计变更先落文档（Godot 规则 → `GameProject/RULES.md`；新系统 → `Docs/` 规划文档），再实现。
3. **追加式不回改**：失效表述不改写历史，加带日期的复核注记或在 `CHANGELOG.md` 更正。
4. **数值改动流程**：改配置（`js/config.js` / `GameProject/logic/config.gd`）→ 同步 `GameProject/BALANCE.md` → 双 smoke 全绿。

## 构建、测试与开发命令

原型侧：

- `npm start` — 在 `http://localhost:5173` 启动本地静态服务器。
- `npm run smoke` — 无头冒烟测试，无需浏览器。
- `node tools/serve.js` 与 `node tools/headless-smoke.mjs` 是上述脚本的等价命令。

Godot 侧：

- `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` — 无头冒烟测试。
- `GameEngine\Godot.exe --headless --path GameProject --import` — 素材变更后强制重导入；生成的 `.import` 文件必须与素材同提交。
- `GameEngine\Godot.exe --headless --path GameProject --script res://tools/weapon_balance.gd` — 确定性武器 DPS harness（数值审计用）。
- 提交前原型与 Godot 两侧 smoke 必须双绿。

本项目没有编译或打包步骤。请使用支持 ES 模块的较新版本 Node.js。

## 代码风格与命名规范

原型侧（`js/`）：2 空格缩进、分号、单引号字符串，import 显式带 `.js` 扩展名。类名 PascalCase（如 `WaveDirector`），函数和变量 camelCase（如 `createEnemyByType`），文件名 kebab-case（如 `rare-items.js`）。保持渲染、状态更新与配置三类职责分离。只在机制或约束不明显时才添加注释。

Godot 侧风格见 `GameProject/AGENTS.md`（GDScript 官方风格 + config 键名 camelCase 例外）。

项目未配置格式化工具或 linter，请严格贴近周边代码的风格。

## 测试规范

每次提交前都要运行原型 `npm run smoke` 与 Godot headless smoke，双绿才可提交。修改战斗、卡牌、波次、输入或状态转换时，需同步扩展两侧对应的冒烟章节（`tools/headless-smoke.mjs` 与 `GameProject/tests/scenarios/` 保持同构）。测试必须是确定性的，失败时通过抛出带描述的错误来报告。涉及画面或 UI 的改动，还需在浏览器 / Godot 编辑器中验证键盘、鼠标、HUD、暂停、死亡和重开等行为。项目未设置正式的覆盖率门槛。

## 提交与 PR 规范

采用 Conventional Commit 风格的祈使句摘要并带作用域，例如 `fix: prevent duplicate boss rewards`、`feat(weapons): port talisman chain lightning`；不相关的改动应分开提交。Pull Request 应说明对玩法的影响、列出已执行的验证步骤、关联相关设计文档（`Docs/`、`GameProject/RULES.md`），涉及可见变化时附上截图或短录屏。数值平衡的改动和任何有意保留的局限都需要明确标注。
