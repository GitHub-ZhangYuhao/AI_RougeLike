extends RefCounted

const CardsScript: GDScript = preload("res://logic/cards.gd")

func title() -> String:
	return "[0] Weapon card structure"

func run(runner) -> void:
	for card: Dictionary in CardsScript.WEAPON_CARDS:
		runner.check(card["maxLevel"] == 6, "[0] %s maxLevel must be 6" % card["id"])
		runner.check(card["levels"].size() == 6, "[0] %s must have 6 levels" % card["id"])
		for level: Dictionary in card["levels"]:
			runner.check(level.get("damage", 0) > 0, "[0] %s level damage missing" % card["id"])
