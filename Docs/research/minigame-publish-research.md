# 微信 / 抖音小游戏打包发布调研报告

> 状态：定稿 v1 ｜ 日期：2026-08-20 ｜ 调研基于 2026-08 官方文档现网页面
> 对象：本项目 Godot 4.7.1（GDScript only）正式版，类吸血鬼幸存者，横屏 1280×720
> 原始抓取文本存于 `Experimental/wx_*.txt`、`Experimental/dy_*.txt`（gitignore，仅本地留档；引用均以官方 URL 为准）

## 一、结论（TL;DR）

**可行，但不能直接导出。** Godot 官方 Web 导出产物无法直接上传小游戏平台，必须走"小游戏专用引擎模板 + 平台适配层"方案。本项目有三道硬门槛：

1. **引擎版本**：微信无官方 Godot 支持（走通用 Emscripten 方案）；抖音有官方 Godot 支持但**当前仅认证 Godot 4.5**。本项目是 4.7.1，需要"降级"或"用社区模板硬上"。
2. **包体**：两平台代码包上限（微信 30MB / 抖音 20MB）装不下本项目 ~100MB+ 的素材；引擎 wasm.br（实测 ≈10MB）+ 纯代码 pck（≈1.5MB）可以装下。**素材必须全部 CDN 化**。
3. **资质合规**：小游戏备案 + ICP 备案是前置项；IAA（广告变现、不开虚拟支付）路线下微信侧**一般无需版号/软著**，中宣部实名系统由平台统一接入（开发者零操作），是独立开发者最友好的路线。

**推荐路线**：先用 1–2 天做技术验证（spike）——用社区模板（godothub 4.7 tpz，保持 4.7.1 不降级）导出空工程跑通微信开发者工具 + 抖音 IDE 双端启动；spike 通过即定为主线，失败则回退到 AnranS 认证模板（需降级 4.6.1）。抖音官方 4.5 路线（TTSDK）作为长期备选，仅当平台方明确要求或提供流量扶持时考虑。

## 二、平台规则对比（均来自官方文档，2026-08 核实）

| 维度 | 微信小游戏 | 抖音小游戏 |
| --- | --- | --- |
| 代码包总上限 | **30MB**（主包+所有分包） | **20MB**（整包目录） |
| 主包 | ≤4MB | ≤4MB |
| 分包 | 单个普通分包不限大小（受总量 30MB 约束）；独立分包 ≤4MB | 单分包 ≤20MB；开放数据域 ≤4MB |
| 分包加载 | `wx.loadSubpackage()` / `wx.preDownloadSubpackage()`（基础库≥3.4.9） | `tt.load_subpackage()`（TTSDK 封装） |
| Wasm | `WXWebAssembly`：基础库 ≥2.13.0（全局）/≥2.15.0（Worker）；支持 `.wasm.br`；8.0.25 起支持 SIMD；iOS 暂不支持 Global export | `TTWebAssembly`：基础库 ≥3.7.0；**仅支持包内 `.wasm.br`**；**iOS 不支持 SIMD** |
| Wasm 异常处理 | 已支持原生 EH（iOS JSC15.2+/Android/PC；Windows 开发者工具 stable 的 V8 未开，需 Nightly）——但社区方案仍普遍强制 longjmp 求稳 | 无官方说明，按 longjmp 处理 |
| 文件白名单 | `.wasm .br .bin .zip .ogg .ttf .astc .ktx .pkm` 等；**无 `.pck`**；`game.js` ≤2MB | 同类白名单含 `.wasm .wasm.br .br .bin .zip .ogg .astc`；**无 `.pck`**（导出插件自动改名 `.bin`/`.br`） |
| 屏幕方向 | 横竖屏均支持 | 官方文档"暂时仅竖屏"；TTSDK 1.0.2+ 已提供横屏导出选项（待真机验证） |
| Godot 官方支持 | **无**。引擎无关架构，Godot 归"其他原生引擎"走通用引擎适配（Emscripten）方案 | **有**。抖音小游戏引擎团队官方支持，当前认证列表仅 **Godot 4.5（推荐）**，不支持自定义引擎版本 |
| 音频 | ogg 在白名单；注意 iOS 音频解锁 | ogg 在白名单；旧 iOS（基础库 <3.95）AudioPlayer 仅 SAMPLE 模式 |
| 存档 | `user://` 由适配层映射宿主存储（方案相关） | TTSDK：包内只读 + `user://` 可读写；包内文件访问前须 `tt.mount_ttpkg_file()` |

## 三、技术路线对比

