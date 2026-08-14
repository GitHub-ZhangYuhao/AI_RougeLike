extends RefCounted
## ← js/meta/shop.js：局外属性商城纯逻辑。

const SHOP_ATTRS: Array[String] = ["damage", "armor", "magnet", "xp", "maxHp", "moveSpeed"]


static func shop_max_level() -> int:
    return Config.CONFIG["meta"]["shopMaxLevel"]


static func price_for_level(level: int) -> int:
    if level < 1:
        return 0
    var price: Dictionary = Config.CONFIG["meta"]["shopPrice"]
    return roundi(price["base"] * pow(price["growth"], level - 1))


static func can_buy(save: Dictionary, attr_id: String) -> bool:
    if not SHOP_ATTRS.has(attr_id) or not save.has("metaLevels"):
        return false
    var current: int = save["metaLevels"].get(attr_id, shop_max_level())
    return current < shop_max_level() and save.get("darkCrystals", 0) >= price_for_level(current + 1)


static func try_buy(save: Dictionary, attr_id: String) -> bool:
    if not can_buy(save, attr_id):
        return false
    var next_level: int = save["metaLevels"][attr_id] + 1
    save["darkCrystals"] -= price_for_level(next_level)
    save["metaLevels"][attr_id] = next_level
    return true
