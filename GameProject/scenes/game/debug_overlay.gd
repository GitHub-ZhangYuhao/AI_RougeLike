extends Control

const WeaponFactoryScript: GDScript = preload('res://logic/weapons/weapon_factory.gd')
const ArtCatalog: GDScript = preload('res://scenes/art_catalog.gd')
const UI_FONT: Font = preload('res://assets/fonts/ui_font_round.tres')
const SAVE_PATH: String = 'user://debug_settings.json'
const INK: Color = Color('4b2f2a')
const CREAM: Color = Color('fff6de')
const CORAL: Color = Color('ff6b5f')
const MINT: Color = Color('78d6b2')
const HONEY: Color = Color('ffc65c')
const JADE: Color = Color('26977c')
const DEEP_TEAL: Color = Color('143f3c')

var run = null
var controls: Dictionary = {}
var weapon_controls: Dictionary = {}
var _updating: bool = false
var _refresh_timer: float = 0.0
var _enemy_type: OptionButton
var _enemy_count: SpinBox
var _crystal_amount: SpinBox
var _crystal_label: Label
var _launcher: Button
var _panel: PanelContainer
var _dimmer: ColorRect
var _paused_before_open: bool = false
var _pause_changed_by_user: bool = false


func _ready() -> void:
  visible = true
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  var ui_theme := Theme.new()
  ui_theme.default_font = UI_FONT
  theme = ui_theme
  _build_launcher()
  _build_panel()
  set_process(true)


func bind_run(game_run) -> void:
  run = game_run
  _launcher.disabled = false
  refresh()


func is_open() -> bool:
  return _panel != null and _panel.visible


func consumes_pointer(viewport_position: Vector2) -> bool:
  if is_open():
    return true
  return _launcher != null and _launcher.visible and _launcher.get_global_rect().has_point(viewport_position)


func toggle() -> bool:
  return set_open(not is_open())


func set_open(open: bool) -> bool:
  if _panel == null or is_open() == open:
    return is_open()
  if open:
    _pause_changed_by_user = false
    _paused_before_open = false if run == null else bool(run.debug.settings['paused'])
    if run != null:
      run.debug.set_paused(true)
    _panel.visible = true
    _dimmer.visible = true
    _launcher.visible = false
    refresh()
  else:
    _panel.visible = false
    _dimmer.visible = false
    _launcher.visible = true
    if run != null and not _pause_changed_by_user:
      run.debug.set_paused(_paused_before_open)
  return is_open()


func refresh() -> void:
  if not is_open() or run == null:
    return
  _updating = true
  var settings: Dictionary = run.debug.settings
  controls['stats'].text = '状态 %s   波次 %d   敌人 %d\n时间 %s   等级 %d   经验 %.0f/%.0f' % [run.state, run.waveDirector.wave, _alive_count(), _format_time(run.elapsed), run.level, run.xp, run.xp_to_next()]
  controls['paused'].button_pressed = settings['paused']
  controls['invincible'].button_pressed = settings['invincible']
  controls['hp'].value = run.player.hp
  controls['damage'].value = settings['player']['damageMult']
  controls['xp'].value = settings['player']['xpMult']
  controls['speed'].value = settings['player']['moveSpeedMult']
  controls['max_hp'].value = settings['player']['maxHpMult']
  controls['pickup'].value = settings['player']['pickupRangeMult']
  controls['armor'].value = settings['player']['armorBonus']
  controls['enemy_hp'].value = settings['enemy']['hpMult']
  controls['enemy_damage'].value = settings['enemy']['damageMult']
  controls['enemy_speed'].value = settings['enemy']['speedMult']
  controls['wave'].value = run.waveDirector.wave
  controls['quota'].value = settings['spawn']['quotaMult']
  controls['alive_cap'].value = settings['spawn']['aliveCap'] if settings['spawn']['aliveCap'] != null else 0
  controls['interval'].value = settings['spawn']['intervalMult']
  controls['spawn_paused'].button_pressed = settings['spawn']['paused']
  for id: String in weapon_controls:
    var weapon = run.get_weapon(id)
    weapon_controls[id].value = weapon.level if weapon != null else 0
  _crystal_label.text = '暗晶 %d' % int(run.save.get('darkCrystals', 0))
  _updating = false


func _process(delta: float) -> void:
  if not is_open():
    _launcher.visible = false  # Debug launcher hidden by default
    return
  _refresh_timer -= delta
  if _refresh_timer <= 0.0:
    _refresh_timer = 0.2
    refresh()


