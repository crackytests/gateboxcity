extends Node
class_name InventorySystem

signal inventory_changed(summary: String)

var items: Dictionary = {}


func add_item(item_name: String, count := 1) -> void:
	items[item_name] = int(items.get(item_name, 0)) + count
	inventory_changed.emit(get_summary())


func has_item(item_name: String, count := 1) -> bool:
	return int(items.get(item_name, 0)) >= count


func get_summary() -> String:
	if items.is_empty():
		return "INVENTORY  empty"

	var parts: Array[String] = []
	for item_name in items.keys():
		parts.append("%s x%d" % [item_name, items[item_name]])
	return "INVENTORY  " + ", ".join(parts)
