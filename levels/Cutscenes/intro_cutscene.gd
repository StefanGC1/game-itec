extends Control

const LINES := [
	'You are M.A.T.E, the "Mining Automaton and Trading Expert"',
	"The shopkeeper, your boss, has assigned you to mining duties, for his and only his gain",
	"However, you have another reason to go to the mines",
	"You are in search of the great mythical ore of",
	"Adamantite",
	"Your mission: collect 50 of it",
]

const LINE_FADE_IN := 0.6
const LINE_HOLD := 2.0
const LINE_FADE_OUT := 0.4
const ADAMANTITE_HOLD := 3.0

@onready var label: Label = $Label

var _current_line := 0


func _ready() -> void:
	label.text = ""
	label.modulate.a = 0.0
	_play_sequence()


func _play_sequence() -> void:
	for i in LINES.size():
		_current_line = i
		label.text = LINES[i]

		# Adamantite line gets special styling
		if i == 4:
			label.add_theme_font_size_override("font_size", 48)
		else:
			label.add_theme_font_size_override("font_size", 28)

		var fade_in := create_tween()
		fade_in.tween_property(label, "modulate:a", 1.0, LINE_FADE_IN)
		await fade_in.finished

		var hold_time := ADAMANTITE_HOLD if i == 4 else LINE_HOLD
		await get_tree().create_timer(hold_time).timeout

		var fade_out := create_tween()
		fade_out.tween_property(label, "modulate:a", 0.0, LINE_FADE_OUT)
		await fade_out.finished

		await get_tree().create_timer(0.2).timeout

	GameMaster.go_to(GameMaster.Location.VILLAGE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Skip to village on any key press
		set_process_unhandled_input(false)
		GameMaster.go_to(GameMaster.Location.VILLAGE)
