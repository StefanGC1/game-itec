extends Node
class_name CaveGenerator

const CaveRockEntryResource := preload("res://features/cave/cave_generator/cave_rock_entry.gd")

@export_group("Tile Set")
@export var tile_set: TileSet

@export_group("Tile Coordinates")
@export var rock_entries: Array[CaveRockEntry] = []
@export var ore_entries: Array[CaveOreEntry] = []
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
var _x_offset: int = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if entrance_layout_layer == null:
		var parent_node := get_parent()
		if parent_node:
			entrance_layout_layer = parent_node.get_node_or_null("TileMapLayer") as TileMapLayer

	_ensure_default_rock_entries()


func generate() -> Array[TileMapLayer]:
	if tile_set == null:
		push_error("CaveGenerator: TileSet is missing.")
		_generated_layers.clear()
		return _generated_layers

	if use_random_seed:
		_rng.randomize()
	else:
		_rng.seed = rng_seed

	_x_offset = floori(float(width) / 2.0)
	_cleanup_previous_generated_layers()
	_generated_layers = _create_layers()

	for layer_index in range(_generated_layers.size()):
		var grid := _generate_base_grid()
		grid = _smooth_grid(grid)
		_stamp_tier_gates(grid)
		_paint_grid_to_layer(grid, _generated_layers[layer_index])
		_place_ores_on_layer(grid, _generated_layers[layer_index])
		_stamp_entrance_layout(_generated_layers[layer_index])
		_force_tier_gates_on_layer(_generated_layers[layer_index])

	if hide_entrance_layout_after_generate and entrance_layout_layer:
		entrance_layout_layer.visible = false
		entrance_layout_layer.collision_enabled = false

	return _generated_layers


func get_generated_layers() -> Array[TileMapLayer]:
	if _generated_layers.is_empty():
		return generate()
	return _generated_layers


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
		# layer.z_index = i - zlayer_amount - 1
		result.append(layer)

	return result


func _generate_base_grid() -> Array:
	var grid: Array = []

	for y in range(max(height, 1)):
		var row: Array[int] = []
		for x in range(max(width, 1)):
			var is_border := x == 0 or y == 0 or x == width - 1 or y == height - 1
			if is_border:
				row.append(CellType.TIER_GATE)
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


func _force_tier_gates_on_layer(layer: TileMapLayer) -> void:
	# Always keep map borders as tier gate.
	for x in range(width):
		var left_right_top := Vector2i(x - _x_offset, 0)
		var left_right_bottom := Vector2i(x - _x_offset, height - 1)
		layer.set_cell(left_right_top, atlas_source_id, tier_gate_tile, atlas_alternative_id)
		layer.set_cell(left_right_bottom, atlas_source_id, tier_gate_tile, atlas_alternative_id)

	for y in range(height):
		var left_cell := Vector2i(-_x_offset, y)
		var right_cell := Vector2i((width - 1) - _x_offset, y)
		layer.set_cell(left_cell, atlas_source_id, tier_gate_tile, atlas_alternative_id)
		layer.set_cell(right_cell, atlas_source_id, tier_gate_tile, atlas_alternative_id)

	# Re-apply horizontal separator gates so entrance empty markers cannot erase them.
	var separators: Array[int] = [tier2_sep_at, tier3_sep_at]
	for start_y in separators:
		if start_y < 0 or start_y >= height:
			continue

		for y in range(start_y, min(start_y + separator_height, height)):
			for x in range(width):
				var map_cell := Vector2i(x - _x_offset, y)
				layer.set_cell(map_cell, atlas_source_id, tier_gate_tile, atlas_alternative_id)


func _paint_grid_to_layer(grid: Array, layer: TileMapLayer) -> void:
	layer.clear()

	for y in range(height):
		for x in range(width):
			var map_cell := Vector2i(x - _x_offset, y)
			match grid[y][x]:
				CellType.ROCK:
					var rock_tile := _pick_weighted_rock_tile()
					layer.set_cell(map_cell, atlas_source_id, rock_tile, atlas_alternative_id)
				CellType.TIER_GATE:
					layer.set_cell(map_cell, atlas_source_id, tier_gate_tile, atlas_alternative_id)


