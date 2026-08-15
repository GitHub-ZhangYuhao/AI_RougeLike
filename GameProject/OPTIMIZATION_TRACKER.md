# 优化迭代追踪

## 第一轮优化 (已完成)

| # | 问题 | 状态 | 修改文件 | 说明 |
|---|------|------|----------|------|
| 1 | 最初级的追击兵重新生成被Alpha扣空 | ✅ 完成 | `logic/enemies/enemy_factory.gd` | `enhanced_chaser_ratio()` 上限从1.0改为0.85，保证至少15%普通追击兵权重 |
| 2 | 火焰丹火和炙热披风特效需重新出序列帧 | ✅ 完成 | `assets/vfx/*.png` | 16个VFX贴图通过Python/PIL重新生成(384×384) |
| 3 | 道剑攻击特效太差 | ✅ 完成 | `scenes/game/world_art_view.gd` | 添加近战斩击弧光特效(slash effect) |
| 4 | 盾兵移动方向和蓄力针方向相反 | ✅ 完成 | `scenes/game/world_art_view.gd` | 移除`flip_h = !flip_h`反转，使用标准朝向逻辑 |
| 5 | 地上掉落经验图片 | ✅ 完成 | `scenes/game/world_art_view.gd` | 用多层圆形渲染发光球体(glow+shadow+body+highlight) |
| 6 | Boss状态机需idle和移动精灵图 | ✅ 完成 | `scenes/art_catalog.gd`, `assets/sprites/enemies/` | boss_idle_sheet.png + boss_walk_sheet.png，windup时切换idle |
| 7 | 玩家攻击特效太小太暗 | ✅ 完成 | `scenes/game/world_art_view.gd` | 增大glow半径(0.85→1.4)、impact_size(4.5→8.0)、添加白色内圈 |
| 8 | UI全屏分辨率适配 | ✅ 完成 | `project.godot`, `scenes/game/game_view.gd` | stretch mode="viewport"，ScreenAtmosphere动态resize |

## 第二轮优化 (已完成)

### 问题清单

| # | 问题 | 状态 | 修改文件 | 说明 |
|---|------|------|----------|------|
| 1 | 丹火持续灼烧DOT特效需精灵图动画+提亮 | ✅ 完成 | `world_art_view.gd` + `assets/vfx/burn_dot_effect.png` | 新增`_draw_enemy_dots()`：区分burn/poison，多层火焰动画+精灵图叠加 |
| 2 | 冲撞兵冲撞位置和方向需UI提示 | ✅ 完成 | `world_art_view.gd` + `assets/vfx/charge_indicator.png` | 新增`_draw_charge_indicator()`：windup状态显示方向箭头+警告圈+发光尖端 |
| 3 | 死灵法杖生成的骷髅需重新出美术资源 | ✅ 完成 | `art_catalog.gd` + `assets/vfx/skeleton_minion.png` | SUMMON_TEXTURES的normal/corpse替换为新骷髅精灵图 |
| 4 | 远程兵攻击特效太粗糙 | ✅ 完成 | `world_art_view.gd` + `assets/vfx/hostile_projectile_v2.png` | 增强`_draw_hostile_projectiles()`：多层glow+粗拖尾+能量核心+新贴图 |
| 5 | 道剑二级+攻击特效太粗糙 | ✅ 完成 | `world_art_view.gd` + `assets/vfx/sword_projectile_v2.png` | 增强`_draw_player_projectiles()`：仙气剑光+侧翼wisps+明亮核心+新贴图 |
| 6 | 雷符落雷没有攻击特效 | ✅ 完成 | `world_art_view.gd` + `assets/vfx/thunder_strike.png` | 新增`_draw_talisman_effects()`：渲染bolt_fx(锯齿闪电+分支)+chain_fx(电弧连线) |

### 额外调整

| # | 需求 | 状态 | 修改文件 | 说明 |
|---|------|------|----------|------|
| 7 | 序列帧播放速度提高1.5倍 | ✅ 完成 | `art_catalog.gd` | `ENEMY_SHEET_FPS`: 12.0 → 18.0 |
| 8 | 经验球大小缩小30% | ✅ 完成 | `world_art_view.gd` | `gem_radius`: 12.0 → 8.4 |
| 9 | 摄像机离角色稍远 | ✅ 完成 | `game_view.gd` | `CAMERA_ZOOM`: 1.0 → 0.82 |
| 10 | 局内UI缩小30% | ✅ 完成 | `game_overlay.gd` | 添加`UI_SCALE=0.7`，HUD用`draw_set_transform`缩放 |

## 技术细节

### 第二轮代码变更

#### 1. DOT特效渲染 (`_draw_enemy_dots`)
- 区分burn/poison两种DOT类型
- burn: 多层火焰(外glow + 火核 + 白色核心 + 精灵图叠加)
- poison: 绿色毒雾效果
- 动画闪烁(sin波驱动)

#### 2. 冲撞兵方向指示 (`_draw_charge_indicator`)
- 读取`enemy.lockedDirection`和`enemy.state`
- windup状态显示: 警告圆弧 + 方向箭头线 + 发光尖端 + charge纹理
- `windup_progress`控制透明度递增

#### 3. 雷符落雷渲染 (`_draw_talisman_effects`)
- 遍历 `run.weapons` 找到 talisman 武器实例
- 读取 `bolt_fx` 数组（落雷位置）和 `chain_fx` 数组（闪电链）
- bolt_fx: 6段锯齿闪电束从上方落下 + 分支闪电 + thunderStrike精灵图叠加 + AOE扩散弧
- chain_fx: 5段锯齿电弧连线 + 白色核心线 + 落点发光圆
- 支持 `aoe`、`swordSynergy`、`relay`、`corpseRelay` 等变体

