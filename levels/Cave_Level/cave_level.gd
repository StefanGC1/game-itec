extends Node2D

var fuel_bar: ProgressBar


func _ready() -> void:
	var cave_generator := $CaveGenerator as CaveGenerator
	var generated_layers := cave_generator.generate()
	assert(generated_layers.size() > 0, "Cave generation produced no layers.")

	var player := $Player2D as Node
	var z_layer_switch := $ZLayerManager as ZLayerManager
	var cave_state := $CaveState as CaveState
	z_layer_switch.initialize_layers()

	# Wire up signal from player to z_layer_switch
	player.connect("switch_layer", z_layer_switch._switch_layer)
	player.connect("preview_layers", z_layer_switch._set_preview_active)
	player.connect("mine_tile", z_layer_switch.mine_at_position)
	player.z_layer_manager = z_layer_switch
	z_layer_switch.drill_level = cave_state.drill_level

	# Drain fuel when mining
	player.connect("mine_tile", _on_block_mined.bind(cave_state))

	# Fuel HUD
	_create_fuel_hud()
	cave_state.fuel_changed.connect(_on_fuel_changed)
	cave_state.fuel_depleted.connect(_on_fuel_depleted)


func _create_fuel_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10

	fuel_bar = ProgressBar.new()
	fuel_bar.anchor_left = 0.5
	fuel_bar.anchor_right = 0.5
	fuel_bar.offset_left = -600.0
	fuel_bar.offset_right = 600.0
	fuel_bar.offset_top = 14.0
	fuel_bar.offset_bottom = 54.0
	fuel_bar.value = 100.0
	fuel_bar.show_percentage = false
	fuel_bar.modulate.a = 0.75

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.03, 0.006, 0.005, 1.0)
	fuel_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.8, 0.8, 0.8)
	fuel_bar.add_theme_stylebox_override("fill", fill_style)

	canvas.add_child(fuel_bar)
	add_child(canvas)


func _on_fuel_changed(current_fuel: float, max_fuel: float) -> void:
	if fuel_bar:
		fuel_bar.max_value = max_fuel
		fuel_bar.value = current_fuel


func _on_block_mined(_global_pos: Vector2, cave_state: CaveState) -> void:
	cave_state.consume_fuel_on_mine()


func _on_fuel_depleted() -> void:
	GameMaster.go_to(GameMaster.Location.VILLAGE)


func _process(delta: float) -> void:
	pass
