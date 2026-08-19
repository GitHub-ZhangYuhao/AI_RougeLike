---
name: performance-optimization
description: >
  系统地查找并修复游戏性能问题——首先使用引擎分析器进行测量，分析帧时间预算，定位 CPU 与 GPU 瓶颈，然后应用正确的解决方案：对象池、绘制调用批处理、减少分配/GC 尖峰以及资产预算；这是一种不依赖特定引擎的方法，可与每种引擎的分析器配合使用。当用户提及性能、优化、低/下降的 FPS、帧掉速、卡顿、延迟、分析器、帧预算、绘制调用、批处理、垃圾回收/GC 尖峰或“游戏运行缓慢”时使用此技能。
---

# 性能优化

性能工作是一项测量纪律，而非一堆技巧。方法始终如一：**剖析 → 找到唯一瓶颈 → 修复该问题 → 再次测量**。本技能教授循环（loop）和高杠杆率的修复方案（池化、批处理、分配控制、资产预算），并指引您至每种引擎的分析器。它与 `physics-tuning` 配合用于模拟成本优化。

## 何时使用此技能

- **帧率低或不均匀**，游戏出现卡顿/顿挫，或必须达到目标帧率（桌面端 60 FPS，移动端 30/60 FPS）但目前未达到的情况。
- **决定优化对象**：进行剖析、读取帧预算，并在修改任何代码前识别出是 CPU 还是 GPU 成为瓶颈。
- **应用特定修复方案**：对象池化、绘制调用/批处理减少、移除每帧分配和 GC 尖峰、设定资产预算。

**何时不使用此技能：** 针对物理抖动/穿模/时间步长问题，请使用 `physics-tuning`。对于引擎的具体剖析器 UI 和渲染设置，请使用该引擎的技能（`godot-export` 涵盖部分构建设置；核心引擎覆盖其余内容）。本技能是跨引擎方法并提供通用修复方案。

## 黄金法则：先测量，绝不猜测

大多数未经剖析就应用的性能“修复”针对了错误对象并增加了复杂度却无收益。**切勿优化未曾测量的代码**。打开分析器，在代表性硬件上的典型场景中找出单个最大成本项并进行修复。再次测量以确认修复有效后再继续。在**发布/优化构建**中进行剖析——因为编辑器与调试构建具有误导性（存在编辑开销且未进行编译器优化）。

## 核心工作流

1. **定义目标并复现问题**。陈述目标（例如：60 FPS = 每帧 16.67 ms）并找到可重复的最坏情况场景。“偶尔变慢”无法修复；可复现的尖峰则可以被修复。
2. **在修改代码前进行剖析**。运行引擎分析器，读取帧数据：总帧时间以及 CPU（游戏逻辑、物理、脚本）与 GPU（渲染）之间的分配比例。
3. **识别瓶颈——CPU 或 GPU**。如果 GPU 耗时远大于 CPU，则攻击绘制调用、过度绘制、着色器或分辨率问题；若 CPU 耗时占主导，则针对脚本、物理引擎和内存分配进行优化。修复错误的一侧毫无作用。
4. **修复单个最大成本项**。优先选择**算法层面**的改进（减少工作量、缓存、空间分区、降低运行频率），而非对热点行进行微优化。应用匹配的通用修复方案（池化、批处理、移除分配）。
5. **在同一场景/硬件上再次测量**。确认数值变化。基于数据保留或回退，而非凭直觉判断。
6. **设定预算以确保效果持久**。为每个子系统设定每帧毫秒级预算，以及资产预算（纹理大小、三角形数量、绘制调用上限）；在验证流程中添加性能检查项。
7. **报告测量到的数值**。陈述修复前后的帧时间、发现的瓶颈及采用的修复方案——绝不使用“应该更快”这类表述。如果您只能在编辑器中测量，请说明这一点。

## 常见模式

### 1. 帧预算计算（将“感觉慢”转化为具体数字）

```text
target FPS → frame budget:   60 FPS = 16.67 ms   |   30 FPS = 33.3 ms   |   120 FPS = 8.33 ms
The WHOLE frame (CPU sim + render submit + GPU) must fit the budget; the GPU runs in parallel,
so the slower of CPU-frame and GPU-frame sets your FPS. Allocate sub-budgets, e.g. @60 FPS:
  gameplay/scripts ~5 ms · physics ~3 ms · rendering(CPU submit) ~4 ms · UI/other ~2 ms · slack.
If one subsystem blows its slice, that's your target — not whatever you assumed.
```
### 2. 使用引擎分析器进行测量（在修复前执行此步骤）

