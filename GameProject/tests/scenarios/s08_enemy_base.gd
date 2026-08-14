extends RefCounted
const Factory = preload("res://logic/enemies/enemy_factory.gd")
const Charger = preload("res://logic/enemies/charger.gd")
const Ranged = preload("res://logic/enemies/ranged.gd")
const Bomber = preload("res://logic/enemies/bomber.gd")
const Shield = preload("res://logic/enemies/shield.gd")
func title() -> String: return "[8] Enemy base and special mechanics"
func run(runner) -> void:
    Rng.set_source(func(): return 0.5)
    var early = Factory.create_enemy_by_type("chaser", 0, 0, 0, 1)
    var late = Factory.create_enemy_by_type("chaser", 0, 0, 0, 11)
    runner.check(is_equal_approx(early.maxHp, 50.0), "[8] wave 1 HP")
    runner.check(is_equal_approx(late.maxHp / early.maxHp, 3.3), "[8] wave 11 HP scaling")
    var player = early.duplicate() if false else Point.new(100.0, 0.0)
    var charger = Charger.new(0, 0); charger.update(player, 0.01)
    runner.check(charger.state == "windup", "[8] charger windup")
    charger.update(player, 0.66); var old_x: float = charger.x; charger.update(player, 0.1)
    runner.check(charger.state == "dash" and charger.x > old_x, "[8] charger locked dash")
    var shield = Shield.new(0, 0)
    runner.check(is_equal_approx(shield.modify_incoming_damage(10), 3.5), "[8] shield reduction")
    shield.update(player, 3.01)
    runner.check(shield.phase == "open" and is_equal_approx(shield.modify_incoming_damage(10), 12.5), "[8] shield open")
    var run = runner.harness.fresh_playing_game()
    var ranged = Ranged.new(0, 0); ranged.update(player, ranged.fireInterval + 0.01, run._world())
    runner.check(run.hostileProjectiles.size() == 1 and is_equal_approx(run.hostileProjectiles[0].vx, 175.0), "[8] ranged projectile")
    var bomber = Bomber.new(0, 0); bomber.update(Point.new(10, 0), 0.01, run._world()); bomber.update(Point.new(10, 0), 0.91, run._world())
    runner.check(bomber.dead and bomber.exploded and run.effects.size() == 1, "[8] bomber explodes once")
    Rng.clear_source()
class Point extends RefCounted:
    var x: float; var y: float
    func _init(px: float, py: float): x = px; y = py
