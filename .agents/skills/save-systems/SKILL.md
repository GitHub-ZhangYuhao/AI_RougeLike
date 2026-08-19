---
name: save-systems
description: >
  设计游戏状态保存/加载功能——选择序列化内容、文件格式、存档槽位、原子性崩溃安全写入、模式版本控制与迁移，以及自动保存。引擎无关通用方案。当用户提及“保存系统”、“保存/加载”、“游戏状态持久化”、“存档槽位”、“自动保存”、“存档文件损坏”或将旧存档迁移至新版本时请使用本技能。
---

# 保存系统

存档文件是**能够跨越重启存活下来的序列化快照**。难点不在于写入字节，而在于选择*要保存什么内容*、以何种方式写入使得中途崩溃不会导致数据损坏，以及在发布补丁后读取*旧的*存档。将这三点做好，其余皆为工程细节。

## 何时使用

- **用于持久化进度**：玩家属性、背包物品、世界标志位、设置项、位置等——跨越会话和游戏更新。
- **用于设计存档槽位、快速保存/自动保存及崩溃安全写入**。
- **当旧版存档文件在内容或代码变更后失效时使用（版本控制与迁移）**。

**何时不使用：** 针对 Roblox 云端持久化具体实现，请使用 `roblox-datastores`；对于存档所序列化的数据模型（资源/SO），请使用 `godot-resources` / `unity-scriptableobjects`；若涉及 Godot 的 `FileAccess`/`ResourceSaver` 及 `user://` 路径，请延后至使用 Godot 引擎技能时再应用本处的模式。

## 核心工作流

1. **决定哪些状态具有权威性。** 保存*数据本身*（生命值、位置、种子、解锁标志位），而非引擎对象或场景节点。加载时将基于数据重建对象——绝不序列化活动节点的引用。
2. **定义带版本号的架构。** 每个存档都嵌入一个 `version` 整数字段。这是你打算发布补丁的游戏中最关键的单一字段。
3. **选择文件格式。** JSON/文本用于可读性和可调试性；二进制格式用于节省空间或提升速度，或提供轻微的防篡改能力。首选从 JSON 开始。
4. **原子写入。** 序列化到临时文件、刷新缓冲区，然后重命名为正式文件名。崩溃后只会留下旧存档或新存档——绝不会留下半写完成的损坏数据。
5. **防御性加载。** 读取版本号 → 迁移至当前版本 → 验证完整性 → 实例化对象。保留最后一个有效存档的备份，并在解析失败时回退使用它。
6. **在安全边界（关卡切换、检查点）触发自动保存**，并进行节流控制，且写入独立槽位以防止覆盖手动保存的文件。
7. **进行验证：** 执行保存 → 完全退出游戏 → 重新启动并加载存档 → 通过人工检查确认状态一致。测试从上一个版本加载存档的情况。

## 模式与技巧

### 1. 将状态序列化为纯数据（而非引擎对象）

```gdscript
# Build a dictionary of pure data. Each savable object reports its own state.
func capture_state() -> Dictionary:
    return {
        "version": SAVE_VERSION,                 # ALWAYS stamp the schema version
        "player": { "hp": player.hp, "pos": [player.position.x, player.position.y] },
        "inventory": player.inventory.to_array(),  # ids + counts, not Item nodes
        "flags": world.flags,                    # e.g. {"met_guard": true}
        "seed": world.seed,                      # regenerate procedural content
    }

# On load, RECONSTRUCT objects from the data — do not expect live references back.
func apply_state(data: Dictionary) -> void:
    player.hp = data["player"]["hp"]
    player.position = Vector2(data["player"]["pos"][0], data["player"]["pos"][1])
    player.inventory.from_array(data["inventory"])
    world.flags = data["flags"]
```
### 2. 原子性、崩溃安全写入（临时文件 + 重命名）

