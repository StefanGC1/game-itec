@tool
extends Node
class_name ZLayerSwitch

# Test stage

# Constants
var ZERO_OPACITY: float = 0.0
var FULL_OPACITY: float = 255.0

# Array for all TileMapLayer nodes in the level
@export var tile_map_layers: Array[TileMapLayer] = []
@export var starting_layer: int = 0
var current_layer: int = 0

var preview_active: bool = false

@export var preview_opacity: float = 0.1
@export var preview_vertical_offset: float = 8.0
@export var preview_next_tint: Color = Color(0.6, 1.0, 0.6, 1.0)
@export var preview_previous_tint: Color = Color(1.0, 0.6, 0.6, 1.0)


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

	for i in range(tile_map_layers.size()):
		if i == current_layer:
			continue
		tile_map_layers[i].collision_enabled = false
		tile_map_layers[i].modulate.a = ZERO_OPACITY
		print("DEBUG POSITION: ", tile_map_layers[i].position)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# ================ LAYER PREVIEW ==================

func _set_preview_active(isActive: bool) -> void:
	preview_active = isActive
	if isActive:
		preview_layers()
	else:
		reset_layers_preview()

func preview_layers() -> void:
	# Previous layer
	if current_layer - 1 >= 0:
		var previous_layer: TileMapLayer = tile_map_layers[current_layer - 1] as TileMapLayer
		previous_layer.modulate = preview_previous_tint
		previous_layer.modulate.a = preview_opacity 
		previous_layer.position -= Vector2(0, preview_vertical_offset)
	
	# Next layer
	if current_layer + 1 < tile_map_layers.size():
		var next_layer: TileMapLayer = tile_map_layers[current_layer + 1] as TileMapLayer
		next_layer.modulate = preview_next_tint
		next_layer.modulate.a = preview_opacity
		next_layer.position += Vector2(0, preview_vertical_offset)

func reset_layers_preview() -> void:
	# Previous layer
	if current_layer - 1 >= 0:
		var previous_layer: TileMapLayer = tile_map_layers[current_layer - 1] as TileMapLayer
		previous_layer.modulate = Color(1, 1, 1, 1)
		previous_layer.modulate.a = ZERO_OPACITY
		previous_layer.position += Vector2(0, preview_vertical_offset)
	
	# Next layer
	if current_layer + 1 < tile_map_layers.size():
		var next_layer: TileMapLayer = tile_map_layers[current_layer + 1] as TileMapLayer
		next_layer.modulate = Color(1, 1, 1, 1)
		next_layer.modulate.a = ZERO_OPACITY
		next_layer.position -= Vector2(0, preview_vertical_offset)

# ================ LAYER SWITCHING ================

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

	# Reset current preview selection
	reset_layers_preview()

	# Check valid switch
	if not is_valid_switch(direction, player_position):
		print("Invalid layer switch, player would land in an invalid position")
		if preview_active:
			preview_layers() # Reapply preview if switch is invalid but preview is active
		return


	# Print
	print("Switching layer from: ", current_layer, " to: ", current_layer + direction)
	print("Current layer name: ", tile_map_layers[current_layer].name)

	# Disable collision and set opacity to 0 for current layer
	tile_map_layers[current_layer].collision_enabled = false
	tile_map_layers[current_layer].modulate.a = ZERO_OPACITY
	# Switch layer
	current_layer += direction
	tile_map_layers[current_layer].collision_enabled = true
	tile_map_layers[current_layer].modulate.a = FULL_OPACITY

	# If preview still active, reapply it
	if preview_active:
		preview_layers() # Reapply preview after reset

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

# func reset_layer_offset() -> void:
# 	# TODO: Reset only for previous and next layer
# 	for layer in tile_map_layers:
# 		layer.position = offsets[1] # Reset to default position


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
