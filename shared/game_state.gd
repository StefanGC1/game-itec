extends Node

const HOME_VILLAGE_ID := "HomeVillage"

var location := "village"
var credits := 300

var inventory := {
	"wood": 20,
	"herbs": 8
}

var village_prices := {
	"Village1": {"wood_buy": 15, "wood_sell": 11, "herbs_buy": 8, "herbs_sell": 6},
	"Village2": {"wood_buy": 12, "wood_sell": 9, "herbs_buy": 10, "herbs_sell": 8},
	"Village3": {"wood_buy": 18, "wood_sell": 13, "herbs_buy": 7, "herbs_sell": 5},
	"Village4": {"wood_buy": 14, "wood_sell": 10, "herbs_buy": 11, "herbs_sell": 9},
	"Village5": {"wood_buy": 20, "wood_sell": 14, "herbs_buy": 6, "herbs_sell": 4}
}


func set_location(new_location: String) -> void:
	location = new_location


func get_inventory_amount(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func get_prices(village_id: String) -> Dictionary:
	if village_prices.has(village_id):
		return village_prices[village_id]
	return {"wood_buy": 16, "wood_sell": 12, "herbs_buy": 9, "herbs_sell": 7}


func get_trade_snapshot(village_id: String) -> Dictionary:
	var prices := get_prices(village_id)
	return {
		"credits": credits,
		"wood": get_inventory_amount("wood"),
		"herbs": get_inventory_amount("herbs"),
		"wood_buy": int(prices.get("wood_buy", 0)),
		"wood_sell": int(prices.get("wood_sell", 0)),
		"herbs_buy": int(prices.get("herbs_buy", 0)),
		"herbs_sell": int(prices.get("herbs_sell", 0))
	}


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
	inventory[item_id] = get_inventory_amount(item_id) + quantity
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
	return {
		"success": true,
		"message": "Gathered " + str(wood_gain) + " wood and " + str(herbs_gain) + " herbs at " + area_name + "."
	}
