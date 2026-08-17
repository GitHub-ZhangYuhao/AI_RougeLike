extends RefCounted
## ← js/systems/synergies.js：15 组武器联动的激活、Build 选择与伤害入口。

const UtilsScript: GDScript = preload("res://logic/utils.gd")

static var DEFINITIONS: Array[Dictionary] = [
    {"id": "sword-talisman-mark", "weaponIds": ["sword", "talisman"], "name": "雷剑引雷", "icon": "⚔️⚡", "effectText": "道剑命中追加六成雷符伤害"},
    {"id": "sword-ring-return", "weaponIds": ["sword", "ring"], "name": "剑环折返", "icon": "⚔️💍", "effectText": "剑气触碰玉环后折返追击"},
    {"id": "sword-cloak-flame", "weaponIds": ["sword", "cloak"], "name": "焚刃", "icon": "⚔️🔥", "effectText": "剑击燃烧目标时斩出穿透火刃"},
    {"id": "sword-trail-cut", "weaponIds": ["sword", "trail"], "name": "切炉", "icon": "⚔️🔥", "effectText": "剑气切开丹炉并留下燃烧剑痕"},
    {"id": "sword-staff-command", "weaponIds": ["sword", "staff"], "name": "御剑号令", "icon": "⚔️🦴", "effectText": "道剑标记目标，魂仆优先追击"},
    {"id": "talisman-ring-relay", "weaponIds": ["talisman", "ring"], "name": "雷环中继", "icon": "⚡💍", "effectText": "闪电链可借玉环跨越断点"},
    {"id": "talisman-cloak-burst", "weaponIds": ["talisman", "cloak"], "name": "雷火震荡", "icon": "⚡🔥", "effectText": "落雷命中燃烧目标引发雷火爆炸"},
    {"id": "talisman-fire-alchemy", "weaponIds": ["talisman", "trail"], "name": "雷火炼化", "icon": "⚡🔥", "effectText": "落雷与闪电链为丹炉快速充能"},
    {"id": "talisman-staff-corpse-relay", "weaponIds": ["talisman", "staff"], "name": "尸雷跳板", "icon": "⚡🦴", "effectText": "闪电链可借魂仆跨越断点"},
    {"id": "ring-cloak-burning", "weaponIds": ["ring", "cloak"], "name": "灼热玉环", "icon": "💍🔥", "effectText": "披风范围内的玉环附加灼烧"},
    {"id": "ring-trail-charge", "weaponIds": ["ring", "trail"], "name": "蓄炉玉", "icon": "💍🔥", "effectText": "玉环穿过丹炉后释放范围爆发"},
    {"id": "ring-staff-guardian", "weaponIds": ["ring", "staff"], "name": "护法玉", "icon": "💍🦴", "effectText": "玉环守护魂仆并共享寒玉减速"},
    {"id": "cloak-trail-core", "weaponIds": ["cloak", "trail"], "name": "内外火域", "icon": "🔥🔥", "effectText": "披风与丹炉重叠时强化牵引伤害"},
    {"id": "cloak-staff-ghostfire", "weaponIds": ["cloak", "staff"], "name": "鬼火护卫", "icon": "🔥🦴", "effectText": "披风点燃魂仆并灼烧周围敌人"},
    {"id": "trail-staff-corpse-fire", "weaponIds": ["trail", "staff"], "name": "尸火炼丹", "icon": "🔥🦴", "effectText": "魂仆退场时化作丹炉燃料"},
]

var active_ids: Dictionary = {}
var runtime: Dictionary = {}
var announcement = null
var weapon_signature: String = ""
var cooldowns: Dictionary = {}
var selected_weapon_ids: Array[String] = []
var last_triggered_id: String = ""
var trigger_flash_ttl: float = 0.0
var last_activated_id: String = ""
var activation_flash_ttl: float = 0.0
var activation_serial: int = 0


func _init() -> void:
    for definition: Dictionary in DEFINITIONS:
        definition["pairKey"] = weapon_pair_key(definition["weaponIds"])
        definition["minLevel"] = 4
        definition["implemented"] = true


static func weapon_pair_key(ids: Array) -> String:
    var sorted: Array = ids.duplicate()
    sorted.sort()
    return "+".join(sorted)


