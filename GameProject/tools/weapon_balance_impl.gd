extends RefCounted
## 武器强度对比 harness 实现（由 res://tools/weapon_balance.gd 运行时 load）。
## 方法见 BALANCE.md「第六轮」：固定敌群（wave 11 档位 chaser x40）/ 单武器配装 /
## 固定 RNG 种子（LCG，每测试重置，保证各武器初始敌位一致）/ 无敌 + xpMult=0 防选卡污染。
## 玩家每 60 帧交替 KeyD/KeyA 巡逻（trail 需要 moving 才掉火）。
## 指标：总伤害（含 overkill）、击杀数、清场时间、DPS。

const HarnessScript: GDScript = preload("res://tests/scenarios/_harness.gd")

const WEAPONS: Array[String] = ["sword", "cloak", "talisman", "trail", "ring", "staff"]
const TEST_LEVELS: Array[int] = [3, 6]
const ENEMY_TYPE: String = "chaser"
const ENEMY_COUNT: int = 40
const TEST_FRAMES: int = 1800  # 30s @ 60fps
const PATROL_PERIOD_FRAMES: int = 60
const TEST_WAVE: int = 11  # 非精英(3n)/非Boss(5n)/非任务波([3,8,13,18,23])，60s 计时内不进阶
const RNG_SEED: int = 987654321

var _lcg_state: int = 0


func run() -> void:
    MetaSave.reset_save()
    var harness: RefCounted = HarnessScript.new()
    var results: Array[Dictionary] = []
    for level in TEST_LEVELS:
        for weapon_id in WEAPONS:
            results.append(_run_one(harness, weapon_id, level))
    Rng.clear_source()
    _print_report(results)


func _reset_rng() -> void:
    _lcg_state = RNG_SEED
    Rng.set_source(func() -> float:
        _lcg_state = (_lcg_state * 1103515245 + 12345) & 0x7FFFFFFF
        return float(_lcg_state) / float(0x7FFFFFFF))


func _run_one(harness, weapon_id: String, level: int) -> Dictionary:
    var game = harness.fresh_playing_game()
    _reset_rng()
    game.debug.set_invincible(true)
    game.debug.set_player_settings({"xpMult": 0.0})
    game.debug.set_wave(TEST_WAVE)
    game.debug.set_spawn_settings({"paused": true})
    for id in WEAPONS:
        game.debug.set_weapon_level(id, 0)
    game.debug.set_weapon_level(weapon_id, level)
    var spawned: Array = game.debug.spawn_enemies(ENEMY_TYPE, ENEMY_COUNT)
    var pool_hp: float = 0.0
    for enemy in spawned:
        pool_hp += enemy.maxHp
    var patrol_key: String = "KeyD"
    game.input.key_down(patrol_key)
    var clear_frame: int = -1
    for frame in TEST_FRAMES:
        if frame > 0 and frame % PATROL_PERIOD_FRAMES == 0:
            game.input.key_up(patrol_key)
            patrol_key = "KeyA" if patrol_key == "KeyD" else "KeyD"
            game.input.key_down(patrol_key)
        if game.state == "opening" or game.state == "choice":
            game.input.key_down("Digit1")
            game.input.key_up("Digit1")
        game.step(HarnessScript.STEP, HarnessScript.VIEW_W, HarnessScript.VIEW_H)
        game.input.end_frame()
        if clear_frame < 0:
            var alive: int = 0
            for enemy in spawned:
                if not enemy.dead:
                    alive += 1
            if alive == 0:
                clear_frame = frame + 1
    game.input.key_up(patrol_key)
    var total_damage: float = 0.0
    var kills: int = 0
    for enemy in spawned:
        total_damage += enemy.maxHp - enemy.hp
        if enemy.dead:
            kills += 1
    var duration: float = TEST_FRAMES * HarnessScript.STEP
    return {
        "weapon": weapon_id, "level": level,
        "totalDamage": total_damage, "poolHp": pool_hp, "kills": kills,
        "clearTime": clear_frame * HarnessScript.STEP if clear_frame >= 0 else -1.0,
        "dps": total_damage / duration,
        "state": game.state,
    }


func _print_report(results: Array[Dictionary]) -> void:
    print("== weapon balance harness ==")
    print("seed=%d wave=%d enemies=%s x%d frames=%d (%.1fs)" % [
        RNG_SEED, TEST_WAVE, ENEMY_TYPE, ENEMY_COUNT, TEST_FRAMES, TEST_FRAMES * HarnessScript.STEP])
    for level in TEST_LEVELS:
        var rows: Array[Dictionary] = []
        for row in results:
            if row["level"] == level:
                rows.append(row)
        rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dps"] > b["dps"])
        print("")
        print("-- Lv%d (pool HP = %.0f) --" % [level, rows[0]["poolHp"]])
        print("%-9s %11s %6s %10s %8s %s" % ["weapon", "totalDmg", "kills", "clearTime", "dps", "note"])
        var best_dps: float = rows[0]["dps"]
        for row in rows:
            var clear_text: String = ("%.2fs" % row["clearTime"]) if row["clearTime"] >= 0.0 else "  --  "
            var note: String = ""
            if row["state"] != "playing":
                note = "state=%s" % row["state"]
            print("%-9s %11.0f %6d %10s %8.1f %s" % [row["weapon"], row["totalDamage"], row["kills"], clear_text, row["dps"], note])
        print("spread: best/worst = %.2fx" % (best_dps / maxf(1.0, rows[-1]["dps"])))
