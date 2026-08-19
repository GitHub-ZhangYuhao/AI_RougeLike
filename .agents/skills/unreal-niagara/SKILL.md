---
name: unreal-niagara
description: >
  使用 Niagara 在 Unreal Engine 5 中创建和控制 VFX：system 与 emitter、module 和 spawn/update
  阶段、公开的 User parameter，以及从 Blueprint 或 C++ 生成或驱动特效。适用于构建粒子特效、
  NS_/NE_ 资产、在运行时生成 Niagara system、设置 User parameter，或用户提及 Niagara、VFX
  或 Unreal 中的 particle system 时。
---

# Unreal Niagara VFX

使用 Niagara 在 UE5 中构建并控制实时视觉特效：理解 System/Emitter/Module 层级结构，公开可由玩法
驱动的 parameter，并在运行时生成特效。目标版本为 **UE 5.8**。（Niagara 取代了旧版 Cascade 系统。）

## 何时使用

- 创建 Niagara System（`NS_`）和 Emitter（`NE_`）、在 spawn/update 阶段连接 module、
  向玩法公开 **User** parameter，或从 Blueprint 或 C++ 生成/驱动特效（命中、枪口火焰、
  火焰、魔法）时使用。
- 当项目具有 Niagara `NS_`/`NE_` 资产或引用 `UNiagaraComponent` 时使用。

**不应使用的场景：** material/shader 编写（表面的视觉效果，而非粒子）是另一个主题；
`shader-programming` 涵盖跨引擎 shader 概念。特效的音频 → `audio-design`。

## 核心工作流

1. **理解层级结构。** **Niagara System**（`NS_`）是放置/生成的特效；它包含一个或多个
   **Emitter**（`NE_`，通常是 emitter *template*）。每个 emitter 分阶段运行：
   **Emitter Spawn/Update**、**Particle Spawn/Update**、可选的 **Event Handler** 和 **Render**。
2. **使用 Module 构建行为**；它们在每个阶段中从上到下执行（Spawn Rate、Add Velocity、
   Gravity Force、Color over Life 等）。顺序很重要——后面的 module 会读取前面的 module 写入的值。
3. **了解 parameter namespace：** `System`、`Emitter`、`Particle` 和 **`User`**。只有
   **User namespace** 中的 parameter 会公开给 Blueprint/C++ 并可从中设置；其他 parameter
   属于模拟内部。
4. **在运行时生成**：使用 `UNiagaraFunctionLibrary::SpawnSystemAtLocation`（世界位置）或
   `SpawnSystemAttached`（跟随 component/socket），它们会返回 `UNiagaraComponent`。
5. **驱动特效**：在返回的 component 上设置其 User parameter（颜色、spawn rate、目标位置），
   并对其调用 `Activate`/`Deactivate`。
6. **验证：** 在 Niagara 编辑器预览和关卡中检查；检查 bounds（尤其是 GPU emitter），并确认
   特效能正确剔除/销毁。

## 模式

### 1. 在世界位置生成一次性特效（C++）

```cpp
#include "NiagaraFunctionLibrary.h"
#include "NiagaraComponent.h"

// ImpactSystem is a UPROPERTY(EditAnywhere) TObjectPtr<UNiagaraSystem>.
void AProjectile::SpawnImpact(const FVector& Location, const FRotator& Rotation)
{
    UNiagaraComponent* FX = UNiagaraFunctionLibrary::SpawnSystemAtLocation(
        GetWorld(), ImpactSystem, Location, Rotation);
    // FX auto-destroys when finished for a one-shot (system marked non-looping).
}
```

### 2. 附加到 socket 生成（跟随枪械的枪口火焰）

```cpp
UNiagaraComponent* Muzzle = UNiagaraFunctionLibrary::SpawnSystemAttached(
    MuzzleSystem, WeaponMesh, FName("MuzzleSocket"),
    FVector::ZeroVector, FRotator::ZeroRotator,
    EAttachLocation::SnapToTarget, /*bAutoDestroy*/ true);
```

### 3. 在运行时驱动公开的 User parameter

```cpp
// Only User-namespace parameters can be set from gameplay. Names match the User parameter.
if (UNiagaraComponent* Fire = UNiagaraFunctionLibrary::SpawnSystemAttached(
        FireSystem, RootComponent, NAME_None, FVector::ZeroVector, FRotator::ZeroRotator,
        EAttachLocation::KeepRelativeOffset, /*bAutoDestroy*/ false))
{
    Fire->SetVariableFloat(FName("SpawnRate"), 250.f);                 // User.SpawnRate
    Fire->SetVariableLinearColor(FName("FireColor"), FLinearColor::Red);
}
```

### 4. 等效 Blueprint（节点流）

```text
Spawn System at Location (System = NS_Impact, Location, Rotation)  -> returns Niagara Component
On the returned component:
  Set Niagara Variable (Float)  Name="SpawnRate"  Value=250
  Set Niagara Variable (LinearColor)  Name="FireColor"  Value=Red
```

## 常见陷阱

- **尝试从玩法设置 System/Emitter/Particle parameter**——不会生效。请在 **User** namespace 中
  公开它；只有 User parameter 能通过 component 设置。
- **使用 Cascade 教程**——Cascade 已过时/弃用。Niagara 是当前系统；其 emitter/module 工作流不同。
- **特效消失或剔除不正确**——bounds 固定或不正确，尤其是需要显式 Fixed Bounds 的
  **GPU Compute** emitter。请在 emitter/system 上设置 bounds。
- **循环特效永不停止**——使用 `bAutoDestroy = false` 生成后从未调用 `Deactivate()`；
  请管理返回 component 的生命周期，或将 system 标记为非循环以用于一次性特效。
- **GPU sim 无法驱动玩法**——GPU 粒子数据不容易回读到 CPU；玩法必须响应的碰撞/event 应使用
  CPU emitter（或通过 data interface 从 Niagara → 玩法），而不是 GPU。
- **Module 顺序错误**——Force/Velocity module 放在初始化该值的 module 之前会读取到零。
  请注意从上到下的 stack 顺序。

## 参考资料

- 主要文档："Overview of Niagara Effects"
  (`https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-niagara-effects-for-unreal-engine`)
  以及 `UNiagaraFunctionLibrary` / `UNiagaraComponent` API。若要从 C++ 访问，请将 `Niagara` 模块
  添加到 `*.Build.cs`。

## 相关 skill

- `shader-programming` — 粒子 material 的 material/shader 概念。
- `unreal-cpp-gameplay` — 从玩法代码生成特效并设置模块。
- `unreal-blueprints` — 从可视化脚本触发特效。
