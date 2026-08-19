---
name: love2d-core
description: >
  使用 Lua 构建和调试 LÖVE（Love2D）游戏：love.load/update/draw 循环、基于 delta time
  的移动、输入和屏幕状态。适用于构建 LÖVE 11.x 游戏（main.lua、conf.lua、.love）。
---

# LÖVE（Love2D）核心

使用 Lua 搭建和调试 LÖVE 游戏的基础：回调循环、帧率无关移动、输入和屏幕状态。
目标版本为 **LÖVE 11.5**。

## 何时使用

- 在开始制作 LÖVE 游戏、连接 `main.lua`/`conf.lua`，或修复核心循环、速度不正确的移动、
  输入处理或屏幕切换时使用。
- 当工作区中有调用 `love.*` 的 `main.lua`、`conf.lua` 或 `.love` 文件时使用。

**不应使用的情况：**与 LÖVE 无关的 Lua *语言*问题；刚体/关节物理（LÖVE 通过 `love.physics` 使用 Box2D，属于独立主题）；shader 代码（`love.graphics` GLSL 同样属于独立主题）。跨引擎保存/加载模式请使用 `save-systems`。

## 核心工作流

1. **确认入口点。** LÖVE 游戏运行 `main.lua`；其中应定义 `love.load()`（一次性设置）、
   `love.update(dt)`（状态）和 `love.draw()`（渲染）。窗口/版本设置放在 `conf.lua` 中
   （在模块加载*之前*运行）。
2. **锁定版本。** 在 `conf.lua` 中设置 `t.version = "11.5"`，让 LÖVE 在版本不匹配时发出警告。
3. **所有移动都由 `dt` 驱动**（以秒为单位的增量时间），使速度与帧率无关。
4. **用两种方式处理输入：**轮询（在 `update` 中使用 `love.keyboard.isDown`，用于按住的按键）和
   事件（`love.keypressed` 回调，用于离散按键操作）。
5. **管理屏幕**（菜单、游戏、暂停）时使用小型状态栈，而不是堆叠大量 `if` 标志——参见模式和
   `references/state-stack.md`。
6. **运行并观察。** 在项目文件夹中用 `love .` 启动；先验证窗口、移动速度和屏幕输入，
   再认定其正常工作。

## 模式

### 1. `main.lua` 骨架（回调循环 + 输入）

```lua
-- main.lua — LÖVE calls these callbacks for you. Colors are 0–1 in LÖVE 11.x.
function love.load()
    -- One-time setup. speed is in PIXELS PER SECOND, not per frame.
    player = { x = 100, y = 100, size = 40, speed = 220 }
    love.graphics.setBackgroundColor(0.1, 0.1, 0.12)
end

function love.update(dt)
    -- Polled input: good for continuous movement while a key is held.
    if love.keyboard.isDown("right") then player.x = player.x + player.speed * dt end
    if love.keyboard.isDown("left")  then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("down")  then player.y = player.y + player.speed * dt end
    if love.keyboard.isDown("up")    then player.y = player.y - player.speed * dt end
end

function love.draw()
    love.graphics.setColor(0.2, 0.8, 1.0)                 -- tint ON
    love.graphics.rectangle("fill", player.x, player.y, player.size, player.size)
    love.graphics.setColor(1, 1, 1)                       -- reset tint before text/images
    love.graphics.print("Arrow keys to move, Esc to quit", 10, 10)
end

function love.keypressed(key)
    -- Event input: fires once per physical press. Use for menus, jumps, toggles.
    if key == "escape" then love.event.quit() end
end
```

### 2. 帧率无关（最常见的单一问题）

```lua
-- RIGHT: scaled by dt → same real-world speed at 30 or 240 FPS.
player.x = player.x + player.speed * dt
-- WRONG: "pixels per frame" → moves twice as fast at double the frame rate.
player.x = player.x + player.speed
```

### 3. `conf.lua`（窗口 + 版本；在 `main.lua` 之前运行）

```lua
-- conf.lua — must be its own file; love.conf will NOT run from main.lua.
function love.conf(t)
    t.version = "11.5"             -- the LÖVE version this game targets (string "X.Y")
    t.window.title  = "My LÖVE Game"
    t.window.width  = 800
    t.window.height = 600
    t.window.vsync  = 1            -- number since 11.0: 1 = on, 0 = off, -1 = adaptive
    t.window.resizable = false
    t.modules.physics = false      -- disable modules you don't use to trim startup/memory
end
```

### 4. LÖVE 11.x 中的颜色范围是 0–1（而非 0–255）

```lua
-- LÖVE 11.x uses normalized floats. (Pre-11.0 code used 0–255 and will look wrong.)
love.graphics.setColor(1, 0, 0)                          -- opaque red
love.graphics.setColor(0.2, 0.8, 1.0, 0.5)               -- translucent cyan (alpha 0.5)
-- Need to convert old byte values? Use the helper instead of dividing by hand:
love.graphics.setColor(love.math.colorFromBytes(128, 234, 255))
```

### 5. 屏幕状态（简述——完整管理器见 `references/`）

```lua
-- A screen is a table with optional :update(dt), :draw(), :keypressed(key).
-- Keep the active screen on a stack so pause/menu overlays are trivial to pop.
local Stack = require("state_stack")   -- see references/state-stack.md for the module
function love.load()              Stack.push(require("screens.menu")) end
function love.update(dt)          Stack.current():update(dt) end
function love.draw()              Stack.current():draw() end
function love.keypressed(key)     Stack.current():keypressed(key) end
```

## 常见陷阱

- **速度随 FPS 变化** → 忘记了 `* dt`。位置、计时器或动画的每帧变化都必须按 `dt` 缩放。
- **把 `love.conf` 放在 `main.lua` 中** → 它会无声地不起作用。它必须位于 `conf.lua` 中，
  LÖVE 会在加载模块*之前*运行该文件。
- **颜色发白或不可见** → 使用了 0–255 值。在 11.x 中，`setColor(255,0,0)` 会被钳制为白色；
  请使用 `setColor(1,0,0)` 或 `love.math.colorFromBytes`。
- **一次 `setColor` 后所有内容都染色** → 颜色是全局状态，会跨绘制持续存在。
  在绘制不希望染色的文本/图像前，用 `love.graphics.setColor(1, 1, 1)` 重置。
- **松开按键/按键重复时没有反应** → `love.keypressed(key, scancode, isrepeat)` 在按下时
  （以及操作系统按键重复时）触发；松开请用 `love.keyreleased`，如需忽略按住产生的重复，
  请检查 `isrepeat`。

## 参考资料

- 完整的推入/弹出式屏幕状态管理器（菜单 → 游戏 → 暂停，并委托回调）见
  `references/state-stack.md`。

## 相关技能

- `save-systems` — 保存/加载游戏状态（与引擎无关）。
- `input-systems` — 可重新绑定的多设备输入架构。
- `pygame-core` / `phaser-core` — 其他轻量级引擎中的相同循环概念。
