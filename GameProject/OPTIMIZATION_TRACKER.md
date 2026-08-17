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

---

## 第四轮：体验问题反馈（已完成）

> 来源：实际游戏体验反馈，2026-08-17

| # | 问题 | 分类 | 状态 | 说明 |
|---|------|------|------|------|
| 1 | 道剑一级攻击特效太粗糙，需要重新做 | 美术/VFX | ✅ 完成 | world_art_view.gd: 重做近战斩击动画(多层弧光+3层火花+7粒子+光晕) |
| 2 | 二级及之后的攻击特效也需要重新做 | 美术/VFX | ✅ 完成 | world_art_view.gd: 8层山形剑光(外环+飘光+核心+拖尾+wisps+微光+精灵图) |
| 3 | 道剑升到二级之后应实现穿透伤害 | 玩法/BUG | ✅ 完成 | sword.gd: CARD.levels[1-4] maxHits 改为 INF，实现全穿透 |
| 4 | 道剑6级质变后的飞剑需增强UI重新实现 | 美术/VFX | ✅ 完成 | world_art_view.gd: 8层渲染+状态特效(轨道/蓄力强化/飞行中)+12个飘光+3层拖尾 |
| 5 | 远程小兵的攻击特效太粗糙 | 美术/VFX | ✅ 完成 | world_art_view.gd: 7层暗色能量球(扩展光晕+旋转粒子+6段拖尾+电弧+脉动核心+精灵图) |
| 6 | 护送任务缺少引导护送至的目标点 | 玩法/UI | ✅ 完成 | world_art_view.gd: 新增_draw_task_guidance()/_draw_light_column()/_draw_offscreen_task_arrow() |
| 7 | 炙热披风6级爆发特效需序列帧精灵图动画 | 美术/VFX | ✅ 完成 | cloak_fire_burst_anim.png(25帧序列帧)+world_art_view.gd多层渲染+增强火焰爆炸 |
| 8 | 冲撞兵的冲撞需UI预警提醒 | 玩法/UI | ✅ 完成 | world_art_view.gd: 5层预警(扩展警戒环+方向扇形区+倒计时弧+发光箭头+警告图标) |
| 9 | 火行路径灼烧火焰图案换成动画序列帧精灵图 | 美术/VFX | ✅ 完成 | furnace_flame_anim.png(25帧序列帧)+world_art_view.gd多层渲染+3层火焰 |
| 10 | 掉落稀有收藏物品的图标及拾取范围放大 | UI/玩法 | ✅ 完成 | config.gd rarePickupRadius 42→58; world_art_view.gd 图标46→68, 光晕62→80 |
| 11 | Boss的动画丢失了 | 美术/BUG | ✅ 完成 | world_art_view.gd: 修复enemy.has('state')改为直接访问enemy.state |
| 12 | 所有UI需支持鼠标点击 | UI/功能 | ✅ 完成 | 已验证全面支持(game_overlay.gd, game_run.gd, choice_card_renderer.gd, meta_screens.gd) |
| 13 | 调试界面需要增加暗晶数量的功能 | 开发工具 | ✅ 完成 | debug_runtime.gd + debug_overlay.gd: 增加暗晶输入框和按钮 |

### 优先级说明

- **P0（影响玩法）**：#3 道剑穿透机制、#6 护送目标引导、#11 Boss动画丢失、#12 UI鼠标支持
- **P1（影响体验）**：#1 #2 #4 道剑特效系列、#5 远程兵特效、#7 披风爆发特效、#8 冲撞预警、#9 火焰路径动画
- **P2（优化项）**：#10 稀有拾取范围、#13 调试工具

### 新增精灵图资源

| 文件 | 用途 | 规格 |
|------|------|------|
| `assets/vfx/furnace_flame_anim.png` | 火行路径灼烧 | 1920×1920, 5×5网格, 25帧, 384px/帧 |

---

