---
name: unity-input-system
description: >
  使用 Input System 包在 Unity 6.3 LTS 中连接玩家输入：Input Actions、action maps、
  PlayerInput 组件，以及通过回调或轮询读取值。适用于项目包含 .inputactions 资源或
  com.unity.inputsystem，或用户提到 Unity Input System、InputAction、action maps、
  PlayerInput、control schemes 或重新绑定时。
---

# Unity Input System（新）

通过 Unity 的 **Input System 包**（`com.unity.inputsystem`, 1.x）读取输入——
基于动作、与设备无关且可重新绑定。面向 **Unity 6.3 LTS**。它是旧版
`Input.GetAxis`/`Input.GetKey` Input Manager 的现代替代方案。

## 何时使用

- 适用于设置移动/跳跃/射击输入、定义带 action maps 和 control schemes 的
  `.inputactions` 资源、连接 `PlayerInput` 组件、读取 `Vector2` 摇杆/WASD 值，
  或使用同一组 actions 处理游戏手柄、键盘和触摸输入。
- 适用于 `Packages/manifest.json` 包含 `com.unity.inputsystem`，或项目包含
  `*.inputactions` 资源时。

**何时不应使用：**跨引擎的可重绑定控制*架构* → `input-systems`（本技能针对 Unity API）。
获得输入向量后移动角色 → `unity-physics` / `unity-csharp-scripting`。

## 核心工作流

1. **检查 Active Input Handling**（Project Settings → Player）。仅当该项为
   `Input System Package (New)` 或 `Both` 时，此包才能接收输入。如果仍有旧版
   `Input.GetAxis` 代码，则必须使用 `Both`。
2. **创建 `.inputactions` 资源。**添加一个 *action map*（例如 `Gameplay`），添加
   *actions*（`Move` = Value/Vector2、`Jump` = Button、`Fire` = Button），并将它们
   绑定到控件和复合绑定（WASD = 2D Vector composite）。
3. **选择读取方式：**
   - **`PlayerInput` 组件**（方便设计师使用）——将其放到玩家对象上，指向资源，
     选择 *Behavior*（Send Messages / Broadcast / Invoke Unity Events / Invoke C# Events）。
     最适合单人/本地合作玩家。
   - **直接在代码中使用**（`InputActionReference` / `InputActionAsset`）——控制力最强；
     需要 `Enable()` actions 并读取它们。最适合系统和工具。
4. **启用所读取的 actions/maps。**`PlayerInput` 会自动启用其默认 map；
   自己引用的 actions 必须调用 `.Enable()`（并在销毁时禁用）。
5. **根据上下文切换 action maps**（游戏 ↔ UI/菜单），而不是为每个处理程序添加条件保护。
6. **使用 Input Debugger 验证**（Window → Analysis → Input Debugger），确认设备存在且 actions 会触发。

## 模式

### 1. 使用“Send Messages”的 `PlayerInput`（处理程序位于同一 GameObject 上）

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

// PlayerInput (Behavior = Send Messages) calls On<ActionName>(InputValue) by name.
public class PlayerInputReceiver : MonoBehaviour
{
    private Vector2 _move;

    private void OnMove(InputValue value) => _move = value.Get<Vector2>();   // Move action
    private void OnJump(InputValue value) { if (value.isPressed) Jump(); }   // Button action

    private void Update() { /* drive movement from _move */ }
    private void Jump() { }
}
```

### 2. 直接在代码中读取 action（轮询值）

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class DirectMover : MonoBehaviour
{
    [SerializeField] private InputActionReference moveAction;  // assign the Move action

    private void OnEnable()  => moveAction.action.Enable();    // REQUIRED or it reads zero
    private void OnDisable() => moveAction.action.Disable();

    private void Update()
    {
        Vector2 move = moveAction.action.ReadValue<Vector2>(); // continuous value
        transform.Translate(new Vector3(move.x, 0, move.y) * (5f * Time.deltaTime));
    }
}
```

### 3. 事件回调与切换 action maps（游戏 ↔ UI）

```csharp
[SerializeField] private InputActionAsset actions;

private void OnEnable()
{
    actions.FindAction("Gameplay/Fire").performed += OnFire;  // edge event: fires once
    actions.FindActionMap("Gameplay").Enable();
}
private void OnDisable() => actions.FindAction("Gameplay/Fire").performed -= OnFire;

private void OnFire(InputAction.CallbackContext ctx) => Shoot();  // ctx.ReadValue<T>() if needed

private void OpenPauseMenu()                       // change context, don't sprinkle if-checks
{
    actions.FindActionMap("Gameplay").Disable();
    actions.FindActionMap("UI").Enable();
}
private void Shoot() { }
```

## 常见陷阱

- **完全没有输入** → Active Input Handling 仍为 `Input Manager (Old)`，或忘记对 action/map
  调用 `Enable()`。`PlayerInput` 会自动启用；原始 `InputAction` 不会。
- **出现与旧输入后端有关的 `InvalidOperationException`** → Active Input Handling 为 `New`，
  但某些脚本仍在调用 `Input.GetAxis`/`Input.GetKey`。迁移代码或设置为 `Both`。
- **使用 `ReadValue` 读取按钮时结果为 0** → 按钮*按下*是边沿事件；对触发器使用
  `performed` 回调（或 `WasPressedThisFrame()`），而不是逐帧 `ReadValue`。
- **`Send Messages` 处理程序从不触发** → 接收脚本必须与 `PlayerInput` 位于*同一*
  GameObject 上；`Broadcast Messages` 还会传递到子对象。
- **订阅泄漏** → 在 `OnDisable` 中取消订阅（`-=`）；如果在 `OnEnable` 中重复订阅
  却不取消，会导致处理程序重复执行。
- **未检测到触摸/游戏手柄** → 启用匹配的 control scheme，并在 Input Debugger 中确认设备；
  Vector2 composite 需要设置全部四个绑定。

## 参考资料

- 有关交互式控件**重新绑定**（`PerformInteractiveRebinding`）、以 JSON 保存/加载绑定，
  以及使用 `PlayerInputManager` 实现**本地多人游戏**，请阅读 `references/rebinding.md`。
- 主要文档：Unity Manual“Input System”
  （`https://docs.unity3d.com/Manual/com.unity.inputsystem.html`）。

## 相关技能

- `input-systems`——与引擎无关的输入架构（重新绑定、缓冲、多设备）。
- `unity-csharp-scripting`——这些处理程序所在的 MonoBehaviour。
- `unity-physics`——将输入向量应用到 Rigidbody。