```text
Godot 4.7 : Debugger ▸ Profiler (script/physics time) and Monitors tab (FPS, draw calls, memory).
            In code: Performance.get_monitor(Performance.TIME_PROCESS) and
            Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME).
Unity 6.3 LTS   : Profiler window (CPU/GPU/Memory/Rendering modules) + Frame Debugger for draw calls.
            In code: a ProfilerRecorder tracking "CPU Main Thread Frame Time" for a HUD/log.
Unreal 5  : `stat unit` (Frame/Game/Draw/GPU ms), `stat fps`, `stat scenerendering` (draw calls);
            Unreal Insights for deep traces.
# Read the split: is the Draw/GPU line the biggest, or the Game/CPU line? That decides the fix.
```
### 3. 对象池化（停止在热点循环中进行分配/释放）

```gdscript
# Bullets, particles, enemies, damage numbers: reuse a fixed set instead of instantiate()/free()
# every frame — that thrashes memory and (in C#) feeds the GC.
var _pool: Array[Node] = []
func acquire() -> Node:
    var n: Node = _pool.pop_back() if not _pool.is_empty() else bullet_scene.instantiate()
    n.set_process(true); n.visible = true
    return n
func release(n: Node) -> void:
    n.set_process(false); n.visible = false       # disable + hide; DON'T free
    _pool.append(n)                                # back to the pool for reuse
# RIGHT: pre-warm the pool at load; reuse. WRONG: instantiate()/queue_free() per shot.
```
### 4. 减少绘制调用数量（最常见的 GPU 侧优化方案）

```text
Each unique material/texture/state change is roughly a draw call; thousands of them stall the GPU.
- Atlas textures and share materials so sprites/meshes batch into one call.
- Identical meshes → GPU instancing (Unity), MultiMesh / MultiMeshInstance (Godot), Instanced
  Static Mesh (Unreal).
- Static geometry → static batching / baking; mark non-moving objects static.
- Reduce overdraw: limit large overlapping transparent/particle layers (they re-shade pixels).
- Fewer real-time lights/shadows; bake lighting where it doesn't move.
Measure draw calls before and after — the count should drop, and so should GPU frame time.
```
### 5. 消除每帧分配（GC 尖峰导致卡顿）

```csharp
// Unity 6.3 LTS (C#). Allocating every frame fills the managed heap; the GC then stalls a frame.
// WRONG (allocates each call): foreach (var e in FindObjectsOfType<Enemy>()) ...  // + LINQ, new[]
// RIGHT: cache references once, reuse buffers, avoid LINQ/boxing in Update.
void Update() {
    _hits = Physics.RaycastNonAlloc(ray, _hitBuffer);   // reuse a preallocated array
    for (int i = 0; i < _hits; i++) { /* ... */ }       // no per-frame allocation
}
// Godot/GDScript: avoid building new arrays/dictionaries every frame in _process; reuse them.
```
## 常见陷阱

- **未剖析就进行优化**。直觉上的罪魁祸首通常是错误的。每次都要先测量。
- **在编辑器或调试构建中剖析**。编辑开销和未优化的代码具有误导性。请在目标硬件的发布构建中进行剖析以获取真实数据。
- **修复性能较差的一方**。当 GPU 成为瓶颈时无需对 CPU 代码进行微调（反之亦然）。**首先检查**CPU 与 GPU 的耗时占比。
- **算法层面的微优化过度**。如果 O(n²) 循环或每帧全场景查询才是真正成本所在，那么修剪函数并无意义。减少工作量，而非仅仅抛光它。
- **在热点循环中实例化/释放对象**。每帧生成和销毁子弹/粒子会导致碎片化和 GC 尖峰。**使用池化技术**解决此问题。
- **`Update`（C#）中的每帧分配/LINQ/装箱**会加剧垃圾回收并导致周期性卡顿。**缓存并重用数据**。
- **由独特材质和非批处理精灵/网格引起的绘制调用爆炸**。使用图集、共享材质、实例化对象并进行批处理。
- **来自堆叠透明层/粒子/全屏效果的过度绘制（Overdraw）**，这些效果会重新着色像素。
- **缺乏预算约束**。若无子系统的毫秒级预算和资产上限，性能将悄无声息地退化；请在构建或 CI 检查中强制执行它们。
- **过早优化**。在原型有趣或未测量之前不要为了性能而扭曲设计。

## 引用资源

- 针对各引擎剖析器操作指南、CPU 与 GPU 排查流程图、完整池化管理器、各引擎的批处理/实例化规则、分配/GC 指导方针、LOD/剔除策略以及资产预算（纹理大小、三角形数量、音频、移动端发热），请阅读 `references/profiling-and-budgets.md`。

## 相关技能

- **`physics-tuning`** —— 模拟成本、固定步长预算、休眠刚体、宽相层。
- **`godot-export`** —— 影响测量性能的发布/构建设置。
- **`procedural-gen`, `game-ai`** —— 常见的 CPU 热点（生成算法、寻路）需进行预算规划并延迟执行。
- **`roguelike`, `tower-defense`, `survival-crafting`** —— 实体密集型类型，需要池化和预算约束支持。
