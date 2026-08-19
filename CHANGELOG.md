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
- `ab77e16` feat(audio)：新增开炉音效 sfx_furnace_open（监听丹火炉累计开炉数触发，高频节流 0.12s）；SFX 账面 2/22→3/23，s22 冒烟扩展（415→419 项）。

## 2026-08-19 · 文档体系重整

- 删除过时文档：根 `DESIGN.md`、`Docs/wave-difficulty-table.md`、`Docs/project-status-summary.md`、`Docs/art-resource-refresh-2026-08-16.md`（信息已由 `GameProject/RULES.md`、`BALANCE.md`、`PROGRESS.md`、`ART_ASSET_CONFIG.md` 承接）。
- 重写根 `README.md`；新建本文件（`CHANGELOG.md`）与 `Docs/README.md`（文档地图 + 更新纪律）。
- Docs 5 个保留文件加状态头/复核注记；`AGENTS.md` 增补文档纪律与 Godot 命令；修复 RULES.md / PLANS 中的 DESIGN.md 引用。
- 更正：Godot smoke 检查数 415→419 由 `ab77e16` 新增 s22 检查所致（此前误归因，历史行不回改）；已更新 README 与 ART_ASSET_CONFIG 现状行。
- 补同步 `ab77e16`（开炉 SFX）的文档缺口：SFX 账面 2/22→3/23 同步至 PROGRESS / OPTIMIZATION_TRACKER / ART_ASSET_CONFIG / README（该提交当时未带文档，违反同提交纪律，此处补录）。

## 2026-08-19 · 第八轮收尾（补录）

- `cbab517` **feat(vfx)**：序列帧运行时接入——新增 `logic/systems/flipbook.gd` 纯函数裁帧；`art_catalog.gd` 增 `cloakFireBurstAnim` / `furnaceFlameAnim`（`VFX_TEXTURES` 22→24）；`world_art_view.gd` 披风 Lv6 爆发一次性播放 + 丹炉/余烬/丹火循环火焰（世界坐标位置相位）；另补齐 **4 类敌人预警**：bomber 自爆蓄力（加速闪烁+收缩环）、enhanced_chaser 狂暴前（脉动光环+旋转断口）、Boss 弹幕蓄力（扩张环+倒计时弧）、ranged 枪口蓄力点；新增 s24_flipbook 冒烟章节（419→436 项 / 24→25 场景）。该提交未带文档，违反同提交纪律，此处补录。
- `ff44fac` **feat(audio)**：21 条 SFX + 3 条 BGM（battle/boss/menu）入库；磁盘 SFX 共 24 条，覆盖 `SFX_PATHS` 全部 23 键（部分键共用文件），BGM 3/6（rest/extraction/summary 缺，gameplay 实际文件为 battle）；s22 仅抽查首批 3 条 SFX + bus layout，无回归。该提交未带文档，违反同提交纪律，此处补录。
- `12b1180` **fix(vfx)**：披风火焰爆燃序列帧重抠像——BiRefNet 显著性抠像侵蚀弥散火焰（关键帧覆盖率 82%→19.8%），改用亮度阿尔法重键（remat_luma.py：黑点提升 / 0.02 噪底 / gamma 0.8 光晕 / 反预乘 + 0.10 clamp / bleed 24），图集原位重建，硬规格（2000×2000 RGBA8、5×5、cell 400、fps 4.83871）不变；覆盖率弧线恢复为蓄力 53–72% → 爆发 82–88% → 单调消散；生产归档 `ArtAsset/Image/VFX/gen_20260819_anim/`。
- 现状同步：Godot smoke 436 项 / 25 场景；序列帧运行时集成完成；音频 SFX 24/23 键、BGM 3/6；敌人预警已补 4 类（shield phase 仍缺）。SFX 键位重映射、BGM 音量/交叉淡化（audio_manager WIP）与 fireBallAnim（并行会话 WIP）未落库。

## 进行中 / 已知缺口

- 对象池 + 180 敌人压测（`GameProject/OPTIMIZATION_TRACKER.md` 候选）。
- 音频收尾：BGM 缺 3 条（rest/extraction/summary）；SFX 24 条已覆盖 23 键，键位重映射与 BGM 音量/交叉淡化参数在工作区 WIP 待落库。
- 盾兵攻防相位表现（其余 4 类敌人预警已由 `cbab517` 补齐：bomber/enhanced_chaser/Boss/ranged）。
- Windows 导出流程。

## 2026-08-19 · 音频收尾 + Lv6 质变设计

