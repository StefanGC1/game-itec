extends CanvasLayer
class_name UpgradeShopUI

signal drill_upgrade_requested
signal mining_speed_upgrade_requested
signal fuel_capacity_upgrade_requested
signal inventory_capacity_upgrade_requested
signal close_requested

@onready var backdrop: ColorRect = $Backdrop
@onready var root_margin: MarginContainer = $MarginContainer
@onready var panel: PanelContainer = $MarginContainer/PanelContainer
@onready var credits_value: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CreditsValue
@onready var drill_value: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/DrillValue
@onready var mining_speed_value: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MiningSpeedValue
@onready var fuel_capacity_value: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/FuelValue
@onready var inventory_capacity_value: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/InventoryValue
@onready var status_value: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/StatusValue

@onready var drill_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/DrillButton
@onready var mining_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/MiningSpeedButton
@onready var fuel_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/FuelButton
@onready var inventory_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/InventoryButton
@onready var close_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/CloseButton


func _ready() -> void:
	visible = false
	backdrop.modulate.a = 0.0
	root_margin.modulate.a = 0.0
	drill_button.pressed.connect(func() -> void: drill_upgrade_requested.emit())
	mining_button.pressed.connect(func() -> void: mining_speed_upgrade_requested.emit())
	fuel_button.pressed.connect(func() -> void: fuel_capacity_upgrade_requested.emit())
	inventory_button.pressed.connect(func() -> void: inventory_capacity_upgrade_requested.emit())
	close_button.pressed.connect(func() -> void: close_requested.emit())


func open_ui() -> void:
	visible = true
	var tween := create_tween()
	tween.parallel().tween_property(backdrop, "modulate:a", 1.0, 0.14)
	tween.parallel().tween_property(root_margin, "modulate:a", 1.0, 0.14)


func close_ui() -> void:
	var tween := create_tween()
	tween.parallel().tween_property(backdrop, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(root_margin, "modulate:a", 0.0, 0.12)
	tween.finished.connect(func() -> void: visible = false)


func set_shop_state(state: Dictionary, status: String, can_interact: bool) -> void:
	credits_value.text = "Credits: " + str(state.get("credits", 0))
	drill_value.text = "Drill Level: " + str(state.get("drill_level", 1)) + " / 3 | Next cost: " + _format_next_cost(state.get("next_drill_cost", -1))
	mining_speed_value.text = "Mining Speed Level: " + str(state.get("mining_speed_level", 1)) + " / 10 | Next cost: " + _format_next_cost(state.get("next_mining_speed_cost", -1))
	fuel_capacity_value.text = "Fuel Capacity Level: " + str(state.get("fuel_capacity_level", 1)) + " / 10 | Next cost: " + _format_next_cost(state.get("next_fuel_capacity_cost", -1))
	inventory_capacity_value.text = "Inventory Capacity Level: " + str(state.get("inventory_capacity_level", 1)) + " / 10 | Next cost: " + _format_next_cost(state.get("next_inventory_capacity_cost", -1))
	status_value.text = "Status: " + status + " | Inflation: +" + str(int(state.get("upgrade_inflation_percent", 0))) + "%"

	drill_button.disabled = not can_interact
	mining_button.disabled = not can_interact
	fuel_button.disabled = not can_interact
	inventory_button.disabled = not can_interact


func _format_next_cost(cost_value: Variant) -> String:
	var cost := int(cost_value)
	if cost < 0:
		return "MAX"
	return str(cost)
