# CHANGELOG — 版本历史

> 追加式记录：最新条目在最下方，不回改历史；已失效的表述用新条目更正而不是改写旧条目。
> 格式：日期 + 阶段标题 + 关键提交（短 hash）+ 说明。逐条细节以 `git log` 为准。

## 原型期（2026-08-12 ~ 2026-08-13）

### 2026-08-12 · 核心循环、武器升级与局外商城
- `d55a9d8` 武器升级系统 Step3 上半：6 把武器 Lv1–6 全落地。
- `3afe49a` 多类型敌人原型与公共基类；`b815c22` 武器波次 Boss 与调试工具。
- `a16a3fe` 战斗平衡迭代 + 视频转序列帧工具；`04852ab`、`ab35565` skill 迁移与 AGENTS.md 汉化。
- `562bdb4` 局外商城一期 Step1 meta 数据层；`76004d0` Boss 撤离抉择与局外商城（商城/仓库/临时背包/存档持久化）。
- 平衡调参轮：`5e7d633` 玩家反馈调参 → `018f222`/`9e10849` 玉环重做与披风扩范围 → `d57dcff` 拔剑斩半径 → `c68dcfa` 敌人压力曲线 → `1cab1d9` 拔剑斩命中充能 → `c51e762` 丹火延长 → `83a7093` 道剑 Lv6 飞剑质变。

### 2026-08-13 · 联动、波次、任务与美术探索（原型收尾）
- `f822c3b` comfyui-workflow skill（Krea-2 t2i / MiniMax fl2va）；`2a19735` 角色视频素材；`4402301` Godot 空工程占位。
- `7a63a70` gpt-image skill 与角色素材；`67860a2`/`1f497a5`/`e2d3443` 风格探索、草甸地图与无缝地贴。
- `8040088` **武器联动与波次进度**：原型玩法功能收尾。
- `5ced693`/`eff2035` Godot 环境沙盒与素材库整理；`cc76ef0` 局内任务规划文档。
- `19a33fc`/`f7fc83b` 局内随机动态任务与奖励（原型）。
- `8046e1f`…`7df0ff9` 地面节点式材质多轮迭代（VisualShader 共享材质）。
- `25deb70` Qwen-Image-Edit pose 工作流并入 comfyui skill。

## Godot 立项与移植（2026-08-13 ~ 2026-08-14）

- `378b43f` 立项规划文档（PORT_PLAN / RULES 等），移除旧美术实验场景。
- `fb8eac9` **M0**：工程脚手架与空跑 smoke runner。
- `ceeb57d`/`f999040` ComfyUI 八方向行走序列帧流水线；`d861387`/`b200f21` 角色与敌人动作素材。
- `11f17f0` M2/M3 实施计划定稿（`GameProject/PLANS/`）。
- `00a224a` **M1–M5 单次落库**：核心循环、六武器、敌人/Boss/局流程、联动系统、商城/仓库/任务全部移植完成。
- `5d9a510`/`596319d` 动画素材整理；项目级 Godot MCP 配置（`.codex/config.toml`）。

## M6 打磨 · 美术与 UI（2026-08-14 ~ 2026-08-17）

- `7db4f2a` 可玩美术基线；`1ab6e6b` 占位视觉；`d2b1080` 美术资产台账（ART_ASSET_CONFIG 前身）。
- `cf491a7` 主题 UI 与调试工具；`e69c48f` 美术 UI 完成与玩家动画恢复。
- `501f826` 暖纸 UI 打磨；`74cff54` 现代 Q 版 UI 重做；`685467c` 地形锐化与图标打磨。
- `a850e66` UI 字体 Nowar Rounded；`6f83881` Peach Night HUD 重做；`425d98a` 角落岛屿 HUD 布局。
- `f92c729` 7 项 UI/玩法优化 + Godot MCP 集成；`90fc11c` 第二轮优化 + 美术审计 + 死资源清理。
- `5c75d32` 静态资源与草甸地形刷新；`3f0b908` BOM 移除 + 编译修复 + gameplay 调整。
- `efb78b4` 玩法脚本与选卡 UI 修复；`27bc247` 武器卡概念图补全；`eda8dd1` 进度反馈与 UI 可读性。

## 美术迭代轮次 4–7（2026-08-17 ~ 2026-08-18）

- `7a5eaba` 道剑 Lv2 穿透弹道特效贴图（ComfyUI Krea-2 生成）。
- `0b05978` 补齐四/五轮未落库的美术与玩法缺口。
- `9515aa0` 记录第八轮候选待办与数值待校准项（OPTIMIZATION_TRACKER）。
- `76a1451` 弹道与玉环特效精修。

## 第八轮 · 音频框架与数值审计（2026-08-18 ~ 2026-08-19）

- `4cf0420` **feat(audio)**：AudioManager autoload + 披风/玉环 SFX（视频生成音轨提取）；账面 SFX 2/22、BGM 0/6。
- `250a430` **feat(balance)**：稀有掉落来源收敛、稀有加成封顶、雷符/玉环再平衡。
- `a86c917` chore(repo)：仓库卫生规则（.gitattributes/.gitignore）+ 音频生成工作流 skill。
- `0e89026` fix(weapons)：js 侧雷符 thunderAoE 半径对齐 RULES 真值（95→80）。
- `671cea9` feat(vfx)：披风/丹炉序列帧 sprite-sheet 图集入库（运行时集成待做）。
- `98248dc` docs(godot)：六份 GameProject 文档同步（BALANCE/PROGRESS/OPTIMIZATION_TRACKER/ART_ASSET_CONFIG/AGENTS/PORT_PLAN）。

## 2026-08-19 · 文档体系重整

- 删除过时文档：根 `DESIGN.md`、`Docs/wave-difficulty-table.md`、`Docs/project-status-summary.md`、`Docs/art-resource-refresh-2026-08-16.md`（信息已由 `GameProject/RULES.md`、`BALANCE.md`、`PROGRESS.md`、`ART_ASSET_CONFIG.md` 承接）。
- 重写根 `README.md`；新建本文件（`CHANGELOG.md`）与 `Docs/README.md`（文档地图 + 更新纪律）。
- Docs 5 个保留文件加状态头/复核注记；`AGENTS.md` 增补文档纪律与 Godot 命令；修复 RULES.md / PLANS 中的 DESIGN.md 引用。

## 进行中 / 已知缺口

- 对象池 + 180 敌人压测（`GameProject/OPTIMIZATION_TRACKER.md` 候选）。
- 音频资源生产：SFX 2/22、BGM 0/6。
- 披风/丹炉序列帧运行时集成（`art_catalog.gd` 仍 preload 静态贴图）。
- 统一敌人预警表现层。
- Windows 导出流程。