- 0bc9de9 feat(av)：音频事件映射落库——audio_manager.gd SFX 键位重映射 + BGM 音量/交叉淡化参数正式化；fire_ball_anim.png flipbook 图集入库（2.9MB）；game_overlay/game_view/world_art_view 音频接线同步更新。
- 17720a5 chore(perf)：确定性空间网格基准——tools/perf_grid_benchmark.gd + _impl.gd，SEED=20260819，60/120/180/240 敌人规模分离与查询加速比 ×4.5~×7.2。
- 4d6b7c9 chore(av)：披风火焰爆发序列帧亮度阿尔法重抠像（覆盖率弧线恢复）+ 补齐 3 个缺失 .uid 文件。
- 文档：OPTIMIZATION_TRACKER.md 新增第四轮「6 武器 Lv6 质变视觉差异化」设计方案（雷符天雷引/法杖百鬼夜行/玉戒极意/丹炉九转），含现状分析与优先级排序。
- .gitignore 新增 ArtAsset/Flipbook/（88MB 生产源帧，不入版本库）。
- 全局 git proxy 移除（此前导致大文件 push RPC 超时）。

- feat(vfx)：丹炉火焰 flipbook 图集重制——Krea-2 生成关键帧 + MiniMax H3 i2v 视频 + BiRefNet 抠像 + 5x5 图集（2048px RGBA8），FLAME_FPS 4.84->8.82 / FLAME_LOOP_FRAMES 24->25；生产归 ArtAsset/Image/VFX/gen_20260819_flame/；双冒烟 436/25 全绿。

## 2026-08-19 · 编码修复与丹火动画统一

- fix(vfx)：编码损坏修复与丹火 2048 图集接线——world_art_view.gd 工作区遭有损编码转换（UTF-8→GBK→UTF-8）致 GDScript 解析失败，恢复后重应用功能改动；修复 HEAD 遗留 2 处损坏注释（eda8dd1 起）；剥离 flipbook.gd / s24_flipbook.gd 多余 BOM；flipbook.frame_region 新增 atlas_size 参数（默认 2000 向后兼容，不均匀单元 roundi 定位）支持 2048×2048 图集，_draw_flame_anim 对齐 a260d55 重制的 furnace_flame_anim.png（5×5、content 393、gutter 8）；s24 新增 2048 用例，循环参数更新为 8.823529 fps / 25 帧；双冒烟 440 项 / 25 场景全绿。
- docs：CHANGELOG.md 与 OPTIMIZATION_TRACKER.md 自 bae597e 混合编码损坏中逐字恢复——9a5557d6 干净基底 + GBK 解码还原追加章节（音频收尾 + Lv6 质变设计；第四轮 6 武器 Lv6 质变视觉差异化），原样保留 a260d55 丹炉火焰图集重制条目。
- feat(vfx)：行走 trail 火焰换用丹炉火焰新图集——_draw_trails 由 fireBallAnim（2000×2000）改用 furnaceFlameAnim（2048×2048，a260d55 重制）+ frame_region(frame, 5, 2048, 393, 8)，局内行走残留火焰与丹炉/丹火视觉统一；用户局内验证通过；双冒烟 440 项 / 25 场景全绿。

## 2026-08-19 · 关卡场景调整

- chore(scene)：草地关卡 Ground 缩放 0.5→0.861 并平移居中，背景色块收缩至 ±1763 恰好适配缩放后地面显示区域；新增 CollisionPolygon2D 关卡边界。
- chore(export)：新增 Windows Desktop 导出预设 export_presets.cfg（x86_64、嵌入 PCK，输出路径 build/windows/aigame.exe）。
- chore(scene)：草地关卡边界碰撞改挂 Area2D（裸 CollisionPolygon2D 在 Node2D 下不生效）并精调多边形范围；双冒烟 440 项 / 25 场景全绿。

## 2026-08-19 · 触屏选卡（移动端适配）

- feat(input)：触屏点选卡牌——game_view.gd 将 InputEventScreenTouch（index 0 按下）桥接为鼠标左键单击、InputEventScreenDrag（index 0）桥接为鼠标移动，第二根手指忽略；选卡/菜单复用鼠标命中语义，移动端无需键盘即可完成完整流程，数字键保留为桌面端快捷路径。新增 s23_touch_choice 冒烟章节（触摸按下/拖拽/多指/点选开局进 playing 全流程）；run_smoke.gd 延后到第一帧执行（_initialize 阶段根窗口尚未入树，场景类章节 @onready 为空）；RULES.md §3.2/§11.6/附录 C 同步。双冒烟 450 项 / 26 场景全绿。

