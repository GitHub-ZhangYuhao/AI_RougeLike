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

@onready var panel: PanelContainer = %Panel
@onready var title_emblem: TextureRect = %TitleEmblem
@onready var screen_medallion: TextureRect = %ScreenMedallion
@onready var divider: TextureRect = %Divider
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
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
	currency_label.text = "暗晶  %d" % run.save.get("darkCrystals", 0)
	title_emblem.visible = state == "menu"
	screen_medallion.visible = state != "menu"
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
	title_label.visible = false
	screen_medallion.texture = ArtCatalog.UI_TEXTURES["buttonCrest"]
	subtitle_label.text = "桃林异变，百鬼夜行 · 守住灵台，择机撤离"
	var stats: Dictionary = run.save.get("stats", {})
	var stats_label := Label.new()
	stats_label.text = "累计 %d 局   撤离 %d 次   通关 %d 次   最佳波数 %d" % [stats.get("runs", 0), stats.get("extractions", 0), stats.get("completions", 0), stats.get("bestWave", 0)]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", Color("b8c8b3"))
	stats_label.add_theme_font_size_override("font_size", 14)
	dynamic_rows.add_child(stats_label)
	var features := HBoxContainer.new()
	features.alignment = BoxContainer.ALIGNMENT_CENTER
	features.add_theme_constant_override("separation", 12)
	features.add_child(_make_menu_feature("择械入夜", "六种法器任选其一，逐级构筑流派", ArtCatalog.UI_TEXTURES["sealWeapon"]))
	features.add_child(_make_menu_feature("镇守灵台", "完成随机任务，迎战精英与首领", ArtCatalog.UI_TEXTURES["sealTask"]))
	features.add_child(_make_menu_feature("择机撤离", "带回稀有材料，强化下一次轮回", ArtCatalog.UI_TEXTURES["warehouse"]))
	dynamic_rows.add_child(features)
	footer_label.text = "Enter / Space 快速开始   ·   WASD / 方向键移动"


func _build_shop() -> void:
	title_label.visible = true
	screen_medallion.texture = ArtCatalog.UI_TEXTURES["shop"]
	title_label.text = "山门商肆 · 永久修行"
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
	title_label.text = "行囊仓库 · 撤离所得"
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


func _make_menu_feature(title: String, detail: String, icon: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(205.0, 92.0)
	card.add_theme_stylebox_override("panel", _menu_feature_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(42.0, 42.0)
	icon_rect.texture = icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon_rect)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	content.add_child(copy)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color("f2d28b"))
	title_label.add_theme_font_size_override("font_size", 16)
	copy.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", Color("c8d1c4"))
	detail_label.add_theme_font_size_override("font_size", 12)
	copy.add_child(detail_label)
	return card


func _menu_feature_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.085, 0.92)
	style.border_color = Color(0.55, 0.47, 0.25, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	return style


func _make_row(name: String, detail: String, action_text: String, enabled: bool, action: Callable, icon: Texture2D = null) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 52.0)
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
	name_label.add_theme_color_override("font_color", Color("f2d28b"))
	name_label.add_theme_font_size_override("font_size", 18)
	line.add_child(name_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.add_theme_color_override("font_color", Color("c8d1c4"))
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
	divider.texture = ArtCatalog.UI_TEXTURES["divider"]
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.075, 0.064, 0.96)
	panel_style.border_color = Color("b99b52")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	_button_styles = _create_button_styles()
	%StartButton.icon = ArtCatalog.UI_TEXTURES["buttonCrest"]
	%ShopButton.icon = ArtCatalog.UI_TEXTURES["shop"]
	%StorageButton.icon = ArtCatalog.UI_TEXTURES["warehouse"]
	%SellAllButton.icon = ArtCatalog.PICKUP_TEXTURES["gem"]
	%BackButton.icon = ArtCatalog.UI_TEXTURES["buttonCrest"]
	for button: Button in [%StartButton, %ShopButton, %StorageButton, %SellAllButton, %BackButton]:
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		_apply_button_style(button)
	for label: Label in [title_label, subtitle_label, currency_label, footer_label]:
		label.add_theme_color_override("font_color", Color("e8eadb"))
	currency_label.add_theme_color_override("font_color", Color("d7b5f5"))
	subtitle_label.add_theme_color_override("font_color", Color("b8c8b3"))
	footer_label.add_theme_color_override("font_color", Color("8fa091"))


func _create_button_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.15, 0.12, 0.96)
	normal.border_color = Color("7f9364")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.13, 0.24, 0.18, 0.98)
	hover.border_color = Color("e0bf6c")
	hover.set_border_width_all(2)
	var pressed: StyleBoxFlat = hover.duplicate()
	pressed.bg_color = Color(0.18, 0.29, 0.20, 1.0)
	var focus: StyleBoxFlat = hover.duplicate()
	focus.bg_color = Color(0.11, 0.2, 0.15, 0.98)
	focus.shadow_color = Color(0.88, 0.75, 0.42, 0.35)
	focus.shadow_size = 6
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.06, 0.08, 0.07, 0.8)
	disabled.border_color = Color(0.3, 0.34, 0.3, 0.5)
	return {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus, "disabled": disabled}


func _apply_button_style(button: Button) -> void:
	for state: String in _button_styles:
		button.add_theme_stylebox_override(state, _button_styles[state])
	button.add_theme_color_override("font_color", Color("e8eadb"))
	button.add_theme_color_override("font_hover_color", Color("f2d28b"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("f2d28b"))
	button.add_theme_color_override("icon_normal_color", Color(1.0, 1.0, 1.0, 0.9))
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color("f2d28b"))
	button.add_theme_color_override("icon_disabled_color", Color(0.5, 0.55, 0.5, 0.5))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.5, 0.7))
	button.add_theme_font_size_override("font_size", 16)


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.10, 0.85)
	style.border_color = Color(0.35, 0.45, 0.34, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
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
