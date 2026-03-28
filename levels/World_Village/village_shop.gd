extends Node3D

const SHOP_TOGGLE_KEY := KEY_E
const SHOP_UI_SCENE := preload("res://ui/upgrade_shop_ui.tscn")

@onready var shop_area: Area3D = $Area3D
@onready var shop_label: Label3D = $Label3D
@onready var player: CharacterBody3D = $Player3d

var shop_ui: CanvasLayer
var player_in_shop := false
var status_message := "Walk into the shop area to upgrade."
var shop_open := false


func _ready() -> void:
	shop_ui = SHOP_UI_SCENE.instantiate() as CanvasLayer
	add_child(shop_ui)
	shop_ui.connect("drill_upgrade_requested", _on_drill_upgrade_requested)
	shop_ui.connect("mining_speed_upgrade_requested", _on_mining_speed_upgrade_requested)
	shop_ui.connect("fuel_capacity_upgrade_requested", _on_fuel_upgrade_requested)
	shop_ui.connect("inventory_capacity_upgrade_requested", _on_inventory_upgrade_requested)
	shop_ui.connect("close_requested", _close_shop)

	shop_area.body_entered.connect(_on_shop_area_body_entered)
	shop_area.body_exited.connect(_on_shop_area_body_exited)
	if shop_label:
		shop_label.text = "Upgrade Shop\nPress E while inside area"
	_refresh_shop_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != SHOP_TOGGLE_KEY:
		return

	if not player_in_shop:
		status_message = "You need to stand in the shop area first."
		_refresh_shop_ui()
		return

	shop_open = not shop_open
	shop_ui.visible = shop_open
	if shop_open:
		status_message = "Shop opened. Use the buttons to upgrade."
	else:
		status_message = "Shop closed."
	_refresh_shop_ui()


func _attempt_upgrade(upgrade_type: String) -> void:
	status_message = _execute_upgrade(upgrade_type)
	_refresh_shop_ui()


func _on_drill_upgrade_requested() -> void:
	_attempt_upgrade("drill")


func _on_mining_speed_upgrade_requested() -> void:
	_attempt_upgrade("mining_speed")


func _on_fuel_upgrade_requested() -> void:
	_attempt_upgrade("fuel_capacity")


func _on_inventory_upgrade_requested() -> void:
	_attempt_upgrade("inventory_capacity")


func _close_shop() -> void:
	shop_open = false
	shop_ui.visible = false
	status_message = "Shop closed."
	_refresh_shop_ui()


func _execute_upgrade(upgrade_type: String) -> String:
	if not player or not player.has_method("get_upgrade_state"):
		return "Player does not support upgrades yet."

	var result: Dictionary
	match upgrade_type:
		"drill":
			result = player.call("try_upgrade_drill")
		"mining_speed":
			result = player.call("try_upgrade_mining_speed")
		"fuel_capacity":
			result = player.call("try_upgrade_fuel_capacity")
		"inventory_capacity":
			result = player.call("try_upgrade_inventory_capacity")
		_:
			return "Unknown upgrade type."

	if result.has("message"):
		return str(result["message"])
	return "Upgrade processed."


func _on_shop_area_body_entered(body: Node3D) -> void:
	if body != player:
		return
	player_in_shop = true
	status_message = "Press E to open the shop menu."
	_refresh_shop_ui()


func _on_shop_area_body_exited(body: Node3D) -> void:
	if body != player:
		return
	player_in_shop = false
	shop_open = false
	shop_ui.visible = false
	status_message = "Left shop area. Walk back in to upgrade."
	_refresh_shop_ui()


func _refresh_shop_ui() -> void:
	if not player or not player.has_method("get_upgrade_state"):
		if shop_label:
			shop_label.text = "Upgrade Shop\nPlayer upgrade data not available."
		return

	var state := player.call("get_upgrade_state") as Dictionary
	if shop_ui:
		shop_ui.call("set_shop_state", state, status_message, player_in_shop)

	if shop_label:
		if player_in_shop:
			shop_label.text = "Upgrade Shop\nPress E"
		else:
			shop_label.text = "Upgrade Shop"
