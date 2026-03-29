extends Node

const HOME_VILLAGE_ID := "HomeVillage"
const TRADE_ITEMS: Array[String] = ["wood", "herbs", "coal", "iron", "gold", "diamond", "adamantite"]
const MINEABLE_ORES: Array[String] = ["coal", "iron", "gold", "diamond", "adamantite"]

const PRICE_MIN_MULTIPLIER := 0.55
const PRICE_MAX_MULTIPLIER := 2.20
const SELL_PRESSURE_PER_UNIT := 0.045
const BUY_PRESSURE_PER_UNIT := 0.032
const STREAK_PRESSURE_PER_UNIT := 0.018
const PASSIVE_DECAY_PER_TRADE := 0.975
const OTHER_ITEM_DECAY_PER_TRADE := 0.94
const RECENT_SELL_HISTORY_LIMIT := 24
const MAX_GLOBAL_INFLATION := 0.75
const UPGRADE_INFLATION_WEIGHT := 0.90

signal inventory_changed(item_id: String, new_amount: int)
signal credits_changed(new_credits: int)
signal trade_completed(village_id: String, item_id: String, quantity: int, is_buy: bool, credits_delta: int)

var location := "village"
var credits := 25
var global_inflation_index := 0.0

var player_progress: Dictionary = {
	"drill_level": 1,
	"mining_speed_level": 1,
	"fuel_capacity_level": 1,
	"inventory_capacity_level": 1
}

func get_inventory_capacity() -> int:
	return 30 * player_progress.get("inventory_capacity_level", 1)

var inventory := {
	"wood": 2,
	"herbs": 1,
	"coal": 0,
	"iron": 0,
	"gold": 0,
	"diamond": 0,
	"adamantite": 0
}

var item_count: int = 0

var village_prices := {
	"Village1": {
		"wood_buy": 15,
		"wood_sell": 11,
		"herbs_buy": 8,
		"herbs_sell": 6,
		"coal_buy": 18,
		"coal_sell": 13,
		"iron_buy": 32,
		"iron_sell": 24,
		"gold_buy": 65,
		"gold_sell": 48,
		"diamond_buy": 130,
		"diamond_sell": 95,
		"adamantite_buy": 220,
		"adamantite_sell": 160
	},
	"Village2": {
		"wood_buy": 12,
		"wood_sell": 9,
		"herbs_buy": 10,
		"herbs_sell": 8,
		"coal_buy": 16,
		"coal_sell": 12,
		"iron_buy": 30,
		"iron_sell": 22,
		"gold_buy": 70,
		"gold_sell": 52,
		"diamond_buy": 140,
		"diamond_sell": 102,
		"adamantite_buy": 235,
		"adamantite_sell": 172
	},
	"Village3": {
		"wood_buy": 18,
		"wood_sell": 13,
		"herbs_buy": 7,
		"herbs_sell": 5,
		"coal_buy": 19,
		"coal_sell": 14,
		"iron_buy": 35,
		"iron_sell": 25,
		"gold_buy": 62,
		"gold_sell": 46,
		"diamond_buy": 126,
		"diamond_sell": 92,
		"adamantite_buy": 210,
		"adamantite_sell": 154
	},
	"Village4": {
		"wood_buy": 14,
		"wood_sell": 10,
		"herbs_buy": 11,
		"herbs_sell": 9,
		"coal_buy": 17,
		"coal_sell": 12,
		"iron_buy": 29,
		"iron_sell": 21,
		"gold_buy": 74,
		"gold_sell": 54,
		"diamond_buy": 144,
		"diamond_sell": 106,
		"adamantite_buy": 245,
		"adamantite_sell": 178
	},
	"Village5": {
		"wood_buy": 20,
		"wood_sell": 14,
		"herbs_buy": 6,
		"herbs_sell": 4,
		"coal_buy": 21,
		"coal_sell": 15,
		"iron_buy": 36,
		"iron_sell": 26,
		"gold_buy": 68,
		"gold_sell": 50,
		"diamond_buy": 136,
		"diamond_sell": 100,
		"adamantite_buy": 228,
		"adamantite_sell": 168
	}
}

var market_pressure: Dictionary = {}
var recent_sell_history: Array[String] = []


func _ready() -> void:
	_ensure_market_state_initialized()

	for item_id in inventory.keys():
		item_count += int(inventory[item_id])


