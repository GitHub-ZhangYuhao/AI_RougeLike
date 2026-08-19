---
name: phaser-core
description: >
  设置和调试 Phaser 4 游戏：Game 配置、Scene 生命周期
  （init/preload/create/update）、asset loader、camera 和跨 scene 通信。
  适用于构建或调试 Phaser 游戏——当用户提到 Phaser、Phaser.Game、Phaser.Scene、
  preload/create/update、this.load、this.add 或 scene transition 时。
  Arcade Physics 移动/碰撞请使用 phaser-arcade-physics。
---

# Phaser 4 核心

设置 Phaser 游戏的基础：`Game` 配置、`Scene`
生命周期、资产加载、相机以及场景之间的数据传递。目标
**Phaser 4.2** 适用于新项目；保留现有的 Phaser 3.90 项目
除非用户明确要求迁移，否则固定专业。

## 何时使用

- 在启动 Phaser 游戏、连接 `Phaser.Game` 配置、构建
  `Scene`s，加载`preload`中的资源，或修复场景转换和共享
  状态。
- 当项目中有`package.json`或`import Phaser from 'phaser'`中的`phaser`时使用，
  代码使用`preload()`/`create()`/`update()`。

**何时*不*使用：** 移动、速度、碰撞、重力或重叠 → 使用
`phaser-arcade-physics`。复杂的刚体模拟使用Matter physics（a
单独关注）。对于跨引擎保存/加载模式，请使用 `save-systems`。

## 核心工作流程

1. **首先检测已安装的专业。** 读取 `package.json` 和锁定文件。使用
   新作Phaser 4.2；不要默默地将 Phaser 3 项目重写为 Phaser 4。
2. **从配置创建游戏。** `new Phaser.Game(config)` 并使用 `type:
   Phaser.AUTO` (WebGL with Canvas fallback), a `width`/`height`, and a `scene`
   大批。第一个场景（以及任何带有 `active: true` 的场景）自动开始。
3. **将每个屏幕建模为 `Scene`。** 子类 `Phaser.Scene`，传递唯一的
   `key` 到 `super`，并实现生命周期：`init(data)` → `preload()` →
   `create(data)` → `update(time, delta)`。
4. **加载`preload`中的资源，在`create`中使用它们。**排队的资源不
   直到 `create` 为止可用。加载程序是针对每个场景的；它填充的缓存是全局的。
5. **在 `init()` 中重置每次运行状态，而不是构造函数。** 场景实例是
   在重新启动时重用，因此构造函数集字段保留陈旧的值。
6. **使用 `this.scene.start/launch/switch/sleep/wake` 在屏幕之间移动**。
   通过 `this.registry`（全局）或同级场景的事件发射器共享数据。
7. **运行并观察。** 提供页面，打开它，并确认资产加载（观看
   网络选项卡和控制台）和场景在假设成功之前按预期切换。

## 模式

### 1.游戏配置+启动（ES模块）

```js
// main.js — one Game owns the renderer, loop, cache, and Scene Manager.
import Phaser from 'phaser';
import BootScene from './scenes/BootScene.js';
import PlayScene from './scenes/PlayScene.js';

const config = {
  type: Phaser.AUTO,            // WebGL if available, else Canvas
  width: 800,
  height: 600,
  backgroundColor: '#1d1d28',
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: [BootScene, PlayScene] // BootScene starts first
};

new Phaser.Game(config);
```

### 2. 具有完整生命周期的场景

```js
// scenes/PlayScene.js
import Phaser from 'phaser';

export default class PlayScene extends Phaser.Scene {
  constructor() {
    super('play');                  // unique scene key
  }

  init(data) {
    // Reset run-specific state HERE so restarts start clean.
    this.score = 0;
    this.level = data.level ?? 1;
  }

  preload() {
    // Queue downloads. Not usable until create().
    this.load.image('player', 'assets/player.png');
    this.load.spritesheet('coin', 'assets/coin.png', { frameWidth: 16, frameHeight: 16 });
  }

  create() {
    this.player = this.add.sprite(400, 300, 'player');
    this.scoreText = this.add.text(10, 10, 'Score: 0', { fontSize: '20px', color: '#fff' });
    this.cursors = this.input.keyboard.createCursorKeys();
  }

  update(time, delta) {
    // delta is milliseconds since last frame; divide by 1000 for seconds.
    const speed = 200 * (delta / 1000);
    if (this.cursors.left.isDown)  this.player.x -= speed;
    if (this.cursors.right.isDown) this.player.x += speed;
  }
}
```

### 3.跨场景数据+事件

```js
// The registry is a global DataManager shared by every scene.
this.registry.set('coins', 0);                 // in any scene
const coins = this.registry.get('coins');      // read anywhere

// React to registry changes (e.g. a HUD scene listening to gameplay):
this.registry.events.on('changedata-coins', (parent, value) => {
  this.coinText.setText(`Coins: ${value}`);
});

// Talk directly to another running scene via its event emitter:
const ui = this.scene.get('hud');
ui.events.emit('show-message', 'Level cleared!');
```

### 4.场景转换（选择正确的动词）

```js
this.scene.start('gameover', { score: this.score }); // stop this scene, start target
this.scene.launch('hud');        // run a second scene in parallel (overlay HUD)
this.scene.switch('menu');       // sleep this scene, start/wake target
this.scene.pause();              // freeze updates but keep rendering (modal)
this.scene.sleep();              // stop updating AND rendering, keep state for wake
```

### 5. 跟随玩家的摄像机

```js
this.cameras.main.setBounds(0, 0, 1600, 1200);  // world size
this.cameras.main.startFollow(this.player, true, 0.1, 0.1); // smooth lerp follow
this.cameras.main.setZoom(1.5);
```

## 陷阱

- **资产是 `create`/`update` 中的 `undefined`** → 您忘记将它们排队
  `preload`，或者使用了错误的密钥。装载机在`preload`和`create`之间运行。
- **重新启动时状态泄漏** → 您在构造函数中设置字段。现场
  实例被重用；重置 `init()` 中的运行状态并清除 `shutdown` 上的数组。
- **`this.scene.start` vs `this.scene.launch`** → `start` 停止调用场景；
  `launch` 与它一起运行目标。使用 `start` 作为 HUD 会隐藏游戏。
- **`this` 在回调中是错误的** → 箭头函数保留场景的 `this`；清楚的
  `function` 回调需要上下文参数或 `.bind(this)`。
- **Phaser 2 教程不起作用** → “States”在 Phaser 3 中被重命名为“Scenes”，
  每个场景都拥有自己的系统（输入、相机、补间），而不是全局的
  Game World。
- **Phaser 3 自定义管道在 Phaser 4 中失败** → Phaser 4 重建了渲​​染器并
  替换了旧的 FX/管道扩展点。迁移自定义着色器和渲染器
  针对 Phaser 4 指南的插件；不要机械地复制内部渲染器代码。
- **没有任何渲染/黑屏** → 确认画布已安装，`width`/`height`
  设置完毕，并且场景实际启动（检查 `game.scene.dump()` 输出）。

## 参考

- 对于全场景状态机（暂停/恢复 vs 睡眠/唤醒 vs 停止/启动），
  重新启动状态错误，并删除/替换场景），阅读
  `references/scene-flow.md`。

## 相关技能

- `phaser-arcade-physics` — 速度、重力、碰撞器、重叠和组。
- `input-systems` — 可重新绑定的多设备输入架构（与引擎无关）。
- `pixijs-rendering` / `threejs-scene-setup` — 其他浏览器渲染堆栈。
- `platformer` / `puzzle` — 构成 Phaser 技能的流派模板。
