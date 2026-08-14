extends RefCounted

const GameRunScript: GDScript = preload("res://logic/game_run.gd")
const TasksScript: GDScript = preload("res://logic/systems/tasks.gd")
const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const CardsScript: GDScript = preload("res://logic/cards.gd")

func title() -> String: return "[21] In-run tasks and rewards"

func run(runner) -> void:
    _guard_and_scheduling(runner)
    _delivery_and_bounty(runner)
    _real_loop_and_rewards(runner)


func _new_task_game(wave: int = 3):
    var game = GameRunScript.new()
    game.state = "playing"
    game.waveDirector.start_wave(wave, game)
    game.waveDirector.waveTimer = Config.CONFIG["waves"]["duration"]
    return game


func _guard_and_scheduling(runner) -> void:
    var game = _new_task_game(2)
    var director = TasksScript.new({"rng": func(): return 0.0})
    game.waveDirector.waveTimer = 40.0
    director.update(0.1, game)
    runner.check(director.current == null, "[21] non-task waves do not schedule")
    game.waveDirector.wave = 3
    game.waveDirector.waveTimer = 56.0
    director.update(0.1, game)
    runner.check(director.current == null, "[21] task waits for trigger")
    game.waveDirector.waveTimer = 55.0
    director.update(0.1, game)
    runner.check(director.current != null and director.current["state"] == "offered" and director.current["type"] == "guard", "[21] wave three triggers guard at 35 seconds")
    var beacon: Dictionary = director.current["beacon"]
    game.player.x = beacon["x"]; game.player.y = beacon["y"]
    director.update(0.5, game)
    runner.check(director.current["state"] == "offered", "[21] beacon needs continuous second")
    game.player.x += Config.CONFIG["tasks"]["beaconRadius"] + 10
    director.update(0.1, game)
    runner.check(director.current["acceptProgress"] == 0.0, "[21] leaving beacon resets progress")
    game.player.x = beacon["x"]
    director.update(1.0, game)
    runner.check(director.current["state"] == "active", "[21] beacon accepts task")
    director.current["payload"]["remaining"] = 0.05
    director.update(0.1, game)
    runner.check(director.current["outcome"] == "succeeded" and game.pendingTaskRewards.size() == 1, "[21] guard queues reward")

    var expired_game = _new_task_game(3)
    var expired = TasksScript.new({"rng": func(): return 0.0})
    expired_game.waveDirector.waveTimer = 55.0
    expired.update(0.1, expired_game)
    expired.update(Config.CONFIG["tasks"]["offerDuration"] + 0.1, expired_game)
    runner.check(expired.current["outcome"] == "expired", "[21] ignored beacon expires")
    director.update(Config.CONFIG["tasks"]["resultDuration"] + 0.1, game)
    director.update(0.1, game)
    runner.check(director.current == null, "[21] completed wave creates one offer")
    game.waveDirector.wave = 8
    game.waveDirector.waveTimer = 55.0
    director.update(0.1, game)
    runner.check(director.current != null and director.current["type"] == "delivery", "[21] task type does not repeat")
    game.release_runtime_refs(); expired_game.release_runtime_refs()


