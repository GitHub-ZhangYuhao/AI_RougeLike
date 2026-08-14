extends RefCounted

const CardsScript: GDScript = preload("res://logic/cards.gd")

class FakeGame extends RefCounted:
    var weapons: Array = []
    var attrStacks: Dictionary = {}

func title() -> String:
    return "[7] generateOffers 卡池规则"

func run(runner) -> void:
    Rng.set_seed(7007)
    var game := FakeGame.new()
    for i in 3:
        var fake_weapon := FakeWeapon.new()
        fake_weapon.card = CardsScript.WEAPON_CARDS[i]
        fake_weapon.level = 1
        game.weapons.append(fake_weapon)
    var offers: Array[Dictionary] = CardsScript.generate_offers(game)
    runner.check(not offers.is_empty(), "[7] 满武器槽仍应有升级/属性卡")
    for offer: Dictionary in offers:
        runner.check(offer["type"] != "new", "[7] 满武器槽不应出现新武器")
    game.weapons = []
    for card: Dictionary in CardsScript.WEAPON_CARDS:
        var weapon := FakeWeapon.new()
        weapon.card = card
        weapon.level = 6
        game.weapons.append(weapon)
    for card: Dictionary in CardsScript.ATTR_CARDS:
        game.attrStacks[card["id"]] = 5
    runner.check(CardsScript.generate_offers(game).is_empty(), "[7] 全部满级后卡池应为空")
    Rng.clear_source()

class FakeWeapon extends RefCounted:
    var card: Dictionary
    var level: int
