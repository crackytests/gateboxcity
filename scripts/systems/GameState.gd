extends Node

signal cybernetics_changed
signal inventory_changed(summary: String)
signal reputation_changed(summary: String)

var items: Dictionary = {}
var reputation: Dictionary = {
	"System X": 0,
	"Gatebox Corporation": 0,
	"Wan Moa Torai": 0,
	"Linda": 0,
}
var completed_quests: Dictionary = {}
var active_job_id := ""
var available_jobs: Array = [
	"pipe_blood_sample",
	"ratchet_saint",
	"listen_to_the_pipes",
	"food_court_filter",
	"cistern_pump_heart",
	"atrium_relay_echo",
]
var completed_jobs: Dictionary = {}
var job_flags: Dictionary = {}
var last_mission_result := ""
var world_flags: Dictionary = {}
var quest_states: Dictionary = {}
var cybernetics: Dictionary = {}
const SAVE_PATH := "user://gatebox_save.json"
const WAN_NOTE_ITEM := "Wan Note"
const DREAMING_GENERATOR_POTENTIAL_FLAG := "dreaming_generator_potential"
const DREAMING_GENERATOR_THRESHOLD := 40
const DREAMING_GENERATOR_MAX_POTENTIAL := 140

const WASTED_POTENTIAL_VALUES := {
	"Pipe Blood Sample": {"wan_notes": 12, "potential": 20, "label": "alive enough to disappoint a pipe"},
	"Saint Ratchet": {"wan_notes": 18, "potential": 28, "label": "a miracle with stripped threading"},
	"Pipe Listening Notes": {"wan_notes": 10, "potential": 16, "label": "recorded confession from infrastructure"},
	"Pure Water Filter": {"wan_notes": 20, "potential": 30, "label": "clean water that never reached a mouth"},
	"Cistern Filter Core": {"wan_notes": 24, "potential": 35, "label": "a public good with private paperwork"},
	"Atrium Relay Packet": {"wan_notes": 16, "potential": 24, "label": "a mall announcement nobody survived to hear"},
	"Cooters Bar Credit": {"wan_notes": 5, "potential": 8, "label": "unspent vice"},
	"Cooters Rumor Token": {"wan_notes": 6, "potential": 10, "label": "a secret that almost became useful"},
	"Chemical Neutralizer": {"wan_notes": 8, "potential": 7, "label": "safety deferred until resale"},
	"Illegal Reactor Cell": {"wan_notes": 30, "potential": 45, "label": "stolen fire with paperwork burns"},
	"Torai Salvage Contract": {"wan_notes": 9, "potential": 12, "label": "labor waiting to become debt"},
	"Broken Gatebox Display": {"wan_notes": 7, "potential": 14, "label": "comfort that failed before it could comfort"},
	"Marbles Backroom Key": {"wan_notes": 4, "potential": 5, "label": "access with nowhere clean to go"},
}

