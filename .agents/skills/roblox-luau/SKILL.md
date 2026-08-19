---
name: roblox-luau
description: >
  使用 Luau 为 Roblox 体验编写脚本：获取服务、创建 Instance 并设置父级、
  连接事件、运行服务器 Script 与客户端 LocalScript，以及通过
  RemoteEvent/RemoteFunction 跨越客户端/服务器边界通信（服务器权威）。
  适用于构建或调试 Roblox Studio 脚本——当用户提到 Roblox、Luau、服务、
  RemoteEvent、Instance.new、PlayerAdded 或客户端与服务器时。保存玩家数据请使用 roblox-datastores。
---

# Roblox Luau 脚本

在 **Luau** 中编写 Roblox 体验：服务、`Instance`、活动、
服务器/客户端分离，安全跨界通信。瞄准当前
Roblox 引擎和 Studio。

## 何时使用

- 编写 Roblox 脚本时使用：获取服务、创建/父子实例、
  连接事件，决定服务器还是客户端，或接线 `RemoteEvent`/
  `RemoteFunction`通讯。
- 当项目有 `Script`/`LocalScript`/`ModuleScript` 对象、`.rbxl(x)` 时使用
  位置，或 Rojo `*.project.json`，代码调用 `game:GetService(...)`。

**何时*不*使用：**跨会话持久保存数据 → `roblox-datastores`。
与 Roblox API 无关的通用 Lua 问题。与引擎无关的输入/保存
架构 → `input-systems` / `save-systems`。

## 核心工作流程

1. **通过`game:GetService("Name")`获得服务。**常见的：`Players`，
   `Workspace`、`ReplicatedStorage`（共享客户端+服务器）、`ServerScriptService`
   （仅服务器代码），`ServerStorage`，`RunService`，`UserInputService`（客户端）。
2. **知道代码在哪里运行。** `Script` 在**服务器**上运行； `LocalScript`
   在 **客户端** 上运行（在 `StarterPlayerScripts`、`StarterGui` 或玩家的
   特点）。 `ModuleScript` 是您共享的代码 `require`。
3. **故意创建实例。** `local p = Instance.new("Part")`，设置其
   属性，然后设置 `p.Parent` **最后**（父子关系触发复制）。
4. **对事件做出反应。** `:Connect` 到 `Players.PlayerAdded` 等信号，
   `part.Touched`，或`RunService.Heartbeat`。完成后断开连接以避免泄漏。
5. **使用遥控器跨越客户端/服务器边界 - 并且永远不要信任客户端。**
   客户通过`RemoteEvent:FireServer(...)`请求；服务器验证并
   适用。服务器对所有游戏状态具有权威性。
6. **在 Studio 中测试** 用 Play / Play Here / 服务器+客户端 启动；使用输出
   窗口和服务器/客户端视图切换以确认代码运行的位置。

## 模式

### 1. 服务器脚本：对玩家加入做出反应（leaderstats）

```lua
-- ServerScriptService/Leaderboard.server.luau  (a Script = runs on the server)
local Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"          -- this name makes it show on the leaderboard

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = stats

    stats.Parent = player               -- parent LAST
end

Players.PlayerAdded:Connect(onPlayerAdded)
```

### 2.创建并配置实例

```lua
local Workspace = game:GetService("Workspace")

local part = Instance.new("Part")
part.Size = Vector3.new(4, 1, 4)
part.Position = Vector3.new(0, 10, 0)
part.Anchored = true                    -- won't fall under gravity
part.BrickColor = BrickColor.new("Bright blue")
part.Parent = Workspace                 -- set Parent last so it replicates once, fully
```

### 3. 连接事件（并断开连接以避免泄漏）

```lua
local debounce = false
local connection
connection = part.Touched:Connect(function(hit: BasePart)
    local character = hit.Parent
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or debounce then return end
    debounce = true
    humanoid.Health -= 10
    task.wait(1)                        -- task.wait, NOT the deprecated wait()
    debounce = false
end)

-- Later, when the part is removed or the round ends:
-- connection:Disconnect()
```

