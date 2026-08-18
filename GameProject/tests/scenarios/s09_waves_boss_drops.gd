extends RefCounted
const Waves = preload("res://logic/systems/waves.gd")
const Factory = preload("res://logic/enemies/enemy_factory.gd")
func title() -> String: return "[9] Waves, Boss, elite drops"
func run(runner) -> void:
    var waves = Waves.new()
    runner.check(waves._quota_for(1) == 30 and waves._quota_for(9) == 318, "[9] normal quotas")
    runner.check(waves._quota_for(15) == 9 and waves._quota_for(25) == 13, "[9] boss quotas")
    var run = runner.harness.fresh_playing_game()
    Rng.set_source(func(): return 0.5)
    # 掉落源修复：盾兵基础 rank 为 normal，常规击杀不掉稀有物
    var shield = Factory.create_enemy_by_type("shield", 0, 0, 0, 1)
    run.enemies.append(shield); run.damage_enemy(shield, shield.maxHp * 10.0)
    runner.check(run.pickups.size() == 0, "[9] normal shield drops no rare")
    # 精英波路径赋 elite rank（与 logic/systems/waves.gd 同构），必掉 1 件
    var elite = Factory.create_enemy_by_type("shield", 0, 0, 0, 1)
    elite.rank = "elite"
    run.enemies.append(elite); run.damage_enemy(elite, elite.maxHp * 10.0)
    runner.check(run.pickups.size() == 1 and run.pickups[0]["kind"] == "rare", "[9] elite rare drop")
    run._update_pickups(0.0)
    runner.check(run.pickups[0]["dead"] and run.rareMessage != null and not run.rareMessage.get("detail", "").is_empty(), "[9] rare pickup explains its effect")
    var boss = Factory.create_enemy_by_type("boss", 60, 0, 0, 5)
    run.enemies.append(boss); boss.attackCooldown = 0; boss.update(run.player, 0.01, run._world()); boss.update(run.player, 0.86, run._world())
    runner.check(run.hostileProjectiles.size() == 12, "[9] boss radial burst")
    var before: int = run.pickups.size(); run.damage_enemy(boss, boss.maxHp * 10.0)
    runner.check(run.pickups.size() == before + 2 and run.bossesDefeated == 1, "[9] boss double rare drop")
    Rng.clear_source()