## 2026-08-20 · 包体瘦身（行走图集降采样与中文字体子集化）

- perf(assets)：行走图 atlas 由 4096² 降至 2048²——8 方向行走序列帧图集 bicubic 降采样，约 75MB→约 20MB（原始 4096 备份于 Experimental\backup_4096_walk_atlas\，不入库），walk_*.json 元数据同步（cell 682/683→341/342、gutter 8→4、resized_frame 666→333）；player_view.gd WALK_SCALE 0.14→0.28 补偿，屏幕尺寸不变。Windows 导出包 296.3→257.9 MB。
- perf(assets)：中文字体子集化——按全仓文案实际用字（1074 字符，其中 943 CJK）子集化两款字体：nowar_rounded_bold.ttf 17.72→0.34 MB、noto_sans_sc.ttf 16.95→0.54 MB（完整字体备份于 Experimental\backup_full_fonts\，不入库）。导出包进一步降至 235.2 MB。
- chore(tools)：字体子集再生工具 tools/font_subset.py 入库——扫描 GameProject 文本源提取字符集并重跑子集化，字符表留存 tools/font_subset_charset.txt；新增文案后缺字时重跑即可。双冒烟 459 项 / 26 场景全绿。

## 2026-08-20 · Android 打包环境与 Android 导出预设

- feat(export)：新增 Android 导出预设（arm64-v8a 单架构、APK 格式、debug keystore 签名），输出 `build/android/aigame.apk`（约 174 MB），包名 `com.aigame.app`，minSdk 24 / targetSdk 36，versionCode 1 / versionName 1.0；导出排除 tests/tools/markdown，与 Windows 预设一致。
- chore(env)：本机安装 Android 打包环境（不入库）：Godot 4.7.1 Android 导出模板（debug/release/source）、JDK 17（Temurin 17.0.20）、Android SDK（platform-tools + platforms;android-36 + build-tools;36.0.0）；debug keystore 由编辑器自动生成于 `%APPDATA%\Godot\keystores\debug.keystore`。注意 Godot 4.7 Android 导出强制要求“编辑器设置 → 导出 → Android”显式填写 Java SDK Path 与 Android SDK Path（不读 JAVA_HOME 环境变量）。
- perf(project)：启用 `rendering/textures/vram_compression/import_etc2_astc`（Android 导出必需），纹理导入为 S3TC+ETC2 双格式：Windows 包 235.2→251.8 MB（+16.6 MB 为双格式纹理代价）；仅发桌面端时可关闭该项并重导入恢复。正式 release APK 需再生成 release keystore（当前仅 debug 包可出）。
- docs：`GameProject/AGENTS.md` 构建命令节补导出命令与环境要求。双冒烟 459 项 / 26 场景全绿。

## 2026-08-20 · 包体瘦身第二轮与 Android release 签名包

- perf(assets)：主地形贴图 amber_starlight_sanctuary_4096.png 4096²→2048²（LANCZOS 降采样；Polygon2D 归一化 UV，场景零改动；原图备份 Experimental\backup_terrain_4096\，不入库），导入 ctex 16.7→5.2 MB；字体子集再生工具重跑验证幂等（字符集 1073，两字体字节级无变化）。
- chore(export)：导出预设 exclude_filter（Windows/Android 双预设）排除死资产——全仓无任何引用（无 .uid、无路径引用）的 4 张 ground_*_crisp.webp（APK 内约 35 MB）与仅自引用的预览场景 art_ground_preview.tscn 及其独占贴图 amber_starlight_sanctuary_2048.png（约 4.9 MB）；源文件保留在仓库，仅不进包。
- feat(export)：生成 release keystore（RSA 2048、10000 天、alias aigame）并写入 Android 预设 keystore/release*；keystore 文件在 %APPDATA%\Godot\keystores\release.keystore，口令与备份在 Experimental\backup_release_keystore\（均不入库）。--export-release 出正式签名 build/android/aigame.apk：174.4 MB（debug）→121.2 MB（release），<150 MB 目标达成；aapt2 校验包名 com.aigame.app、minSdk 24 / targetSdk 36、已签名。
- 已知遗留：未设置项目图标（导出日志报 No project icon，不影响签名与安装）；微信/抖音小游戏需另走 Web 导出链路。双冒烟 459 项 / 26 场景全绿。
