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

## 第四轮：体验问题反馈（表格状态未经核对，见复核结论）

> 来源：实际游戏体验反馈，2026-08-17
>
> ⚠️ **2026-08-18 复核**：下表标记 ✅ 的条目**多数没有出现在 `main` 的代码里**，git 历史中也查不到对应提交。
> 经逐项核对，以下条目在仓库中**不存在**：
> #3（`sword.gd` Lv2–5 仍为 maxHits 2/2/2/4，Lv6 才 INF——且 `RULES.md` §道剑同样规定 2/2/2/4/∞，
> 全穿透的说法与规则真值冲突，需先裁决再改）、#6（无 `_draw_task_guidance/_draw_light_column/_draw_offscreen_task_arrow`）、
> #7（无 `cloak_fire_burst_anim.png`）、#9（无 `furnace_flame_anim.png`）、
> #10（`config.gd` 仍 `rarePickupRadius: 42`；`world_art_view.gd` 稀有图标仍 46.0 / 光晕 62.0）、
> #11（`world_art_view.gd:484` 仍是 `enemy.has('state')`；敌人是 RefCounted，`Object` 没有 `has()`，
> 该行在 Boss 上屏时会报错，Boss idle 切换实际不生效）、#13（`debug_runtime.gd` 无 `grant_dark_crystals()`，
> `debug_overlay.gd` 无暗晶输入控件）。
> 表格保留原样仅作历史记录，请勿据此认为已完成。

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

## 第五轮：资源补全与渲染修复（表格状态未经核对，见复核结论）

> 来源：实际游戏体验反馈，2026-08-17。第四轮代码已完成，但部分图片资源未正确配置导致视觉效果未生效。本轮通过 ComfyUI 生成新贴图并修复渲染绑定。
>
> ⚠️ **2026-08-18 复核**：本轮**整轮都没有落库**。
> 「本轮新增精灵图资源」表里的 6 张 PNG（`sword_projectile_v3` / `flying_sword_v2` /
> `hostile_projectile_v3` / `charge_indicator_v2` / `task_beacon_v2` / `rare_pickup_glow`）
> 以及第四轮的 `furnace_flame_anim` / `cloak_fire_burst_anim`，在 `assets/vfx/` 与
> 全部 git 历史（`git log --all --diff-filter=A`）中均不存在。
> `art_catalog.gd` 的 `VFX_TEXTURES` 复核时仍是 19 条（不是 27 条），
> `s00_weapon_cards.gd` 仍校验 19，`s05_attr_cards.gd` 仍是 42，`s06_weapon_mechanics.gd` 的 maxHits 未改。
> 表格保留原样仅作历史记录，请勿据此认为已完成。

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

## 第六轮：道剑 Lv2 穿透弹道特效重制（已完成，2026-08-18 配置落库）

> 来源：用户要求，2026-08-17。使用 ComfyUI Krea-2 工作流生成蓝色 Q 版卡通风格飞剑特效。
> 流程：ComfyUI 黑色背景生图 → `key_black_to_alpha.py` 抠出阿尔法通道。

| # | 问题 | 分类 | 状态 | 说明 |
|---|------|------|------|------|
| 1 | 道剑 Lv2 穿透弹道需重新生成特效贴图 | 美术/VFX | ✅ 完成 | sword_projectile_lv2.png: 512×512, 蓝色 Q 版卡通飞剑，明亮色调，已抠阿尔法通道 |

### ✅ 本轮新增精灵图资源

| 文件 | 用途 | 大小 | 规格 |
|------|------|------|------|
| `assets/vfx/sword_projectile_lv2.png` | 道剑 Lv2 穿透弹道 | 326KB | 512×512, RGBA, ComfyUI Krea-2 生成 + key_black_to_alpha.py 抠图，蓝色 Q 版卡通飞剑 |

### ✅ 已配置代码变更（2026-08-18）

原计划里的 `swordProjectileV3` 并不存在于 `main`（第五轮整轮未落库），因此按仓库实际代码等效配置：

