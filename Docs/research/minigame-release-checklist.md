# 微信 / 抖音小游戏发布准备清单

> 状态：定稿 v1 ｜ 日期：2026-08-20 ｜ 分支：`feat/minigame-publish`
> 配套文档：`Docs/research/minigame-publish-research.md`（路线调研，定稿 v1）。本文档只管「发布前要准备什么」，路线选型依据以调研报告为准。
> 实测环境：Godot 4.5.1（`GameEngine/4.5/Godot.exe`，与 4.7.1 并存）+ godothub/godot-minigame 社区插件（AtomGit 模板 `minigame4.5.1.tpz`），Windows headless 导出。

## 一、已完成的工程事项（本分支实测）

| 事项 | 结果 |
| --- | --- |
| 引擎版本 | 4.7.1 → **4.5.1** 并存（4.7.1 仍在 `GameEngine/Godot.exe`，两者均 gitignore） |
| 适配插件 | `addons/godot-minigame/`（0.79MB，注入「小游戏」导出平台） |
| 模板离线缓存 | `minigame4.5.1.tpz`（8.3MB）已预置到插件模板目录（`%APPDATA%\Godot\app_userdata\...\toolkit\templates\`），离线可导出 |
| 导出预设 | preset.2「微信小游戏」（全量）/ preset.3「微信小游戏-精简量尺寸」（排除全部美术目录，仅代码+音频+字体） |
| 导出链路 | `--export-release 微信小游戏 ...` headless EXIT=0：产出完整微信工程（game.json landscape、project.config.json、引擎分包；native-audio 空 manifest 优雅降级） |
| 体积审计工具 | `tools/pck_size_report.gd`、`tools/pck_top_files.gd`（用法：`--main-pack <绝对路径pck> --script <绝对路径脚本>`，相对路径会回退启动游戏本体） |
| 冒烟基线 | Godot 4.5.1 headless 459 项 / 26 场景全绿 + 原型侧全绿（2026-08-20） |

## 二、实测包体 vs 平台限制

| 产物 | 总大小 | 其中 pck | 微信（代码包总上限 30MB） | 抖音（整包 20MB） |
| --- | --- | --- | --- | --- |
| 全量（preset.2） | 142.6 MB | 136.23 MB | ❌ 超限 4.8 倍 | ❌ |
| 精简（preset.3，排除全部美术） | 10.74 MB | 4.36 MB | ✅ 余量充足 | ✅ 偏紧（wasm ≈10MB + pck 4.36MB ≈ 15MB） |

pck 构成审计（全量包，645 文件）：

- **ctex 纹理 132.27 MB（占 97%）**：terrain 46.3 / sprites 43.4 / 根目录 ground_* 六张 ≈23 / ui 8.7 / vfx 8.0 / env 1.2 / icons 0.9（单位 MB）
- ogg 音频 2.41 MB、字体 0.63 MB、脚本 gdc 0.46 MB
- **关键发现**：全部 200 张纹理 `compress/mode=0`（lossless、vram_texture=false），尽管项目早已开启 `import_etc2_astc=true` —— 切 ETC2 是最大的免费减重杠杆。

结论：**全量美术进不了任何一端的包**。策略为「精简首包 + 重美术 CDN 化」，或先做 ETC2 + 排除把包压到限内（见第三节路线）。

## 三、包体优化路线（按序执行，每步实测）

### 阶段 1：纹理切 VRAM 压缩（ETC2/ASTC）——最大免费杠杆
- 现状：200 张纹理全部 lossless；Android ETC2 打包环境已在 `744bc3e` 落地。
- 动作：批量修改 `.import` 的 `compress/mode=2`、`vram_texture=true` → `--import` 重导入 → 重导 preset.3 对比 pck。
- 预期：参考 Android APK 先例纹理降 50–75%，从精简 pck 4.36MB 起实测。
- 风险：暗部渐变画质损失（terrain / sanctuary 大图重点目检）。

### 阶段 2：死资产排除（已有经验复用）
- preset.3 已排除全部美术目录；全量包侧复用 APK 瘦身经验（`744bc3e`：`ground_*_crisp.webp` 四张 ≈35MB、仅自引用预览场景等）。
- 审计手段：`pck_top_files.gd` 出 Top N → 全仓 `.uid` / 路径引用核对确认无引用 → 加入 `exclude_filter`。

### 阶段 3：重美术 CDN 化（阶段 1+2 仍超限时启用）
- 首包 = 引擎 wasm.br（≈10MB）+ 代码 pck + 音频/字体；≈110MB 纹理走 CDN。
- 技术要点：`HTTPRequest` 下载 + `user://` 缓存 + `ProjectSettings.load_resource_pack()` 热载；CDN 资源运行时下载，不受包内文件白名单限制（白名单无 `.pck` 等格式）。
- 附加工作：资源版本化 / 缓存失效、首次进入的下载进度 UI、弱网降级——这是改造量大头。
- 抖音注意：整包 ≤20MB，精简包下引擎分包 + 代码分包合计 ≈15MB 可行；超限则拆 wasm/pck 两个分包或继续瘦 pck。

