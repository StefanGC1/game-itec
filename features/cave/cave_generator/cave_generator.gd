extends Node
class_name CaveGenerator

@export_group("Tile Set")
@export var tile_set: TileSet

@export_group("Tile Coordinates")
@export var rock_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
@export var rock_tile_weights: Array[float] = [0.6, 0.4]
@export var tier_gate_tile: Vector2i = Vector2i(0, 3)
@export var empty_tile: Vector2i = Vector2i(4, 0)
@export var atlas_source_id: int = 0
@export var atlas_alternative_id: int = 0

@export_group("Cave Generation Settings")
@export var zlayer_amount: int = 3
@export var width: int = 75
@export var height: int = 150
@export var tier2_sep_at: int = 50
@export var tier3_sep_at: int = 100
@export var separator_height: int = 4

@export var initial_stone_chance: float = 0.45
@export var smoothing_passes: int = 3
@export var use_random_seed: bool = true
@export var rng_seed: int = 1337

@export_group("Entrance")
@export var entrance_layout_layer: TileMapLayer
@export var hide_entrance_layout_after_generate: bool = true

enum CellType {
	EMPTY,
	ROCK,
	TIER_GATE
}

var _rng := RandomNumberGenerator.new()
var _generated_layers: Array[TileMapLayer] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if entrance_layout_layer == null:
		var parent_node := get_parent()
		if parent_node:
			entrance_layout_layer = parent_node.get_node_or_null("TileMapLayer") as TileMapLayer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func generate() -> Array[TileMapLayer]:
	if tile_set == null:
		push_error("CaveGenerator: TileSet is missing.")
		_generated_layers.clear()
		return _generated_layers

	if use_random_seed:
		_rng.randomize()
	else:
		_rng.seed = rng_seed

	_cleanup_previous_generated_layers()
	_generated_layers = _create_layers()

	for layer_index in range(_generated_layers.size()):
		var grid := _generate_base_grid()
		grid = _smooth_grid(grid)
		_stamp_tier_gates(grid)
		_paint_grid_to_layer(grid, _generated_layers[layer_index])
		_stamp_entrance_layout(_generated_layers[layer_index])

	if hide_entrance_layout_after_generate and entrance_layout_layer:
		entrance_layout_layer.visible = false
		entrance_layout_layer.collision_enabled = false

	return _generated_layers


func get_generated_layers() -> Array[TileMapLayer]:
	if _generated_layers.is_empty():
		return generate()
	return _generated_layers


func get_generated_z_layers() -> Array[TileMapLayer]:
	# Backward compatible alias.
	return get_generated_layers()


func _cleanup_previous_generated_layers() -> void:
	if _generated_layers.is_empty():
		return

	for layer in _generated_layers:
		if is_instance_valid(layer):
			layer.queue_free()

	_generated_layers.clear()


func _create_layers() -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	var parent_node := get_parent()
	if parent_node == null:
		return result

	for i in range(max(zlayer_amount, 1)):
		var layer := TileMapLayer.new()
		layer.name = "ZLayer%d" % (i + 1)
		layer.tile_set = tile_set

		if entrance_layout_layer:
			layer.position = entrance_layout_layer.position
			layer.scale = entrance_layout_layer.scale
			layer.z_index = entrance_layout_layer.z_index

		parent_node.add_child(layer)
		layer.owner = parent_node.owner
		result.append(layer)

	return result


func _generate_base_grid() -> Array:
	var grid: Array = []

	for y in range(max(height, 1)):
		var row: Array[int] = []
		for x in range(max(width, 1)):
			var is_border := x == 0 or y == 0 or x == width - 1 or y == height - 1
			if is_border:
				row.append(CellType.ROCK)
			else:
				var roll := _rng.randf()
				row.append(CellType.ROCK if roll < initial_stone_chance else CellType.EMPTY)
		grid.append(row)

	return grid


func _smooth_grid(grid: Array) -> Array:
	var current_grid := grid
	for _pass_index in range(max(smoothing_passes, 0)):
		var next_grid: Array = []

		for y in range(height):
			var row: Array[int] = []
			for x in range(width):
				var solid_neighbors := _count_rock_neighbors(current_grid, x, y)
				if solid_neighbors >= 5:
					row.append(CellType.ROCK)
				elif solid_neighbors <= 3:
					row.append(CellType.EMPTY)
				else:
					row.append(current_grid[y][x])
			next_grid.append(row)

		current_grid = next_grid

	return current_grid


