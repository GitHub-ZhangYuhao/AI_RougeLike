extends Control
## M5 Meta UI；宿主显式 bind_run，正式挂载于 main.tscn 的独立 CanvasLayer。

const ShopScript: GDScript = preload("res://logic/meta/shop.gd")
const ItemsScript: GDScript = preload("res://logic/meta/items.gd")
const ArtCatalog: GDScript = preload("res://scenes/art_catalog.gd")
const UI_FONT: Font = preload("res://assets/fonts/ui_font_round.tres")

const ATTR_NAMES: Dictionary = {
	"damage": "强攻",
	"armor": "护体",
	"magnet": "聚灵",
	"xp": "悟道",
	"maxHp": "固本",
	"moveSpeed": "御风",
}
const ATTR_DESCRIPTIONS: Dictionary = {
	"damage": "永久提高本局伤害倍率",
	"armor": "永久提高护甲与伤害减免",
	"magnet": "扩大经验与掉落拾取范围",
	"xp": "永久提高经验获取倍率",
	"maxHp": "永久提高最大生命",
	"moveSpeed": "永久提高移动速度",
}

signal start_requested
signal shop_requested
signal storage_requested
signal menu_requested
signal shop_purchase_requested(attr_id: String)
signal storage_sale_requested(item_id: String)
signal storage_sale_all_requested

var run = null
var _last_signature: String = ""
var _backdrop_layer: Control = null
var _reference_menu: Control = null

const INK: Color = Color('4b2f2a')
const INK_SOFT: Color = Color('72524a')
const CREAM: Color = Color('fff6de')
const CREAM_DEEP: Color = Color('f3deae')
const CORAL: Color = Color('ef624f')
const CORAL_DARK: Color = Color('9f352f')
const MINT: Color = Color('79d9b7')
const JADE: Color = Color('278f78')
const JADE_DEEP: Color = Color('155a52')
const HONEY: Color = Color('efb950')
const PLUM: Color = Color('714766')
const NIGHT: Color = Color('0d1729')
const NIGHT_SOFT: Color = Color('172944')
const NIGHT_MID: Color = Color('203a55')
const WALNUT: Color = Color('4a2c24')
const ANTIQUE_GOLD: Color = Color('b57b36')
const SPIRIT_GLOW: Color = Color('79e1bd')

@onready var dim: ColorRect = %Dim
@onready var panel: PanelContainer = %Panel
@onready var header_card: PanelContainer = %HeaderCard
@onready var currency_card: PanelContainer = %CurrencyCard
@onready var screen_medallion: TextureRect = %ScreenMedallion
@onready var divider: TextureRect = %Divider
@onready var kicker_label: Label = %Kicker
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var currency_icon: TextureRect = %CurrencyIcon
@onready var currency_amount: Label = %CurrencyAmount
@onready var dynamic_rows: VBoxContainer = %DynamicRows
@onready var menu_buttons: HBoxContainer = %MenuButtons
@onready var action_buttons: HBoxContainer = %ActionButtons
@onready var footer_label: Label = %Footer


