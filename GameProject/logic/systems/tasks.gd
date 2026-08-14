extends RefCounted
## ← js/systems/tasks.js：局内随机任务、奖励池与任务导演。

const CardsScript: GDScript = preload("res://logic/cards.gd")
const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const EnemyFactoryScript: GDScript = preload("res://logic/enemies/enemy_factory.gd")

const TASK_TYPES: Array[String] = ["guard", "delivery", "bounty"]

var rng: Callable = Callable(Rng, "next")
var current = null
var scheduledWave = null
var triggerAt = null
var lastTaskType = null
var nextTaskId: int = 1
var completedWaves: Dictionary = {}


func _init(options: Dictionary = {}) -> void:
    if options.get("rng", Callable()).is_valid():
        rng = options["rng"]
    reset()


func reset() -> void:
    current = null
    scheduledWave = null
    triggerAt = null
    lastTaskType = null
    nextTaskId = 1
    completedWaves = {}


func set_rng(source: Callable = Callable()) -> void:
    rng = source if source.is_valid() else Callable(Rng, "next")


static func _clamp_random(source: Callable) -> float:
    return clampf(float(source.call()), 0.0, 0.999999)


static func _random_range(source: Callable, minimum: float, maximum: float) -> float:
    return minimum + (maximum - minimum) * _clamp_random(source)


static func _random_int(source: Callable, minimum: int, maximum: int) -> int:
    return floori(_random_range(source, minimum, maximum + 1))


static func _point_around(origin, distance: float, source: Callable) -> Dictionary:
    var angle: float = _random_range(source, 0.0, TAU)
    return {"x": origin.x + cos(angle) * distance, "y": origin.y + sin(angle) * distance}


static func _tier_value(values: Array, tier: int):
    return values[clampi(tier - 1, 0, values.size() - 1)]


static func _reward_card(id: String, name: String) -> Dictionary:
    return {"id": id, "kind": "taskReward", "name": name, "icon": "", "desc": ""}


static func _weapon_reward_pool(game) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for weapon in game.weapons:
        if weapon.level < weapon.card["maxLevel"]:
            pool.append({"type": "taskWeapon", "rewardId": weapon.card["id"], "isNew": false,
                "card": _reward_card("task-weapon-%s" % weapon.card["id"], "强化·%s" % weapon.card["name"]),
                "levelInfo": "Lv %d → Lv %d" % [weapon.level, weapon.level + 1]})
    if game.weapons.size() < Config.CONFIG["cards"]["maxWeaponSlots"]:
        for card: Dictionary in CardsScript.WEAPON_CARDS:
            var owned: bool = false
            for weapon in game.weapons:
                if weapon.card["id"] == card["id"]:
                    owned = true
                    break
            if not owned:
                pool.append({"type": "taskWeapon", "rewardId": card["id"], "isNew": true,
                    "card": _reward_card("task-weapon-new-%s" % card["id"], "武装·%s" % card["name"]),
                    "levelInfo": "获得 Lv 1"})
    return pool


static func _stat_reward_pool() -> Array[Dictionary]:
    var definitions: Array[Array] = [
        ["damage", "强攻", "伤害 +30%"], ["armor", "铁壁", "护甲 +30"],
        ["magnet", "聚灵", "拾取范围 +100px"], ["xp", "悟道", "经验 +30%"],
        ["hp", "血契", "最大生命 +40"], ["speed", "疾风", "移速 +12%"],
    ]
    var pool: Array[Dictionary] = []
    for definition: Array in definitions:
        pool.append({"type": "taskStat", "rewardId": definition[0],
            "card": _reward_card("task-stat-%s" % definition[0], definition[1]), "levelInfo": definition[2]})
    return pool


static func _blessing_reward_pool(game) -> Array[Dictionary]:
    var definitions: Array[Array] = [
        ["hunter", "猎杀祝福"], ["tenacity", "坚韧祝福"], ["swift-hunt", "疾猎祝福"],
        ["insight", "灵悟祝福"], ["battle-spirit", "战意祝福"],
    ]
    var pool: Array[Dictionary] = []
    for definition: Array in definitions:
        if game.taskBlessings.has(definition[0]):
            continue
        pool.append({"type": "taskBlessing", "rewardId": definition[0],
            "card": _reward_card("task-blessing-%s" % definition[0], definition[1]), "levelInfo": "祝福"})
    return pool


