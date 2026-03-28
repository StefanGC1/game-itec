extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var is_in_dialogue = false
var coins
@onready var actionable_finder: Area2D = $DialogueFinder
@onready var player_walking_audio_stream =$AudioStreamPlayer_walking
@onready var player_jumping_audio_stream = $AudioStreamPlayer_jumping
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
signal speaking
func _physics_process(delta: float) -> void:
	
	if not is_on_floor() and not is_in_dialogue:
		velocity.y += gravity * delta
	
	
	if is_in_dialogue:
		return
		
	if Input.is_action_just_pressed("2d_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		player_jumping_audio_stream.play()

	var direction := Input.get_axis("2d_left", "2d_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	if velocity != Vector2.ZERO:
		if not player_walking_audio_stream.playing:
			player_walking_audio_stream.play()
	else: player_walking_audio_stream.stop()
	position.x = clamp(position.x,-2000,2300)
	position.y = clamp(position.y,-800, 1350)
	

	move_and_slide()
	
	
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Talk") and  actionable_finder.has_overlapping_bodies() and is_in_dialogue== false:
		is_in_dialogue = true
		velocity = Vector2.ZERO
		speaking.emit()
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		return
		
func _on_dialogue_ended(_resource: DialogueResource):
	is_in_dialogue = false
