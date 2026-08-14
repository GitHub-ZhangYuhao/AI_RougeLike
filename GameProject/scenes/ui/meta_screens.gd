extends Control
## M5 Meta UI；宿主显式 bind_run，正式挂载于 main.tscn 的独立 CanvasLayer。

const ShopScript: GDScript = preload("res://logic/meta/shop.gd")
const ItemsScript: GDScript = preload("res://logic/meta/items.gd")
const ArtCatalog: GDScript = preload("res://scenes/art_catalog.gd")
const UI_FONT: Font = preload("res://assets/fonts/noto_sans_sc.ttf")

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
var _button_styles: Dictionary = {}

const INK: Color = Color('4b2f2a')
const INK_SOFT: Color = Color('72524a')
const CREAM: Color = Color('fff6de')
const CREAM_DEEP: Color = Color('f3deae')
const CORAL: Color = Color('ff6b5f')
const CORAL_DARK: Color = Color('b73f3b')
const MINT: Color = Color('78d6b2')
const JADE: Color = Color('2a8f76')
const HONEY: Color = Color('ffc65c')
const PLUM: Color = Color('6e3f68')

@onready var dim: ColorRect = %Dim
@onready var panel: PanelContainer = %Panel
@onready var header_card: PanelContainer = %HeaderCard
@onready var currency_card: PanelContainer = %CurrencyCard
@onready var screen_medallion: TextureRect = %ScreenMedallion
@onready var divider: TextureRect = %Divider
@onready var kicker_label: Label = %Kicker
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var currency_hint: Label = %CurrencyHint
@onready var currency_label: Label = %Currency
@onready var dynamic_rows: VBoxContainer = %DynamicRows
@onready var menu_buttons: HBoxContainer = %MenuButtons
@onready var action_buttons: HBoxContainer = %ActionButtons
@onready var footer_label: Label = %Footer


func _ready() -> void:
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
	currency_label.text = "◆  %d" % run.save.get("darkCrystals", 0)
	screen_medallion.visible = true

	menu_buttons.visible = state == "menu"
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
	stats_label.add_theme_color_override("font_color", INK)
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
	card.custom_minimum_size = Vector2(270.0, 116.0)
	card.add_theme_stylebox_override("panel", _menu_feature_style(fill, accent))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(66.0, 66.0)
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_rect)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 4)
	content.add_child(copy)
	var feature_title := Label.new()
	feature_title.text = title
	feature_title.add_theme_color_override("font_color", accent)
	feature_title.add_theme_color_override("font_outline_color", CREAM)
	feature_title.add_theme_constant_override("outline_size", 1)
	feature_title.add_theme_font_size_override("font_size", 19)
	copy.add_child(feature_title)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", INK)
	detail_label.add_theme_font_size_override("font_size", 12)
	copy.add_child(detail_label)
	return card


func _menu_feature_style(fill: Color, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.17, 0.10, 0.08, 0.2)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 5.0)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _stats_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color('d8fff0')
	style.border_color = JADE
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.03, 0.18, 0.15, 0.16)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _make_row(name: String, detail: String, action_text: String, enabled: bool, action: Callable, icon: Texture2D = null) -> PanelContainer:
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
	name_label.text = name
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
	_apply_button_style(button)
	button.pressed.connect(action)
	line.add_child(button)
	return row


func _clear_rows() -> void:
	for child in dynamic_rows.get_children():
		child.free()


func _apply_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	theme = ui_theme
	dim.color = Color(0.035, 0.13, 0.13, 0.72)
	divider.texture = ArtCatalog.UI_TEXTURES["divider"]
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = CREAM
	panel_style.border_color = INK
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(32)
	panel_style.shadow_color = Color(0.03, 0.13, 0.13, 0.48)
	panel_style.shadow_size = 20
	panel_style.shadow_offset = Vector2(0.0, 10.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color('ffe8c1')
	header_style.border_color = INK
	header_style.set_border_width_all(3)
	header_style.set_corner_radius_all(24)
	header_style.shadow_color = Color(0.17, 0.10, 0.08, 0.16)
	header_style.shadow_size = 6
	header_style.shadow_offset = Vector2(0.0, 4.0)
	header_card.add_theme_stylebox_override("panel", header_style)
	var currency_style := StyleBoxFlat.new()
	currency_style.bg_color = Color('d8fff0')
	currency_style.border_color = JADE
	currency_style.set_border_width_all(3)
	currency_style.set_corner_radius_all(22)
	currency_card.add_theme_stylebox_override("panel", currency_style)
	_button_styles = _create_button_styles()
	%StartButton.icon = ArtCatalog.UI_TEXTURES["buttonCrest"]
	%ShopButton.icon = ArtCatalog.UI_TEXTURES["shop"]
	%StorageButton.icon = ArtCatalog.UI_TEXTURES["warehouse"]
	%SellAllButton.icon = ArtCatalog.PICKUP_TEXTURES["gem"]
	%BackButton.icon = ArtCatalog.UI_TEXTURES["buttonCrest"]
	for button: Button in [%StartButton, %ShopButton, %StorageButton, %SellAllButton, %BackButton]:
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		_apply_button_style(button, button == %StartButton)
	kicker_label.add_theme_color_override("font_color", CORAL_DARK)
	title_label.add_theme_color_override("font_color", INK)
	title_label.add_theme_color_override("font_outline_color", Color(CREAM, 0.96))
	title_label.add_theme_constant_override("outline_size", 2)
	subtitle_label.add_theme_color_override("font_color", INK)
	currency_hint.add_theme_color_override("font_color", JADE)
	currency_label.add_theme_color_override("font_color", JADE)
	footer_label.add_theme_color_override("font_color", INK_SOFT)


func _create_button_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color('fff0c8')
	normal.border_color = INK
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(20)
	normal.shadow_color = Color(0.17, 0.10, 0.08, 0.2)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0.0, 4.0)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = HONEY
	hover.border_color = CORAL_DARK
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = Color('f5aa45')
	pressed.shadow_size = 1
	var focus: StyleBoxFlat = hover.duplicate()
	focus.shadow_color = Color(CORAL, 0.4)
	focus.shadow_size = 8
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color('ded8c7')
	disabled.border_color = Color(INK, 0.45)
	return {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus, "disabled": disabled}


func _apply_button_style(button: Button, prominent: bool = false) -> void:
	for state: String in _button_styles:
		var style: StyleBoxFlat = _button_styles[state].duplicate()
		if prominent and state != "disabled":
			style.bg_color = CORAL if state == "normal" else (Color('ff8b70') if state == "hover" or state == "focus" else CORAL_DARK)
			style.border_color = INK
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", CREAM if prominent else INK)
	button.add_theme_color_override("font_hover_color", CREAM if prominent else CORAL_DARK)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM if prominent else CORAL_DARK)
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1.0, 1.0, 1.0, 0.42))
	button.add_theme_color_override("font_disabled_color", Color(INK, 0.46))
	button.add_theme_font_size_override("font_size", 17 if prominent else 16)


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color('fff0cf')
	style.border_color = Color(INK, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.17, 0.10, 0.08, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 3.0)
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
