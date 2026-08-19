---
name: phaser-arcade-physics
description: >
  使用 Phaser 4 Arcade Physics：启用 world、为 sprite 添加 body、设置
  velocity/acceleration/gravity，并通过 collider、overlap、group 和 world bounds
  处理碰撞。适用于 Phaser 游戏需要移动或碰撞时——当用户提到 Arcade Physics、
  this.physics、setVelocity、collider、overlap、gravity、onFloor，或 platformer/
  top-down controller 时。游戏配置、scene 和 loader 请使用 phaser-core。
---

# Phaser 4 Arcade Physics

使用轻量级 **Arcade 为 Phaser 游戏添加运动和碰撞
物理**引擎（仅限 AABB 矩形和圆形）。目标 **Phaser 4.2** 用于
新项目；在编辑现有项目之前检查已安装的专业。

## 何时使用

- 用于自上而下或平台游戏运动、速度/加速度/重力、弹跳、
  世界边界以及精灵、组和图块之间的碰撞/重叠分辨率。
- 当场景启用`physics: { default: 'arcade' }`且代码调用时使用
  `this.physics.add.*`、`body.setVelocity` 或 `this.physics.add.collider`。

**何时*不*使用：** `Game` 配置、场景结构、资源加载或
相机→使用`phaser-core`。铰链、弹簧、复杂多边形或堆叠
刚体 → 使用Matter physics（不同的引擎；Arcade 和 Matter body
不互动）。对于与引擎无关的感觉调整，请参阅 `physics-tuning`。

## 核心工作流程

1. **启用 world。** 在游戏或 scene 配置中设置 `physics: { default: 'arcade', arcade: { gravity:`
   `{...}, debug: true } }`。构建时启用 `debug`，以查看 body 轮廓和速度向量。
2. **给精灵一个身体。** 使用 `this.physics.add.sprite(...)` 创建它（动态）
   或 `this.physics.add.staticImage(...)`（静态），或附加到现有对象
   与`this.physics.add.existing(obj)`。
3. **通过身体驱动它，而不是通过设置`x`/`y`。**使用`setVelocity`，
   `setAcceleration`、重力、`setBounce` 和 `setCollideWorldBounds`。发动机
   积分每一步速度的位置（已经与帧速率无关）。
4. **解决相互作用。** `this.physics.add.collider(a, b)` 分离物体；
   `this.physics.add.overlap(a, b, cb)` 无需分离即可检测（拾音器、
   触发器）。传递回调以做出反应。
5. **对多个对象进行分组。** 使用 `this.physics.add.group()`（动态）或
   `staticGroup()`（平台），因此一次对撞机调用即可处理所有成员。
6. **使用 `body.onFloor()` / `body.blocked.down` 之前检查接地情况**
   跳跃。使用 `debug: true` 运行并确认主体、接触和边界。

## 模式

### 1.启用街机物理（游戏配置）

```js
const config = {
  type: Phaser.AUTO,
  width: 800, height: 600,
  physics: {
    default: 'arcade',
    arcade: {
      gravity: { x: 0, y: 600 },  // top-down? use { x: 0, y: 0 }
      debug: false                // true to draw bodies + velocity while building
    }
  },
  scene: [PlayScene]
};
new Phaser.Game(config);
```

### 2.自上而下的运动（来自输入的速度）

```js
create() {
  this.player = this.physics.add.sprite(400, 300, 'player');
  this.player.setCollideWorldBounds(true);
  this.cursors = this.input.keyboard.createCursorKeys();
}

update() {
  const speed = 220;
  const body = this.player.body;
  body.setVelocity(0);                              // reset each frame
  if (this.cursors.left.isDown)  body.setVelocityX(-speed);
  if (this.cursors.right.isDown) body.setVelocityX(speed);
  if (this.cursors.up.isDown)    body.setVelocityY(-speed);
  if (this.cursors.down.isDown)  body.setVelocityY(speed);
  body.velocity.normalize().scale(speed);           // keep diagonals same speed
}
```

### 3.平台跳跃（重力+地面检查）

```js
create() {
  this.player = this.physics.add.sprite(100, 450, 'player');
  this.player.setCollideWorldBounds(true);

  // Static platforms: one body each, never moved by collisions.
  this.platforms = this.physics.add.staticGroup();
  this.platforms.create(400, 568, 'ground');
  this.physics.add.collider(this.player, this.platforms);

  this.cursors = this.input.keyboard.createCursorKeys();
}

update() {
  const onGround = this.player.body.blocked.down; // or this.player.body.onFloor()
  if (this.cursors.left.isDown)  this.player.setVelocityX(-160);
  else if (this.cursors.right.isDown) this.player.setVelocityX(160);
  else this.player.setVelocityX(0);

  if (this.cursors.up.isDown && onGround) this.player.setVelocityY(-450);
}
```

### 4. 碰撞与重叠（分离与检测）

```js
// Push apart and react: player vs enemies.
this.physics.add.collider(this.player, this.enemies, (player, enemy) => {
  this.handleHit(player, enemy);
});

// Detect without pushing: collect coins. The 4th arg is an optional
// process callback returning a boolean to filter pairs before the main callback.
this.physics.add.overlap(this.player, this.coins, (player, coin) => {
  coin.disableBody(true, true);              // deactivate + hide
  this.registry.inc('score', 10);
});
```

### 5. 一组移动的物体

```js
this.bullets = this.physics.add.group({
  defaultKey: 'bullet',
  maxSize: 30                  // pool size; reuse instead of allocating
});

fire(x, y) {
  const bullet = this.bullets.get(x, y);     // reuses a dead bullet if available
  if (!bullet) return;
  bullet.enableBody(true, x, y, true, true);
  bullet.setVelocityY(-500);
}
```

## 陷阱

- **精灵忽略物理** → 它是用 `this.add.sprite` 添加的，而不是
  `this.physics.add.sprite`（或`this.physics.add.existing(obj)`），所以它没有主体。
- **设置`sprite.x`直接对抗引擎** → 移动动态物体
  `setVelocity`/`setAcceleration`。直接位置写入可以穿过碰撞器。
- **对角线运动更快** → 独立的 X 和 Y 速度相加；正常化
  速度矢量并重新缩放到预期速度。
- **平台由玩家推动** → 使用 `staticGroup`，或设置
  动态平台上的 `body.setImmovable(true)`。
- **`onFloor()` 总是 false** → 身体需要一些东西来碰撞；添加
  检查前将 `collider` 靠在地面/平台上，并确保重力已开启。
- **移动了静态物体，但碰撞已过时** → 静态物体不会自动同步；
  调用 `body.updateFromGameObject()`（或游戏对象上的 `refreshBody()`）。
- **每帧添加碰撞体** → 在 `create` 中注册一次 `collider`/`overlap`，
  不在`update`。

## 参考

- 用于身体解剖学和调整（拖动、弹跳、最大速度、自定义 `setSize`/
  `setCircle`/`setOffset` 碰撞箱、碰撞类别/遮罩和 `worldbounds`
  事件），读取 `references/bodies-and-collision.md`。

## 相关技能

- `phaser-core` — 游戏配置、场景、加载器、摄像机（必备设置）。
- `physics-tuning` — 与引擎无关的感觉（固定时间步长、隧道效应、抖动）。
- `platformer` / `tower-defense` — 构成该技能的流派。
- `level-design` — 布置这些物体碰撞的瓷砖/平台几何形状。
