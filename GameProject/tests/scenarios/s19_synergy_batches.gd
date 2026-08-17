extends RefCounted

const Factory: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const Synergies: GDScript = preload("res://logic/systems/synergies.gd")
const Enemy: GDScript = preload("res://logic/enemy.gd")
const Status: GDScript = preload("res://logic/systems/status.gd")

func title() -> String:
    return "[19] First and second weapon Build batches"

func _weapon(id: String):
    var weapon = Factory.create_weapon(id); weapon.level = 4; return weapon
func _enemy(x: float, y: float):
    var enemy = Enemy.create_chaser(x, y, 0.0, {"speedVariance": false}); enemy.hp = 10000.0; enemy.maxHp = 10000.0; enemy.speed = 0.0; return enemy
func _setup(runner, first: String, second: String) -> Array:
    var game = runner.harness.fresh_playing_game(); game.weapons = [_weapon(first), _weapon(second)]; game.synergies = Synergies.new(); game.synergies.refresh(game.weapons, game.elapsed); game.enemies = []; game.summons.clear(); game.effects = []; return [game, game.weapons[0], game.weapons[1]]
func _zone() -> Dictionary:
    return {"points": [{"x": -120.0, "y": -120.0}, {"x": 120.0, "y": -120.0}, {"x": 120.0, "y": 120.0}, {"x": -120.0, "y": 120.0}], "center": {"x": 0.0, "y": 0.0}, "life": 5.0, "maxLife": 5.0, "tickTimer": 999.0, "coreTickTimer": 999.0, "damage": 10.0, "pullSpeed": 25.0, "fuel": 0.0, "opens": 0, "maxOpens": 1, "openCooldown": 0.0, "eliteFuelAt": {}, "dead": false}

func run(runner) -> void:
    runner.check(Synergies.DEFINITIONS.filter(func(entry: Dictionary) -> bool: return not entry["implemented"]).is_empty(), "[19] no registered Builds remain unimplemented")
    var setup: Array = _setup(runner, "sword", "talisman"); var game = setup[0]; var sword = setup[1]; var talisman = setup[2]
    var target = _enemy(100.0, 0.0); game.enemies = [target]
    for action: String in ["melee", "projectile", "ring", "flyingSword"]: sword._on_damage_hit(target, game._world(), sword.stats, false, action)
    runner.check(talisman.bolt_fx.filter(func(fx: Dictionary) -> bool: return fx.get("swordSynergy", false)).size() == 4, "[19] every sword attack emits sword thunder")
    runner.check(game.synergies.get_runtime("sword-talisman-mark")["triggerCount"] == 4, "[19] sword thunder records each trigger")

    setup = _setup(runner, "ring", "cloak"); game = setup[0]; var ring = setup[1]
    var position: Dictionary = ring.ring_positions(game._world())[0]; target = _enemy(position["x"], position["y"]); game.enemies = [target]; ring.update(0.0, game._world())
    runner.check(target.dots.get("burn", {}).get("timer", 0.0) > 0.0, "[19] burning ring applies burn")
    game.weapons = [ring]; game.synergies.refresh(game.weapons, game.elapsed); ring.update(0.0, game._world())
    runner.check(ring.burning_rings.all(func(active: bool) -> bool: return not active), "[19] burning ring state clears on deactivation")

    setup = _setup(runner, "cloak", "staff"); game = setup[0]; var staff = setup[2]; target = _enemy(35.0, 0.0); game.enemies = [target]
    var first: Dictionary = {"x": 0.0, "y": 0.0, "damage": 100.0, "life": 5.0, "speed": 0.0, "hitTimer": 10.0, "wander": 0.0, "dead": false}; var second: Dictionary = first.duplicate(true); second["y"] = 8.0
    staff.slots = [{"phase": "active", "timer": 5.0, "summon": first}, {"phase": "active", "timer": 5.0, "summon": second}]; game.summons.clear(); game.summons.append_array([first, second]); var hp: float = target.hp; staff.update(0.0, game._world())
    runner.check(target.hp == hp - 35.0, "[19] overlapping ghostfire shares target cooldown")
    runner.check(first["ghostfireActive"] and second["ghostfireActive"], "[19] summons inside cloak gain ghostfire")

    setup = _setup(runner, "sword", "cloak"); game = setup[0]; sword = setup[1]; var burned = _enemy(40.0, 0.0); var forward = _enemy(120.0, 0.0); var side = _enemy(40.0, 90.0); game.enemies = [burned, forward, side]; Status.apply_dot(burned, "burn", 12.0, 2.0); hp = forward.hp; var side_hp: float = side.hp; sword._on_damage_hit(burned, game._world(), sword.stats, false, "melee")
    runner.check(forward.hp < hp and side.hp == side_hp, "[19] flame blade follows attack direction")
    runner.check(game.effects.any(func(fx: Dictionary) -> bool: return fx["type"] == "synergyFlameBlade"), "[19] flame blade emits effect")

    setup = _setup(runner, "ring", "trail"); game = setup[0]; ring = setup[1]; var trail = setup[2]; trail.furnaces = [_zone()]; ring.update(0.0, game._world()); runner.check(ring.ring_charge.any(func(state: Dictionary) -> bool: return state["charged"]), "[19] jade ring stores furnace charge"); trail.furnaces = []; ring.update(0.0, game._world()); position = ring.ring_positions(game._world())[0]; target = _enemy(position["x"], position["y"]); game.enemies = [target]; hp = target.hp; ring.update(0.0, game._world()); runner.check(target.hp < hp and not ring.ring_charge[0]["charged"], "[19] charged ring releases and consumes charge")

    setup = _setup(runner, "trail", "staff"); game = setup[0]; trail = setup[1]; staff = setup[2]; var furnace: Dictionary = _zone(); trail.furnaces = [furnace]; var summon: Dictionary = {"x": 0.0, "y": 0.0, "damage": 10.0, "life": 10.0, "speed": 0.0, "hitTimer": 10.0, "wander": 0.0, "dead": false}; staff.slots = [{"phase": "active", "timer": 0.01, "summon": summon}]; game.summons.clear(); game.summons.append(summon); staff.update(0.02, game._world()); runner.check(furnace["fuel"] == 1.5 and summon["corpseFireConverted"], "[19] summon retirement adds corpse-fire fuel once"); staff.update(0.02, game._world()); runner.check(furnace["fuel"] == 1.5, "[19] corpse-fire conversion is idempotent")

    setup = _setup(runner, "talisman", "staff"); game = setup[0]; talisman = setup[1]; var origin = _enemy(0.0, 0.0); target = _enemy(320.0, 0.0); summon = {"x": 160.0, "y": 0.0, "life": 5.0, "dead": false}; game.enemies = [origin, target]; game.summons.clear(); game.summons.append(summon); hp = target.hp; talisman._chain_lightning(origin, 25.0, game._world()); runner.check(target.hp == hp - 25.0, "[19] corpse relay connects distant target"); runner.check(talisman.chain_fx.any(func(fx: Dictionary) -> bool: return fx.get("corpseRelay", false)), "[19] corpse relay emits distinct feedback")
