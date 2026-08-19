---
name: threejs-gltf-loading
description: >
  使用 GLTFLoader 在 three.js 中加载 glTF/GLB 模型，并通过 AnimationMixer 播放其
  skinned animation，包括 DRACO/Meshopt 压缩 mesh 和 KTX2 texture。适用于将 3D
  模型导入 three.js——当用户提到 glTF、GLB、GLTFLoader、AnimationMixer、
  animation clip、DRACOLoader 或“加载 3D 模型”时。scene/camera/renderer 设置请使用
  threejs-scene-setup；material 和 light 请使用 threejs-materials-lighting。
---

# three.js glTF 加载

加载`.gltf`/`.glb`模型并在three.js中播放它们的动画，包括
压缩几何体（DRACO/Meshopt）和纹理（KTX2）。图案目标
**r184**；保留现有项目的固定版本，除非请求迁移。

## 何时使用

- 用于导入 3D 模型，将其添加到场景中，检查其节点层次结构，以及
  使用 `AnimationMixer` 播放烘焙/蒙皮动画剪辑。
- 当文件为 `.gltf`/`.glb` 或代码导入 `GLTFLoader` / 时使用
  `DRACOLoader` / `KTX2Loader` 来自 `three/addons/loaders/...`。

**当*不*使用时：**创建渲染器/相机/循环 → `threejs-scene-setup`。
调整加载模型的表面外观、灯光或阴影→
`threejs-materials-lighting`。创作/导出模型本身（Blender）已过时
范围；对于运行时，更喜欢 glTF 而不是 OBJ/FBX。

## 核心工作流程

1. **为什么是glTF。** 它是一种传输格式：二进制顶点数据、PBR材质和
   动画已准备好以最少的解析进行渲染。比起 OBJ 更喜欢它（没有场景
   图形，无动画）和用于网络的 FBX（重）。
2. **加载 `GLTFLoader`。** `loader.load(url, onLoad, onProgress, onError)`。这
   结果`gltf`有`gltf.scene`（`Object3D`根），`gltf.animations`
   (`AnimationClip[]`)、`gltf.cameras` 和 `gltf.asset`。
3. **将 `gltf.scene` 添加到您的场景**并对其进行构图。检查层次结构
   `traverse` / `getObjectByName` 查找您要控制的部件。
4. **使用 `AnimationMixer` 播放动画。** 每个动画根有一个混音器；
   `mixer.clipAction(clip).play()`;每帧以 `mixer.update(delta)` 前进。
5. **解码压缩资源。** 附加 `DRACOLoader`（和/或 `KTX2Loader` +
   Meshopt）以便加载 DRACO 网格和 KTX2 纹理；将解码器指向他们的
   文件。
6. **验证加载的内容** — 记录场景图和 `gltf.animations`，并确认
   模型可见（正确比例，点亮）并且剪辑实际播放。

## 模式

### 1. 加载模型并对其进行框架

```js
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
loader.load(
  'assets/robot.glb',
  (gltf) => {
    const root = gltf.scene;
    scene.add(root);
    // Inspect: gltf.animations is an array of AnimationClip.
    console.log('clips:', gltf.animations.map((c) => c.name));
  },
  (event) => console.log(`${(event.loaded / event.total) * 100}% loaded`),
  (error) => console.error('glTF load failed:', error)
);
```

### 2.使用AnimationMixer播放蒙皮动画

```js
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

let mixer;                                  // declare outside so the loop can see it
const clock = new THREE.Clock();

new GLTFLoader().load('assets/character.glb', (gltf) => {
  scene.add(gltf.scene);
  mixer = new THREE.AnimationMixer(gltf.scene);          // one mixer per animated root
  const clip = THREE.AnimationClip.findByName(gltf.animations, 'Run')
            ?? gltf.animations[0];
  mixer.clipAction(clip).play();
});

renderer.setAnimationLoop(() => {
  const dt = clock.getDelta();
  if (mixer) mixer.update(dt);              // advance the animation by real seconds
  renderer.render(scene, camera);
});
```

### 3. 两个剪辑之间交叉淡入淡出

```js
const actions = {};
mixer = new THREE.AnimationMixer(gltf.scene);
for (const clip of gltf.animations) {
  actions[clip.name] = mixer.clipAction(clip);
}
actions['Idle'].play();

function transitionTo(name, duration = 0.3) {
  const next = actions[name];
  next.reset().play();
  for (const [n, action] of Object.entries(actions)) {
    if (n !== name) action.crossFadeTo(next, duration, false);
  }
}
```

### 4. DRACO 压缩几何

```js
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';

const draco = new DRACOLoader();
// Point at the decoder files you ship (or a pinned CDN copy of the same version).
draco.setDecoderPath('https://cdn.jsdelivr.net/npm/three@0.184.0/examples/jsm/libs/draco/');

const loader = new GLTFLoader();
loader.setDRACOLoader(draco);
loader.load('assets/city-draco.glb', (gltf) => scene.add(gltf.scene));
```

### 5. 查找指定零件并为其设置动画

```js
new GLTFLoader().load('assets/car.glb', (gltf) => {
  scene.add(gltf.scene);
  const wheels = [];
  gltf.scene.traverse((node) => {
    if (node.name.startsWith('Wheel')) wheels.push(node);
  });
  renderer.setAnimationLoop(() => {
    const dt = clock.getDelta();
    for (const w of wheels) w.rotation.x += dt * 4;
    renderer.render(scene, camera);
  });
});
```

## 陷阱

- **模型加载但不可见** → 它具有照明（PBR）材质，并且场景没有
  光线或环境。添加灯光或 `scene.environment`（参见
  `threejs-materials-lighting`），并检查比例 - glTF 以米为单位，因此 0.01-scaled
  资产很小。
- **`load` 是异步的** → `gltf` 只存在于回调内部；声明 `mixer`/refs
  外部并在回调中分配它们，或使用 `await loader.loadAsync(url)`。
- **动画永远不会移动** → 你没有每帧调用 `mixer.update(delta)`，或者你
  传递了毫秒而不是秒（使用 `clock.getDelta()`），或者你忘记了
  `action.play()`。
- **DRACO/KTX2 模型失败** → 解码器/转码器路径错误或版本-
  不匹配。 `setDecoderPath`/`setTranscoderPath` 必须指向与您的文件匹配的文件
  three.js版本。
- **多个混合器战斗** → 每个动画根使用 **一个** `AnimationMixer` 和
  从中创建所有动作；不要为每个剪辑创建一个新的混音器。
- **烘焙变换会让您大吃一惊** → 出口商有时会将缩放/旋转烘焙到
  子节点。在依赖之前转储层次结构（名称+位置/旋转/比例）
  节点的局部变换；如果装备不可用，请从源重新导出。
- **起源已关闭** → 在新的 `Object3D` 下重新设置零件的父级，以使其干净
  转向而不是对抗烘焙偏移。

## 参考

- 对于完整的解码/转码设置（DRACO + Meshopt + KTX2 一起），`loadAsync`
  + `LoadingManager` 进度条，与 `SkeletonUtils.clone` 重用模型，以及
  出口商指南（应用转换，一个干净的根），阅读
  `references/loaders-and-animation.md`。

## 相关技能

- `threejs-scene-setup` — 该模型渲染到的渲染器、相机和循环。
- `threejs-materials-lighting` — 照明/环境，使 PBR 模型看起来正确。
- `fps-shooter` — 一种由三个.js 技能组成的 3D 类型。
