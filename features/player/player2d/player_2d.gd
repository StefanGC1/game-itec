extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var mining_box: Area2D = $MiningBox
@onready var dig_charge_bar: ProgressBar = $Dig_Charge_Up
@onready var audio_walking_brick = $AudioStreamPlayer_walk
@onready var audio_jumping = $AudioStreamPlayer_jump
@onready var audio_landing = $AudioStreamPlayer_land_brick

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

@export_group("Cave State")
@export var cave_state: CaveState

@export_group("Movement")
@export var max_speed: float = 320.0
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
@export_group("Mining")
@export var mine_charge_time: float = 0.35
var mine_charge_progress: float = 0.0
var mine_target_pos: Vector2 = Vector2.ZERO
var z_layer_manager: ZLayerManager = null
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
var facing_direction: int = 1
var _input_locked: bool = false
var  was_in_air:bool = false
signal switch_layer(direction: int, player_position: Vector2)
signal preview_layers(isActive: bool)
signal mine_tile(target_global_position: Vector2)

func _ready() -> void:
	layer_switch_cooldown_timer = _create_one_shot_timer(layer_switch_cooldown_seconds, _on_layer_switch_cooldown_timeout)
	coyote_timer = _create_one_shot_timer(coyote_time, _on_coyote_timer_timeout)
	jump_buffer_timer = _create_one_shot_timer(jump_buffer_time, _on_jump_buffer_timer_timeout)
	landing_timer = _create_one_shot_timer(landing_state_duration, _on_landing_timer_timeout)
	was_on_floor = is_on_floor()
	_connect_dialogue_signals()

	animated_sprite.play("idle")


