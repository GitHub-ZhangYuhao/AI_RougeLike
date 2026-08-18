extends RefCounted

const CardsScript: GDScript = preload("res://logic/cards.gd")
const ArtCatalogScript: GDScript = preload("res://scenes/art_catalog.gd")

func title() -> String:
	return "[0] Weapon card structure"

func run(runner) -> void:
	runner.check(ArtCatalogScript.ENEMY_TEXTURES.size() == 7, "[0] all enemy production textures registered")
	runner.check(ArtCatalogScript.WEAPON_ICONS.size() == 6, "[0] all weapon production icons registered")
	runner.check(ArtCatalogScript.VFX_TEXTURES.size() == 22, "[0] all production VFX textures registered")
	runner.check(ArtCatalogScript.UI_TEXTURES.size() == 13, "[0] all production UI ornaments registered")
	for card: Dictionary in CardsScript.WEAPON_CARDS:
		runner.check(card["maxLevel"] == 6, "[0] %s maxLevel must be 6" % card["id"])
		runner.check(card["levels"].size() == 6, "[0] %s must have 6 levels" % card["id"])
		for level: Dictionary in card["levels"]:
			runner.check(level.get("damage", 0) > 0, "[0] %s level damage missing" % card["id"])
