---
name: godot-multiplayer
description: >
  使用 Godot 4.7 高级多人游戏功能构建联网游戏：设置 ENetMultiplayerPeer 服务器/客户端、
  使用 @rpc 注解定义 RPC（通过 rpc()/rpc_id() 调用）、设置各节点的多人权限，
  并通过 MultiplayerSpawner 和 MultiplayerSynchronizer 复制状态。为 Godot 项目添加
  多人游戏/网络功能、编写 @rpc 函数，或在各 peer 之间同步玩家/世界状态时使用。
---

# Godot 多人游戏（4.x 高级 API）

连接 peer、使用 `@rpc` 远程调用函数、分配权限，并通过
`MultiplayerSpawner`/`MultiplayerSynchronizer` 复制状态。适用于 **Godot 4.7** (ENet)。
将所有客户端输入视为不可信；保持服务器权威。

## 何时使用

- 添加联网多人游戏时使用：通过 ENet 托管/加入、调用 RPC、分配各节点的权限，
  或在各 peer 之间自动生成/同步节点。

**不应使用的情况：** 本地分屏（无网络）；原始 TCP/UDP/WebSocket 协议工作
（低级 `PacketPeer`）；HTTP 请求。保存/持久化请使用 → `save-systems`。

## 核心工作流

1. **创建 peer**（`ENetMultiplayerPeer`），调用 `create_server(port, max)` 或
   `create_client(ip, port)`，并将其分配给 `multiplayer.multiplayer_peer`。
   服务器的唯一 ID 始终为 `1`；客户端获得随机正 ID。
2. 处理 `multiplayer` 上的**连接信号**：`peer_connected(id)`、`peer_disconnected(id)`、
   `connected_to_server`、`connection_failed`、`server_disconnected`。
3. **使用 `@rpc(...)` 定义 RPC。** 通过 Callable 的 `rpc()`（所有 peer）或
   `rpc_id(peer_id)`（一个 peer）调用。在其内部，`multiplayer.get_remote_sender_id()`
   会告诉你发送者是谁。
4. **在运行该脚本的每个 peer 上保持 RPC 签名一致**——Godot 会校验脚本中所有 `@rpc`
   方法的 checksum；不匹配会静默失败。
5. 使用 `set_multiplayer_authority(id)` 为各节点**分配权限**；通过
   `is_multiplayer_authority()` 限制输入/RPC。
6. 使用 `MultiplayerSpawner`（在客户端自动实例化场景）和
   `MultiplayerSynchronizer`（自动同步选定属性）**复制状态**。
7. **在服务器上验证。** 不要信任客户端报告的位置/结果。

## 模式

### 1. 托管或加入 (ENet)

```gdscript
const PORT := 7000
const MAX_PLAYERS := 8

func host() -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(PORT, MAX_PLAYERS)
    if err != OK:
        push_error("Cannot host: %s" % err); return
    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)

func join(ip := "127.0.0.1") -> void:
    var peer := ENetMultiplayerPeer.new()
    peer.create_client(ip, PORT)
    multiplayer.multiplayer_peer = peer
    multiplayer.connected_to_server.connect(func(): print("connected"))

func leave() -> void:
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
```

### 2. RPC：客户端向服务器发送输入 (any_peer, call_local)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("fire") and is_multiplayer_authority():
        request_fire.rpc_id(1)          # send only to the server (id 1)

# Clients may call this; it runs on the server (and locally if server is a player).
@rpc("any_peer", "call_local", "reliable")
func request_fire() -> void:
    var sender := multiplayer.get_remote_sender_id()
    if not _can_fire(sender):           # server-side validation
        return
    spawn_projectile.rpc(sender)        # tell everyone to spawn it

@rpc("authority", "call_local", "reliable")
func spawn_projectile(owner_id: int) -> void:
    _do_spawn(owner_id)
```

### 3. 各节点权限（每位玩家控制自己的 avatar）

```gdscript
extends CharacterBody2D

func _ready() -> void:
    # The node name is the owning peer's id; that peer is the authority.
    set_multiplayer_authority(name.to_int())

func _physics_process(delta: float) -> void:
    if not is_multiplayer_authority():
        return                          # only the owner reads input & moves
    velocity = Input.get_vector("left", "right", "up", "down") * 200.0
    move_and_slide()
```

### 4. MultiplayerSynchronizer 配置（编辑器 + 复制）

```gdscript
# Add a MultiplayerSynchronizer child; in its Replication editor add the properties to
# sync (e.g. position, velocity). Set "Sync"/"Spawn" flags per property. From code you
# can scope visibility:
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _ready() -> void:
    # Only replicate this node to a specific peer (e.g. private info).
    sync.set_visibility_for(target_peer_id, true)
```

## 常见陷阱

- **RPC 签名 checksum。** 客户端和服务器构建中，脚本里的每个 `@rpc` 方法都必须以相同声明
  存在——*即使是未使用的方法*。不匹配时，错误可能指向错误的函数。不会检查参数名/数量，
  但会检查 RPC 集合及其注解。
- **`@rpc` 默认为 `"authority"`。** 除非设置 `"any_peer"`，否则客户端调用会被忽略。
  使用 `"call_local"`，使主机（同时也是玩家）也在本地运行它。
- **各 peer 的 NodePath 必须匹配。** RPC 路由使用节点的路径/名称；在所有 peer 上以相同名称
  生成节点（使用 `MultiplayerSpawner` 或 `add_child(node, true)` 获得可读、确定的名称）。
- **信任客户端。** 切勿让客户端直接设置权威状态（生命值、位置、命中）。发送*意图*，
  在服务器上验证，然后广播结果。
- **非 Node 类上的 RPC 会失败。** `@rpc` 方法必须位于 `Node` 派生类上，
  不能位于普通 `Resource`/`RefCounted` 上。
- **RPC 不会序列化 Objects/Callables。** 传递普通数据（int、string、array、dictionary、
  PackedArrays）。
- **忘记重置 peer。** 要干净地断开连接，请设置
  `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()`。
- **Android 需要 INTERNET 权限**，否则所有网络功能都会被阻止。

## 参考资料

- 有关 `MultiplayerSpawner` 设置、传输模式/channel、`SceneMultiplayer` 身份验证
  （`auth_callback`/`complete_auth`）、lobby 骨架和专用服务器导出说明，请阅读
  `references/replication-and-rpc.md`。

## 相关 skill

- `godot-nodes-scenes` — 实例化要生成/同步的场景。
- `godot-signals-groups` — 连接信号和事件流。
- `godot-export` — 导出无头专用服务器构建。
