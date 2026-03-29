extends Node
class_name CaveState

signal fuel_changed(current_fuel: float, max_fuel: float)
signal fuel_depleted

@export var drill_level = GameState.player_progress["drill_level"]
@export var mining_level = GameState.player_progress["mining_speed_level"]
@export var fuel_capacity_level = GameState.player_progress["fuel_capacity_level"]

@export var base_fuel_capacity: float = 180.0
@export var fuel_drain_on_mine: float = 1.5

var fuel_capacity: float
var current_fuel: float
var fuel_active: bool = false

@export var base_mining_speed = 0.35
var mining_speed_multiplier = 1 - (mining_level - 1) * 0.08
var mining_speed_effective = base_mining_speed * mining_speed_multiplier


func _ready() -> void:
	fuel_capacity = base_fuel_capacity * (1 + (fuel_capacity_level - 1) * 0.5)
	current_fuel = fuel_capacity
	fuel_active = true
	print("CaveState initialized with fuel capacity: ", fuel_capacity, " and mining speed: ", mining_speed_effective, "and level: ", drill_level)


func _process(delta: float) -> void:
	if not fuel_active:
		return
	current_fuel -= delta
	current_fuel = maxf(current_fuel, 0.0)
	fuel_changed.emit(current_fuel, fuel_capacity)
	if current_fuel <= 0.0:
		fuel_active = false
		fuel_depleted.emit()


func consume_fuel_on_mine() -> void:
	if not fuel_active:
		return
	current_fuel -= fuel_drain_on_mine
	current_fuel = maxf(current_fuel, 0.0)
	fuel_changed.emit(current_fuel, fuel_capacity)
	if current_fuel <= 0.0:
		fuel_active = false
		fuel_depleted.emit()