func _place_ores_on_layer(grid: Array, layer: TileMapLayer) -> void:
	if ore_entries.is_empty():
		return

	var ore_cells := {}
	var ore_counts := {}
	for entry in ore_entries:
		if entry == null:
			continue
		var placed := _place_ore_veins(grid, layer, entry, ore_cells)
		var id: String = entry.ore_id if entry.ore_id != "" else str(entry.atlas_variants)
		ore_counts[id] = ore_counts.get(id, 0) + placed

	for ore_id in ore_counts:
		print("CaveGenerator: %s — %d tiles" % [ore_id, ore_counts[ore_id]])


func _place_ore_veins(grid: Array, layer: TileMapLayer, ore: Resource, ore_cells: Dictionary) -> int:
	var y_min := clampi(ore.depth_min, 1, height - 2)
	var y_max := clampi(ore.depth_max, 1, height - 2)
	var total_placed := 0

	for y in range(y_min, y_max + 1):
		for x in range(1, width - 1):
			if grid[y][x] != CellType.ROCK:
				continue
			var cell := Vector2i(x, y)
			if ore_cells.has(cell):
				continue
			if _rng.randf() >= ore.vein_spawn_chance:
				continue

			var vein_size := _rng.randi_range(ore.vein_min_size, ore.vein_max_size)
			var vein := _grow_vein(grid, cell, vein_size, ore_cells)
			total_placed += vein.size()

			for vein_cell in vein:
				var map_pos := Vector2i(vein_cell.x - _x_offset, vein_cell.y)
				var tile: Vector2i = ore.atlas_variants[_rng.randi() % ore.atlas_variants.size()]
				layer.set_cell(map_pos, atlas_source_id, tile, atlas_alternative_id)

	return total_placed


func _grow_vein(grid: Array, start: Vector2i, target_size: int, ore_cells: Dictionary) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [start]

	while placed.size() < target_size and not candidates.is_empty():
		var idx := _rng.randi() % candidates.size()
		var cell: Vector2i = candidates[idx]
		candidates.remove_at(idx)

		if ore_cells.has(cell):
			continue
		if cell.x <= 0 or cell.y <= 0 or cell.x >= width - 1 or cell.y >= height - 1:
			continue
		if grid[cell.y][cell.x] != CellType.ROCK:
			continue

		ore_cells[cell] = true
		placed.append(cell)

		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = cell + offset
			if not ore_cells.has(neighbor):
				candidates.append(neighbor)

	return placed


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
	if rock_entries.is_empty():
		return Vector2i.ZERO

	var total_weight := 0.0
	for entry in rock_entries:
		if entry == null:
			continue
		total_weight += max(entry.weight, 0.0)

	if total_weight <= 0.0:
		for fallback_entry in rock_entries:
			if fallback_entry != null:
				return fallback_entry.atlas_coords
		return Vector2i.ZERO

	var roll := _rng.randf() * total_weight
	var running := 0.0

	for entry in rock_entries:
		if entry == null:
			continue
		running += max(entry.weight, 0.0)
		if roll <= running:
			return entry.atlas_coords

	for i in range(rock_entries.size() - 1, -1, -1):
		if rock_entries[i] != null:
			return rock_entries[i].atlas_coords

	return Vector2i.ZERO


func _ensure_default_rock_entries() -> void:
	if not rock_entries.is_empty():
		return

	var rock_a: Resource = CaveRockEntryResource.new()
	rock_a.atlas_coords = Vector2i(0, 0)
	rock_a.weight = 0.6

	var rock_b: Resource = CaveRockEntryResource.new()
	rock_b.atlas_coords = Vector2i(0, 1)
	rock_b.weight = 0.4

	rock_entries = [rock_a, rock_b]


func _is_empty_tile(source_id: int, atlas_coords: Vector2i, alternative_id: int) -> bool:
	# Generation no longer depends on custom tile data.
	# Empty handling is editor-defined by explicit empty tile coordinate.
	if source_id != atlas_source_id:
		return false

	if alternative_id != atlas_alternative_id:
		return false

	if atlas_coords == empty_tile:
		return true

	return false
