extends Control
## 独立可实例化的 M5 meta/UI 壳。宿主显式 bind_run；本场景不反向挂载 main.tscn。

const ShopScript: GDScript = preload("res://logic/meta/shop.gd")
const ItemsScript: GDScript = preload("res://logic/meta/items.gd")

signal start_requested
signal shop_requested
signal storage_requested
signal menu_requested
signal shop_purchase_requested(attr_id: String)
signal storage_sale_requested(item_id: String)
signal storage_sale_all_requested

var run = null

@onready var title_label: Label = %Title
@onready var detail_label: Label = %Detail
@onready var task_label: Label = %TaskHud


func _ready() -> void:
	%StartButton.pressed.connect(_on_start_pressed)
	%ShopButton.pressed.connect(_on_shop_pressed)
	%StorageButton.pressed.connect(_on_storage_pressed)
	%BackButton.pressed.connect(_on_back_pressed)
	%SellAllButton.pressed.connect(_on_sell_all_pressed)
	refresh()


func bind_run(game_run) -> void:
	run = game_run
	refresh()


func unbind_run() -> void:
	run = null
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	if run == null:
		title_label.text = "Meta Screens"
		detail_label.text = "等待宿主绑定 GameRun"
		task_label.text = ""
		return
	title_label.text = str(run.state).capitalize()
	match run.state:
		"menu": detail_label.text = "暗晶 %d" % run.save["darkCrystals"]
		"shop": detail_label.text = _shop_text()
		"storage": detail_label.text = _storage_text()
		_: detail_label.text = "暗晶 %d · 临时背包 %s" % [run.save["darkCrystals"], str(run.tempBackpack)]
	task_label.text = _task_text()


func request_purchase(attr_id: String) -> bool:
	shop_purchase_requested.emit(attr_id)
	var result: bool = run != null and run.buy_shop_item(attr_id)
	refresh()
	return result


func request_sell(item_id: String) -> int:
	storage_sale_requested.emit(item_id)
	var gained: int = run.sell_storage_item(item_id) if run != null else 0
	refresh()
	return gained


func request_sell_all() -> int:
	storage_sale_all_requested.emit()
	var gained: int = run.sell_all_storage() if run != null else 0
	refresh()
	return gained


func _shop_text() -> String:
	var lines: Array[String] = []
	for attr_id: String in ShopScript.SHOP_ATTRS:
		var level: int = run.save["metaLevels"][attr_id]
		var price: int = ShopScript.price_for_level(level + 1)
		lines.append("%s Lv%d / %d" % [attr_id, level, price])
	return "\n".join(lines)


func _storage_text() -> String:
	var lines: Array[String] = []
	for item: Dictionary in ItemsScript.META_ITEM_LIST:
		lines.append("%s ×%d · %d/个" % [item["name"], run.save["storage"][item["id"]], item["sellPrice"]])
	return "\n".join(lines)


func _task_text() -> String:
	if run == null or run.taskDirector == null or run.taskDirector.current == null:
		return ""
	var task: Dictionary = run.taskDirector.current
	return "任务 · %s · T%d · %s" % [task["type"], task["tier"], task["state"]]


func _on_start_pressed() -> void:
	start_requested.emit()
	if run != null and run.state == "menu":
		run._start_run()
	refresh()


func _on_shop_pressed() -> void:
	shop_requested.emit()
	if run != null:
		run.open_shop()
	refresh()


func _on_storage_pressed() -> void:
	storage_requested.emit()
	if run != null:
		run.open_storage()
	refresh()


func _on_back_pressed() -> void:
	menu_requested.emit()
	if run != null:
		run.back_to_menu()
	refresh()


func _on_sell_all_pressed() -> void:
	request_sell_all()


func _exit_tree() -> void:
	run = null