func _count_rock_neighbors(grid: Array, cx: int, cy: int) -> int:
	var count := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue

			var nx := cx + ox
			var ny := cy + oy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				count += 1
				continue

			if grid[ny][nx] == CellType.ROCK or grid[ny][nx] == CellType.TIER_GATE:
				count += 1

	return count


func _stamp_tier_gates(grid: Array) -> void:
	var separators: Array[int] = [tier2_sep_at, tier3_sep_at]

	for start_y in separators:
		if start_y < 0 or start_y >= height:
			continue

		for y in range(start_y, min(start_y + separator_height, height)):
			for x in range(width):
				grid[y][x] = CellType.TIER_GATE


func _paint_grid_to_layer(grid: Array, layer: TileMapLayer) -> void:
	layer.clear()

	var x_offset := floori(float(width) / 2.0)

	for y in range(height):
		for x in range(width):
			var map_cell := Vector2i(x - x_offset, y)
			match grid[y][x]:
				CellType.EMPTY:
					layer.erase_cell(map_cell)
				CellType.ROCK:
					var rock_tile := _pick_weighted_rock_tile()
					layer.set_cell(map_cell, atlas_source_id, rock_tile, atlas_alternative_id)
				CellType.TIER_GATE:
					layer.set_cell(map_cell, atlas_source_id, tier_gate_tile, atlas_alternative_id)


func _stamp_entrance_layout(target_layer: TileMapLayer) -> void:
	if entrance_layout_layer == null:
		return

	var used_rect := entrance_layout_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return

	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var cell := Vector2i(x, y)
			target_layer.erase_cell(cell)

	for cell in entrance_layout_layer.get_used_cells():
		var source_id := entrance_layout_layer.get_cell_source_id(cell)
		if source_id == -1:
			continue

		var atlas_coords := entrance_layout_layer.get_cell_atlas_coords(cell)
		var alternative_id := entrance_layout_layer.get_cell_alternative_tile(cell)

		if _is_empty_tile(source_id, atlas_coords, alternative_id):
			target_layer.erase_cell(cell)
			continue

		target_layer.set_cell(cell, source_id, atlas_coords, alternative_id)


func _pick_weighted_rock_tile() -> Vector2i:
	if rock_tiles.is_empty():
		return Vector2i.ZERO

	var effective_weights: Array[float] = _build_effective_rock_weights()
	if effective_weights.is_empty():
		return rock_tiles[0]

	var total_weight := 0.0
	for weight in effective_weights:
		total_weight += max(weight, 0.0)

	if total_weight <= 0.0:
		return rock_tiles[0]

	var roll := _rng.randf() * total_weight
	var running := 0.0

	for i in range(rock_tiles.size()):
		running += max(effective_weights[i], 0.0)
		if roll <= running:
			return rock_tiles[i]

	return rock_tiles[rock_tiles.size() - 1]


func _build_effective_rock_weights() -> Array[float]:
	var weights: Array[float] = []
	for i in range(rock_tiles.size()):
		var fallback_weight := 1.0
		if i < rock_tile_weights.size():
			fallback_weight = rock_tile_weights[i]

		var custom_weight: Variant = _get_custom_data_value(atlas_source_id, rock_tiles[i], atlas_alternative_id, "gen_weight", fallback_weight)
		weights.append(float(custom_weight))

	return weights


func _is_empty_tile(source_id: int, atlas_coords: Vector2i, alternative_id: int) -> bool:
	if atlas_coords == empty_tile:
		return true

	var type_value: Variant = _get_custom_data_value(source_id, atlas_coords, alternative_id, "type", "")
	if str(type_value) == "empty":
		return true

	var is_empty_value: Variant = _get_custom_data_value(source_id, atlas_coords, alternative_id, "is_empty", false)
	return bool(is_empty_value)


func _get_custom_data_value(source_id: int, atlas_coords: Vector2i, alternative_id: int, key: String, default_value: Variant) -> Variant:
	if tile_set == null:
		return default_value

	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return default_value

	var tile_data := source.get_tile_data(atlas_coords, alternative_id)
	if tile_data == null:
		return default_value

	var value: Variant = tile_data.get_custom_data(key)
	if value == null:
		return default_value

	return value