func refresh(weapons: Array, elapsed: float = 0.0) -> bool:
    var levels: Dictionary = {}
    for weapon in weapons:
        levels[weapon.card["id"]] = weapon.level
    var selected: Array[String] = []
    for id: String in selected_weapon_ids:
        if levels.has(id) and not selected.has(id):
            selected.append(id)
    if selected.size() > 2:
        selected = selected.slice(selected.size() - 2)
    selected_weapon_ids = selected
    var selected_pair: String = weapon_pair_key(selected_weapon_ids) if selected_weapon_ids.size() == 2 else ""
    var ids: Array = levels.keys()
    ids.sort()
    var parts: Array[String] = []
    for id in ids:
        parts.append("%s:%s" % [id, levels[id]])
    var signature: String = "|".join(parts) + "#" + (selected_pair if not selected_pair.is_empty() else (selected_weapon_ids[0] if selected_weapon_ids.size() == 1 else ""))
    if signature == weapon_signature:
        return false
    weapon_signature = signature
    var candidates: Array[Dictionary] = []
    for definition: Dictionary in DEFINITIONS:
        var weapon_ids: Array = definition["weaponIds"]
        if not selected_pair.is_empty() and weapon_pair_key(weapon_ids) != selected_pair:
            continue
        if selected_weapon_ids.size() == 1 and not weapon_ids.has(selected_weapon_ids[0]):
            continue
        var first_level: int = levels.get(weapon_ids[0], 0)
        var second_level: int = levels.get(weapon_ids[1], 0)
        if first_level >= 4 and second_level >= 4:
            candidates.append({"definition": definition, "minLevel": mini(first_level, second_level), "levelSum": first_level + second_level})
    var chosen: Dictionary = {}
    for candidate: Dictionary in candidates:
        if chosen.is_empty() or candidate["minLevel"] > chosen["minLevel"] or (candidate["minLevel"] == chosen["minLevel"] and candidate["levelSum"] > chosen["levelSum"]):
            chosen = candidate
    var next: Dictionary = {}
    if not chosen.is_empty():
        next[chosen["definition"]["id"]] = true
    for id: String in next:
        if active_ids.has(id):
            continue
        runtime[id] = {"activatedAt": elapsed, "triggerCount": 0, "contribution": 0.0, "pulseCooldown": 0.0}
        var definition: Dictionary = definition_by_id(id)
        last_activated_id = id
        activation_flash_ttl = 1.8
        activation_serial += 1
        announcement = {"text": "联动成型 · %s" % definition["name"], "detail": definition["effectText"], "color": "#80fff0", "ttl": 3.6, "maxTtl": 3.6}
    for id: String in active_ids:
        if not next.has(id):
            runtime.erase(id)
    active_ids = next
    return true


func update(dt: float) -> void:
    trigger_flash_ttl = maxf(0.0, trigger_flash_ttl - dt)
    activation_flash_ttl = maxf(0.0, activation_flash_ttl - dt)
    for state: Dictionary in runtime.values():
        state["pulseCooldown"] = maxf(0.0, state.get("pulseCooldown", 0.0) - dt)
    if announcement != null:
        announcement["ttl"] -= dt
        if announcement["ttl"] <= 0.0:
            announcement = null


func toggle_build_weapon(id: String, weapons: Array, elapsed: float = 0.0) -> bool:
    if not weapons.any(func(weapon) -> bool: return weapon.card["id"] == id):
        return false
    var index: int = selected_weapon_ids.find(id)
    if index >= 0:
        selected_weapon_ids.remove_at(index)
    else:
        if selected_weapon_ids.size() >= 2:
            selected_weapon_ids.pop_back()
        selected_weapon_ids.append(id)
    weapon_signature = ""
    refresh(weapons, elapsed)
    var definition = selected_definition()
    var text: String = "流派选择"
    var detail: String = "已恢复自动联动" if selected_weapon_ids.is_empty() else "已选 %s" % _weapon_name(selected_weapon_ids[0], weapons)
    var color: String = "#ffd54f"
    if selected_weapon_ids.size() == 1:
        detail = "已选 %s，再选一把武器" % _weapon_name(selected_weapon_ids[0], weapons)
    elif definition != null:
        text = "流派 · %s" % definition["name"]
        if not is_active(definition["id"]):
            detail = "需要两把武器都达到 Lv4"
        else:
            detail = definition["effectText"]
            color = "#80deea"
    announcement = {"text": text, "detail": detail, "color": color, "ttl": 2.5, "maxTtl": 2.5}
    return true


