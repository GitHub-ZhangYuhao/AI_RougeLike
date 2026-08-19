---
name: pixijs-rendering
description: >
  构建 PixiJS v8 渲染层：创建异步 Application、使用 Assets 加载 texture、
  通过 Container 和 Sprite 组织 scene graph、驱动 ticker 循环、连接 pointer event，
  并使用 render group 合并绘制。适用于构建或调试 PixiJS v8——当用户提到 PixiJS、
  Pixi、Application、app.stage、Container、Sprite、Assets.load、app.ticker 或
  eventMode 时。固定使用 v8 的异步 init() API。
---

# PixiJS 8.19 渲染

设置和构建 PixiJS **8.19** 应用程序：异步 `Application`、资产
通过 `Assets`、`Container`/`Sprite` 场景图、ticker 循环加载，
指针事件和渲染组。固定8.19 API（异步`init`，统一
`Assets`、`eventMode`）。

## 何时使用

- 在启动 PixiJS v8 项目、修复空白画布、构建
  显示列表、加载纹理、通过ticker制作动画或处理指针
  输入。
- 当 `package.json` 依赖于 `pixi.js` (v8) 并且代码不依赖时使用
  `import { Application } from 'pixi.js'`。

**何时*不*使用：** Phaser 的场景/加载器模型 → `phaser-core`。 3D 场景 →
`threejs-scene-setup`。 PixiJS v7 及更早版本的代码（同步 `new
Application({...})`, `Loader`, `interactive = true`) 首先需要 v8 迁移；
该技能仅针对 v8。

## 核心工作流程

1. **创建并 `await` 应用程序。** 在 v8 中，`new Application()` 为空；
   配置发生在 `await app.init({...})` 中。附加`app.canvas`（不是
   `app.view`) 到 DOM。将顶级 `await` 包装在捆绑器的异步函数中。
2. **使用 `Assets` 加载资产。** `await Assets.load(url)` 返回 `Texture`。为了
   许多资产，注册清单/捆绑包并按名称加载。没有 v7 `Loader`。
3. **构建场景图。**一切都源自 `app.stage`（`Container`）。
   将`Container`s中的相关对象分组；子变换是相对于
   父母。绘制顺序=插入顺序（稍后=在顶部）。
4. **使用股票行情动画。** `app.ticker.add((ticker) => {...})`。缩放运动
   `ticker.deltaTime`（帧，60fps 时 ~1）或 `ticker.deltaMS`（毫秒）所以
   速度与帧速率无关。
5. **通过设置 `eventMode = 'static'`（或 `'dynamic'`）启用每个对象的事件**，
   那么`obj.on('pointerdown', ...)`。联合指针事件涵盖鼠标/触摸/笔。
6. **提升大型静态子树以渲染组**（`isRenderGroup: true`），因此
   GPU 缓存它们的转换。之前和之后的轮廓；确认屏幕上的像素。

## 模式

### 1. 异步应用程序启动（v8 入口点）

```js
import { Application, Assets, Sprite } from 'pixi.js';

(async () => {
  // v8: construct empty, then await init(). Config does NOT go in the constructor.
  const app = new Application();
  await app.init({
    background: '#1099bb',
    resizeTo: window,        // track the window size
    antialias: true,
    // preference: 'webgpu',  // opt into WebGPU; default 'webgl'
  });

  document.body.appendChild(app.canvas); // v8 uses app.canvas, not app.view

  const texture = await Assets.load('https://pixijs.com/assets/bunny.png');
  const bunny = new Sprite(texture);
  bunny.anchor.set(0.5);
  bunny.position.set(app.screen.width / 2, app.screen.height / 2);
  app.stage.addChild(bunny);
})();
```

### 2. 相对变换场景图的容器

```js
import { Container, Sprite } from 'pixi.js';

const world = new Container();
app.stage.addChild(world);

// Children are positioned relative to `world`; move/scale/rotate the whole group
// by transforming the parent.
for (let i = 0; i < 10; i++) {
  const coin = new Sprite(coinTexture);
  coin.x = i * 40;
  world.addChild(coin);
}
world.position.set(100, 100);
world.scale.set(2);            // every coin scales with the container
```

### 3. 股票行情循环（与帧速率无关）

```js
let elapsed = 0;
app.ticker.add((ticker) => {
  // deltaTime ≈ 1 at 60fps; deltaMS is milliseconds since last frame.
  elapsed += ticker.deltaMS;
  bunny.rotation += 0.05 * ticker.deltaTime;          // smooth at any frame rate
  bunny.y = app.screen.height / 2 + Math.sin(elapsed / 500) * 50;
});
```

### 4. 指针事件（联合）

```js
bunny.eventMode = 'static';   // 'static' = interactive, doesn't move on its own
bunny.cursor = 'pointer';
bunny.on('pointerdown', (event) => {
  bunny.tint = 0xff0000;
  // event.global is the pointer position in stage space.
});
bunny.on('pointerover', () => bunny.scale.set(1.1));
bunny.on('pointerout',  () => bunny.scale.set(1.0));
```

### 5. 按名称加载许多资产（捆绑包）

```js
import { Assets } from 'pixi.js';

await Assets.init({
  manifest: {
    bundles: [{
      name: 'level-1',
      assets: [
        { alias: 'hero',  src: 'assets/hero.png' },
        { alias: 'tiles', src: 'assets/tiles.png' },
      ],
    }],
  },
});

const bundle = await Assets.loadBundle('level-1'); // { hero: Texture, tiles: Texture }
const hero = new Sprite(bundle.hero);
```

### 6.大型静态图层的渲染组

```js
// A big, rarely-changing background subtree: let the GPU cache its transforms.
const background = new Container({ isRenderGroup: true });
app.stage.addChild(background);
// Add hundreds of static tiles to `background`. Moving `background` itself stays
// cheap; constantly re-adding/removing children negates the benefit.
```

## 陷阱

- **空白画布/“app.stage 未定义”** → 你没有 `await app.init()`，或者你
  配置了构造函数。在 v8 中，构造函数是空的；所有选项都转到
  `init()`。
- **`app.view` 未定义** → v8 将其重命名为 `app.canvas`。
- **v7 代码抛出** → `interactive = true` → `eventMode = 'static'`； `Loader`/
  `loader.add` → `Assets.load`；同步 `new Application({...})` → 异步 `init`。
- **顶级等待构建错误（Vite ≤6.0.6）** → 在 `(async () => { ... })()` 中包装启动。
- **速度随帧速率变化** → 将移动乘以 `ticker.deltaTime`（或使用
  `deltaMS`);永远不要假设 60fps。
- **点击不执行任何操作** → 对象的 `eventMode` 仍然是 `'none'`（默认值）；
  将其设置为 `'static'` 或 `'dynamic'`。
- **纹理在像素艺术上看起来模糊** → 设置
  `texture.source.scaleMode = 'nearest'`（或者加载时传递）。
- **内存增长** → `removeChild` 不释放 GPU 内存；称呼
  `sprite.destroy()` 和 `Assets.unload(url)` 表示您已完成的资产。

## 参考

- 对于纹理/资源管道（精灵表/图集、`Assets.add`、背景
  加载、卸载）和`Graphics`/`Text`/`TilingSprite`/`ParticleContainer` 以及
  过滤器，读取 `references/assets-and-display.md`。

## 相关技能

- `phaser-core` — 一个包含电池的 2D 框架（场景、物理、输入）。
- `threejs-scene-setup` — 使用 Three.js 在浏览器中实现 3D。
- `prototype-fast` — 灰盒快速播放切片（经常引用 PixiJS）。
