# 微信 / 抖音小游戏发布准备清单

> 状态：定稿 v2 ｜ 日期：2026-08-20 ｜ 分支：`perf/minigame-etc2`（v1 成稿于 `feat/minigame-publish`，v2 为当日复核修订：平台限额口径、实测包体数字、preset.3 重设计）
> 配套文档：`Docs/research/minigame-publish-research.md`（路线调研，定稿 v1）。本文档只管「发布前要准备什么」，路线选型依据以调研报告为准。
> 实测环境：Godot 4.5.1（`GameEngine/4.5/Godot.exe`，与 4.7.1 并存）+ godothub/godot-minigame 社区插件（AtomGit 模板 `minigame4.5.1.tpz`），Windows headless 导出。

## 一、已完成的工程事项（本分支实测）

| 事项 | 结果 |
| --- | --- |
| 引擎版本 | 4.7.1 → **4.5.1** 并存（4.7.1 仍在 `GameEngine/Godot.exe`，两者均 gitignore） |
| 适配插件 | `addons/godot-minigame/`（0.79MB，注入「小游戏」导出平台） |
| 模板离线缓存 | `minigame4.5.1.tpz`（8.3MB）已预置到插件模板目录（`%APPDATA%\Godot\app_userdata\...\toolkit\templates\`），离线可导出 |
| 导出预设 | preset.2「微信小游戏」（全量档：ETC2 + 死资产排除 + 尺寸限制）/ preset.3「微信小游戏-精简量尺寸」（slim 尺寸档，排除清单与 preset.2 相同，尺寸更紧） |
| 导出链路 | `--export-release 微信小游戏 ...` headless EXIT=0：产出完整微信工程（game.json landscape、project.config.json、引擎分包；native-audio 空 manifest 优雅降级） |
| 体积审计工具 | `tools/pck_size_report.gd`、`tools/pck_top_files.gd`（用法：`--main-pack <绝对路径pck> --script <绝对路径脚本>`，相对路径会回退启动游戏本体） |
| 打包工具链 | `tools/minigame_export.ps1`（MCPRuntime 剥离/恢复、preset.3 slim 档自动切换、pck 残留校验）、`tools/minigame_size_limit.gd`（default/slim 两档 size_limit）、`tools/minigame_exclude_check.mjs`（exclude_filter 误杀检查）、`tools/minigame_unused_scan.mjs`（无引用资产扫描） |
| 冒烟基线 | Godot 4.5.1 headless 459 项 / 26 场景全绿 + 原型侧全绿（2026-08-20） |

## 二、实测包体 vs 平台限制

> 复核注记（2026-08-20 v2）：下表为 v1 成稿时的数字（纹理尚为 lossless、preset.3 为旧的「排除全部美术」设计），当日完成 ETC2 切换与 preset.3 重设计后已被下方 v2 实测表取代，保留仅作版本史。

| 产物 | 总大小 | 其中 pck | 备注（v1 口径） |
| --- | --- | --- | --- |
| 全量（preset.2） | 142.6 MB | 136.23 MB | lossless 纹理（ctex 132.27MB 占 97%），任何一端都装不下 |
| 精简（preset.3 旧设计，排除全部美术） | 10.74 MB | 4.36 MB | 整目录排除导致 preload() 美术的脚本 parse 失败，设计已废弃（见第三节阶段 2） |

**平台限额口径（v2 复核确认）**：

| 平台 | 总包（主包+分包） | 主包 | 单分包 |
| --- | --- | --- | --- |
| 微信小游戏 | ≤30 MB | ≤4 MB | 无独立上限 |
| 抖音小游戏 | ≤20 MB | ≤4 MB | ≤20 MB |

**v2 实测（2026-08-20，ETC2 + 78 条死资产排除 + BGM 重编码后，headless 导出实测）**：

| 产物 | 总大小 | 其中 pck | 微信（总包 30MB） | 抖音（整包 20MB） |
| --- | --- | --- | --- | --- |
| 全量档（preset.2） | **29.05 MB** | 22.68 MB | ✅ 余量 0.95 MB | ❌ 超 9.05 MB |
| 精简档（preset.3 slim 尺寸档） | **20.69 MB** | 14.31 MB | ✅ 余量 9.31 MB | ❌ 微超 0.69 MB |

> 复核注记（2026-08-20 当日）：slim 档收紧（`assets/environment/` 长边 512→384，其余组不变）后 preset.3 复测 **总包 19.37 MB / pck 13.00 MB**（ctex 10.24 MB）：**抖音 ✅ 达标，余量 0.63 MB**，微信 ✅ 余量 10.63 MB。表内为收紧前首次实测值。

插件产物分包结构（`build/minigame/wx/`，两档结构相同）：

- 主包 ≈0.09 MB：game.js / godot-loader.js / weapp-adapter.js / images —— 远小于 4MB 主包上限 ✅
- `engine/` 分包：godot.wasm.br 5.88 MB + godot.js / godot-sdk.js 0.39 MB + demo-pck.bin（pck 本体）
- `subpack1/sub.bin`（0.02 MB）为插件示例：`engine/game.js` 内 `GODOTSDK.load_pack1` 手动加载；产物「使用前阅读.md」说明 4.5 支持多 pck 分包加载与 `GODOTSDK.releasePck()` 卸载
- 微信单分包无独立上限 → **无需拆 wasm/pck 双分包**，engine 分包整体计入总包即可

pck 构成审计（v2，ETC2 后，两档均 432 文件）：

- 全量档 pck 22.68 MB：ctex 19.92 MB（v1 lossless 时 132.27 MB，ETC2 降 85%）、ogg 1.52 MB（BGM 重编码较 v1 省 ≈0.9 MB）、字体 0.63 MB、gdc 0.32 MB
- 精简档 pck 14.31 MB：ctex 11.55 MB（slim 尺寸档：sprites/vfx 长边 256、terrain/env/ui 长边 512），音频/字体/脚本与全量档相同
  - 复核注记（当日）：env 长边收紧 512→384 后复测 pck 13.00 MB（ctex 10.24 MB）；现行 slim 档 = sprites/vfx 256、terrain/ui 512、env 384
- 两档文件数相同（432）：排除清单只排无引用的死资产，slim 档只改导入尺寸、不改内容集

结论：**微信端全量档即可直接发布**（29.05 ≤ 30 MB，无需 CDN）；**抖音端 slim 档仍微超 ≈0.7 MB**，需补齐差额或重美术走 CDN（见第三节路线）。

> 复核注记（2026-08-20 当日）：抖音差额已由 slim 收紧补齐（总包 19.37 MB ≤ 20 MB），**两端均无需 CDN**；上文为 v2 首次结论。

## 三、包体优化路线（按序执行，每步实测）

### 阶段 1：纹理切 VRAM 压缩（ETC2/ASTC）——✅ 已完成（最大免费杠杆）
- 动作：全部 `.import` 批量切 `compress/mode=2`、`vram_texture=true`，`project.godot` 同步 `import_etc2_astc=true` + `import_s3tc_bptc=false`（小游戏端只留移动端格式）→ `--import` 重导入 → 重导对比。
- 实测：ctex 132.27 → 19.92 MB（-85%），全量 pck 136.23 → 22.68 MB；附带 3 条 BGM ogg 重编码，音频 2.41 → 1.52 MB（省 ≈0.9 MB）。
- 遗留风险：暗部渐变画质损失（terrain / sanctuary 大图重点目检）——真机提审前目检一次。

### 阶段 2：死资产排除 + preset.3 重设计——✅ 已完成
- preset.2 / preset.3 现共用同一份 78 条 `exclude_filter` 清单（APK 瘦身经验复用 + `tools/minigame_unused_scan.mjs` 无引用扫描 + `tools/minigame_exclude_check.mjs` 误杀检查；检查已知噪音 18 条：TestShader / ground_* / terrain 引用链与 tests/tools 自引用，无真冲突）。
- **preset.3 重设计**：v1 的「排除全部美术目录」（13 条整目录排除）会令 preload() 美术的脚本 parse 失败，已废弃；现在 preset.3 = 同一份排除清单 + 更紧的导入尺寸档（slim profile）。
- slim 档由 `tools/minigame_size_limit.gd` 管理（default/slim 两档：slim 为 sprites/vfx 长边 256、terrain/ui 长边 512、env 长边 384（2026-08-20 当日由 512 收紧）），`tools/minigame_export.ps1` 自动完成「快照全部 .import → slim apply → --import → 导出 → 恢复快照 → --import」，仓库恒回默认档。
- 实测：slim 档 ctex 19.92 → 11.55 MB，总包 29.05 → 20.69 MB（省 8.36 MB）；两档 pck `--main-pack --quit-after 30` 运行时验证零脚本错误。

### 阶段 3：重美术 CDN 化——微信已不需要；仅抖音补差额时启用
- 微信：全量档 29.05 MB ≤ 30 MB 且单分包无独立上限，**直接发布，无需 CDN**。
- 抖音：slim 档 20.69 MB 微超 20 MB 限额 ≈0.7 MB，两条路：(a) 继续瘦 pck 补齐差额（更紧尺寸档 / 音频再压 / 排除清单扩列）；(b) 重美术走 CDN：`HTTPRequest` 下载 + `user://` 缓存 + `ProjectSettings.load_resource_pack()` 热载（CDN 资源运行时下载，不受包内文件白名单限制）。
- 插件侧已具备多 pck 基础：`GODOTSDK.load_pack1` 手动加载分包 pck、`GODOTSDK.releasePck()` 卸载——CDN 化时可按关卡/场景拆 pck。
- 附加工作（若走 CDN）：资源版本化 / 缓存失效、首次进入的下载进度 UI、弱网降级——这是改造量大头。
- 复核注记（2026-08-20 当日）：抖音差额已由 slim 收紧补齐（19.37 MB ≤ 20 MB），阶段 3 未启用，仅保留为后续内容增量时的后备手段。

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

