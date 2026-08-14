# Godot 美术资源配置台账

> 最后核对：2026-08-14
>
> 适用工程：`GameProject/`（Godot 4.7.1）
>
> 用途：统一记录正式资源、待修订资源、未配置资源和临时占位符。玩法进度仍以 `PROGRESS.md` 为唯一真值。

## 1. 状态定义

| 状态 | 含义 |
| --- | --- |
| 已配置 | 资源已进入 `GameProject/assets/`，已绑定正式场景或表现节点，并可在主游戏中看到 |
| 已配置（开发工具） | 仅用于预览、导入或生成，不直接参与主游戏 |
| 待修订 | 管线和绑定已完成，但源素材、帧间连贯性、尺寸或最终品质仍需调整 |
| 未配置 | 玩法逻辑存在，但没有正式美术资源或正式表现节点 |
| 占位 | 当前由颜色、几何图形、文字或默认控件保证玩法可读性 |

## 2. 当前总体进度

- 工程里程碑：M0–M5 完成，M6 进行中，完成度 `6 / 7`。
- Godot smoke：`23 / 23` 章节已全部移植，最新回归为 340 项检查全绿。
- 正式关卡：4096×4096 草甸地形已挂入主场景，并启用确定性地图边界。
- 正式角色表现：玩家八方向状态机和 SpriteFrames 管线已接入。
- 正式 UI：HUD、卡牌、菜单、商城、仓库、撤离、死亡、结算与 F2 Debug Overlay 已接入。
- 当前主要美术缺口：玩家源序列帧修订、七类敌人、六武器及技能表现、掉落与召唤物、任务与联动特效、音频和字体。

## 3. 资源流向约定

```text
ArtAsset/ 或 Experimental/
  → 选定定稿
  → 复制到 GameProject/assets/<类别>/
  → Godot 生成 .import
  → 场景或表现脚本以 res://assets/... 引用
```

- `ArtAsset/` 是源素材库，不允许被 Godot 工程直接引用。
- `GameProject/assets/` 是运行时资源目录。
- 素材与对应 `.import` 必须一起提交。
- 逻辑状态保留在 `logic/`；贴图、动画、材质、颜色和粒子只存在于 `scenes/` 与 `assets/`。

## 4. 已配置并接入主游戏

| 系统 | 状态 | 运行时资源 | 配置/绑定位置 | 备注 |
| --- | --- | --- | --- | --- |
| 草甸地形 | 已配置 | `assets/ground_*.png` | `scenes/game/meadow_level.tscn` | 已挂入 `scenes/main.tscn` |
| 地形节点式材质 | 已配置 | `assets/ground_visual_shader.tres`、`assets/ground_visual_material.tres` | `meadow_level.tscn/MeadowLevel/Ground` | 6 张贴图通过 VisualShader 混合 |
| 地图边界 | 已配置 | 无外部美术资源 | `logic/level_geometry.gd` | 约束玩家、敌人、弹道、相机、刷怪点和任务点 |
| 玩家表现管线 | 已配置 | `assets/sprites/player/*.png`、移动动画 JSON | `scenes/game/player_sprite_frames.gd`、`player_view.gd`、`player_view.tscn` | 管线正确，源帧质量仍为“待修订” |
| 主场景表现分层 | 已配置 | 场景资源 | `scenes/main.tscn`、`scenes/game/game_view.gd` | 顺序为地形、世界占位、玩家、HUD |
| 集中式占位框架 | 已配置 | 无外部美术资源 | `scenes/game/placeholder_world_view.gd` | 所有未完成世界表现统一收口 |
| 主菜单标题徽记 | 已配置 | `assets/ui/title_emblem.png` | `scenes/ui/meta_screens.tscn` | 使用 GPT Image 2 生成，准确中文标题 |
| HUD/卡牌/状态界面 | 已配置 | Godot 绘制 API | `scenes/game/game_overlay.gd` | 经验、生命、武器、Boss、任务、卡牌与局流程界面 |
| 主菜单/商城/仓库 | 已配置 | 标题徽记 + Godot Control | `scenes/ui/meta_screens.gd/.tscn` | 已挂入 `main.tscn`，支持完整鼠标交互 |
| Debug Runtime/Overlay | 已配置 | Godot Control | `logic/debug_runtime.gd`、`scenes/game/debug_overlay.gd/.tscn` | F2 开启，支持倍率、波次、刷怪、武器和配置存取 |

## 5. 已配置但仍需修订或整合

### 5.1 玩家源序列帧

