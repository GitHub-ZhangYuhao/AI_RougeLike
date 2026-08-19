---
name: unity-scriptableobjects
description: >
  使用 ScriptableObject 构建 Unity 6.3 LTS 的数据架构和解耦：配置/数据资源、共享运行时变量、
  事件通道以及运行时集合/注册表。适用于设计数据驱动系统、替换单例/管理器、
  通过 CreateAssetMenu 创建 .asset 数据，或用户提到 ScriptableObject、SO 架构或数据资源时。
---

# Unity ScriptableObject 架构

使用 `ScriptableObject` 资源存储共享数据，并在 Unity 6.3 LTS 中解耦系统——
将配置、事件通道和注册表作为项目资源存在，而不是硬编码到场景或单例中。
面向 **Unity 6.3 LTS (6000.3)**。

## 何时使用

- 适用于需要设计师可编辑的配置（武器属性、关卡数据）、在无关系统之间共享同一个值、
  通过事件通道解耦发送者与监听者，或在不使用 `static`/单例管理器的情况下构建
  活动对象运行时注册表时。
- 适用于项目包含由 `: ScriptableObject` 类支持的 `*.asset` 数据文件时。

**何时不应使用：**每个 GameObject 各不相同的实例运行时状态（应放在 MonoBehaviour 上）——
ScriptableObject 资源由所有引用它的对象*共享*。将玩家进度保存到磁盘 → `save-systems`。
永远不需要作为资源的普通 DTO 可以直接使用 `[System.Serializable]` 类。

## 核心工作流

1. **定义继承自 `ScriptableObject` 的类**，并添加 `[CreateAssetMenu]`，
   使设计师可以从 Assets 菜单创建实例。
2. **在 Project 窗口中创建一个或多个 `.asset` 实例**；每个实例都是一份共享的命名数据，
   由 `[SerializeField]` 字段引用。
3. **引用，而不是复制。**MonoBehaviour 持有资源引用；它们都能看到同一数据，
   因此更改资源会影响所有使用者。
4. **为了解耦**，将*信号*和*共享变量*建模为 ScriptableObject：HUD 读取而玩家写入的
   “FloatVariable”；玩家触发、多个系统监听的“event channel”。双方均无需引用对方。
5. **如果资源会在运行期间发生修改，请在 `OnEnable` 中重置运行时修改**，因为在 Editor
   运行时所做的编辑会持久保留在资源上（这是“播放后数值发生变化”的常见原因）。
6. **通过 Play 模式验证**：检查资源值并确认使用者会作出响应。

## 模式

### 1. 配置/数据资源

```csharp
using UnityEngine;

[CreateAssetMenu(fileName = "WeaponData", menuName = "Game/Weapon Data", order = 0)]
public class WeaponData : ScriptableObject
{
    public string displayName = "Pistol";
    public int    damage = 10;
    public float  fireRate = 0.25f;
    public GameObject projectilePrefab;
}
```

```csharp
public class Weapon : MonoBehaviour
{
    [SerializeField] private WeaponData data;   // assign the shared asset in the Inspector
    private void Fire() => Debug.Log($"{data.displayName} for {data.damage}");
}
```

### 2. 共享运行时变量（解耦生产者与使用者）

```csharp
[CreateAssetMenu(menuName = "Game/Float Variable")]
public class FloatVariable : ScriptableObject
{
    [SerializeField] private float initialValue;
    [System.NonSerialized] public float runtimeValue;   // not saved to the asset

    private void OnEnable() => runtimeValue = initialValue;  // reset each play session
}
// Player writes playerHealth.runtimeValue; the HUD reads it — neither references the other.
```

### 3. 在运行时创建实例（不是磁盘上的资源）

```csharp
// For transient SO data you build in code (e.g. a generated config).
var temp = ScriptableObject.CreateInstance<WeaponData>();
temp.damage = 25;
// ...use temp...  Destroy(temp);   // clean up runtime-created instances
```

## 常见陷阱

- **运行时编辑 SO 会在 Editor 中持久保留**——在 Play 期间更改的值会在停止后继续保留在资源上。
  将可变运行时状态保存在 `[NonSerialized]` 字段中，并在 `OnEnable` 中重置，否则会产生意外。
  （在*构建版本*中，资源编辑不会跨启动持久保留。）
- **禁用 Domain Reload 会跳过 `OnEnable` 重置**——启用 **Enter Play Mode Options** 且关闭
  **Reload Domain**（Unity 6.3 LTS 的快速迭代设置）时，按下 Play 后不会重新创建已加载的 SO，
  所以 `OnEnable` 不会触发，`runtimeValue` 会保留上次会话的值。应通过
  `ISerializationCallbackReceiver` 或场景加载钩子显式重置，而不是仅依赖 `OnEnable`。
- **期待每个对象拥有独立状态**——每个引用都指向*同一个*资源。如果两个敌人需要不同的
  当前 HP，请将 HP 存储在 MonoBehaviour 上，而不是共享 SO 中。
- **没有帧生命周期**——ScriptableObject 有 `OnEnable`/`OnDisable`/`OnDestroy`，但没有
  `Update`。不要期待逐帧回调。
- **将 SO 用作保存文件**——它们是创作资源，不是运行时持久化方案；请改用
  `save-systems` 写入进度。
- **泄漏 `CreateInstance` 对象**——运行时创建的实例不会像普通 C# 对象一样被垃圾回收；
  使用完毕后请 `Destroy`。

## 参考资料

- 有关**事件通道**模式（`GameEvent` SO 和监听者、类型安全的载荷）以及
  **运行时集合/注册表**（活动敌人的共享列表），请阅读 `references/event-channels.md`。
- 主要文档：Unity Manual“ScriptableObject”（`/Manual/class-ScriptableObject.html`），以及
  `ScriptReference/ScriptableObject`、`ScriptReference/CreateAssetMenuAttribute`。

## 相关技能

- `unity-csharp-scripting`——使用这些资源的 MonoBehaviour。
- `save-systems`——将状态持久化到磁盘（SO *不适合*此用途）。
- `card-game` / `rpg` / `survival-crafting`——高度依赖 SO 驱动数据的游戏类型。
