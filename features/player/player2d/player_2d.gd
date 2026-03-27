extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -900
const GRAVITY = 900.0

@onready var foot_pos_marker = $FootPosition

signal switch_layer(direction: int, player_position: Vector2)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Handle jump.
	if Input.is_action_just_pressed("2d_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("2d_left", "2d_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("2d_layer_forward"):
		emit_signal("switch_layer", 1, foot_pos_marker.global_position)
	elif event.is_action_pressed("2d_layer_backward"):
		emit_signal("switch_layer", -1, foot_pos_marker.global_position)
