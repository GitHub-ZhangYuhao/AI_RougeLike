extends Control

const WeaponFactoryScript: GDScript = preload("res://logic/weapons/weapon_factory.gd")
const SAVE_PATH: String = "user://debug_settings.json"

var run = null
var controls: Dictionary = {}
var weapon_controls: Dictionary = {}
var _updating: bool = false
var _refresh_timer: float = 0.0
var _enemy_type: OptionButton
var _enemy_count: SpinBox


func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_panel()
    set_process(true)


func bind_run(game_run) -> void:
    run = game_run
    refresh()


func toggle() -> bool:
    visible = not visible
    mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
    if visible and run != null:
        run.debug.set_paused(true)
        refresh()
    return visible


func refresh() -> void:
    if not visible or run == null:
        return
    _updating = true
    var settings: Dictionary = run.debug.settings
    controls["stats"].text = "状态 %s   波次 %d   敌人 %d\n时间 %s   等级 %d   经验 %.0f/%.0f" % [run.state, run.waveDirector.wave, _alive_count(), _format_time(run.elapsed), run.level, run.xp, run.xp_to_next()]
    controls["paused"].button_pressed = settings["paused"]
    controls["invincible"].button_pressed = settings["invincible"]
    controls["hp"].value = run.player.hp
    controls["damage"].value = settings["player"]["damageMult"]
    controls["xp"].value = settings["player"]["xpMult"]
    controls["speed"].value = settings["player"]["moveSpeedMult"]
    controls["max_hp"].value = settings["player"]["maxHpMult"]
    controls["pickup"].value = settings["player"]["pickupRangeMult"]
    controls["armor"].value = settings["player"]["armorBonus"]
    controls["enemy_hp"].value = settings["enemy"]["hpMult"]
    controls["enemy_damage"].value = settings["enemy"]["damageMult"]
    controls["enemy_speed"].value = settings["enemy"]["speedMult"]
    controls["wave"].value = run.waveDirector.wave
    controls["quota"].value = settings["spawn"]["quotaMult"]
    controls["alive_cap"].value = settings["spawn"]["aliveCap"] if settings["spawn"]["aliveCap"] != null else 0
    controls["interval"].value = settings["spawn"]["intervalMult"]
    controls["spawn_paused"].button_pressed = settings["spawn"]["paused"]
    for id: String in weapon_controls:
        var weapon = run.get_weapon(id)
        weapon_controls[id].value = weapon.level if weapon != null else 0
    _updating = false


func _process(delta: float) -> void:
    if not visible:
        return
    _refresh_timer -= delta
    if _refresh_timer <= 0.0:
        _refresh_timer = 0.2
        refresh()


func _build_panel() -> void:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
    panel.offset_left = -410.0
    panel.offset_right = -10.0
    panel.offset_top = 10.0
    panel.offset_bottom = -10.0
    panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    scroll.add_child(margin)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)
    var header := HBoxContainer.new()
    content.add_child(header)
    var title := Label.new()
    title.text = "调试面板 · F2"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("e0bf6c"))
    header.add_child(title)
    var close := Button.new()
    close.text = "关闭"
    _style_button(close)
    close.pressed.connect(toggle)
    header.add_child(close)
    var stats := Label.new()
    stats.custom_minimum_size.y = 50.0
    stats.add_theme_color_override("font_color", Color("b8c8b3"))
    stats.add_theme_font_size_override("font_size", 13)
    content.add_child(stats)
    controls["stats"] = stats
    _add_section(content, "游戏")
    controls["paused"] = _add_check(content, "暂停世界", Callable(self, "_paused_toggled"))
    controls["invincible"] = _add_check(content, "玩家无敌", Callable(self, "_invincible_toggled"))
    controls["hp"] = _add_number(content, "当前生命", 0.0, 1000000.0, 1.0, Callable(self, "_hp_changed"))
    _add_section(content, "玩家倍率")
    controls["damage"] = _add_number(content, "伤害", 0.0, 1000.0, 0.1, _player_setting.bind("damageMult"))
    controls["xp"] = _add_number(content, "经验", 0.0, 1000.0, 0.1, _player_setting.bind("xpMult"))
    controls["speed"] = _add_number(content, "移速", 0.0, 100.0, 0.1, _player_setting.bind("moveSpeedMult"))
    controls["max_hp"] = _add_number(content, "最大生命", 0.01, 1000.0, 0.1, _player_setting.bind("maxHpMult"))
    controls["pickup"] = _add_number(content, "拾取范围", 0.0, 1000.0, 0.1, _player_setting.bind("pickupRangeMult"))
    controls["armor"] = _add_number(content, "护甲加成", 0.0, 1000000.0, 5.0, _player_setting.bind("armorBonus"))
    _add_section(content, "敌人与刷怪")
    controls["enemy_hp"] = _add_number(content, "敌人生命", 0.01, 1000.0, 0.1, _enemy_setting.bind("hpMult"))
    controls["enemy_damage"] = _add_number(content, "敌人伤害", 0.0, 1000.0, 0.1, _enemy_setting.bind("damageMult"))
    controls["enemy_speed"] = _add_number(content, "敌人速度", 0.0, 1000.0, 0.1, _enemy_setting.bind("speedMult"))
    controls["wave"] = _add_number(content, "跳转波次", 1.0, Config.CONFIG["waves"]["maxWave"], 1.0, Callable(self, "_wave_changed"))
    controls["quota"] = _add_number(content, "波次数量倍率", 0.0, 1000.0, 0.1, _spawn_setting.bind("quotaMult"))
    controls["alive_cap"] = _add_number(content, "同屏上限（0默认）", 0.0, 10000.0, 1.0, _alive_cap_changed)
    controls["interval"] = _add_number(content, "刷新间隔倍率", 0.01, 1000.0, 0.05, _spawn_setting.bind("intervalMult"))
    controls["spawn_paused"] = _add_check(content, "暂停自动刷怪", Callable(self, "_spawn_paused_toggled"))
    var spawn_row := HBoxContainer.new()
    spawn_row.add_theme_constant_override("separation", 6)
    content.add_child(spawn_row)
    _enemy_type = OptionButton.new()
    _enemy_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for type: String in Config.CONFIG["enemyTypes"]:
        _enemy_type.add_item(type)
    spawn_row.add_child(_enemy_type)
    _enemy_count = SpinBox.new()
    _enemy_count.min_value = 1
    _enemy_count.max_value = 200
    _enemy_count.value = 1
    _enemy_count.custom_minimum_size.x = 78.0
    spawn_row.add_child(_enemy_count)
    var spawn_button := Button.new()
    spawn_button.text = "生成"
    _style_button(spawn_button)
    spawn_button.pressed.connect(_spawn_selected)
    spawn_row.add_child(spawn_button)
    var clear_button := Button.new()
    clear_button.text = "清场"
    _style_button(clear_button)
    clear_button.pressed.connect(Callable(self, "_clear_enemies"))
    spawn_row.add_child(clear_button)
    _add_section(content, "武器等级（0移除）")
    for card: Dictionary in WeaponFactoryScript.WEAPON_CARDS:
        weapon_controls[card["id"]] = _add_number(content, card["name"], 0.0, card["maxLevel"], 1.0, _weapon_level.bind(card["id"]))
    _add_section(content, "配置")
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 6)
    content.add_child(buttons)
    for data: Array in [["恢复默认", Callable(self, "_reset_defaults")], ["保存", Callable(self, "_save_settings")], ["载入", Callable(self, "_load_settings")]]:
        var button := Button.new()
        button.text = data[0]
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _style_button(button)
        button.pressed.connect(data[1])
        buttons.add_child(button)