1. [x] ~~移除 autoload MCPRuntime~~ —— 已由 `tools/minigame_export.ps1` 自动化：导出前临时剥离 `MCPRuntime → res://addons/godot_mcp/...`（0.76MB），导出后自动恢复，仓库不动
2. [ ] 替换微信 AppID（见第四节；preset.2 / preset.3 两处的 `wxf40904ea6120ad08` 均为插件 demo 值）
3. [ ] 配置启动封面背景图 / logo（预设「资源信息」选项，当前为空）
4. [x] ~~执行第三节阶段 1（ETC2 重导入）~~ —— ✅ 已完成并实测（ctex 132.27 → 19.92 MB，见第二、三节）
5. [x] ~~抖音端：slim 档微超 20MB 限额 ≈0.7 MB，补齐差额（继续瘦 pck）或走 CDN~~ —— ✅ 已解决（2026-08-20）：slim 档收紧 env 长边 512→384（12 张环境贴图 512²→384²），pck 14.31→13.00 MB、总包 19.37 MB ≤ 20 MB 达标（余量 0.63 MB），UI/角色贴图未动；TTSDK / 横屏真机验证仍为后续项（见第五节）
6. [ ] 正式提审前重跑双 smoke 与两端导出（4.5.1 基线：459 项 / 26 场景）

## 七、参考资料

- 配套调研报告：`Docs/research/minigame-publish-research.md`（平台规则对比表、三条技术路线对比、合规流程细节与官方文档 URL 清单）
- 插件仓库：godothub/godot-minigame（AtomGit 镜像；模板 `minigame4.5.1.tpz`，本地留档 `Experimental/minigame4.5.1.tpz`）
- 抖音官方 TTSDK：`partner.open-douyin.com` → 小游戏 → 开发 → 游戏引擎 → Godot