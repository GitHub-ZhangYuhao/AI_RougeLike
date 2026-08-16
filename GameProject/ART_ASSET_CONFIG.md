# Godot 美术资源配置台账

> 最后核对：2026-08-16
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
- Godot smoke：`23 / 23` 章节已全部移植，最新本地回归为 `359` 项检查全绿。
- 正式关卡：4096×4096 草甸地形、确定性地图边界和环境装饰均已挂入主场景。
- 正式世界表现：`WorldArtView` 已取代 `PlaceholderWorld`，接管敌人、Boss、弹道、掉落、召唤物、任务信标、武器范围与战斗 VFX。
- 正式玩家表现：主游戏已恢复 `AnimatedSprite2D` 的 Idle / Move / Dead 八方向动画状态机，`player_static.png` 仅作为资源缺失时的回退。
- 正式 UI：主菜单已切换为批准的桃夜巡 B+A 视觉稿；局内 HUD 与开局/升级卡牌使用桃夜巡原子资源动态拼装，商城、仓库、模态框与 Debug 保留现代 Q 版组件体系，并完成焦点/悬停/按下/禁用状态。
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
| 草甸地形 | 已配置（方案 3） | `assets/terrain/amber_starlight_sanctuary_2048.png` | `scenes/game/meadow_level.tscn` |
| 环境装饰 | 已配置（烘焙进整体地图） | `assets/terrain/amber_starlight_sanctuary_2048.png`；旧 `assets/environment/*.png` 保留回退 | `scenes/game/meadow_level.tscn`、`meadow_decor.gd` |
| 玩家 | 已配置（回退保留） | `assets/sprites/player/player_static.png`；旧 `idle/walk_*.png` | `scenes/game/player_view.gd/.tscn` |
| 七类敌人与 Boss | 已配置 | `assets/sprites/enemies/*.png` | `scenes/art_catalog.gd`、`scenes/game/world_art_view.gd` |
| 六武器与弹道 | 已配置 | `assets/icons/weapon_*.png`、`projectile_*.png`、`assets/sprites/weapons/jade_ring_world.png` | `art_catalog.gd`、`world_art_view.gd`、`game_overlay.gd` |
| 掉落与稀有物 | 已配置 | `assets/icons/pickup_*.png`、`rare_*.png`；经验宝石已作为世界贴图使用 | `art_catalog.gd`、`world_art_view.gd`、`game_overlay.gd` |
| 召唤物与任务 | 已配置 | `assets/sprites/summons/*.png`、`assets/vfx/skeleton_minion*.png`、`assets/icons/task_*.png` | `art_catalog.gd`、`world_art_view.gd`、`game_overlay.gd` |
| 战斗 VFX | 已配置 | `assets/vfx/*.png`；16 张第一代单帧 VFX 已替换为 384×384 RGBA 手绘图片 | `art_catalog.gd`、`world_art_view.gd` |
| 现代 Q 版 UI 图形 | 已配置 | `assets/ui/modern/*.png`（13 类）；11 张徽章/印章/卡角已升级为精细手绘版 | `art_catalog.gd`、`meta_screens.gd`、`debug_overlay.gd` |
| 桃夜巡主菜单 | 已配置 | `assets/ui/peach_night/menu_bg_exact.png`、三类按钮切片 | `scenes/ui/peach_night_menu.gd`、`meta_screens.gd` |
| 桃夜巡局内原子 UI | 已配置 | `assets/ui/peach_night/atomic/` 的背板、边框、头像、状态条、图标、花饰、法器槽、标签和纸张纹理 | `scenes/game/game_overlay.gd`、`logic/ui_layout.gd` |
| 品牌吉祥物 | 已配置（回退保留） | `assets/ui/modern/brand_mascot.png` | `scenes/ui/meta_screens.gd` 的非桃夜巡界面 |
| 中文字体 | 已配置 | `assets/fonts/noto_sans_sc.ttf`、`OFL.txt` | `game_overlay.gd`、`meta_screens.tscn` |
| Debug Runtime/Overlay | 已配置 | Godot Control | `logic/debug_runtime.gd`、`scenes/game/debug_overlay.gd/.tscn` |

