extends Node

signal world_state_changed(summary: String)

const REGION_FADED_ATRIUM := "faded_atrium"
const REGION_SUB_BASEMENT := "sub_sub_basement"

const EVENT_CLEAR := "clear"
const EVENT_TOXIC_RAIN := "toxic_rain"
const EVENT_POWER_SAG := "power_sag"
const EVENT_LAN_OUTAGE := "lan_outage"

const GENERATOR_STABLE := "stable"
const GENERATOR_SAGGING := "sagging"
const GENERATOR_OVERLOADED := "overloaded"
const GENERATOR_OFFLINE := "offline"

const REGIONS := {
	REGION_FADED_ATRIUM: {
		"name": "Faded Atrium",
		"brief": "Counterfeit mall comfort under a leaking artificial sky, still insisting it is retail therapy.",
		"pressure": "stable, watched",
	},
	REGION_SUB_BASEMENT: {
		"name": "Sub-Sub-Basement",
		"brief": "Leak Street, one wet patchwork settlement lane pretending the larger lower-city sprawl is not breathing behind it.",
		"pressure": "crowded, watched, larger than it looks",
	},
}

const EVENTS := {
	EVENT_CLEAR: {
		"name": "clear",
		"hud": "SKY  false daylight",
		"brief": "The artificial ceiling is pretending to be weather and doing community theater about daylight.",
	},
	EVENT_TOXIC_RAIN: {
		"name": "toxic rain",
		"hud": "SKY  toxic rain",
		"brief": "Industrial runoff is falling from the fake sky. Shelter and sealed gear matter unless you enjoy becoming a cautionary texture.",
	},
	EVENT_POWER_SAG: {
		"name": "power sag",
		"hud": "GRID  sagging",
		"brief": "Generators are coughing. Doors, lights, and cheap cybernetics are unreliable in that personal way machines get.",
	},
	EVENT_LAN_OUTAGE: {
		"name": "LAN outage",
		"hud": "GRID  hoodlum outage",
		"brief": "Hoodlums hijacked the grid for an illegal LAN party. Surveillance is blind in patches and pretending this is beneath it.",
	},
}

const TRAVEL_EVENT_CARDS := [
	{
		"id": "clear",
		"title": "Clear Run",
		"event": EVENT_CLEAR,
		"weight": 3,
		"text": "The route opens clean. The fake sky watches without spending weather, generous little ceiling that it is.",
	},
	{
		"id": "toxic_rain",
		"title": "Toxic Rain",
		"event": EVENT_TOXIC_RAIN,
		"weight": 2,
		"text": "The ceiling starts leaking industrial weather before you reach the turnstiles. Timing like a heckler with plumbing access.",
	},
	{
		"id": "power_sag",
		"title": "Power Sag",
		"event": EVENT_POWER_SAG,
		"weight": 2,
		"text": "The grid coughs. Streetlights dim and every terminal sounds like it owes money to someone with thumbs.",
	},
	{
		"id": "lan_outage",
		"title": "LAN Outage",
		"event": EVENT_LAN_OUTAGE,
		"weight": 1,
		"text": "Hoodlum packets flood the route. Cameras blink out in suspiciously useful order, very tragic, thoughts and prayers.",
	},
	{
		"id": "quiet_shortcut",
		"title": "Quiet Shortcut",
		"event": EVENT_CLEAR,
		"weight": 1,
		"text": "A maintenance door gives up. No one admits they saw you use it, which is the closest this city gets to privacy.",
	},
]

