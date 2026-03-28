extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player := $Player2D as Node
	var z_layer_switch := $ZLayerSwitch as ZLayerSwitch
	
	# Wire up signal from player to z_layer_switch
	player.connect("switch_layer", z_layer_switch._switch_layer)
	player.connect("preview_layers", z_layer_switch._set_preview_active)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
