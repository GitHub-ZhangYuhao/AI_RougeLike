---
name: unreal-enhanced-input
description: >
  使用 Enhanced Input 在 Unreal Engine 5 中设置玩家输入：Input Action、Input Mapping Context、
  modifier 和 trigger、添加 mapping context，以及按 ETriggerEvent 绑定 action。适用于连接移动/视角/
  跳跃输入、创建 IA_/IMC_ 资产、在 C++ 或 Blueprint 中绑定，或用户提及 Enhanced Input、
  Input Mapping Context、Input Action、IA_/IMC_ 或 ETriggerEvent 时。
---

# Unreal Enhanced Input

使用 **Enhanced Input** 系统以现代 UE5 方式连接玩家输入：使用数据驱动的 Input Action 和
Mapping Context，而非旧版 Project Settings axis/action mapping。目标版本为 **UE 5.8**
（Enhanced Input 是默认方案；旧版 input 已弃用）。

## 何时使用

- 添加移动/视角/跳跃/开火输入、创建 Input Action（`IA_`）和 Input Mapping Context（`IMC_`）
  资产、应用 modifier/trigger、向玩家添加 mapping context，或在 C++ 或 Blueprint 中绑定 action 时使用。
- 当项目具有 `IA_*`/`IMC_*` 资产或引用 `EnhancedInput` 时使用。

**不应使用的场景：** 与引擎无关的输入*架构*（重绑定策略、缓冲、多设备设计）→
`input-systems`。承载这些绑定的 Pawn/Character C++ → `unreal-cpp-gameplay`。

## 核心工作流

1. **启用模块/plugin。** Enhanced Input 在 UE5 中默认开启；若要使用 C++ 绑定，请在
   `*.Build.cs` 的 `PublicDependencyModuleNames` 中添加 `"EnhancedInput"`。
2. **创建 Input Action（`IA_`）。** 每个 action 都有一个 **Value Type**：按钮使用
   `Digital (bool)`，trigger 使用 `Axis1D (float)`，移动/视角使用 `Axis2D (Vector2D)`。
3. **创建 Input Mapping Context（`IMC_`）**，将键/按钮映射到这些 action。使用 **Modifier**
   调整原始输入（Negate、Swizzle Input Axis Values、Dead Zone）——例如，要将 WASD 映射到一个
   Axis2D，需要对 A/S 使用 Negate，并对 W/S 使用 Swizzle。使用 **Trigger**（Pressed、Hold、Tap）
   决定 action 在*何时*触发。
4. **通过 `EnhancedInputLocalPlayerSubsystem` 向玩家添加 mapping context**
   （`AddMappingContext(IMC, Priority)`），通常在 `BeginPlay`/possession 期间执行。
5. **按 `ETriggerEvent`（`Triggered`、`Started`、`Completed` 等）将 action 绑定到 handler**，
   绑定在 `EnhancedInputComponent` 上，并在 handler 中读取 `FInputActionValue`。
6. **在 PIE 中验证；** Enhanced Input 调试控制台命令（`showdebug enhancedinput`）会显示
   哪些 action 被触发及其值。

## 模式

### 1. 添加 mapping context（C++ Character）

```cpp
void AMyCharacter::BeginPlay()
{
    Super::BeginPlay();
    if (APlayerController* PC = Cast<APlayerController>(GetController()))
        if (ULocalPlayer* LP = PC->GetLocalPlayer())
            if (auto* Subsystem = LP->GetSubsystem<UEnhancedInputLocalPlayerSubsystem>())
                Subsystem->AddMappingContext(DefaultMappingContext, /*Priority*/ 0);
}
// DefaultMappingContext is a UPROPERTY(EditAnywhere) TObjectPtr<UInputMappingContext>.
```

### 2. 绑定 action 并读取值

```cpp
void AMyCharacter::SetupPlayerInputComponent(UInputComponent* InputComponent)
{
    Super::SetupPlayerInputComponent(InputComponent);

    // The component is an Enhanced Input component when the plugin is active.
    if (UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(InputComponent))
    {
        EIC->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AMyCharacter::Move);
        EIC->BindAction(LookAction, ETriggerEvent::Triggered, this, &AMyCharacter::Look);
        EIC->BindAction(JumpAction, ETriggerEvent::Started,   this, &ACharacter::Jump);
        EIC->BindAction(JumpAction, ETriggerEvent::Completed, this, &ACharacter::StopJumping);
    }
}

void AMyCharacter::Move(const FInputActionValue& Value)
{
    const FVector2D Axis = Value.Get<FVector2D>();          // Axis2D action
    AddMovementInput(GetActorForwardVector(), Axis.Y);
    AddMovementInput(GetActorRightVector(),   Axis.X);
}
```

### 3. 等效 Blueprint（节点流）

```text
Event BeginPlay
  -> Get Controller -> Cast To PlayerController -> Get Local Player
  -> Get EnhancedInputLocalPlayerSubsystem -> Add Mapping Context (IMC_Default, Priority 0)

// IA_Move is exposed as its own event node in the Character's Event Graph:
EnhancedInputAction IA_Move (Triggered)
  -> Action Value (Vector2D) -> Add Movement Input (Forward * Y, Right * X)
```

## 常见陷阱

- **完全没有输入**——mapping context 从未被添加（`AddMappingContext`），或者玩家还没有 Local Player。
  请在 possession/`BeginPlay` 之后添加。
- **在 C++ 中绑定时出现链接/编译错误**——`"EnhancedInput"` 不在 `Build.cs` 的
  `PublicDependencyModuleNames` 中。
- **WASD 只有两个键能移动/轴向错误**——Axis2D 需要 **Modifier**：对负方向键（A、S）使用
  Negate，并对垂直方向（W/S）使用 Swizzle Input Axis Values，使两个轴都能正确映射。
  没有 modifier 的原始绑定会出现异常。
- **`Get<FVector2D>()` 返回零**——value type 不匹配：Input Action 是 Digital/Axis1D，而非
  Axis2D。让 `Get<T>()` 与 action 的 Value Type 匹配。
- **Action 意外地每帧触发**——对于 Down trigger，`Triggered` 会在按住期间重复触发；
  一次性操作（按下/松开跳跃）请使用 `Started`/`Completed`，或使用 Pressed/Tap trigger。
- **两个 context 冲突**——多个 mapping context 按 Priority 堆叠；优先级更高的 context 可能会
  消耗某个键。请使用优先级和 `RemoveMappingContext` 进行管理。

## 参考资料

- 关于使用 Enhanced Input 的完整第一/第三人称 C++ Character（头文件 + 源文件，包括视角/跳跃和
  控制重绑定说明），请阅读 `references/cpp-setup.md`。
- 主要文档："Enhanced Input in Unreal Engine"
  (`https://dev.epicgames.com/documentation/en-us/unreal-engine/enhanced-input-in-unreal-engine`)。

## 相关 skill

- `input-systems` — 与引擎无关的输入架构和重绑定策略。
- `unreal-cpp-gameplay` — Character/Pawn 类和模块设置。
- `fps-shooter` — 将输入与 3D controller 和射击功能组合。