const NAMED_CARDS: Dictionary = {
	"pipe_blood_sample_exit": {
		"id": "pipe_blood_sample_exit", "title": "Pipe Condition Report",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "pipe_blood_sample"},
		"effects": [], "expires_after": 1, "tags": ["pipe_blood_sample_active"],
		"speaker": "Marbles",
		"text": "The blood moves upward on odd days. Today is odd. Sealed bulb or it wins the argument.",
	},
	"pipe_blood_sample_travel": {
		"id": "pipe_blood_sample_travel", "title": "Pipe Pressure Spike",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "pipe_blood_sample"},
		"effects": [{"type": "set_event", "event_id": "toxic_rain"}],
		"expires_after": -1, "tags": ["pipe_blood_sample_active"],
		"speaker": "System X",
		"text": "Pipe pressure elevated in the utility corridor. The ceiling has decided today is billable.",
	},
	"pipe_blood_sample_return": {
		"id": "pipe_blood_sample_return", "title": "Pipe Blood Catalogued",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "Sample catalogued. It moved three times in unspecified directions. Marbles is quietly excited and professionally refusing to admit it.",
	},
	"ratchet_saint_exit": {
		"id": "ratchet_saint_exit", "title": "Saint Ratchet Directions",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "ratchet_saint"},
		"effects": [], "expires_after": 1, "tags": ["ratchet_saint_active"],
		"speaker": "Marbles",
		"text": "Gideon says Saint Ratchet hums when it is close to the surface. Bolt-pitch harmonics. Go toward them.",
	},
	"ratchet_saint_travel": {
		"id": "ratchet_saint_travel", "title": "Pipe Chapel Signal",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "ratchet_saint"},
		"effects": [], "expires_after": -1, "tags": ["ratchet_saint_active"],
		"speaker": "Pipe Father Gideon",
		"text": "The Saint fell because the pipe trusted weight it could not carry. That is a sermon and also directions.",
	},
	"ratchet_saint_return": {
		"id": "ratchet_saint_return", "title": "Saint Ratchet Returned",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "set_flag", "flag": "saint_ratchet_returned", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "Pipe Father Gideon",
		"text": "Saint Ratchet is returned. The generator hums different. Do not tell Wan Moa Torai it is doing anything miraculous or they will invoice the miracle.",
	},
	"listen_pipes_exit": {
		"id": "listen_pipes_exit", "title": "Pipe Frequency Tip",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "listen_to_the_pipes"},
		"effects": [], "expires_after": 1, "tags": ["listen_to_the_pipes_active"],
		"speaker": "Ladderboy",
		"text": "The pipes get loud around the drain at third power cycle. Recorder needs to be within two meters or all you get is institutional breathing.",
	},
	"listen_pipes_travel": {
		"id": "listen_pipes_travel", "title": "LAN Pipe Tap",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "listen_to_the_pipes"},
		"effects": [{"type": "set_event", "event_id": "lan_outage"}],
		"expires_after": -1, "tags": ["listen_to_the_pipes_active"],
		"speaker": "System X",
		"text": "LAN spike in the utility corridor. Someone else is also listening to the pipes today. First one with a recording wins, probably.",
	},
	"listen_pipes_return": {
		"id": "listen_pipes_return", "title": "Pipes Catalogue Updated",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "set_flag", "flag": "pipes_catalogue_updated", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "The recording is in the catalogue. The pipes said something in three distinct registers. Two were complaints. One was a warning we are still translating.",
	},
	"food_court_exit": {
		"id": "food_court_exit", "title": "Bloom Route Advice",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "food_court_filter"},
		"effects": [], "expires_after": 1, "tags": ["food_court_filter_active"],
		"speaker": "Marbles",
		"text": "The bloom is worst near the condiment bar. Upper ring is slower but your ankles survive at the same rate your dignity does, which is one to one.",
	},
	"food_court_travel": {
		"id": "food_court_travel", "title": "Bloom Grid Interference",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "food_court_filter"},
		"effects": [{"type": "set_event", "event_id": "power_sag"}],
		"expires_after": -1, "tags": ["food_court_filter_active"],
		"speaker": "System X",
		"text": "The bloom has worked into the grid junction near the food court. Power is unreliable. Cheap cybernetics will complain about this personally.",
	},
	"food_court_return": {
		"id": "food_court_return", "title": "Torai Filter Credit",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": [],
		"speaker": "Kiki Baja",
		"text": "Clean filter out of the bloom court. Torai has already opened a ledger entry for the clean water credit. Gratitude here is shaped like paperwork.",
	},
	"cistern_exit": {
		"id": "cistern_exit", "title": "Live Conduit Warning",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "cistern_pump_heart"},
		"effects": [], "expires_after": 1, "tags": ["cistern_pump_heart_active"],
		"speaker": "Marbles",
		"text": "The live conduit is real. Do not step in the water near it. Torai will say they are sorry and then invoice the emergency response.",
	},
	"cistern_travel": {
		"id": "cistern_travel", "title": "Torai Lease Check",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "cistern_pump_heart"},
		"effects": [{"type": "set_event", "event_id": "lan_outage"}],
		"expires_after": -1, "tags": ["cistern_pump_heart_active"],
		"speaker": "Brickmouth Ronnie",
		"text": "Torai network check on the pump heart lease just went active. They are watching the approach. Surveillance blind spot is your friend today.",
	},
	"cistern_return": {
		"id": "cistern_return", "title": "Torai Lease Cleared",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "add_rep", "faction": "Wan Moa Torai", "amount": 1}],
		"expires_after": 0, "tags": [],
		"speaker": "Brickmouth Ronnie",
		"text": "Pump core returned. Torai cleared the lease flag. Your ledger is one line shorter, which is as close to forgiveness as the office gets.",
	},
	"atrium_relay_exit": {
		"id": "atrium_relay_exit", "title": "Catwalk Warning",
		"contexts": ["district_exit"], "weight": 2,
		"conditions": {"active_job": "atrium_relay_echo"},
		"effects": [], "expires_after": 1, "tags": ["atrium_relay_echo_active"],
		"speaker": "Marbles",
		"text": "The catwalk above the sludge gap is load-bearing until it decides it is not. Trust the north side. The south side has been making its own decisions for three months.",
	},
	"atrium_relay_travel": {
		"id": "atrium_relay_travel", "title": "Relay Grid Interference",
		"contexts": ["travel"], "weight": 2,
		"conditions": {"active_job": "atrium_relay_echo"},
		"effects": [{"type": "set_event", "event_id": "power_sag"}],
		"expires_after": -1, "tags": ["atrium_relay_echo_active"],
		"speaker": "System X",
		"text": "The relay is still broadcasting. Grid sag in the atrium approach is interference from the signal, not malfunction. Probably.",
	},
	"atrium_relay_return": {
		"id": "atrium_relay_return", "title": "Relay Data Logged",
		"contexts": ["hub_return"], "weight": 3,
		"conditions": {}, "effects": [{"type": "set_flag", "flag": "atrium_relay_data_logged", "value": true}],
		"expires_after": 0, "tags": [],
		"speaker": "System X",
		"text": "Relay packet received. The mall is still saying something in a frequency that predates the corporate reformat. We are not sure if it is a warning or a customer service survey.",
	},
	"splice_pipes_return": {
		"id": "splice_pipes_return", "title": "Splice In The Tunnels",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "Marbles",
		"text": "One in the west passage. Former maintenance, Torai integration frame still running whatever it thinks maintenance is. Did not respond to the safety signal. Did respond to the scrap pistol. In retrospect, same outcome.",
	},
	"splice_bloom_return": {
		"id": "splice_bloom_return", "title": "Splice In The Bloom",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "Marbles",
		"text": "Splice in the growth pit. The bloom had started using it as a route anchor. Whatever Torai installed in it, the plants do not mind the frame. This is either biologically interesting or structurally concerning. I am going with both.",
	},
	"splice_cistern_return": {
		"id": "splice_cistern_return", "title": "Splice Near The Water",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "Marbles",
		"text": "One on the east walkway. The Torai frame kept it dry. Water does not bother them because Torai sealed the integration points on install. At least the contract waterproofed.",
	},
	"splice_atrium_return": {
		"id": "splice_atrium_return", "title": "Splice Below The Catwalk",
		"contexts": ["hub_return"], "weight": 2,
		"conditions": {}, "effects": [], "expires_after": 0, "tags": ["splice_encounter"],
		"speaker": "System X",
		"text": "Splice on the atrium ground floor. Below the catwalk. Below the sludge line. This is not reassurance. This is a current arrangement that the sludge does not care about.",
	},
	"splice_travel_warning": {
		"id": "splice_travel_warning", "title": "Splice Activity",
		"contexts": ["travel"], "weight": 1,
		"conditions": {}, "effects": [], "expires_after": -1, "tags": ["splice_ambient"],
		"speaker": "Ladderboy",
		"text": "Movement near the utility junction. Torai integration frame, organic component still present. They remember walls. They do not remember you. Aim for the Graft Shell.",
	},
}