func _delivery_and_bounty(runner) -> void:
    var delivery_game = _new_task_game(3)
    var delivery_source := Sequence.new([0.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    var delivery = TasksScript.new({"rng": Callable(delivery_source, "next_value")})
    delivery_game.waveDirector.waveTimer = 55.0
    delivery.update(0.1, delivery_game)
    var beacon: Dictionary = delivery.current["beacon"]
    delivery_game.player.x = beacon["x"]; delivery_game.player.y = beacon["y"]
    delivery.update(1.0, delivery_game)
    runner.check(delivery.current["type"] == "delivery" and delivery.current["state"] == "active", "[21] deterministic delivery activates")
    delivery_game.waveDirector.spawned = 7
    delivery.current["payload"]["interceptorTimer"] = 0.0
    delivery.update(0.1, delivery_game)
    var interceptor_found: bool = false
    for enemy in delivery_game.enemies:
        interceptor_found = interceptor_found or enemy.taskRole == "interceptor"
    runner.check(interceptor_found and delivery_game.waveDirector.spawned == 7, "[21] interceptors do not consume quota")
    var destination: Dictionary = delivery.current["payload"]["destination"]
    delivery_game.player.x = destination["x"]; delivery_game.player.y = destination["y"]
    delivery.update(0.1, delivery_game)
    runner.check(delivery.current["outcome"] == "succeeded", "[21] destination completes delivery")

    var bounty_game = _new_task_game(3)
    var bounty_source := Sequence.new([0.0, 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    var bounty = TasksScript.new({"rng": Callable(bounty_source, "next_value")})
    bounty_game.waveDirector.waveTimer = 55.0
    bounty.update(0.1, bounty_game)
    beacon = bounty.current["beacon"]
    bounty_game.player.x = beacon["x"]; bounty_game.player.y = beacon["y"]
    bounty.update(1.0, bounty_game)
    var target = bounty.current["payload"]["target"]
    var fake = EnemyStub.new(); fake.taskId = -1; fake.taskRole = "bountyTarget"
    bounty.on_enemy_killed(fake, bounty_game)
    runner.check(bounty.current["state"] == "active", "[21] unrelated target ignored")
    bounty.on_enemy_killed(target, bounty_game)
    runner.check(bounty.current["outcome"] == "succeeded", "[21] matching bounty completes")
    delivery_game.release_runtime_refs(); bounty_game.release_runtime_refs()


func _real_loop_and_rewards(runner) -> void:
    var game = runner.harness.game
    game.reset(); game.state = "playing"
    game.weapons = [WeaponFactoryScript.create_weapon_by_type("sword", CardsScript.card_by_id("sword"))]
    game.taskDirector.set_rng(func(): return 0.0)
    game.waveDirector.start_wave(3, game)
    game.waveDirector.waveTimer = Config.CONFIG["waves"]["duration"] - Config.CONFIG["tasks"]["triggerWindow"][0]
    game.step(0.0)
    runner.check(game.taskDirector.current != null and game.taskDirector.current["state"] == "offered", "[21] real update loop runs task director")

    game.reset(); game.state = "playing"
    var sword = WeaponFactoryScript.create_weapon_by_type("sword", CardsScript.card_by_id("sword"))
    game.weapons = [sword]
    var weapon_offers: Array[Dictionary] = TasksScript.generate_task_reward_offers(game, func(): return 0.0)
    var stat_offers: Array[Dictionary] = TasksScript.generate_task_reward_offers(game, func(): return 0.5)
    var blessing_offers: Array[Dictionary] = TasksScript.generate_task_reward_offers(game, func(): return 0.9)
    for offers: Array in [weapon_offers, stat_offers, blessing_offers]:
        var ids: Dictionary = {}
        for offer: Dictionary in offers: ids[offer["card"]["id"]] = true
        runner.check(offers.size() == Config.CONFIG["tasks"]["rewards"]["choicesCount"], "[21] reward has three offers")
        runner.check(ids.size() == offers.size(), "[21] reward offers unique")
    runner.check(weapon_offers.all(func(offer): return offer["type"] == "taskWeapon"), "[21] weapon category")
    runner.check(stat_offers.all(func(offer): return offer["type"] == "taskStat"), "[21] stat category")
    runner.check(blessing_offers.all(func(offer): return offer["type"] == "taskBlessing"), "[21] blessing category")
    var damage_before: float = game.mods["damageMult"]
    TasksScript.apply_reward(stat_offers[0], game)
    runner.check(game.mods["damageMult"] != damage_before or game.taskBonuses["armor"] > 0.0 or game.taskBonuses["xpMult"] > 0.0 or game.taskBonuses["magnetRadiusBonus"] > 0.0 or game.player.maxHp > Config.CONFIG["player"]["maxHp"] or game.taskBonuses["moveSpeedMult"] > 0.0, "[21] stat reward applies")

    var talisman = WeaponFactoryScript.create_weapon_by_type("talisman", CardsScript.card_by_id("talisman"))
    sword.level = 3; talisman.level = 4; game.weapons = [sword, talisman]
    game.synergies.refresh(game.weapons, game.elapsed)
    var synergy_offer: Dictionary = {"type": "taskWeapon", "rewardId": "sword", "isNew": false, "card": {"id": "task-weapon-sword"}}
    TasksScript.apply_reward(synergy_offer, game)
    runner.check(sword.level == 4 and game.synergies.is_active("sword-talisman-mark"), "[21] weapon reward refreshes formal synergies")

    game.pendingChoices = 1
    game.queue_task_reward(stat_offers)
    game.step(0.0)
    runner.check(game.state == "choice" and game.choiceOrigin == "task" and game.pendingChoices == 1, "[21] task reward has priority")
    game._apply_offer(game.currentOffers[0]); game._finish_choice()
    runner.check(game.choiceOrigin == "levelup" and game.pendingChoices == 1, "[21] level-up resumes without consumption")


class Sequence extends RefCounted:
    var values: Array[float]
    var index: int = 0
    func _init(sequence: Array[float]) -> void: values = sequence
    func next_value() -> float:
        var value: float = values[index] if index < values.size() else 0.0
        index += 1
        return value


class EnemyStub extends RefCounted:
    var taskId = null
    var taskRole = null
