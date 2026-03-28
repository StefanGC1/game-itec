extends CanvasLayer

const ORE_SPRITESHEET := preload("res://assets/UIAssets/minereuriinventar.png")
const COIN_ICON := preload("res://assets/UIAssets/coin.png")
const SPRITESHEET_SLOT_COUNT := 7
const ORE_ORDER: Array[String] = ["adamantite", "diamond", "gold", "iron", "coal"]
const ORE_SPRITE_INDEX := {
	"adamantite": 0,
	"diamond": 1,
	"gold": 2,
	"iron": 3,
	"coal": 4
}

@onready var prompt_label: Label = $Root/PromptPanel/MarginContainer/PromptLabel
@onready var inventory_panel: PanelContainer = $Root/InventoryPanel
@onready var rows_container: VBoxContainer = $Root/InventoryPanel/MarginContainer/VBoxContainer/Rows

var value_labels: Dictionary = {}
var game_state: Node


func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	_build_rows()
	_connect_game_state_signals()
	_set_inventory_open(false)
	_refresh_all_values()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	if event.keycode != KEY_TAB:
		return

	_set_inventory_open(not inventory_panel.visible)
	get_viewport().set_input_as_handled()


func _set_inventory_open(is_open: bool) -> void:
	inventory_panel.visible = is_open
	if is_open:
		prompt_label.text = "[TAB] Close Inventory"
	else:
		prompt_label.text = "[TAB] Open Inventory"


func _connect_game_state_signals() -> void:
	if game_state == null:
		return

	if game_state.has_signal("credits_changed"):
		game_state.credits_changed.connect(_on_credits_changed)
	if game_state.has_signal("inventory_changed"):
		game_state.inventory_changed.connect(_on_inventory_changed)


func _refresh_all_values() -> void:
	if game_state == null:
		_set_value("credits", 0)
		for ore_id in ORE_ORDER:
			_set_value(ore_id, 0)
		return

	_set_value("credits", int(game_state.get("credits")))
	for ore_id in ORE_ORDER:
		_set_value(ore_id, int(game_state.call("get_inventory_amount", ore_id)))


func _on_credits_changed(new_credits: int) -> void:
	_set_value("credits", new_credits)


func _on_inventory_changed(item_id: String, new_amount: int) -> void:
	if value_labels.has(item_id):
		_set_value(item_id, new_amount)


func _set_value(key: String, amount: int) -> void:
	var label := value_labels.get(key, null) as Label
	if label:
		label.text = str(amount)


func _build_rows() -> void:
	_add_row("credits", "Money", COIN_ICON)
	for ore_id in ORE_ORDER:
		_add_row(ore_id, _format_item_name(ore_id), _build_ore_icon(ore_id))


func _add_row(id: String, title: String, icon_texture: Texture2D) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == "credits":
		title_label.modulate = Color(1.0, 0.9, 0.5, 1.0)

	var value_label := Label.new()
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(56, 0)

	row.add_child(icon)
	row.add_child(title_label)
	row.add_child(value_label)
	rows_container.add_child(row)
	value_labels[id] = value_label


func _build_ore_icon(ore_id: String) -> Texture2D:
	if ORE_SPRITESHEET == null:
		return null

	var sprite_index := int(ORE_SPRITE_INDEX.get(ore_id, -1))
	if sprite_index < 0:
		return ORE_SPRITESHEET

	var frame_width := int(float(ORE_SPRITESHEET.get_width()) / float(SPRITESHEET_SLOT_COUNT))
	var frame_height := int(ORE_SPRITESHEET.get_height())
	if frame_width <= 0 or frame_height <= 0:
		return ORE_SPRITESHEET

	var atlas := AtlasTexture.new()
	atlas.atlas = ORE_SPRITESHEET
	atlas.region = Rect2i(sprite_index * frame_width, 0, frame_width, frame_height)
	return atlas


func _format_item_name(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	return item_id[0].to_upper() + item_id.substr(1)