const FACTIONS := {
	"System X": {
		"stance": "improvisation over control",
		"summary": "Digital resistance maintained by Pee Kid and Yoko through terminals, drones, and agents.",
	},
	"Gatebox Corporation": {
		"stance": "comfort through ownership",
		"summary": "Corporate care systems expanding into every private corner of life.",
	},
	"Wan Moa Torai": {
		"stance": "because everyone deserves one more try",
		"summary": "Debt, bars, housing, salvage contracts, and contradictory offices that all somehow count.",
	},
	"Linda": {
		"stance": "freedom creates suffering",
		"summary": "Still human, still brilliant, and already converting care into control.",
	},
}

var current_region := REGION_FADED_ATRIUM
var active_event := EVENT_CLEAR
var generator_state := GENERATOR_SAGGING

var event_cycle_timer := 0.0
var event_cycle_interval := 45.0
var event_paused := false


func _ready() -> void:
	restore_from_game_state()
	_publish_state()


func _process(delta: float) -> void:
	if event_paused:
		return
	if generator_state == GENERATOR_STABLE and active_event == EVENT_CLEAR:
		return
	if active_event == EVENT_LAN_OUTAGE:
		return

	event_cycle_timer += delta
	if event_cycle_timer >= event_cycle_interval:
		event_cycle_timer = 0.0
		_auto_cycle_event()


