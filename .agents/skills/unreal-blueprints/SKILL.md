---
name: unreal-blueprints
description: >
  使用 Blueprint 可视化脚本构建 Unreal Engine 5 玩法：Blueprint Class、Event Graph 和
  Construction Script、变量/函数/宏，以及 Blueprint 通信（Cast、Interface、Event Dispatcher）。
  适用于使用 Blueprint、连接 event graph、决定 Blueprint 之间如何通信，或用户提及
  Blueprint、BP、event graph、construction script 或 Blueprint .uasset 时。
---

# Unreal Blueprint（可视化脚本）

在 Unreal Engine 5 Blueprint 中组织玩法逻辑：选择正确的 graph、清晰地公开数据，并选择不会
造成硬引用混乱的通信方式。目标版本为 **UE 5.8**。（Blueprint 是节点 graph；以下片段描述节点流。）

## 何时使用

- 编写 Blueprint Class、连接 Event Graph（BeginPlay/Tick/overlap）、使用 Construction Script、
  创建变量/函数/宏，或选择两个 Blueprint 的通信方式（Cast、Interface 或 Event Dispatcher）时使用。
- 当项目具有 `*.uproject` 和 Blueprint `*.uasset` 文件，且用户以可视化方式而非 C++ 工作时使用。

**不应使用的场景：** 性能关键系统、大型数据结构，或任何受益于源代码管理 diff 和单元测试的内容
→ `unreal-cpp-gameplay`。玩家输入映射 → `unreal-enhanced-input`。AI 逻辑 →
`unreal-behavior-trees`。

## 核心工作流

1. **选择 Blueprint 类型。** **Blueprint Class**（派生自 Actor/Pawn/Character/ActorComponent）
   定义可复用对象。**Level Blueprint** 是仅用于关卡特定脚本的单关卡 graph——不要把可复用逻辑放在那里。
2. **使用 Construction Script 进行编辑器阶段的设置**（程序化放置、根据变量配置 component）——
   它在 actor 被放置或编辑时运行，*不会*在游戏运行期间执行。
3. **使用 Event Graph 编写运行时逻辑。** 使用 `Event BeginPlay` 初始化，使用 input/overlap event
   做出响应。除非确实需要逐帧工作，否则避免使用 `Event Tick`。
4. **使用变量公开数据**；单击眼睛图标使变量 Instance Editable，并使用 category 对相关变量分组。
   将用于 getter 的函数标记为 **pure**（无 exec pin）。
5. **根据耦合度选择通信方式**（参见“模式”）：对自己拥有的对象使用直接 **Cast**；使用
   **Blueprint Interface** 跨类型调用而不产生硬引用；使用 **Event Dispatcher** 进行一对多广播。
6. **验证：** 使用 Blueprint 调试器，在节点上设置 breakpoint、观察变量值，并在 Play In Editor
   （PIE）期间使用 Print String 确认执行路径。

## 模式

### 1. 响应式 Event Graph（无 Tick）

```text
Event BeginPlay
  -> Set 'StartLocation' = GetActorLocation
  -> Bind Event to OnComponentBeginOverlap (TriggerVolume) [calls custom event OnEnterZone]

OnEnterZone (Other Actor)
  -> Branch: Other Actor == Player?
       True  -> Open Door (Timeline drives the rotation)   // event-driven, runs once
```

优先使用 event（overlap、timer、dispatcher）和 Timeline，而不是在 Tick 中轮询。

### 2. 直接引用 + Cast（紧耦合，谨慎使用）

```text
Overlapped Actor (Actor ref)
  -> Cast To BP_Player
       Cast Failed -> (do nothing)
       Success     -> call BP_Player.ApplyDamage(10)
```

`Cast To` 会创建对该类的硬引用（该类会随此 Blueprint 一起加载）。当调用方确实依赖该类型时可以使用；
否则优先使用 Interface。

### 3. Blueprint Interface（解耦调用）

```text
// 1. Create BPI_Interactable with function 'Interact(Instigator)'.
// 2. Add the interface to BP_Door, BP_Chest, BP_Lever and implement 'Interact' in each.
// 3. Caller, with any Actor ref:
Player presses Use
  -> Does Object Implement Interface (BPI_Interactable)?  // safe check, no Cast/hard ref
       True -> Interact (Message) on Target Actor
```

### 4. Event Dispatcher（一对多广播）

```text
// In BP_Player: declare Event Dispatcher 'OnHealthChanged (float NewHealth)'.
TakeDamage -> Set Health -> Call 'OnHealthChanged' (Health)   // broadcast

// In WBP_HUD BeginPlay: Bind Event to 'OnHealthChanged' -> update health bar.
// Many listeners can bind; the player never references them.
```

## 常见陷阱

- **Cast 混乱/加载时间过长**——`Cast To` 链会创建硬引用，将整棵资产树载入内存。使用 Interface
  或 Dispatcher 解耦。
- **本应复用的逻辑放在 Level Blueprint 中**——它无法跨关卡复用。请将其放入 Blueprint Class。
- **过度使用 `Event Tick`**——逐帧节点的开销会迅速累积。改用 event、Timer
  （`Set Timer by Event`）和 Timeline。
- **Construction Script 执行玩法逻辑**——它会在编辑器中编辑/放置对象时运行；在其中生成玩法 actor
  或启动逻辑会产生仅存在于编辑器中的异常。请在 BeginPlay 中初始化。
- **实例上看不到变量**——启用 Instance Editable（眼睛图标）；若要通过 Spawn 节点在生成前编辑，
  还要标记 "Expose on Spawn"。
- **Interface 调用没有效果**——目标未实现该 interface；调用前使用 "Does Implement Interface"，
  或使用对未实现者也安全的 Message 版本。

## 参考资料

- 关于 **Cast、Interface 与 Event Dispatcher 的选择指南**以及逐步绑定 dispatcher 的方法，
  请阅读 `references/communication.md`。
- 主要文档："Blueprints Visual Scripting"
  (`https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-blueprints-visual-scripting-in-unreal-engine`)。

## 相关 skill

- `unreal-cpp-gameplay` — 何时改用 C++；BP 与 C++ 类如何互操作。
- `unreal-enhanced-input` — 将输入 event 传入这些 graph 的现代方式。
- `unreal-behavior-trees` — 由 Blueprint 触发的 AI 决策逻辑。
