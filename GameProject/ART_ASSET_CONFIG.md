# Godot 美术资源配置台账

> 最后核对：2026-08-14
>
> 适用工程：`GameProject/`（Godot 4.7.1）
>
> 用途：统一记录正式资源、待修订资源、未配置资源和开发回退。玩法进度仍以 `PROGRESS.md` 为唯一真值。

## 1. 状态定义

| 状态 | 含义 |
| --- | --- |
| 已配置 | 资源已进入 `GameProject/assets/`，已绑定正式场景或表现节点，并可在主游戏中看到 |
| 已配置（回退保留） | 正式资源已经生效，旧资源或程序化绘制仅保留作开发回退 |
| 待升级 | 当前版本已可交付，但仍可用动画、材质或更高规格素材继续提升 |
| 未配置 | 尚无正式资源或正式表现节点 |

## 2. 当前总体进度

- 工程里程碑：M0–M5 完成，M6 进行中，完成度 `6 / 7`。
- Godot smoke：`23 / 23` 章节已全部移植，最新本地回归为 `358` 项检查全绿。
- 正式关卡：4096×4096 草甸地形、确定性地图边界和环境装饰均已挂入主场景。
- 正式世界表现：`WorldArtView` 已取代 `PlaceholderWorld`，接管敌人、Boss、弹道、掉落、召唤物、任务信标、武器范围与战斗 VFX。
- 正式玩家表现：主游戏已恢复 `AnimatedSprite2D` 的 Idle / Move / Dead 八方向动画状态机，`player_static.png` 仅作为资源缺失时的回退。
- 正式 UI：HUD、卡牌、Boss、任务、稀有物、模态框、主菜单、商城、仓库与 Debug 已统一为现代 Q 版圆角卡片体系，并完成焦点/悬停/按下/禁用状态。
- 正式字体：`Noto Sans SC` 与 OFL 许可已进入工程并应用于游戏内 UI 和 Meta UI。
- 剩余缺口：正式音频、可选的玩家逐帧动画升级、实体视图对象池与 140 敌人压力检查。

## 3. 资源流向约定

```text
ArtAsset/ 或 Experimental/
  → 选定定稿
  → 复制到 GameProject/assets/<类别>/
  → Godot 生成 .import
  → 场景或表现脚本以 res://assets/... 引用
```

- `ArtAsset/` 是源素材库，不允许被 Godot 工程直接引用。
- `Experimental/` 用于生成图集、截图和临时试验，不进入 git，也不被运行时引用。
- `GameProject/assets/` 是唯一运行时资源目录；素材与对应 `.import` 必须一起提交。
- 逻辑状态保留在 `logic/`；贴图、动画、材质、颜色和粒子只存在于 `scenes/` 与 `assets/`。

## 4. 正式资源目录与绑定

| 类别 | 状态 | 运行时资源 | 配置/绑定位置 |
| --- | --- | --- | --- |
| 草甸地形 | 已配置 | `assets/terrain/ground_*_crisp.webp`、`assets/ground_visual.gdshader`、`ground_visual_material.tres` | `scenes/game/meadow_level.tscn` |
| 环境装饰 | 已配置 | `assets/environment/*.png` | `scenes/game/meadow_decor.gd`、`meadow_level.tscn` |
| 玩家 | 已配置（回退保留） | `assets/sprites/player/player_static.png`；旧 `idle/walk_*.png` | `scenes/game/player_view.gd/.tscn` |
| 七类敌人与 Boss | 已配置 | `assets/sprites/enemies/*.png` | `scenes/art_catalog.gd`、`scenes/game/world_art_view.gd` |
| 六武器与弹道 | 已配置 | `assets/icons/weapon_*.png`、`projectile_*.png` | `art_catalog.gd`、`world_art_view.gd`、`game_overlay.gd` |
| 掉落与稀有物 | 已配置 | `assets/icons/pickup_*.png`、`rare_*.png` | `art_catalog.gd`、`world_art_view.gd`、`game_overlay.gd` |
| 召唤物与任务 | 已配置 | `assets/icons/summon_*.png`、`task_*.png` | `art_catalog.gd`、`world_art_view.gd`、`game_overlay.gd` |
| 战斗 VFX | 已配置 | `assets/vfx/*.png` | `art_catalog.gd`、`world_art_view.gd` |
| 现代 Q 版 UI 图形 | 已配置 | `assets/ui/modern/*.svg`、`*.png`（13 类）与统一圆章绘制 | `art_catalog.gd`、`game_overlay.gd`、`meta_screens.gd`、`debug_overlay.gd` |
| 品牌吉祥物 | 已配置 | `assets/ui/modern/brand_mascot.png` | `scenes/ui/meta_screens.gd` |
| 中文字体 | 已配置 | `assets/fonts/noto_sans_sc.ttf`、`OFL.txt` | `game_overlay.gd`、`meta_screens.tscn` |
| Debug Runtime/Overlay | 已配置 | Godot Control | `logic/debug_runtime.gd`、`scenes/game/debug_overlay.gd/.tscn` |

