extends RefCounted
## [22] 音频资产与 AudioManager 映射冒烟：
##   - SFX_PATHS 中已登记的武器音效文件存在且可加载
##   - OGG 流时长合理（> 0.5s，防止空文件/截断产物混入）
##   - BGM 总线布局文件存在

func title() -> String: return "[22] Audio assets & AudioManager mapping"

func run(runner) -> void:
    _check_weapon_sfx(runner)
    _check_bus_layout(runner)


func _check_weapon_sfx(runner) -> void:
    var expected: Array[String] = ["sfx_cloak_burst", "sfx_trail_blaze"]
    for sfx_name in expected:
        runner.check(AudioManager.SFX_PATHS.has(sfx_name),
                "[22] SFX_PATHS contains %s" % sfx_name)
        if not AudioManager.SFX_PATHS.has(sfx_name):
            continue
        var path: String = AudioManager.SFX_PATHS[sfx_name]
        runner.check(ResourceLoader.exists(path),
                "[22] sfx asset exists: %s" % path)
        if not ResourceLoader.exists(path):
            continue
        var stream: AudioStream = load(path)
        runner.check(stream != null, "[22] sfx loadable: %s" % path)
        if stream == null:
            continue
        var length: float = stream.get_length()
        runner.check(length > 0.5,
                "[22] sfx length %.2fs > 0.5s: %s" % [length, path])


func _check_bus_layout(runner) -> void:
    var layout_path: String = "res://assets/audio/default_bus_layout.tres"
    runner.check(ResourceLoader.exists(layout_path),
            "[22] default bus layout exists: %s" % layout_path)
