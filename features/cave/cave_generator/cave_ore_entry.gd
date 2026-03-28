extends Resource
class_name CaveOreEntry

@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var depth_min: int = 0
@export var depth_max: int = 9999
@export_range(0.0, 100.0, 0.01) var weight: float = 1.0

@export var vein_min_size: int = 3
@export var vein_max_size: int = 8
@export_range(0.0, 1.0, 0.01) var vein_spawn_chance: float = 0.2