## 四、微信小游戏发布清单（IAA 路线，个人主体可行）

**账号与资质**
- [ ] mp.weixin.qq.com 注册小游戏账号（个人主体可注册）
- [ ] 类目：注册时选定（一级类目「游戏」不可改）；个人主体可选休闲/益智/动作等，**不可选文化互动、角色类、牌类**；类目与内容不符会提审被驳
- [ ] 资质审核：选「情况二：不开通虚拟支付」（IAA），一般**无需版号/软著**；审核 1–3 个自然日
- [ ] **替换 AppID**：当前预设里的 `wxf40904ea6120ad08` 是插件作者的 demo 值，必须换成自己的小游戏 AppID（preset.2 / preset.3 两处）

**合规**
- [ ] 小游戏备案（前置审批环节：平台初审 → 主管部门 → 小程序备案；名称/主体全程一致）
- [ ] 适龄提示：MP 后台选 8+/12+/16+，展示于启动页健康游戏忠告旁
- [ ] 隐私：配置「用户隐私保护指引」+ C 端授权弹窗曝光 + 上报授权结果
- [ ] 中宣部实名：不开通虚拟支付的由平台统一协助接入，**开发者零操作**

**技术验证**
- [ ] 微信开发者工具导入 `build/minigame/wx/` 验证启动（game.json 已 landscape）
- [ ] 真机预览：横屏、触摸（触屏桥接已有 `bf81834`）、iOS 音频解锁
- [ ] 存档 flush 时机验证（切后台/退出前落盘；`autoload/meta_save.gd` 走 `user://` 逻辑不用改）

## 五、抖音小游戏发布清单

**账号与资质**
- [ ] 抖音开放平台注册 + 主体认证 + 对公验证（个人主体可创建小游戏，但变现结算走对公——实际运营建议企业/个体工商户主体；主体类型审核通过后不可变更）
- [ ] 创建小游戏 + 完善基本信息（基本信息审核）
- [ ] 版本审核通过后**平台自动申报小游戏备案**（无需手动；已有版号的游戏免备案）

**必接能力与合规**
- [ ] 侧边栏复访能力（**所有小游戏强制必接**）
- [ ] 有用户输入时接敏感词能力；客服仅 IAP 需要
- [ ] ICP 核准；中宣部防沉迷渠道绑定仅「已获版号的在运营游戏」需要

**技术验证**
- [ ] 抖音开发者工具（IDE）导入导出产物验证启动
- [ ] **横屏真机验证**：官方口径目前「暂时仅竖屏」，TTSDK 1.0.2+ 提供横屏导出选项——这是本项目最大潜在返工点，优先级最高；若必须竖屏需新增一套 UI/HUD 锚点适配
- [ ] 抖音官方路线后手：TTSDK addon 1.0.4（2026-07-15 发布），当前认证列表仅 Godot 4.5——本项目已在 4.5.1，平台方明确要求或提供流量扶持时可直接接入（`tt` autoload：`tt.login()`、`mount_ttpkg_file()`、`load_subpackage()`）

## 六、发布前工程 TODO

1. [ ] 移除 autoload `MCPRuntime → res://addons/godot_mcp/...`（0.76MB；不移除则 exclude_filter 无法排除 godot_mcp）；MCP 仅开发期工具
2. [ ] 替换微信 AppID（见第四节）
3. [ ] 配置启动封面背景图 / logo（预设「资源信息」选项，当前为空）
4. [ ] 执行第三节阶段 1（ETC2 重导入）并实测对比
5. [ ] 抖音端产物与横屏验证完成后，决定是否接入 TTSDK / 做竖屏适配
6. [ ] 正式提审前重跑双 smoke 与两端导出（4.5.1 基线：459 项 / 26 场景）

## 七、参考资料

- 配套调研报告：`Docs/research/minigame-publish-research.md`（平台规则对比表、三条技术路线对比、合规流程细节与官方文档 URL 清单）
- 插件仓库：godothub/godot-minigame（AtomGit 镜像；模板 `minigame4.5.1.tpz`，本地留档 `Experimental/minigame4.5.1.tpz`）
- 抖音官方 TTSDK：`partner.open-douyin.com` → 小游戏 → 开发 → 游戏引擎 → Godot