统一资源表：`scenes/art_catalog.gd`。它集中预载敌人、武器、弹道、掉落、稀有物、召唤、任务、VFX、环境和 UI ornament，避免各表现脚本散落硬编码路径。

## 5. 主场景表现结构

正式主场景顺序为：

1. `MeadowLevel`：地形材质、地图装饰和边界背景。
2. `WorldArtView`：全部世界实体、战斗状态和特效。
3. `PlayerView`：正式玩家贴图与程序化状态反馈。
4. `GameOverlay`：HUD、卡牌和局流程模态界面。
5. `MetaScreens` / `DebugOverlay`：局外 UI 与调试界面。

`scenes/game/placeholder_world_view.gd` 仅保留为开发回退，不再被 `scenes/main.tscn` 正式引用。

草甸地形使用四张 2048×2048 无缝锐化 WebP，通过文本 Shader 以局部地形坐标混合草地、浅径、泥地和苔石；开启 mipmap 与各向异性线性过滤，避免大地图拉伸造成的模糊，同时消除旧 VisualShader 混合链失效与 UV 分块问题。

## 6. 世界资源覆盖

| 对象/系统 | 状态 | 当前正式表现 |
| --- | --- | --- |
| chaser / enhancedChaser / charger / ranged / bomber / shield | 已配置 | 独立敌人贴图、朝向、受击/冰冻/DoT 状态、血条 |
| Boss | 已配置 | 专用贴图、Boss 尺寸、狂暴光效、血条与 HUD medallion |
| 玩家与敌方弹道 | 已配置 | 按武器/阵营映射正式弹道资源，并保留轨迹与危险提示 |
| 经验、血包、五种稀有物 | 已配置 | 独立图标、拾取光效和 HUD/结算图标复用 |
| 普通/尸体/护法/鬼火召唤 | 已配置 | 独立召唤图标与状态光效 |
| 披风、玉环、丹火、法杖 | 已配置 | 范围、轨迹、爆发、灵弹和命中 VFX |
| 任务信标与任务区域 | 已配置 | guard/delivery/bounty 正式图标、信标 VFX 与世界提示 |
| 联动与通用战斗效果 | 已配置 | 电弧、焚烧、冻结、毒雾、诅咒、治疗、爆炸、拾取和冲击效果 |
| 环境 | 已配置 | 桃树、岩石、边界石、石柱、神龛、灯笼、灌木、草丛、野花、落花 |

## 7. UI 完成状态

