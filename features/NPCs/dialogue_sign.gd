extends Area2D

const FALLBACK_DIALOGUE := preload("res://levels/Npc_test_dialogue/Dialogs/Vincent_dialogue.dialogue")
const FALLBACK_TITLE := "Vincent_Dialogue"

@onready var prompt_panel: Panel = $Prompt
@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"
var _player_in_range := false
var _dialogue_running := false


func _ready() -> void:
	prompt_panel.visible = false
	prompt_panel.top_level = true
	if dialogue_resource == null:
		dialogue_resource = FALLBACK_DIALOGUE
	if dialogue_start.is_empty():
		dialogue_start = FALLBACK_TITLE


func _process(_delta: float) -> void:
	# Keep prompt positioned above sign while ignoring parent scale.
	prompt_panel.global_position = global_position + Vector2(-74.0, -92.0)

	if not _player_in_range:
		return
	if _dialogue_running:
		return
	if not Input.is_action_just_pressed("Talk"):
		return

	_start_dialogue()


func _start_dialogue() -> void:
	var resource_to_use: DialogueResource = dialogue_resource
	if resource_to_use == null:
		resource_to_use = FALLBACK_DIALOGUE

	if resource_to_use == null:
		push_warning("DialogueSign: no dialogue resource available.")
		return

	var title_to_use := dialogue_start
	if title_to_use.is_empty():
		title_to_use = FALLBACK_TITLE

	var available_titles := resource_to_use.get_titles()
	if not available_titles.has(title_to_use):
		if available_titles.has(FALLBACK_TITLE):
			title_to_use = FALLBACK_TITLE
		elif not resource_to_use.first_title.is_empty():
			title_to_use = resource_to_use.first_title
		elif available_titles.size() > 0:
			title_to_use = available_titles[0]
		else:
			push_warning("DialogueSign: dialogue resource has no titles.")
			return

	_dialogue_running = true
	prompt_panel.visible = false
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	DialogueManager.show_example_dialogue_balloon(resource_to_use, title_to_use)


func _on_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_player_in_range = true
	prompt_panel.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_player_in_range = false
	prompt_panel.visible = false


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_dialogue_running = false
	prompt_panel.visible = _player_in_range


func _is_player_body(body: Node) -> bool:
	return body is CharacterBody2D
