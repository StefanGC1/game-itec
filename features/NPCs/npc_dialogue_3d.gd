extends Node3D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "interaction_1"
@export var prompt_text: String = "[ T ] Talk"

@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt_label: Label3D = $InteractionPrompt

var _player_in_range := false
var _dialogue_running := false
var _interaction_titles: PackedStringArray = PackedStringArray()
var _next_interaction_index := 0


func _ready() -> void:
	prompt_label.visible = false
	prompt_label.text = prompt_text
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	_build_interaction_sequence()


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if _dialogue_running:
		return
	if not Input.is_action_just_pressed("Talk"):
		return

	_start_dialogue()


func _start_dialogue() -> void:
	if dialogue_resource == null:
		push_warning("NPCDialogue3D: dialogue_resource is not assigned.")
		return

	var title_to_use := ""
	var available_titles := dialogue_resource.get_titles()

	if _interaction_titles.size() > 0:
		var bounded_index := mini(_next_interaction_index, _interaction_titles.size() - 1)
		title_to_use = _interaction_titles[bounded_index]

	if title_to_use.is_empty() or not available_titles.has(title_to_use):
		title_to_use = dialogue_start

	if title_to_use.is_empty() or not available_titles.has(title_to_use):
		if not dialogue_resource.first_title.is_empty():
			title_to_use = dialogue_resource.first_title
		elif available_titles.size() > 0:
			title_to_use = available_titles[0]
		else:
			push_warning("NPCDialogue3D: dialogue resource has no titles.")
			return

	_dialogue_running = true
	prompt_label.visible = false
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	DialogueManager.show_example_dialogue_balloon(dialogue_resource, title_to_use)

	# Move to the next interaction. Once we reach the end, keep repeating the last one.
	if _interaction_titles.size() > 0 and _next_interaction_index < _interaction_titles.size() - 1:
		_next_interaction_index += 1


func _on_body_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	_player_in_range = true
	prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if not _is_player_body(body):
		return
	_player_in_range = false
	prompt_label.visible = false


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_dialogue_running = false
	prompt_label.visible = _player_in_range


func _is_player_body(body: Node) -> bool:
	return body is CharacterBody3D


func _build_interaction_sequence() -> void:
	_interaction_titles = PackedStringArray()
	_next_interaction_index = 0

	if dialogue_resource == null:
		return

	var regex := RegEx.new()
	regex.compile("^interaction_(\\d+)$")

	var indexed_titles: Array = []
	for title in dialogue_resource.get_titles():
		var match := regex.search(title)
		if match == null:
			continue
		indexed_titles.append({
			"index": int(match.get_string(1)),
			"title": title,
		})

	indexed_titles.sort_custom(func(a, b): return a["index"] < b["index"])

	for entry in indexed_titles:
		_interaction_titles.append(entry["title"])

	if _interaction_titles.size() == 0:
		return

	var configured_index := _interaction_titles.find(dialogue_start)
	if configured_index >= 0:
		_next_interaction_index = configured_index