| 文件 | 位置 | 修改内容 |
|------|------|----------|
| `scenes/art_catalog.gd` | `VFX_TEXTURES`，`'swordSlash'` 之后 | 新增 `'swordProjectileLv2': preload('res://assets/vfx/sword_projectile_lv2.png'),` |
| `scenes/game/world_art_view.gd` | `_draw_player_projectiles()` 的 `source == 'sword' and projectile.swordQi` 分支 | 剑气主体贴图由 `PROJECTILE_TEXTURES['swordQi']` 改为 `VFX_TEXTURES.get('swordProjectileLv2', PROJECTILE_TEXTURES['swordQi'])` |
| `assets/vfx/sword_projectile_lv2.png.import` | — | 由 `Godot --headless --import` 生成并入库（缺 `.import` 时 `preload` 无法解析） |
| `tests/scenarios/s00_weapon_cards.gd` | 第 12 行 | `VFX_TEXTURES.size()` 校验 19 → 20 |

说明：当轮只替换弹道分支，Lv6 飞剑另见第七轮 #1。

验证：`Godot --headless --path GameProject --script res://tools/run_smoke.gd` → 403 项检查 / 23 章节全绿
（与改动前基线一致；退出时的 ObjectDB 泄漏告警为既有现象，改动前后相同）。

### 生成参数记录

- **模型**: Krea-2 Turbo (`krea2_turbo_fp8_scaled.safetensors`)
- **正向提示词**: `A bright cyan-blue flying sword projectile for a 2D video game, chibi Q-version cartoon style, glowing magical sword with energy aura, luminous blade with light blue and white highlights, magical sparkles around it, solid black background, clean isolated game asset, vibrant bright colors, anime-style weapon sprite, high quality game VFX art`
- **分辨率**: 512×512
- **采样**: 8 步, euler, simple, CFG 1.0
- **抠图脚本**: `.agents/skills/video-to-alpha-flipbook/scripts/key_black_to_alpha.py`
- **抠图参数**: `--black-threshold 15 --fade-width 20 --blur-alpha 1.0`

---

## 第七轮：补齐四/五轮缺口（已完成，2026-08-18）

> 来源：复核发现第四、五轮标 ✅ 的条目多数未落库（见上文两处复核结论）。本轮按「代码先补、图片重出」的顺序把缺口做完。
> ComfyUI 服务当轮不可用（`127.0.0.1:8188` 无响应），改用 gpt-image 网关出图，见下方生成参数记录。

### 代码与玩法

| # | 问题 | 分类 | 状态 | 说明 |
|---|------|------|------|------|
| 1 | 道剑 Lv2+ 未真正全穿透 | 玩法/移植缺陷 | ✅ 完成 | `sword.gd` Lv2–5 `maxHits` 2/2/2/4 → 全部 `INF`，恢复与原型 `js/weapons/sword.js` 一致；`RULES.md` §12.1、`BALANCE.md` 第五轮、`s06` 期望值同步 |
| 2 | **Boss 与冲撞兵渲染在运行时报错**（第四/五轮均未真正修好） | 美术/BUG | ✅ 完成 | 实测确认 `Object` 没有 `has()`、`Object.get()` 最多 1 个参数（2 参形式在静态类型下是 Parse Error，在 `Variant` 上是运行时错误）。`world_art_view.gd` 的 `enemy.has('state')` 与 `enemy.get('state','')` 两处一律改为 `'state' in enemy`。原症状：Boss 上屏打断 Pass 3 整个敌人精灵绘制（即「Boss 动画丢失」），冲撞兵进入 windup 打断 Pass 4，连带 DoT 特效、任务图标、血条一起消失 |
| 3 | 稀有收藏物拾取范围与图标偏小 | UI/玩法 | ✅ 完成 | `rarePickupRadius` 42→58；世界图标 46→68、光晕 62→110（改用新贴图），并新增按 `rarePickupRadius` 真实半径绘制的脉动外环 + 内环，让「已进范围」可见；标签下移避免与放大后的图标重叠 |
| 4 | 护送任务缺少目标点引导 | 玩法/UI | ✅ 完成 | 新增 `_draw_task_guidance()` / `_draw_light_column()` / `_draw_offscreen_task_arrow()`：地面流动虚线+末端箭头、目标在屏内时 3 层锥形光柱+上升光点、屏外时在可视边缘贴指向箭头（带任务图标与距离）。delivery 常驻引导，guard 仅在离圈时引导，bounty 指向悬赏目标 |
| 5 | 调试界面缺少发放暗晶功能 | 开发工具 | ✅ 完成 | `debug_runtime.grant_dark_crystals()`（写入后 `MetaSave.persist_save`，否则回主菜单被 `load_save` 覆盖）+ `debug_overlay.gd` 新增「局外资源」区：数量 SpinBox、发放按钮、实时余额标签；`tests/scenarios/debug_runtime.gd` 补 2 条断言 |

