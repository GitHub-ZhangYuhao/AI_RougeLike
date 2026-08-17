extends RefCounted
## ← js/rare-items.js

const RARE_ITEMS: Array[Dictionary] = [
    {"id": "warRune", "name": "战意符石", "description": "本局伤害提高 20%", "color": "#ffca28"},
    {"id": "bloodJade", "name": "血玉", "description": "最大生命 +25，并回复 25", "color": "#ef5350"},
    {"id": "magnetCore", "name": "聚灵核心", "description": "灵晶吸附范围 +80", "color": "#40c4ff"},
    {"id": "spiritBook", "name": "悟道残卷", "description": "本局经验获取提高 25%", "color": "#b388ff"},
    {"id": "windFeather", "name": "疾风羽", "description": "本局移动速度提高 10%", "color": "#69f0ae"},
]
const RARE_ITEM_BY_ID: Dictionary = {
    "warRune": RARE_ITEMS[0], "bloodJade": RARE_ITEMS[1], "magnetCore": RARE_ITEMS[2],
    "spiritBook": RARE_ITEMS[3], "windFeather": RARE_ITEMS[4],
}

static func roll_rare_item() -> Dictionary:
    return RARE_ITEMS[floori(Rng.next() * RARE_ITEMS.size())]

static func create_rare_pickup(x: float, y: float, item: Dictionary = {}) -> Dictionary:
    var selected: Dictionary = item if not item.is_empty() else roll_rare_item()
    # pulse consumes a separate RNG value exactly as the JS prototype does.
    return {"x": x, "y": y, "kind": "rare", "itemId": selected["id"], "pulse": Rng.next() * TAU, "dead": false}

static func apply_rare_item(game, pickup) -> Dictionary:
    var id: String = pickup["itemId"] if pickup is Dictionary else str(pickup)
    if not RARE_ITEM_BY_ID.has(id):
        return {}
    match id:
        "warRune": game.rareBonuses["damageMult"] *= 1.2
        "bloodJade": game.increase_max_hp(25.0, 25.0)
        "magnetCore": game.rareBonuses["magnetRadiusBonus"] += 80.0
        "spiritBook": game.rareBonuses["xpMult"] *= 1.25
        "windFeather": game.rareBonuses["moveSpeedMult"] *= 1.1
    game.rareInventory[id] = game.rareInventory.get(id, 0) + 1
    game.recompute_mods()
    return RARE_ITEM_BY_ID[id]
