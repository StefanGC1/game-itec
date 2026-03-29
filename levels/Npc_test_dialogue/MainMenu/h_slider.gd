extends HSlider

@export var bus_name: String
var bus_index: int

func _ready() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	# Sincronizăm slider-ul cu volumul real la deschiderea meniului
	value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))

func _on_value_changed(new_value: float) -> void:
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(new_value))
	# Mute automat dacă e la minim
	AudioServer.set_bus_mute(bus_index, new_value < 0.01)