func _auto_cycle_event() -> void:
	match active_event:
		EVENT_CLEAR:
			if generator_state != GENERATOR_STABLE:
				trigger_event(EVENT_TOXIC_RAIN)
		EVENT_TOXIC_RAIN:
			trigger_event(EVENT_POWER_SAG)
		EVENT_POWER_SAG:
			trigger_event(EVENT_CLEAR)


func restore_from_game_state() -> void:
	var saved_region := str(GameState.get_world_flag("current_region", current_region))
	var saved_event := str(GameState.get_world_flag("active_world_event", active_event))
	var saved_generator_state := str(GameState.get_world_flag("generator_state", generator_state))
	if REGIONS.has(saved_region):
		current_region = saved_region
	if EVENTS.has(saved_event):
		active_event = saved_event
	if _is_valid_generator_state(saved_generator_state):
		generator_state = saved_generator_state


func set_region(region_id: String) -> void:
	if not REGIONS.has(region_id):
		return

	current_region = region_id
	GameState.set_world_flag("current_region", current_region)
	_publish_state()


func trigger_event(event_id: String) -> void:
	if not EVENTS.has(event_id):
		return

	active_event = event_id
	GameState.set_world_flag("active_world_event", active_event)
	_publish_state()


func clear_event() -> void:
	trigger_event(EVENT_CLEAR)


func get_named_card(card_id: String) -> Dictionary:
	var card: Dictionary = NAMED_CARDS.get(card_id, {})
	return card.duplicate(true) if not card.is_empty() else {}


func roll_travel_event(route_id: String) -> Dictionary:
	var pool: Array = []
	for card in TRAVEL_EVENT_CARDS:
		pool.append(card.duplicate(true))
	pool.append_array(EventDeckSystem.get_candidates("travel"))

	var total_weight := 0
	for card in pool:
		total_weight += int(card.get("weight", 1))

	var roll := randi_range(1, maxi(total_weight, 1))
	var cursor := 0
	var selected: Dictionary = pool[0].duplicate(true)
	for card in pool:
		cursor += int(card.get("weight", 1))
		if roll <= cursor:
			selected = card.duplicate(true)
			break

	if selected.has("effects"):
		EventDeckSystem.apply_and_expire(selected)
	else:
		var event_id := str(selected.get("event", EVENT_CLEAR))
		if EVENTS.has(event_id):
			trigger_event(event_id)

	selected["route_id"] = route_id
	GameState.set_world_flag("last_travel_event", str(selected.get("id", "")))
	GameState.set_world_flag("last_travel_event_title", str(selected.get("title", "")))
	GameState.set_world_flag("last_travel_route", route_id)
	return selected


func roll_context_event(context: String) -> Dictionary:
	var candidates := EventDeckSystem.get_candidates(context)
	if candidates.is_empty():
		return {}

	var total_weight := 0
	for card in candidates:
		total_weight += int(card.get("weight", 1))

	var roll := randi_range(1, maxi(total_weight, 1))
	var cursor := 0
	var selected: Dictionary = candidates[0].duplicate(true)
	for card in candidates:
		cursor += int(card.get("weight", 1))
		if roll <= cursor:
			selected = card.duplicate(true)
			break

	EventDeckSystem.apply_and_expire(selected)
	return selected


