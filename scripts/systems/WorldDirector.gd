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


func roll_travel_event(route_id: String) -> Dictionary:
	var total_weight := 0
	for card in TRAVEL_EVENT_CARDS:
		total_weight += int(card.get("weight", 1))

	var roll := randi_range(1, maxi(total_weight, 1))
	var cursor := 0
	var selected: Dictionary = TRAVEL_EVENT_CARDS[0].duplicate(true)
	for card in TRAVEL_EVENT_CARDS:
		cursor += int(card.get("weight", 1))
		if roll <= cursor:
			selected = card.duplicate(true)
			break

	var event_id := str(selected.get("event", EVENT_CLEAR))
	if EVENTS.has(event_id):
		trigger_event(event_id)
	selected["route_id"] = route_id
	GameState.set_world_flag("last_travel_event", str(selected.get("id", "")))
	GameState.set_world_flag("last_travel_event_title", str(selected.get("title", "")))
	GameState.set_world_flag("last_travel_route", route_id)
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