统一资源表：`scenes/art_catalog.gd`。它集中预载敌人、武器、弹道、掉落、稀有物、召唤、任务、VFX、环境和 UI ornament，避免各表现脚本散落硬编码路径。

## 5. 主场景表现结构

正式主场景顺序为：

1. `MeadowLevel`：琥珀星光圣地整体地图与边界背景。
2. `WorldArtView`：全部世界实体、战斗状态和特效。
3. `PlayerView`：正式玩家贴图与程序化状态反馈。
4. `GameOverlay`：HUD、卡牌和局流程模态界面。
5. `MetaScreens` / `DebugOverlay`：局外 UI 与调试界面。

`scenes/game/placeholder_world_view.gd` 仅保留为开发回退，不再被 `scenes/main.tscn` 正式引用。

草甸地形已改为方案 3「琥珀星光圣地」整体构图：一张 2048×2048 Q 版夜晚地图覆盖 4096×4096 世界，左上池塘、顶部月牙石阵、外围青蓝树林与暖橙树冠均烘焙进同一图片。正式场景不再引用旧地表 Shader，也关闭旧分层装饰绘制，避免重复树木、石块和神龛覆盖整体构图。贴图开启 mipmap 与各向异性线性过滤。

## 6. 世界资源覆盖

| 对象/系统 | 状态 | 当前正式表现 |
| --- | --- | --- |
| chaser / enhancedChaser / charger / ranged / bomber / shield | 已配置 | 独立敌人贴图、朝向、受击/冰冻/DoT 状态、血条 |
| Boss | 已配置 | 专用贴图、Boss 尺寸、狂暴光效、血条与 HUD medallion |
| 玩家与敌方弹道 | 已配置 | 按武器/阵营映射正式弹道资源；轨道玉环已使用独立世界图片，并保留轨迹与危险提示 |
| 经验、血包、五种稀有物 | 已配置 | 经验宝石已绑定正式世界图片；其余对象使用独立图标、拾取光效和 HUD/结算图标 |
| 普通/尸体/护法/鬼火召唤 | 已配置 | 普通骷髅、尸体、玉卫和鬼火均使用独立世界图片，不再复用同一贴图或 UI 图标 |
| 披风、玉环、丹火、法杖 | 已配置 | 范围、轨迹、爆发、灵弹和命中 VFX |
| 任务信标与任务区域 | 已配置 | guard/delivery/bounty 正式图标、信标 VFX 与世界提示 |
| 联动与通用战斗效果 | 已配置 | 电弧、焚烧、冻结、毒雾、诅咒、治疗、爆炸、拾取和冲击效果 |
| 环境 | 已配置 | 桃树、岩石、边界石、石柱、神龛、灯笼、灌木、草丛、野花、落花 |

## 7. UI 完成状态

| 界面 | 状态 | 正式化内容 |
| --- | --- | --- |
| 基础 HUD | 已配置 | 桃夜巡深蓝金边底部壳体由原子资源和程序化面板拼装；头像环、等级、XP/生命/波次、守夜时间、暗晶、暂停、三格法器、首领状态与击破统计分区清晰，法器视觉槽和点击命中区域一致 |
| 开局/升级/任务奖励卡牌 | 已配置 | 桃夜巡宣纸卡由纸张纹理、边框、标题牌、编号、品质签、图标灵火环、等级胶囊、描述板、选择按钮和桃花角饰拼装；六卡开局、三卡升级与 hover 上浮间距已复核 |
| 撤离、死亡、结算 | 已配置 | medallion、按钮 crest、收益/损失汇总和键鼠操作提示 |
| 主菜单 | 已配置 | 按批准的桃夜巡 B+A 稿像素级还原背景、暗晶计数和商城/开始巡守/仓库热区，保留动态数值和交互反馈 |
| 商城/仓库 | 已配置 | 现代 medallion、圆角列表卡、动态行图标、购买/出售状态和中文字体 |
| Boss/任务提示 | 已配置 | Boss medallion、Boss 条、任务正式图标、世界信标与 HUD 卡片 |
| Debug Overlay | 已配置 | 薄荷胶囊入口、奶油白圆角控制台、珊瑚标题与统一输入控件；保留自动暂停/恢复、F2/Esc/遮罩关闭及全部调试能力 |

