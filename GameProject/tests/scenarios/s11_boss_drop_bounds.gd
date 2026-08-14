extends RefCounted
const Drops = preload("res://logic/meta/drops.gd")
func title() -> String: return "[11] Boss drop bounds"
func run(runner) -> void:
    runner.check(is_equal_approx(Drops.drop_chance_for(1), 0.08) and is_equal_approx(Drops.drop_chance_for(5), 0.20), "[11] drop chance cap")
    runner.check(Drops.min_tier_for(3) == 2 and Drops.min_tier_for(5) == 3, "[11] guaranteed tiers")
    runner.check(Drops.roll_boss_drops(9, func(): return 0.99).is_empty(), "[11] failure boundary")
    runner.check(Drops.roll_boss_drops(1, func(): return 0.0) == ["shard"], "[11] tier one drop")
    runner.check(Drops.roll_boss_drops(5, func(): return 0.0) == ["soulCrystal", "soulCrystal"], "[11] tier five guarantee")
