---
name: game-ai
description: >
  使用有限状态机、行为树、转向行为和 A\*寻路来设计 NPC 和敌人决策逻辑——这些是与检测到的引擎导航 API 配合使用的中立算法，适用于构建敌人生成 AI、FSM 或行为树、转向/群聚，或寻路；也适用于用户提及状态机、行为树、黑板（blackboard）、A\*、NavMesh、Seek 或巡逻/追击时。
---

# 游戏 AI：决策、转向与寻路

构建可信 NPC 行为的三个可分离层级为：**decide**（做什么）、**steer**（如何移动过去）和 **path**（如何在地图中规划路线）。保持它们解耦——行为树选择目标，寻路生成路径点，转向跟随这些路径点。本技能教授与引擎无关的算法；通过下方相关技能将它们绑定到您的引擎上。

## 何时使用

- 在实现敌人生成/NPC 逻辑时使用：巡逻、追击/逃跑、守卫状态、群体移动或“找到通往玩家的路径”。
- 用于选择 **FSM**（少数清晰的状态）、**行为树**（多个具有优先级的反应性行为）还是 **转向**（平滑的局部移动）。
- 在集成寻路时：网格/图上的 A*，或驱动引擎 NavMesh 代理。

**何时不使用：** 针对引擎特定的 NavMesh/代理 API 及烘焙流程，请使用 `unity-navmesh`、`unreal-behavior-trees` 或 Godot 的 `NavigationAgent2D/3D`（参考该引擎的技能说明）；用于调整移动与碰撞手感时，使用 `physics-tuning`；若需沿车道生成波次，请参考 `tower-defense` 类型技能。

## 核心工作流

1. **根据复杂度选择决策模型。** 2–5 个状态且转换明显 → FSM。多个行为、优先级、中断和复用 → 行为树。连续的“我有多想执行每个选项”→ 效用评分。
2. **将决策与运动分离。** 决策层输出 *意图*（目标位置、动作）。转向或寻路将意图转化为运动。
3. **在正确的图上规划路径。** 网格瓦片、路径点图，或烘焙后的 NavMesh。节点越少 A*越快。对于 3D 游戏优先使用引擎的 NavMesh；用于瓦片游戏则在网格上使用 A*。
4. **沿路径转向**，而非直接朝向目标——跟随下一个路径点，当接近时推进，使代理能够转弯。
5. **谨慎重算路径。** 在定时器或目标移动到新瓦片时进行寻路，而不是每帧都计算。缓存路径；仅让路径点索引前进。
6. **通过观察验证。** 观察代理：它是否到达目标？卡在角落吗？在不同状态间振荡吗？调整参数时在屏幕上绘制路径和当前状态。

## 模式

### 1. 有限状态机（单个状态对象，显式转换）

```gdscript
# Each state is a small object with enter/update/exit. The machine owns "current".
class_name State
func enter(agent): pass
func update(agent, dt) -> State: return null   # return a new state to transition
func exit(agent): pass

# --- Chase state: returns Patrol when the player escapes sight range ---
class Chase extends State:
    func update(agent, dt) -> State:
        if not agent.can_see(agent.target):
            return Patrol.new()                 # transition by returning next state
        agent.move_toward(agent.target.position, dt)
        return null                             # null = stay in this state

# --- Driver: call once per frame ---
func tick(dt):
    var next = current.update(self, dt)
    if next != null:
        current.exit(self); next.enter(self); current = next
```
保持转换逻辑 *在* 状态内部（或在一个表中），绝不在一个不断增长的 `if` 标志堆中。一个状态拥有单一行为；这正是使 FSM 可读的关键。

### 2. 行为树 Tick（复合节点返回状态）

