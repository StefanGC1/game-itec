extends Node
class_name CaveGenerator

@export_group("Tile Set")
@export var tile_set: TileSet

@export_group("Cave Generation Settings")
@export var zlayer_amount: int = 3
@export var width: int = 75
@export var height: int = 150
@export var tier2_sep_at: int = 50
@export var tier3_sep_at: int = 100
@export var separator_height: int = 4

@export var initial_stone_chance: float = 0.45


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_generated_z_layers() -> Array[TileMapLayer]:
	return []
