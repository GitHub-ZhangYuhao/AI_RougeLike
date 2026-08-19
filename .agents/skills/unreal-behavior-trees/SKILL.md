---
name: unreal-behavior-trees
description: >
  使用 Behavior Tree 和 Blackboard 在 Unreal Engine 5 中构建 NPC AI：composite
  （Selector/Sequence）、task、decorator、service，以及从 AIController 运行行为树。
  适用于创建敌人/NPC AI、BT_/BB_ 资产、自定义 BTTask 或 BTService 节点，或用户提及
  Behavior Tree、Blackboard、AIController、BTTask、decorator 或 service 时。
---

# Unreal Behavior Tree

在 UE5 中使用由 Blackboard 驱动的 Behavior Tree 编写 NPC 决策逻辑：用 composite 组织行为树，
用 decorator 控制分支准入，用 service 保持状态最新，并从 AIController 运行行为树。目标版本为
**UE 5.8**。

## 何时使用

- 构建敌人/NPC AI 时使用：创建 `BT_`/`BB_` 资产对、组织 Selector/Sequence 分支、
  添加 decorator（条件）和 service（定期更新）、编写自定义 `BTTask`/`BTService` 节点，
  或连接 AIController 以运行行为树。
- 当项目具有 Behavior Tree（`BT_`）和 Blackboard（`BB_`）资产以及
  `AAIController` 时使用。

**不应使用的场景：** AI 的*概念*（FSM 与 BT 与 steering 的比较、跨引擎）→
`game-ai`。纯导航/寻路数学属于引擎 navmesh（BT 的 `MoveTo` 会使用它）。简单的一次性逻辑
采用小型状态机可能比完整行为树成本更低。

## 核心工作流

1. **创建资产对：** Blackboard（`BB_`）保存带类型的键（AI 的记忆：`TargetActor`、
   `LastKnownLocation`、`bIsInvestigating`）；Behavior Tree（`BT_`）引用该 Blackboard。
2. **接管并运行。** `AAIController` 接管 pawn 并调用 `RunBehaviorTree(BT)`，
   这也会初始化所引用的 Blackboard。
3. **使用 composite 组织结构。** **Selector** 从左到右运行子节点，直到某个节点*成功*
   （优先级/回退：“攻击，否则追击，否则巡逻”）。**Sequence** 运行子节点，直到某个节点
   *失败*（全部执行：“移动到掩体 → 换弹 → 探头”）。**Simple Parallel** 在运行一个主 task
   的同时运行一个次要 task。
4. **使用读取 Blackboard 键的 Decorator 控制分支准入**（例如用“Has Target?”守卫战斗分支）。
   设置 **Observer Aborts**，让行为树在键发生变化时重新求值。
5. **使用附加到分支的 Service 保持 Blackboard 最新**——它们仅在该分支处于活动状态时定期 tick
   （例如通过视线检查更新 `TargetActor`）。
6. **在 Task 中执行工作**，它们返回 `Succeeded`、`Failed` 或 `InProgress`（像 `MoveTo`
   这样的 latent task 会在稍后完成）。
7. **验证：** 在 PIE 期间使用 Behavior Tree 调试器——它会突出显示正在运行的节点并展示实时
   Blackboard 值，因此可以准确看到正在执行哪个分支。

## 模式

### 1. 运行行为树的 AIController（C++）

```cpp
void AEnemyAIController::OnPossess(APawn* InPawn)
{
    Super::OnPossess(InPawn);
    if (BehaviorTree)                 // UPROPERTY(EditAnywhere) TObjectPtr<UBehaviorTree>
        RunBehaviorTree(BehaviorTree); // initializes & uses the Blackboard the BT references
}
```

### 2. 优先级行为树（节点结构）

```text
ROOT
└── Selector (try combat, else investigate, else patrol)
    ├── Sequence            [Decorator: Blackboard 'TargetActor' Is Set, Observer Aborts: Both]
    │     ├── Task: MoveTo (TargetActor)          // latent: returns InProgress then Succeeded
    │     └── Task: Attack
    ├── Sequence            [Decorator: 'LastKnownLocation' Is Set]
    │     ├── Task: MoveTo (LastKnownLocation)
    │     └── Task: Wait (3s) + clear key
    └── Task: Patrol (BTTask_FindPatrolPoint -> MoveTo)
```

`Observer Aborts: Both` 会在 `TargetActor` 被设置的瞬间让战斗分支中断巡逻，并在该键被清除时
退出战斗分支——这正是让 AI 显得反应灵敏的机制。

### 3. 从代码更新 Blackboard（例如看到玩家时）

```cpp
void AEnemyAIController::SetTarget(AActor* Target)
{
    if (UBlackboardComponent* BB = GetBlackboardComponent())
        BB->SetValueAsObject(TEXT("TargetActor"), Target);   // key name must match the BB asset
}
// Clear with BB->ClearValue(TEXT("TargetActor")); to drop back to a lower-priority branch.
```

## 常见陷阱

- **AI 从未启动**——pawn 未被接管（将 Pawn 的 *Auto Possess AI* 设置为 "Placed
  in World or Spawned" 并指定 AIController），或者从未调用 `RunBehaviorTree`。
- **`MoveTo` 立即失败**——关卡中没有 NavMesh（添加 Nav Mesh Bounds Volume），或者目标位于
  navmesh 之外。
- **分支不响应变化**——控制准入的 Decorator 的 **Observer Aborts** 被设置为 None；将其设置为
  Self/Lower Priority/Both，使行为树在键发生变化时重新求值。
- **task 使行为树卡住**——自定义 task 返回了 `InProgress`，但从未调用
  `FinishLatentTask`。务必完成 latent task。
- **Blackboard 键拼写错误**——`SetValueAsObject("Taget", ...)` 会静默地不执行任何操作；请精确匹配
  键名和类型，或使用缓存的 `FBlackboardKeySelector`。
- **混淆 Sequence 与 Selector**——Sequence = AND（遇到第一个失败时停止）；Selector = OR
  （遇到第一个成功时停止）。将它们互换会反转行为。

## 参考资料

- 关于**自定义 C++ `UBTTaskNode`**（即时和 latent `ExecuteTask` 返回 `EBTNodeResult`，
  并使用 `FBlackboardKeySelector`），请阅读 `references/custom-bttask.md`。
- 主要文档："Behavior Trees in Unreal Engine"
  (`https://dev.epicgames.com/documentation/en-us/unreal-engine/behavior-trees-in-unreal-engine`)。

## 相关 skill

- `game-ai` — 与引擎无关的 AI 设计（FSM、BT、steering、寻路方案选择）。
- `unreal-cpp-gameplay` — C++ 中的 AIController 和 pawn 类。
- `fps-shooter` / `tower-defense` — 组合使用敌人 AI 的游戏类型。
