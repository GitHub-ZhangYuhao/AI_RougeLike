extends RefCounted
class_name SmokeRunner
## 冒烟测试场景注册表 + 汇总 + 退出码（由 tools/run_smoke.gd 调用）。
## 与原型 tools/headless-smoke.mjs 同构：断言文案保留 "[章节号]" 前缀，便于两边 diff。
##
## 场景契约：tests/scenarios/*.gd，extends RefCounted，实现：
##   func title() -> String           # 如 "[0] Weapon card structure"
##   func run(runner) -> void         # 用 runner.check() / runner.fail() 断言
## 新章节完成后把 res:// 路径追加进 SCENARIO_PATHS 即完成注册。
## 注意：headless --script 运行没有编辑器生成的全局类缓存，场景里不要直接引用
## SmokeRunner 类型名；如需静态类型标注，用 preload 拿脚本类型：
##   const SmokeRunnerScript: GDScript = preload("res://tests/smoke_runner.gd")
##   func run(runner: SmokeRunnerScript) -> void: ...
##
## M0：注册表为空，仅跑脚手架自检（autoload 四件套），空注册表也算 OK。

const HarnessScript: GDScript = preload("res://tests/scenarios/_harness.gd")

## 已注册的 smoke 场景（一章一个 .gd）。按原型线性执行顺序共享同一个 game。
const SCENARIO_PATHS: Array[String] = [
    "res://tests/scenarios/s00_weapon_cards.gd",
    "res://tests/scenarios/s01_menu_opening.gd",
    "res://tests/scenarios/s02_movement.gd",
    "res://tests/scenarios/s03_idle_wave.gd",
    "res://tests/scenarios/s04_mouse_choice.gd",
    "res://tests/scenarios/s05_attr_cards.gd",
    "res://tests/scenarios/s06_weapon_mechanics.gd",
    "res://tests/scenarios/s07_generate_offers.gd",
    "res://tests/scenarios/s08_enemy_base.gd",
    "res://tests/scenarios/s09_waves_boss_drops.gd",
    "res://tests/scenarios/debug_runtime.gd",
    "res://tests/scenarios/s10_death_return.gd",
    "res://tests/scenarios/s11_boss_drop_bounds.gd",
    "res://tests/scenarios/s12_extraction.gd",
    "res://tests/scenarios/s13_continue_deeper.gd",
    "res://tests/scenarios/s14_death_loss.gd",
    "res://tests/scenarios/s15_meta_shop.gd",
    "res://tests/scenarios/s16_storage_meta.gd",
    "res://tests/scenarios/s17_final_wave.gd",
    "res://tests/scenarios/s18_synergy_infrastructure.gd",
    "res://tests/scenarios/s19_synergy_batches.gd",
    "res://tests/scenarios/s20_synergy_third_batch.gd",
    "res://tests/scenarios/s21_tasks_rewards.gd",
    "res://tests/scenarios/s22_audio.gd",
    "res://tests/scenarios/s23_touch_choice.gd",

    "res://tests/scenarios/s24_flipbook.gd",
]

var harness = HarnessScript.new()
var _failures: Array[String] = []
var _check_count: int = 0


## 断言：condition 为 false 时记录失败并打印（不中断后续检查，便于一次跑完看全貌）。
func check(condition: bool, message: String) -> void:
    _check_count += 1
    if not condition:
        _failures.append(message)
        printerr("FAIL: %s" % message)


## 直接记一条失败。
func fail(message: String) -> void:
    check(false, message)


## 跑全部检查，返回是否全绿。
func run_all() -> bool:
    print("[smoke] registered scenarios: %d" % SCENARIO_PATHS.size())
    _run_scaffold_checks()
    _run_scenarios()
    Rng.clear_source()
    if harness.game != null:
        harness.game.release_runtime_refs()
    harness.game = null
    if _failures.is_empty():
        print("All smoke tests passed (%d checks, %d scenarios)." % [_check_count, SCENARIO_PATHS.size()])
        return true
    printerr("Smoke FAILED: %d/%d checks failed." % [_failures.size(), _check_count])
    return false


