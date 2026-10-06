extends Node

# 심플한 목록형 인벤토리 관리 매니저

var items: Array = []
var battery_level: float = 100.0
var max_battery: float = 100.0

signal item_added(item_name)
signal item_removed(item_name)
signal battery_changed(current_level)

func _ready():
	print("InventoryManager Initialized")

func add_item(item_name: String):
	if not items.has(item_name):
		items.append(item_name)
		emit_signal("item_added", item_name)
		print("Item added: ", item_name)

func remove_item(item_name: String):
	if items.has(item_name):
		items.erase(item_name)
		emit_signal("item_removed", item_name)
		print("Item removed: ", item_name)

func has_item(item_name: String) -> bool:
	return items.has(item_name)

func consume_battery(amount: float):
	battery_level = max(0.0, battery_level - amount)
	emit_signal("battery_changed", battery_level)