const COOTERS_JOBS := {
	"pipe_blood_sample": {
		"title": "Pipe Blood Sample",
		"short_desc": "Bring Marbles a living drip from the utility tunnels before it develops opinions.",
		"details": "The utility pipes below Leak Street are sweating something that moves against gravity, which is rude and probably billable. Find a clean sample bulb, collect Pipe Blood Sample, and bring it back before it starts arguing with the glass.",
		"objective": "Collect Pipe Blood Sample in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Cooters Bar Credit, System X +1",
		"reward_item": "Cooters Bar Credit",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pipe Blood Sample",
		"objective_interactable": "pipe_blood_sample_node",
		"event_cards_on_accept": ["pipe_blood_sample_exit", "pipe_blood_sample_travel"],
		"event_cards_on_complete": ["pipe_blood_sample_return"],
	},
	"ratchet_saint": {
		"title": "Saint Ratchet",
		"short_desc": "Recover a pipe-cult relic before Torai invoices the miracle.",
		"details": "Pipe Father Gideon says Saint Ratchet fell into a utility runoff channel and started blessing the bolts, which is very moving if you are a bolt. Marbles says bring it back before Wan Moa Torai puts a lien on the miracle.",
		"objective": "Recover Saint Ratchet in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Chemical Neutralizer, Torai +1",
		"reward_item": "Chemical Neutralizer",
		"reward_count": 1,
		"reward_faction": "Wan Moa Torai",
		"reward_rep": 1,
		"objective_item": "Saint Ratchet",
		"objective_interactable": "saint_ratchet_node",
		"event_cards_on_accept": ["ratchet_saint_exit", "ratchet_saint_travel"],
		"event_cards_on_complete": ["ratchet_saint_return"],
	},
	"listen_to_the_pipes": {
		"title": "Listen To The Pipes",
		"short_desc": "Record the pipe choir where the ceiling leaks sideways.",
		"details": "There is a listening node under the main drain, because apparently the building needed a mouth and a diary. Put your head where the pipes tell you not to and bring Marbles whatever the lower city says back.",
		"objective": "Use the pipe listening node in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Cooters Rumor Token, System X +1",
		"reward_item": "Cooters Rumor Token",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pipe Listening Notes",
		"objective_interactable": "pipe_listening_node",
		"event_cards_on_accept": ["listen_pipes_exit", "listen_pipes_travel"],
		"event_cards_on_complete": ["listen_pipes_return"],
	},
	"food_court_filter": {
		"title": "Food Court Filter",
		"short_desc": "Pull a clean water filter from the plant-choked food court.",
		"details": "The old food court is trying to become a greenhouse with teeth, a sentence nobody should have to say before lunch. Stay on the slow upper ring for clean angles, or cut through the seating pit if you trust decorative plants with your ankles.",
		"objective": "Recover the Pure Water Filter from Dead Food Court Bloom.",
		"destination": "Dead Food Court Bloom",
		"destination_id": "dead_food_court_bloom",
		"reward_text": "Cooters Bar Credit, System X +1",
		"reward_item": "Cooters Bar Credit",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pure Water Filter",
		"objective_interactable": "pure_water_filter_node",
		"event_cards_on_accept": ["food_court_exit", "food_court_travel"],
		"event_cards_on_complete": ["food_court_return"],
	},
	"cistern_pump_heart": {
		"title": "Pump Heart Lease",
		"short_desc": "Borrow a pump core from a flooded reclamation room.",
		"details": "Wan Moa Torai says the pump core is unpaid inventory. Marbles says the water gets less bitey when it is gone. Both of them are calling this a favor, which means watch the wet floor around the live conduit.",
		"objective": "Recover the Cistern Filter Core from Water Reclamation Cistern.",
		"destination": "Water Reclamation Cistern",
		"destination_id": "water_reclamation_cistern",
		"reward_text": "Chemical Neutralizer, Torai +1",
		"reward_item": "Chemical Neutralizer",
		"reward_count": 1,
		"reward_faction": "Wan Moa Torai",
		"reward_rep": 1,
		"objective_item": "Cistern Filter Core",
		"objective_interactable": "cistern_filter_core_node",
		"event_cards_on_accept": ["cistern_exit", "cistern_travel"],
		"event_cards_on_complete": ["cistern_return"],
	},
	"atrium_relay_echo": {
		"title": "Atrium Relay Echo",
		"short_desc": "Record a relay pulse from the collapsed mall atrium.",
		"details": "There is an old mall relay above a sludge gap, still whispering customer-service hymns through System X static. Use the catwalk. Do not trust the floor pretending to be floor; that is how floors get promoted.",
		"objective": "Use the comms relay in Collapsed Service Atrium.",
		"destination": "Collapsed Service Atrium",
		"destination_id": "collapsed_service_atrium",
		"reward_text": "Cooters Rumor Token, System X +1",
		"reward_item": "Cooters Rumor Token",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Atrium Relay Packet",
		"objective_interactable": "atrium_relay_node",
		"event_cards_on_accept": ["atrium_relay_exit", "atrium_relay_travel"],
		"event_cards_on_complete": ["atrium_relay_return"],
	},
}

