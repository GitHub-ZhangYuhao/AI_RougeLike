extends Node
## 局外 Meta 存档（autoload 名：MetaSave）← js/meta/save.js（RULES.md §15.5）。
## 原型用 localStorage 键 CONFIG.meta.saveKey + memoryBackup 内存兜底；
## Godot 侧统一落 user://save.json（PORT_PLAN 决策 10）。
## 本 autoload 是纯函数库（对应原型 save.js 的导出函数），不自动加载/持有存档；
## 开局等时机由逻辑层显式调用 load_save()。

## 存档文件路径（user:// 在仓库之外，永不进 git）。
const SAVE_PATH: String = "user://save.json"


## 默认存档结构（= save.js defaultSave；storage/metaLevels 键序与
## js/meta/items.js META_ITEM_LIST、js/meta/shop.js SHOP_ATTRS 一致）。
func default_save() -> Dictionary:
    return {
        "version": 1,
        "darkCrystals": 0,
        "storage": {"shard": 0, "essence": 0, "soulCrystal": 0},
        "metaLevels": {"damage": 0, "armor": 0, "magnet": 0, "xp": 0, "maxHp": 0, "moveSpeed": 0},
        "stats": {"runs": 0, "extractions": 0, "completions": 0, "bestWave": 0, "totalBossKills": 0},
    }


## 深层合并（= save.js mergeInto）：只保留默认结构内的字段，缺失补默认值，
## 未知字段忽略；嵌套 Dictionary 递归合并；标量要求 JSON 类型一致
## （int/float 同为 JS number，视为同类型；null 一律拒绝）。
func merge_into(base: Dictionary, data: Variant) -> Dictionary:
    if typeof(data) != TYPE_DICTIONARY:
        return base
    var data_dict: Dictionary = data
    for key: Variant in base.keys():
        if not data_dict.has(key):
            continue
        var base_val: Variant = base[key]
        var data_val: Variant = data_dict[key]
        if typeof(base_val) == TYPE_DICTIONARY:
            merge_into(base_val, data_val)
        elif data_val != null and _same_json_type(base_val, data_val):
            base[key] = data_val
    return base


## 读取存档：文件缺失 / JSON 损坏 / version != 1 一律返回默认存档。
func load_save() -> Dictionary:
    var raw: String = ""
    if FileAccess.file_exists(SAVE_PATH):
        var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file != null:
            raw = file.get_as_text()
            file.close()
    if raw.strip_edges().is_empty():
        return default_save()
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return default_save()
    var data: Dictionary = parsed
    if data.get("version") != 1:
        return default_save()
    return merge_into(default_save(), data)


## 写入存档（= save.js persistSave）。返回是否写盘成功。
func persist_save(save_data: Dictionary) -> bool:
    var raw: String = JSON.stringify(save_data)
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("MetaSave: cannot open %s for writing (err=%d)" % [SAVE_PATH, FileAccess.get_open_error()])
        return false
    file.store_string(raw)
    file.close()
    return true


## 重置为默认存档并持久化（= save.js resetSave）。
func reset_save() -> Dictionary:
    var save_data: Dictionary = default_save()
    persist_save(save_data)
    return save_data


# JS typeof 对齐：int/float 均为 number；其余按 Variant 类型严格比较。
func _same_json_type(base_val: Variant, data_val: Variant) -> bool:
    if typeof(base_val) == typeof(data_val):
        return true
    return typeof(base_val) in [TYPE_INT, TYPE_FLOAT] and typeof(data_val) in [TYPE_INT, TYPE_FLOAT]