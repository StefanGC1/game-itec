extends Node

enum Location { VILLAGE, WORLD_MAP, CAVE, INTRO_CUTSCENE, END_CUTSCENE }

const SCENES := {
	Location.VILLAGE:        "res://levels/World_Village/Village.tscn",
	Location.WORLD_MAP:      "res://levels/World_Map/World_Map.tscn",
	Location.CAVE:           "res://levels/Cave_Level/cave_level.tscn",
	Location.INTRO_CUTSCENE: "res://levels/Cutscenes/intro_cutscene.tscn",
	Location.END_CUTSCENE:   "res://levels/Cutscenes/end_cutscene.tscn",
}

const LOCATION_NAMES := {
	Location.VILLAGE:        "village",
	Location.WORLD_MAP:      "world_map",
	Location.CAVE:           "cave_level",
	Location.INTRO_CUTSCENE: "intro_cutscene",
	Location.END_CUTSCENE:   "end_cutscene",
}

const FADE_DURATION := 0.35
const INVENTORY_UI_SCENE := preload("res://ui/inventory_overlay.tscn")

var current_location: Location = Location.VILLAGE
var previous_location: Location = Location.VILLAGE
var is_transitioning := false
var transition_context: Dictionary = {}

# Cached village player position — set before leaving village, applied on return.
var cached_village_position: Variant = null  # Vector3 or null

@onready var _fade_rect: ColorRect = $TransitionLayer/ColorRect


func _ready() -> void:
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory_ui := INVENTORY_UI_SCENE.instantiate() as CanvasLayer
	add_child(inventory_ui)


func go_to(target: Location, context: Dictionary = {}) -> void:
	if is_transitioning:
		return
	if not SCENES.has(target):
		push_error("GameMaster: Unknown location: " + str(target))
		return

	is_transitioning = true
	transition_context = context

	previous_location = current_location
	current_location = target

	if has_node("/root/GameState"):
		get_node("/root/GameState").call("set_location", LOCATION_NAMES[target])

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await fade_out.finished

	get_tree().change_scene_to_file(SCENES[target])

	# Wait one frame for the new scene tree to be ready.
	await get_tree().process_frame

	RenderingServer.force_draw()

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	await fade_in.finished

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false


func go_back(context: Dictionary = {}) -> void:
	go_to(previous_location, context)