func _build_launcher() -> void:
  _launcher = Button.new()
  _launcher.name = 'DebugLauncher'
  _launcher.text = '调试台   F2'
  _launcher.tooltip_text = '打开游戏内调试台（F2）'
  _launcher.set_anchors_preset(Control.PRESET_TOP_RIGHT)
  _launcher.offset_left = -150.0
  _launcher.offset_right = -18.0
  _launcher.offset_top = 140.0
  _launcher.offset_bottom = 176.0
  _launcher.icon = ArtCatalog.UI_TEXTURES['buttonCrest']
  _launcher.expand_icon = true
  _launcher.add_theme_constant_override('icon_max_width', 23)
  _launcher.add_theme_font_size_override('font_size', 14)
  _launcher.disabled = true
  _style_button(_launcher, true)
  _launcher.pressed.connect(toggle)
  add_child(_launcher)


func _build_panel() -> void:
  _dimmer = ColorRect.new()
  _dimmer.name = 'DebugDimmer'
  _dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
  _dimmer.color = Color(0.035, 0.13, 0.13, 0.68)
  _dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
  _dimmer.visible = false
  _dimmer.gui_input.connect(_on_dimmer_input)
  add_child(_dimmer)

  _panel = PanelContainer.new()
  _panel.name = 'DebugPanel'
  _panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
  _panel.offset_left = -484.0
  _panel.offset_right = -18.0
  _panel.offset_top = 18.0
  _panel.offset_bottom = -18.0
  _panel.add_theme_stylebox_override('panel', _panel_style())
  _panel.visible = false
  add_child(_panel)

  var outer := MarginContainer.new()
  outer.add_theme_constant_override('margin_left', 18)
  outer.add_theme_constant_override('margin_right', 18)
  outer.add_theme_constant_override('margin_top', 16)
  outer.add_theme_constant_override('margin_bottom', 16)
  _panel.add_child(outer)
  var column := VBoxContainer.new()
  column.add_theme_constant_override('separation', 10)
  outer.add_child(column)

  var header := HBoxContainer.new()
  header.add_theme_constant_override('separation', 10)
  column.add_child(header)
  var emblem := TextureRect.new()
  emblem.custom_minimum_size = Vector2(54.0, 54.0)
  emblem.texture = ArtCatalog.UI_TEXTURES['buttonCrest']
  emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
  header.add_child(emblem)
  var title_column := VBoxContainer.new()
  title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  title_column.add_theme_constant_override('separation', 0)
  header.add_child(title_column)
  var title := Label.new()
  title.text = '灵枢调试台'
  title.add_theme_font_size_override('font_size', 24)
  title.add_theme_color_override('font_color', CORAL)
  title_column.add_child(title)
  var subtitle := Label.new()
  subtitle.text = '实时修改战斗参数 · F2 / Esc 关闭'
  subtitle.add_theme_font_size_override('font_size', 12)
  subtitle.add_theme_color_override('font_color', INK.lightened(0.18))
  title_column.add_child(subtitle)
  var close := Button.new()
  close.text = '关闭'
  close.custom_minimum_size = Vector2(72.0, 38.0)
  _style_button(close)
  close.pressed.connect(toggle)
  header.add_child(close)

  var status_panel := PanelContainer.new()
  status_panel.add_theme_stylebox_override('panel', _status_style())
  column.add_child(status_panel)
  var status_margin := MarginContainer.new()
  status_margin.add_theme_constant_override('margin_left', 12)
  status_margin.add_theme_constant_override('margin_right', 12)
  status_margin.add_theme_constant_override('margin_top', 9)
  status_margin.add_theme_constant_override('margin_bottom', 9)
  status_panel.add_child(status_margin)
  var stats := Label.new()
  stats.custom_minimum_size.y = 42.0
  stats.add_theme_color_override('font_color', INK)
  stats.add_theme_font_size_override('font_size', 13)
  status_margin.add_child(stats)
  controls['stats'] = stats

  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  column.add_child(scroll)
  var content_margin := MarginContainer.new()
  content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  content_margin.add_theme_constant_override('margin_right', 8)
  scroll.add_child(content_margin)
  var content := VBoxContainer.new()
  content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  content.add_theme_constant_override('separation', 8)
  content_margin.add_child(content)

  _add_section(content, '游戏控制')
  controls['paused'] = _add_check(content, '暂停世界', Callable(self, '_paused_toggled'))
  controls['invincible'] = _add_check(content, '玩家无敌', Callable(self, '_invincible_toggled'))
  controls['hp'] = _add_number(content, '当前生命', 0.0, 1000000.0, 1.0, Callable(self, '_hp_changed'))
  _add_section(content, '玩家倍率')
  controls['damage'] = _add_number(content, '伤害', 0.0, 1000.0, 0.1, _player_setting.bind('damageMult'))
  controls['xp'] = _add_number(content, '经验', 0.0, 1000.0, 0.1, _player_setting.bind('xpMult'))
  controls['speed'] = _add_number(content, '移速', 0.0, 100.0, 0.1, _player_setting.bind('moveSpeedMult'))
  controls['max_hp'] = _add_number(content, '最大生命', 0.01, 1000.0, 0.1, _player_setting.bind('maxHpMult'))
  controls['pickup'] = _add_number(content, '拾取范围', 0.0, 1000.0, 0.1, _player_setting.bind('pickupRangeMult'))
  controls['armor'] = _add_number(content, '护甲加成', 0.0, 1000000.0, 5.0, _player_setting.bind('armorBonus'))
  _add_section(content, '敌人与刷怪')
  controls['enemy_hp'] = _add_number(content, '敌人生命', 0.01, 1000.0, 0.1, _enemy_setting.bind('hpMult'))
  controls['enemy_damage'] = _add_number(content, '敌人伤害', 0.0, 1000.0, 0.1, _enemy_setting.bind('damageMult'))
  controls['enemy_speed'] = _add_number(content, '敌人速度', 0.0, 1000.0, 0.1, _enemy_setting.bind('speedMult'))
  controls['wave'] = _add_number(content, '跳转波次', 1.0, Config.CONFIG['waves']['maxWave'], 1.0, Callable(self, '_wave_changed'))
  controls['quota'] = _add_number(content, '波次数量倍率', 0.0, 1000.0, 0.1, _spawn_setting.bind('quotaMult'))
  controls['alive_cap'] = _add_number(content, '同屏上限（0默认）', 0.0, 10000.0, 1.0, _alive_cap_changed)
  controls['interval'] = _add_number(content, '刷新间隔倍率', 0.01, 1000.0, 0.05, _spawn_setting.bind('intervalMult'))
  controls['spawn_paused'] = _add_check(content, '暂停自动刷怪', Callable(self, '_spawn_paused_toggled'))

  var spawn_row := HBoxContainer.new()
  spawn_row.add_theme_constant_override('separation', 6)
  content.add_child(spawn_row)
  _enemy_type = OptionButton.new()
  _enemy_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  for type: String in Config.CONFIG['enemyTypes']:
    _enemy_type.add_item(type)
  _enemy_type.custom_minimum_size.y = 40.0
  _style_button(_enemy_type)
  spawn_row.add_child(_enemy_type)
  _enemy_count = SpinBox.new()
  _enemy_count.min_value = 1
  _enemy_count.max_value = 200
  _enemy_count.value = 1
  _enemy_count.custom_minimum_size = Vector2(84.0, 40.0)
  _style_spin_box(_enemy_count)
  spawn_row.add_child(_enemy_count)
  var spawn_button := Button.new()
  spawn_button.text = '生成'
  _style_button(spawn_button)
  spawn_button.pressed.connect(_spawn_selected)
  spawn_row.add_child(spawn_button)
  var clear_button := Button.new()
  clear_button.text = '清场'
  _style_button(clear_button)
  clear_button.pressed.connect(_clear_enemies)
  spawn_row.add_child(clear_button)

  _add_section(content, '武器等级（0移除）')
  for card: Dictionary in WeaponFactoryScript.WEAPON_CARDS:
    weapon_controls[card['id']] = _add_number(content, card['name'], 0.0, card['maxLevel'], 1.0, _weapon_level.bind(card['id']))
  _add_section(content, '局外资源')
  var crystal_row := HBoxContainer.new()
  crystal_row.add_theme_constant_override('separation', 6)
  content.add_child(crystal_row)
  _crystal_label = Label.new()
  _crystal_label.text = '暗晶 0'
  _crystal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _crystal_label.add_theme_color_override('font_color', INK)
  _crystal_label.add_theme_font_size_override('font_size', 13)
  crystal_row.add_child(_crystal_label)
  _crystal_amount = SpinBox.new()
  _crystal_amount.min_value = 0
  _crystal_amount.max_value = 1000000
  _crystal_amount.step = 100
  _crystal_amount.value = 500
  _crystal_amount.custom_minimum_size = Vector2(120.0, 38.0)
  _style_spin_box(_crystal_amount)
  crystal_row.add_child(_crystal_amount)
  var grant_button := Button.new()
  grant_button.text = '发放'
  _style_button(grant_button)
  grant_button.pressed.connect(_grant_crystals)
  crystal_row.add_child(grant_button)

  _add_section(content, '配置')
  var buttons := HBoxContainer.new()
  buttons.add_theme_constant_override('separation', 6)
  content.add_child(buttons)
  for data: Array in [['恢复默认', Callable(self, '_reset_defaults')], ['保存', Callable(self, '_save_settings')], ['载入', Callable(self, '_load_settings')]]:
    var button := Button.new()
    button.text = data[0]
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _style_button(button)
    button.pressed.connect(data[1])
    buttons.add_child(button)


