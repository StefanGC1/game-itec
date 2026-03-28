extends CanvasLayer
class_name UpgradeShopUI

signal drill_upgrade_requested
signal mining_speed_upgrade_requested
signal fuel_capacity_upgrade_requested
signal inventory_capacity_upgrade_requested
signal close_requested

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
	drill_button.pressed.connect(func() -> void: drill_upgrade_requested.emit())
	mining_button.pressed.connect(func() -> void: mining_speed_upgrade_requested.emit())
	fuel_button.pressed.connect(func() -> void: fuel_capacity_upgrade_requested.emit())
	inventory_button.pressed.connect(func() -> void: inventory_capacity_upgrade_requested.emit())
	close_button.pressed.connect(func() -> void: close_requested.emit())


func set_shop_state(state: Dictionary, status: String, can_interact: bool) -> void:
	credits_value.text = "Credits: " + str(state.get("credits", 0))
	drill_value.text = "Drill Level: " + str(state.get("drill_level", 1)) + " / 3"
	mining_speed_value.text = "Mining Speed Level: " + str(state.get("mining_speed_level", 1)) + " / 10"
	fuel_capacity_value.text = "Fuel Capacity Level: " + str(state.get("fuel_capacity_level", 1)) + " / 10"
	inventory_capacity_value.text = "Inventory Capacity Level: " + str(state.get("inventory_capacity_level", 1)) + " / 10"
	status_value.text = "Status: " + status

	drill_button.disabled = not can_interact
	mining_button.disabled = not can_interact
	fuel_button.disabled = not can_interact
	inventory_button.disabled = not can_interact