## 第五轮：资源补全与渲染修复（已完成）

> 来源：实际游戏体验反馈，2026-08-17。第四轮代码已完成，但部分图片资源未正确配置导致视觉效果未生效。本轮通过 ComfyUI 生成新贴图并修复渲染绑定。

| # | 问题 | 分类 | 状态 | 说明 |
|---|------|------|------|------|
| 1 | 道剑Lv2-5弹道仍用旧图标 projectile_sword.png | 美术/配置 | ✅ 完成 | world_art_view.gd: 新增sword分支，使用sword_projectile_v3.png + 多层仙侠剑光渲染 |
| 2 | 道剑6级飞剑视觉增强 | 美术/VFX | ✅ 完成 | flying_sword_v2.png 生成并绑定到飞剑和swordQi渲染 |
| 3 | 远程小兵攻击特效优化 | 美术/VFX | ✅ 完成 | hostile_projectile_v3.png 生成并替换弹道贴图 |
| 4 | 护送任务目标引导增强 | UI/玩法 | ✅ 完成 | _draw_marker()增强：光柱+更大信标+task_beacon_v2.png |
| 5 | 炙热披风6级爆发序列帧确认 | 美术/VFX | ✅ 完成 | cloak_fire_burst_anim.png 已确认正确导入 |
| 6 | 冲撞兵预警指示器增强 | UI/VFX | ✅ 完成 | charge_indicator_v2.png 生成，图标尺寸增大(28→36+windup*20) |
| 7 | 火行路径火焰序列帧确认 | 美术/VFX | ✅ 完成 | furnace_flame_anim.png 已确认正确导入 |
| 8 | 稀有收藏物品图标放大 | UI | ✅ 完成 | rare_pickup_glow.png + 图标尺寸(68→90) + 光晕(80→110) + 脉动外环 |
| 9 | Boss动画丢失修复 | 美术/BUG | ✅ 完成 | 修复 enemy.has('state') → enemy.get('state','chase')，Object不支持.has() |
| 10 | UI鼠标点击支持确认 | UI/功能 | ✅ 完成 | game_overlay.gd _clickable_buttons 系统已覆盖所有界面 |
| 11 | 调试界面暗晶功能确认 | 开发工具 | ✅ 完成 | debug_overlay.gd SpinBox+Button 已配置，grant_dark_crystals() 工作正常 |

### 本轮代码变更

| 文件 | 修改内容 |
|------|----------|
| `scenes/game/world_art_view.gd` | 道剑弹道分支重构、飞剑贴图替换、稀有拾取放大+脉动光效、任务信标光柱增强、冲撞预警尺寸增大、Boss动画 .has() → .get() 修复 |
| `scenes/art_catalog.gd` | VFX_TEXTURES 新增 6 条记录：swordProjectileV3, flyingSwordV2, hostileProjectileV3, chargeIndicatorV2, taskBeaconV2, rarePickupGlow |
| `tests/scenarios/s00_weapon_cards.gd` | VFX_TEXTURES 数量检查 19→27 |
| `tests/scenarios/s05_attr_cards.gd` | rarePickupRadius 42→58 |
| `tests/scenarios/s06_weapon_mechanics.gd` | 道剑 maxHits 期望值全部改为 INF |

### 本轮新增精灵图资源（ComfyUI 生成）

| 文件 | 用途 | 大小 |
|------|------|------|
| `assets/vfx/sword_projectile_v3.png` | 道剑Lv2+穿透弹道 | 2.7MB |
| `assets/vfx/flying_sword_v2.png` | 道剑Lv6飞剑 | 996KB |
| `assets/vfx/hostile_projectile_v3.png` | 远程兵暗色能量弹 | 105KB |
| `assets/vfx/charge_indicator_v2.png` | 冲撞兵预警指示 | 334KB |
| `assets/vfx/task_beacon_v2.png` | 护送任务信标 | 236KB |
| `assets/vfx/rare_pickup_glow.png` | 稀有拾取发光 | 192KB |
| `assets/vfx/furnace_flame_anim.png` | 火行路径灼烧 | 1920×1920, 5×5网格, 25帧, 384px/帧 |

