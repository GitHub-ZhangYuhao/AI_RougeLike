---
name: threejs-scene-setup
description: >
  搭建 three.js 场景：import map 与 three/addons 路径、
  Scene/PerspectiveCamera/WebGLRenderer 三件套、setAnimationLoop 渲染循环、
  响应式尺寸调整和 OrbitControls。适用于启动或调试 three.js 应用——当用户提到
  three.js、THREE.Scene、WebGLRenderer、PerspectiveCamera、渲染循环、尺寸调整或
  OrbitControls 时使用。模型请用 threejs-gltf-loading；材质/灯光请用
  threejs-materials-lighting。
---

# three.js 场景搭建

创建 three.js 应用的基础：模块加载、场景/相机/渲染器三件套、渲染循环、
响应式尺寸调整和相机控制。模式以 **r184** 为目标。修改现有项目前请读取已安装的
`three` 版本，因为示例和 addons 会随版本变化。

## 何时使用

- 在初始化 three.js 场景、修复空白/黑色画布、使画布响应式、设置动画循环或添加
  `OrbitControls` 时使用。
- 当 `package.json` 依赖 `three`，且代码使用 `import * as THREE from 'three'` 时使用。

**不应使用的情况：**加载 `.gltf`/`.glb` 模型或蒙皮动画 → `threejs-gltf-loading`；
材质、灯光、阴影、环境贴图 → `threejs-materials-lighting`；2D 渲染 → `pixijs-rendering`。

## 核心工作流

1. **使用 import map 将 three.js 作为 ES 模块加载。** 从 r147 起，裸说明符 `'three'`
   和 `'three/addons/'` 必须映射（在 HTML 中或由打包工具完成）。控件、加载器等 addons
   位于 `three/addons/...` 下。
2. **创建三件套。** 创建 `Scene`（场景图根节点）、从原点向后移动的
   `PerspectiveCamera(fov, aspect, near, far)`，以及 `domElement` 位于 DOM 中的
   `WebGLRenderer`。设置尺寸和 `pixelRatio`。
3. **添加网格。** 使用 `new Mesh(geometry, material)` 和 `scene.add(mesh)`。
   若使用受光材质，还需要灯光（见 `threejs-materials-lighting`）。
4. **用 `renderer.setAnimationLoop(fn)` 驱动渲染循环。** 它是手写
   `requestAnimationFrame` 的现代替代方案，并且兼容 WebXR/WebGPU。用 `Clock` 获取增量时间。
5. **处理尺寸调整**，让相机宽高比和渲染器与画布匹配；更新 `camera.aspect`，调用
   `updateProjectionMatrix()` 和 `renderer.setSize(...)`。
6. **开发时添加 `OrbitControls`** 以便环绕/平移/缩放。先确认内容确实渲染出来
   （例如受光立方体、控件有响应），再认定成功。

## 模式

### 1. HTML import map + 模块入口（无打包工具）

```html
<canvas id="c"></canvas>
<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.184.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.184.0/examples/jsm/"
  }
}
</script>
<script type="module" src="./main.js"></script>
```

使用打包工具（Vite/webpack）时，跳过 import map，只需执行 `npm i three`；
相同的 `import` 语句仍会正常解析。

### 2. 场景 + 相机 + 渲染器

```js
// main.js
import * as THREE from 'three';

const canvas = document.querySelector('#c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // cap for perf
renderer.setSize(window.innerWidth, window.innerHeight);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x101018);

const camera = new THREE.PerspectiveCamera(
  60,                                   // vertical field of view (degrees)
  window.innerWidth / window.innerHeight, // aspect
  0.1,                                  // near
  100                                   // far
);
camera.position.set(3, 2, 5);
camera.lookAt(0, 0, 0);

const cube = new THREE.Mesh(
  new THREE.BoxGeometry(1, 1, 1),
  new THREE.MeshNormalMaterial()        // unlit; shows orientation without a light
);
scene.add(cube);
```

### 3. 渲染循环（setAnimationLoop + Clock）

```js
const clock = new THREE.Clock();

renderer.setAnimationLoop(() => {
  const dt = clock.getDelta();          // seconds since last frame
  cube.rotation.x += dt;                // frame-rate independent
  cube.rotation.y += dt * 0.7;
  renderer.render(scene, camera);
});
// renderer.setAnimationLoop(null); // stop the loop
```

### 4. 响应式尺寸调整

```js
function onResize() {
  const w = window.innerWidth, h = window.innerHeight;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();      // required after changing aspect
  renderer.setSize(w, h);
}
window.addEventListener('resize', onResize);
```

### 5. OrbitControls（环绕 / 平移 / 缩放）

```js
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;          // inertial feel
controls.target.set(0, 0, 0);

renderer.setAnimationLoop(() => {
  controls.update();                    // needed every frame when damping is on
  renderer.render(scene, camera);
});
```

## 常见陷阱

- **`Failed to resolve module specifier "three"`** → 缺少 import map（或打包工具配置）。
  同时映射 `"three"` 和 `"three/addons/"`；addon 路径必须以 `/` 结尾。
- **画布全黑但没有错误** → 相机位于原点（物体内部/后方），或使用了受光材质
  （`MeshStandardMaterial`）却没有灯光。将相机后移；先用
  `MeshNormalMaterial`/`MeshBasicMaterial` 验证几何体。
- **没有任何动画** → 循环内从未调用 `renderer.render`，或调用了 `setAnimationLoop`
  却在循环外渲染。
- **调整尺寸时画面拉伸/压扁** → 调整了渲染器尺寸，却未更新
  `camera.aspect` + `updateProjectionMatrix()`。
- **HiDPI 下模糊或有锯齿** → 设置 `renderer.setPixelRatio(...)`；将其限制在约 2，
  避免 4K/retina 屏幕拖垮性能。
- **OrbitControls 没有响应** → 使用 `enableDamping = true` 时，必须每帧调用
  `controls.update()`。
- **旧教程使用 `<script src="three.min.js">`** → 从 r147 起 three.js 仅发布 ES 模块；
  请使用 `type="module"` + import map。

## 参考资料

- 坐标约定、场景图（`Group`、父子变换、`Object3D` 添加/移除）、用于 2.5D 的
  `OrthographicCamera`，以及为避免泄漏而释放几何体/材质/纹理的方法，见
  `references/scene-graph.md`。

## 相关技能

- `threejs-materials-lighting` — 为表面提供受光外观（灯光、阴影、PBR）。
- `threejs-gltf-loading` — 加载 3D 模型并播放其动画。
- `pixijs-rendering` — 浏览器中的 2D 渲染。
- `fps-shooter` — 组合 three.js 技能的 3D 类型模板。