var QUEST_DEFS: Dictionary = {
	"wake_up_call": {
		"title": "Wake-Up Call",
		"type": "campaign",
		"objectives": [
			{"id": "display_recovered", "text": "Recover the broken display", "required": true},
			{"id": "arm_disabled", "text": "Disable the goon's right arm", "required": true},
			{"id": "coolant_routed", "text": "Route soul coolant (optional)", "required": false},
		],
	},
	"hub_power_restore": {
		"title": "Restore Hub Power",
		"type": "hub",
		"giver": "Mister Static",
		"active_flag": "quest_hub_power_active",
		"done_flag": "hub_power_restored",
		"objectives": [
			{"id": "hub_power_restored", "text": "Repair the generator coupling", "required": true, "done_flag": "hub_power_restored"},
		],
		"objective_text_active": "Hub: repair the generator coupling in the basement.",
		"objective_text_done": "Hub power restored.",
	},
	"hub_lan_restore": {
		"title": "Restore Hub LAN",
		"type": "hub",
		"giver": "Vessel",
		"active_flag": "quest_hub_lan_active",
		"done_flag": "hub_lan_restored",
		"objectives": [
			{"id": "hub_lan_restored", "text": "Restore the LAN tap in the north corridor", "required": true, "done_flag": "hub_lan_restored"},
		],
		"objective_text_active": "Hub: restore the LAN tap in the north corridor ceiling.",
		"objective_text_done": "Hub LAN restored.",
	},
	"hub_cistern": {
		"title": "Connect Hub Water",
		"type": "hub",
		"giver": "Vera",
		"active_flag": "quest_hub_cistern_active",
		"done_flag": "hub_cistern_connected",
		"objectives": [
			{"id": "hub_cistern_connected", "text": "Install the water conduit at the cistern junction", "required": true, "done_flag": "hub_cistern_connected"},
		],
		"objective_text_active": "Hub: install water conduit at the cistern west walkway junction.",
		"objective_text_done": "Hub water connected.",
	},
	"hub_clear_court": {
		"title": "Clear the Court",
		"type": "hub",
		"giver": "Ladderboy",
		"active_flag": "quest_clear_court_active",
		"done_flag": "atrium_cleared",
		"objectives": [
			{"id": "atrium_cleared", "text": "Remove three debris piles from the central atrium", "required": true, "done_flag": "atrium_cleared"},
		],
		"objective_text_active": "Hub: remove three debris piles from the central atrium.",
		"objective_text_done": "Hub atrium cleared.",
	},
	"hub_store_4": {
		"title": "Claim Store 4",
		"type": "hub",
		"giver": "Velvet Coil",
		"active_flag": "quest_store_4_active",
		"done_flag": "store_4_claimed",
		"objectives": [
			{"id": "store_4_cleared", "text": "Wipe the terminal and clear debris in Store 4", "required": true},
		],
		"objective_text_active": "Hub: wipe the terminal and clear the debris in Store 4.",
		"objective_text_done": "Store 4 claimed.",
	},
}


func add_item(item_name: String, count := 1) -> void:
	items[item_name] = int(items.get(item_name, 0)) + count
	inventory_changed.emit(get_inventory_summary())


func spend_item(item_name: String, count := 1) -> bool:
	if int(items.get(item_name, 0)) < count:
		return false

	items[item_name] = int(items[item_name]) - count
	if int(items[item_name]) <= 0:
		items.erase(item_name)
	inventory_changed.emit(get_inventory_summary())
	return true


func has_item(item_name: String, count := 1) -> bool:
	return int(items.get(item_name, 0)) >= count