```gdscript
# RIGHT: write to a temp file, then atomically rename over the target.
func save_atomic(path: String, data: Dictionary) -> void:
    var tmp := path + ".tmp"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    f.store_string(JSON.stringify(data))
    f.flush()                                    # ensure bytes hit disk
    f.close()
    DirAccess.rename_absolute(tmp, path)         # replaces the target; atomic on POSIX
# WRONG: opening `path` directly and writing in place — a crash mid-write leaves a
# truncated, unloadable save and destroys the player's progress.
```
在 POSIX 系统（同一卷）上，覆盖目标文件是原子的；但在 Windows 上，通过重命名进行替换并不保证原子性。因此，在执行重命名之前应将旧文件保存为 `path + ".bak"`——这个备份才是真正确保你能从坏写入中恢复的关键。

### 3. 带迁移的版本化加载

```python
SAVE_VERSION = 3

def load_save(raw_bytes):
    data = parse(raw_bytes)                  # JSON/binary -> dict
    v = data.get("version", 0)
    if v > SAVE_VERSION:
        raise NewerSaveError(v)              # save is from a newer build; refuse
    while v < SAVE_VERSION:                   # apply migrations in order, v -> v+1
        data = MIGRATIONS[v](data)
        v += 1
        data["version"] = v
    validate(data)                            # check required keys / ranges
    return data

# Each migration is a pure function from one version's shape to the next.
def migrate_1_to_2(d):
    d["flags"] = {k: True for k in d.pop("completed_quests", [])}  # list -> set-map
    return d
MIGRATIONS = {1: migrate_1_to_2, 2: migrate_2_to_3}
```
### 4. 存档槽位 + 节流自动保存

```gdscript
const SLOT_PATH := "user://save_%d.json"      # manual slots 0..N
const AUTOSAVE_PATH := "user://autosave.json"  # separate file: never clobbers a slot
var _autosave_cooldown := 0.0

func autosave_if_due(dt: float) -> void:
    _autosave_cooldown -= dt
    if _autosave_cooldown <= 0.0:
        save_atomic(AUTOSAVE_PATH, capture_state())
        _autosave_cooldown = 60.0             # throttle: at most once a minute
# Trigger an immediate autosave on checkpoints/level transitions, not mid-combat.
```
## 常见陷阱与注意事项

- **序列化引擎对象或节点路径**会将存档绑定到场景结构；重命名一个节点会导致所有旧版存档失效。应保存数据，加载时重建对象。
- **缺少版本字段。** 当你发布补丁的那一天，每个现有存档都变成了一场猜谜游戏。从第 1 个版本开始就打上 `version` 标记。
- **原地写入**会在崩溃或断电时损坏存档。务必先写临时文件再重命名；保留 `.bak` 备份。
- **盲目信任文件内容。** 存档可能被截断、手动编辑或因云同步而变得过时。加载时需验证完整性，并在失败时使用备份回退。
- **浮点数与区域设置问题。** 文本序列化器可能会丢失精度或在某些区域使用逗号作为小数分隔符。请使用不受区域影响（locale-invariant）的序列化器。
- **自动保存覆盖手动存档**，或在中断动作时触发导致状态不一致。应使用专用的自动保存槽位，并在安全边界处执行保存操作。
- **存储秘密信息或在多人游戏中信任客户端存档。** 本地存档由玩家控制；绝不可将其视为在线状态的权威来源。对于云端数据，需处理设备的数据限制与冲突处理（`roblox-datastores`）。

## 参考资料

- `references/versioning-and-migration.md` —— 架构演进策略、迁移链、备份/回滚方案、格式权衡（JSON vs 二进制）以及加载时的验证检查清单。

## 相关技能

- `roblox-datastores` —— 云端持久化、请求限制与会话锁定机制。
- `godot-resources`, `unity-scriptableobjects` —— 你所序列化的数据模型基础。
- `procedural-gen` —— 存储种子以重新生成世界，而非直接保存整个世界实例。
- `rpg`, `survival-crafting`, `visual-novel` —— 组合使用本技能的典型游戏类型。
