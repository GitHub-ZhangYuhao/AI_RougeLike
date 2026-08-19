---
name: unreal-cpp-gameplay
description: >
  编写 Unreal Engine 5 C++ 玩法代码：UCLASS/UPROPERTY/UFUNCTION 反射宏、Gameplay Framework
  （GameMode、Pawn、Character、PlayerController、Actor component）以及模块 Build.cs。
  适用于编写或调试 UE C++、派生 AActor/ACharacter/AGameModeBase、向编辑器或 Blueprint
  公开属性，或用户提及 Unreal C++、UCLASS、GENERATED_BODY、GameMode、ACharacter 或 .Build.cs 时。
---

# Unreal C++ 玩法

编写正确的 UE5 玩法 C++：了解连接 C++ 与编辑器和 Blueprint 的反射宏、Gameplay Framework
类职责以及模块依赖。目标版本为 **UE 5.8**。

## 何时使用

- 创建 C++ 玩法类（`AActor`、`APawn`、`ACharacter`、`AGameModeBase`、`UActorComponent`）、
  使用 `UPROPERTY`/`UFUNCTION` 公开属性/函数、设置 GameMode 的默认类，或在 `*.Build.cs`
  中添加模块依赖时使用。
- 当项目具有使用 `UCLASS` 的 `Source/` 目录树、`*.h`/`*.cpp` 以及 `*.Build.cs` 时使用。

**不应使用的场景：** 面向设计师的可视化逻辑 → `unreal-blueprints`。玩家输入绑定细节 →
`unreal-enhanced-input`。AI 逻辑 → `unreal-behavior-trees`。本 skill 负责这些功能所依赖的
C++ 类/反射基础。

## 核心工作流

1. **使用正确的前缀命名。** `A` = Actor 派生类，`U` = `UObject`/component 派生类，
   `F` = 普通 struct，`E` = enum，`I` = interface。前缀必须与基类匹配。
2. **使用反射宏声明类。** 在类上方放置 `UCLASS()`，将 `GENERATED_BODY()` 作为类体中的第一行，
   并将 `#include "ClassName.generated.h"` 作为头文件中的**最后一个** include。
3. **使用 `UPROPERTY` 公开数据**（编辑器/Blueprint 可见性*以及*垃圾回收跟踪），并使用
   `UFUNCTION`（`BlueprintCallable` 等）公开行为。
4. **在构造函数中使用 `CreateDefaultSubobject<T>(TEXT("Name"))` 创建 component**，并设置
   `RootComponent`。
5. **了解 framework 职责：** `AGameModeBase` 设置规则和默认类；`APawn`/`ACharacter` 是可控制的
   载体；`APlayerController` 表示玩家意图；`UActorComponent` 是可复用行为。
6. **向 `*.Build.cs` 添加模块依赖**（例如 `EnhancedInput`），否则会出现未解析符号的链接错误。
7. **验证：** 编译（函数体可使用 Live Coding `Ctrl+Alt+F11`；header/UPROPERTY 更改需要完整重建），
   并检查类/属性是否出现在编辑器中。

## 模式

### 1. 最小 Actor 类（头文件 + 源文件）

```cpp
// Pickup.h
#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Pickup.generated.h"          // MUST be the last include

UCLASS()
class MYGAME_API APickup : public AActor   // MYGAME_API = your module's export macro
{
    GENERATED_BODY()
public:
    APickup();

    // EditAnywhere = tweak per-instance & on the CDO; BlueprintReadWrite = BP get/set.
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Pickup")
    int32 ScoreValue = 10;

    // UPROPERTY on a UObject* pointer is what keeps it from being garbage-collected.
    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UStaticMeshComponent> Mesh;   // UE5: TObjectPtr instead of raw UStaticMeshComponent*

    UFUNCTION(BlueprintCallable, Category = "Pickup")
    void Collect();

protected:
    virtual void BeginPlay() override;
};
```

```cpp
// Pickup.cpp
#include "Pickup.h"
#include "Components/StaticMeshComponent.h"

APickup::APickup()
{
    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    RootComponent = Mesh;                     // the mesh is this actor's root
}

void APickup::BeginPlay() { Super::BeginPlay(); }   // always call Super
void APickup::Collect()   { Destroy(); }
```

### 2. GameMode 连接其默认类

```cpp
// MyGameMode.cpp — set in the constructor so the engine spawns your classes.
AMyGameMode::AMyGameMode()
{
    DefaultPawnClass      = AMyCharacter::StaticClass();
    PlayerControllerClass = AMyPlayerController::StaticClass();
}
```

### 3. Build.cs 中的模块依赖

```csharp
// MyGame.Build.cs
PublicDependencyModuleNames.AddRange(new string[]
{
    "Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput"
});
```

## 常见陷阱

- **`generated.h` 不是最后一个 include 或缺失**——会出现 "Cannot find generated header" 或
  "Expected an include" 等编译错误。它必须是头文件中的最后一个 include。
- **忘记 `GENERATED_BODY()`**——会产生 UHT（Unreal Header Tool）错误；它必须是类体中的第一个内容。
- **使用没有 `UPROPERTY` 的裸 `UObject*`**——垃圾回收器看不到它，可能在你仍使用它时将其销毁。
  使用 `UPROPERTY` 跟踪每个 UObject 指针（在 UE5 中使用 `TObjectPtr`）。
- **使用 Live Coding 修改 header/UPROPERTY**——Live Coding 可以处理函数体，但对
  `UCLASS`/`UPROPERTY`/header 的更改需要完全重启编辑器并重建。
- **类前缀错误**——将 Actor 命名为 `UFoo`（或将 component 命名为 `AFoo`）会破坏 UHT；
  请使前缀与基类型匹配。
- **链接时出现未解析的外部符号**——提供该 API 的模块不在 `Build.cs` 的
  `PublicDependencyModuleNames` 中。
- **重写 `BeginPlay`/`Tick` 等时未调用 `Super::`**会跳过引擎设置。

## 参考资料

- 关于 `UActorComponent` 的创建/附加、`UPROPERTY` 垃圾回收所有权规则
  （`TObjectPtr`、`TArray<TObjectPtr<>>`、`AddToRoot`）以及网络复制入门，请阅读
  `references/components-and-gc.md`。
- 主要文档："Unreal Engine CPP Quick Start" 和 "Gameplay Framework"
  (`https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-framework-in-unreal-engine`)。

## 相关 skill

- `unreal-blueprints` — 向设计师公开 C++；BP/C++ 互操作。
- `unreal-enhanced-input` — 在 C++ Pawn/Character 中绑定输入。
- `unreal-behavior-trees` — 由 behaviour tree 驱动的 C++ AI task。
