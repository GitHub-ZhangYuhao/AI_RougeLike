extends Control
## Pixel-faithful interactive menu assembled from the approved B+A concept artwork.

signal start_pressed
signal shop_pressed
signal storage_pressed

const MENU_BACKGROUND: Texture2D = preload("res://assets/ui/peach_night/menu_bg_exact.png")
const SHOP_BUTTON: Texture2D = preload("res://assets/ui/peach_night/button_shop_exact.png")
const START_BUTTON: Texture2D = preload("res://assets/ui/peach_night/button_start_exact.png")
const STORAGE_BUTTON: Texture2D = preload("res://assets/ui/peach_night/button_storage_exact.png")
const UI_FONT: Font = preload("res://assets/fonts/ui_font_round.tres")

var _currency_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var background := TextureRect.new()
	background.name = "ApprovedConceptBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = MENU_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_currency_label = Label.new()
	_currency_label.name = "DynamicCrystalAmount"
	_currency_label.position = Vector2(1112.0, 72.0)
	_currency_label.size = Vector2(88.0, 62.0)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_override("font", UI_FONT)
	_currency_label.add_theme_font_size_override("font_size", 34)
	_currency_label.add_theme_color_override("font_color", Color("2f241e"))
	_currency_label.add_theme_color_override("font_outline_color", Color("f3ddb1"))
	_currency_label.add_theme_constant_override("outline_size", 2)
	_currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_currency_label)

	_add_hotspot("ShopHotspot", Rect2(102.0, 584.0, 330.0, 126.0), SHOP_BUTTON, Callable(self, "_emit_shop"))
	_add_hotspot("StartHotspot", Rect2(436.0, 578.0, 454.0, 136.0), START_BUTTON, Callable(self, "_emit_start"))
	_add_hotspot("StorageHotspot", Rect2(915.0, 584.0, 298.0, 126.0), STORAGE_BUTTON, Callable(self, "_emit_storage"))


func set_currency(amount: int) -> void:
	if _currency_label != null:
		_currency_label.text = str(amount)


func _add_hotspot(node_name: String, rect: Rect2, texture: Texture2D, callback: Callable) -> void:
	var overlay := TextureRect.new()
	overlay.name = "%sGlow" % node_name
	overlay.position = rect.position
	overlay.size = rect.size
	overlay.texture = texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	overlay.modulate = Color(1.16, 1.10, 0.90, 1.0)
	add_child(overlay)

	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(func() -> void: overlay.visible = true)
	button.mouse_exited.connect(func() -> void: overlay.visible = false)
	button.button_down.connect(func() -> void:
		overlay.scale = Vector2(0.985, 0.985)
		overlay.position = rect.position + rect.size * 0.0075
	)
	button.button_up.connect(func() -> void:
		overlay.scale = Vector2.ONE
		overlay.position = rect.position
	)
	button.pressed.connect(callback)
	add_child(button)


func _emit_start() -> void:
	start_pressed.emit()


func _emit_shop() -> void:
	shop_pressed.emit()


func _emit_storage() -> void:
	storage_pressed.emit()