static func generate_task_reward_offers(game, source: Callable = Callable()) -> Array[Dictionary]:
    if not source.is_valid():
        source = Callable(Rng, "next")
    var pools: Dictionary = {
        "weapon": _weapon_reward_pool(game),
        "stat": _stat_reward_pool(),
        "blessing": _blessing_reward_pool(game),
    }
    var offers: Array[Dictionary] = []
    while offers.size() < Config.CONFIG["tasks"]["rewards"]["choicesCount"]:
        var available: Array[String] = []
        var total: float = 0.0
        for category: String in pools:
            if not pools[category].is_empty():
                available.append(category)
                total += Config.CONFIG["tasks"]["rewards"]["weights"][category]
        if available.is_empty():
            break
        var roll: float = _clamp_random(source) * total
        var selected: String = available[-1]
        for category: String in available:
            roll -= Config.CONFIG["tasks"]["rewards"]["weights"][category]
            if roll < 0.0:
                selected = category
                break
        var pool: Array = pools[selected]
        var index: int = floori(_clamp_random(source) * pool.size())
        var offer: Dictionary = pool.pop_at(index)
        # Bind only scalar reward data: never bind game/offer into a Callable owned by game.
        offer["apply"] = Callable(load("res://logic/systems/tasks.gd"), "apply_bound_reward").bind(
            offer["type"], offer["rewardId"], offer.get("isNew", false))
        offers.append(offer)
    return offers


static func apply_bound_reward(game, type: String, reward_id: String, is_new: bool) -> void:
    apply_reward({"type": type, "rewardId": reward_id, "isNew": is_new}, game)


static func apply_reward(offer: Dictionary, game) -> void:
    var reward_id: String = offer.get("rewardId", "")
    match offer.get("type", ""):
        "taskWeapon":
            if offer.get("isNew", false):
                if game.weapons.size() < Config.CONFIG["cards"]["maxWeaponSlots"] and game.get_weapon(reward_id) == null:
                    var card: Dictionary = CardsScript.card_by_id(reward_id)
                    var weapon = WeaponFactoryScript.create_weapon_by_type(reward_id, card)
                    if weapon != null:
                        game.weapons.append(weapon)
            else:
                var owned = game.get_weapon(reward_id)
                if owned != null and owned.level < owned.card["maxLevel"]:
                    owned.level += 1
            # 任务武器奖励与正式升级走同一条联动刷新路径。
            game.synergies.refresh(game.weapons, game.elapsed)
        "taskStat":
            match reward_id:
                "damage": game.taskBonuses["damageMult"] += 0.3
                "armor": game.taskBonuses["armor"] += 30.0
                "magnet": game.taskBonuses["magnetRadiusBonus"] += 100.0
                "xp": game.taskBonuses["xpMult"] += 0.3
                "hp": game.increase_max_hp(40.0, 40.0)
                "speed": game.taskBonuses["moveSpeedMult"] += 0.12
            game.recompute_mods()
        "taskBlessing":
            if game.taskBlessings.has(reward_id):
                return
            game.taskBlessings[reward_id] = true
            match reward_id:
                "hunter": game.taskBonuses["eliteBossDamageMult"] += 0.25
                "tenacity":
                    game.taskBonuses["armor"] += 20.0
                    game.increase_max_hp(25.0, 25.0)
                "swift-hunt":
                    game.taskBonuses["moveSpeedMult"] += 0.1
                    game.taskBonuses["magnetRadiusBonus"] += 80.0
                "insight":
                    game.taskBonuses["xpMult"] += 0.25
                    game.taskBonuses["damageMult"] += 0.1
                "battle-spirit":
                    game.taskBonuses["damageMult"] += 0.2
                    game.taskBonuses["moveSpeedMult"] += 0.06
            game.recompute_mods()