### ✅ 本轮新增精灵图资源（gpt-image 网关生成）

全部 384×384 RGBA 直单图，与既有 16 张一代 VFX 规格一致：

| 文件 | 用途 | 绑定键 | 大小 |
|------|------|--------|------|
| `assets/vfx/flying_sword_v2.png` | 道剑 Lv6 飞剑 | `VFX_TEXTURES['flyingSword']`（新增键） | 38KB |
| `assets/vfx/hostile_projectile_v3.png` | 远程兵暗色能量弹 | `PROJECTILE_TEXTURES['hostile']`（沿用键） | 33KB |
| `assets/vfx/charge_indicator_v2.png` | 冲撞兵预警指示 | `VFX_TEXTURES['chargeIndicator']`（沿用键） | 62KB |
| `assets/vfx/task_beacon_v2.png` | 任务信标 | `VFX_TEXTURES['taskBeacon']`（沿用键） | 59KB |
| `assets/vfx/rare_pickup_glow.png` | 稀有拾取发光 | `VFX_TEXTURES['rarePickupGlow']`（新增键） | 90KB |

沿用键名的三张按第三轮先例直接顶替旧图；被顶替的 `hostile_projectile_v2.png`、`task_beacon.png`、
`charge_indicator.png` 以及只剩回退作用的 `sword_projectile_v2.png` 已无运行时引用，
**保留未删**，是否清理由后续「死资源清理」统一处理。

`VFX_TEXTURES` 因此为 22 条，`s00_weapon_cards.gd` 校验同步 20 → 22。

### 未做的两项（按用户决定）

| 项目 | 原因 |
|------|------|
| `furnace_flame_anim.png`（火行路径 25 帧） | 文生图出不了连贯的 5×5 帧网格；留待 ComfyUI + MiniMax H3 视频管线（`.agents/skills/video-to-alpha-flipbook/` 即为此准备） |
| `cloak_fire_burst_anim.png`（披风 Lv6 爆发 25 帧） | 同上 |
| `sword_projectile_v3.png` | 已被第六轮的 `sword_projectile_lv2.png` 取代，无需再出 |

### 生成参数记录

- **管线**：`.devin/src/gpt_image_cli/cli.py`（打过 `--background transparent` 补丁的本地副本）
  → Pillow 后处理（裁到 alpha 边界 → 4% padding → Lanczos 降到 384×384）
- **模型 / 参数**：`openai/gpt-image-1.5`，`--background transparent --size 1024x1024 --quality high`
  （`gpt-image-2` 不支持透明底，会被 API 拒绝）
- **朝向约定**：弹道与预警类贴图一律画成**朝右（+X）**，因为 `_draw_sprite` 按 `direction.angle()` 旋转
- **构图约定**：`_draw_sprite` 的 `display_size` 除以贴图最长边，所以留白越多实际显示越小；
  本轮统一裁到内容边界再留 4%，因此同样的 `display_size` 比旧图更饱满
- **中心点**：远程兵能量弹按**高亮核心的亮度加权质心**居中（而非包围盒中心），
  避免拖尾把包围盒拉长、导致弹体视觉超前于真实碰撞点；其余按包围盒居中
- **归档**：原始 1024 图与 384 成品在 `ArtAsset/Image/VFX/gen_20260818/`（`final/` 为成品）

### 验证

- Godot headless smoke：**405 项检查 / 23 章节全绿**（新增 2 条暗晶断言、1 条 VFX 计数从 20 改 22）
- 原型 `npm run smoke`：全绿（本轮未触碰原型代码）
- `Godot --headless --path GameProject --import`：无 Parse/Compile 错误，6 个新 `.import` 已生成
- ⚠️ **仍需人工验证**：`_draw` 在 headless 下不执行，光柱／边缘箭头／脉动外环／新贴图的实际观感
  必须在编辑器 F5 跑一局确认（GameProject/AGENTS.md §测试规范要求）

### 追加调整（2026-08-18 验收反馈，已通过）