### 路线 A：抖音官方 TTSDK（Godot 4.5）
- **来源**：抖音开放平台官方文档（`partner.open-douyin.com` → 小游戏 → 开发 → 游戏引擎 → Godot），2024-12 起由抖音小游戏引擎团队维护。
- **形态**：`addons/ttsdk` + `ttsdk.editor` 插件（最新 **1.0.4**，2026-07-15），注入 `tt-minigame` 导出平台；autoload `tt` 提供 `is_run_in_tt()`、`tt.login()`、`mount_ttpkg_file()`、`load_subpackage()` 等。
- **导出参数**：App ID、Canvas Resize Policy、**Subpackage On**（wasm+主 pack 进子包）、Enable iOS Hpp（iOS 高性能+）、Brotli On/Policy（Fast=5 / Size=9）、Remote Debugger 等。**不支持自定义导出模板**。
- **限制**：仅支持特定 Godot 版本（当前列表只有 4.5）；渲染走 Compatibility；ASTC/ETC2；无多线程/GDExtension/C#/WebRTC/遮挡剔除；LineEdit 在 4.5 无 `text_changed`/`submitted` 信号（已知问题）。
- **对本项目**：需 4.7.1 → 4.5 **降级**（GDScript 向下兼容大体 OK，但需全量回归 smoke；会失去 4.6/4.7 的修复与特性），且**仅覆盖抖音**，微信还得另找方案。
- **评价**：官方维护、长期最稳，是"抖音单平台长期运营"的正解；代价是引擎降级 + 双平台两套方案。

### 路线 B：AnranS/godot_for_minigame（社区插件，MIT）
- **来源**：github.com/AnranS/godot_for_minigame；main 分支 `support-matrix.json` 现为 **plugin 0.3.0**（最新 GitHub release v0.2.1，2026-08-02），bridgeAbi 1，`requiresExactEngineTemplate: true`。
- **认证引擎**：**仅 Godot 4.6.1.stable**（tag `4.6.1-stable`，commit `14d19694e0c8`，Emscripten 4.0.3，`2d_full` profile，release，templateRevision 1）。平台矩阵：wechat / douyin 均 automated，tiktok beta。
- **形态**：编辑器 Dock 插件；`MiniGameSDK` autoload（约 224 方法/83 信号）；导出产物 = 主包（game.js/adapter）+ 引擎分包（godot.wasm.br + godot.zip 即改名的 pck）+ 资源分包。`user://`（IDBFS）映射宿主存储，5s syncfs + onHide flush。
- **对本项目**：要么**降级 4.6.1**（比降到 4.5 损失小），要么用其 `scripts/build_wasm_template.sh [godot-tag] [emsdk-ver]` 自编 4.7.1 模板——但补丁基于 4.6.1 的 godot.js，4.7.1 未验证，且插件强制"模板版本精确匹配"，自编模板属脱保操作。
- **评价**：双平台统一出口，工程化程度高；风险是认证版本落后项目两个小版本。

### 路线 C：godothub/godot-minigame（社区 C++ 插件 + 预编译模板，MIT）
- **来源**：github.com/godothub/godot-minigame。Release 按引擎版本分桶：4.3.0 / 4.4.0 / 4.5.1 / 4.6.2 / **4.7**（2026-07-22 发布）。
- **模板**：`versions.yaml` 显示 4.7 桶模板 `minigame4.7.0.5.tpz` 由 tag **4.7**（即 4.7.0）构建，**11MB**（内含 wasm.br，br 不可再压缩 ? wasm.br ≈ 10MB）。模板匹配规则"回退到 ≤ 目标版本"，4.7.1 项目会命中 4.7 模板（patch 级差异，pck 格式不变，风险低但非精确匹配）。
- **内置补丁**：fetch 分块 write_offset 修复、iOS 关 SIMD、音频/显示/输入清理（contextPool、getWindowInfo、showKeyboard）——都是小游戏环境实打实的坑。
- **代价**：C++ 插件需源码编译（godot-cpp + `build_win.bat`）；`skills/` 配套工具链锁在 Godot 4.6 分支 commit `a16e481cf4`（bundle id `godot-4.6.2-rc-a16e481cf4`），自编引擎时用。
- **评价**：**唯一能保持本项目 4.7.1 大体不动的方案**（模板 4.7.0 与 4.7.1 差一个 patch）。社区项目无官方背书，需 spike 验证。

### 路线 D：微信"通用引擎适配方案"自研 Emscripten 接入
微信对非 Cocos/Unity 引擎提供通用方案（产物 game.js + wasm + data，经转换工具接入），状态标注"需评估"。工作量最大（自己维护 adapter、文件系统、音频解锁），仅当 A/B/C 全部失败才考虑。

