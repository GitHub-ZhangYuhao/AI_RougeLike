extends RefCounted
## ← js/meta/items.js

const META_ITEMS: Dictionary = {
    "shard": {"id": "shard", "name": "碎片", "icon": "🔹", "tier": 1, "sellPrice": 5},
    "essence": {"id": "essence", "name": "辉光精华", "icon": "✨", "tier": 2, "sellPrice": 20},
    "soulCrystal": {"id": "soulCrystal", "name": "灵魂结晶", "icon": "💎", "tier": 3, "sellPrice": 80},
}
const META_ITEM_LIST: Array = [META_ITEMS["shard"], META_ITEMS["essence"], META_ITEMS["soulCrystal"]]
const ITEM_BY_TIER: Dictionary = {1: META_ITEMS["shard"], 2: META_ITEMS["essence"], 3: META_ITEMS["soulCrystal"]}
