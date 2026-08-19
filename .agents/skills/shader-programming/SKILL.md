---
name: shader-programming
description: >
  基于跨引擎基础编写游戏着色器——涵盖从顶点到片段管线、坐标空间、UV 数学，以及常见的 2D/3D 效果（重调色、滚动纹理、溶解、轮廓线、菲涅尔边缘光、暗角）在 GLSL 中的实现及其 HLSL 等效版本。当用户提及着色器、片段或像素着色器、顶点着色器、UV、GLSL、HLSL，或是如溶解、轮廓线或边缘光等效果时启用此技能。
---

# 着色器编程（跨引擎）

着色器是在 GPU 上为每个**顶点**和每个**像素**运行的微型程序。这些概念——管线、坐标空间、UV 以及常见效果的构建方式——可移植到各种引擎；唯一变化的是语言方言和内建变量名。本技能教授在 GLSL 中及其 HLSL 等效实现中的那些可移植基础；对于确切的引擎语法和内建，请使用 `godot-shaders`（或 Unity/Unreal 材质文档）。

## 何时使用

- 用于理解或编写顶点/片段着色器，并推理 UV、坐标空间和 GPU 管线。
- 用于构建常见效果：重调色、滚动纹理、溶解、轮廓线、菲涅尔/边缘光、暗角、色彩分级。
- 用于在 GLSL 和 HLSL 之间，或在不同引擎之间翻译着色器概念。

**当不使用时：** 针对确切的引擎着色器语言和内建功能，请使用 `godot-shaders`（Godot 着色语言）或该引擎的材质文档；如需完整的粒子 VFX 系统，请参阅 `unreal-niagara`；对于后期处理 **stacks**，请遵循引擎的渲染器设置。

## 核心工作流

1. **明确当前所处阶段。** **顶点**着色器将每个顶点转换到裁剪空间并传递数据（UV、法线）；**片段/像素**着色器针对光栅化后的每个像素运行并输出颜色。大多数游戏效果位于片段阶段。
2. **追踪坐标空间。** 位置移动路径为模型 → 世界 → 视图 → 裁剪空间；法线应属于世界或视图空间。混合不同空间是最常见的错误来源。
3. **利用 UV 和时间驱动特效。** UV 是 `0..1` 的纹理坐标；对其施加偏移、缩放或扭曲，并使用 `time` 统一变量进行动画处理。
4. **逐像素工作，减少分支逻辑。** 尽可能优先使用 `mix`、`step`、`smoothstep` 和 `clamp` 而非 `if`；GPU 倾向于锁步运行像素且不喜欢发散式分支。
5. **通过 uniforms（每绘制调用常量）传递数据**以及 **varyings（顶点到片段插值）**。尽量减少纹理采样次数，因为它们主导了计算成本。
6. **在视觉上和目标硬件上进行验证。** 在桌面端看起来正确的着色器可能在移动端失效（精度问题、缺少特性）。务必在实际发布环境中测试。

## 模式

GLSL 风格的片段代码段（类似于 Godot 中 `canvas_item`/`spatial` 的着色器或 OpenGL）。关于 HLSL 等效版本及完整大纲、菲涅尔和暗角着色器的说明，请参阅 `references/effects.md`。

### 1. 片段着色基础：采样、着色与混合

```glsl
// Per-pixel: read the texture at this UV, multiply by a color (tint), keep alpha.
uniform sampler2D tex;
uniform vec4 tint;          // e.g. (1,0,0,1) reddens; multiply is non-destructive
in vec2 uv;                 // interpolated 0..1 texture coordinate (a "varying")
out vec4 frag;
void main() {
    vec4 c = texture(tex, uv);   // HLSL: tex.Sample(samp, uv)
    frag = c * tint;             // component-wise multiply tints without clipping
}
```
### 2. 滚动 UV（动画纹理）——帧率无关

