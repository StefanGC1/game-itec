extends Area2D
@onready var text = $Label
@export var dialogue_resource:DialogueResource
@export var dialogue_start: String = "start"
@onready var candyman_scene =$"../Candyman"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	candyman_scene.speaking.connect(_on_candyman_speaking)
	
func _on_candyman_speaking():
	DialogueManager.show_example_dialogue_balloon(dialogue_resource, dialogue_start)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	text.visible = true


func _on_body_exited(body: Node2D) -> void:
	text.visible = false
