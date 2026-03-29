extends Node3D

const SHOP_TOGGLE_ACTION := "shop_toggle"
const SHOP_UI_SCENE := preload("res://ui/upgrade_shop_ui.tscn")
const ENTRANCE_FALLBACK_RADIUS := 2.4

@onready var shop_area: Area3D = $Area3D
@onready var shop_label: Label3D = $Label3D
@onready var player: CharacterBody3D = $Player3d
var map_entrance: Area3D
var mine_entrance: Area3D

var shop_ui: CanvasLayer
var player_in_shop := false
var status_message := "Walk into the shop area to upgrade."
var shop_open := false


func _ready() -> void:
	map_entrance = get_node_or_null("MapEntrance") as Area3D
	mine_entrance = get_node_or_null("MineEntrance") as Area3D

	shop_ui = SHOP_UI_SCENE.instantiate() as CanvasLayer
	add_child(shop_ui)
	shop_ui.connect("drill_upgrade_requested", _on_drill_upgrade_requested)
	shop_ui.connect("mining_speed_upgrade_requested", _on_mining_speed_upgrade_requested)
	shop_ui.connect("fuel_capacity_upgrade_requested", _on_fuel_upgrade_requested)
	shop_ui.connect("inventory_capacity_upgrade_requested", _on_inventory_upgrade_requested)
	shop_ui.connect("close_requested", _close_shop)

	shop_area.body_entered.connect(_on_shop_area_body_entered)
	shop_area.body_exited.connect(_on_shop_area_body_exited)
	if map_entrance:
		map_entrance.monitoring = true
		map_entrance.body_entered.connect(_on_map_entrance_body_entered)
	if mine_entrance:
		mine_entrance.monitoring = true
		mine_entrance.body_entered.connect(_on_mine_entrance_body_entered)
	if shop_label:
		shop_label.text = "Upgrade Shop\nPress E while inside area"
	_sync_player_state_from_game_state()
	_restore_village_position()
	_refresh_shop_ui()


func _physics_process(_delta: float) -> void:
	if GameMaster.is_transitioning:
		return
	if not player:
		return

	# Fallback for cases where Area3D signal wiring/collision setup is missing.
	if map_entrance and player.global_position.distance_to(map_entrance.global_position) <= ENTRANCE_FALLBACK_RADIUS:
		_go_to_world_map()
		return

	if mine_entrance and player.global_position.distance_to(mine_entrance.global_position) <= ENTRANCE_FALLBACK_RADIUS:
		_go_to_cave_level()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(SHOP_TOGGLE_ACTION):
		return
	if event.is_echo():
		return

	if not player_in_shop:
		status_message = "You need to stand in the shop area first."
		_refresh_shop_ui()
		return

	shop_open = not shop_open
	if shop_open:
		shop_ui.call("open_ui")
	else:
		shop_ui.call("close_ui")
	if shop_open:
		status_message = "Shop opened. Use the buttons to upgrade."
	else:
		status_message = "Shop closed."
	_refresh_shop_ui()


func _attempt_upgrade(upgrade_type: String) -> void:
	status_message = _execute_upgrade(upgrade_type)
	_sync_game_state_from_player()
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
	shop_ui.call("close_ui")
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
	_sync_player_state_from_game_state()
	player_in_shop = true
	status_message = "Press E to open the shop menu."
	_refresh_shop_ui()


func _on_shop_area_body_exited(body: Node3D) -> void:
	if body != player:
		return
	player_in_shop = false
	shop_open = false
	shop_ui.call("close_ui")
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


func _on_map_entrance_body_entered(body: Node3D) -> void:
	if body != player:
		return
	_go_to_world_map()


func _on_mine_entrance_body_entered(body: Node3D) -> void:
	if body != player:
		return
	_go_to_cave_level()


func _go_to_world_map() -> void:
	if GameMaster.is_transitioning:
		return

	if shop_open:
		_close_shop()

	_sync_game_state_from_player()
	_cache_village_position()
	GameMaster.go_to(GameMaster.Location.WORLD_MAP)


func _go_to_cave_level() -> void:
	if GameMaster.is_transitioning:
		return

	if shop_open:
		_close_shop()

	_sync_game_state_from_player()
	_cache_village_position()
	GameMaster.go_to(GameMaster.Location.CAVE)


func _cache_village_position() -> void:
	if player:
		GameMaster.cached_village_position = player.global_transform.origin


func _restore_village_position() -> void:
	if player and GameMaster.cached_village_position is Vector3:
		player.global_transform.origin = GameMaster.cached_village_position


func _sync_player_state_from_game_state() -> void:
	if not player or not has_node("/root/GameState"):
		return

	var game_state := get_node("/root/GameState")
	if game_state.has_method("apply_player_state"):
		game_state.call("apply_player_state", player)
		return

	player.set("credits", int(game_state.get("credits")))


func _sync_game_state_from_player() -> void:
	if not player or not has_node("/root/GameState"):
		return

	var game_state := get_node("/root/GameState")
	if game_state.has_method("capture_player_state"):
		game_state.call("capture_player_state", player)
		return

	game_state.set("credits", int(player.get("credits")))