---

## 第六轮：道剑 Lv2 穿透弹道特效重制（美术资源已生成，代码待配置）

> 来源：用户要求，2026-08-17。使用 ComfyUI Krea-2 工作流生成蓝色 Q 版卡通风格飞剑特效。
> 流程：ComfyUI 黑色背景生图 → `key_black_to_alpha.py` 抠出阿尔法通道。

| # | 问题 | 分类 | 状态 | 说明 |
|---|------|------|------|------|
| 1 | 道剑 Lv2 穿透弹道需重新生成特效贴图 | 美术/VFX | ✅ 完成 | sword_projectile_lv2.png: 512×512, 蓝色 Q 版卡通飞剑，明亮色调，已抠阿尔法通道 |

### ✅ 本轮新增精灵图资源

| 文件 | 用途 | 大小 | 规格 |
|------|------|------|------|
| `assets/vfx/sword_projectile_lv2.png` | 道剑 Lv2 穿透弹道 | 326KB | 512×512, RGBA, ComfyUI Krea-2 生成 + key_black_to_alpha.py 抠图，蓝色 Q 版卡通飞剑 |

### 🔧 待配置代码变更（需手动应用）

以下代码修改未随本轮推送，需后续手动配置：

| 文件 | 行号 | 修改内容 |
|------|------|----------|
| `scenes/art_catalog.gd` | VFX_TEXTURES 字典末尾（约第 98 行） | 新增 `'swordProjectileLv2': preload('res://assets/vfx/sword_projectile_lv2.png'),` |
| `scenes/game/world_art_view.gd` | 第 771 行 | 将 `ArtCatalog.VFX_TEXTURES.get('swordProjectileV3', texture)` 改为 `ArtCatalog.VFX_TEXTURES.get('swordProjectileLv2', texture)` |

#### art_catalog.gd 修改详情

在 `VFX_TEXTURES` 字典的 `'swordProjectileV3'` 行之后添加一行：

```gdscript
  'swordProjectileV3': preload('res://assets/vfx/sword_projectile_v3.png'),
  'swordProjectileLv2': preload('res://assets/vfx/sword_projectile_lv2.png'),  # ← 新增
  'flyingSwordV2': preload('res://assets/vfx/flying_sword_v2.png'),
```

#### world_art_view.gd 修改详情

在 `_draw_player_projectiles()` 函数中，`source == 'sword'` 分支内（约第 771 行），将：

```gdscript
_draw_sprite(ArtCatalog.VFX_TEXTURES.get('swordProjectileV3', texture), projectile_position, size * 1.4, angle, false, Color(0.88, 0.97, 1.0, 0.9))
```

改为：

```gdscript
_draw_sprite(ArtCatalog.VFX_TEXTURES.get('swordProjectileLv2', texture), projectile_position, size * 1.4, angle, false, Color(0.88, 0.97, 1.0, 0.9))
```

### 生成参数记录

- **模型**: Krea-2 Turbo (`krea2_turbo_fp8_scaled.safetensors`)
- **正向提示词**: `A bright cyan-blue flying sword projectile for a 2D video game, chibi Q-version cartoon style, glowing magical sword with energy aura, luminous blade with light blue and white highlights, magical sparkles around it, solid black background, clean isolated game asset, vibrant bright colors, anime-style weapon sprite, high quality game VFX art`
- **分辨率**: 512×512
- **采样**: 8 步, euler, simple, CFG 1.0
- **抠图脚本**: `.agents/skills/video-to-alpha-flipbook/scripts/key_black_to_alpha.py`
- **抠图参数**: `--black-threshold 15 --fade-width 20 --blur-alpha 1.0`