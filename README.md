# 暗夜幸存者 · 类吸血鬼幸存者

双轨仓库：**HTML5 原型**（根目录，零依赖浏览器游戏）+ **Godot 移植**（`GameProject/`，正式版）。

## 仓库结构

| 目录 | 说明 |
| --- | --- |
| `index.html`、`js/`、`tools/` | HTML5 原型：Canvas + ES Modules，零依赖零构建；数值集中在 `js/config.js` |
| `GameProject/` | Godot 4.7.1 移植（GDScript only），规则真值在 `GameProject/RULES.md`，内部规范见 `GameProject/AGENTS.md` |
| `ArtAsset/` | 源素材库（不进游戏运行时引用，定稿后复制到 `GameProject/assets/`） |
| `Docs/` | 策划设计文档，索引与更新纪律见 [`Docs/README.md`](./Docs/README.md) |
| `GameEngine/` | 本地 Godot 引擎（gitignore，不入库） |
| `Experimental/` | 媒体实验产物（gitignore，不入库） |
| `.agents/skills/` | 独立的媒体处理 skill/工具集 |

## 当前状态（2026-08-19）

- Godot 移植 **M0–M5 全部完成**，处于 **M6 打磨期**；headless smoke 419 checks / 24 scenarios 全绿，原型 smoke 同构双绿。
- 美术：玩家八方向序列帧、节点式草甸地形、武器卡牌概念图、弹道/玉环特效、披风/丹炉序列帧图集已入库；披风/丹炉序列帧的运行时集成待做。
- 音频：`AudioManager` autoload 框架就绪，SFX 3/23、BGM 0/6（资源生产待补）。
- 主要剩余工作：对象池与 180 敌人压测、音频资源生产、序列帧 VFX 集成、统一敌人预警层、Windows 导出。
- 完整版本史见 [`CHANGELOG.md`](./CHANGELOG.md)；Godot 侧里程碑分解见 [`GameProject/PROGRESS.md`](./GameProject/PROGRESS.md)。

## 快速开始

### HTML5 原型

```powershell
npm start
# 浏览器打开 http://localhost:5173
```

### Godot

```powershell
GameEngine\Godot.exe --path GameProject
# 编辑器中按 F5 运行主场景 scenes/main.tscn
```

操作：WASD / 方向键移动（对角线归一化），鼠标选择升级卡牌，F2 打开调试面板（打开时暂停），死亡后按 R 返回菜单重开。

## 测试与开发命令

| 命令 | 用途 |
| --- | --- |
| `npm run smoke` | 原型无头冒烟测试（无需浏览器） |
| `GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd` | Godot 无头冒烟测试 |
| `GameEngine\Godot.exe --headless --path GameProject --import` | 素材变更后强制重导入（`.import` 与素材同提交） |
| `GameEngine\Godot.exe --headless --path GameProject --script res://tools/weapon_balance.gd` | 确定性武器 DPS harness |

提交前必须原型 + Godot 双 smoke 全绿。详细测试与提交规范见 [`AGENTS.md`](./AGENTS.md) 与 `GameProject/AGENTS.md`。

## 文档索引

| 文档 | 职责 |
| --- | --- |
| [`CHANGELOG.md`](./CHANGELOG.md) | 追加式版本史与进行中事项（根级） |
| [`Docs/README.md`](./Docs/README.md) | 文档地图与更新纪律 |
| [`AGENTS.md`](./AGENTS.md) | 仓库规范（结构 / 构建 / 风格 / 测试 / 提交） |
| [`GameProject/RULES.md`](./GameProject/RULES.md) | 游戏规则唯一真值（数值 / 公式 / 时机） |
| [`GameProject/PROGRESS.md`](./GameProject/PROGRESS.md) | 移植进度与里程碑分解 |
| [`GameProject/BALANCE.md`](./GameProject/BALANCE.md) | 数值平衡台账 |
| [`GameProject/OPTIMIZATION_TRACKER.md`](./GameProject/OPTIMIZATION_TRACKER.md) | 优化轮次记录与候选待办 |
| [`GameProject/ART_ASSET_CONFIG.md`](./GameProject/ART_ASSET_CONFIG.md) | 美术资源状态台账 |

## Godot MCP（Codex 开发工具）

Godot 移植工程通过 [`godot-mcp-server`](https://github.com/tomyud1/godot-mcp) 接入 Codex：
项目级 `.codex/config.toml` 固定 `godot-mcp-server@0.5.0`，服务端经 `ws://127.0.0.1:6505`
连接 Godot 编辑器插件（`GameProject/addons/godot_mcp/`，已作为开发工具例外入库）。

```toml
[mcp_servers.godot]
command = "cmd"
args = ["/c", "npx", "-y", "godot-mcp-server@0.5.0"]
```

使用要点：

- 在 Godot 编辑器 **Project → Project Settings → Plugins** 启用 **Godot MCP** 后重启项目；编辑器右上角显示绿色 `MCP Connected` 即连通。
- 配置后从本仓库目录启动 Codex 会话；不要执行 `codex mcp add godot ...`（会写入用户级配置污染其他工作区）。
- 排障顺序：插件是否启用 → 项目是否重启 → 端口 6505 是否被占用 → Codex 是否重启。
- MCP 编辑操作可能直接保存文件且无 Undo，调用前后检查 `git diff`；自动化回归一律走 headless smoke，不用 MCP 替代。
- 移除配置：删除 `.codex/config.toml` 中的 `[mcp_servers.godot]` 表。
