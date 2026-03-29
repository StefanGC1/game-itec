extends Node2D

const HOME_VILLAGE_NAME := "HomeVillage"
const TRADE_MENU_UI_SCENE := preload("res://ui/trade_menu_ui.tscn")

@onready var home_village_button: Button = $HomeVillage
@onready var village_buttons: Array[Button] = [
	$Village1,
	$Village2,
	$Village3,
	$Village4,
	$Village5
]
@onready var forestry_area_buttons: Array[Button] = [
	$"Butterfly Grove North",
	$"Butterfly Grove West"
]

var trade_menu: CanvasLayer
var status_label: Label


func _ready() -> void:
	trade_menu = TRADE_MENU_UI_SCENE.instantiate() as CanvasLayer
	add_child(trade_menu)
	trade_menu.buy_requested.connect(_on_trade_buy_requested)
	trade_menu.sell_requested.connect(_on_trade_sell_requested)
	trade_menu.close_requested.connect(_on_trade_close_requested)

	home_village_button.pressed.connect(_on_home_village_pressed)
	for button in village_buttons:
		button.pressed.connect(_on_remote_village_pressed.bind(button.name))

	for button in forestry_area_buttons:
		button.pressed.connect(_on_forestry_area_pressed.bind(button.name))

	status_label = Label.new()
	status_label.text = "Select a village to trade, or gather from forestry areas."
	status_label.position = Vector2(24, 24)
	status_label.size = Vector2(860, 30)
	add_child(status_label)


func _unhandled_input(event: InputEvent) -> void:
	if not trade_menu:
		return

	if event.is_action_pressed("ui_cancel") and trade_menu.visible:
		_on_trade_close_requested()
		get_viewport().set_input_as_handled()


func _on_home_village_pressed() -> void:
	GameMaster.go_to(GameMaster.Location.VILLAGE)


func _on_remote_village_pressed(village_name: String) -> void:
	if not has_node("/root/GameState"):
		status_label.text = "GameState autoload is missing. Add it in project settings."
		return

	var game_state := get_node("/root/GameState")
	var snapshot := game_state.call("get_trade_snapshot", village_name) as Dictionary
	_set_map_buttons_enabled(false)
	trade_menu.open_for_village(village_name, snapshot)
	status_label.text = "Opened trade menu for " + village_name + "."


func _on_forestry_area_pressed(area_name: String) -> void:
	if not has_node("/root/GameState"):
		status_label.text = "GameState autoload is missing. Add it in project settings."
		return

	var game_state := get_node("/root/GameState")
	var result := game_state.call("gather_from_forest", area_name) as Dictionary
	status_label.text = str(result.get("message", "Gathered resources."))


func _on_trade_buy_requested(village_id: String, item_id: String, quantity: int) -> void:
	if not has_node("/root/GameState"):
		return

	var game_state := get_node("/root/GameState")
	var result := game_state.call("buy_item", village_id, item_id, quantity) as Dictionary
	var snapshot := game_state.call("get_trade_snapshot", village_id) as Dictionary
	trade_menu.set_snapshot(snapshot)
	trade_menu.set_status(str(result.get("message", "Trade completed.")))
	status_label.text = str(result.get("message", "Trade completed."))


func _on_trade_sell_requested(village_id: String, item_id: String, quantity: int) -> void:
	if not has_node("/root/GameState"):
		return

	var game_state := get_node("/root/GameState")
	var result := game_state.call("sell_item", village_id, item_id, quantity) as Dictionary
	var snapshot := game_state.call("get_trade_snapshot", village_id) as Dictionary
	trade_menu.set_snapshot(snapshot)
	trade_menu.set_status(str(result.get("message", "Trade completed.")))
	status_label.text = str(result.get("message", "Trade completed."))


func _on_trade_close_requested() -> void:
	trade_menu.close_menu()
	_set_map_buttons_enabled(true)
	status_label.text = "Trade menu closed. Choose another destination."


func _set_map_buttons_enabled(enabled: bool) -> void:
	home_village_button.disabled = not enabled
	for button in village_buttons:
		button.disabled = not enabled
	for button in forestry_area_buttons:
		button.disabled = not enabled