func _add_section(parent: VBoxContainer, text: String) -> void:
  var row := HBoxContainer.new()
  row.add_theme_constant_override('separation', 8)
  parent.add_child(row)
  var label := Label.new()
  label.text = text
  label.add_theme_font_size_override('font_size', 16)
  label.add_theme_color_override('font_color', CORAL)
  row.add_child(label)
  var divider := TextureRect.new()
  divider.texture = ArtCatalog.UI_TEXTURES['divider']
  divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  divider.custom_minimum_size.y = 22.0
  divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  divider.modulate = Color(1.0, 1.0, 1.0, 0.44)
  divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(divider)


func _add_check(parent: VBoxContainer, label: String, callback: Callable) -> CheckButton:
  var control := CheckButton.new()
  control.text = label
  control.add_theme_font_size_override('font_size', 14)
  control.add_theme_color_override('font_color', INK)
  control.add_theme_color_override('font_hover_color', JADE)
  control.add_theme_color_override('font_pressed_color', DEEP_TEAL)
  control.toggled.connect(callback)
  parent.add_child(control)
  return control


func _add_number(parent: VBoxContainer, label: String, minimum: float, maximum: float, step: float, callback: Callable) -> SpinBox:
  var row := HBoxContainer.new()
  row.add_theme_constant_override('separation', 8)
  parent.add_child(row)
  var text := Label.new()
  text.text = label
  text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  text.add_theme_color_override('font_color', INK)
  text.add_theme_font_size_override('font_size', 13)
  row.add_child(text)
  var control := SpinBox.new()
  control.min_value = minimum
  control.max_value = maximum
  control.step = step
  control.custom_minimum_size = Vector2(140.0, 38.0)
  _style_spin_box(control)
  control.value_changed.connect(callback)
  row.add_child(control)
  return control


