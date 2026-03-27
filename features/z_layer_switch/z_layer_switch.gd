@tool
extends Node
class_name ZLayerSwitch

# Test stage

# Array for all TileMapLayer nodes in the level
@export var tile_map_layers: Array[TileMapLayer] = []
@export var starting_layer: int = 0
var current_layer: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Assert we have at least one TileMapLayer in the level
	assert(tile_map_layers.size() > 0, "No TileMapLayer nodes assigned to ZLayerSwitch")

	# We explicitly and deterministically assign ZLayers in the editor
	# So we avoid depending on find_children functionality
	# Print the array to the console for debugging
	print("TileMapLayer nodes in the level: ", tile_map_layers.size())
	print("TileMapLayer nodes: ", tile_map_layers)

	current_layer = starting_layer
	if starting_layer < 0 or starting_layer >= tile_map_layers.size():
		printerr("Starting layer index is out of bounds: ", starting_layer)
		current_layer = clamp(starting_layer, 0, tile_map_layers.size() - 1)

	print("Current active layer: ", current_layer)
	print("Current active layer name: ", tile_map_layers[current_layer].name)

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _switch_layer(direction: int, player_position: Vector2) -> void:
	# Check valid direction
	if direction != 1 and direction != -1:
		print("Invalid direction: ", direction)
		return
	
	# Check array oob
	if current_layer + direction < 0 or current_layer + direction >= tile_map_layers.size():
		print("Cannot switch layer, out of bounds: ", current_layer + direction)
		return

	print("Entered _switch_layer with direction: ", direction)

	# Check valid switch
	if not is_valid_switch(direction, player_position):
		print("Invalid layer switch, player would land in an invalid position")
		return
	
	# Print
	print("Switching layer from: ", current_layer, " to: ", current_layer + direction)
	print("Current layer name: ", tile_map_layers[current_layer].name)

	# Disable current layer and enable new layer
	tile_map_layers[current_layer].enabled = false
	current_layer += direction
	tile_map_layers[current_layer].enabled = true

	# Print
	print("Switched to layer name: ", tile_map_layers[current_layer].name)

func is_valid_switch(direction: int, player_position: Vector2) -> bool:
	var current_layer_node: TileMapLayer = tile_map_layers[current_layer] as TileMapLayer
	var target_layer_node: TileMapLayer = tile_map_layers[current_layer + direction] as TileMapLayer

	# Check if switch would cause player to land in an invalid position (inside a solid tile)
	var local_position := target_layer_node.to_local(player_position)
	var cell: Vector2i = target_layer_node.local_to_map(local_position)
	var cell_data: TileData = target_layer_node.get_cell_tile_data(cell)
	
	if !cell_data:
		return true # No tile at target position, so switch is valid

	# Currently a demo way to test if switch would land player in a solid tile
	# TODO: Introduce a custom property to TileData to extract more info about the tile
	var collision_count := cell_data.get_collision_polygons_count(0)
	print("Target layer at current cell has " + str(collision_count) + " collision polygons")
	return collision_count == 0


# ================ DEBUG =================

@export_tool_button("Layer forward", "MoveUp") var layer_frwd_btn: Callable = editor_layer_forward
@export_tool_button("Layer backward", "MoveDown") var layer_bckwd_btn: Callable = editor_layer_backward

func editor_layer_forward() -> void:
	if not Engine.is_editor_hint():
		return
	_editor_switch_layer(1)

func editor_layer_backward() -> void:
	if not Engine.is_editor_hint():
		return
	_editor_switch_layer(-1)

func _editor_switch_layer(direction: int) -> void:
	if current_layer + direction < 0 or current_layer + direction >= tile_map_layers.size():
		return
	tile_map_layers[current_layer].enabled = false
	current_layer += direction
	tile_map_layers[current_layer].enabled = true