func get_wasted_potential_value(item_name: String) -> Dictionary:
	return WASTED_POTENTIAL_VALUES.get(item_name, {}).duplicate(true)


func get_sellable_wasted_potential_items() -> Array:
	var sellable := []
	for item_name in items.keys():
		if int(items.get(item_name, 0)) <= 0:
			continue
		if WASTED_POTENTIAL_VALUES.has(str(item_name)):
			var data: Dictionary = get_wasted_potential_value(str(item_name))
			data["item_name"] = str(item_name)
			data["count"] = int(items[item_name])
			sellable.append(data)
	sellable.sort_custom(func(a, b): return int(a.get("potential", 0)) > int(b.get("potential", 0)))
	return sellable


func sell_highest_wasted_potential_to_gideon() -> Dictionary:
	var sellable := get_sellable_wasted_potential_items()
	if sellable.is_empty():
		return {}

	var sale: Dictionary = sellable[0]
	var item_name := str(sale.get("item_name", ""))
	if item_name.is_empty() or not spend_item(item_name):
		return {}

	var wan_notes := int(sale.get("wan_notes", 0))
	var potential := int(sale.get("potential", 0))
	add_item(WAN_NOTE_ITEM, wan_notes)
	add_dreaming_generator_potential(potential)
	sale["wan_notes"] = wan_notes
	sale["potential"] = potential
	sale["new_generator_potential"] = get_dreaming_generator_potential()
	last_mission_result = "Sold %s to Gideon for %d Wan Notes" % [item_name, wan_notes]
	return sale


func add_dreaming_generator_potential(amount: int) -> int:
	var current := get_dreaming_generator_potential()
	current = clampi(current + amount, 0, DREAMING_GENERATOR_MAX_POTENTIAL)
	set_world_flag(DREAMING_GENERATOR_POTENTIAL_FLAG, current)
	return current


func consume_dreaming_generator_potential(amount: int) -> int:
	var current := get_dreaming_generator_potential()
	current = clampi(current - amount, 0, DREAMING_GENERATOR_MAX_POTENTIAL)
	set_world_flag(DREAMING_GENERATOR_POTENTIAL_FLAG, current)
	return current


func get_dreaming_generator_potential() -> int:
	return int(get_world_flag(DREAMING_GENERATOR_POTENTIAL_FLAG, 30))


func is_dreaming_generator_failing() -> bool:
	return get_dreaming_generator_potential() < DREAMING_GENERATOR_THRESHOLD


func add_reputation(faction_name: String, amount: int) -> void:
	reputation[faction_name] = int(reputation.get(faction_name, 0)) + amount
	reputation_changed.emit(get_faction_summary())


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
	for card_id: String in COOTERS_JOBS[job_id].get("event_cards_on_accept", []):
		var card := WorldDirector.get_named_card(card_id)
		if not card.is_empty():
			EventDeckSystem.add_card(card)
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
	EventDeckSystem.remove_cards_by_tag(job_id + "_active")
	for card_id: String in job.get("event_cards_on_complete", []):
		var card := WorldDirector.get_named_card(card_id)
		if not card.is_empty():
			EventDeckSystem.add_card(card)
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
		"quest_states": quest_states,
		"cybernetics": cybernetics,
		"last_mission_result": last_mission_result,
		"event_deck": EventDeckSystem.get_deck_for_save(),
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
	available_jobs = parsed.get("available_jobs", COOTERS_JOBS.keys())
	for job_id in COOTERS_JOBS.keys():
		if not available_jobs.has(job_id):
			available_jobs.append(job_id)
	completed_jobs = parsed.get("completed_jobs", {})
	job_flags = parsed.get("job_flags", {})
	world_flags = parsed.get("world_flags", {})
	quest_states = parsed.get("quest_states", {})
	cybernetics = parsed.get("cybernetics", {})
	last_mission_result = str(parsed.get("last_mission_result", ""))
	EventDeckSystem.restore_from_save(parsed.get("event_deck", []))
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