func _ready() -> void:
	_build_reference_menu()
	_build_backdrop_decor()
	_apply_theme()
	%StartButton.pressed.connect(_on_start_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%StorageButton.pressed.connect(_on_storage_pressed)
	%BackButton.pressed.connect(_on_back_pressed)
	%SellAllButton.pressed.connect(_on_sell_all_pressed)
	refresh(true)


func bind_run(game_run) -> void:
	run = game_run
	_last_signature = ""
	refresh(true)


func unbind_run() -> void:
	run = null
	_last_signature = ""
	refresh(true)


func refresh(force: bool = false) -> void:
	if not is_node_ready():
		return
	var state: String = str(run.state) if run != null else ""
	var should_show: bool = state == "menu" or state == "shop" or state == "storage"
	visible = should_show
	mouse_filter = Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
	if not should_show:
		_last_signature = state
		return
	var signature := "%s|%s|%s|%s|%s" % [state, run.save.get("darkCrystals", 0), str(run.save.get("metaLevels", {})), str(run.save.get("storage", {})), str(run.save.get("stats", {}))]
	if not force and signature == _last_signature:
		return
	_last_signature = signature
	_clear_rows()
	currency_icon.texture = ArtCatalog.PICKUP_TEXTURES["gem"]
	currency_amount.text = "%d" % run.save.get("darkCrystals", 0)
	if _reference_menu != null:
		_reference_menu.set_currency(int(run.save.get("darkCrystals", 0)))
	screen_medallion.visible = true

	var is_menu: bool = state == "menu"
	if _reference_menu != null:
		_reference_menu.visible = is_menu
	panel.visible = not is_menu
	dim.visible = not is_menu
	if _backdrop_layer != null:
		_backdrop_layer.visible = not is_menu
	menu_buttons.visible = is_menu
	action_buttons.visible = state != "menu"
	%SellAllButton.visible = state == "storage"
	match state:
		"menu": _build_menu()
		"shop": _build_shop()
		"storage": _build_storage()


func request_purchase(attr_id: String) -> bool:
	shop_purchase_requested.emit(attr_id)
	var result: bool = run != null and run.buy_shop_item(attr_id)
	_last_signature = ""
	refresh(true)
	return result


func request_sell(item_id: String) -> int:
	storage_sale_requested.emit(item_id)
	var gained: int = run.sell_storage_item(item_id) if run != null else 0
	_last_signature = ""
	refresh(true)
	return gained


func request_sell_all() -> int:
	storage_sale_all_requested.emit()
	var gained: int = run.sell_all_storage() if run != null else 0
	_last_signature = ""
	refresh(true)
	return gained


func _build_menu() -> void:
	title_label.visible = true
	screen_medallion.texture = ArtCatalog.UI_TEXTURES["brandMascot"]
	kicker_label.text = "桃源守夜 · 轻松构筑"
	title_label.text = "暗夜幸存者"
	subtitle_label.text = "桃林异变，百鬼夜行 · 守住灵台，择机撤离"
	var stats: Dictionary = run.save.get("stats", {})
	var stats_panel := PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(610.0, 42.0)
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_panel.add_theme_stylebox_override("panel", _stats_pill_style())
	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 18)
	stats_margin.add_theme_constant_override("margin_right", 18)
	stats_margin.add_theme_constant_override("margin_top", 7)
	stats_margin.add_theme_constant_override("margin_bottom", 7)
	stats_panel.add_child(stats_margin)
	var stats_label := Label.new()
	stats_label.text = "桃源战绩   ·   累计 %d 局   ·   撤离 %d 次   ·   通关 %d 次   ·   最佳波数 %d" % [stats.get("runs", 0), stats.get("extractions", 0), stats.get("completions", 0), stats.get("bestWave", 0)]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", CREAM_DEEP)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_margin.add_child(stats_label)
	dynamic_rows.add_child(stats_panel)
	var features := HBoxContainer.new()
	features.alignment = BoxContainer.ALIGNMENT_CENTER
	features.add_theme_constant_override("separation", 14)
	features.add_child(_make_menu_feature("择械入夜", "六种法器自由搭配，逐级构筑专属流派", ArtCatalog.UI_TEXTURES["sealWeapon"], Color("ffe1db"), CORAL_DARK))
	features.add_child(_make_menu_feature("镇守灵台", "完成奇遇任务，迎战精英与暗夜首领", ArtCatalog.UI_TEXTURES["sealTask"], Color("dcf8ec"), JADE))
	features.add_child(_make_menu_feature("满载而归", "带回稀有材料，强化下一次桃源轮回", ArtCatalog.UI_TEXTURES["warehouse"], Color("fff0c6"), Color("9a6719")))
	dynamic_rows.add_child(features)
	footer_label.text = "Enter / Space 快速开始   ·   WASD / 方向键移动"


