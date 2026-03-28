extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var cave_generator := $CaveGenerator as CaveGenerator
	var generated_layers := cave_generator.generate()
	assert(generated_layers.size() > 0, "Cave generation produced no layers.")

	var player := $Player2D as Node
	var z_layer_switch := $ZLayerManager as ZLayerManager
	z_layer_switch.initialize_layers()
	
	# Wire up signal from player to z_layer_switch
	player.connect("switch_layer", z_layer_switch._switch_layer)
	player.connect("preview_layers", z_layer_switch._set_preview_active)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