func set_location(new_location: String) -> void:
	location = new_location


func get_inventory_amount(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func get_player_progress_snapshot() -> Dictionary:
	var snapshot := player_progress.duplicate(true)
	snapshot["credits"] = credits
	return snapshot


func capture_player_state(player_node: Node) -> void:
	if player_node == null:
		return

	credits = int(player_node.get("credits"))
	if player_node.get("drill_level") != null:
		player_progress["drill_level"] = int(player_node.get("drill_level"))
	if player_node.get("mining_speed_level") != null:
		player_progress["mining_speed_level"] = int(player_node.get("mining_speed_level"))
	if player_node.get("fuel_capacity_level") != null:
		player_progress["fuel_capacity_level"] = int(player_node.get("fuel_capacity_level"))
	if player_node.get("inventory_capacity_level") != null:
		player_progress["inventory_capacity_level"] = int(player_node.get("inventory_capacity_level"))


func apply_player_state(player_node: Node) -> void:
	if player_node == null:
		return

	player_node.set("credits", credits)
	if player_node.get("drill_level") != null:
		player_node.set("drill_level", int(player_progress.get("drill_level", 1)))
	if player_node.get("mining_speed_level") != null:
		player_node.set("mining_speed_level", int(player_progress.get("mining_speed_level", 1)))
	if player_node.get("fuel_capacity_level") != null:
		player_node.set("fuel_capacity_level", int(player_progress.get("fuel_capacity_level", 1)))
	if player_node.get("inventory_capacity_level") != null:
		player_node.set("inventory_capacity_level", int(player_progress.get("inventory_capacity_level", 1)))


func get_global_inflation_index() -> float:
	return global_inflation_index


func get_upgrade_inflation_multiplier() -> float:
	return 1.0 + (global_inflation_index * UPGRADE_INFLATION_WEIGHT)


func apply_inflation_to_upgrade_cost(base_cost: int) -> int:
	if base_cost <= 0:
		return 0

	return max(1, int(round(float(base_cost) * get_upgrade_inflation_multiplier())))


func add_inventory_item(item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return {"success": false, "message": "Quantity must be greater than zero."}
	if item_count + quantity > get_inventory_capacity():
		return {"success": false, "message": "Cannot add items. Inventory capacity exceeded."}

	inventory[item_id] = get_inventory_amount(item_id) + quantity
	item_count += quantity
	inventory_changed.emit(item_id, int(inventory[item_id]))

	if item_id == "adamantite" and int(inventory["adamantite"]) >= 50:
		GameMaster.go_to(GameMaster.Location.END_CUTSCENE)

	return {
		"success": true,
		"message": "Added " + str(quantity) + " " + item_id + " to inventory.",
		"item_id": item_id,
		"new_amount": int(inventory[item_id])
	}


func add_inventory_items(items: Dictionary) -> Dictionary:
	var added_total := 0
	for item_id in items.keys():
		var quantity := int(items[item_id])
		if quantity <= 0:
			continue
		inventory[item_id] = get_inventory_amount(item_id) + quantity
		inventory_changed.emit(str(item_id), int(inventory[item_id]))
		added_total += quantity

	return {
		"success": true,
		"message": "Added " + str(added_total) + " total items to inventory.",
		"added_total": added_total
	}


func add_mined_ore(ore_id: String, quantity: int) -> Dictionary:
	if not MINEABLE_ORES.has(ore_id):
		return {"success": false, "message": "Unsupported ore type: " + ore_id + "."}

	return add_inventory_item(ore_id, quantity)


func get_prices(village_id: String) -> Dictionary:
	_ensure_market_state_initialized()
	if village_prices.has(village_id):
		return _get_effective_prices(village_prices[village_id])
	return _get_effective_prices({
		"wood_buy": 16,
		"wood_sell": 12,
		"herbs_buy": 9,
		"herbs_sell": 7,
		"coal_buy": 18,
		"coal_sell": 13,
		"iron_buy": 33,
		"iron_sell": 24,
		"gold_buy": 69,
		"gold_sell": 50,
		"diamond_buy": 138,
		"diamond_sell": 100,
		"adamantite_buy": 230,
		"adamantite_sell": 168
	})


func get_trade_snapshot(village_id: String) -> Dictionary:
	var prices: Dictionary = get_prices(village_id)
	var snapshot: Dictionary = {
		"credits": credits,
		"inflation_index": global_inflation_index,
		"inflation_multiplier": 1.0 + global_inflation_index,
		"trade_items": TRADE_ITEMS.duplicate(),
		"inventory": {},
		"prices": {}
	}

	for item_id in TRADE_ITEMS:
		var buy_key: String = item_id + "_buy"
		var sell_key: String = item_id + "_sell"
		snapshot[item_id] = get_inventory_amount(item_id)
		snapshot[buy_key] = int(prices.get(buy_key, 0))
		snapshot[sell_key] = int(prices.get(sell_key, 0))
		snapshot["inventory"][item_id] = get_inventory_amount(item_id)
		snapshot["prices"][item_id] = {
			"buy": int(prices.get(buy_key, 0)),
			"sell": int(prices.get(sell_key, 0))
		}

	return snapshot


func buy_item(village_id: String, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return {"success": false, "message": "Quantity must be greater than zero."}

	var prices: Dictionary = get_prices(village_id)
	var key: String = item_id + "_buy"
	if not prices.has(key):
		return {"success": false, "message": "This village does not sell " + item_id + "."}

	var price: int = int(prices[key])
	var total_cost: int = price * quantity
	if credits < total_cost:
		return {"success": false, "message": "Not enough credits. Need " + str(total_cost) + "."}

	credits -= total_cost
	credits_changed.emit(credits)
	inventory[item_id] = get_inventory_amount(item_id) + quantity
	inventory_changed.emit(item_id, int(inventory[item_id]))
	_register_trade_pressure(item_id, quantity, true)
	trade_completed.emit(village_id, item_id, quantity, true, -total_cost)
	return {
		"success": true,
		"message": "Bought " + str(quantity) + " " + item_id + " for " + str(total_cost) + " credits."
	}


func sell_item(village_id: String, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return {"success": false, "message": "Quantity must be greater than zero."}

	var current_amount: int = get_inventory_amount(item_id)
	if current_amount < quantity:
		return {"success": false, "message": "Not enough " + item_id + " in inventory."}

	var prices: Dictionary = get_prices(village_id)
	var key: String = item_id + "_sell"
	if not prices.has(key):
		return {"success": false, "message": "This village does not buy " + item_id + "."}

	var price: int = int(prices[key])
	var total_revenue: int = price * quantity
	inventory[item_id] = current_amount - quantity
	credits += total_revenue
	credits_changed.emit(credits)
	inventory_changed.emit(item_id, int(inventory[item_id]))
	_register_trade_pressure(item_id, quantity, false)
	trade_completed.emit(village_id, item_id, quantity, false, total_revenue)
	return {
		"success": true,
		"message": "Sold " + str(quantity) + " " + item_id + " for " + str(total_revenue) + " credits."
	}


func gather_from_forest(area_name: String) -> Dictionary:
	var wood_gain := 0
	var herbs_gain := 0

	match area_name:
		"Butterfly Grove North":
			wood_gain = 7
			herbs_gain = 2
		"Butterfly Grove West":
			wood_gain = 5
			herbs_gain = 4
		_:
			wood_gain = 4
			herbs_gain = 1

	inventory["wood"] = get_inventory_amount("wood") + wood_gain
	inventory["herbs"] = get_inventory_amount("herbs") + herbs_gain
	inventory_changed.emit("wood", int(inventory["wood"]))
	inventory_changed.emit("herbs", int(inventory["herbs"]))
	return {
		"success": true,
		"message": "Gathered " + str(wood_gain) + " wood and " + str(herbs_gain) + " herbs at " + area_name + "."
	}


func _ensure_market_state_initialized() -> void:
	if not market_pressure.is_empty():
		return

	for item_id in TRADE_ITEMS:
		market_pressure[item_id] = {
			"sell": 0.0,
			"buy": 0.0,
			"streak": 0.0
		}


func _register_trade_pressure(item_id: String, quantity: int, is_buy: bool) -> void:
	_ensure_market_state_initialized()
	if quantity <= 0:
		return

	for key in market_pressure.keys():
		var p: Dictionary = market_pressure[key] as Dictionary
		p["sell"] = float(p.get("sell", 0.0)) * PASSIVE_DECAY_PER_TRADE
		p["buy"] = float(p.get("buy", 0.0)) * PASSIVE_DECAY_PER_TRADE
		p["streak"] = float(p.get("streak", 0.0)) * PASSIVE_DECAY_PER_TRADE
		if str(key) != item_id:
			p["sell"] = float(p["sell"]) * OTHER_ITEM_DECAY_PER_TRADE
			p["buy"] = float(p["buy"]) * OTHER_ITEM_DECAY_PER_TRADE
			p["streak"] = float(p["streak"]) * OTHER_ITEM_DECAY_PER_TRADE
		market_pressure[key] = p

	var item_pressure: Dictionary = market_pressure.get(item_id, {"sell": 0.0, "buy": 0.0, "streak": 0.0}) as Dictionary
	if is_buy:
		item_pressure["buy"] = float(item_pressure.get("buy", 0.0)) + (float(quantity) * BUY_PRESSURE_PER_UNIT)
	else:
		item_pressure["sell"] = float(item_pressure.get("sell", 0.0)) + (float(quantity) * SELL_PRESSURE_PER_UNIT)
		item_pressure["streak"] = float(item_pressure.get("streak", 0.0)) + (float(quantity) * STREAK_PRESSURE_PER_UNIT)
		recent_sell_history.append(item_id)
		while recent_sell_history.size() > RECENT_SELL_HISTORY_LIMIT:
			recent_sell_history.pop_front()

	market_pressure[item_id] = item_pressure
	_recalculate_global_inflation()


func _recalculate_global_inflation() -> void:
	var total_sell := 0.0
	var total_buy := 0.0
	var total_streak := 0.0
	for item_id in TRADE_ITEMS:
		var p := market_pressure.get(item_id, {}) as Dictionary
		total_sell += float(p.get("sell", 0.0))
		total_buy += float(p.get("buy", 0.0))
		total_streak += float(p.get("streak", 0.0))

	var item_count: float = max(1.0, float(TRADE_ITEMS.size()))
	var base_pressure_component: float = ((total_sell * 0.80) + (total_buy * 0.35) + (total_streak * 1.15)) / item_count
	var concentration_component: float = _get_sell_concentration_index() * 0.85
	global_inflation_index = clamp((base_pressure_component * 0.07) + concentration_component, 0.0, MAX_GLOBAL_INFLATION)


func _get_sell_concentration_index() -> float:
	if recent_sell_history.is_empty():
		return 0.0

	var frequency: Dictionary = {}
	for item_id in recent_sell_history:
		frequency[item_id] = int(frequency.get(item_id, 0)) + 1

	var highest_count := 0
	for count in frequency.values():
		highest_count = max(highest_count, int(count))

	var concentration_ratio: float = float(highest_count) / float(recent_sell_history.size())
	return clamp((concentration_ratio - (1.0 / max(1.0, float(TRADE_ITEMS.size())))) * 1.15, 0.0, 1.0)


func _get_effective_prices(base_prices: Dictionary) -> Dictionary:
	_ensure_market_state_initialized()
	var effective_prices: Dictionary = base_prices.duplicate(true)
	var village_inflation_multiplier: float = 1.0 + global_inflation_index

	for item_id in TRADE_ITEMS:
		var pressure: Dictionary = market_pressure.get(item_id, {"sell": 0.0, "buy": 0.0, "streak": 0.0}) as Dictionary
		var base_buy_key: String = item_id + "_buy"
		var base_sell_key: String = item_id + "_sell"
		if not base_prices.has(base_buy_key) or not base_prices.has(base_sell_key):
			continue

		var base_buy: float = float(base_prices[base_buy_key])
		var base_sell: float = float(base_prices[base_sell_key])
		var buy_pressure: float = float(pressure.get("buy", 0.0))
		var sell_pressure: float = float(pressure.get("sell", 0.0))
		var streak_pressure: float = float(pressure.get("streak", 0.0))

		var buy_multiplier: float = clamp((1.0 + buy_pressure * 0.08) * village_inflation_multiplier, 1.0, PRICE_MAX_MULTIPLIER)
		var sell_penalty_multiplier: float = clamp(1.0 - (sell_pressure * 0.09) - (streak_pressure * 0.08), PRICE_MIN_MULTIPLIER, 1.0)

		effective_prices[base_buy_key] = max(1, int(round(base_buy * buy_multiplier)))
		effective_prices[base_sell_key] = max(1, int(round(base_sell * sell_penalty_multiplier)))

	return effective_prices