func update(dt: float, game) -> void:
    var director = game.waveDirector
    if director == null:
        return
    _sync_wave(director.wave)
    if current != null and current["state"] == "result":
        current["resultRemaining"] -= dt
        if current["resultRemaining"] <= 0.0:
            current = null
        return
    if current == null and scheduledWave == director.wave and not completedWaves.has(director.wave) and triggerAt != null and director.phase == "wave":
        var wave_elapsed: float = Config.CONFIG["waves"]["duration"] - director.timeRemaining
        if wave_elapsed >= triggerAt:
            _create_offer(game, director.wave)
    if current == null:
        return
    if current["wave"] != director.wave or director.phase != "wave":
        _finish_result("failed" if current["state"] == "active" else "expired")
        return
    if current["state"] == "offered":
        _update_offer(dt, game)
    elif current["state"] == "active":
        _update_active(dt, game)


func on_enemy_killed(enemy, game) -> void:
    if current == null or current["state"] != "active" or current["type"] != "bounty":
        return
    if enemy.taskId == current["id"] and enemy.taskRole == "bountyTarget":
        _succeed(game)


func _sync_wave(wave: int) -> void:
    if scheduledWave == wave or completedWaves.has(wave):
        return
    scheduledWave = wave
    if not Config.CONFIG["tasks"]["waves"].has(wave):
        triggerAt = null
        return
    var window: Array = Config.CONFIG["tasks"]["triggerWindow"]
    triggerAt = _random_range(rng, window[0], window[1])


func _create_offer(game, wave: int) -> void:
    var tier: int = Config.CONFIG["tasks"]["waves"].find(wave) + 1
    var choices: Array[String] = []
    for type: String in TASK_TYPES:
        if type != lastTaskType:
            choices.append(type)
    var type: String = choices[floori(_clamp_random(rng) * choices.size())]
    var distances: Array = Config.CONFIG["tasks"]["beaconDistance"]
    var beacon: Dictionary = _point_around(game.player, _random_range(rng, distances[0], distances[1]), rng)
    lastTaskType = type
    completedWaves[wave] = true
    triggerAt = null
    current = {"id": nextTaskId, "type": type, "tier": tier, "wave": wave, "state": "offered",
        "beacon": beacon, "offerRemaining": Config.CONFIG["tasks"]["offerDuration"],
        "acceptProgress": 0.0, "payload": {}}
    nextTaskId += 1


func _update_offer(dt: float, game) -> void:
    var dx: float = game.player.x - current["beacon"]["x"]
    var dy: float = game.player.y - current["beacon"]["y"]
    var radius: float = Config.CONFIG["tasks"]["beaconRadius"]
    current["acceptProgress"] = current["acceptProgress"] + dt if dx * dx + dy * dy <= radius * radius else 0.0
    if current["acceptProgress"] >= Config.CONFIG["tasks"]["acceptDuration"]:
        _activate(game)
        return
    current["offerRemaining"] -= dt
    if current["offerRemaining"] <= 0.0:
        _finish_result("expired")


func _activate(game) -> void:
    current["state"] = "active"
    var tier: int = current["tier"]
    if current["type"] == "guard":
        var duration: float = _tier_value(Config.CONFIG["tasks"]["guard"]["durations"], tier)
        current["payload"] = {"center": current["beacon"].duplicate(), "duration": duration, "remaining": duration,
            "radius": _tier_value(Config.CONFIG["tasks"]["guard"]["radii"], tier),
            "leaveGrace": _tier_value(Config.CONFIG["tasks"]["guard"]["leaveGrace"], tier), "outsideFor": 0.0}
    elif current["type"] == "delivery":
        var distance_range: Array = _tier_value(Config.CONFIG["tasks"]["delivery"]["distances"], tier)
        current["payload"] = {"destination": _point_around(current["beacon"], _random_range(rng, distance_range[0], distance_range[1]), rng),
            "timeRemaining": _tier_value(Config.CONFIG["tasks"]["delivery"]["timeLimits"], tier),
            "interceptorTimer": _tier_value(Config.CONFIG["tasks"]["delivery"]["interceptorIntervals"], tier)}
    else:
        var distance_range: Array = Config.CONFIG["tasks"]["bounty"]["spawnDistance"]
        var position: Dictionary = _point_around(game.player, _random_range(rng, distance_range[0], distance_range[1]), rng)
        var target = EnemyFactoryScript.create_enemy_by_type(_bounty_enemy_type(tier), position["x"], position["y"], game.elapsed, current["wave"])
        target.maxHp *= _tier_value(Config.CONFIG["tasks"]["bounty"]["hpMultipliers"], tier)
        target.hp = target.maxHp
        target.damage *= _tier_value(Config.CONFIG["tasks"]["bounty"]["damageMultipliers"], tier)
        target.taskId = current["id"]
        target.taskRole = "bountyTarget"
        target.suppressRareDrop = true
        target.name = "悬赏目标"
        game.enemies.append(target)
        current["payload"] = {"target": target, "timeRemaining": _tier_value(Config.CONFIG["tasks"]["bounty"]["timeLimits"], tier)}