| # | 反馈 | 改动 |
|---|------|------|
| 1 | 冲撞预警「还是没有」 | 旧版只有 0.65s 的几根 2.5px 细线，实际过于隐蔽。重做为：按 `dashSpeed × 剩余冲刺时间` 绘制的填充危险车道（蓄力中按整段 `dashDuration` 预告、冲刺中随剩余时间收缩，终点始终落在真实撞击点）+ 充能推进线 + 两侧护栏 + 落点箭头 + 绕身倒计时环（蓄满即闭合）+ 图标 36→68/94px；并把触发条件从 `windup` 扩到 `windup or dash`，冲刺段淡出而非瞬间消失 |
| 2 | Lv6 飞剑要更大更明显 | 尺寸 46/54 → 80/96，拖尾 42/74 → 62/104、线宽 9/2.5 → 13/4.5，加双层脉动灵光与剑尖亮点，贴图 tint 由 `(0.88,0.97,1.0)` 改为纯白不再压暗 |
| 3 | 远程兵子弹前方有多余圆圈 | 删除两处程序化 `draw_circle`（弹头暗红光晕盘 `size*0.85` 与内层暖色核心）——新贴图自带暗紫外圈与红核，叠圆会在弹头前方露出盘子；尺寸 `maxf(26, r*5.2)` → `maxf(46, r*8.4)` |
| 4 | 道剑 Lv2 贴图朝向不对 | 贴图刀尖朝右上（≈ -45°），绘制时补 `angle + PI * 0.25` 顺时针 45° 偏移，使刀尖对准飞行方向 |

---

## 第八轮：音频框架与数值审计（2026-08-18/19）

> 处理「第八轮候选」中优先级最高的三类缺口：音频、数值、序列帧。
> 相关提交：`4cf0420`（音频框架）、`250a430`（数值收敛）、`0e89026`（js/Godot 对齐）、`671cea9`（序列帧图集）。

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| 1 | AudioManager autoload 框架 | ✅ 完成 | `autoload/audio_manager.gd`：SFX 8 路池 + 节流 + 音高抖动、BGM 双播放器交叉淡入、按 game_run 状态自动切歌、监听 `Events.sfx_requested`；game_view/meta_screens 完成接线；`default_bus_layout.tres` 总线布局；新增 s22 音频冒烟章节，Godot smoke 415 项 / 24 场景与原型 smoke 双绿 |
| 2 | 首批技能音效 | ✅ 完成 | 视频生成音频转制 `sfx_cloak_burst` / `sfx_trail_blaze`（ogg 入 `assets/audio/sfx/weapon/`，WAV 母带存 `ArtAsset/Audio/sfx/`） |
| 3 | 数值三项待校准 | ✅ 完成 | 武器强度重排、稀有物叠加与掉落源收敛、rarePickupRadius 复核全部解决；方法与数据见 `BALANCE.md` 调参历史第六轮；新增确定性校准工具 `tools/weapon_balance.gd`（双进程跑分逐字一致） |
| 4 | 两套 25 帧序列帧 | 🟨 图集就绪 | `cloak_fire_burst_anim` / `furnace_flame_anim`（5×5 网格、384px/帧）已入 `assets/vfx/` 与 `.import`，生产管线归档 `ArtAsset/Image/VFX/gen_20260818_anim/`；`art_catalog.gd` 仍 preload 静态贴图，抽帧渲染集成待做 |

资源进度：音频 SFX 2/22、BGM 0/6（清单以 `autoload/audio_manager.gd` 的 `SFX_PATHS` / `BGM_PATHS` 为准，缺口台账见 `ART_ASSET_CONFIG.md` §9）。

---

## 第八轮候选：待办清单（2026-08-19 起）

> 下列条目均为 2026-08-18 复核代码时确认存在的缺口，附依据文件/配置键，便于开工时直接定位。
> 归属其他台账的条目只在此处交叉引用，不重复维护：性能与音频见 `PROGRESS.md` §2 当前焦点，
> 资源缺口见 `ART_ASSET_CONFIG.md` §9，数值待校准见 `BALANCE.md` §待校准项。
>
> **2026-08-19 状态更新**（执行记录见上文「第八轮：音频框架与数值审计」节）：
> - 「音频完全空缺」→ 🟨 进行中：AudioManager 框架已落地，剩余资源补齐（SFX 2/22、BGM 0/6）。
> - 「两套 25 帧序列帧」→ 🟨 图集就绪待集成：两张图集已入库，渲染层抽帧接入未做。
> - 数值表三项（武器强度重排 / 稀有物叠加与掉落源 / rarePickupRadius）→ ✅ 已解决，见 `BALANCE.md` 第六轮。

### 美术效果与资源