func _build_shop() -> void:
	title_label.visible = true
	screen_medallion.texture = ArtCatalog.UI_TEXTURES["shop"]
	kicker_label.text = "桃源补给 · 永久成长"
	title_label.text = "山门商肆"
	subtitle_label.text = "消耗暗晶强化每次轮回的基础能力"
	var max_level: int = ShopScript.shop_max_level()
	for attr_id: String in ShopScript.SHOP_ATTRS:
		var level: int = run.save["metaLevels"].get(attr_id, 0)
		var maxed: bool = level >= max_level
		var price: int = 0 if maxed else ShopScript.price_for_level(level + 1)
		var enabled: bool = ShopScript.can_buy(run.save, attr_id)
		var detail := "%s   Lv %d/%d   %s" % [ATTR_DESCRIPTIONS[attr_id], level, max_level, "MAX" if maxed else "需暗晶 %d" % price]
		var action := Callable(self, "request_purchase").bind(attr_id)
		dynamic_rows.add_child(_make_row(ATTR_NAMES[attr_id], detail, "已圆满" if maxed else "修行", enabled, action, ArtCatalog.UI_TEXTURES["sealAttribute"]))
	footer_label.text = "永久属性会在下一局开始时自动生效   ·   Esc 返回"


func _build_storage() -> void:
	title_label.visible = true
	screen_medallion.texture = ArtCatalog.UI_TEXTURES["warehouse"]
	kicker_label.text = "行囊整理 · 撤离所得"
	title_label.text = "行囊仓库"
	subtitle_label.text = "出售入库材料以换取暗晶"
	var has_items: bool = false
	for item: Dictionary in ItemsScript.META_ITEM_LIST:
		var count: int = run.save["storage"].get(item["id"], 0)
		has_items = has_items or count > 0
		var detail := "持有 %d   单价 %d 暗晶   总值 %d" % [count, item["sellPrice"], count * item["sellPrice"]]
		var action := Callable(self, "request_sell").bind(item["id"])
		dynamic_rows.add_child(_make_row(item["name"], detail, "出售", count > 0, action, ArtCatalog.PICKUP_TEXTURES["gem"]))
	%SellAllButton.disabled = not has_items
	footer_label.text = "死亡会失去临时背包，成功撤离才会存入仓库   ·   Esc 返回"


