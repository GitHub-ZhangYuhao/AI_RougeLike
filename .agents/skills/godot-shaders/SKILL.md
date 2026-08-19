---
name: godot-shaders
description: >
  使用 Godot Shading Language 编写 Godot 4.7 着色器：用于 2D 的 canvas_item 着色器
  和用于 3D 的 spatial 着色器，包括 vertex/fragment 函数、uniform（source_color、
  hint_range）、TIME/UV 动画，以及通过 hint_screen_texture 读取屏幕。适用于编写
  .gdshader 文件、编写 fragment/vertex 代码、制作 2D/3D 视觉效果，或将 3.x 着色器
  （SCREEN_TEXTURE、hint_color）迁移到 4.x。
---

# Godot 着色器 (4.x)

使用 Godot Shading Language 编写 `canvas_item`（2D）和 `spatial`（3D）着色器，
通过 `TIME`/`UV` 制作动画，公开 `uniform`，并读取屏幕。目标版本为 **Godot 4.7**。

## 何时使用

- 适用于编写 `.gdshader` 代码或 `ShaderMaterial`：2D 效果（描边、溶解、闪光、水面）、
  3D 表面着色器（边缘光、卡通渲染、滚动 UV），或屏幕空间后处理效果。

**不适用的情况：** 跨引擎的着色_概念_（UV、vertex/fragment 理论）→
`shader-programming`；粒子/VFX 节点 → 通用 3D；非着色器视觉效果。

## 核心工作流

1. **在第一行选择着色器类型：** 2D（Sprite2D、TextureRect、任何 `CanvasItem`）使用
   `shader_type canvas_item;`，3D 材质使用 `shader_type spatial;`。
   （此外还有 `particles`、`sky`、`fog`。）
2. **通过 `ShaderMaterial` 附加。** 创建 `ShaderMaterial`，分配 `.gdshader`，并将其放到
   节点的 `material` 上。Uniforms 会显示在 Inspector 中。
3. **编写 `fragment()` 设置输出：** 2D 使用 `COLOR`，3D 使用
   `ALBEDO`/`EMISSION`/`ALPHA`。可选地使用 `vertex()` 移动几何体，并使用 `light()`
   自定义光照。
4. **将可调参数公开为带提示的 `uniform`**（`source_color`、`hint_range`），使其可编辑并
   获得正确的颜色管理。
5. **使用内置 `TIME` 制作动画，** 并通过 `texture(tex, UV)` 采样纹理。
6. **通过代码使用 `material.set_shader_parameter("name", value)` 设置 uniforms。**

## 模式

### 1. 2D (canvas_item)：着色 + 滚动 UV

```glsl
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);     // source_color = sRGB-correct color
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.3;

void fragment() {
    vec2 uv = UV;
    uv.x += TIME * scroll_speed;                  // scroll horizontally over time
    COLOR = texture(TEXTURE, uv) * tint;          // TEXTURE = the node's texture
}
```

### 2. 使用噪声阈值实现 2D 溶解

```glsl
shader_type canvas_item;

uniform sampler2D noise : repeat_enable;          // a NoiseTexture2D
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float n = texture(noise, UV).r;
    if (n < amount) {
        discard;                                  // cut the pixel away
    }
    COLOR = tex;
}
```

### 3. 3D (spatial)：自发光边缘光

```glsl
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec3 rim_color : source_color = vec3(0.6, 0.8, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

void fragment() {
    ALBEDO = base_color.rgb;
    // VIEW and NORMAL are view-space built-ins; rim is strong at grazing angles.
    float rim = pow(1.0 - dot(NORMAL, VIEW), rim_power);
    EMISSION = rim_color * rim;
}
```

### 4. 读取屏幕的后处理效果（4.x 提示，而非 SCREEN_TEXTURE）

```glsl
shader_type canvas_item;

// 4.x: declare the screen as a uniform with hint_screen_texture.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 4.0) = 1.0;

void fragment() {
    vec2 px = SCREEN_PIXEL_SIZE * blur;
    vec4 c = texture(screen_tex, SCREEN_UV);
    c += texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0));
    c += texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0));
    COLOR = c / 3.0;
}
```

从 GDScript 设置 uniform：

```gdscript
$Sprite2D.material.set_shader_parameter("amount", 0.7)
```

## 常见陷阱

- **3.x → 4.x 重命名。** `SCREEN_TEXTURE` 已被移除——请声明
  `uniform sampler2D x : hint_screen_texture;` 并使用 `SCREEN_UV` 采样。颜色提示
  `hint_color`→`source_color`；`hint_albedo`/`hint_white`→`source_color`；
  `hint_range` 保持不变。深度/法线使用 `hint_depth_texture` / `hint_normal_roughness_texture`。
- **输出变量错误。** 在 `canvas_item` 中写入 `COLOR`；在 `spatial` 中写入 `ALBEDO`
  （以及 `EMISSION`、`ALPHA`、`ROUGHNESS`、`METALLIC`）。在 spatial 着色器中写入
  `COLOR` 不会产生任何效果。
- **不带 `source_color` 的颜色 uniforms** 会被视为原始线性值，并因 Godot 不进行 sRGB 转换而
  显得不正确（褪色/过暗）。
- **透明度需要显式启用（3D）。** 要让 `ALPHA < 1.0` 混合，请添加渲染模式或设置材质透明度；
  否则它是不透明的/会被裁切。
- **在 [0,1] UV 之外采样**且没有 `repeat_enable` 时会被钳制。为 sampler uniform 添加
  `: repeat_enable` 以实现平铺/滚动。
- **`TIME` 是启动后的秒数，**并会持续增长——对于周期效果，使用 `fract()`/`mod()` 包裹它，
  以避免精度漂移。
- **`discard` 在某些硬件上开销很高，**并会破坏 early-Z；如有可能，优先设置 `ALPHA`/`COLOR.a`。

## 参考资料

- 关于每种着色器类型的内置变量、渲染模式、`varying`、自定义 `light()`、`vertex()` 位移和
  可视化着色器图，请阅读 `references/shading-language.md`。

## 相关技能

- `shader-programming` — 与引擎无关的着色器概念（GLSL/HLSL）。
- `godot-3d-essentials` — 材质、环境，以及 spatial 着色器所在的位置。
- `godot-ui-control` — 将着色器应用于 UI 以实现效果。
