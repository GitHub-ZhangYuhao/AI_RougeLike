---
name: unity-physics
description: >
  在 Unity 6.3 LTS 中设置 3D 物理：Rigidbody 移动与力、碰撞体、触发器与碰撞、
  基于层的碰撞、射线投射和关节。适用于添加 Rigidbody、处理
  OnCollisionEnter/OnTriggerEnter、调整碰撞层、投射射线，或用户提到 Unity 物理、
  AddForce、isKinematic 或 linearVelocity 时。
---

# Unity 物理（Rigidbody / PhysX）

使用 Unity 6.3 LTS 的内置 3D 物理（PhysX）使对象移动、碰撞并相互检测。
正确处理 `FixedUpdate` 规范、触发器与碰撞规则以及碰撞层。面向 **Unity 6.3 LTS (6000.3)**。

> **Unity 6.3 LTS 重命名：**`Rigidbody.velocity` 现已改为 **`Rigidbody.linearVelocity`**
>（旧名称已弃用）。从旧教程复制的代码会产生警告或编译失败。

## 何时使用

- 适用于为对象提供物理运动（力、速度、重力）、响应碰撞或触发器、设置碰撞层/遮罩、
  通过射线投射检查地面或视线，或使用关节连接刚体时。
- 适用于场景/预制体包含 `Rigidbody` 和 `Collider` 组件时。

**何时不应使用：**2D 物理（`Rigidbody2D`、`Collider2D`）使用单独的 API——概念可以借鉴，
但类型不同。跨引擎的*手感*调整（时间步长、抖动、穿透）→ `physics-tuning`。
读取驱动移动的输入 → `unity-input-system`。

## 核心工作流

1. **向需要模拟的对象添加 `Rigidbody`**；向需要被命中的对象添加 `Collider`。
   碰撞双方都需要 `Collider`，并且至少一方需要 `Rigidbody`。
2. **在 `FixedUpdate` 中处理所有物理。**在 `Update` 中读取输入并存储意图，
   然后在 `FixedUpdate` 中施力、设置 `linearVelocity` 或调用 `MovePosition`。
3. **通过物理 API 而非 Transform 移动刚体。**使用 `AddForce`、`linearVelocity`
   或 `MovePosition`——绝不要为非运动学 Rigidbody 分配 `transform.position`
   （这会瞬移并破坏碰撞解析）。
4. **选择碰撞或触发器。**实体碰撞会阻挡并调用 `OnCollisionEnter`；勾选 `Is Trigger`
   的 `Collider` 会穿过并调用 `OnTriggerEnter`。
5. **使用层组织交互。**将对象放到不同层，并编辑 Layer Collision Matrix
   （Project Settings → Physics），避免无关对象相互进行检测。
6. **使用 Physics Debugger 验证**（Window → Analysis → Physics Debugger）并观察是否抖动；
   如果高速对象穿墙，请提高 Collision Detection 模式。

## 模式

### 1. `FixedUpdate` 中基于力的移动（带速度限制）

```csharp
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class Mover : MonoBehaviour
{
    [SerializeField] private float accel = 30f, maxSpeed = 8f;
    private Rigidbody _rb;
    private Vector3 _input;   // set from Update / input system

    private void Awake() => _rb = GetComponent<Rigidbody>();

    private void FixedUpdate()
    {
        _rb.AddForce(_input * accel, ForceMode.Acceleration);     // mass-independent accel
        // Unity 6.3 LTS: linearVelocity (was 'velocity'). Clamp horizontal speed.
        Vector3 flat = new(_rb.linearVelocity.x, 0, _rb.linearVelocity.z);
        if (flat.magnitude > maxSpeed)
        {
            flat = flat.normalized * maxSpeed;
            _rb.linearVelocity = new Vector3(flat.x, _rb.linearVelocity.y, flat.z);
        }
    }
}
```

`ForceMode`：`Force`（连续、受质量影响）、`Acceleration`（连续、忽略质量）、
`Impulse`（瞬时、受质量影响——跳跃）、`VelocityChange`（瞬时、忽略质量）。

### 2. 碰撞与触发器回调

```csharp
// Solid hit: both have colliders, this one has a (non-kinematic) Rigidbody.
private void OnCollisionEnter(Collision col)
{
    Debug.Log($"Hit {col.gameObject.name} at {col.contacts[0].point}");
}

// Overlap: one collider has 'Is Trigger' = true. Requires a Rigidbody on at least one party.
private void OnTriggerEnter(Collider other)
{
    if (other.CompareTag("Pickup")) Destroy(other.gameObject);
}
```

### 3. 使用带层遮罩的射线投射检查地面

```csharp
[SerializeField] private LayerMask groundMask;   // set to your "Ground" layer in the Inspector

private bool IsGrounded()
{
    // Cast a short ray down; only test colliders on groundMask.
    return Physics.Raycast(transform.position, Vector3.down, out RaycastHit hit,
                           1.1f, groundMask);
}
```

### 4. 仍可推动刚体的运动学平台

```csharp
// isKinematic Rigidbody: not driven by forces, but MovePosition interpolates and carries
// resting bodies correctly (unlike moving the Transform directly).
private void FixedUpdate() => _rb.MovePosition(_rb.position + Vector3.right * (2f * Time.fixedDeltaTime));
```

## 常见陷阱

- **Unity 6.3 LTS 中不存在 `Rigidbody.velocity`**——使用 `linearVelocity`
  （`angularVelocity` 保持不变）。
- **为动态 Rigidbody 设置 `transform.position`**——这会使其瞬移并跳过碰撞。
  使用 `MovePosition`（运动学/插值）或施加力。
- **在 `Update` 中施力**——这会依赖帧率并产生抖动。物理操作应放在 `FixedUpdate` 中。
- **触发器回调从不触发**——两个碰撞体中至少一个需要 `Rigidbody`，且两个碰撞体都要启用；
  两个静态触发器不会报告重叠。
- **高速对象穿墙（穿透）**——对于子弹/高速移动对象，将 Rigidbody 的 Collision Detection
  设置为 `Continuous`（或 `Continuous Dynamic`）。
- **非均匀缩放的 `MeshCollider` 或其他碰撞体**会行为异常；优先使用基本碰撞体并保持均匀缩放。
- **所有对象都相互碰撞**——浪费开销；分配层并精简 Layer Collision Matrix。

## 参考资料

- 有关射线投射变体（`SphereCast`、`RaycastAll`、`OverlapSphere`、`LayerMask` 位运算）
  和关节（`FixedJoint`、`HingeJoint`、`ConfigurableJoint`、可断裂关节），请阅读
  `references/raycasting-and-joints.md`。
- 主要文档：Unity Manual“Physics”章节，以及 `ScriptReference/Rigidbody`、
  `ScriptReference/Physics.Raycast`。

## 相关技能

- `physics-tuning`——与引擎无关的手感：固定时间步长、质量/阻力、CCD、稳定性。
- `unity-csharp-scripting`——这些模式依赖的 `FixedUpdate`/`Update` 分工。
- `unity-navmesh`——*不由*力驱动的代理移动。
