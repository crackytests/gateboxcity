extends Node

signal cybernetics_changed

var items: Dictionary = {}
var reputation: Dictionary = {
	"System X": 0,
	"Gatebox Corporation": 0,
	"Wan Moa Torai": 0,
	"Linda": 0,
}
var completed_quests: Dictionary = {}
var last_mission_result := ""
var world_flags: Dictionary = {}
var cybernetics: Dictionary = {}
const SAVE_PATH := "user://gatebox_save.json"


func add_item(item_name: String, count := 1) -> void:
	items[item_name] = int(items.get(item_name, 0)) + count


func spend_item(item_name: String, count := 1) -> bool:
	if int(items.get(item_name, 0)) < count:
		return false

	items[item_name] = int(items[item_name]) - count
	if int(items[item_name]) <= 0:
		items.erase(item_name)
	return true


func has_item(item_name: String, count := 1) -> bool:
	return int(items.get(item_name, 0)) >= count


func add_reputation(faction_name: String, amount: int) -> void:
	reputation[faction_name] = int(reputation.get(faction_name, 0)) + amount


func mark_quest_completed(quest_id: String) -> void:
	completed_quests[quest_id] = true


func is_quest_completed(quest_id: String) -> bool:
	return bool(completed_quests.get(quest_id, false))


func set_world_flag(flag_name: String, value = true) -> void:
	world_flags[flag_name] = value


func get_world_flag(flag_name: String, default_value = false):
	return world_flags.get(flag_name, default_value)


func add_cybernetic(upgrade_id: String) -> void:
	cybernetics[upgrade_id] = true
	cybernetics_changed.emit()


func has_cybernetic(upgrade_id: String) -> bool:
	return bool(cybernetics.get(upgrade_id, false))


func get_inventory_summary() -> String:
	if items.is_empty():
		return "INVENTORY  empty"

	var parts: Array[String] = []
	for item_name in items.keys():
		parts.append("%s x%d" % [item_name, items[item_name]])
	return "INVENTORY  " + ", ".join(parts)


func get_faction_summary() -> String:
	return "REP  System X %+d  Gatebox %+d  Torai %+d" % [
		int(reputation.get("System X", reputation.get("Sub-Basement Resistance", 0))),
		int(reputation.get("Gatebox Corporation", 0)),
		int(reputation.get("Wan Moa Torai", 0)),
	]


func get_cybernetic_summary() -> String:
	if cybernetics.is_empty():
		return "CYBERNETICS  none"

	var names: Array[String] = []
	for upgrade_id in cybernetics.keys():
		if bool(cybernetics[upgrade_id]):
			names.append(_display_upgrade_name(upgrade_id))
	return "CYBERNETICS  " + ", ".join(names)


func save_game() -> bool:
	var data := {
		"items": items,
		"reputation": reputation,
		"completed_quests": completed_quests,
		"world_flags": world_flags,
		"cybernetics": cybernetics,
		"last_mission_result": last_mission_result,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	items = parsed.get("items", {})
	reputation = parsed.get("reputation", reputation)
	_migrate_reputation_keys()
	completed_quests = parsed.get("completed_quests", {})
	world_flags = parsed.get("world_flags", {})
	cybernetics = parsed.get("cybernetics", {})
	last_mission_result = str(parsed.get("last_mission_result", ""))
	return true


func _display_upgrade_name(upgrade_id: String) -> String:
	match upgrade_id:
		"targeting_coprocessor":
			return "Targeting Co-Processor"
		"gatebox_eye_mk1":
			return "Gatebox Eye MK1"
		"black_market_armature":
			return "Black-Market Armature"
		"pipewalker_legs":
			return "Pipewalker Legs"
		"soul_baffle":
			return "Soul Baffle"
		_:
			return upgrade_id.capitalize()


func _migrate_reputation_keys() -> void:
	if reputation.has("Sub-Basement Resistance") and not reputation.has("System X"):
		reputation["System X"] = reputation["Sub-Basement Resistance"]
	if not reputation.has("Wan Moa Torai"):
		reputation["Wan Moa Torai"] = 0
	if not reputation.has("Linda"):
		reputation["Linda"] = 0
