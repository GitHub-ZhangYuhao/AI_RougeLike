extends RefCounted
## ← js/weapons/index.js：六武器卡表与实例工厂。

const SwordScript: GDScript = preload("res://logic/weapons/sword.gd")
const CloakScript: GDScript = preload("res://logic/weapons/cloak.gd")
const TalismanScript: GDScript = preload("res://logic/weapons/talisman.gd")
const TrailScript: GDScript = preload("res://logic/weapons/trail.gd")
const RingScript: GDScript = preload("res://logic/weapons/ring.gd")
const StaffScript: GDScript = preload("res://logic/weapons/staff.gd")

const WEAPON_CARDS: Array[Dictionary] = [
    SwordScript.CARD, CloakScript.CARD, TalismanScript.CARD,
    TrailScript.CARD, RingScript.CARD, StaffScript.CARD,
]


static func card_by_id(id: String) -> Dictionary:
    for card: Dictionary in WEAPON_CARDS:
        if card["id"] == id:
            return card
    return {}


static func create_weapon(id: String):
    var card: Dictionary = card_by_id(id)
    return create_weapon_by_type(id, card) if not card.is_empty() else null


# 保留 M1 的注入式接口，供 game_run/cards 继续使用。
static func create_weapon_by_type(id: String, card: Dictionary):
    match id:
        "sword": return SwordScript.new(card)
        "cloak": return CloakScript.new(card)
        "talisman": return TalismanScript.new(card)
        "trail": return TrailScript.new(card)
        "ring": return RingScript.new(card)
        "staff": return StaffScript.new(card)
    return null