```gdscript
# A node's tick() returns SUCCESS, FAILURE, or RUNNING (still working this frame).
enum Status { SUCCESS, FAILURE, RUNNING }

# Sequence: run children in order; stop at the first non-SUCCESS (logical AND).
func sequence_tick(children, agent, dt) -> int:
    for child in children:
        var s = child.tick(agent, dt)
        if s != Status.SUCCESS:
            return s                 # FAILURE or RUNNING short-circuits the sequence
    return Status.SUCCESS

# Selector: try children until one succeeds or is RUNNING (logical OR / fallback).
func selector_tick(children, agent, dt) -> int:
    for child in children:
        var s = child.tick(agent, dt)
        if s != Status.FAILURE:
            return s                 # SUCCESS or RUNNING stops the search
    return Status.FAILURE
```
守卫 AI 自顶向下读取：`Selector[ Sequence[CanSeePlayer?, Chase], Patrol ]`——可见时追击，否则巡逻。参见 `references/behavior-trees.md` 了解叶节点、装饰器（Inverter, Cooldown）和黑板的使用。

### 3. 转向：寻路与抵达（平滑且与帧率无关）

```gdscript
# Seek: accelerate toward a target at full speed. Steering = desired - current.
func seek(pos, vel, target, max_speed, max_force) -> Vector2:
    var desired = (target - pos).normalized() * max_speed
    return (desired - vel).limit_length(max_force)   # a force, not a teleport

# Arrive: like seek, but ramp speed down inside slow_radius so it stops cleanly.
func arrive(pos, vel, target, max_speed, max_force, slow_radius) -> Vector2:
    var offset = target - pos
    var dist = offset.length()
    if dist < 0.001: return -vel                      # already there: kill drift
    var ramped = max_speed * min(dist / slow_radius, 1.0)
    var desired = offset / dist * ramped
    return (desired - vel).limit_length(max_force)

# Per frame: vel += steering * dt; pos += vel * dt   (always scale by dt)
```
### 4. A*启发函数不得高估（否则路径将不再是最短）

```python
# Match the heuristic to the movement. An ADMISSIBLE heuristic (never larger
# than the true remaining cost) keeps A* optimal.
def heuristic(a, b):
    dx, dy = abs(a.x - b.x), abs(a.y - b.y)
    # return dx + dy             # Manhattan: 4-direction grids (no diagonals)
    return (dx + dy) + (1.414 - 2) * min(dx, dy)   # octile: 8-direction grids
# f(n) = g(n) + h(n): g = cost from start, h = heuristic to goal.
# Overestimating h is faster but no longer guarantees the shortest path.
```
完整的 A*循环（优先队列、`came_from`重建、网格 + 路径点图）在 `references/pathfinding.md` 中。

## 常见陷阱

- **每帧进行寻路**会导致帧率下降。仅在定时器或目标移动到新瓦片时重算；中间跟随缓存的路径点。
- **直接朝向目标转向**而非下一个路径点会使代理紧贴墙壁和角落。遵循路径；当在半径内时推进路径点。
- **不可采纳的 A*启发式函数**（例如放大的欧几里得距离，或对角网格上的曼哈顿距离）返回快速但 *非最短* 的路径。选择与您允许移动匹配的启发式函数。
- **永远不返回 `RUNNING` 状态的动作叶子节点**会导致每帧重复启动该动作，直至其最终返回 `RUNNING` 状态为止。（注：根据上下文逻辑修正了原句末尾“直到...返回"的矛盾表述为“直至完成”）
- **避免 FSM 代码 spaghetti**：分散各处使用 `if state == ...` 条件判断会导致重新出现 FSM 试图防范的逻辑混乱，应将所有转换逻辑封装在状态机内部。
- **缺少视线或卡住检测**→代理永远撞向墙壁。添加超时强制重新规划或改变状态。

## 参考资料

- `references/pathfinding.md` — 完整的 A*（优先队列、重建）、网格与路径点图，何时应委托给引擎 NavMesh。
- `references/behavior-trees.md` — 节点分类学、叶节点/装饰器实现、黑板以及 FSM vs BT 选择。

## 相关技能

- `unity-navmesh`, `unreal-behavior-trees` —— 具体的引擎 AI/导航 API。
- `physics-tuning` —— 移动、碰撞响应和代理半径。
- `procedural-gen` —— 生成 AI 进行导航的图或关卡。
- `tower-defense`, `fps-shooter` —— 组合此技能的类型。
