---
name: unity-navmesh
description: >
  在 Unity 6.3 LTS 中添加 AI 导航：使用 AI Navigation 包（NavMeshSurface）烘焙 NavMesh，
  通过 NavMeshAgent.SetDestination 移动代理，并处理动态障碍物。适用于设置寻路、
  让敌人追逐玩家、烘焙导航，或用户提到 NavMesh、NavMeshAgent、NavMeshSurface、
  NavMeshObstacle 或 Unity 寻路时。
---

# Unity NavMesh（AI Navigation）

在 Unity 6.3 LTS 中为 NPC 提供寻路能力：烘焙可行走表面，并使代理绕过障碍物移动。
面向 **Unity 6.3 LTS (6000.3)** 和 **AI Navigation package 2.x**。

> **版本陷阱（Unity 2022+/6）：**旧的内置 **Navigation window**（Object/Bake 选项卡）
> 已被移除。现在通过 **AI Navigation package** 以**组件方式**烘焙
>（`com.unity.ai.navigation`）：向关卡几何体添加 **NavMeshSurface** 并点击
> **Bake**。*运行时* `NavMeshAgent`/`NavMesh` API 仍位于内置的 `UnityEngine.AI` 中。

## 何时使用

- 适用于代理需要行走/追逐/巡逻至目标、烘焙可导航表面、添加动态阻挡物
  （`NavMeshObstacle`），或检查目的地是否可达时。
- 适用于项目包含 AI Navigation 包、`NavMeshSurface` 组件，或使用
  `UnityEngine.AI.NavMeshAgent` 的脚本时。

**何时不应使用：**决定何时/向何处移动的*决策*逻辑（FSM、行为树、转向）→
`game-ai`（本技能针对 Unity 移动/寻路机制）。不涉及寻路的力驱动或运动学移动 →
`unity-physics`。

## 核心工作流

1. **安装 AI Navigation 包**（Package Manager → `com.unity.ai.navigation`）。
2. **烘焙表面：**选择静态关卡几何体，依次选择 **Add Component → Navigation → NavMesh
   Surface**，设置代理类型/区域设置，然后点击 **Bake**。几何体、`NavMeshModifier`
   或代理设置发生变化时，都要重新烘焙。
3. **向每个移动的 NPC 添加 `NavMeshAgent`**；其半径/高度/速度必须与烘焙的代理类型匹配，
   并且必须生成在已烘焙网格*上*。
4. **使用脚本中的 `SetDestination(targetPos)` 驱动代理**；代理会自动转向并避开其他代理。
   使用 `remainingDistance`/`pathPending` 检测是否到达。
5. **使用 `NavMeshObstacle`（carving）处理动态阻挡物**，使关闭的门/箱子无需完整重新烘焙
   即可阻挡路径。
6. **使用 AI Navigation 叠加层验证**（烘焙网格会绘制在 Scene 视图中），观察代理是否
   绕过障碍到达目标；使用 `NavMeshPath.status` 检查不可达目标。

## 模式

### 1. 使用 NavMeshAgent 追逐/寻找目标

```csharp
using UnityEngine;
using UnityEngine.AI;

[RequireComponent(typeof(NavMeshAgent))]
public class Chaser : MonoBehaviour
{
    [SerializeField] private Transform target;
    private NavMeshAgent _agent;

    private void Awake() => _agent = GetComponent<NavMeshAgent>();

    private void Update()
    {
        if (target) _agent.SetDestination(target.position);   // re-path toward the target
    }

    // Arrived? pathPending guards the first frame before a path exists.
    private bool HasArrived() =>
        !_agent.pathPending && _agent.remainingDistance <= _agent.stoppingDistance;
}
```

### 2. 执行前检查可达性

```csharp
using UnityEngine.AI;

public bool CanReach(NavMeshAgent agent, Vector3 destination)
{
    var path = new NavMeshPath();
    agent.CalculatePath(destination, path);
    return path.status == NavMeshPathStatus.PathComplete;   // vs Partial / Invalid
}
```

### 3. 在运行时烘焙（用于程序化构建或流式加载的关卡）

```csharp
using Unity.AI.Navigation;   // the package namespace (NavMeshSurface)

[SerializeField] private NavMeshSurface surface;

// After spawning level geometry, build the navmesh in code.
public void RebuildNav() => surface.BuildNavMesh();
```

### 4. 在网格上执行 carving 的动态障碍物

```csharp
// Add a NavMeshObstacle (Carve = true) to a door/crate. While present it cuts a hole in the
// navmesh so agents route around it; remove/disable it to reopen the path — no re-bake needed.
```

## 常见陷阱

- **寻找 Navigation window**——它在 Unity 6 中已不存在。请使用 AI Navigation 包的
  `NavMeshSurface` 组件和 Bake。
- **代理不移动/传送到原点**——它不在已烘焙网格上，或没有烘焙表面。烘焙表面并将代理
  生成在其上（使用 `NavMesh.SamplePosition` 吸附）。
- **代理忽略新几何体**——navmesh 是烘焙得到的；运行时生成的障碍物需要使用
  `NavMeshObstacle`（carving），或通过 `surface.BuildNavMesh()` 重新烘焙。
- **每帧调用 `SetDestination` 浪费资源**——对于移动缓慢的目标，应按计时器重新寻路
  （例如每 0.2s 一次），而不是每帧执行。
- **代理半径/高度不匹配**——如果 `NavMeshAgent` 的尺寸与烘焙代理类型不同，
  它会卡在缝隙中或悬空；请保持一致。
- **代理相互挤压时抖动**——调整 `avoidancePriority` 和质量；对于真正静态的阻挡物，
  应使用 obstacle，而不是依赖代理避让。

## 参考资料

- 主要文档：AI Navigation 包手册
  （`https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/index.html`）以及
  `ScriptReference/AI.NavMeshAgent`、`ScriptReference/AI.NavMesh`。

## 相关技能

- `game-ai`——使用本技能、与引擎无关的决策（FSM、行为树、转向）。
- `unity-csharp-scripting`——代理周围的 MonoBehaviour 结构。
- `tower-defense` / `fps-shooter`——将寻路与玩法组合的游戏类型。