func _on_dimmer_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
    set_open(false)


func _paused_toggled(value: bool) -> void:
  if not _updating and run != null:
    _pause_changed_by_user = true
    run.debug.set_paused(value)


func _invincible_toggled(value: bool) -> void:
  if not _updating and run != null:
    run.debug.set_invincible(value)


func _spawn_paused_toggled(value: bool) -> void:
  if not _updating and run != null:
    run.debug.set_spawn_settings({'paused': value})


func _hp_changed(value: float) -> void:
  if not _updating and run != null:
    run.debug.set_player_hp(value)


func _wave_changed(value: float) -> void:
  if not _updating and run != null:
    run.debug.set_wave(value)


func _grant_crystals() -> void:
  if run == null:
    return
  run.debug.grant_dark_crystals(_crystal_amount.value)
  refresh()


func _clear_enemies() -> void:
  if run != null:
    run.debug.clear_enemies()


func _player_setting(value: float, key: String) -> void:
  if not _updating and run != null:
    run.debug.set_player_settings({key: value})


func _enemy_setting(value: float, key: String) -> void:
  if not _updating and run != null:
    run.debug.set_enemy_multipliers({key: value})


func _spawn_setting(value: float, key: String) -> void:
  if not _updating and run != null:
    run.debug.set_spawn_settings({key: value})


func _alive_cap_changed(value: float) -> void:
  if not _updating and run != null:
    var alive_cap: Variant = null
    if value > 0.0:
      alive_cap = floori(value)
    run.debug.set_spawn_settings({'aliveCap': alive_cap})


func _weapon_level(value: float, id: String) -> void:
  if not _updating and run != null:
    run.debug.set_weapon_level(id, value)


