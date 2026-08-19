---
name: roblox-datastores
description: >
  使用 DataStoreService 在 Roblox 中持久保存玩家数据：将 GetDataStore、GetAsync/
  SetAsync/UpdateAsync/IncrementAsync 包装在 pcall 中，处理 load-on-join、
  save-on-leave、BindToClose、重试和 OrderedDataStore 排行榜。适用于在 Roblox
  体验中保存或加载持久数据——当用户提到 DataStore、DataStoreService、GetAsync、
  SetAsync、UpdateAsync、保存玩家数据或排行榜时。通用 Luau 脚本请使用 roblox-luau。
---

# Roblox DataStores

使用 `DataStoreService` 在 Roblox 中跨会话保留数据：加入时加载，
节省休假和关机、安全更新、重试和有序存储的时间
排行榜。仅限服务器端。

## 何时使用

- 用于保存/加载玩家进度（金币、库存、等级），构建持久性
  排行榜，或修复数据丢失、覆盖和限制。
- 当服务器代码调用 `DataStoreService`、`GetDataStore`、`GetAsync`、
  `SetAsync`、`UpdateAsync` 或 `GetOrderedDataStore`。

**何时*不*使用：**通用脚本、服务、远程、客户端/服务器
分裂 → `roblox-luau`。高频临时状态（牵线搭桥，每轮）→
内存存储（不同的服务）。与引擎无关的持久性理论 →
`save-systems`。

## 核心工作流程

1. **启用 Studio 访问一次。** 文件 → 游戏设置 → 安全 → *启用 Studio
   访问 API 服务*（使用测试位置；Studio 获取实时数据）。数据存储
   仅从服务器 `Script` 工作，从不从 `LocalScript` 工作。
2. **获取一个store，然后通过key读/写。** `DataStoreService:GetDataStore("Name")`;
   每个玩家的密钥通常是 `"Player_" .. player.UserId`。
3. **将每个呼叫包裹在`pcall`中。** `GetAsync`/`SetAsync`/`UpdateAsync` 是网络
   可能失败的调用；不受保护的故障会导致线程出错并面临数据丢失的风险。
4. **在 `PlayerAdded` 上加载，在 `PlayerRemoving` 上保存，以及 `BindToClose` 上。** A
   离开玩家和关闭服务器都需要最终保存。
5. **优先选择 `UpdateAsync` 进行读-修改-写**（多服务器安全）而不是 `SetAsync`
   （盲覆盖）。加载失败时，不要用默认值覆盖 - 中止
   保存，这样您就不会擦除好的数据。
6. **通过 `GetSortedAsync` 使用 `OrderedDataStore` 获取排名数据**（排行榜）。
   通过加入、更改数据、重新加入并确认数据持续进行测试。

## 模式

### 1. 连接时加载（pcall 保护）

```lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local store = DataStoreService:GetDataStore("PlayerData")

local DEFAULT = { Coins = 0, Level = 1 }

Players.PlayerAdded:Connect(function(player)
    local key = "Player_" .. player.UserId
    local ok, data = pcall(function()
        return store:GetAsync(key)
    end)

    if not ok then
        -- Load FAILED (network). Do not treat as a new player; flag so we never save
        -- over their real data with defaults.
        warn("Load failed for", player.Name, data)
        player:SetAttribute("DataLoaded", false)
        return
    end

    player:SetAttribute("DataLoaded", true)
    local profile = data or DEFAULT          -- nil == genuinely new player
    applyToLeaderstats(player, profile)
end)
```

### 2.使用UpdateAsync保存（多服务器安全）

```lua
-- UpdateAsync reads the latest value, then writes what the callback returns.
-- The callback MUST NOT yield (no task.wait, no further Async calls inside it).
local function savePlayer(player)
    if player:GetAttribute("DataLoaded") == false then return end  -- never overwrite on a bad load
    local key = "Player_" .. player.UserId
    local newData = gatherDataFor(player)    -- a plain table of serializable values

    local ok, err = pcall(function()
        store:UpdateAsync(key, function(old)
            -- merge/decide here; return nil to cancel the write
            return newData
        end)
    end)
    if not ok then warn("Save failed for", player.Name, err) end
end
```

