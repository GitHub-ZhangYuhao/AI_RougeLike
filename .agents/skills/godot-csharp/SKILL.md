---
name: godot-csharp
description: >
  在 Godot 4.7 中使用 C#/.NET：扩展节点的 partial 类、PascalCase 生命周期
  (_Ready/_Process/_PhysicsProcess)、[Export] 字段、作为 C# 事件的 [Signal] 委托、
  类型安全的节点查找，以及 C# 与 GDScript 之间的调用。使用 C# 编写 Godot 游戏代码
  （.cs 文件、.csproj）、需要 Godot .NET 构建、将 GDScript 模式转换为 C#，
  或将 Godot 信号连接为 C# 事件时使用。
---

# Godot C# / .NET (4.x)

使用 C# 编写 Godot 游戏代码：节点子类、引擎生命周期、导出、作为事件的信号，以及
GDScript 互操作。适用于 **Godot 4.7 (.NET / C#)** 和 **.NET 8**。

## 何时使用

- 使用 C#（`.cs` + `.csproj`）编写 Godot 游戏脚本、将 GDScript 惯用法翻译为 C#、
  暴露 `[Export]` 字段，或连接 `[Signal]` 委托和 GetNode<T> 时使用。

**不应使用的情况：** GDScript 特有语法 → `godot-gdscript`；与语言无关的引擎概念
（场景、物理、动画）→ 相关 `godot-*` skill。需要安装 **Godot .NET 构建** + .NET SDK；
标准构建无法运行 C#。

## 核心工作流

1. **使用 Godot .NET 编辑器构建**并安装匹配的 .NET 8 SDK。创建第一个 C# 脚本时会生成
   `.csproj`/`.sln`。通过编辑器或 `dotnet build` 构建。
2. **每个节点脚本都是扩展 Godot 类型的 `partial` 类**（源生成器依赖 `partial`）。
   文件名/类名应与节点脚本匹配。
3. **使用 PascalCase 重写生命周期方法**，delta 类型为 `double`：`_Ready()`、
   `_Process(double delta)`、`_PhysicsProcess(double delta)`。
4. **使用 `[Export]` 暴露可调参数**；它们会像 GDScript `@export` 一样显示在 Inspector 中。
5. **将信号声明为 `[Signal]` 委托**，命名为 `XxxEventHandler`；使用
   `EmitSignal(SignalName.Xxx, ...)` 发出信号，并通过生成的 C# `event` 订阅。
6. **使用 `GetNode<T>("Path")` 获取节点**（或 `%Unique`），并在需要时通过
   `Call`/`Get`/`Set` 调用 GDScript。

## 模式

### 1. 节点脚本：生命周期、[Export]、GetNode<T>

```csharp
using Godot;

public partial class Player : CharacterBody2D
{
    [Export] public float Speed = 200.0f;          // editable in the Inspector
    [Export] public float JumpVelocity = -400.0f;

    private const float Gravity = 1200.0f;
    private AnimatedSprite2D _sprite;

    public override void _Ready()
    {
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
    }

    public override void _PhysicsProcess(double delta)
    {
        Vector2 v = Velocity;                       // Velocity is a property here
        if (!IsOnFloor())
            v.Y += Gravity * (float)delta;          // delta is double; cast for float math
        if (Input.IsActionJustPressed("jump") && IsOnFloor())
            v.Y = JumpVelocity;

        float dir = Input.GetAxis("move_left", "move_right");
        v.X = dir != 0 ? dir * Speed : Mathf.MoveToward(v.X, 0, Speed);

        Velocity = v;
        MoveAndSlide();                             // no args, like GDScript 4.x
    }
}
```

### 2. 将信号用作 C# 事件

```csharp
using Godot;

public partial class Health : Node
{
    // Delegate name MUST end with "EventHandler"; generator creates the event + SignalName.
    [Signal] public delegate void HealthChangedEventHandler(int current, int max);

    private int _hp = 100;

    public void TakeDamage(int amount)
    {
        _hp = Mathf.Max(_hp - amount, 0);
        EmitSignal(SignalName.HealthChanged, _hp, 100);   // type-safe signal name
    }

    public override void _Ready()
    {
        HealthChanged += OnHealthChanged;            // subscribe like a normal C# event
    }

    private void OnHealthChanged(int current, int max) => GD.Print($"HP {current}/{max}");
}
```

### 3. 在 C# 中实例化场景

```csharp
public partial class Spawner : Node2D
{
    // Load once; PackedScene is the C# equivalent of preload's result.
    private readonly PackedScene _bullet = GD.Load<PackedScene>("res://bullet.tscn");

    public void Shoot(Vector2 at)
    {
        var b = _bullet.Instantiate<Node2D>();       // typed instantiate
        b.GlobalPosition = at;
        AddChild(b);
    }
}
```

### 4. 与 GDScript 节点互操作

```csharp
public override void _Ready()
{
    Node gd = GetNode("GDScriptNode");
    // Call a GDScript method and read/write its properties dynamically.
    gd.Call("take_damage", 10);
    int score = (int)gd.Get("score");
    gd.Set("score", score + 5);
    // Connect to a GDScript signal by name:
    gd.Connect("died", Callable.From(OnDied));
}

private void OnDied() => GD.Print("entity died");
```

## 常见陷阱

- **忘记 `partial`。** 没有 `partial`，Godot 源生成器便无法扩展该类，
  `[Export]`/`[Signal]` 会产生令人困惑的构建错误。
- **方法大小写/签名错误。** C# 重写为 `_Ready`、`_Process(double)`、
  `_PhysicsProcess(double)`——使用 PascalCase 和 `double` delta（GDScript 使用 snake_case
  和 `float`）。名称不匹配时不会被调用。
- **`[Signal]` 委托命名。** 必须以 `EventHandler` 结尾；引擎将信号暴露为不含该后缀的名称，
  并生成 `SignalName.X` 和 C# `event`。
- **`GD.Print` 与 `Console.WriteLine`。** 使用 `GD.Print`/`GD.PrintErr` 将信息输出到 Godot
  输出面板；`Console` 输出可能不会显示。
- **值类型 struct。** `Vector2`、`Color`、`Transform2D` 都是 struct——应修改局部副本
  （`var v = Velocity; v.X = ...; Velocity = v;`）；直接编辑 `Velocity.X` 无法编译/持久化。
- **需要 .NET 构建 + SDK。** 非 .NET 编辑器无法运行 C#；.NET SDK 不匹配/缺失会导致构建失败。
  Godot 4.7 面向 .NET 8；请检查当前平台的导出说明，因为 Android 和其他 AOT 目标可能需要
  更新的 SDK 工具。
- **`QueueFree()` 与 `Free()`**——规则与 GDScript 相同；优先使用 `QueueFree()`。
  释放后再使用已释放对象会抛出 `ObjectDisposedException`。
- **某些平台的 .NET 导出方式不同**（例如 web/mobile 的额外步骤）；请查看目标平台的
  .NET 导出说明。

## 参考资料

- 有关导出特性变体（`[ExportGroup]`、范围、类型化数组）、使用 `await ToSignal(...)` 异步、
  `Godot.Collections` 与 System 集合、自定义 C# Resources，以及项目/构建设置，
  请阅读 `references/csharp-setup-and-interop.md`。

## 相关 skill

- `godot-gdscript` — 这些模式的 GDScript 等价形式。
- `godot-signals-groups` — 信号/事件架构（与语言无关）。
- `godot-resources` — 数据资源；C# `[Export]` + `Resource` 模式。
- `unity-csharp-scripting` — 面向从 Unity 转来的开发者的 Unity C#。
