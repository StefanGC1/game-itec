extends CanvasLayer
class_name TradeMenuUI

signal buy_requested(village_id: String, item_id: String, quantity: int)
signal sell_requested(village_id: String, item_id: String, quantity: int)
signal close_requested

var current_village_id := ""
var current_snapshot: Dictionary = {}

@onready var credits_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CreditsValue
@onready var inventory_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/InventoryValue
@onready var prices_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/PricesValue
@onready var item_picker: OptionButton = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/ItemRow/ItemOptionButton
@onready var status_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/StatusValue
@onready var quantity_spinbox: SpinBox = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/QuantityRow/QuantitySpinBox

@onready var buy_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/BuyButton
@onready var sell_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Buttons/SellButton
@onready var close_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	$MarginContainer.mouse_filter = Control.MOUSE_FILTER_STOP
	buy_button.pressed.connect(_emit_buy)
	sell_button.pressed.connect(_emit_sell)
	item_picker.item_selected.connect(_on_item_selected)
	close_button.pressed.connect(func() -> void: close_requested.emit())


func open_for_village(village_id: String, snapshot: Dictionary) -> void:
	current_village_id = village_id
	visible = true
	current_snapshot = snapshot
	_populate_item_picker(snapshot)
	set_snapshot(snapshot)
	status_label.text = "Trading in " + village_id + "."


func close_menu() -> void:
	visible = false


func set_snapshot(snapshot: Dictionary) -> void:
	current_snapshot = snapshot
	credits_label.text = "Credits: " + str(snapshot.get("credits", 0))
	_render_inventory_lines(snapshot)
	_refresh_selected_item_details()


func set_status(message: String) -> void:
	status_label.text = message


func _emit_buy() -> void:
	var item_id := _get_selected_item_id()
	if item_id.is_empty():
		set_status("No tradable item selected.")
		return

	buy_requested.emit(current_village_id, item_id, int(quantity_spinbox.value))


func _emit_sell() -> void:
	var item_id := _get_selected_item_id()
	if item_id.is_empty():
		set_status("No tradable item selected.")
		return

	sell_requested.emit(current_village_id, item_id, int(quantity_spinbox.value))


func _populate_item_picker(snapshot: Dictionary) -> void:
	item_picker.clear()
	var items: Array = snapshot.get("trade_items", [])
	for item in items:
		var item_id := str(item)
		item_picker.add_item(_pretty_item_name(item_id))
		item_picker.set_item_metadata(item_picker.item_count - 1, item_id)

	if item_picker.item_count > 0:
		item_picker.select(0)


func _render_inventory_lines(snapshot: Dictionary) -> void:
	var inventory_lines: Array[String] = []
	var items: Array = snapshot.get("trade_items", [])
	for item in items:
		var item_id := str(item)
		inventory_lines.append(_pretty_item_name(item_id) + ": " + str(snapshot.get(item_id, 0)))

	inventory_label.text = "Inventory: " + ", ".join(inventory_lines)


func _on_item_selected(_index: int) -> void:
	_refresh_selected_item_details()


func _refresh_selected_item_details() -> void:
	var item_id := _get_selected_item_id()
	if item_id.is_empty():
		prices_label.text = "No item selected."
		return

	var buy_key := item_id + "_buy"
	var sell_key := item_id + "_sell"
	var buy_price := int(current_snapshot.get(buy_key, 0))
	var sell_price := int(current_snapshot.get(sell_key, 0))
	var owned := int(current_snapshot.get(item_id, 0))
	var inflation_percent := int(round(float(current_snapshot.get("inflation_index", 0.0)) * 100.0))
	prices_label.text = _pretty_item_name(item_id) + " | In inventory: " + str(owned) + " | Buy: " + str(buy_price) + " | Sell: " + str(sell_price) + " | Inflation: +" + str(inflation_percent) + "%"


func _get_selected_item_id() -> String:
	if item_picker.item_count == 0 or item_picker.selected < 0:
		return ""

	return str(item_picker.get_item_metadata(item_picker.selected))


func _pretty_item_name(item_id: String) -> String:
	if item_id.is_empty():
		return ""

	var normalized := item_id.replace("_", " ")
	return normalized.substr(0, 1).to_upper() + normalized.substr(1)
