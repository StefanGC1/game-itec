extends CharacterBody3D


@export var move_speed: float = 6.0
@export var sprint_speed: float = 8.5
@export var acceleration: float = 18.0
@export var deceleration: float = 24.0
@export var air_control: float = 0.45
@export var jump_velocity: float = 5.5
@export var gravity_scale: float = 1.15
@export var max_fall_speed: float = 30.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var rotate_to_move_direction: bool = true
@export var turn_speed: float = 14.0
@export var camera_path: NodePath


const ACTION_LEFT := "move_left"
const ACTION_RIGHT := "move_right"
const ACTION_UP := "move_up"
const ACTION_DOWN := "move_down"
const ACTION_JUMP := "move_jump"
const ACTION_SPRINT := "move_sprint"


var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func _ready() -> void:
	_ensure_default_input_map()


func _physics_process(delta: float) -> void:
	_update_jump_timers(delta)

	if _can_jump_now():
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	_apply_gravity(delta)
	_apply_horizontal_movement(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
		velocity.y = max(velocity.y, -max_fall_speed)


func _apply_horizontal_movement(delta: float) -> void:
	var input_dir := Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	var world_dir := _get_camera_relative_direction(input_dir)
	var speed := sprint_speed if Input.is_action_pressed(ACTION_SPRINT) else move_speed
	var target_horizontal := Vector3(world_dir.x, 0.0, world_dir.z) * speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var using_accel := acceleration if target_horizontal.length_squared() > 0.0 else deceleration
	if not is_on_floor():
		using_accel *= air_control

	horizontal = horizontal.move_toward(target_horizontal, using_accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if rotate_to_move_direction and world_dir.length_squared() > 0.0001:
		var target_yaw := atan2(world_dir.x, world_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)


func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir.length_squared() == 0.0:
		return Vector3.ZERO

	var cam := _resolve_camera()
	if cam == null:
		return Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var right := cam.global_transform.basis.x
	var forward := -cam.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0

	if right.length_squared() <= 0.0001 or forward.length_squared() <= 0.0001:
		return Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	right = right.normalized()
	forward = forward.normalized()
	return (right * input_dir.x + forward * input_dir.y).normalized()


func _resolve_camera() -> Camera3D:
	if camera_path != NodePath():
		var configured_camera := get_node_or_null(camera_path) as Camera3D
		if configured_camera != null:
			return configured_camera

	var viewport_camera := get_viewport().get_camera_3d()
	if viewport_camera != null:
		return viewport_camera

	return get_node_or_null("CameraPivot/Camera3D") as Camera3D


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed(ACTION_JUMP):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)


func _can_jump_now() -> bool:
	return _jump_buffer_timer > 0.0 and _coyote_timer > 0.0


func _ensure_default_input_map() -> void:
	_ensure_action(ACTION_LEFT)
	_ensure_action(ACTION_RIGHT)
	_ensure_action(ACTION_UP)
	_ensure_action(ACTION_DOWN)
	_ensure_action(ACTION_JUMP)
	_ensure_action(ACTION_SPRINT)

	_add_key_if_missing(ACTION_LEFT, KEY_A)
	_add_key_if_missing(ACTION_LEFT, KEY_LEFT)
	_add_key_if_missing(ACTION_RIGHT, KEY_D)
	_add_key_if_missing(ACTION_RIGHT, KEY_RIGHT)
	_add_key_if_missing(ACTION_UP, KEY_W)
	_add_key_if_missing(ACTION_UP, KEY_UP)
	_add_key_if_missing(ACTION_DOWN, KEY_S)
	_add_key_if_missing(ACTION_DOWN, KEY_DOWN)
	_add_key_if_missing(ACTION_JUMP, KEY_SPACE)
	_add_key_if_missing(ACTION_SPRINT, KEY_SHIFT)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _add_key_if_missing(action: StringName, keycode: Key) -> void:
	var events := InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey and e.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