func _spawn_selected() -> void:
  if run != null:
    run.debug.spawn_enemies(_enemy_type.get_item_text(_enemy_type.selected), floori(_enemy_count.value))


func _reset_defaults() -> void:
  if run == null:
    return
  run.debug.reset_defaults()
  _pause_changed_by_user = true
  refresh()


func _save_settings() -> void:
  if run == null:
    return
  var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
  if file != null:
    file.store_string(JSON.stringify(run.debug.serialize()))


func _load_settings() -> void:
  if run == null or not FileAccess.file_exists(SAVE_PATH):
    return
  var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
  if file != null:
    run.debug.apply_serialized(file.get_as_text())
    _pause_changed_by_user = true
    refresh()


func _alive_count() -> int:
  var count: int = 0
  for enemy in run.enemies:
    if not enemy.dead:
      count += 1
  return count


func _format_time(value: float) -> String:
  var seconds: int = maxi(0, floori(value))
  return '%02d:%02d' % [floori(float(seconds) / 60.0), seconds % 60]


func _panel_style() -> StyleBoxFlat:
  var style := StyleBoxFlat.new()
  style.bg_color = CREAM
  style.border_color = INK
  style.set_border_width_all(3)
  style.set_corner_radius_all(28)
  style.shadow_color = Color(0.035, 0.18, 0.16, 0.42)
  style.shadow_size = 18
  style.shadow_offset = Vector2(0.0, 8.0)
  return style


func _status_style() -> StyleBoxFlat:
  var style := StyleBoxFlat.new()
  style.bg_color = Color('d8fff0')
  style.border_color = JADE
  style.set_border_width_all(2)
  style.set_corner_radius_all(18)
  return style


func _field_style(focused: bool = false) -> StyleBoxFlat:
  var style := StyleBoxFlat.new()
  style.bg_color = Color('fffdf4')
  style.border_color = CORAL if focused else INK
  style.set_border_width_all(2)
  style.set_corner_radius_all(12)
  style.content_margin_left = 10.0
  style.content_margin_right = 10.0
  style.content_margin_top = 7.0
  style.content_margin_bottom = 7.0
  return style


func _style_spin_box(control: SpinBox) -> void:
  var line_edit := control.get_line_edit()
  line_edit.add_theme_stylebox_override('normal', _field_style())
  line_edit.add_theme_stylebox_override('focus', _field_style(true))
  line_edit.add_theme_stylebox_override('read_only', _field_style())
  line_edit.add_theme_color_override('font_color', INK)
  line_edit.add_theme_color_override('caret_color', CORAL)
  line_edit.add_theme_color_override('selection_color', Color(0.47, 0.84, 0.70, 0.42))
  line_edit.add_theme_font_size_override('font_size', 13)


func _style_button(button: Button, prominent: bool = false) -> void:
  var normal := StyleBoxFlat.new()
  normal.bg_color = MINT if prominent else Color('fffdf4')
  normal.border_color = INK
  normal.set_border_width_all(3 if prominent else 2)
  normal.set_corner_radius_all(18 if prominent else 14)
  normal.content_margin_left = 12.0
  normal.content_margin_right = 12.0
  normal.content_margin_top = 7.0
  normal.content_margin_bottom = 7.0
  if prominent:
    normal.shadow_color = Color(0.035, 0.18, 0.16, 0.30)
    normal.shadow_size = 6
    normal.shadow_offset = Vector2(0.0, 3.0)
  var hover: StyleBoxFlat = normal.duplicate()
  hover.bg_color = HONEY
  hover.border_color = INK
  var pressed: StyleBoxFlat = normal.duplicate()
  pressed.bg_color = CORAL
  pressed.border_color = INK
  var disabled: StyleBoxFlat = normal.duplicate()
  disabled.bg_color = Color('e8e1d1')
  disabled.border_color = INK.lightened(0.38)
  button.add_theme_stylebox_override('normal', normal)
  button.add_theme_stylebox_override('hover', hover)
  button.add_theme_stylebox_override('pressed', pressed)
  button.add_theme_stylebox_override('focus', hover)
  button.add_theme_stylebox_override('disabled', disabled)
  button.add_theme_color_override('font_color', INK)
  button.add_theme_color_override('font_hover_color', INK)
  button.add_theme_color_override('font_pressed_color', CREAM)
  button.add_theme_color_override('font_disabled_color', INK.lightened(0.38))