```glsl
// Add time * speed to the UV to scroll. fract() wraps it into 0..1 so it tiles.
uniform sampler2D tex;
uniform float time;          // seconds, supplied by the engine
uniform vec2 scroll_speed;   // UV units per second, e.g. (0.1, 0.0)
in vec2 uv;
out vec4 frag;
void main() {
    vec2 scrolled = fract(uv + scroll_speed * time);  // HLSL: frac(...)
    frag = texture(tex, scrolled);
}
// Drive with a real time uniform, not a per-frame accumulator, so speed is stable.
```
### 3. 溶解（阈值去噪，边缘发光）

```glsl
// Hide pixels where noise < threshold; tint a thin band at the boundary.
uniform sampler2D tex;
uniform sampler2D noise_tex;     // grayscale noise, 0..1
uniform float amount;            // 0 = fully visible, 1 = fully dissolved
uniform float edge = 0.05;       // width of the glowing edge band
uniform vec4 edge_color;
in vec2 uv;
out vec4 frag;
void main() {
    vec4 c = texture(tex, uv);
    float n = texture(noise_tex, uv).r;
    if (n < amount) discard;                 // cut away dissolved pixels
    float e = smoothstep(amount, amount + edge, n);  // 0 at the edge -> 1 inside
    frag = mix(edge_color, c, e);            // HLSL: lerp(edge_color, c, e)
}
```
### 4. 菲涅尔轮廓光（3D）——提亮掠射角区域

```glsl
// Rim = 1 where the surface faces away from the camera (silhouette glow).
in vec3 world_normal;        // normalized, world space (from the vertex stage)
in vec3 view_dir;            // normalized, surface -> camera, world space
uniform float power = 3.0;
uniform vec3 rim_color;
out vec4 frag;
void main() {
    float f = pow(1.0 - clamp(dot(world_normal, view_dir), 0.0, 1.0), power);
    frag = vec4(rim_color * f, 1.0);   // add to lighting; f peaks at the silhouette
}
// Correctness: normal and view_dir MUST be in the same space and normalized.
```
## 常见陷阱

- **混合坐标空间**：例如用世界空间的法线对视图空间的光源进行光照计算，会导致微妙的着色错误。请选定一个统一的空间并将所有数据转换至该空间。
- **忘记归一化插值的法线或方向向量**：插值会缩短向量长度，导致 `dot()` 结果产生偏差。应在片段阶段执行 `normalize()`。
- **跨引擎的 UV 假设**。某些引擎翻转了 V（左上角 vs 左下角原点），纹理可能会上下颠倒。请了解您所用引擎的具体约定。
- **大量分支或动态循环**会阻塞 GPU。优先使用 `step`/`smoothstep`/`mix`；仅在真正需要时保留用于早期退出的 `if`/`discard`。
- `discard` 会破坏深度预剔除（early-Z），并可能损害分块式移动设备的性能；在可能的情况下优先使用 Alpha Blending。
- **移动端精度问题**：`highp` vs `mediump` 至关重要；低精度下的大 UV 或时间值会产生闪烁现象。为坐标和时间使用足够的精度。
- **假设 GLSL == HLSL。** `mix`↔`lerp`，`fract`↔`frac`，`texture()`↔`.Sample()`，`vec2`↔`float2`，列主序 vs 行主序矩阵。请参阅参考映射表。

## 引用文档

- `references/effects.md` — 完整大纲（含 2D 精灵与 3D）、暗角及色彩分级着色器；GLSL↔HLSL 函数/类型映射表；各引擎说明（Godot `canvas_item`/`spatial`，Unity ShaderLab/HLSL，Unreal material nodes）。

## 相关技能

- `godot-shaders` — Godot 着色语言语法、内建函数及屏幕阅读。
- `unreal-niagara` — GPU 粒子 VFX（一种不同的着色器用途）。
- `procedural-gen` — 驱动溶解和程序化纹理生成的噪声算法。
