extends CharacterBody3D


const SPEED = 5.0
const DRILL_MAX_LEVEL := 3
const STAT_MAX_LEVEL := 10

const DRILL_UPGRADE_COSTS: Array[int] = [0, 100, 250]
const MINING_SPEED_UPGRADE_COSTS: Array[int] = [0, 30, 45, 60, 80, 100, 130, 160, 200, 240]
const FUEL_UPGRADE_COSTS: Array[int] = [0, 25, 35, 50, 70, 90, 120, 150, 185, 220]
const INVENTORY_UPGRADE_COSTS: Array[int] = [0, 20, 30, 45, 60, 80, 105, 130, 160, 195]

const ACTION_LEFT := "3d_left"
const ACTION_RIGHT := "3d_right"
const ACTION_FORWARD := "3d_forward"
const ACTION_BACKWARD := "3d_backward"

@export var credits := 300

@export_range(1, DRILL_MAX_LEVEL) var drill_level := 1

@export_range(1, STAT_MAX_LEVEL) var mining_speed_level := 1
@export_range(1, STAT_MAX_LEVEL) var fuel_capacity_level := 1
@export_range(1, STAT_MAX_LEVEL) var inventory_capacity_level := 1

@export var base_mining_speed := 1.0
@export var base_fuel_capacity := 100.0
@export var base_inventory_capacity := 10

@export var mining_speed_per_level := 0.2
@export var fuel_capacity_per_level := 20.0
@export var inventory_capacity_per_level := 2


func _physics_process(_delta: float) -> void:
	# Simple 4-direction movement: left/right on X, up/down on Z.
	var horizontal := Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var vertical := Input.get_action_strength(ACTION_BACKWARD) - Input.get_action_strength(ACTION_FORWARD)
	var direction := Vector3(horizontal, 0.0, vertical)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.y = 0.0
	velocity.z = direction.z * SPEED

	move_and_slide()


func can_mine_tier(required_drill_level: int) -> bool:
	return drill_level >= required_drill_level


func get_mining_speed() -> float:
	return base_mining_speed + float(mining_speed_level - 1) * mining_speed_per_level


func get_fuel_capacity() -> float:
	return base_fuel_capacity + float(fuel_capacity_level - 1) * fuel_capacity_per_level


func get_inventory_capacity() -> int:
	return base_inventory_capacity + (inventory_capacity_level - 1) * inventory_capacity_per_level


func get_upgrade_state() -> Dictionary:
	return {
		"credits": credits,
		"drill_level": drill_level,
		"mining_speed_level": mining_speed_level,
		"fuel_capacity_level": fuel_capacity_level,
		"inventory_capacity_level": inventory_capacity_level,
		"mining_speed": get_mining_speed(),
		"fuel_capacity": get_fuel_capacity(),
		"inventory_capacity": get_inventory_capacity()
	}


func try_upgrade_drill() -> Dictionary:
	if drill_level >= DRILL_MAX_LEVEL:
		return {"success": false, "message": "Drill is already max level."}

	var cost: int = DRILL_UPGRADE_COSTS[drill_level]
	if credits < cost:
		return {"success": false, "message": "Not enough credits for drill upgrade (" + str(cost) + ")."}

	credits -= cost
	drill_level += 1
	return {"success": true, "message": "Drill upgraded to level " + str(drill_level) + "."}


func try_upgrade_mining_speed() -> Dictionary:
	return _try_upgrade_stat("mining_speed")


func try_upgrade_fuel_capacity() -> Dictionary:
	return _try_upgrade_stat("fuel_capacity")


func try_upgrade_inventory_capacity() -> Dictionary:
	return _try_upgrade_stat("inventory_capacity")


func _try_upgrade_stat(stat_name: String) -> Dictionary:
	var level_ref: String = ""
	var costs: Array = []
	var label := ""

	match stat_name:
		"mining_speed":
			level_ref = "mining_speed_level"
			costs = MINING_SPEED_UPGRADE_COSTS
			label = "Mining Speed"
		"fuel_capacity":
			level_ref = "fuel_capacity_level"
			costs = FUEL_UPGRADE_COSTS
			label = "Fuel Capacity"
		"inventory_capacity":
			level_ref = "inventory_capacity_level"
			costs = INVENTORY_UPGRADE_COSTS
			label = "Inventory Capacity"
		_:
			return {"success": false, "message": "Unknown stat upgrade."}

	var current_level := int(get(level_ref))
	if current_level >= STAT_MAX_LEVEL:
		return {"success": false, "message": label + " is already max level."}

	var cost: int = int(costs[current_level])
	if credits < cost:
		return {"success": false, "message": "Not enough credits for " + label + " (" + str(cost) + ")."}

	credits -= cost
	set(level_ref, current_level + 1)
	return {"success": true, "message": label + " upgraded to level " + str(current_level + 1) + "."}