### 3.休假和关机时保存

```lua
Players.PlayerRemoving:Connect(savePlayer)

-- BindToClose runs when the server shuts down; save everyone still in.
-- It has a limited time budget, so save in parallel and yield until done.
game:BindToClose(function()
    local players = Players:GetPlayers()
    local remaining = #players
    if remaining == 0 then return end
    for _, player in players do
        task.spawn(function()
            savePlayer(player)
            remaining -= 1
        end)
    end
    while remaining > 0 do task.wait() end
end)
```

### 4. 退避重试（暂时失败）

```lua
local function withRetry(fn, attempts)
    attempts = attempts or 3
    for i = 1, attempts do
        local ok, result = pcall(fn)
        if ok then return true, result end
        if i < attempts then task.wait(2 ^ i) end   -- 2s, 4s, ... backoff
    end
    return false
end

local ok, data = withRetry(function() return store:GetAsync(key) end)
```

### 5. 增加一个计数器

```lua
-- IncrementAsync is a convenience for integer read-modify-write (still wrap it).
local ok, newTotal = pcall(function()
    return store:IncrementAsync("Visits_" .. player.UserId, 1)
end)
```

### 6. 带 OrderedDataStore 的排行榜

```lua
local boards = DataStoreService:GetOrderedDataStore("Coins")

-- Write a player's score (call when it changes, not every frame).
pcall(function() boards:SetAsync("Player_" .. player.UserId, coins) end)

-- Read the top 10, descending.
local ok, pages = pcall(function()
    return boards:GetSortedAsync(false, 10)   -- ascending=false → highest first
end)
if ok then
    for rank, entry in ipairs(pages:GetCurrentPage()) do
        print(rank, entry.key, entry.value)   -- entry.value is the number
    end
end
```

## 陷阱

- **未处理的故障会擦除进度** → 始终为 `pcall` 异步调用；在失败的
  *加载*，标记会话并拒绝*保存*，因此默认值永远不会覆盖真实数据。
- **服务器之间的 `SetAsync` 竞争** → 写入相同密钥的两个服务器可能会崩溃
  彼此。使用 `UpdateAsync` 进行读取-修改-写入，以便每次写入都能看到最新的内容。
- **`UpdateAsync` 回调内部屈服** → 回调无法调用
  `task.wait`或其他异步函数；预先计算新值并返回它。
- **没有 `BindToClose` 保存** → 服务器关闭时玩家会丢失未保存的进度；
  添加 `game:BindToClose` 并等待保存在预算范围内完成。
- **限制/“请求过多”** → 尊重每个键和每分钟的限制；不
  节省每次值更改。在计时器/休假时批量并保存。 `GetAsync` 是
  短暂缓存，因此立即重新读取可能会过时。
- **存储不可序列化的值** → 仅保留 JSON 可序列化数据：数字、
  字符串、布尔值和带有字符串/数字键的表。 `Instance`s、`Vector3`、
  `CFrame`，而函数则不然——首先将它们序列化为普通表。
- **无需 API 访问进行测试** → 无法在 Studio 中静默使用数据存储，直到
  *启用 Studio 访问 API 服务*已打开（并且它们无法从
  `LocalScript`）。
- **对于订购的商店来说，`DataStoreKeyInfo` 为零** → `OrderedDataStore` 不是
  支持版本控制/元数据；当您需要时，请使用常规 `DataStore`。

## 参考

- 对于会话锁定（防止跨服务器重复数据）、版本控制/
  具有 `DataStoreSetOptions` 的元数据，有序存储分页
  (`AdvanceToNextPageAsync`)，关键错误代码和请求限制，以及
  “被遗忘权”合规性，请阅读 `references/sessions-and-limits.md`。

## 相关技能

- `roblox-luau` — 服务、实例、事件和服务器/客户端模型。
- `save-systems` — 与引擎无关的序列化、插槽和迁移。