func _update_active(dt: float, game) -> void:
    var payload: Dictionary = current["payload"]
    if current["type"] == "guard":
        var dx: float = game.player.x - payload["center"]["x"]
        var dy: float = game.player.y - payload["center"]["y"]
        payload["outsideFor"] = payload["outsideFor"] + dt if dx * dx + dy * dy > payload["radius"] * payload["radius"] else 0.0
        if payload["outsideFor"] > payload["leaveGrace"]:
            _finish_result("failed")
            return
        payload["remaining"] -= dt
        if payload["remaining"] <= 0.0:
            _succeed(game)
    elif current["type"] == "delivery":
        var dx: float = game.player.x - payload["destination"]["x"]
        var dy: float = game.player.y - payload["destination"]["y"]
        var radius: float = Config.CONFIG["tasks"]["delivery"]["destinationRadius"]
        if dx * dx + dy * dy <= radius * radius:
            _succeed(game)
            return
        payload["timeRemaining"] -= dt
        payload["interceptorTimer"] -= dt
        if payload["interceptorTimer"] <= 0.0:
            _spawn_interceptors(game, current["tier"], current["id"])
            payload["interceptorTimer"] += _tier_value(Config.CONFIG["tasks"]["delivery"]["interceptorIntervals"], current["tier"])
        if payload["timeRemaining"] <= 0.0:
            _finish_result("failed")
    else:
        payload["timeRemaining"] -= dt
        if payload["timeRemaining"] <= 0.0:
            if payload["target"] != null and not payload["target"].dead:
                payload["target"].dead = true
            _finish_result("failed")


func _spawn_interceptors(game, tier: int, task_id: int) -> void:
    var count_range: Array = _tier_value(Config.CONFIG["tasks"]["delivery"]["interceptorCounts"], tier)
    var count: int = _random_int(rng, count_range[0], count_range[1])
    var type: String = "chaser" if tier <= 1 else ("enhancedChaser" if tier <= 3 else "charger")
    for i in count:
        var position: Dictionary = _point_around(game.player, _random_range(rng, 240.0, 340.0), rng)
        var enemy = EnemyFactoryScript.create_enemy_by_type(type, position["x"], position["y"], game.elapsed, game.waveDirector.wave)
        enemy.taskId = task_id
        enemy.taskRole = "interceptor"
        enemy.suppressRareDrop = true
        game.enemies.append(enemy)


func _bounty_enemy_type(tier: int) -> String:
    if tier == 1:
        return "enhancedChaser"
    if tier == 2:
        return "enhancedChaser" if _clamp_random(rng) < 0.5 else "charger"
    return "charger" if _clamp_random(rng) < 0.5 else "shield"


func _succeed(game) -> void:
    var offers: Array[Dictionary] = generate_task_reward_offers(game, rng)
    if not offers.is_empty():
        game.queue_task_reward(offers)
    _finish_result("succeeded")


func _finish_result(outcome: String) -> void:
    current["state"] = "result"
    current["outcome"] = outcome
    current["message"] = "任务完成，获得强力奖励" if outcome == "succeeded" else "任务未完成"
    current["resultRemaining"] = Config.CONFIG["tasks"]["resultDuration"]
