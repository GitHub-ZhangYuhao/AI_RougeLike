---
name: fps-shooter
description: >
  构建第一人称射击游戏：移动 + 鼠标视角控制器、命中扫描或投射物射击、武器、
  生命值和敌人 AI。适用于 FPS，或调整瞄准手感、击杀耗时、后坐力或散布。
---

# 第一人称射击游戏

第一人称射击游戏开发指南——涵盖视角/移动控制器、射击模型、武器手感和战斗。
这是一项**组合式**技能：将 3D 控制器、输入和 AI 接入射击游戏。它不再重复讲解
3D 节点或射线检测，而是定义射击模型以及决定枪械手感的参数（TTK、后坐力、散布）。

## 何时使用

- 构建以**瞄准并射击**为核心动作的第一人称游戏时使用——竞技场射击、
  战术 FPS、PvE 射击、复古快节奏射击游戏。
- 决定命中扫描还是投射物，或调整击杀耗时、后坐力、散布和瞄准手感时使用。

**何时*不*使用：**第三人称/2D 射击 → 复用此处的射击模型，但使用对应类型的
摄像机/控制器。带防御塔的波次生存 → `tower-defense`。
对于摄像机/角色体本身，使用 `godot-3d-essentials` / `unreal-cpp-gameplay`。

## 核心循环

**扫描 → 锁定目标 → 瞄准并开火 → 确认击杀（反馈）→ 重新走位 / 换弹 / 推进。**
整个体验都建立在干脆利落的*瞄准与开火*微循环之上：视角响应迅速、命中反馈清晰，
死亡信息能够即时传达。

## 必备系统

1. **第一人称控制器**——移动（WASD/摇杆）+ 鼠标/摇杆视角、重力、跳跃/蹲伏。
2. **摄像机**——视线高度视角、可配置的 FOV 与灵敏度、后坐力抬枪。
3. **射击模型**——命中扫描射线和/或生成投射物；统一的命中反馈路径。
4. **武器 + 弹药**——伤害、射速、弹匣、换弹、切换武器。
5. **生命值 + 伤害**——HP、命中/爆头倍率、死亡；玩家与敌人共用同一模型。
6. **敌人 AI**——感知 → 警戒 → 攻击 → 搜索；掩体和反应延迟（`game-ai`）。
7. **反馈**——命中标记、命中贴花/粒子、命中音效、屏幕震动、击杀确认。
8. **目标**——射击之外要完成的事项：清剿、占领、生存、护送。

## 设计参数

| 参数 | 影响 | 合理默认值 |
|------|--------|--------------|
| 击杀耗时 (TTK) | 致命性、容错度 | 联动调整伤害 × 射速 × HP（参见参考资料）。 |
| 命中扫描与投射物 | 瞄准技巧类型 | 命中扫描 = 甩枪；投射物 = 预判/躲避。 |
| 伤害衰减 | 限制射程 | 约 20 m 内全额伤害，约 60 m 时降至下限。 |
| 爆头倍率 | 技巧回报 | 约 1.5–2.0×。 |
| 后坐力模式 | 可学习的抬枪规律 | 固定模式优于纯随机。 |
| 散布（扩散） | 抑制激光般的精准度 | 首发精准；持续射击时增大。 |
| 射速 / 弹匣 / 换弹 | 节奏、停顿 | 换弹 = 易受攻击的窗口。 |
| 鼠标灵敏度 / FOV | 舒适度、可读性 | 始终将两者作为选项开放。 |
| 瞄准辅助（手柄） | 控制器平衡性 | 靠近目标时吸附/减速。 |

## 模式

### 1. 命中扫描射击（即时射线，主力方案）

```python
# Pseudocode. Cast from the camera; first hit takes damage scaled by range + headshot.
direction = apply_spread(camera.forward, current_spread)
hit = raycast(camera.world_position, direction, max_dist=RANGE, mask=SHOOTABLE)
if hit:
    dmg = base_damage * falloff(hit.distance)
    if hit.is_head: dmg *= HEADSHOT_MULT
    hit.actor.take_damage(dmg)
    spawn_impact_fx(hit.point, hit.normal)        # decal + sound + hitmarker
```

### 2. 投射物射击（可躲避，需要预判目标）

```python
# Pseudocode. Spawn a moving body; it deals damage on its own collision.
p = spawn(projectile_scene, at=muzzle.world_position)
p.velocity = camera.forward * PROJECTILE_SPEED
p.on_hit   = lambda other, point: (other.take_damage(base_damage), explode_fx(point))
p.lifetime = RANGE / PROJECTILE_SPEED             # despawn so shots don't live forever
```

### 3. 击杀耗时（联动平衡三个要素）

```python
# Pseudocode. TTK falls out of HP, per-shot damage, and fire rate — tune as one system.
shots_to_kill = ceil(target_hp / damage_per_shot)
ttk_seconds   = (shots_to_kill - 1) / fire_rate_per_second   # first shot at t=0
```

## 陷阱 / 失败模式

- **视角移动绑定帧率或未按 `dt` 缩放** → 灵敏度随 FPS 改变。视角应由原始鼠标增量驱动；
  移动积分使用 `dt`（参见 `physics-tuning`）。
- **纯随机后坐力/散布** → 感觉不可控且不公平。使用可学习的后坐力模式；保持首发精准。
- **命中扫描没有衰减** → 手枪可以跨地图狙击。加入基于射程的伤害衰减。
- **没有命中反馈** → 玩家无法判断子弹是否命中。始终显示命中标记、命中特效和
  明确不同的击杀确认。
- **TTK 不合适** → 太低会显得过于依赖瞬时反应且不公平；太高会显得敌人像海绵。
  将伤害、射速和 HP 作为一个系统调整（模式 3）。
- **多人游戏中信任客户端** → 导致作弊和“我先开枪”的争议。由服务器保持权威；
  使用延迟补偿（参见参考资料），网络代码交由引擎的多人游戏技能处理。
- **没有 FOV / 灵敏度选项** → 引发晕动症和无障碍问题。始终开放这些选项。

## 组合方式（由以下技能构建）

- **控制器 + 摄像机：**`godot-3d-essentials`（Godot）或 `unreal-cpp-gameplay` / `unreal-blueprints`；Unity 使用 `unity-physics` + 角色控制器。
- **输入：**`input-systems`（或 `unreal-enhanced-input`）用于视角/移动、按键重映射和手柄瞄准辅助。
- **射击物理：**`godot-physics` / `unity-physics` 用于射线检测和投射物碰撞。
- **敌人：**`game-ai` 搭配 `unity-navmesh` / `unreal-behavior-trees` / Godot 导航。
- **摄像机与手感：**`camera-systems` 用于 FOV/后坐力抬枪和视角平滑；`game-feel` 用于命中停顿、屏幕震动和冲击表现。
- **润色：**`audio-design` 用于武器/命中音效；`shader-programming` 用于枪口/命中 VFX。
- **流程：**先用 `prototype-fast` 验证瞄准手感，再构建内容。

## 参考资料

- 有关命中扫描与投射物的取舍、伤害衰减、后坐力/散布、TTK 计算、命中判定/延迟补偿
  和敌人 AI 状态，请阅读 `references/shooting-and-feel.md`。
