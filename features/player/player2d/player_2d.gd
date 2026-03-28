extends CharacterBody2D

const FLOOR_EPSILON := 0.01

enum PlayerState {
	IDLE,
	RUN,
	JUMP_RISE,
	JUMP_FALL,
	MINING,
	LANDING
}

@onready var foot_pos_marker = $FootPosition

@export_group("Movement")
@export var max_speed: float = 220.0
@export var ground_accel: float = 1600.0
@export var ground_decel: float = 2200.0
@export var air_accel: float = 900.0
@export var air_decel: float = 700.0

@export_group("Jump")
@export var jump_velocity: float = -900.0
@export var rise_gravity: float = 1200.0
@export var fall_gravity: float = 2000.0
@export_range(0.1, 1.0, 0.05) var jump_cut_multiplier: float = 0.5
@export var coyote_time: float = 0.2
@export var jump_buffer_time: float = 0.2

@export_group("FSM")
@export var landing_state_duration: float = 0.05

@export var layer_switch_cooldown_seconds: float = 0.25
var can_switch_layer: bool = true
var layer_switch_cooldown_timer: Timer
var coyote_timer: Timer
var jump_buffer_timer: Timer
var landing_timer: Timer
var current_state: PlayerState = PlayerState.IDLE

var coyote_window_active: bool = false
var jump_buffer_active: bool = false
var landing_lock_active: bool = false
var was_on_floor: bool = false

signal switch_layer(direction: int, player_position: Vector2)
signal preview_layers(isActive: bool)

func _ready() -> void:
	layer_switch_cooldown_timer = _create_one_shot_timer(layer_switch_cooldown_seconds, _on_layer_switch_cooldown_timeout)
	coyote_timer = _create_one_shot_timer(coyote_time, _on_coyote_timer_timeout)
	jump_buffer_timer = _create_one_shot_timer(jump_buffer_time, _on_jump_buffer_timer_timeout)
	landing_timer = _create_one_shot_timer(landing_state_duration, _on_landing_timer_timeout)
	was_on_floor = is_on_floor()


func _create_one_shot_timer(wait_time: float, on_timeout: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer

func _physics_process(delta: float) -> void:
	var on_floor_before := is_on_floor()
	var direction := Input.get_axis("2d_left", "2d_right")
	var mining_active := _is_mining_input_active()

	_capture_jump_buffer_input()
	_apply_jump_cut()

	if not mining_active:
		_try_consume_buffered_jump(on_floor_before)

	if mining_active:
		_set_state(PlayerState.MINING)
		_apply_mining_lock(delta)
	else:
		_handle_horizontal_movement(direction, on_floor_before, delta)

	_apply_gravity(delta, on_floor_before)

	move_and_slide()
	var on_floor_after := is_on_floor()
	_update_coyote_window(was_on_floor, on_floor_after)
	_update_state_after_move(direction)
	was_on_floor = on_floor_after


func _update_coyote_window(on_floor_previous_frame: bool, on_floor_after_move: bool) -> void:
	if on_floor_previous_frame and not on_floor_after_move and velocity.y >= 0.0:
		coyote_window_active = true
		coyote_timer.stop()
		coyote_timer.wait_time = coyote_time
		coyote_timer.start()

	if on_floor_after_move:
		coyote_window_active = false
		if not coyote_timer.is_stopped():
			coyote_timer.stop()

func _capture_jump_buffer_input() -> void:
	if Input.is_action_just_pressed("2d_jump"):
		jump_buffer_active = true
		jump_buffer_timer.stop()
		jump_buffer_timer.wait_time = jump_buffer_time
		jump_buffer_timer.start()


func _apply_jump_cut() -> void:
	if Input.is_action_just_released("2d_jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _try_consume_buffered_jump(on_floor_before: bool) -> void:
	if not jump_buffer_active:
		return

	if on_floor_before or coyote_window_active:
		velocity.y = jump_velocity
		jump_buffer_active = false
		if not jump_buffer_timer.is_stopped():
			jump_buffer_timer.stop()
		coyote_window_active = false
		if not coyote_timer.is_stopped():
			coyote_timer.stop()
		_set_state(PlayerState.JUMP_RISE)


func _handle_horizontal_movement(direction: float, on_floor_before: bool, delta: float) -> void:
	var acceleration := ground_accel if on_floor_before else air_accel
	var deceleration := ground_decel if on_floor_before else air_decel

	if direction:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _apply_gravity(delta: float, on_floor_before: bool) -> void:
	# Apply gravity while airborne and also right after jump starts.
	if not on_floor_before or velocity.y < 0.0:
		var gravity := rise_gravity if velocity.y < 0.0 else fall_gravity
		velocity.y += gravity * delta

# ================= MINING =================

func _apply_mining_lock(delta: float) -> void:
	# For now: holding click means no movement input is applied.
	# Mouse-over-block validation will be added later.
	velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)

func _is_mining_input_active() -> bool:
	# TODO: Use input map with input action
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

# ================= STATE MANAGEMENT =================

func _update_state_after_move(direction: float) -> void:
	if _is_mining_input_active():
		_set_state(PlayerState.MINING)
		return

	var on_floor_after := is_on_floor()
	var just_landed := (not was_on_floor) and on_floor_after

	if just_landed:
		landing_lock_active = true
		landing_timer.stop()
		landing_timer.wait_time = landing_state_duration
		landing_timer.start()
		_set_state(PlayerState.LANDING)

	if not on_floor_after:
		if velocity.y < 0.0:
			_set_state(PlayerState.JUMP_RISE)
		else:
			_set_state(PlayerState.JUMP_FALL)
		return

	if current_state == PlayerState.LANDING and landing_lock_active:
			return

	if abs(direction) > FLOOR_EPSILON:
		_set_state(PlayerState.RUN)
	else:
		_set_state(PlayerState.IDLE)

func _set_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
	current_state = new_state

# ================= TIMER TIMEOUT CALLBACKS =================

func _on_coyote_timer_timeout() -> void:
	coyote_window_active = false


func _on_jump_buffer_timer_timeout() -> void:
	jump_buffer_active = false


func _on_landing_timer_timeout() -> void:
	landing_lock_active = false

# ================= EXPLICIT INPUT HANDLING =================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("2d_layer_forward"):
		_try_switch_layer(1)
	elif event.is_action_pressed("2d_layer_backward"):
		_try_switch_layer(-1)

	if event.is_action_pressed("2d_layer_preview"):
		emit_signal("preview_layers", true)
	elif event.is_action_released("2d_layer_preview"):
		emit_signal("preview_layers", false)

# ================ LAYER SWITCHING ================

func _try_switch_layer(direction: int) -> void:
	if not can_switch_layer:
		return

	can_switch_layer = false
	layer_switch_cooldown_timer.start()
	emit_signal("switch_layer", direction, foot_pos_marker.global_position)

func _on_layer_switch_cooldown_timeout() -> void:
	can_switch_layer = true