func _add_section(parent: VBoxContainer, text: String) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color("79c99b"))
    parent.add_child(label)
    var separator := HSeparator.new()
    parent.add_child(separator)


func _add_check(parent: VBoxContainer, label: String, callback: Callable) -> CheckButton:
    var control := CheckButton.new()
    control.text = label
    control.toggled.connect(callback)
    parent.add_child(control)
    return control


func _add_number(parent: VBoxContainer, label: String, minimum: float, maximum: float, step: float, callback: Callable) -> SpinBox:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var text := Label.new()
    text.text = label
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(text)
    var control := SpinBox.new()
    control.min_value = minimum
    control.max_value = maximum
    control.step = step
    control.custom_minimum_size.x = 132.0
    control.value_changed.connect(callback)
    row.add_child(control)
    return control


func _paused_toggled(value: bool) -> void:
    if not _updating:
        run.debug.set_paused(value)


func _invincible_toggled(value: bool) -> void:
    if not _updating:
        run.debug.set_invincible(value)


func _spawn_paused_toggled(value: bool) -> void:
    if not _updating:
        run.debug.set_spawn_settings({"paused": value})


func _hp_changed(value: float) -> void:
    if not _updating:
        run.debug.set_player_hp(value)


func _wave_changed(value: float) -> void:
    if not _updating:
        run.debug.set_wave(value)


func _clear_enemies() -> void:
    run.debug.clear_enemies()


func _player_setting(value: float, key: String) -> void:
    if not _updating:
        run.debug.set_player_settings({key: value})


func _enemy_setting(value: float, key: String) -> void:
    if not _updating:
        run.debug.set_enemy_multipliers({key: value})


func _spawn_setting(value: float, key: String) -> void:
    if not _updating:
        run.debug.set_spawn_settings({key: value})


func _alive_cap_changed(value: float) -> void:
    if not _updating:
        run.debug.set_spawn_settings({"aliveCap": null if value <= 0.0 else floori(value)})


func _weapon_level(value: float, id: String) -> void:
    if not _updating:
        run.debug.set_weapon_level(id, value)


func _spawn_selected() -> void:
    run.debug.spawn_enemies(_enemy_type.get_item_text(_enemy_type.selected), floori(_enemy_count.value))


func _reset_defaults() -> void:
    run.debug.reset_defaults()
    refresh()


func _save_settings() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(run.debug.serialize()))


func _load_settings() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file != null:
        run.debug.apply_serialized(file.get_as_text())
        refresh()


func _alive_count() -> int:
    var count: int = 0
    for enemy in run.enemies:
        if not enemy.dead:
            count += 1
    return count


func _format_time(value: float) -> String:
    var seconds: int = maxi(0, floori(value))
    return "%02d:%02d" % [seconds / 60, seconds % 60]


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.04, 0.035, 0.98)
    style.border_color = Color("6f8f73")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
    style.shadow_size = 12
    return style


func _style_button(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.07, 0.12, 0.10, 0.96)
    normal.border_color = Color("6f8f73")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(6)
    var hover: StyleBoxFlat = normal.duplicate()
    hover.bg_color = Color(0.12, 0.20, 0.15, 1.0)
    hover.border_color = Color("e0bf6c")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
