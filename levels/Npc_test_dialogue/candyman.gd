extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var is_in_dialogue = false
var coins
@onready var mining_bar = $Dig_Charge_Up
@onready var actionable_finder: Area2D = $DialogueFinder
@onready var player_walking_audio_stream =$AudioStreamPlayer_walking
@onready var player_jumping_audio_stream = $AudioStreamPlayer_jumping
@onready var mining_reach_shape = $Mining_detector/CollisionShape2D
@onready var player_landing_audio_bricks = $AudioStreamPlayer_landing_brick
@onready var red_stone_label = $Hud_red_stone/GridContainer/Sprite2D/Label
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
signal speaking
signal digging_completed(target_global_position)
var dig_timer = 0.0
@export var dig_duration_stone_drill_1 = 1.5
var is_digging = false
var was_in_air = false	

#combustibi;
@onready var fuel_bar = $Fuel_hiud/ProgressBar
var current_fuel 
var max_fuel 
var draining_rate_idle = 0.5
var draining_rate_mining = 1

func _ready() -> void:
	max_fuel = fuel_bar.max_value
	current_fuel = fuel_bar.value

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
	if get_real_velocity() != Vector2.ZERO and is_on_floor():
		if not player_walking_audio_stream.playing:
			player_walking_audio_stream.play()
	else: player_walking_audio_stream.stop()
	position.x = clamp(position.x,-2000,2300)
	position.y = clamp(position.y,-800, 1350)
	
	if Input.is_action_pressed("mining_2d"):
		is_digging = true
	

	move_and_slide()
	
	if not was_in_air and not is_on_floor():
		was_in_air = true
	if was_in_air and is_on_floor():
		was_in_air = false
		player_landing_audio_bricks.play()
func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var allowed_radius = mining_reach_shape.shape.radius
	var is_mouse_in_range = global_position.distance_to(mouse_pos) <= allowed_radius
	if Input.is_action_just_pressed("Talk") and  actionable_finder.has_overlapping_bodies() and is_in_dialogue== false:
		is_in_dialogue = true
		velocity = Vector2.ZERO
		speaking.emit()
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		return
		
		
	if Input.is_action_pressed("mining_2d") and is_mouse_in_range:
		mining_bar.visible = true
		is_digging = true
		dig_timer += delta
		print(dig_timer)
		mining_bar.value = (dig_timer/dig_duration_stone_drill_1) * 100
		#mining
		current_fuel = current_fuel - draining_rate_mining * delta
		fuel_bar.value = current_fuel
	
				
		if dig_timer >= dig_duration_stone_drill_1:
			_on_dig_success(mouse_pos)
			
	else:
		is_digging = false
		dig_timer = 0.0
		mining_bar.visible = false
		mining_bar.value = 0
		#mining
		current_fuel = current_fuel - draining_rate_idle * delta
		fuel_bar.value = current_fuel
		
func _on_dialogue_ended(_resource: DialogueResource):
	is_in_dialogue = false

func _on_dig_success(pos: Vector2):
	dig_timer  = 0
	mining_bar.value = 0
	mining_bar.visible = false
	digging_completed.emit(pos)
	is_digging = false
	
func _on_dialogue_finder_area_entered(area: Area2D) -> void:
	
	if area.has_method("collect"):
		area.collect()
	
	if area.is_in_group("red_stone"):
		GameState.add_inventory_item("adamantite", 1)
		red_stone_label.text = str(GameState.inventory.get("adamantite"))
		
		
		
