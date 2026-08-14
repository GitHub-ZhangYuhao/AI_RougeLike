extends RefCounted
## ← js/meta/drops.js. RNG consumption order is part of the public behavior.

const ItemsScript: GDScript = preload("res://logic/meta/items.gd")

static func drop_chance_for(boss_tier: int) -> float:
    var config: Dictionary = Config.CONFIG["meta"]["dropChance"]
    return minf(config["base"] + config["perTier"] * (maxi(1, boss_tier) - 1), config["cap"])

static func min_tier_for(boss_tier: int) -> int:
    var result: int = 1
    var best_key: int = -2147483648
    for key: String in Config.CONFIG["meta"]["guaranteedMinTier"]:
        var value: int = int(key)
        if value <= boss_tier and value > best_key:
            best_key = value
            result = Config.CONFIG["meta"]["guaranteedMinTier"][key]
    return result

static func roll_boss_drops(boss_tier: int, rng: Callable = Callable()) -> Array[String]:
    var random: Callable = rng if rng.is_valid() else Callable(Rng, "next")
    if random.call() >= drop_chance_for(boss_tier):
        return []
    var tier_key: int = clampi(boss_tier, 1, 5)
    var count_range: Array = Config.CONFIG["meta"]["dropCount"][str(tier_key)]
    var count: int = count_range[0] + floori(random.call() * (count_range[1] - count_range[0] + 1))
    var weights: Array = Config.CONFIG["meta"]["tierWeights"][str(tier_key)]
    var drops: Array[String] = []
    for _i in count:
        var tier: int = maxi(_roll_weighted_tier(weights, random), min_tier_for(boss_tier))
        drops.append(ItemsScript.ITEM_BY_TIER[tier]["id"])
    return drops

static func _roll_weighted_tier(weights: Array, rng: Callable) -> int:
    var total: float = 0.0
    for weight in weights:
        total += weight
    var roll: float = rng.call() * total
    for i in weights.size():
        roll -= weights[i]
        if roll < 0.0:
            return i + 1
    return weights.size()