func selected_definition():
    if selected_weapon_ids.size() != 2:
        return null
    var key: String = weapon_pair_key(selected_weapon_ids)
    for definition: Dictionary in DEFINITIONS:
        if weapon_pair_key(definition["weaponIds"]) == key:
            return definition
    return null


func active_definitions() -> Array:
    return DEFINITIONS.filter(func(definition: Dictionary) -> bool: return active_ids.has(definition["id"]))


func primary_definition():
    var active: Array = active_definitions()
    return active[0] if not active.is_empty() else null


func activation_mode() -> String:
    return "locked" if selected_weapon_ids.size() == 2 else "auto"


func is_active(id: String) -> bool:
    return active_ids.has(id)


func get_runtime(id: String):
    return runtime.get(id)


func record_trigger(id: String, contribution: float = 0.0) -> bool:
    var state = runtime.get(id)
    if state == null:
        return false
    state["triggerCount"] += 1
    state["contribution"] += contribution
    last_triggered_id = id
    trigger_flash_ttl = 0.35
    if state.get("pulseCooldown", 0.0) > 0.0:
        return false
    state["pulseCooldown"] = 0.24
    return true


func on_damage(event: Dictionary, world: Dictionary) -> void:
    var options: Dictionary = event["options"]
    if options.get("noSynergy", false) or options.get("sourceWeaponId") != "talisman" or not options.get("sourceTags", []).has("lightning"):
        return
    _trigger_lightning_fire_burst(event, world)
    _charge_lightning_furnace(event, world)


func _trigger_lightning_fire_burst(event: Dictionary, world: Dictionary) -> void:
    if not is_active("talisman-cloak-burst") or event["options"].get("sourceAction") != "thunder":
        return
    var target = event["target"]
    if target.dots.get("burn", {}).get("timer", 0.0) <= 0.0:
        return
    if world["elapsed"] < target.synergyCooldowns.get("talismanCloakBurst", -INF):
        return
    target.synergyCooldowns["talismanCloakBurst"] = world["elapsed"] + 0.9
    var damage: float = event["damage"] * 0.45
    var hits: int = 0
    for enemy in world["enemies"]:
        if not enemy.dead and UtilsScript.dist2(enemy.x, enemy.y, target.x, target.y) <= pow(80.0 + enemy.radius, 2):
            world["damage_enemy"].call(enemy, damage, {"sourceWeaponId": "talisman", "sourceAction": "lightning-fire-burst", "sourceTags": ["lightning", "fire", "area"], "synergyId": "talisman-cloak-burst", "noSynergy": true, "noSummon": true})
            hits += 1
    record_trigger("talisman-cloak-burst", damage * hits)
    world["effects"].append({"type": "synergyBurst", "style": "lightningFire", "x": target.x, "y": target.y, "radius": 80.0, "color": "#ff8a50", "accent": "#fff176", "ttl": 0.32, "maxTtl": 0.32})


func _charge_lightning_furnace(event: Dictionary, world: Dictionary) -> void:
    if not is_active("talisman-fire-alchemy") or not ["thunder", "chain"].has(event["options"].get("sourceAction")):
        return
    if world["elapsed"] < cooldowns.get("talisman-fire-alchemy", -INF):
        return
    var trail = world["get_weapon"].call("trail")
    if trail == null:
        return
    var amount: float = 2.0 if event["options"]["sourceAction"] == "thunder" else 0.75
    var target = event["target"]
    var zone = trail.charge_furnace_at(target.x, target.y, amount, world)
    if zone == null:
        return
    cooldowns["talisman-fire-alchemy"] = world["elapsed"] + 0.18
    record_trigger("talisman-fire-alchemy", amount)
    world["effects"].append({"type": "synergyArc", "x1": target.x, "y1": target.y, "x2": zone["center"]["x"], "y2": zone["center"]["y"], "color": "#80deea", "ttl": 0.22, "maxTtl": 0.22})
    world["effects"].append({"type": "synergyBurst", "style": "alchemy", "x": zone["center"]["x"], "y": zone["center"]["y"], "radius": 34.0, "color": "#ff8a50", "accent": "#80deea", "ttl": 0.26, "maxTtl": 0.26})


static func definition_by_id(id: String) -> Dictionary:
    for definition: Dictionary in DEFINITIONS:
        if definition["id"] == id:
            return definition
    return {}


static func _weapon_name(id: String, weapons: Array) -> String:
    for weapon in weapons:
        if weapon.card["id"] == id:
            return weapon.card["name"]
    return id