func set_generator_state(state: String) -> void:
	if not _is_valid_generator_state(state):
		return

	generator_state = state
	GameState.set_world_flag("generator_state", generator_state)
	_publish_state()


func get_generator_state() -> String:
	return generator_state


func is_toxic_rain_active() -> bool:
	return active_event == EVENT_TOXIC_RAIN


func is_power_unstable() -> bool:
	return active_event == EVENT_POWER_SAG or active_event == EVENT_LAN_OUTAGE or generator_state in [GENERATOR_SAGGING, GENERATOR_OVERLOADED, GENERATOR_OFFLINE]


func get_event_damage_per_second() -> float:
	if active_event == EVENT_TOXIC_RAIN:
		return 2.0
	return 0.0


func get_region_name() -> String:
	return str(REGIONS.get(current_region, {}).get("name", "Unknown Region"))


func get_region_brief() -> String:
	return str(REGIONS.get(current_region, {}).get("brief", ""))


func get_event_name() -> String:
	return str(EVENTS.get(active_event, {}).get("name", "clear"))


func get_event_brief() -> String:
	return str(EVENTS.get(active_event, {}).get("brief", ""))


func get_hud_summary() -> String:
	var event_data: Dictionary = EVENTS.get(active_event, EVENTS[EVENT_CLEAR])
	return "%s  %s  GEN %s  POT %d/%d" % [
		str(event_data.get("hud", "SKY  false daylight")),
		get_region_name(),
		generator_state,
		GameState.get_dreaming_generator_potential(),
		GameState.DREAMING_GENERATOR_THRESHOLD,
	]


func get_status_lines() -> Array[String]:
	var region_data: Dictionary = REGIONS.get(current_region, REGIONS[REGION_FADED_ATRIUM])
	return [
		"REGION  %s" % get_region_name(),
		"PRESSURE  %s" % str(region_data.get("pressure", "unknown")),
		"EVENT  %s" % get_event_name(),
		"GENERATOR  %s  POTENTIAL %d/%d" % [generator_state, GameState.get_dreaming_generator_potential(), GameState.DREAMING_GENERATOR_THRESHOLD],
		get_event_brief(),
	]


func get_event_status_lines() -> Array[String]:
	var lines: Array[String] = [
		"EVENT  %s" % get_event_name(),
		"GENERATOR  %s  POTENTIAL %d/%d" % [generator_state, GameState.get_dreaming_generator_potential(), GameState.DREAMING_GENERATOR_THRESHOLD],
	]
	if GameState.get_world_flag("suitors_surveillance_jammed"):
		lines.append("SURVEILLANCE  Sunday's blind spot active")
	if active_event == EVENT_TOXIC_RAIN:
		lines.append("HAZARD  exposed bodies take corrosion damage")
	elif active_event == EVENT_POWER_SAG:
		lines.append("HAZARD  terminals and cheap cybernetics are unreliable")
	elif active_event == EVENT_LAN_OUTAGE:
		lines.append("HAZARD  surveillance blind spots, generator stress")
	else:
		lines.append("HAZARD  none")
	return lines


func get_faction_brief_lines() -> Array[String]:
	var lines: Array[String] = ["LOWER CITY"]
	for faction_name in FACTIONS.keys():
		var faction_data: Dictionary = FACTIONS[faction_name]
		lines.append("%s  %s" % [faction_name, str(faction_data.get("stance", ""))])
	return lines


func get_establishment_lines() -> Array[String]:
	return [
		"ESTABLISHMENTS",
		"Cooters  dive bar, rumors, fights, criminal jobs",
		"Suitors  System X lounge, surveillance choir, impossible calm",
		"Wan Moa Torai Offices  debt, permits, salvage contracts",
	]


func _publish_state() -> void:
	world_state_changed.emit(get_hud_summary())


func _is_valid_generator_state(state: String) -> bool:
	return state in [GENERATOR_STABLE, GENERATOR_SAGGING, GENERATOR_OVERLOADED, GENERATOR_OFFLINE]