func _make_menu_feature(title: String, detail: String, icon: Texture2D, fill: Color, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(270.0, 188.0)
	card.add_theme_stylebox_override("panel", _menu_feature_style(fill, accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(104.0, 86.0)
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_frame.add_theme_stylebox_override("panel", _feature_icon_style(accent))
	content.add_child(icon_frame)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(88.0, 74.0)
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_rect)
	var title_ribbon := PanelContainer.new()
	title_ribbon.custom_minimum_size = Vector2(150.0, 34.0)
	title_ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_ribbon.add_theme_stylebox_override("panel", _feature_ribbon_style(accent))
	content.add_child(title_ribbon)
	var feature_title := Label.new()
	feature_title.text = title
	feature_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feature_title.add_theme_color_override("font_color", CREAM)
	feature_title.add_theme_font_size_override("font_size", 18)
	title_ribbon.add_child(feature_title)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.custom_minimum_size = Vector2(226.0, 36.0)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", INK)
	detail_label.add_theme_font_size_override("font_size", 12)
	content.add_child(detail_label)
	return card


func _menu_feature_style(fill: Color, _accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill.lightened(0.08)
	style.border_color = WALNUT
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.01, 0.03, 0.08, 0.48)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 7.0)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _feature_icon_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.16)
	style.border_color = Color(accent, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(accent, 0.20)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _feature_ribbon_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.12)
	style.border_color = WALNUT
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.10, 0.04, 0.03, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _stats_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(NIGHT_MID, 0.92)
	style.border_color = Color(ANTIQUE_GOLD, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.01, 0.03, 0.08, 0.34)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _make_row(feature_name: String, detail: String, action_text: String, enabled: bool, action: Callable, icon: Texture2D = null) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 58.0)
	row.add_theme_stylebox_override("panel", _row_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	margin.add_child(line)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(38.0, 38.0)
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon_rect)
	var name_label := Label.new()
	name_label.custom_minimum_size.x = 90.0
	name_label.text = feature_name
	name_label.add_theme_color_override("font_color", CORAL_DARK)
	name_label.add_theme_font_size_override("font_size", 18)
	line.add_child(name_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.add_theme_color_override("font_color", INK_SOFT)
	detail_label.add_theme_font_size_override("font_size", 14)
	line.add_child(detail_label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(100.0, 38.0)
	button.text = action_text
	button.disabled = not enabled
	_apply_button_style(button, "jade")
	button.pressed.connect(action)
	line.add_child(button)
	return row


func _clear_rows() -> void:
	for child in dynamic_rows.get_children():
		child.free()



func _build_reference_menu() -> void:
	var script: GDScript = preload("res://scenes/ui/peach_night_menu.gd")
	_reference_menu = Control.new()
	_reference_menu.name = "PeachNightApprovedMenu"
	_reference_menu.set_script(script)
	add_child(_reference_menu)
	move_child(_reference_menu, get_child_count() - 1)
	_reference_menu.start_pressed.connect(_on_start_pressed)
	_reference_menu.shop_pressed.connect(_on_shop_pressed)
	_reference_menu.storage_pressed.connect(_on_storage_pressed)
func _build_backdrop_decor() -> void:
	_backdrop_layer = Control.new()
	_backdrop_layer.name = "NightBackdropDecor"
	_backdrop_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop_layer)
	move_child(_backdrop_layer, dim.get_index() + 1)
	_add_backdrop_texture(ArtCatalog.ENVIRONMENT_TEXTURES["peachTreeLarge"], Rect2(-74.0, 238.0, 380.0, 430.0), Color(0.36, 0.48, 0.58, 0.58))
	_add_backdrop_texture(ArtCatalog.ENVIRONMENT_TEXTURES["peachTreeMedium"], Rect2(1002.0, 256.0, 340.0, 390.0), Color(0.34, 0.46, 0.56, 0.56))
	_add_backdrop_texture(ArtCatalog.ENVIRONMENT_TEXTURES["lanternPost"], Rect2(14.0, 378.0, 202.0, 270.0), Color(0.78, 0.64, 0.43, 0.72))
	_add_backdrop_texture(ArtCatalog.ENVIRONMENT_TEXTURES["roadsideShrine"], Rect2(1082.0, 438.0, 190.0, 210.0), Color(0.58, 0.68, 0.62, 0.68))
	_add_backdrop_texture(ArtCatalog.ENVIRONMENT_TEXTURES["fallenPetals"], Rect2(0.0, 0.0, 330.0, 230.0), Color(0.96, 0.56, 0.54, 0.38))
	_add_backdrop_texture(ArtCatalog.ENVIRONMENT_TEXTURES["fallenPetals"], Rect2(950.0, 4.0, 330.0, 230.0), Color(0.96, 0.56, 0.54, 0.34))


func _add_backdrop_texture(texture: Texture2D, rect: Rect2, tint: Color) -> void:
	var decoration := TextureRect.new()
	decoration.position = rect.position
	decoration.size = rect.size
	decoration.texture = texture
	decoration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decoration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	decoration.modulate = tint
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_layer.add_child(decoration)


func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	theme = ui_theme
	dim.color = Color(0.025, 0.055, 0.11, 0.91)
	divider.texture = ArtCatalog.UI_TEXTURES["divider"]
	divider.modulate = Color(0.92, 0.66, 0.42, 0.90)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(NIGHT, 0.98)
	panel_style.border_color = WALNUT
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(32)
	panel_style.shadow_color = Color(0.0, 0.02, 0.07, 0.78)
	panel_style.shadow_size = 24
	panel_style.shadow_offset = Vector2(0.0, 12.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = NIGHT_SOFT
	header_style.border_color = ANTIQUE_GOLD
	header_style.set_border_width_all(3)
	header_style.set_corner_radius_all(24)
	header_style.shadow_color = Color(0.0, 0.02, 0.07, 0.62)
	header_style.shadow_size = 9
	header_style.shadow_offset = Vector2(0.0, 5.0)
	header_card.add_theme_stylebox_override("panel", header_style)
	var currency_style := StyleBoxFlat.new()
	currency_style.bg_color = Color('f8ead0')
	currency_style.border_color = JADE_DEEP
	currency_style.set_border_width_all(3)
	currency_style.set_corner_radius_all(22)
	currency_style.shadow_color = Color(SPIRIT_GLOW, 0.18)
	currency_style.shadow_size = 8
	currency_style.shadow_offset = Vector2(0.0, 4.0)
	currency_card.add_theme_stylebox_override("panel", currency_style)
	%StartButton.icon = ArtCatalog.UI_TEXTURES["buttonCrest"]
	%ShopButton.icon = ArtCatalog.UI_TEXTURES["shop"]
	%StorageButton.icon = ArtCatalog.UI_TEXTURES["warehouse"]
	%SellAllButton.icon = ArtCatalog.PICKUP_TEXTURES["gem"]
	%BackButton.icon = ArtCatalog.UI_TEXTURES["buttonCrest"]
	for button: Button in [%StartButton, %ShopButton, %StorageButton, %SellAllButton, %BackButton]:
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
	_apply_button_style(%StartButton, "cinnabar")
	_apply_button_style(%ShopButton, "jade")
	_apply_button_style(%StorageButton, "paper")
	_apply_button_style(%SellAllButton, "jade")
	_apply_button_style(%BackButton, "paper")
	kicker_label.add_theme_color_override("font_color", CORAL)
	title_label.add_theme_color_override("font_color", CREAM)
	title_label.add_theme_color_override("font_outline_color", Color(WALNUT, 0.98))
	title_label.add_theme_constant_override("outline_size", 5)
	subtitle_label.add_theme_color_override("font_color", Color('d8c7a9'))
	currency_amount.add_theme_color_override("font_color", JADE_DEEP)
	footer_label.add_theme_color_override("font_color", Color('c9b99f'))


func _apply_button_style(button: Button, role: String = "paper") -> void:
	var normal_fill: Color = Color('f6e6c4')
	var hover_fill: Color = HONEY
	var pressed_fill: Color = Color('d9973d')
	var border: Color = WALNUT
	var text_color: Color = INK
	if role == "cinnabar":
		normal_fill = CORAL
		hover_fill = Color('ff8068')
		pressed_fill = CORAL_DARK
		border = Color('6d241f')
		text_color = CREAM
	elif role == "jade":
		normal_fill = JADE_DEEP
		hover_fill = JADE
		pressed_fill = Color('0f4944')
		border = Color('0a3735')
		text_color = CREAM
	var normal := _button_style_box(normal_fill, border, 7, Vector2(0.0, 5.0))
	var hover := _button_style_box(hover_fill, ANTIQUE_GOLD, 10, Vector2(0.0, 5.0))
	var pressed := _button_style_box(pressed_fill, border, 2, Vector2(0.0, 2.0))
	var focus: StyleBoxFlat = hover.duplicate()
	focus.shadow_color = Color(SPIRIT_GLOW if role == "jade" else CORAL, 0.34)
	focus.shadow_size = 12
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color('746e68')
	disabled.border_color = Color(WALNUT, 0.58)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus, "disabled": disabled}[state]
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", CREAM if role != "paper" else CORAL_DARK)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM if role != "paper" else CORAL_DARK)
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1.0, 1.0, 1.0, 0.42))
	button.add_theme_color_override("font_disabled_color", Color(CREAM, 0.48))
	button.add_theme_font_size_override("font_size", 18 if role == "cinnabar" else 16)


func _button_style_box(fill: Color, border: Color, shadow_size: int, shadow_offset: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.0, 0.02, 0.06, 0.46)
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	return style


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color('f7e7c8')
	style.border_color = WALNUT
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.02, 0.07, 0.42)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _on_start_pressed() -> void:
	start_requested.emit()
	if run != null and run.state == "menu":
		run._start_run()
	_last_signature = ""
	refresh(true)


func _on_shop_pressed() -> void:
	shop_requested.emit()
	if run != null:
		run.open_shop()
	_last_signature = ""
	refresh(true)


func _on_storage_pressed() -> void:
	storage_requested.emit()
	if run != null:
		run.open_storage()
	_last_signature = ""
	refresh(true)


func _on_back_pressed() -> void:
	menu_requested.emit()
	if run != null:
		run.back_to_menu()
	_last_signature = ""
	refresh(true)


func _on_sell_all_pressed() -> void:
	request_sell_all()


func _exit_tree() -> void:
	run = null
