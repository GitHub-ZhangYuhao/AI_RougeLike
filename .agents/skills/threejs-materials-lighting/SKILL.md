---
name: threejs-materials-lighting
description: >
  为 three.js scene 添加光照和着色：选择 material（MeshStandardMaterial PBR 与
  unlit MeshBasicMaterial）、添加 ambient/hemisphere/directional/point/spot light、
  启用 shadow map，并使用 environment map（IBL）实现逼真的反射。适用于 three.js
  模型看起来发黑、扁平或不正确时——当用户提到 three.js material、
  MeshStandardMaterial、light、shadow、envMap 或 PBR 时。renderer/loop 设置请使用
  threejs-scene-setup；加载模型请使用 threejs-gltf-loading。
---

# three.js 材质与照明

让 three.js 表面看起来正确：选择正确的材质，照亮场景，
启用阴影并添加基于图像的照明。模式目标**r184**，已验证
反对 **r184** （自 r155 以来，照明默认基于物理）。

## 何时使用

- 当网格呈现黑色或平坦时、选择材质、添加灯光、
  启用阴影，或设置环境贴图反射 (IBL)。
- 当代码构造 `MeshStandardMaterial`、`DirectionalLight` 等或设置时使用
  `renderer.shadowMap.enabled` 或 `scene.environment`。

**当*不*使用时：**渲染器/相机/循环 → `threejs-scene-setup`。加载中
模型（补充其 PBR 材料）→ `threejs-gltf-loading`。风俗
GLSL/`ShaderMaterial` 是它自己的主题；对于便携式概念，请参见
`shader-programming`。

## 核心工作流程

1. **根据需要选择材质。** `MeshStandardMaterial`（PBR：`roughness`，
   `metalness`，对灯光/IBL）做出反应以实现真实感； `MeshPhysicalMaterial` 为
   透明涂层/传输； `MeshBasicMaterial`（不亮，忽略灯光）用于 UI/平面；
   `MeshNormalMaterial`/`MeshDepthMaterial` 用于调试。
2. **添加灯光，否则什么也不显示。** 发光材料需要光源和/或
   `scene.environment`。将软填充 (`AmbientLight`/`HemisphereLight`) 与
   键`DirectionalLight`。
3. **注意光强度。** 自 r155 起，照明是基于物理的；现代的
   强度高于旧教程（关键 `DirectionalLight` ≈ 1-3）。
4. **在三个地方启用阴影。** `renderer.shadowMap.enabled = true`，
   灯光为 `castShadow = true`，每个网格为 `castShadow`/`receiveShadow`。然后
   将灯光的阴影相机安装到场景中。
5. **使用环境贴图进行接地反射。**指定等距矩形或
   PMREM 处理纹理为 `scene.environment`； PBR材质捡起来
   自动地。
6. **在真实照明下验证** — 确认表面对主光做出响应
   （高光移动），阴影落在预期的位置，反射看起来似乎合理。

## 模式

### 1. 3灯装置下的PBR材质

```js
import * as THREE from 'three';

const material = new THREE.MeshStandardMaterial({
  color: 0xcc4444,
  roughness: 0.5,     // 0 = mirror, 1 = fully matte
  metalness: 0.0,     // 0 = dielectric (plastic/wood), 1 = metal
});
const mesh = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 16), material);
scene.add(mesh);

// Soft sky/ground fill + a directional key light.
scene.add(new THREE.HemisphereLight(0xbbddff, 0x443322, 1.0)); // sky, ground, intensity
const key = new THREE.DirectionalLight(0xffffff, 2.5);
key.position.set(5, 10, 7);
scene.add(key);
```

### 2. 不发光材质（不需要光源）

```js
// MeshBasicMaterial ignores lights — for flat color, UI, or sprites/labels.
const flat = new THREE.MeshBasicMaterial({ color: 0x44aa88 });
// A textured color map should be tagged sRGB so colors aren't washed out:
const tex = new THREE.TextureLoader().load('assets/logo.png');
tex.colorSpace = THREE.SRGBColorSpace;
const logo = new THREE.MeshBasicMaterial({ map: tex, transparent: true });
```