| 项目 | 当前配置 | 后续修改位置 |
| --- | --- | --- |
| Idle | `idle.png`，6×6、36 帧、12 FPS | `assets/sprites/player/idle.png`、`player_sprite_frames.gd::IDLE_FPS` |
| 八方向移动 | 7 组 PNG + JSON；左右正方向共用并镜像 | `assets/sprites/player/`、`MOVE_ANIMATIONS`、`MOVE_FPS` |
| 显示尺寸 | Idle 与移动使用独立缩放 | `player_view.gd::IDLE_SCALE / WALK_SCALE` |
| 脚底对齐 | 统一脚底偏移 | `player_view.gd::SPRITE_FOOT_OFFSET` |
| 当前问题 | 部分源帧画面或帧间连贯性不理想 | 直接替换对应 PNG/JSON；方向映射和状态机无需重写 |

预览入口：`scenes/game/player_animation_preview.tscn`，打开后按 `F6`。

### 5.2 地形材质

| 参数 | 位置 | 用途 |
| --- | --- | --- |
| `terrain_scale` | `assets/ground_visual_material.tres` | 贴图采样缩放 |
| `macro_scale` | 同上 | 宏观区域分布密度 |
| `dirt_amount` | 同上 | 泥地区域比例 |
| `stone_amount` | 同上 | 石地区域比例 |
| `terrain_tint` | 同上 | 整体色调 |
| `tint_strength` | 同上 | 色调混合强度 |

- 节点图：`assets/ground_visual_shader.tres`。
- 独立预览：`scenes/game/art_ground_preview.tscn`，打开后按 `F6`。
- `Polygon2D.texture` 和 2048×2048 像素 UV 必须保留，否则 Godot 4.7.1 会向 CanvasItem Shader 传递全零 UV，地形退化成单色。
- `tools/create_ground_visual_shader.gd` 会覆盖节点图和材质实例。手工修改节点图后不要再次运行，除非需要恢复生成版本。

### 5.3 Meta UI

| 项目 | 状态 | 配置位置 | 缺口 |
| --- | --- | --- | --- |
| 商城/仓库/任务数据接口 | 已配置 | `scenes/ui/meta_screens.gd` | 已绑定逻辑接口与动态行项目 |
| Meta UI 正式场景 | 已配置 | `scenes/ui/meta_screens.tscn` | 已挂入 `main.tscn`，使用东方幻想主题控件 |

## 6. 当前占位符清单

占位实现集中在 `scenes/game/placeholder_world_view.gd`。正式资源到位前必须保留，确保玩法机制可见且可测试。

| 对象/系统 | 当前占位方式 | 正式资源状态 | 后续替换建议 |
| --- | --- | --- | --- |
| chaser | 红色圆形 + “追” | 未配置 | 独立 EnemyView、移动/受击/死亡动画 |
| enhancedChaser | 深红菱形 + “强” | 未配置 | 狂暴预警与狂暴动画 |
| charger | 橙色箭头形 + “冲” | 未配置 | 蓄力、冲刺、恢复动画 |
| ranged | 紫色方形 + “远” | 未配置 | 瞄准、射击动画 |
| bomber | 黄色六边形 + “爆” | 未配置 | 引爆预警与爆炸动画 |
| shield | 灰蓝圆形/盾弧 + “盾” | 未配置 | 盾态、开放态切换动画 |
| boss | 紫色八边形/金环 + “王” | 未配置 | Boss 移动、蓄力、弹幕、狂暴状态机 |
| 敌人血条/状态 | 几何血条、圆环和状态点 | 占位 | 专用状态组件、受击闪白和状态材质 |
| 玩家弹道 | 线段、圆形、菱形 | 未配置 | 按武器类型建立 ProjectileView |
| 敌方弹道 | 橙色圆与描边 | 未配置 | 普通弹、Boss 弹、狂暴弹材质 |
| 经验宝石 | 彩色菱形 | 未配置 | 分档宝石精灵与吸附拖尾 |
| 血包 | 红色圆形白十字 | 未配置 | 拾取动画与提示特效 |
| 五种稀有掉落 | 彩色六边形 | 未配置 | 每种独立图标、地面光柱和拾取特效 |
| 死灵召唤物/尸体召唤 | 紫色五边形 | 未配置 | 普通召唤、尸体召唤及退场动画 |
| 披风范围/冲击 | 半透明圆和圆弧 | 占位 | 范围材质、火焰边缘和震荡波 |
| 玉环 | 小圆与描边 | 未配置 | 玉环精灵、轨迹、充能和护法状态 |
| 丹火轨迹 | 半透明圆和轮廓 | 占位 | 火焰/焦痕材质 |
| 丹炉/热域/切炉 | 多边形、线段 | 占位 | 炉域材质、开炉、热域和切割特效 |
| 任务信标/守卫/运送点 | 圆环与文字 | 占位 | 信标场景、方向指示、任务区域材质 |
| 联动电弧/焚刃/号令 | 线段、圆弧、多边形 | 占位 | 每组 Build 的独立 VFX |
| 通用爆炸/范围效果 | 圆弧 | 占位 | 粒子、扭曲、闪光和地面残留 |

