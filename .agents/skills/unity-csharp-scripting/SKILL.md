---
name: unity-csharp-scripting
description: >
  编写 Unity 6.3 LTS C# 玩法脚本：MonoBehaviour 生命周期
  （Awake/OnEnable/Start/Update/FixedUpdate/LateUpdate）、GameObject 和组件访问、
  协程以及 Inspector 序列化。适用于在 Unity 项目中创建或编辑 .cs 脚本，或用户提到
  MonoBehaviour、Start/Update、GetComponent、SerializeField、协程或“Unity 脚本”时。
---

# Unity C# 脚本（MonoBehaviour）

在 Unity 6 中编写正确且符合惯例的玩法脚本。正确处理生命周期、组件访问、序列化和协程，
使行为具有确定性，并保持 Inspector 易用。面向 **Unity 6.3 LTS (6000.3)**、C# / .NET Standard 2.1。

## 何时使用

- 适用于编写或修复 `MonoBehaviour`：选择正确的生命周期回调、读取/缓存组件、
  向 Inspector 公开字段，或使用协程运行定时逻辑。
- 适用于项目包含 `*.cs` 文件、`Assembly-CSharp` 或 `*.asmdef`，以及
  `ProjectSettings/` 文件夹时。

**何时不应使用：**移动刚体/碰撞响应 → `unity-physics`；读取玩家输入 →
`unity-input-system`；共享数据资源/配置 → `unity-scriptableobjects`；Animator 参数 →
`unity-animation`。本技能负责*脚本生命周期和 C# 连接代码*，而非这些子系统。

## 核心工作流

1. **根据用途而非习惯选择回调。**`Awake`（缓存引用，加载时运行一次）、
   `OnEnable`（订阅事件）、`Start`（依赖其他对象 `Awake` 的初始化）、
   `Update`（逐帧逻辑/输入轮询）、`FixedUpdate`（物理）、`LateUpdate`
   （移动完成后的相机跟随）、`OnDisable`/`OnDestroy`（取消订阅/清理）。
2. **在 `Awake` 中缓存组件查询**——绝不要每帧调用 `GetComponent`。
3. **使用 `[SerializeField] private` 公开可调参数**，而不是 public 字段；这样其他代码
   无法修改它们，但设计师仍可在 Inspector 中编辑。
4. **在 `Update` 中用 `Time.deltaTime` 缩放逐帧值**（`FixedUpdate` 中会自动采用
   `Time.fixedDeltaTime` 语义）。
5. **使用协程处理按时间排序的逻辑**（延迟、补间、“执行 X、等待、再执行 Y”）；
   使用 `StartCoroutine` 启动，并以确定方式停止。
6. **在 Play 模式中验证**：检查 Console 是否存在空引用异常，确认 Inspector 中的值
   按预期更新；如果 `Update` 开销较大，则查看 Profiler。

## 模式

### 1. 生命周期与缓存组件（标准骨架）

```csharp
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]      // auto-adds the dependency, prevents null refs
public class PlayerController : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 6f;   // editable in Inspector, private in code
    private Rigidbody _rb;                            // cached, not fetched per frame

    private void Awake() => _rb = GetComponent<Rigidbody>();  // cache once on load

    private void Update()
    {
        // Per-frame, non-physics work. Scale by deltaTime so it is frame-rate independent.
        transform.Rotate(0f, 90f * Time.deltaTime, 0f);
    }

    private void FixedUpdate()
    {
        // Physics work belongs here (fixed timestep). See the unity-physics skill.
        _rb.MovePosition(_rb.position + transform.forward * moveSpeed * Time.fixedDeltaTime);
    }
}
```

### 2. 使用 `TryGetComponent` 安全访问组件

```csharp
// Avoids allocating a null and is clearer than GetComponent + null check.
if (other.TryGetComponent<Health>(out var health))
    health.Apply(-10);
```

### 3. 在 Inspector 中正确显示的序列化

```csharp
[SerializeField, Range(0f, 1f)] private float volume = 0.8f;  // slider
[SerializeField] private string playerName = "Hero";          // private but serialized

[System.Serializable]                 // REQUIRED for a plain class to serialize/show
public class Stats { public int hp = 100; public int mana = 50; }

[SerializeField] private Stats stats = new();  // nested struct-like data in the Inspector
```

### 4. 使用协程处理按时间排序的逻辑

```csharp
private void Start() => StartCoroutine(FlashThenHide());

private System.Collections.IEnumerator FlashThenHide()
{
    yield return new WaitForSeconds(0.5f);   // wait half a second of game time
    GetComponent<Renderer>().enabled = false;
    yield return null;                       // resume next frame
}
```

## 常见陷阱

- **在 `Update` 中调用 `GetComponent`**——它每帧都会搜索，严重影响性能。请在
  `Awake`/`Start` 中缓存引用。
- **在 `Update` 中处理物理**——在 `FixedUpdate` 之外用力或 `MovePosition` 移动
  `Rigidbody` 会造成抖动和依赖时间步长的行为。在 `Update` 中读取输入，
  在 `FixedUpdate` 中应用物理。
- **依赖不同对象间的 `Start` 顺序**——`Start` 在*所有* `Awake` 之后运行，
  但各 `Start` 之间的顺序未定义。跨对象连接放在 `Start` 中，自身设置放在 `Awake` 中。
- **仅为在 Inspector 中显示而使用 `public` 字段**——这也允许任何脚本修改它们。
  应改用 `[SerializeField] private`。
- **`gameObject.tag == "Enemy"`** 会分配字符串且速度较慢；请使用
  `gameObject.CompareTag("Enemy")`。
- **禁用 GameObject 时协程会停止**——已禁用对象的协程会被终止；如果切换启用状态后
  必须继续，请在 `OnEnable` 中重新调用 `StartCoroutine`。
- **`Update` 绝不会在 `Start` 之前运行，但*第一次* `Update` 可以与 `Start` 在同一帧运行**
  ——如果初始化被异常拆分，请防范字段尚未初始化。

## 参考资料

- 如需完整的事件执行顺序表和高级协程模式（自定义 `CustomYieldInstruction`、
  按句柄停止、`WaitUntil`/`WaitWhile`），请阅读 `references/lifecycle-and-coroutines.md`。
- 主要文档：Unity Manual“Event function execution order”
  （`https://docs.unity3d.com/Manual/execution-order.html`）和 `ScriptReference/MonoBehaviour`。

## 相关技能

- `unity-physics`——`Rigidbody`、碰撞和 `FixedUpdate` 移动。
- `unity-input-system`——将玩家输入读入这些脚本。
- `unity-scriptableobjects`——无需单例即可在脚本间共享数据/配置。