#### 4. 远程兵弹道增强 (`_draw_hostile_projectiles`)
- 使用新贴图 `hostile_projectile_v2.png`（暗色能量球，红橙核心）
- 多层渲染: 外层glow(半透明) + 粗拖尾(6段衰减) + 能量核心(白色) + 精灵图叠加
- 弹道尺寸从20增大到26

#### 5. 道剑二级弹道增强 (`_draw_player_projectiles`)
- source=='sword' 分支单独处理
- 使用新贴图 `sword_projectile_v2.png`（青白仙侠剑光）
- 外层仙气光环 + 双层拖尾(青色+白色) + 侧翼wisps(仙气) + 明亮剑核 + 精灵图叠加

### 新增精灵图资源 (全部已完成)

以下PNG由Python/PIL生成(384×384, 透明背景):
- ✅ `assets/vfx/burn_dot_effect.png` (63KB) — 火焰灼烧DOT，橙黄核心+红色火焰
- ✅ `assets/vfx/charge_indicator.png` (69KB) — 冲撞方向箭头，橙红渐变+运动拖尾
- ✅ `assets/vfx/skeleton_minion.png` (54KB) — 紫蓝幽灵骷髅
- ✅ `assets/vfx/hostile_projectile_v2.png` (49KB) — 暗色能量球，红橙核心
- ✅ `assets/vfx/sword_projectile_v2.png` (92KB) — 青白仙侠剑光
- ✅ `assets/vfx/thunder_strike.png` (109KB) — 垂直闪电束，白蓝核心

---

## 第三轮：美术资源优化（待执行）

### 🔴 需要正式资源替换（占位/粗糙）

#### 1. 世界掉落物（经验球/宝石）
- **现状**：`_draw_gems()` 用6层 `draw_circle` 画几何圆形
- **资源**：`pickup_gem.png`（37KB）存在但只在UI中使用，未用于世界掉落
- **需要**：世界掉落用的宝石精灵图/序列帧

#### 2. 闪电链特效（雷符 chain_fx）
- **现状**：纯 `draw_line` 锯齿线段 + 4px圆点，无任何纹理
- **资源**：完全不存在
- **需要**：闪电链精灵图或序列帧

#### 3. 第一代VFX贴图（<20KB，粗糙，需重新生成）

| 文件 | 大小 | 用途 | 严重度 |
|------|------|------|--------|
| `synergy_arc.png` | **2.8KB** | 协同弧线 | 🔴 最小资源 |
| `sword_slash.png` | **7.1KB** | 道剑斩击特效 | 🔴 每次攻击都出现 |
| `talisman_lightning.png` | **8.3KB** | 雷符闪电 | 🔴 每次落雷都出现 |
| `healing_petals.png` | 8.7KB | 治疗花瓣 | |
| `poison_mist.png` | 8.9KB | 毒雾 | |
| `dot_curse.png` | 9.4KB | 诅咒DOT | |
| `task_beacon.png` | 9.5KB | 任务信标 | |
| `staff_spirit_bolt.png` | **10.5KB** | 法杖弹道 | 🔴 每次射击都出现 |
| `freeze_burst.png` | 11.1KB | 冰冻爆裂 | |
| `impact_flash.png` | **12.2KB** | 打击闪光 | 🔴 每次命中都出现 |
| `pickup_glow.png` | 14.8KB | 拾取发光 | |
| `furnace_flame.png` | 15.1KB | 丹火火焰 | |
| `boss_enraged.png` | 16.5KB | Boss狂暴 | |
| `jade_ring_trail.png` | 17.4KB | 玉戒拖尾 | |
| `explosion.png` | 20.8KB | 爆炸 | 临界 |

#### 4. UI扁平装饰（`ui/modern/`）
- `divider_blossom.svg` 只有2.5KB，`panel_corner` 12KB — 极简几何图形
- 备选：`ui/ornaments/` 目录有12个手绘风格版本（53-172KB）但未被引用

### 🟡 可以打磨优化

| 项目 | 现状 | 建议 |
|------|------|------|
| 道剑剑气拖尾 | 多层圆形+线条叠加在sprite上 | 用烘焙拖尾纹理替代 |
| 普通弹道拖尾 | 同上，glow+线条+核心圆 | 同上 |
| 雷符闪电束 | 6段程序化锯齿线+分支 | 用序列帧闪电动画替代 |
| 骷髅召唤物 | 普通/尸体共用同一张 `skeleton_minion.png` | 尸体形态需独立贴图 |
| HUD几何图元 | `game_overlay.gd` 中等级徽章、暂停按钮等用圆形/矩形绘制 | 出专用UI小图标 |
| 敌人动画同步 | 同类敌人共享 `animation_time`，完全同步 | 需要每敌人随机相位偏移 |

### ✅ 资源充足的类别

- **敌人精灵图**：7种敌人全部有静态贴图+5×5动画序列帧（1.8-5.7MB/张）
- **玩家角色**：8方向行走序列帧+idle，完整覆盖
- **环境装饰**：12种全部有正式贴图（49-238KB）
- **地面纹理**：6张高清贴图（4.9-6.4MB）+ shader材质
- **地形瓦片**：4张webp（1.9-2.7MB）
