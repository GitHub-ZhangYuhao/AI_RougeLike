extends RefCounted

const Factory: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const Synergies: GDScript = preload("res://logic/systems/synergies.gd")
const Enemy: GDScript = preload("res://logic/enemy.gd")

func title() -> String:
    return "[18] Weapon synergy infrastructure / fifteen Builds"

func _weapon(id: String, level: int = 4):
    var weapon = Factory.create_weapon(id)
    weapon.level = level
    return weapon

func _enemy(x: float, y: float):
    var enemy = Enemy.create_chaser(x, y, 0.0, {"speedVariance": false})
    enemy.hp = 10000.0
    enemy.maxHp = 10000.0
    enemy.speed = 0.0
    return enemy

func _zone(damage: float = 10.0) -> Dictionary:
    return {"points": [{"x": -120.0, "y": -120.0}, {"x": 120.0, "y": -120.0}, {"x": 120.0, "y": 120.0}, {"x": -120.0, "y": 120.0}], "center": {"x": 0.0, "y": 0.0}, "area": 57600.0, "life": 5.0, "maxLife": 5.0, "tickTimer": 999.0, "coreTickTimer": 0.0, "damage": damage, "pullSpeed": 25.0, "fuel": 0.0, "opens": 0, "maxOpens": 1, "openCooldown": 0.0, "eliteFuelAt": {}, "dead": false}

func run(runner) -> void:
    var game = runner.harness.fresh_playing_game()
    runner.check(Synergies.DEFINITIONS.size() == 15, "[18] should register all 15 weapon-pair definitions")
    runner.check(Synergies.DEFINITIONS.all(func(entry: Dictionary) -> bool: return entry["implemented"]), "[18] all fifteen registered weapon Builds should be implemented")
    game.weapons = [_weapon("sword", 4), _weapon("staff", 3)]
    game.synergies = Synergies.new()
    game.synergies.refresh(game.weapons, game.elapsed)
    runner.check(not game.synergies.is_active("sword-staff-command"), "[18] synergy must stay inactive below level 4")
    game._apply_offer({"card": Factory.card_by_id("staff"), "type": "upgrade"})
    runner.check(game.synergies.is_active("sword-staff-command"), "[18] normal upgrade should auto-activate synergy")
    var ttl: float = game.synergies.announcement["ttl"]
    game.synergies.update(0.1)
    runner.check(game.synergies.announcement["ttl"] < ttl, "[18] game should advance synergy announcements")

    var talisman = _weapon("talisman")
    var trail = _weapon("trail")
    game.weapons = [talisman, trail]
    game.synergies = Synergies.new()
    game.synergies.refresh(game.weapons, game.elapsed)
    var furnace: Dictionary = _zone()
    trail.furnaces = [furnace]
    var target = _enemy(10.0, 0.0)
    game.enemies = [target]
    game.damage_enemy(target, 1.0, {"sourceWeaponId": "talisman", "sourceAction": "thunder", "sourceTags": ["lightning", "thunder"]})
    runner.check(furnace["fuel"] == 2.0, "[18] thunder should add two furnace fuel")
    runner.check(game.effects.any(func(fx: Dictionary) -> bool: return fx["type"] == "synergyArc"), "[18] lightning alchemy should emit arc feedback")

    var cloak = _weapon("cloak")
    trail = _weapon("trail")
    game.weapons = [cloak, trail]
    game.synergies = Synergies.new()
    game.synergies.refresh(game.weapons, game.elapsed)
    furnace = _zone()
    trail.furnaces = [furnace]
    target = _enemy(80.0, 0.0)
    game.enemies = [target]
    var hp: float = target.hp
    trail.update(0.1, game._world())
    runner.check(target.hp == hp - 15.0, "[18] inner/outer fire domain controlled burst")
    runner.check(target.x < 77.5, "[18] inner/outer fire domain strengthens pull")
    runner.check(game.synergies.get_runtime("cloak-trail-core")["triggerCount"] == 1, "[18] inner/outer fire records trigger")

    game.release_runtime_refs()
    game.weapons = [_weapon("talisman"), _weapon("trail"), _weapon("ring")]
    game.synergies = Synergies.new()
    game.synergies.refresh(game.weapons, game.elapsed)
    runner.check(game.synergies.is_active("talisman-fire-alchemy") and game.synergies.is_active("talisman-ring-relay"), "[18] automatic mode activates eligible Builds")
    game.synergies.toggle_build_weapon("talisman", game.weapons, game.elapsed)
    game.synergies.toggle_build_weapon("trail", game.weapons, game.elapsed)
    runner.check(game.synergies.selected_definition()["id"] == "talisman-fire-alchemy", "[18] manual Build resolves pair")
    runner.check(game.synergies.active_definitions().size() == 1, "[18] locked Build filters active set")
    game.synergies.toggle_build_weapon("ring", game.weapons, game.elapsed)
    runner.check(game.synergies.selected_weapon_ids == ["talisman", "ring"], "[18] third click keeps anchor and replaces partner")
    game.weapons[1].level = 3
    game.synergies.toggle_build_weapon("talisman", game.weapons, game.elapsed)
    game.synergies.toggle_build_weapon("trail", game.weapons, game.elapsed)
    runner.check(game.synergies.active_definitions().is_empty(), "[18] below-level locked Build must not fall back")