### 4. 客户端→带有 RemoteEvent 的服务器（在服务器上验证！）

```lua
-- ReplicatedStorage: create a RemoteEvent named "BuyItem" (in Studio or via code).
-- CLIENT (LocalScript): request a purchase. The client can lie — this is only a request.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")  -- wait: may not have replicated yet
buyButton.MouseButton1Click:Connect(function()
    buyItem:FireServer("sword")        -- send the item id only; never the price/result
end)
```

```lua
-- SERVER (Script): the ONLY place the transaction is decided.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local buyItem = ReplicatedStorage:WaitForChild("BuyItem")
local PRICES = { sword = 100, shield = 75 }

buyItem.OnServerEvent:Connect(function(player: Player, itemId)
    -- TRUST NOTHING from the client. Validate types and values.
    if type(itemId) ~= "string" then return end
    local price = PRICES[itemId]
    if not price then return end                         -- unknown item
    local coins = player.leaderstats.Coins
    if coins.Value < price then return end               -- can't afford
    coins.Value -= price                                 -- server applies the change
    grantItem(player, itemId)
end)
```

### 5. 使用 RunService 进行每帧循环

```lua
local RunService = game:GetService("RunService")
-- Heartbeat fires every frame AFTER physics; dt is seconds since the last step.
RunService.Heartbeat:Connect(function(dt)
    spinner.CFrame *= CFrame.Angles(0, math.rad(90) * dt, 0)  -- 90deg/sec, frame-independent
end)
```

### 6. ModuleScript 中的共享代码

```lua
-- ReplicatedStorage/GameConfig (a ModuleScript) — usable by server and client.
local GameConfig = {}
GameConfig.MaxHealth = 100
function GameConfig.damageFor(weapon: string): number
    return ({ sword = 25, bow = 15 })[weapon] or 0
end
return GameConfig
```

```lua
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))
print(GameConfig.MaxHealth)
```

## 陷阱

- **信任客户端是一种漏洞** → 客户端可以将任何参数发送给
  `RemoteEvent`/`RemoteFunction`。验证每个参数的类型和范围
  服务器并保持服务器对健康、货币和库存的权威。
- **`LocalScript` 不会在你放置的地方运行** → LocalScripts 运行在
  `StarterPlayerScripts`、`StarterCharacterScripts`、`StarterGui` 或工具 — 不在其中
  `Workspace` 或 `ServerScriptService`。服务器 `Script` 属于
  `ServerScriptService`/`Workspace`。
- **已弃用的全局变量** → 使用 `task.wait`/`task.spawn`/`task.delay`，而不是旧的
  `wait()`/`spawn()`/`delay()`（更糟糕的调度和节流）。
- **先育儿，再设置属性**→先设置属性然后`Parent`
  最后，因此实例在其最终状态下复制一次。
- **加入后立即在客户端上出现 `nil`** → 对象随着时间的推移进行流式传输/复制；使用
  `parent:WaitForChild("Name")` 而不是直接在客户端建立索引。
- **连接永远不会断开** → 长期存在的 `:Connect` 处理程序会泄漏并可能
  对被毁坏的物体起火；存储连接和 `:Disconnect()` （或使用
  `Instance:GetAttributeChangedSignal`/`:Once`（如适用）。
- **在 RemoteEvent 适合的地方使用 RemoteFunction** → `RemoteFunction` 块
  等待返回，恶意/缓慢的客户端可能会导致服务器停顿；更喜欢
  除非您确实需要回复，否则单向 `RemoteEvent`。

## 参考

- 对于完整的客户端/服务器模型（复制、`RemoteFunction` 与 `RemoteEvent`、
  `:WaitForChild` 计时，`BindableEvent` 用于相同上下文消息传递、属性、
  `CollectionService` 标签和 `:Once`/连接清理），读取
  `references/client-server.md`。

## 相关技能

- `roblox-datastores` — 跨会话持久保存玩家数据（仅限服务器）。
- `save-systems` — 与引擎无关的持久性概念。
- `game-ai` / `input-systems` — 在 Luau 中实现的便携式 AI 和输入模式。