func _run_scenarios() -> void:
    for path: String in SCENARIO_PATHS:
        var script: GDScript = load(path)
        if script == null or not script.can_instantiate():
            fail("[scenario] cannot load/instantiate %s" % path)
            continue
        var scenario: RefCounted = script.new()
        var failures_before: int = _failures.size()
        scenario.run(self)
        if _failures.size() == failures_before:
            print("%s OK" % str(scenario.title()))


# ---------- M0 脚手架自检 ----------

func _run_scaffold_checks() -> void:
    _check_config()
    _check_rng()
    _check_meta_save()
    _check_events()


# CONFIG 抽样：与 BALANCE.md / js/config.js 对照。
func _check_config() -> void:
    var cfg: Dictionary = Config.CONFIG
    check(cfg["player"]["radius"] == 14, "[M0] CONFIG.player.radius == 14")
    check(cfg["player"]["hurtIFrames"] == 0.8, "[M0] CONFIG.player.hurtIFrames == 0.8")
    check(cfg["camera"]["lerp"] == 8, "[M0] CONFIG.camera.lerp == 8")
    check(cfg["spawner"]["maxAliveCap"] == 180, "[M0] CONFIG.spawner.maxAliveCap == 180")
    check(cfg["enemy"]["hpPerWaveMid"] == 0.12, "[M0] CONFIG.enemy.hpPerWaveMid == 0.12")
    check(cfg["enemy"]["damagePerMin"] == 1.0 and cfg["enemy"]["damagePerWaveLate"] == 0.09, "[M0] CONFIG.enemy damage curve")
    check(cfg["enemyTypes"]["chaser"]["weight"] == 62, "[M0] CONFIG.enemyTypes.chaser.weight == 62")
    check(cfg["enemyTypes"]["chaser"]["maxAlive"] == INF, "[M0] CONFIG.enemyTypes.chaser.maxAlive == INF")
    check(cfg["enemyTypes"]["boss"]["hpMult"] == 24, "[M0] CONFIG.enemyTypes.boss.hpMult == 24")
    check(cfg["enemyTypes"]["boss"]["enragedProjectileSpeed"] == 205, "[M0] CONFIG.enemyTypes.boss.enragedProjectileSpeed == 205")
    check(cfg["waves"]["duration"] == 60, "[M0] CONFIG.waves.duration == 60")
    check(cfg["waves"]["quantityWaveCap"] == 14, "[M0] CONFIG.waves.quantityWaveCap == 14")
    check(cfg["tasks"]["waves"] == [3, 8, 13, 18, 23], "[M0] CONFIG.tasks.waves == [3, 8, 13, 18, 23]")
    check(cfg["tasks"]["guard"]["durations"] == [18, 20, 22, 24, 26], "[M0] CONFIG.tasks.guard.durations")
    check(cfg["tasks"]["delivery"]["distances"][4] == [1900, 2200], "[M0] CONFIG.tasks.delivery.distances[4]")
    check(cfg["tasks"]["rewards"]["weights"]["blessing"] == 0.25, "[M0] CONFIG.tasks.rewards.weights.blessing == 0.25")
    check(cfg["gems"]["tiers"][2]["until"] == INF, "[M0] CONFIG.gems.tiers[2].until == INF")
    check(cfg["xp"] == {"base": 6, "perLevel": 4}, "[M0] CONFIG.xp == {base: 6, perLevel: 4}")
    check(cfg["pickups"]["maxAlive"] == 5, "[M0] CONFIG.pickups.maxAlive == 5")
    check(cfg["hud"]["font"] == "16px \"Segoe UI\", \"Microsoft YaHei\", sans-serif", "[M0] CONFIG.hud.font")
    check(cfg["meta"]["tierWeights"]["5"] == [10, 40, 50], "[M0] CONFIG.meta.tierWeights[5] == [10, 40, 50]")
    check(cfg["meta"]["dropCount"]["3"] == [1, 2], "[M0] CONFIG.meta.dropCount[3] == [1, 2]")
    check(cfg["meta"]["guaranteedMinTier"]["5"] == 3, "[M0] CONFIG.meta.guaranteedMinTier[5] == 3")
    check(cfg["meta"]["deathRewardMult"] == 0.35, "[M0] CONFIG.meta.deathRewardMult == 0.35")
    check(cfg["meta"]["shopPrice"]["growth"] == 1.6, "[M0] CONFIG.meta.shopPrice.growth == 1.6")
    check(cfg["meta"]["saveKey"] == "ai-roguelike-meta-save-v1", "[M0] CONFIG.meta.saveKey")


