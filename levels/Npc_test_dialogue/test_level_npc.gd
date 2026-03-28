extends Node2D

@onready var tile_map_layer = $TileMapLayer
@onready var player = $Candyman
@onready var red_stone_scene = preload("res://levels/Npc_test_dialogue/red_stone.tscn")
@onready var coin_scene = preload("res://levels/Npc_test_dialogue/coin.tscn")

@onready var ore_scenes = {
	"Coin" = coin_scene,
	"RedStone" = red_stone_scene
	
}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if player.has_signal("digging_completed"):
		player.digging_completed.connect(_on_player_mined)
	
func _on_player_mined( target_global_pos: Vector2) -> void:
	var local_pos = tile_map_layer.to_local(target_global_pos)
	var map_pos = tile_map_layer.local_to_map(local_pos)
	var tile_data = tile_map_layer.get_cell_tile_data(map_pos)
	
	if tile_data:
		var is_coin = tile_data.get_custom_data("Coin")
		var is_red_stone = tile_data.get_custom_data("RedStone")
		tile_map_layer.erase_cell(map_pos)
		
		if is_red_stone == true:
			spawn_item(red_stone_scene, map_pos)
		elif is_coin == true:
			spawn_item(coin_scene, map_pos)
func spawn_item(scene, map_pos: Vector2):
	if scene == null: return
	var instance = scene.instantiate()
	var tile_center_local = tile_map_layer.map_to_local(map_pos)
	instance.global_position = tile_map_layer.to_global(tile_center_local)
	add_child(instance)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