# ── Unified quest system ────────────────────────────────────────────

func start_quest(quest_id: String) -> bool:
	if not QUEST_DEFS.has(quest_id):
		return false
	if not quest_states.has(quest_id):
		quest_states[quest_id] = {"objectives": {}}
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("active_flag"):
		set_world_flag(str(def.get("active_flag")), true)
	return true


func is_quest_started(quest_id: String) -> bool:
	if quest_states.has(quest_id):
		return true
	# Backward compat: fall back to active_flag world_flag for pre-unified saves
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("active_flag"):
		return bool(get_world_flag(str(def.get("active_flag"))))
	return false


func mark_quest_objective(quest_id: String, obj_id: String) -> void:
	if not quest_states.has(quest_id):
		quest_states[quest_id] = {"objectives": {}}
	var state: Dictionary = quest_states[quest_id]
	if not state.has("objectives"):
		state["objectives"] = {}
	state["objectives"][obj_id] = true
	# Propagate to world_flag if the objective defines one
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	for obj in def.get("objectives", []):
		if str((obj as Dictionary).get("id", "")) == obj_id:
			var done_flag := str((obj as Dictionary).get("done_flag", ""))
			if not done_flag.is_empty():
				set_world_flag(done_flag, true)
			break


func is_quest_step_done(quest_id: String, obj_id: String) -> bool:
	var qs: Dictionary = quest_states.get(quest_id, {})
	var objs: Dictionary = qs.get("objectives", {})
	if bool(objs.get(obj_id, false)):
		return true
	# Also accept direct world_flag if the objective declares a done_flag
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	for obj in def.get("objectives", []):
		if str((obj as Dictionary).get("id", "")) == obj_id:
			var done_flag := str((obj as Dictionary).get("done_flag", ""))
			if not done_flag.is_empty():
				return bool(get_world_flag(done_flag))
	return false


func can_complete_quest(quest_id: String) -> bool:
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.is_empty():
		return false
	for obj in def.get("objectives", []):
		if bool((obj as Dictionary).get("required", false)):
			if not is_quest_step_done(quest_id, str((obj as Dictionary).get("id", ""))):
				return false
	return true


func complete_quest(quest_id: String) -> void:
	mark_quest_completed(quest_id)
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("done_flag"):
		set_world_flag(str(def.get("done_flag")), true)
	if quest_states.has(quest_id):
		quest_states[quest_id]["completed"] = true
	else:
		quest_states[quest_id] = {"objectives": {}, "completed": true}


func get_quest_objective_text(quest_id: String) -> String:
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.is_empty():
		return ""
	if is_quest_completed(quest_id):
		return str(def.get("objective_text_done", str(def.get("title", quest_id)) + " complete."))
	if def.has("objective_text_active"):
		return str(def.get("objective_text_active", ""))
	# Campaign quests: build from objectives list
	var objs: Array = def.get("objectives", [])
	if objs.is_empty():
		return str(def.get("title", quest_id)) + ": in progress."
	var parts: PackedStringArray = []
	for obj in objs:
		var done := is_quest_step_done(quest_id, str((obj as Dictionary).get("id", "")))
		var label := str((obj as Dictionary).get("id", "")).replace("_", " ")
		parts.append("%s (%s)" % [label, "done" if done else "needed"])
	return "%s: %s" % [str(def.get("title", quest_id)), ", ".join(parts)]


func get_active_hub_quests() -> Array:
	var result: Array = []
	for quest_id in QUEST_DEFS.keys():
		var def: Dictionary = QUEST_DEFS.get(quest_id, {})
		if str(def.get("type", "")) != "hub":
			continue
		if not is_quest_started(quest_id):
			continue
		if is_quest_completed(quest_id):
			continue
		result.append({
			"id": quest_id,
			"title": str(def.get("title", quest_id)),
			"objective_text": get_quest_objective_text(quest_id),
		})
	return result
