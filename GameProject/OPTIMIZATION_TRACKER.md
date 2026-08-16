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

## 第三轮：美术资源优化（静态图片已完成，动态资源延期）

### ✅ 本轮已完成的静态图片

#### 1. 世界掉落与世界实体

- `pickup_gem.png` 已重绘并正式绑定 `_draw_gems()`；主体不再由六层圆形模拟，仅保留光晕、阴影和磁吸反馈。
- 新增 `assets/sprites/weapons/jade_ring_world.png`，轨道玉环不再复用 HUD 武器图标。
- 新增 `assets/sprites/summons/jade_guard_world.png` 与 `wisp_world.png`，玉卫和鬼火不再复用 UI 图标。
- 新增 `assets/vfx/skeleton_minion_corpse.png`，骷髅尸体与存活召唤物已使用独立图片和落地构图。

#### 2. 第一代单帧 VFX

以下 16 张旧的低容量/占位式图片已替换为 384×384 RGBA 手绘资源，并沿用原绑定键名：

| 文件 | 用途 | 状态 |
|------|------|------|
| `sword_slash.png` | 道剑斩击 | ✅ 已替换 |
| `talisman_lightning.png` | 雷符落雷 | ✅ 已替换 |
| `cloak_fire_burst.png` | 披风火焰爆发 | ✅ 已替换 |
| `staff_spirit_bolt.png` | 法杖灵弹 | ✅ 已替换 |
| `synergy_arc.png` | 协同弧线 | ✅ 已替换 |
| `impact_flash.png` | 通用命中闪光 | ✅ 已替换 |
| `explosion.png` | 爆炸 | ✅ 已替换 |
| `freeze_burst.png` | 冰冻爆裂 | ✅ 已替换 |
| `poison_mist.png` | 毒雾 | ✅ 已替换 |
| `dot_curse.png` | 诅咒 DoT | ✅ 已替换 |
| `healing_petals.png` | 治疗花瓣 | ✅ 已替换 |
| `pickup_glow.png` | 拾取发光 | ✅ 已替换 |
| `boss_enraged.png` | Boss 狂暴 | ✅ 已替换 |
| `furnace_flame.png` | 丹火 | ✅ 已替换 |
| `jade_ring_trail.png` | 玉环拖尾 | ✅ 已替换 |
| `task_beacon.png` | 任务信标 | ✅ 已替换 |

#### 3. 静态 UI 装饰

- `ui/modern/` 中 11 张方形徽章、印章、卡角和光标已换成细节更完整的手绘版本，现有 `ArtCatalog.UI_TEXTURES` 绑定保持不变。
- `divider_blossom.png` 保留横向原子切片：它需要在 Debug 面板中按 22px 高度横向排版，不属于未配置占位符。
- 桃夜巡 HUD/卡牌继续使用 `ui/peach_night/atomic/` 的正式切片，本轮不重做已批准的 UI 原子资源。

### ⏸ 按本轮范围延期的动态资源

| 项目 | 当前表现 | 后续方向 |
|------|----------|----------|
| 闪电链 `chain_fx` | 程序化锯齿线与节点 | 动态闪电材质或序列帧 |
| 道剑/普通弹道拖尾 | 贴图主体叠加程序化线条和光晕 | 动态拖尾材质或序列帧 |
| 雷符闪电束 | 程序化分段闪电 | 动态闪电动画 |
| 玩家、敌人、Boss 动画 | 现有序列帧可运行 | 攻击/受击/死亡补帧与随机相位 |
| 视频资源 | 当前无正式视频管线 | 后续按界面或剧情需求单独规划 |

### ✅ 当前静态图片覆盖结论

- **敌人/Boss 静态图**：7 类全部有正式图片。
- **玩家静态回退与八方向图片**：已配置。
- **世界掉落、弹道、召唤状态、任务和单帧战斗 VFX**：均已绑定正式图片。
- **环境装饰、地面纹理、地形瓦片**：已配置。
- **现代 UI 与桃夜巡原子 UI 图片**：已配置；后续只做明确批准的风格迭代，不再视为占位符。
