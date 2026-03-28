extends Node

const HOME_VILLAGE_ID := "HomeVillage"
const TRADE_ITEMS: Array[String] = ["wood", "herbs", "coal", "iron", "gold", "diamond", "adamantite"]
const MINEABLE_ORES: Array[String] = ["coal", "iron", "gold", "diamond", "adamantite"]

signal inventory_changed(item_id: String, new_amount: int)
signal credits_changed(new_credits: int)
signal trade_completed(village_id: String, item_id: String, quantity: int, is_buy: bool, credits_delta: int)

var location := "village"
var credits := 300

var inventory := {
	"wood": 20,
	"herbs": 8,
	"coal": 0,
	"iron": 0,
	"gold": 0,
	"diamond": 0,
	"adamantite": 0
}

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


func set_location(new_location: String) -> void:
	location = new_location


func get_inventory_amount(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_inventory_item(item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return {"success": false, "message": "Quantity must be greater than zero."}

	inventory[item_id] = get_inventory_amount(item_id) + quantity
	inventory_changed.emit(item_id, int(inventory[item_id]))
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
	if village_prices.has(village_id):
		return village_prices[village_id]
	return {
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
	}


func get_trade_snapshot(village_id: String) -> Dictionary:
	var prices := get_prices(village_id)
	var snapshot := {
		"credits": credits,
		"trade_items": TRADE_ITEMS.duplicate(),
		"inventory": {},
		"prices": {}
	}

	for item_id in TRADE_ITEMS:
		var buy_key := item_id + "_buy"
		var sell_key := item_id + "_sell"
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

	var prices := get_prices(village_id)
	var key := item_id + "_buy"
	if not prices.has(key):
		return {"success": false, "message": "This village does not sell " + item_id + "."}

	var price := int(prices[key])
	var total_cost := price * quantity
	if credits < total_cost:
		return {"success": false, "message": "Not enough credits. Need " + str(total_cost) + "."}

	credits -= total_cost
	credits_changed.emit(credits)
	inventory[item_id] = get_inventory_amount(item_id) + quantity
	inventory_changed.emit(item_id, int(inventory[item_id]))
	trade_completed.emit(village_id, item_id, quantity, true, -total_cost)
	return {
		"success": true,
		"message": "Bought " + str(quantity) + " " + item_id + " for " + str(total_cost) + " credits."
	}


func sell_item(village_id: String, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return {"success": false, "message": "Quantity must be greater than zero."}

	var current_amount := get_inventory_amount(item_id)
	if current_amount < quantity:
		return {"success": false, "message": "Not enough " + item_id + " in inventory."}

	var prices := get_prices(village_id)
	var key := item_id + "_sell"
	if not prices.has(key):
		return {"success": false, "message": "This village does not buy " + item_id + "."}

	var price := int(prices[key])
	var total_revenue := price * quantity
	inventory[item_id] = current_amount - quantity
	credits += total_revenue
	credits_changed.emit(credits)
	inventory_changed.emit(item_id, int(inventory[item_id]))
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