### 路线 E（备选思路）：HTML5 原型直接改小游戏
根目录原型是零依赖 Canvas + ES Modules 的 JS 游戏，天然贴近小游戏形态（无 wasm、包体极小、启动快）。但 Godot 版才是正式版且功能已拉开差距（原型落后于 M5/M6 进度），双轨重齐成本高。**仅当 Godot 路线整体受阻时启用**。

### 路线对比矩阵

| | A 抖音官方 | B AnranS | C godothub | D 自研 |
| --- | --- | --- | --- | --- |
| 引擎版本要求 | 降到 4.5 | 降到 4.6.1（或脱保自编 4.7.1） | 保持 4.7.1（模板 4.7.0） | 4.7.1 自编 |
| 平台覆盖 | 仅抖音 | 微信+抖音(+TikTok beta) | 微信+抖音 | 微信（抖音另做） |
| 维护方 | 抖音官方 | 社区（活跃，2026-08 仍在发版） | 社区 | 自己 |
| 主要风险 | 降级回归成本；微信无解 | 降级；自编模板脱保 | 需编译 C++ 插件；无官方背书 | 工作量不可控 |

## 四、本项目包体预算（实测数据）

当前资产盘点（`GameProject/` 全量，不含 .godot）：

| 类别 | 大小 | 处置 |
| --- | --- | --- |
| PNG 纹理（175 张，含 20482×8 向行走图集、20482 地形） | **131.9 MB** | 全部 CDN；导出时走纹理压缩可再降 |
| OGG 音频（27 个：24 SFX + 3 BGM） | 2.3 MB | 可进包（两平台白名单均含 .ogg）或 CDN |
| TTF 字体（2 个，子集化后） | 0.9 MB | 可进包或 CDN |
| GDScript（106 个）+ 场景/资源/配置 | ≈1.2 MB | 进包（代码 pck） |
| 引擎 wasm.br（godothub 4.7 tpz 实测 11MB 模板） | **≈10 MB** | 进包：微信放普通分包；抖音开 Subpackage On |

**预算结论**：

- **微信**：主包 ≤4MB（game.js/adapter）+ 分包（wasm.br ≈10MB + 代码 pck ≈1.5MB + 音频 2.3MB + 字体 0.9MB ≈ 14.7MB）? 总计 ≈15–19MB < 30MB ? 余量充足。
- **抖音**：整包 ≤20MB：wasm.br ≈10MB + 主包 js ≈1MB + pck/音频/字体 ≈4.7MB ? ≈16–17MB < 20MB ? 可行但紧张，BGM 建议也走 CDN。
- **CDN 侧**：纹理裸 131.9MB；按 Android 导出先例（ETC2 压缩后 APK 121MB）估计压缩纹理后 40–80MB 量级，需导出后实测。CDN 资源走 HTTP 运行时下载，不受包内白名单限制。
- **注意**：`.pck` 不在两平台白名单——微信侧改名 `.zip`/`.bin` 上传；抖音 TTSDK 导出自动改名（代码里仍按 `.pck` 加载）。

## 五、本项目改造清单

**工程侧**
1. 新建小游戏导出链路（按选定路线）：Web/minigame 导出预设，`threads=no`、`wasm_simd=no`（iOS 兼容）、longjmp EH。
2. **资源 CDN 化**：新增远程加载层（首包 = 代码 + 引擎；纹理/BGM/字体按需 HTTP 拉取 + 本地缓存）。这是改造量大头。
3. pck 拆分与改名（代码包内 `.bin`，素材远端）。
4. 存档：`autoload/meta_save.gd` 走 `user://` 无需改逻辑，但要验证各方案的 flush 时机（切后台/退出前落盘）。
5. 屏幕方向决策：**微信横屏无障碍；抖音官方口径目前竖屏**（TTSDK 1.0.2+ 有横屏导出，需真机验证）。若抖音必须竖屏，UI/HUD 锚点需要一套竖屏适配——这是本项目最大的潜在返工点，spike 阶段优先验证。
6. 触摸输入已有桥接（`bf81834`），无需额外开发。
7. 性能：M6 待办的 180 敌人性能/对象池与小游戏低端机目标直接重叠，优先做。

**平台 SDK 侧**
8. IAA 变现：激励视频广告（复活/奖励）、Banner/插屏（两平台都有对应 API）。
9. 登录/用户信息（wx.login / tt.login）、分享转发。
10. 抖音**必接能力**：侧边栏复访能力（所有小游戏强制）；有用户输入时接敏感词；IAP 才需客服。
11. 隐私：微信需配置「用户隐私保护指引」+ C 端授权弹窗 + 授权结果上报（用到 wx.getUserInfo 等标准 API 时）。

## 六、发布合规流程