# Rng 注入：确定性序列必须原样返回；清除注入后回到内部 RNG。
func _check_rng() -> void:
    var source := SequenceSource.new([0.1, 0.5, 0.9])
    Rng.set_source(Callable(source, "next_value"))
    check(is_equal_approx(Rng.next(), 0.1), "[M0] Rng injected sequence returns 0.1")
    check(is_equal_approx(Rng.next(), 0.5), "[M0] Rng injected sequence returns 0.5")
    check(is_equal_approx(Rng.next(), 0.9), "[M0] Rng injected sequence returns 0.9")
    check(is_equal_approx(Rng.next(), 0.1), "[M0] Rng injected sequence wraps around")
    Rng.clear_source()
    var value: float = Rng.next()
    check(value >= 0.0 and value < 1.0, "[M0] Rng.clear_source restores internal RNG in [0, 1)")


# MetaSave：默认结构与 RULES.md §15.5 一致；merge_into 语义同 save.js mergeInto。
func _check_meta_save() -> void:
    var expected: Dictionary = {
        "version": 1,
        "darkCrystals": 0,
        "storage": {"shard": 0, "essence": 0, "soulCrystal": 0},
        "metaLevels": {"damage": 0, "armor": 0, "magnet": 0, "xp": 0, "maxHp": 0, "moveSpeed": 0},
        "stats": {"runs": 0, "extractions": 0, "completions": 0, "bestWave": 0, "totalBossKills": 0},
    }
    check(MetaSave.default_save() == expected, "[M0] MetaSave.default_save matches RULES.md §15.5")

    # 未知字段忽略、类型不符保留默认、嵌套深合并。
    var merged: Dictionary = MetaSave.default_save()
    MetaSave.merge_into(merged, {
        "version": 1,
        "darkCrystals": 42,
        "unknownField": 999,
        "storage": {"shard": 3, "unexpected": 1},
        "stats": {"bestWave": "not-a-number", "completions": 2},
        "metaLevels": "wrong-type",
    })
    check(merged["darkCrystals"] == 42, "[M0] merge keeps valid darkCrystals")
    check(not merged.has("unknownField"), "[M0] merge ignores unknown fields")
    check(merged["storage"] == {"shard": 3, "essence": 0, "soulCrystal": 0}, "[M0] merge deep-merges storage")
    check(merged["stats"]["bestWave"] == 0, "[M0] merge rejects type-mismatched value")
    check(merged["stats"]["completions"] == 2, "[M0] merge keeps valid completions")
    check(merged["metaLevels"] == expected["metaLevels"], "[M0] merge rejects non-dict nested value")
    check(MetaSave.merge_into(MetaSave.default_save(), null)["version"] == 1, "[M0] merge tolerates null data")


# Events：声明的信号集合存在（M1+ 逐步 emit）。
func _check_events() -> void:
    for signal_name: String in [
        "screen_shake", "effect_spawned", "enemy_killed", "player_hurt",
        "player_level_up", "wave_banner", "announcement", "sfx_requested",
    ]:
        check(Events.has_signal(signal_name), "[M0] Events declares signal '%s'" % signal_name)


# 确定性序列源：供 Rng.set_source 注入（测试专用）。
class SequenceSource extends RefCounted:
    var values: Array[float] = []
    var index: int = 0

    func _init(sequence: Array[float]) -> void:
        values = sequence

    func next_value() -> float:
        var value: float = values[index % values.size()]
        index += 1
        return value