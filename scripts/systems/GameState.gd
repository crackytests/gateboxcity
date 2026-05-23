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
var active_job_id := ""
var available_jobs: Array = ["pipe_blood_sample", "ratchet_saint", "listen_to_the_pipes"]
var completed_jobs: Dictionary = {}
var job_flags: Dictionary = {}
var last_mission_result := ""
var world_flags: Dictionary = {}
var cybernetics: Dictionary = {}
const SAVE_PATH := "user://gatebox_save.json"

const COOTERS_JOBS := {
	"pipe_blood_sample": {
		"title": "Pipe Blood Sample",
		"short_desc": "Bring Marbles a living drip from the utility tunnels.",
		"details": "The utility pipes below Leak Street sweat something that moves against gravity. Find a clean sample bulb, collect Pipe Blood Sample, and bring it back before it stops arguing with the glass.",
		"objective": "Collect Pipe Blood Sample in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Cooters Bar Credit, System X +1",
		"reward_item": "Cooters Bar Credit",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pipe Blood Sample",
	},
	"ratchet_saint": {
		"title": "Saint Ratchet",
		"short_desc": "Recover a pipe-cult relic before Torai invoices the miracle.",
		"details": "Pipe Father Gideon says Saint Ratchet fell into a utility runoff channel and started blessing the bolts. Marbles says bring it back before Wan Moa Torai turns it into collateral.",
		"objective": "Recover Saint Ratchet in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Chemical Neutralizer, Torai +1",
		"reward_item": "Chemical Neutralizer",
		"reward_count": 1,
		"reward_faction": "Wan Moa Torai",
		"reward_rep": 1,
		"objective_item": "Saint Ratchet",
	},
	"listen_to_the_pipes": {
		"title": "Listen To The Pipes",
		"short_desc": "Record the pipe choir where the ceiling leaks sideways.",
		"details": "There is a listening node under the main drain. Put your head where the pipes tell you not to and bring Marbles whatever the lower city says back.",
		"objective": "Use the pipe listening node in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Cooters Rumor Token, System X +1",
		"reward_item": "Cooters Rumor Token",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pipe Listening Notes",
	},
}


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


func get_job_data(job_id: String) -> Dictionary:
	var job: Dictionary = COOTERS_JOBS.get(job_id, {}).duplicate(true)
	if not job.is_empty():
		job["id"] = job_id
		job["status"] = get_job_status(job_id)
	return job


func get_available_jobs() -> Array:
	var jobs := []
	for job_id in available_jobs:
		var job := get_job_data(str(job_id))
		if not job.is_empty():
			jobs.append(job)
	return jobs


func accept_job(job_id: String) -> bool:
	if not active_job_id.is_empty():
		return false
	if not available_jobs.has(job_id):
		return false
	if is_job_completed(job_id):
		return false
	if not COOTERS_JOBS.has(job_id):
		return false

	active_job_id = job_id
	job_flags.erase(_objective_flag(job_id))
	last_mission_result = "Accepted Cooters job: %s" % str(COOTERS_JOBS[job_id].get("title", job_id))
	return true


func clear_active_job() -> void:
	active_job_id = ""


func get_active_job_data() -> Dictionary:
	if active_job_id.is_empty():
		return {}
	return get_job_data(active_job_id)


func get_job_status(job_id: String) -> String:
	if is_job_completed(job_id):
		return "paid"
	if active_job_id == job_id:
		return "ready for payout" if is_job_objective_done(job_id) else "active"
	if not active_job_id.is_empty():
		return "unavailable"
	return "available"


func is_job_completed(job_id: String) -> bool:
	return bool(completed_jobs.get(job_id, false))


func mark_job_objective_done(job_id: String) -> void:
	if job_id.is_empty() or not COOTERS_JOBS.has(job_id):
		return
	job_flags[_objective_flag(job_id)] = true
	completed_quests["cooters_job_objective_%s" % job_id] = true


func is_job_objective_done(job_id: String) -> bool:
	return bool(job_flags.get(_objective_flag(job_id), false))


func complete_active_job() -> Dictionary:
	var job_id := active_job_id
	if job_id.is_empty() or not COOTERS_JOBS.has(job_id):
		return {}
	if not is_job_objective_done(job_id):
		return {}

	var job: Dictionary = COOTERS_JOBS[job_id]
	add_item(str(job.get("reward_item", "")), int(job.get("reward_count", 1)))
	add_reputation(str(job.get("reward_faction", "System X")), int(job.get("reward_rep", 0)))
	completed_jobs[job_id] = true
	completed_quests["cooters_job_%s" % job_id] = true
	last_mission_result = "Completed Cooters job: %s" % str(job.get("title", job_id))
	active_job_id = ""
	return get_job_data(job_id)


func get_active_job_objective_text() -> String:
	if active_job_id.is_empty():
		return ""
	var job := get_job_data(active_job_id)
	if job.is_empty():
		return ""
	if is_job_objective_done(active_job_id):
		return "Return to Marbles for payment: %s." % str(job.get("title", active_job_id))
	return str(job.get("objective", "Complete the active Cooters job."))


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
		"active_job_id": active_job_id,
		"available_jobs": available_jobs,
		"completed_jobs": completed_jobs,
		"job_flags": job_flags,
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
	active_job_id = str(parsed.get("active_job_id", ""))
	available_jobs = parsed.get("available_jobs", ["pipe_blood_sample", "ratchet_saint", "listen_to_the_pipes"])
	completed_jobs = parsed.get("completed_jobs", {})
	job_flags = parsed.get("job_flags", {})
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


func _objective_flag(job_id: String) -> String:
	return "%s_objective_done" % job_id