| 优先 | 项目 | 依据 |
|------|------|------|
| 高 | **音频完全空缺** | `assets/audio/` 不存在；`PROGRESS.md` §2 焦点 2。目前全程零音效，感官落差大于任何贴图重绘 |
| 高 | **盾兵攻防窗口无表现** | `shield.gd` 有 `phase: shielded(3s) / open(1.5s)`、受伤 0.35× vs 1.25×，但 `world_art_view.gd` 中 `enemy.type == 'shield'` 仅用于放大尺寸——该敌人的全部机制不可见，玩家无法卡输出窗口 |
| 高 | **自爆兵无引爆预警** | `bomber.gd`：`triggerDistance 58`、`windup 0.9`、`blastRadius 88`。爆炸半径大于触发距离，进圈近乎必吃；且击杀不引爆（RULES §7.6），预警直接决定该敌人是否存在玩法。渲染层无任何绘制 |
| 中 | 精英狂暴无预警 | `enhancedChaser` 有 `enrageHpRatio 0.5`、`warningDuration 0.45`；渲染层只用到 Boss 的 `bossEnraged` |
| 中 | 两套 25 帧序列帧 | `furnace_flame_anim` / `cloak_fire_burst_anim`，需 ComfyUI + MiniMax H3 视频管线 → `.agents/skills/video-to-alpha-flipbook/` |
| 低 | 敌人受击/死亡补帧 | 目前仅 walk sheet + Boss idle，受击只有 tint |
| 低 | 死资源清理 | `hostile_projectile_v2` / `task_beacon` / `charge_indicator` / `sword_projectile_v2` 已无运行时引用 |

### 玩法

| 优先 | 项目 | 依据 |
|------|------|------|
| 高 | **统一敌人预警层** | 第七轮只补了冲撞兵。盾兵、自爆兵、精英狂暴、Boss 齐射（`windup 0.85`、12 发）都缺。建议抽通用 telegraph 层，避免每种敌人各写一份绘制代码 |
| 中 | 稀有物缺机制型选项 | `rare_items.gd` 5 种全是纯数值乘区（伤害 ×1.2 / 回血 / 磁吸 +80 / 经验 ×1.25 / 移速 ×1.1），没有改变行为的遗物，构筑深度最易补 |
| 中 | 任务节奏固定 | `tasks.waves = [3,8,13,18,23]`、`triggerWindow [35,45]`、3 种类型；25 分钟仅 5 次任务且类型可能重复 |
| 中 | 180 敌人对象池与降级策略 | `PROGRESS.md` §2 焦点 1，M6 唯一未完成技术项；分离算法 O(n²) 卡住 `maxAliveCap` |
| 低 | 六武器质变表现差异 | 道剑有飞剑、披风有爆发，其余四把质变感知偏弱 |

### 数值（详见 `BALANCE.md` §待校准项）

| 优先 | 项目 | 依据 |
|------|------|------|
| 高 | 道剑穿透 buff 后的六武器强度重排 | 第七轮把 Lv2–5 `maxHits` 恢复为 INF，道剑密集波 DPS 显著上升，其余五把未动 |
| 高 | 稀有物无上限乘法叠加 + 掉落源过宽 | `rareBonuses["damageMult"] *= 1.2` 无 cap；且 `shield.gd` **所有盾兵 rank 均为 "elite"**，而盾兵 `weight 4`、`unlockAt 180`、`maxAlive 1` 会常规刷新，每只击杀都掉稀有物 → 一局可能拿到 20+ 永久乘区 |
| 中 | `rarePickupRadius` 58 是否过头 | js 原值 30，第七轮按体验反馈提到 58（近 2 倍），与上一条叠加后几乎不会漏捡 |
| 中 | W25 Boss 弹 161 原始伤害 | `BALANCE.md` 第三轮后曲线速览自标「后续通过实机与受击遥测继续校准」，尚未做 |
| 低 | 单局 25 分钟时长 | 已由 90s/波压到 60s/波，是否继续压取决于单局时长目标 |

### 建议起手三件

1. **盾兵 phase + 自爆兵引信预警**：两个敌人的核心机制当前完全不可见，投入小、体感提升最直接。
2. ~~**稀有物掉落源与叠加上限**~~ ✅ 已完成（2026-08-19，`BALANCE.md` 第六轮；含武器强度重排与 rarePickupRadius 复核）。
3. **接入音频层** → 🟨 框架已落地（AudioManager + s22 冒烟）：剩余为资源补齐（SFX 2/22、BGM 0/6），按 `ART_ASSET_CONFIG.md` §9 清单推进。