# 仓库规范

## 项目结构与模块组织

本仓库是一个无依赖的浏览器游戏，使用 JavaScript ES 模块和 Canvas 构建。`index.html` 是入口页面；`js/main.js` 启动固定步长的游戏主循环。核心玩法模块直接位于 `js/` 下，敌人实现位于 `js/enemies/`，武器实现位于 `js/weapons/`，共享玩法系统位于 `js/systems/`。数值平衡配置统一集中在 `js/config.js` 中管理。开发辅助工具位于 `tools/`，设计文档位于 `DESIGN.md` 和 `Docs/`，生成的媒体实验产物放在被 gitignore 忽略的 `Experimental/` 目录下。`.agents/skills/video-to-alpha-flipbook/` 目录是一个独立的媒体处理 skill/工具集。

## 构建、测试与开发命令

- `npm start` — 在 `http://localhost:5173` 启动本地静态服务器。
- `npm run smoke` — 执行无头（headless）游戏冒烟测试，无需启动浏览器。
- `node tools/serve.js` 和 `node tools/headless-smoke.mjs` — 与上述 npm 脚本直接等价的命令。

本项目没有编译或打包步骤。请使用支持 ES 模块的较新版本 Node.js。

## 代码风格与命名规范

使用 2 空格缩进、分号、单引号字符串，import 时显式带上 `.js` 扩展名。遵循现有的 ES 模块模式：类名用 PascalCase（如 `WaveDirector`），函数和变量用 camelCase（如 `createEnemyByType`），文件名用 kebab-case（如 `rare-items.js`）。保持渲染、状态更新和配置三类职责分离。只在机制或约束不明显时才添加注释。项目未配置格式化工具或 linter，请严格贴近周边代码的风格。

## 测试规范

每次提交前都要运行 `npm run smoke`。修改战斗、卡牌、波次、输入或状态转换时，需同步扩展 `tools/headless-smoke.mjs`。测试必须是确定性的，失败时通过抛出带描述的错误来报告。涉及画面或 UI 的改动，还需运行 `npm start` 并在浏览器中验证键盘、鼠标、HUD、暂停、死亡和重开等行为。项目未设置正式的覆盖率门槛。

## 提交与 PR 规范

近期提交历史采用 Conventional Commit 风格的标题，主要是 `feat: <摘要>` 形式。请使用带作用域的祈使句摘要，例如 `fix: prevent duplicate boss rewards`（修复：防止重复发放 Boss 奖励）；不相关的改动应分开提交。Pull Request 应说明对玩法的影响、列出已执行的验证步骤、关联相关 issue 或设计文档，涉及可见变化时附上截图或短录屏。数值平衡的改动和任何有意保留的局限都需要明确标注。
