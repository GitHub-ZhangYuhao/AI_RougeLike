---
name: bevy-ecs
description: >
  围绕实体组件系统构建 Bevy 应用：通过插件构建 App，定义
  Component/Resource 类型，使用 Query/Res/Commands 编写系统，过滤系统并安排其
  顺序，并使用 Time 资源实现与帧率无关的运动。适用于使用 Rust 构建或调试
  Bevy 游戏——当用户提到 Bevy、ECS、App::new、add_systems、Query、Commands、
  components/systems，或依赖 bevy 的 Cargo.toml 时。
---

# Bevy ECS

围绕实体组件系统用 Rust 构建 Bevy 游戏：`App` 和
插件、组件和资源、具有查询、调度和功能的系统
与帧速率无关的更新。新示例的目标是 **Bevy 0.19**。如果项目
已固定另一个版本，保留该版本并使用其匹配的迁移指南。

## 何时使用

- 在连接 Bevy `App`、定义 `Component`/`Resource` 类型、编写时使用
  查询实体、排序/过滤系统或修复的系统
  借用冲突恐慌和依赖框架的运动。
- 当`Cargo.toml`依赖于`bevy`并且代码调用`App::new()`时使用，
  `add_systems`、`Query` 或 `Commands`。

**当*不*使用时：**这是 ECS 核心。深度渲染、自定义着色器/
管道、UI 布局和音频是不同的问题。对于与引擎无关的人工智能或
程序算法，与 `game-ai` / `procedural-gen` 配对。

## 核心工作流程

1. **检测并固定版本。** 首先阅读 `Cargo.toml` 和 `Cargo.lock`。对于一个
   新项目使用`bevy = "0.19"`；永远不要默默地迁移现有项目
   跨越 Bevy 小版本。将匹配的文档和迁移指南视为事实。
2. **构建 `App`。** `App::new().add_plugins(DefaultPlugins)` 提供窗口，
   输入、渲染、时间等。将系统注册到调度中：`Startup`（一次）
   和 `Update`（每帧）。
3. **模型数据作为组件，全局变量作为资源。** `#[derive(Component)]`
   每个实体的数据； `#[derive(Resource)]` 用于一种独一无二的数据（分数、设置、
   `Time` 时钟）。在 0.19 中，`Resource` 扩展了 `Component`，因此不要导出两者。
4. **将系统编写为普通函数。** 参数声明数据访问：`Query<...>`
   对于实体，`Res<T>`/`ResMut<T>` 对于资源，`Commands` 对于延迟
   产生/消失。当访问不冲突时，系统并行运行。
5. **通过 `time.delta_secs()` 驱动运动**，因此速度与帧速率无关。
6. **仅订购必须订购的**，带有 `.chain()` 或显式约束；
   采用 `run_if` 的门系统。将相关设置分组到 `Plugin` 中。构建与
   `cargo run` 并阅读恐慌 - Bevy 报告启动时查询冲突。

## 模式

### 1. Cargo.toml + 最小 App

```toml
# Cargo.toml — pin the version; the API differs across minor releases.
[dependencies]
bevy = "0.19"
```

```rust
// main.rs
use bevy::prelude::*;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)            // window, input, render, time, ...
        .add_systems(Startup, setup)            // runs once at startup
        .add_systems(Update, move_players)      // runs every frame
        .run();
}
```

### 2. 组件、资源和生成

```rust
#[derive(Component)]
struct Player;

#[derive(Component)]
struct Velocity(Vec2);

#[derive(Resource)]
struct Score(u32);

fn setup(mut commands: Commands) {
    commands.insert_resource(Score(0));

    // Camera2d is a component with required components (bundles removed in 0.16);
    // spawning it pulls in Transform, Camera, etc. automatically.
    commands.spawn(Camera2d);

    // Spawn an entity as a tuple of components.
    commands.spawn((
        Player,
        Velocity(Vec2::new(150.0, 0.0)),
        Transform::from_xyz(0.0, 0.0, 0.0),
    ));
}
```

### 3. 具有查询+时间资源的系统

