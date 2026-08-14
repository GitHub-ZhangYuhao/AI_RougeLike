extends RefCounted

const Factory: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const Synergies: GDScript = preload("res://logic/systems/synergies.gd")
const Enemy: GDScript = preload("res://logic/enemy.gd")

func title() -> String: return "[20] Third weapon Build batch"
func _weapon(id: String):
    var weapon = Factory.create_weapon(id); weapon.level = 4; return weapon
func _enemy(x: float, y: float):
    var enemy = Enemy.create_chaser(x, y, 0.0, {"speedVariance": false}); enemy.hp = 10000.0; enemy.maxHp = 10000.0; enemy.speed = 0.0; return enemy
func _setup(runner, first: String, second: String) -> Array:
    var game = runner.harness.fresh_playing_game(); game.weapons = [_weapon(first), _weapon(second)]; game.synergies = Synergies.new(); game.synergies.refresh(game.weapons, game.elapsed); game.enemies = []; game.summons.clear(); game.effects = []; return [game, game.weapons[0], game.weapons[1]]
func _zone() -> Dictionary:
    return {"points": [{"x": -120.0, "y": -120.0}, {"x": 120.0, "y": -120.0}, {"x": 120.0, "y": 120.0}, {"x": -120.0, "y": 120.0}], "center": {"x": 0.0, "y": 0.0}, "life": 5.0, "maxLife": 5.0, "tickTimer": 999.0, "coreTickTimer": 999.0, "damage": 10.0, "pullSpeed": 25.0, "fuel": 0.0, "opens": 0, "maxOpens": 1, "openCooldown": 0.0, "eliteFuelAt": {}, "dead": false}

func run(runner) -> void:
    var setup: Array = _setup(runner, "sword", "ring"); var game = setup[0]; var sword = setup[1]; var ring = setup[2]; var world: Dictionary = game._world(); var position: Dictionary = ring.ring_positions(world)[0]
    sword._fire_main_sword(world, sword.stats, 0.0, sword.stats["damage"]); var projectile = game.projectiles.back(); projectile.synergyPrevX = position["x"] - 90.0; projectile.synergyPrevY = position["y"]; projectile.x = position["x"] + 90.0; projectile.y = position["y"]; sword._update_projectile_synergies(world, sword.stats)
    runner.check(projectile.ringReturnCharged, "[20] sword qi crossing jade ring gains return charge")
    var hit = _enemy(projectile.x, projectile.y); var redirect = _enemy(projectile.x - 120.0, projectile.y); game.enemies = [hit, redirect]; projectile.onHit.call(hit)
    runner.check(projectile.ringReturnUsed and projectile.vx < 0.0, "[20] charged sword qi redirects after hit")
    runner.check(projectile.hitSet.has(hit.get_instance_id()) and game.synergies.get_runtime("sword-ring-return")["triggerCount"] == 1, "[20] sword return records exactly one trigger")
    projectile.ringReturnCharged = true; game.weapons = [sword]; game.synergies.refresh(game.weapons, game.elapsed); sword._update_projectile_synergies(game._world(), sword.stats); runner.check(not projectile.ringReturnCharged, "[20] return charge clears on deactivation")

    setup = _setup(runner, "sword", "trail"); game = setup[0]; sword = setup[1]; var trail = setup[2]; trail.furnaces = [_zone()]; world = game._world(); sword._fire_main_sword(world, sword.stats, 0.0, sword.stats["damage"]); projectile = game.projectiles.back(); projectile.synergyPrevX = -180.0; projectile.synergyPrevY = 0.0; projectile.x = 180.0; projectile.y = 0.0; sword._update_projectile_synergies(world, sword.stats)
    runner.check(trail.cut_zones.size() == 1, "[20] sword qi cuts each furnace once"); sword._update_projectile_synergies(world, sword.stats); runner.check(trail.cut_zones.size() == 1, "[20] same sword qi cannot cut furnace twice")
    var target = _enemy(0.0, 0.0); game.enemies = [target]; var hp: float = target.hp; trail._update_cut_zones(0.0, game._world()); runner.check(target.hp < hp, "[20] combustion lane damages enemies"); runner.check(game.synergies.get_runtime("sword-trail-cut")["triggerCount"] == 1, "[20] furnace cut records once"); game.weapons = [trail]; game.synergies.refresh(game.weapons, game.elapsed); trail._update_cut_zones(0.0, game._world()); runner.check(trail.cut_zones.is_empty(), "[20] combustion lanes clear on deactivation")

    setup = _setup(runner, "ring", "staff"); game = setup[0]; var staff = setup[2]; target = _enemy(0.0, 0.0); game.enemies = [target]; var first: Dictionary = {"x": 0.0, "y": 0.0, "damage": 10.0, "life": 5.0, "speed": 0.0, "hitTimer": 0.0, "wander": 0.0, "dead": false}; var second: Dictionary = first.duplicate(true); second["hitTimer"] = 10.0; var third: Dictionary = second.duplicate(true); third["corpse"] = true; staff.slots = [{"phase": "active", "timer": 5.0, "summon": first}, {"phase": "active", "timer": 5.0, "summon": second}]; staff.corpses = [third]; game.summons.clear(); game.summons.append_array([first, second, third]); staff.update(0.0, game._world())
    runner.check(staff.get_guardian_wards().size() == 2 and game.summons.filter(func(summon: Dictionary) -> bool: return summon.get("guardianWardActive", false)).size() == 2, "[20] guardian jade protects at most two summons")
    runner.check(target.slowFactor == 0.35 and target.slowTimer == 1.6, "[20] guarded summon shares jade slow")
    runner.check(game.synergies.get_runtime("ring-staff-guardian")["triggerCount"] == 1, "[20] guardian slow records trigger")
    game.weapons = [staff]; game.synergies.refresh(game.weapons, game.elapsed); staff.update(0.0, game._world()); runner.check(staff.get_guardian_wards().is_empty() and game.summons.all(func(summon: Dictionary) -> bool: return not summon.get("guardianWardActive", false)), "[20] guardian state clears on deactivation")
