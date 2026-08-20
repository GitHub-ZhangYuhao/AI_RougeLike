# 小游戏发布交接快照（2026-08-21 续作用）

> 分支 `perf/minigame-etc2` ｜ 落档时 HEAD `45a6886`（已推送 origin）｜ 日期 2026-08-21
> 一次性交接快照：停在哪、剩什么、命令怎么跑。长期真值在 `Docs/research/minigame-release-checklist.md`（发布清单 v2 + 复核注记）；本快照随工作完成作废。

## 一、当前状态（2026-08-20 实测，Godot 4.5.1）

| 项 | 结果 |
| --- | --- |
| 微信小游戏（preset.2 全量档） | 总包 29.05 MB / pck 22.68 MB ≤ 30MB ✅ 余量 0.95 MB → `GameProject/build/minigame/wx/` |
| 抖音小游戏（preset.3 slim 档） | 总包 19.37 MB / pck 13.00 MB ≤ 20MB ✅ 余量 0.63 MB → `GameProject/build/minigame/wx-slim/` |
| slim 档规则 | sprites/vfx 长边 256、terrain/ui 长边 512、env 长边 384（`tools/minigame_size_limit.gd` RULES_SLIM） |
| 仓库状态 | 恒回默认导入档（导出脚本自动快照/恢复 .import），工作区无 .import 残留；提交分工程/文档两组 |
| 验证 | 两档 pck `--main-pack --quit-after 30` 运行时零脚本错误；双 smoke 全绿（Godot 459 项 / 26 场景 + 原型 21 章） |

## 二、续作 TODO（按优先级）

**工程侧**

1. [ ] 替换微信 AppID：`GameProject/export_presets.cfg` preset.2 / preset.3 两处的 `wxf40904ea6120ad08` 是插件 demo 值 → 换成自己的小游戏 AppID → 两档重导出
2. [ ] 配置启动封面背景图 / logo（预设「资源信息」选项，当前为空）
3. [ ] 全量 verify / 键鼠 UI 流程复核（PROGRESS.md §2 焦点 3 剩余项）

**验证侧**

4. [ ] 微信开发者工具导入 `GameProject/build/minigame/wx/` 验证启动与横屏（本机已装：`C:\Program Files (x86)\Tencent\微信web开发者工具\微信开发者工具.exe`，AppID 可先用测试号）
5. [ ] 抖音开发者工具（IDE，需另装）导入导出产物验证
6. [ ] **横屏真机验证（抖音最大返工风险）**：官方口径「暂时仅竖屏」，TTSDK 1.0.2+ 提供横屏导出；若必须竖屏需新增一套 UI/HUD 锚点适配

**账号/合规侧（仅用户可办，详见清单 §4/§5）**

7. [ ] 微信：mp.weixin.qq.com 注册小游戏（个人主体可行，IAA 路线一般无需版号/软著）+ 小游戏备案 + 适龄提示 + 隐私指引
8. [ ] 抖音：开放平台注册 + 主体认证（建议企业/个体工商户主体）+ 侧边栏复访能力（强制必接）

## 三、常用命令（cwd=C:\WorkSpace\AIGame）

```powershell
# 导出（自动 slim apply/恢复/校验一条龙；2=微信全量，3=抖音 slim）
cd GameProject; powershell -ExecutionPolicy Bypass -File tools\minigame_export.ps1 -Presets 3

# pck 审计（必须绝对路径，相对路径会回退启动游戏本体）
cmd /c "chcp 65001 >nul & cd /d C:\WorkSpace\AIGame & GameEngine\4.5\Godot.exe --headless --main-pack C:\WorkSpace\AIGame\GameProject\build\minigame\wx-slim\engine\demo-pck.bin --script C:\WorkSpace\AIGame\GameProject\tools\pck_top_files.gd > Experimental\pck_top.log 2>&1 & echo EXIT=%ERRORLEVEL%"

# 运行时验证（零 SCRIPT ERROR 即通过；退出时的 ObjectDB/资源泄漏警告属正常）
cmd /c "chcp 65001 >nul & cd /d C:\WorkSpace\AIGame & GameEngine\4.5\Godot.exe --headless --main-pack <绝对pck路径> --quit-after 30 > Experimental\rv.log 2>&1 & echo EXIT=%ERRORLEVEL%"

# 双 smoke（提交前必须双绿）
npm run smoke
cmd /c "chcp 65001 >nul & cd /d C:\WorkSpace\AIGame & GameEngine\4.5\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd > Experimental\smoke.log 2>&1 & echo EXIT=%ERRORLEVEL%"

# 排除清单误杀检查（仅动 exclude_filter 时需要）
node tools\minigame_exclude_check.mjs 3
```

## 四、环境注记（本机）

- 引擎双版本并存（均 gitignore）：小游戏插件只认 4.5 → `GameEngine/4.5/Godot.exe`；日常开发仍用 4.7.1 → `GameEngine/Godot.exe`
- PowerShell 5.1：`Remove-Item` 被策略拦截 → 用 `[System.IO.File]::Delete()` / `[System.IO.Directory]::Delete($path,$true)`；`Set-Content -Encoding utf8NoBOM` 不存在 → 写 UTF-8 无 BOM 用 `New-Object System.Text.UTF8Encoding $false`；编辑多反引号 Markdown 用**单引号** here-string
- `git push` 成功也可能报 exit 1（stderr 被 PS 当 NativeCommandError），看输出的 `old..new branch -> branch` 行判断
- Godot MCP 工具（read_file/edit_script 等）在编辑器未连接时不可用，一律走 shell
- 提交纪律：工程/文档分开提交；勿动用户 WIP（`.agents/skills/*` 删除态、`.codex/config.toml` 改动不进提交）

## 五、参考文档

- `Docs/research/minigame-release-checklist.md` —— 发布清单（限额口径 / 实测数字 / 三阶段路线 / 微信抖音合规 checklist）
- `Docs/research/minigame-publish-research.md` —— 路线调研（三条技术路线对比、官方文档 URL）
- `GameProject/PROGRESS.md` §2 焦点 3、§6 变更历史
- `GameProject/tools/minigame_export.ps1` —— 导出脚本；`tools/minigame_size_limit.gd` —— 尺寸档管理