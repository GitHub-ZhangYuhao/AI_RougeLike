# Godot 静态美术资源与地形重制记录

> 实施日期：2026-08-16  
> 适用工程：`GameProject/`（Godot 4.7.1）  
> 范围：静态图片、世界实体贴图、单帧 VFX、现代 UI 装饰和正式地形。视频、序列帧动画及其他动态资源不在本轮范围内。

## 1. 本轮目标

本轮先处理 Godot 游戏中未配置、仍在复用 UI 图标、使用程序化占位绘制或画面质量不足的静态图片资源，并重做正式关卡地表。目标包括：

1. 将世界中的经验宝石、召唤物、武器实体和骷髅尸体替换为独立正式图片。
2. 替换第一代低容量、占位感较强的单帧战斗 VFX。
3. 提升 `ui/modern/` 中徽章、印章、卡角和焦点光标的静态品质。
4. 舍弃旧的重复平铺噪声地表，将选定的 Q 版夜晚方案“琥珀星光圣地”接入正式关卡。
5. 保留动态 VFX、角色补帧和视频资源，后续单独立项，避免静态资源阶段扩大修改范围。

## 2. 正式地形：琥珀星光圣地

### 2.1 视觉方向

地形根据 `Experimental/TerrainReference/My Reference/` 中的参考图提取以下要素：

- Q 版、可爱、俯视角游戏构图；
- 青蓝色夜晚森林作为外围边界；
- 中央保留大面积明亮草地，保证玩家、敌人、弹道和掉落物的战斗辨识度；
- 左上配置池塘，顶部配置月牙石阵和暖光视觉焦点；
- 使用少量暖橙树冠打破大面积冷色，但不占据中央战斗区域；
- 地表使用手绘草叶、花簇和明暗变化，不再依赖纯程序噪声。

### 2.2 运行时资源

正式贴图：

```text
GameProject/assets/terrain/amber_starlight_sanctuary_2048.png
GameProject/assets/terrain/amber_starlight_sanctuary_2048.png.import
```

源概念图保存在被忽略的实验目录：

```text
Experimental/TerrainReference/GeneratedConcept/MyReferenceStudy/concept_03_amber_starlight_2048.png
```

### 2.3 Godot 接入方式

正式关卡由 `GameProject/scenes/game/meadow_level.tscn` 加载整张地图：

- 世界范围：`-2048..2048`，即 4096×4096 Godot 世界单位；
- `Polygon2D` 使用四个顶点覆盖完整关卡；
- UV 使用原图 `0..2048` 像素坐标；
- `texture_repeat = 1`，禁止重复平铺；
- 不再引用旧 `ground_visual_material.tres` 或地形 Shader；
- `meadow_decor.gd` 的 `SHOW_LEGACY_DECOR` 设为 `false`，避免旧桃树、神龛、石块和新地图中的烘焙景物重复叠加。

整体预览入口：

```text
GameProject/scenes/game/art_ground_preview.tscn
```

预览默认缩放为 `0.18`，方向键移动，滚轮缩放，`R` 重置视角。

### 2.4 保留但未启用的地形实验

以下资源作为早期 4×4 平铺/Shader 方案和差异对照保留在仓库中，但正式场景不再引用：

```text
GameProject/assets/terrain/ground_surface.gdshader
GameProject/assets/terrain/ground_surface.gdshader.uid
GameProject/assets/terrain/ground_surface_material.tres
GameProject/assets/terrain/night_meadow_ground_1024.png
GameProject/assets/terrain/night_meadow_ground_1024.png.import
ArtAsset/Image/Terrain/GroundRefresh/
```

## 3. 世界实体静态图片升级

### 3.1 经验宝石

`GameProject/assets/icons/pickup_gem.png` 已重新制作，并正式绑定到 `world_art_view.gd` 的世界掉落绘制。程序绘制仅保留阴影、光晕和磁吸反馈，不再用多层圆形模拟宝石主体。

### 3.2 武器世界贴图

新增：

```text
GameProject/assets/sprites/weapons/jade_ring_world.png
```

轨道玉环使用独立世界贴图，不再直接复用 HUD 武器图标。

### 3.3 召唤物与尸体

新增：

```text
GameProject/assets/sprites/summons/jade_guard_world.png
GameProject/assets/sprites/summons/wisp_world.png
GameProject/assets/vfx/skeleton_minion_corpse.png
```

玉卫、鬼火和骷髅尸体均改用独立构图；骷髅尸体不再与存活召唤物共用同一视觉状态。

对应源资源归档在：

```text
ArtAsset/Image/WorldSprites/StaticRefresh/
```

## 4. 单帧战斗 VFX 升级

以下 16 张运行时资源已替换为统一的 384×384 RGBA 手绘图片，并沿用原有资源键和调用路径：