| 界面 | 状态 | 正式化内容 |
| --- | --- | --- |
| 基础 HUD | 已配置 | 现代圆角玩家卡、波次卡、讨妖簿、六格法器 Dock、Boss、任务、稀有物与统计；武器/任务/掉落统一使用深褐描边、奶油内底、主题色外圈与软阴影圆章 |
| 开局/升级/任务奖励卡牌 | 已配置 | 大尺寸圆角卡、类型色边框、图标圆章、胶囊 CTA、焦点光标、悬停反馈、中文字体和快捷键提示 |
| 撤离、死亡、结算 | 已配置 | medallion、按钮 crest、收益/损失汇总和键鼠操作提示 |
| 主菜单 | 已配置 | 吉祥物 Header、暗晶卡、桃源战绩胶囊、三张功能卡与珊瑚主按钮，包含完整 normal/hover/pressed/focus/disabled 状态 |
| 商城/仓库 | 已配置 | 现代 medallion、圆角列表卡、动态行图标、购买/出售状态和中文字体 |
| Boss/任务提示 | 已配置 | Boss medallion、Boss 条、任务正式图标、世界信标与 HUD 卡片 |
| Debug Overlay | 已配置 | 薄荷胶囊入口、奶油白圆角控制台、珊瑚标题与统一输入控件；保留自动暂停/恢复、F2/Esc/遮罩关闭及全部调试能力 |

## 8. 已配置但可继续升级

### 8.1 玩家动画

主游戏已恢复 `AnimatedSprite2D` 动画管线，由 `player_sprite_frames.gd` 构建 SpriteFrames，并由 `player_view.gd` 驱动 Idle、Move、Dead 三态。移动状态覆盖八方向：右、右上、上、左上、左、左下、下、右下；正左方向镜像右向动画，左上/左下继续使用独立图集。世界暂停时动画同步暂停，死亡时停止并灰化。

`player_static.png` 仍作为动画资源缺失时的安全回退，不再覆盖正常 SpriteFrames。`player_animation_preview.tscn` 可用于独立检查图集，正式运行以主场景中的 PlayerView 状态机为准。

### 8.2 地形材质

- 节点图：`assets/ground_visual_shader.tres`。
- 材质参数：`assets/ground_visual_material.tres`。
- 独立预览：`scenes/game/art_ground_preview.tscn`，打开后按 `F6`。
- `Polygon2D.texture` 和 2048×2048 像素 UV 必须保留，否则 Godot 4.7.1 会向 CanvasItem Shader 传递全零 UV，地形会退化成单色。

## 9. 尚未完成的正式资源

| 类别 | 未完成内容 | 后续入口 |
| --- | --- | --- |
| 音频 | BGM、武器 SFX、受击、掉落、UI、Boss 音效 | 新增 `assets/audio/` 和独立音频表现层 |
| 可选动画升级 | 敌人/Boss 更完整的移动、攻击和死亡序列；继续提升玩家现有逐帧图集的帧间连贯性 | 复用现有 PlayerView/WorldArtView 状态映射 |
| 性能表现 | 实体视图对象池、VFX 预算、140 敌人压力下的降级策略 | M6 性能任务 |

## 10. 预览与验证入口

| 目标 | 场景/命令 | 运行方式 |
| --- | --- | --- |
| 当前完整游戏 | `scenes/main.tscn` | Godot 中按 `F5` |
| 地形材质 | `scenes/game/art_ground_preview.tscn` | 打开后按 `F6` |
| 玩家动画独立预览 | `scenes/game/player_animation_preview.tscn` | 打开后按 `F6`；主游戏已使用同一 SpriteFrames 管线 |
| 正式 Meta UI | `scenes/ui/meta_screens.tscn` | 已挂入主游戏，可单独检查布局 |
| Godot smoke | `res://tools/run_smoke.gd` | `Godot --headless --path GameProject --script res://tools/run_smoke.gd` |
| 当前分支全量回归 | Godot import + Godot smoke + `npm run smoke` | 从仓库根目录分别运行；当前 `main` 未包含规则中提到的 `verify.ps1` |

## 11. 资源完成判定

一项资源只有同时满足以下条件，才能标记为“已配置”：

- 定稿文件已进入 `GameProject/assets/`。
- 对应 `.import` 已生成并准备提交。
- 正式表现节点已经绑定资源。
- 关键状态有可读反馈，且程序化回退不会覆盖正式贴图。
- 主场景已人工验证键盘、鼠标、HUD、暂停、死亡和重开流程。
- Godot smoke 与原型 smoke 均无回归。
