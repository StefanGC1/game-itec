extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -900
const GRAVITY = 900.0

@onready var foot_pos_marker = $FootPosition

@export var layer_switch_cooldown_seconds: float = 0.25
var can_switch_layer: bool = true
var layer_switch_cooldown_timer: Timer

signal switch_layer(direction: int, player_position: Vector2)
signal preview_layers(isActive: bool)

func _ready() -> void:
	layer_switch_cooldown_timer = Timer.new()
	layer_switch_cooldown_timer.one_shot = true
	layer_switch_cooldown_timer.wait_time = layer_switch_cooldown_seconds
	layer_switch_cooldown_timer.timeout.connect(_on_layer_switch_cooldown_timeout)
	add_child(layer_switch_cooldown_timer)

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
		_try_switch_layer(1)
	elif event.is_action_pressed("2d_layer_backward"):
		_try_switch_layer(-1)

	if event.is_action_pressed("2d_layer_preview"):
		emit_signal("preview_layers", true)
	elif event.is_action_released("2d_layer_preview"):
		emit_signal("preview_layers", false)

func _try_switch_layer(direction: int) -> void:
	if not can_switch_layer:
		return

	can_switch_layer = false
	layer_switch_cooldown_timer.start()
	emit_signal("switch_layer", direction, foot_pos_marker.global_position)

func _on_layer_switch_cooldown_timeout() -> void:
	can_switch_layer = true
