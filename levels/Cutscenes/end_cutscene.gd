extends Control

const FADE_IN := 1.0
const HOLD := 3.0

@onready var label: Label = $Label


func _ready() -> void:
	label.text = "You win"
	label.modulate.a = 0.0
	_play_sequence()


func _play_sequence() -> void:
	var fade_in := create_tween()
	fade_in.tween_property(label, "modulate:a", 1.0, FADE_IN)
	await fade_in.finished

	await get_tree().create_timer(HOLD).timeout

	get_tree().quit()