```rust
// Iterate every entity that has BOTH Velocity and Transform; mutate Transform.
fn move_players(time: Res<Time>, mut query: Query<(&Velocity, &mut Transform)>) {
    for (velocity, mut transform) in &mut query {
        // delta_secs() is f32 seconds (renamed from delta_seconds() in 0.16).
        transform.translation += velocity.0.extend(0.0) * time.delta_secs();
    }
}
```

### 4. 查询过滤器（有/无/已更改）

```rust
// Only entities tagged Player (the Player component itself isn't read).
fn aim_player(mut q: Query<&mut Transform, With<Player>>) { /* ... */ }

// Disjoint two mutable Transform queries so they don't conflict at runtime.
fn separate(
    mut players: Query<&mut Transform, With<Player>>,
    mut enemies: Query<&mut Transform, Without<Player>>,
) { /* ... */ }

// React only when Health changed since last run (change detection).
fn on_health_change(q: Query<&Health, Changed<Health>>) {
    for health in &q { /* update the HUD, etc. */ }
}
```

### 5. 资源：读和写

```rust
fn add_points(mut score: ResMut<Score>) {
    score.0 += 10;                 // ResMut = write access
}

fn show_score(score: Res<Score>) {
    info!("score: {}", score.0);   // Res = read access
}
```

### 6. 订购、运行条件和插件

```rust
fn main() {
    App::new()
        .add_plugins((DefaultPlugins, GameplayPlugin))
        // .chain() forces order: damage resolves before death is checked.
        .add_systems(Update, (apply_damage, check_deaths).chain())
        // run_if gates a system on a condition each frame.
        .add_systems(Update, spawn_wave.run_if(wave_timer_finished))
        .run();
}

struct GameplayPlugin;
impl Plugin for GameplayPlugin {
    fn build(&self, app: &mut App) {
        app.insert_resource(Score(0))
           .add_systems(Startup, setup)
           .add_systems(Update, (move_players, add_points));
    }
}
```

## 陷阱

- **`delta_seconds()` 未找到** → 它被重命名为 `time.delta_secs()`（并且
  `elapsed_secs()`) 在 0.16 中。使用旧名称无法编译。
- **移动速度与帧速率成比例** → 将每帧变化乘以
  `time.delta_secs()`。永远不要假设固定的帧时间。
- **恐慌：“访问冲突”/“&mut T 和 &mut T”** → 两个 `Query` 合二为一
  系统都写入相同的组件，或者一个读取而另一个写入重叠
  实体。使它们与 `With`/`Without` 不相交，或使用 `ParamSet`。
- **未找到 `Camera2dBundle`/`SpriteBundle`** → 捆绑包在 0.15 中已弃用，并且
  在 0.16 中删除。
  直接生成组件（`Camera2d`、`Sprite`、`Transform`）；必需的
  组件填充其余部分。
- **“特征 `Component` 未实现”** → 你忘记了 `#[derive(Component)]`
  （或 `#[derive(Resource)]` 表示资源）。
- **生成的实体对于同一帧中的后续查询不可见** → `Commands` 是
  推迟并在下一个同步点应用。读取后续系统中的实体，
  不是产生它的那个。
- **假定但不强制执行系统顺序** → 系统默认并行运行。
  如果 `B` 必须遵循 `A`，请添加 `(A, B).chain()` 或显式排序约束。
- **在 0.19 中导出 `Resource` 和 `Component`** → `Resource` 现在扩展
  `Component`;单独导出 `Resource` 以避免实现冲突。
- **复制粘贴较旧的 Bevy 片段** → API 在次要版本之间切换。这
  缓冲事件系统成为最近版本中的消息系统。验证对照
  *您的*固定版本的文档和迁移指南；不要混合版本。

## 参考

- 对于时间表和 `SystemSet` 订购，`States`/`OnEnter`/`OnExit`，更改
  检测，`Commands` 生命周期和同步点，`ParamSet` 冲突
  查询以及有关事件/观察者 API 的版本说明，请阅读
  `references/queries-and-scheduling.md`。

## 相关技能

- `game-ai` — FSM/行为树/转向作为可移植概念在 ECS 中实现。
- `procedural-gen` — 从系统驱动的噪声/RNG/生成算法。
- `pygame-core` / `love2d-core` — 适用于小型项目的轻型发动机。