### 3.阴影（所需的三个开关+相机适配）

```js
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;     // softer edges

const sun = new THREE.DirectionalLight(0xffffff, 3);
sun.position.set(8, 12, 6);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);                   // default 512; raise for crisp
// DirectionalLight uses an OrthographicCamera — fit it tightly to the scene:
const cam = sun.shadow.camera;
cam.near = 1; cam.far = 40;
cam.left = -15; cam.right = 15; cam.top = 15; cam.bottom = -15;
scene.add(sun);

mesh.castShadow = true;
ground.receiveShadow = true;                          // a plane to catch the shadow
```

### 4. 材质上的 PBR 纹理

```js
const loader = new THREE.TextureLoader();
const colorMap = loader.load('assets/brick_color.jpg');
colorMap.colorSpace = THREE.SRGBColorSpace;           // color maps are sRGB
const normalMap = loader.load('assets/brick_normal.jpg'); // data maps stay linear
const roughMap  = loader.load('assets/brick_rough.jpg');

const brick = new THREE.MeshStandardMaterial({
  map: colorMap,
  normalMap,
  roughnessMap: roughMap,
  metalness: 0,
});
```

### 5. HDR 环境中基于图像的照明

```js
import { RGBELoader } from 'three/addons/loaders/RGBELoader.js';

new RGBELoader().load('assets/studio.hdr', (hdr) => {
  hdr.mapping = THREE.EquirectangularReflectionMapping;
  scene.environment = hdr;     // lights + reflects all PBR materials
  scene.background = hdr;       // optional: show it as the backdrop
});
// Optional cinematic tone curve:
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
```

## 陷阱

- **网格为纯黑色** → 发光材质，无光且无`scene.environment`。
  添加灯光或环境贴图；为了确认几何形状，暂时交换到
  `MeshBasicMaterial`/`MeshNormalMaterial`。
- **即使有灯光，场景也太暗** → 旧教程强度。 r155+ 物理上
  基于;提高强度（主光 ≈ 2–3）或添加环境贴图。
- **阴影不出现** → 你错过了三个开关之一
  (`renderer.shadowMap.enabled`、`light.castShadow`、网状`castShadow`/
  `receiveShadow`）。
- **阴影被切断或块状** → `DirectionalLight` 的正交
  `shadow.camera` 视锥体太大/太小或者没有覆盖场景；收紧
  `left/right/top/bottom/near/far` 并加注 `shadow.mapSize`。可视化它
  `new THREE.CameraHelper(light.shadow.camera)`。
- **阴影痤疮/peter-panning** → 调整 `light.shadow.bias`（小负数）和
  `light.shadow.normalBias`。
- **颜色看起来褪色/太亮** → 颜色（反照率）纹理需要
  `texture.colorSpace = THREE.SRGBColorSpace`;法线/粗糙度/金属度贴图必须
  保持线性（将它们保留为 `NoColorSpace`）。
- **PointLight 阴影坦克性能** → 点光源渲染场景 6 次
  （立方体贴图）。优先选择1个阴影投射`DirectionalLight`；使用更便宜的假货
  别处。

## 参考

- 对于材质备忘单（`Mesh*Material` 的外观），灯光类型
  及其参数/单位、透明度与 `alphaTest` 排序以及
  `PMREMGenerator`/`RoomEnvironment` 路由至 IBL，无需 HDR 文件，读取
  `references/materials-lights-table.md`。

## 相关技能

- `threejs-scene-setup` — 渲染器、相机和循环（设置 `shadowMap`、色调映射）。
- `threejs-gltf-loading` — 模型附带此技能调整的 PBR 材质。
- `shader-programming` — 自定义着色器效果（与引擎无关的概念）。
