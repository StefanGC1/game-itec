extends CanvasLayer
class_name TradeMenuUI

signal buy_requested(village_id: String, item_id: String, quantity: int)
signal sell_requested(village_id: String, item_id: String, quantity: int)
signal close_requested

var current_village_id := ""

@onready var credits_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CreditsValue
@onready var wood_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/WoodValue
@onready var herbs_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/HerbsValue
@onready var prices_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/PricesValue
@onready var status_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/StatusValue
@onready var quantity_spinbox: SpinBox = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/QuantityRow/QuantitySpinBox

@onready var buy_wood_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/BuyWoodButton
@onready var sell_wood_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/SellWoodButton
@onready var buy_herbs_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/BuyHerbsButton
@onready var sell_herbs_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/SellHerbsButton
@onready var close_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	buy_wood_button.pressed.connect(func() -> void: _emit_buy("wood"))
	sell_wood_button.pressed.connect(func() -> void: _emit_sell("wood"))
	buy_herbs_button.pressed.connect(func() -> void: _emit_buy("herbs"))
	sell_herbs_button.pressed.connect(func() -> void: _emit_sell("herbs"))
	close_button.pressed.connect(func() -> void: close_requested.emit())


func open_for_village(village_id: String, snapshot: Dictionary) -> void:
	current_village_id = village_id
	visible = true
	set_snapshot(snapshot)
	status_label.text = "Trading in " + village_id + "."


func close_menu() -> void:
	visible = false


func set_snapshot(snapshot: Dictionary) -> void:
	credits_label.text = "Credits: " + str(snapshot.get("credits", 0))
	wood_label.text = "Wood in inventory: " + str(snapshot.get("wood", 0))
	herbs_label.text = "Herbs in inventory: " + str(snapshot.get("herbs", 0))
	prices_label.text = "Wood buy/sell: " + str(snapshot.get("wood_buy", 0)) + " / " + str(snapshot.get("wood_sell", 0)) + " | Herbs buy/sell: " + str(snapshot.get("herbs_buy", 0)) + " / " + str(snapshot.get("herbs_sell", 0))


func set_status(message: String) -> void:
	status_label.text = message


func _emit_buy(item_id: String) -> void:
	buy_requested.emit(current_village_id, item_id, int(quantity_spinbox.value))


func _emit_sell(item_id: String) -> void:
	sell_requested.emit(current_village_id, item_id, int(quantity_spinbox.value))