## 7. 未配置的正式资源

| 类别 | 未配置内容 | 计划入口 |
| --- | --- | --- |
| 环境组件 | 树木、独立岩石、灌木、边界装饰、可碰撞障碍 | `scenes/game/` 新建组件；障碍同步登记到 `logic/level_geometry.gd` |
| 七类敌人 | 正式精灵、动画、状态材质和死亡表现 | 建议新增 `enemy_view.gd` + 类型资源表 |
| 六武器 | 武器图标、攻击精灵、轨迹、范围材质 | 建议新增 `assets/sprites/weapons/`、`assets/effects/weapons/` |
| Boss | 专用精灵、蓄力、弹幕、狂暴和死亡演出 | 建议新增 `boss_view.gd` 或独立 Boss 场景 |
| 弹道 | 玩家六武器弹道与敌方弹道正式资源 | 建议新增对象池化 ProjectileView |
| 掉落 | 宝石、血包、五种稀有物正式资源 | 建议新增 PickupView |
| 召唤物 | 普通召唤、尸体召唤、护法玉和鬼火 | 建议新增 SummonView |
| VFX | 受击、爆炸、冻结、减速、DoT、15 组联动 | 建议新增 `assets/effects/` 与统一 EffectView |
| 字体 | 中文 UI 字体、数字字体、标题字体 | `assets/fonts/`；当前使用 Godot fallback font |
| 音频 | BGM、武器 SFX、受击、掉落、UI、Boss 音效 | `assets/audio/`；当前无正式音频文件 |
| 性能表现 | 实体视图对象池、粒子预算、140 敌人压力下的降级策略 | M6 性能任务 |

## 8. UI 当前状态

| 界面 | 当前状态 | 表现方式 |
| --- | --- | --- |
| 基础 HUD | 已配置 | 东方幻想面板；经验、生命、武器槽、波次、Boss、任务、掉落与统计完整显示 |
| 主菜单 | 已配置 | GPT Image 2 标题徽记 + 主题化 Control 按钮与局外统计 |
| 开局/升级/任务奖励选卡 | 已配置 | 类型配色、符印、等级信息、描述、悬停和数字键提示 |
| 撤离、死亡、结算 | 已配置 | 主题化模态面板、损失/收益汇总与按键操作提示 |
| 商城/仓库 | 已配置 | 正式挂载 `meta_screens.tscn`；支持购买、单项出售、全部出售和返回 |
| Boss/任务提示 | 已配置 | HUD 专用 Boss 条与任务卡；世界位置继续由 PlaceholderWorld 标记 |
| Debug Overlay | 已配置 | F2 面板；暂停、无敌、玩家/敌人/刷怪倍率、波次、武器、生成和配置存取 |

## 9. 预览入口

| 目标 | 场景 | 运行方式 |
| --- | --- | --- |
| 当前完整游戏 | `scenes/main.tscn` | `F5` |
| 地形材质 | `scenes/game/art_ground_preview.tscn` | 打开场景后按 `F6` |
| 玩家八方向动画 | `scenes/game/player_animation_preview.tscn` | 打开场景后按 `F6` |
| 正式 Meta UI | `scenes/ui/meta_screens.tscn` | 已挂入主游戏；可单独打开检查布局 |
| Debug Overlay | `scenes/game/debug_overlay.tscn` | 主游戏中按 `F2` |

## 10. 正式资源替换流程

1. 在本台账中找到对应的“占位”或“未配置”项目。
2. 将源素材放入 `ArtAsset/` 对应分类。
3. 复制定稿到 `GameProject/assets/<类别>/`，使用小写 ASCII、snake_case 命名。
4. 在独立预览场景验证尺寸、锚点、帧率、材质参数和透明边缘。
5. 新建或更新 `scenes/` 表现节点，只读取 `logic/` 状态。
6. 保留占位绘制作为回退，确认正式视图覆盖完整状态后再移除对应分支。
7. 运行 Godot smoke 与 `npm run smoke`。
8. 更新本台账状态和 `PROGRESS.md` M6 进度。

## 11. 资源完成判定

一项资源只有同时满足以下条件，才能从“占位/未配置”改为“已配置”：

- 定稿文件已进入 `GameProject/assets/`。
- `.import` 已生成并准备提交。
- 正式表现节点已绑定资源。
- 关键状态均有对应表现。
- 独立预览或主场景已人工验证。
- Godot smoke 与原型 smoke 均无回归。
