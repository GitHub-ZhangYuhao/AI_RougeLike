---
name: unity-animation
description: >
  使用 Animator Controller 驱动 Unity 6.3 LTS 角色动画：状态、过渡、参数、混合树、动画层和
  人形 Avatar IK。适用于连接 Animator、从脚本设置参数（SetFloat/SetBool/SetTrigger）、
  构建混合树，或用户提到 Animator、Mecanim、状态机、混合树或 .controller 时。
---

# Unity 动画（Animator / Mecanim）

使用 Unity 6.3 LTS 的 `Animator` 和 Animator Controller 控制动画状态：参数、过渡、
混合树、动画层和人形 IK。面向 **Unity 6.3 LTS (6000.3)**。

## 何时使用

- 适用于将动画剪辑连接到状态机、通过参数从脚本驱动动画、混合移动动画
  （idle→walk→run）、在移动之上叠加上半身动作，或为人形骨骼添加脚部/手部 IK。
- 适用于项目包含 `*.controller`（Animator Controller）和 `*.anim` 资源，或包含
  带 Avatar 的已绑定模型时。

**何时不应使用：**简单的非骨骼数值补间（UI 淡入淡出、位置线性插值）更适合
使用补间/协程——参见 `unity-csharp-scripting`。Timeline 过场动画是单独的工具。
2D 精灵逐帧动画也使用 Animator，但使用的是精灵关键帧。

## 核心工作流

1. **添加 `Animator`** 到模型并分配 Animator Controller；对于人形模型，
   将其骨骼设置为 **Humanoid**，使其拥有 Avatar（启用重定向和 IK）。
2. **在 Controller 上定义参数**——`Float`（Speed）、`Bool`（IsGrounded）、`Int`、
   `Trigger`（Jump）——并创建带过渡的状态，其*条件*读取这些参数。
3. **从脚本设置参数**，绝不要直接干预状态：`SetFloat`、`SetBool`、
   `SetInteger`、`SetTrigger`。状态机会替你解析过渡。
4. **使用 Blend Tree 混合连续动作**（用一个 `Float`，如 Speed，驱动 idle↔walk↔run），
   而不是使用大量离散状态和过渡。
5. **分层叠加 Additive/Override 动作**（例如带 Avatar Mask 的上半身“瞄准”层），
   并控制其 `layerWeight`。
6. **在 Play 模式下通过 Animator 窗口验证**——当前状态会高亮显示，参数值也会更新，
   因此可以准确看到哪个过渡已触发（或未触发）。

## 模式

### 1. 从脚本驱动移动与一次性动作

```csharp
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class CharacterAnim : MonoBehaviour
{
    private Animator _anim;
    // Cache parameter hashes — faster and typo-proof vs string lookups every frame.
    private static readonly int Speed     = Animator.StringToHash("Speed");
    private static readonly int IsGrounded= Animator.StringToHash("IsGrounded");
    private static readonly int Jump      = Animator.StringToHash("Jump");

    private void Awake() => _anim = GetComponent<Animator>();

    public void Tick(float planarSpeed, bool grounded)
    {
        _anim.SetFloat(Speed, planarSpeed);     // drives a 1D blend tree (idle/walk/run)
        _anim.SetBool(IsGrounded, grounded);    // gates a falling/landing transition
    }

    public void DoJump() => _anim.SetTrigger(Jump);  // fire-and-forget; auto-resets after use
}
```

### 2. 将有噪声的输入平滑为混合参数

```csharp
// dampTime smooths Speed so the blend tree doesn't snap; great for analog sticks.
_anim.SetFloat(Speed, targetSpeed, 0.1f /* dampTime */, Time.deltaTime);
```

### 3. 直接播放状态或交叉淡化（绕过参数条件）

```csharp
// Useful for hit reactions where you want an immediate, explicit transition.
_anim.CrossFade("Hit", 0.1f);                    // blend over 0.1s normalized
// Or jump instantly:  _anim.Play("Hit");
```

### 4. 等待当前状态结束

```csharp
private System.Collections.IEnumerator AfterAttack()
{
    var info = _anim.GetCurrentAnimatorStateInfo(0);   // layer 0
    yield return new WaitForSeconds(info.length);      // approximate clip length
    // ...follow-up logic
}
```

## 常见陷阱

- **`SetTrigger` 被错过或“卡住”**——触发器会被下一个满足条件的过渡消耗并自动重置；
  如果没有过渡消耗它，它可能会在之后意外触发。使用 `ResetTrigger` 清除它；如果条件
  表示持续状态，则优先使用 `Bool`。
- **字符串参数拼写错误会静默失败**——名称拼错时不会执行任何操作。使用
  `Animator.StringToHash` 并缓存 int 哈希值。
- **过渡感觉迟缓**——`Has Exit Time` 会使过渡等待剪辑到达指定的归一化时间。
  对需要快速响应、由条件驱动的过渡（跳跃、受击），应取消勾选它。
- **角色滑动或无法移动**——`Apply Root Motion` 已开启，但代码也在移动 transform
  （反之亦然）。二选一：根运动或脚本移动，不要同时使用。
- **上半身层覆盖了全身**——设置该层的 Blend 模式（Override 或 Additive），
  分配 Avatar Mask，并调整 `layerWeight`（0–1）。
- **IK 不起作用**——IK 仅在 `OnAnimatorIK` 内应用，需要在该层启用“IK Pass”，
  并且需要 Humanoid Avatar。

## 参考资料

- 有关**混合树**（1D 与 2D Freeform/Directional）、**动画层和 Avatar Mask**，
  以及**人形 IK**（`OnAnimatorIK`、`SetIKPositionWeight`、`SetIKPosition`、look-at），请阅读
  `references/blend-trees-and-ik.md`。
- 主要文档：Unity Manual 的“Animation”章节和 `ScriptReference/Animator`。

## 相关技能

- `unity-csharp-scripting`——上文使用的 MonoBehaviour 和协程计时。
- `unity-physics`——移动动画所呈现的身体。
- `game-ai`——决定*何时*播放哪个动画状态。