func _create_one_shot_timer(wait_time: float, on_timeout: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer

func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity = Vector2.ZERO
		_set_state(PlayerState.IDLE)
		_update_animation(false)
		move_and_slide()
		was_on_floor = is_on_floor()
		return
		
	if get_real_velocity() != Vector2.ZERO and is_on_floor():
		if not audio_walking_brick.playing:
			audio_walking_brick.play()
	else: audio_walking_brick.stop()

	var on_floor_before := is_on_floor()
	var direction := Input.get_axis("2d_left", "2d_right")
	var mining_active := _is_mining_input_active()
	_update_facing_from_direction_input(direction)

	_capture_jump_buffer_input()
	_apply_jump_cut()

	if not mining_active:
		_try_consume_buffered_jump(on_floor_before)

	if mining_active:
		_set_state(PlayerState.MINING)
		_apply_mining_lock(delta)
	else:
		_reset_mine_charge()
		_handle_horizontal_movement(direction, on_floor_before, delta)

	_apply_gravity(delta, on_floor_before)

	move_and_slide()
	var on_floor_after := is_on_floor()
	_update_coyote_window(was_on_floor, on_floor_after)
	_update_state_after_move(direction)
	_update_animation(mining_active)
	was_on_floor = on_floor_after

	if mining_active:
		_try_emit_mine()
		
	if not was_in_air and not is_on_floor():
		was_in_air = true
	if was_in_air and is_on_floor():
		was_in_air = false
		audio_landing.play()


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
	if _input_locked:
		return false
	# TODO: Use input map with input action
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _is_mouse_in_mining_range() -> bool:
	var mouse_pos := get_global_mouse_position()
	var shape: CollisionShape2D = mining_box.get_child(0) as CollisionShape2D
	var circle: CircleShape2D = shape.shape as CircleShape2D
	return mining_box.global_position.distance_to(mouse_pos) <= circle.radius

func _try_emit_mine() -> void:
	var mouse_pos := get_global_mouse_position()
	if not _is_mouse_in_mining_range():
		_reset_mine_charge()
		return
	if z_layer_manager and not z_layer_manager.is_mineable_at(mouse_pos):
		_reset_mine_charge()
		return

	var charge_time := mine_charge_time
	if cave_state:
		charge_time = cave_state.mining_speed_effective

	mine_target_pos = mouse_pos
	mine_charge_progress += get_physics_process_delta_time()
	dig_charge_bar.visible = true
	dig_charge_bar.max_value = charge_time
	dig_charge_bar.value = mine_charge_progress
	_position_charge_bar_at_mouse()

	if mine_charge_progress >= charge_time:
		mine_tile.emit(mine_target_pos)
		_reset_mine_charge()

func _reset_mine_charge() -> void:
	mine_charge_progress = 0.0
	dig_charge_bar.visible = false
	dig_charge_bar.value = 0.0

func _position_charge_bar_at_mouse() -> void:
	var mouse_local := to_local(get_global_mouse_position())
	dig_charge_bar.position = mouse_local + Vector2(-56, -20)

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


func _update_facing_from_direction_input(direction: float) -> void:
	if direction > FLOOR_EPSILON:
		facing_direction = 1
	elif direction < -FLOOR_EPSILON:
		facing_direction = -1


func _update_animation(mining_active: bool) -> void:
	if mining_active:
		_play_mining_animation_from_mouse_angle()
		return

	animated_sprite.flip_h = facing_direction < 0

	if not is_on_floor():
		_play_animation_if_needed("jump")
		return

	if current_state == PlayerState.RUN and abs(velocity.x) > FLOOR_EPSILON:
		_play_animation_if_needed("run")
	else:
		_play_animation_if_needed("idle")


func _play_mining_animation_from_mouse_angle() -> void:
	var mouse_delta := get_global_mouse_position() - global_position
	var angle := rad_to_deg(mouse_delta.angle())
	# This return relative to horizontal right
	# Subtract 90 to make it relative to vertical up
	angle += 90.0
	if angle < 0.0:
		angle += 360.0

	# Right-facing sectors
	if angle >= 0.0 and angle < 45.0:
		animated_sprite.flip_h = false
		_play_animation_if_needed("drill_up")
		facing_direction = 1
		return
	if angle >= 45.0 and angle < 135.0:
		animated_sprite.flip_h = false
		_play_animation_if_needed("drill_forward")
		facing_direction = 1
		return
	if angle >= 135.0 and angle < 180.0:
		animated_sprite.flip_h = false
		_play_animation_if_needed("drill_down")
		facing_direction = 1
		return

	# Left-facing mirrored sectors
	if angle >= 315.0 and angle < 360.0:
		animated_sprite.flip_h = true
		_play_animation_if_needed("drill_up")
		facing_direction = -1
		return
	if angle >= 225.0 and angle < 315.0:
		animated_sprite.flip_h = true
		_play_animation_if_needed("drill_forward")
		facing_direction = -1
		return

	# 180..225 (including 180 exactly)
	animated_sprite.flip_h = true
	_play_animation_if_needed("drill_down")
	facing_direction = -1


func _play_animation_if_needed(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

# ================= TIMER TIMEOUT CALLBACKS =================

func _on_coyote_timer_timeout() -> void:
	coyote_window_active = false


func _on_jump_buffer_timer_timeout() -> void:
	jump_buffer_active = false


func _on_landing_timer_timeout() -> void:
	landing_lock_active = false

# ================= EXPLICIT INPUT HANDLING =================

func _input(event: InputEvent) -> void:
	if _input_locked:
		return

	if event.is_action_pressed("2d_layer_forward"):
		_try_switch_layer(1)
	elif event.is_action_pressed("2d_layer_backward"):
		_try_switch_layer(-1)

	if event.is_action_pressed("2d_layer_preview"):
		emit_signal("preview_layers", true)
	elif event.is_action_released("2d_layer_preview"):
		emit_signal("preview_layers", false)
		
	if event.is_action_pressed("2d_leave_cave"):
		GameMaster.go_to(GameMaster.Location.VILLAGE)

# ================ LAYER SWITCHING ================

func _try_switch_layer(direction: int) -> void:
	if not can_switch_layer:
		return

	can_switch_layer = false
	layer_switch_cooldown_timer.start()
	emit_signal("switch_layer", direction, foot_pos_marker.global_position)

func _on_layer_switch_cooldown_timeout() -> void:
	can_switch_layer = true


func _connect_dialogue_signals() -> void:
	if not has_node("/root/DialogueManager"):
		return

	var dialogue_manager := get_node("/root/DialogueManager")
	if not dialogue_manager.dialogue_started.is_connected(_on_dialogue_started):
		dialogue_manager.dialogue_started.connect(_on_dialogue_started)
	if not dialogue_manager.dialogue_ended.is_connected(_on_dialogue_ended):
		dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_started(_resource: Resource) -> void:
	_input_locked = true
	velocity = Vector2.ZERO
	jump_buffer_active = false
	coyote_window_active = false
	landing_lock_active = false
	if not jump_buffer_timer.is_stopped():
		jump_buffer_timer.stop()
	if not coyote_timer.is_stopped():
		coyote_timer.stop()
	emit_signal("preview_layers", false)


func _on_dialogue_ended(_resource: Resource) -> void:
	_input_locked = false
