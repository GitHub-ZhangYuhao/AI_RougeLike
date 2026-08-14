extends RefCounted
## ← js/cards.js：武器/属性卡池与属性合成。

const SwordScript: GDScript = preload("res://logic/weapons/sword.gd")
const CloakScript: GDScript = preload("res://logic/weapons/cloak.gd")
const TalismanScript: GDScript = preload("res://logic/weapons/talisman.gd")
const TrailScript: GDScript = preload("res://logic/weapons/trail.gd")
const RingScript: GDScript = preload("res://logic/weapons/ring.gd")
const StaffScript: GDScript = preload("res://logic/weapons/staff.gd")

const WEAPON_CARDS: Array[Dictionary] = [SwordScript.CARD, CloakScript.CARD, TalismanScript.CARD, TrailScript.CARD, RingScript.CARD, StaffScript.CARD]
const ATTR_CARDS: Array[Dictionary] = [
    {"id": "damage", "kind": "attr", "name": "伤害提升"},
    {"id": "armor", "kind": "attr", "name": "护甲提升"},
    {"id": "magnet", "kind": "attr", "name": "拾取范围"},
    {"id": "xp", "kind": "attr", "name": "经验倍率"},
    {"id": "maxHp", "kind": "attr", "name": "血量提升"},
    {"id": "moveSpeed", "kind": "attr", "name": "移动速度"},
]


static func card_by_id(id: String) -> Dictionary:
    for card: Dictionary in WEAPON_CARDS + ATTR_CARDS:
        if card["id"] == id:
            return card
    return {}


static func compute_mods(attr_stacks: Dictionary, meta_stacks: Dictionary = {}) -> Dictionary:
    var mods: Dictionary = {"damageMult": 1.0, "xpMult": 1.0, "moveSpeedMult": 1.0,
        "armor": 0.0, "damageReduction": 0.0, "magnetRadiusBonus": 0.0,
        "maxHpBonus": 0.0, "projectileBonus": 0, "areaMult": 1.0,
        "attackSpeedMult": 1.0, "cooldownMult": 1.0}
    for card: Dictionary in ATTR_CARDS:
        var id: String = card["id"]
        var n: int = attr_stacks.get(id, 0) + meta_stacks.get(id, 0)
        if n <= 0:
            continue
        match id:
            "damage": mods["damageMult"] += 0.15 * n
            "armor": mods["armor"] += 15.0 * n
            "magnet": mods["magnetRadiusBonus"] += 50.0 * n
            "xp": mods["xpMult"] += 0.15 * n
            "maxHp": mods["maxHpBonus"] += 20.0 * n
            "moveSpeed": mods["moveSpeedMult"] += 0.06 * n
    mods["damageReduction"] = minf(0.5, mods["armor"] / (mods["armor"] + 100.0))
    return mods


static func opening_offers(_game = null) -> Array[Dictionary]:
    var offers: Array[Dictionary] = []
    for card: Dictionary in WEAPON_CARDS:
        offers.append({"card": card, "type": "new"})
    return offers


static func generate_offers(game) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for weapon in game.weapons:
        if weapon.level < weapon.card["maxLevel"]:
            pool.append({"card": weapon.card, "type": "upgrade"})
    if game.weapons.size() < Config.CONFIG["cards"]["maxWeaponSlots"]:
        for card: Dictionary in WEAPON_CARDS:
            var owned: bool = false
            for weapon in game.weapons:
                if weapon.card["id"] == card["id"]:
                    owned = true
                    break
            if not owned:
                pool.append({"card": card, "type": "new"})
    for card: Dictionary in ATTR_CARDS:
        if game.attrStacks.get(card["id"], 0) < Config.CONFIG["cards"]["attrMaxStack"]:
            pool.append({"card": card, "type": "attr"})
    for i in range(pool.size() - 1, 0, -1):
        var j: int = floori(Rng.next() * (i + 1))
        var swap: Dictionary = pool[i]
        pool[i] = pool[j]
        pool[j] = swap
    return pool.slice(0, Config.CONFIG["cards"]["choicesCount"])
