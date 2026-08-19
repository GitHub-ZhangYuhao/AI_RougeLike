---
name: pygame-core
description: >
  使用 Python 构建 pygame（pygame-ce）游戏：init/event/update/draw 循环、
  delta-time 运动、Surface/Rect blitting、键盘/鼠标输入，以及带碰撞的
  Sprite/Group 管理。适用于构建或调试 pygame 游戏——当用户提到 pygame、
  pygame-ce、game loop、blit、Surface、Rect、sprite groups 或 clock.tick 时。
  目标为 pygame-ce。
---

# pygame核心

使用Python构建pygame游戏的基础：主循环、增量时间
运动、使用`Surface`/`Rect`绘图、输入和`Sprite`/`Group`管理。
目标 **pygame-ce 2.5.7** （积极维护的社区分叉；相同
`import pygame`）。

## 何时使用

- 在启动 pygame 游戏时使用，修复循环、依赖于帧速率的速度、
  输入处理、位块传送或精灵/组碰撞。
- 当代码执行 `import pygame` 且项目依赖于 `pygame-ce` 时使用
  （或`pygame`）。

**何时*不*使用：**与pygame无关的Python语言问题。 3D渲染
（pygame 是 2D）。对于跨引擎保存/加载，请使用 `save-systems`；用于可重新绑定的输入
架构见`input-systems`。

## 核心工作流程

1. **这是安装pygame-ce，而不是旧版本的pygame。** `pip install pygame-ce` —
   维持前叉和导入为`pygame`。不要将两者安装在一个环境中。
2. **初始化并打开一个窗口。** `pygame.init()`, `screen =
   pygame.display.set_mode((w, h))`, `clock = pygame.time.Clock()`。
3. **运行一个循环：事件 → 更新 → 绘制 → 翻转。** 每隔一次泵送事件队列
   帧（`for event in pygame.event.get()`），更新状态，重绘，然后
   `pygame.display.flip()`。
4. **导致与帧速率无关。**获取`dt = clock.tick(60) / 1000`（秒）
   并按 `dt` 缩放所有运动。保持持仓浮动； blit 位于矩函数处。
5. **处理输入有两种方式：**基于事件（`KEYDOWN`/`MOUSEBUTTONDOWN`，用于离散）
   动作）和轮询（`pygame.key.get_pressed()`，用于保持移动）。
6. **用 `Sprite` + `Group` 组织对象。** `pygame.sprite.Sprite` 子类
   与 `image`/`rect`； `group.update(dt)` 和 `group.draw(screen)` 处理
   批。运行它并观察窗口，然后再假设它可以工作。

## 模式

### 1. 最小游戏循环（骨架）

```python
import pygame

pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("My Game")
clock = pygame.time.Clock()

running = True
while running:
    dt = clock.tick(60) / 1000          # cap at 60 FPS; dt = seconds since last frame
    for event in pygame.event.get():    # MUST drain the queue or the OS thinks it hung
        if event.type == pygame.QUIT:
            running = False

    # update game state here, scaled by dt ...

    screen.fill((18, 18, 28))           # clear each frame
    # draw everything here ...
    pygame.display.flip()               # present the frame

pygame.quit()
```

### 2. 增量时间运动（与帧速率无关）

```python
from pygame.math import Vector2

pos = Vector2(100, 100)        # keep position as floats
speed = 220                    # PIXELS PER SECOND, not per frame

# inside the loop, after computing dt:
keys = pygame.key.get_pressed()
direction = Vector2(
    keys[pygame.K_RIGHT] - keys[pygame.K_LEFT],
    keys[pygame.K_DOWN]  - keys[pygame.K_UP],
)
if direction.length_squared() > 0:
    direction = direction.normalize()      # equal speed on diagonals
pos += direction * speed * dt              # RIGHT: dt-scaled
screen.blit(player_img, (round(pos.x), round(pos.y)))  # blit at integer pixels
```

### 3. 输入：事件与轮询