| 文件 | 用途 |
| --- | --- |
| `sword_slash.png` | 道剑斩击 |
| `talisman_lightning.png` | 雷符落雷 |
| `cloak_fire_burst.png` | 披风火焰爆发 |
| `staff_spirit_bolt.png` | 法杖灵弹 |
| `synergy_arc.png` | 协同弧线 |
| `impact_flash.png` | 通用命中闪光 |
| `explosion.png` | 爆炸 |
| `freeze_burst.png` | 冰冻爆裂 |
| `poison_mist.png` | 毒雾 |
| `dot_curse.png` | 诅咒持续伤害 |
| `healing_petals.png` | 治疗花瓣 |
| `pickup_glow.png` | 拾取发光 |
| `boss_enraged.png` | Boss 狂暴 |
| `furnace_flame.png` | 丹火 |
| `jade_ring_trail.png` | 玉环拖尾 |
| `task_beacon.png` | 任务信标 |

运行时目录：

```text
GameProject/assets/vfx/
```

源图和组合图集：

```text
ArtAsset/Image/VFX/StaticRefresh/
```

本轮只升级静态单帧图片。闪电链动画、弹道动态拖尾、敌人攻击/受击/死亡补帧等动态资源继续保留为后续任务。

## 5. 现代 UI 静态装饰升级

`GameProject/assets/ui/modern/` 中以下 11 张资源已替换为细节更完整的手绘版本：

```text
button_crest.png
focus_cursor.png
medallion_boss.png
medallion_pause.png
medallion_shop.png
medallion_warehouse.png
panel_corner.png
seal_attribute.png
seal_blessing.png
seal_task.png
seal_weapon.png
```

原有 `ArtCatalog.UI_TEXTURES` 键保持不变，界面代码无需改变资源调用协议。源文件归档在：

```text
ArtAsset/Image/UI/StaticRefresh/final/
```

横向分隔装饰未在本轮强行替换，以免方形生成图被布局拉伸后破坏界面比例。

## 6. 敌人风格探索资源

本轮同时归档了两组敌人方向探索图：

```text
ArtAsset/Image/Enemy/StyleExploration/v02_clean_animation/
ArtAsset/Image/Enemy/StyleExploration/v03_role_readability/
```

这些图片用于后续确定敌人轮廓、职业辨识度和动画清洁度，目前没有直接接入 Godot 正式运行时。

## 7. 代码和测试调整

涉及的主要代码与配置：

```text
GameProject/scenes/art_catalog.gd
GameProject/scenes/game/world_art_view.gd
GameProject/scenes/game/meadow_level.tscn
GameProject/scenes/game/meadow_decor.gd
GameProject/scenes/game/art_ground_preview.tscn
GameProject/scenes/game/art_ground_preview.gd
GameProject/tests/scenarios/s00_weapon_cards.gd
GameProject/ART_ASSET_CONFIG.md
GameProject/OPTIMIZATION_TRACKER.md
GameProject/PROGRESS.md
```

资源绑定继续集中在 `ArtCatalog`，世界表现继续由 `WorldArtView` 读取纯逻辑运行状态；本轮没有将图片或碰撞规则写入 `logic/`。

## 8. 验证记录

2026-08-16 已执行：

```powershell
GameEngine\Godot.exe --headless --path GameProject --import
GameEngine\Godot.exe --headless --path GameProject --script res://tools/run_smoke.gd
npm run smoke
```

结果：

- Godot 资源导入成功；
- Godot headless smoke 退出码为 0；
- HTML5 原型全部 smoke 章节通过；
- 整体地图预览通过；
- 中央战斗区域实机截图通过；
- 左上和右下地图边缘均未露出底色；
- 新地形没有 4×4 重复块；
- 旧环境装饰没有重复叠加。

本地验收截图位于被忽略的实验目录：

```text
Experimental/TerrainReference/Validation/amber_starlight_preview.png
Experimental/TerrainReference/Validation/amber_starlight_gameplay.png
Experimental/TerrainReference/Validation/amber_starlight_edge_top_left.png
Experimental/TerrainReference/Validation/amber_starlight_edge_bottom_right.png
```

## 9. 已知限制和后续工作

1. 池塘、树林、石头和月牙石阵目前烘焙在背景图中，不包含物理碰撞；玩家可以进入这些看似不可通行的区域。
2. 若需要阻挡区域，应单独设计确定性的关卡逻辑边界，不应直接在美术场景中加入 Godot 物理碰撞并绕过 `logic/level_geometry.gd`。
3. 中央草地为了战斗辨识度比外围森林明亮；如果最终希望更深夜，可在不降低实体辨识度的前提下统一压暗中间调。
4. 正式动态 VFX、敌人和 Boss 攻击/受击/死亡动画、玩家动画连贯性、视频资源和音频资源均不在本轮交付范围内。
5. 保留的旧地形实验资源当前没有运行时引用，后续确认不再需要时可另开清理提交。

## 10. 验收清单

- [ ] Q 版俯视角和夜晚森林风格符合目标。
- [ ] 中央青绿色草地的亮度适合长时间战斗。
- [ ] 左上池塘和顶部月牙石阵构图符合预期。
- [ ] 暖橙树冠没有抢夺玩家、敌人和弹道信息。
- [ ] 世界经验宝石、玉环、玉卫、鬼火和骷髅尸体均显示独立图片。
- [ ] 单帧攻击、状态和任务 VFX 没有明显占位感。
- [ ] 现代 UI 徽章、印章、卡角和焦点光标风格统一。
- [ ] 地图移动到四周边缘时不露底。
- [ ] 确认是否需要为池塘和森林增加逻辑阻挡区域。