### 微信（IAA 路线，个人主体可行）
1. **注册**：mp.weixin.qq.com 注册小游戏账号（个人主体可注册）。
2. **类目**：一级类目"游戏"注册时选定不可改；二三级类目可选**休闲/益智/动作**等——注意**个人主体不可选文化互动、角色类、牌类**；类目与内容不符会在提审时被驳回。
3. **资质审核（IAA）**：选择"情况二：不开通虚拟支付"，一般**无需版号/软著**（游戏名含英文/"软件"或品牌合作时才需软著/授权书）；审核 1–3 个自然日。
4. **小游戏备案**：IAA 备案为前置审批环节 → 平台初审 → 主管部门 → 再走小程序备案（工信）；名称/主体须全程一致。
5. **适龄提示**：8+/12+/16+ 分级，MP 后台设置，展示于启动页健康游戏忠告旁。
6. **隐私合规**：自查是否处理个人信息 → 配置隐私保护指引 → C 端弹窗曝光 → 上报授权结果。
7. **中宣部实名**：不开通虚拟支付的，平台已统一协助接入，**开发者无需操作**。

### 抖音
1. **入驻**：开放平台注册账号 + 主体认证 + 对公验证。主体支持企业、个体工商户、党政机关、事业单位、社会组织及**个人**（个人可创建小玩法/小游戏/小程序）；但个体工商户需对公账户、变现结算走对公，**实际运营建议企业/个体工商户主体**。主体类型审核通过后不可变更。
2. **创建小游戏 + 完善信息**（基本信息审核）。
3. **开发接入**：侧边栏复访（必接）；使用 TTSDK 的 `tt` autoload。
4. **提审**：版本审核通过后**平台自动申报小游戏备案**（无需手动；已有版号的游戏免备案）。
5. **ICP 核准**与中宣部防沉迷渠道绑定：后者仅"已获得版号的在运营游戏"需要（绑定统一社会信用代码 `911101085923662400` 北京抖音信息服务有限公司）。

## 七、建议行动计划

| 阶段 | 内容 | 产出/判定 |
| --- | --- | --- |
| **P0 技术 spike（1–2 天）** | ① godothub 插件编译 + 4.7 tpz 模板安装；导出空工程/最小场景；微信开发者工具 + 抖音 IDE 双端启动验证。② 并行验证抖音横屏真机表现（决定 UI 是否返工） | 双端能启动 → 路线 C 定主线；失败 → 回退路线 B（降 4.6.1） |
| **P0 资质并行（同期启动，周期最长）** | 注册微信小游戏账号 + 类目/资质（IAA）；注册抖音开放平台 + 主体认证/对公验证；启动备案材料准备 | 两边审核/备案排队中 |
| **P1 资源 CDN 化** | 远程加载层 + 导出拆包脚本 + pck 改名 + 缓存策略；实测包体与首屏加载时间 | 双端包体达标（≤预算表） |
| **P2 平台功能** | 广告（激励视频）、登录、分享、侧边栏复访、隐私弹窗、存档 flush 验证 | 功能自测清单全绿 |
| **P3 性能与提审** | 180 敌人低端机达标（与 M6 合并）、适龄提示/隐私/备案材料提交、提审 | 双平台过审上线 |

## 八、参考资料

官方文档（2026-08-20 访问）：
- 微信代码包限制与白名单：developers.weixin.qq.com/minigame 开发 → 代码包（`Experimental/wx_code_package.txt`）
- 微信分包加载：`wx_subpackage.txt`；通用引擎适配（Emscripten）：`wx_emscripten.txt`、`wx_engine_overview.txt`
- 微信 WXWebAssembly：`wx_wasm.txt`；Wasm Exception：`wx_wasm_exception.txt`
- 微信合规：IAA 资质 `wx_iaa_qual.txt`、小游戏备案 `wx_beian.txt`、类目 `wx_category.txt`、注册 `wx_register.txt`、适龄提示 `wx_slts.txt`、中宣部实名 `wx_zxbsm.txt`、隐私 `wx_privacy.txt`
- 抖音 Godot 官方接入：partner.open-douyin.com → 小游戏 → 游戏引擎 → Godot（接入指引/引擎集成/SDK 使用/适配清单，`dy_sdk.txt`、`dy_checklist.txt`）
- 抖音包体与白名单：bytedance-mini-game 页（`dy_minigame_intro.txt`）；TTWebAssembly：`dy_wasm.txt`
- 抖音入驻/备案/必接能力/实名：`dy_join.txt`、`dy_register.txt`、`dy_filing.txt`、`dy_essential.txt`、`dy_realname.txt`

社区方案：
- github.com/AnranS/godot_for_minigame（`support-matrix.json`、README/USAGE 中译：`Experimental/research_README_zh.md`、`research_USAGE_zh.md`）
- github.com/godothub/godot-minigame（Releases：4.3–4.7 模板桶、versions.yaml）