## 8. 已配置但可继续升级

### 8.1 玩家动画

主游戏已恢复 `AnimatedSprite2D` 动画管线，由 `player_sprite_frames.gd` 构建 SpriteFrames，并由 `player_view.gd` 驱动 Idle、Move、Dead 三态。移动状态覆盖八方向：右、右上、上、左上、左、左下、下、右下；正左方向镜像右向动画，左上/左下继续使用独立图集。世界暂停时动画同步暂停，死亡时停止并灰化。

`player_static.png` 仍作为动画资源缺失时的安全回退，不再覆盖正常 SpriteFrames。`player_animation_preview.tscn` 可用于独立检查图集，正式运行以主场景中的 PlayerView 状态机为准。

### 8.2 整体地形图片

- 正式图片：`assets/terrain/amber_starlight_sanctuary_2048.png`。
- 场景映射：`Polygon2D` 覆盖 `-2048..2048` 世界范围，UV 使用图片原始 `0..2048` 像素坐标，不重复平铺。
- 独立预览：`scenes/game/art_ground_preview.tscn`，打开后按 `F6`；默认缩放可看到完整构图。
- 旧 `ground_surface.gdshader`、`ground_surface_material.tres` 和旧环境原子资源不再被正式地形场景引用，暂时保留作回退和差异对照。

### 8.3 静态图片质量升级

世界经验宝石、玉环、玉卫、鬼火和骷髅尸体均已使用独立世界图片；16 张第一代单帧 VFX 已替换为统一的 384×384 RGBA 手绘资源。`assets/ui/modern/` 中 11 张方形 UI 装饰也已升级为细节更完整的手绘版本；横向 `divider_blossom.png` 因布局用途保留原子切片形态。生成图集和透明单图归档在 `ArtAsset/Image/`，运行时只引用 `GameProject/assets/`。

### 8.4 桃夜巡 UI 原子化约束

局内 HUD 和卡牌禁止使用整张大图覆盖动态内容。运行时以 `assets/ui/peach_night/atomic/` 中的独立切片为基础，由 `game_overlay.gd` 根据当前生命、经验、波次、货币、法器和选卡状态动态拼装；布局命中矩形统一由 `logic/ui_layout.gd` 提供。主菜单因批准稿要求保留整幅背景还原，但按钮与暗晶数值仍以独立交互层覆盖。

## 9. 尚未完成的正式资源

| 类别 | 未完成内容 | 后续入口 |
| --- | --- | --- |
| 音频 | BGM、武器 SFX、受击、掉落、UI、Boss 音效 | 新增 `assets/audio/` 和独立音频表现层 |
| 动态 VFX 与可选动画升级 | 闪电链、弹道拖尾、雷符闪电束的动态材质/序列帧；敌人/Boss 攻击、受击和死亡补帧；玩家逐帧连贯性 | 复用现有 PlayerView/WorldArtView 状态映射，本轮静态图片完成后再单独处理 |
| 视频资源 | 当前没有正式视频资源或视频播放管线 | 后续按剧情、开场或界面需求单独立项 |
| 性能表现 | 实体视图对象池、VFX 预算、140 敌人压力下的降级策略 | M6 性能任务 |

## 10. 预览与验证入口

| 目标 | 场景/命令 | 运行方式 |
| --- | --- | --- |
| 当前完整游戏 | `scenes/main.tscn` | Godot 中按 `F5` |
| 整体地形 | `scenes/game/art_ground_preview.tscn` | 打开后按 `F6` |
| 玩家动画独立预览 | `scenes/game/player_animation_preview.tscn` | 打开后按 `F6`；主游戏已使用同一 SpriteFrames 管线 |
| 正式 Meta UI | `scenes/ui/meta_screens.tscn` | 已挂入主游戏，可单独检查布局 |
| 桃夜巡局内 UI | `scenes/main.tscn` | 已人工复核底部 HUD、法器 hover/选中、六卡开局、三卡升级及卡牌 hover 上浮状态 |
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