```python
for event in pygame.event.get():
    if event.type == pygame.QUIT:
        running = False
    elif event.type == pygame.KEYDOWN:        # discrete press: jump, menu, pause
        if event.key == pygame.K_SPACE:
            jump()
        elif event.key == pygame.K_ESCAPE:
            running = False
    elif event.type == pygame.MOUSEBUTTONDOWN:
        shoot_at(event.pos)                   # event.pos = (x, y)

# Polled state (read once per frame) for continuous/held input:
keys = pygame.key.get_pressed()
if keys[pygame.K_a]:
    move_left(dt)
```

### 4.一个Sprite子类+一个Group

```python
class Player(pygame.sprite.Sprite):
    def __init__(self, x, y):
        super().__init__()
        # convert() once at load makes blits much faster; _alpha keeps transparency.
        self.image = pygame.image.load("player.png").convert_alpha()
        self.rect = self.image.get_rect(center=(x, y))
        self.pos = pygame.math.Vector2(self.rect.center)
        self.speed = 240

    def update(self, dt):                      # Group.update(dt) calls this per sprite
        keys = pygame.key.get_pressed()
        self.pos.x += (keys[pygame.K_RIGHT] - keys[pygame.K_LEFT]) * self.speed * dt
        self.rect.center = (round(self.pos.x), round(self.pos.y))

all_sprites = pygame.sprite.Group()
all_sprites.add(Player(400, 300))

# in the loop:
all_sprites.update(dt)        # calls each sprite's update(dt)
all_sprites.draw(screen)      # blits each sprite at its rect
```

### 5. 碰撞检测

```python
# Sprite vs group: e.g. player picking up coins (True = remove collided coins).
collected = pygame.sprite.spritecollide(player, coins, dokill=True)
score += len(collected)

# Group vs group: bullets vs enemies (kill both on hit).
hits = pygame.sprite.groupcollide(bullets, enemies, True, True)

# Plain rect overlap (no sprites needed):
if player.rect.colliderect(door_rect):
    open_door()
```

## 陷阱

- **窗口冻结/“无响应”** → 您没有抽吸事件队列。称呼
  每帧 `pygame.event.get()`（或 `pygame.event.pump()`）。
- **速度较快的机器上的速度有所不同** → 每帧移动固定的量。
  单击 `dt = clock.tick(fps) / 1000` 缩放并使用每秒像素值。
- **子像素移动吸附/睡眠** → `rect` 坐标为整数；存储
  真实位置作为浮点分配的`Vector2`并分别为`rect.center = round(...)`
  框架。
- **Blits 很慢/帧率下降** → 调用 `.convert()` （不透明）或
  `.convert_alpha()`（透明）加载图像一次；未转换的表面块传输
  慢得多。
- **什么也没有出现** → 你忘记了`pygame.display.flip()`（或`update()`），或者你
  在`screen.fill(...)`之前相等，因此被清除。
- **错误的顺序** → pygame 使用画家的顺序；后面的位块传送覆盖了前面的位块传送。
  先绘制背景，最后绘制精灵。
- **`pip install pygame` 得到了旧的** → 用于维护叉子使用
  `pip install pygame-ce`；两者安装都会导致导入冲突。
- **对角线移动更快** → 在缩放之前对方向向量进行归一化
  速度。

## 参考

- 对于`Group`变体（`GroupSingle`、`LayeredUpdates`用于z顺序），像素完美
  与`mask`碰撞、切割精灵表、简单动画、声音/音乐，以及
  文本渲染，阅读`references/sprites-and-collision.md`。

## 相关技能

- `love2d-core` — LÖVE/Lua 中相同的循环概念。
- `bevy-ecs` — 当项目无法满足 pygame 的需求时，使用更重的 ECS 引擎。
- `input-systems` / `save-systems` — 与引擎无关的输入和持久性。
- `platformer` / `roguelike` — 与 pygame 仪表的类型模板。
