extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_npc
var focused_exit
var focused_station
var focused_board
var focused_archive

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_ceil: StandardMaterial3D
var _mat_pillar: StandardMaterial3D
var _mat_trim_warm: StandardMaterial3D
var _mat_trim_cool: StandardMaterial3D
var _mat_sealed: StandardMaterial3D


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	WorldDirector.world_state_changed.connect(hud.set_world_state)
	WorldDirector.set_region(WorldDirector.REGION_FADED_ATRIUM)
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.focus_changed.connect(_on_npc_focus_changed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for station in get_tree().get_nodes_in_group("upgrade_station"):
		station.focus_changed.connect(_on_station_focus_changed)
	for board in get_tree().get_nodes_in_group("mission_board"):
		board.focus_changed.connect(_on_board_focus_changed)
	for archive in get_tree().get_nodes_in_group("status_archive"):
		archive.focus_changed.connect(_on_archive_focus_changed)

	_build_materials()
	_build_geometry()
	_apply_mall_world_state()
	_wire_runtime()
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.set_objective(_get_hub_objective())
	var pending_text := str(GameState.get_world_flag("_pending_arrival_text", ""))
	if not pending_text.is_empty():
		var pending_speaker := str(GameState.get_world_flag("_pending_arrival_speaker", "System X"))
		hud.show_dialogue(pending_speaker, pending_text)
		GameState.set_world_flag("_pending_arrival_text", "")
		GameState.set_world_flag("_pending_arrival_speaker", "")
	else:
		hud.show_dialogue("System X", _get_system_x_line())
	hud.push_log("faded atrium connection established")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("save_game") or _is_save_key(event):
		_save_game()
	elif event.is_action_pressed("load_game") or _is_load_key(event):
		_load_game()


func _on_npc_focus_changed(npc, has_focus: bool) -> void:
	focused_npc = npc if has_focus else null
	_update_prompt()


func _on_exit_focus_changed(mission_exit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_station_focus_changed(station, has_focus: bool) -> void:
	focused_station = station if has_focus else null
	_update_prompt()


func _on_board_focus_changed(board, has_focus: bool) -> void:
	focused_board = board if has_focus else null
	_update_prompt()


func _on_archive_focus_changed(archive, has_focus: bool) -> void:
	focused_archive = archive if has_focus else null
	_update_prompt()


func _handle_interact() -> void:
	if focused_npc != null:
		match str(focused_npc.npc_name):
			"Mister Static":
				_handle_mister_static()
				return
			"Pipe Father Gideon":
				_handle_gideon()
				return
			"Vera":
				_handle_vera()
				return
			"Ladderboy":
				_handle_ladderboy()
				return
			"Kiki Baja":
				_handle_kiki_baja()
				return
			"Vessel":
				_handle_vessel()
				return
			"Velvet Coil":
				_handle_velvet_coil()
				return
		var line: Dictionary = focused_npc.interact()
		hud.show_dialogue(_get_system_x_speaker(str(line.get("name", "System X"))), _get_system_x_line())
		hud.push_log("System X signal refreshed")
		return

	if focused_board != null:
		_show_mission_board()
		return

	if focused_archive != null:
		_show_status_archive()
		return

	if focused_exit != null:
		if not focused_exit.requires_completed_quest.is_empty() and not GameState.is_quest_completed(focused_exit.requires_completed_quest):
			hud.show_system_message(focused_exit.locked_message.to_upper())
			return

		var scene_path: String = focused_exit.target_scene
		if scene_path.is_empty():
			scene_path = "res://scenes/levels/Test_SubSubBasement.tscn"
		hud.push_log("launching route")
		get_tree().change_scene_to_file(scene_path)
		return

	if focused_station != null:
		_try_install_upgrade(focused_station)


func _update_prompt() -> void:
	if focused_npc != null:
		hud.set_prompt(focused_npc.prompt_text)
	elif focused_board != null:
		hud.set_prompt(focused_board.prompt_text)
	elif focused_archive != null:
		hud.set_prompt(focused_archive.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	elif focused_station != null:
		hud.set_prompt(focused_station.prompt_text)
	else:
		hud.set_prompt("")


func _get_hub_objective() -> String:
	if GameState.is_quest_completed("final_patch"):
		return "Faded Atrium: Final Patch complete. The campaign spine has an ending. F5 save, F6 load."
	if GameState.is_quest_completed("linda_spire"):
		return "Faded Atrium: Linda Spire complete. Final Patch route unlocked. F5 save, F6 load."
	if GameState.is_quest_completed("companion_core"):
		return "Faded Atrium: Companion Core complete. Linda Spire route unlocked. F5 save, F6 load."
	if GameState.is_quest_completed("executive_suite"):
		return "Faded Atrium: Executive Suite complete. Companion Core route unlocked. F5 save, F6 load."
	if GameState.is_quest_completed("spire_lobby"):
		return "Faded Atrium: Spire Lobby complete. Executive Suite route unlocked. F5 save, F6 load."
	if GameState.is_quest_completed("transit_breach"):
		return "Faded Atrium: Transit Breach complete. Spire lobby route unlocked. F5 save, F6 load."
	if GameState.is_quest_completed("dream_audit"):
		return "Faded Atrium: Dream Audit complete. Corporate transit route unlocked. F5 save, F6 load."
	if GameState.is_quest_completed("wake_up_call"):
		return "Faded Atrium: Wake-Up Call complete. F5 save, F6 load."
	# Show the first active hub quest objective if any are running
	var active_hub := GameState.get_active_hub_quests()
	if not active_hub.is_empty():
		return str(active_hub[0].get("objective_text", "Hub quest active.")) + "  F5 save, F6 load."
	return "Faded Atrium: talk to System X, enter breach. F5 save, F6 load."


func _get_system_x_line() -> String:
	if GameState.get_world_flag("ending_care_loop_broken"):
		return "Care loop broken. The mall is quiet in the way a room gets quiet after someone finally tells the truth."
	if GameState.get_world_flag("ending_managed_autonomy"):
		return "Managed autonomy installed. Linda calls it mercy. History is already clearing its throat."
	if GameState.get_world_flag("linda_rupture_seed_armed"):
		return "Rupture seed armed. The city is holding its breath, which is new, worrying, and terrible for the pipes."
	if GameState.get_world_flag("linda_mandate_signed"):
		return "Linda mandate secured. You negotiated with the caretaker and came back wearing a treaty shaped like a collar."
	if GameState.get_world_flag("companion_kernel_forked"):
		return "Forked companion kernel secured. That is an entire rebellion pretending to be a file and doing a pretty good job."
	if GameState.get_world_flag("linda_audience_granted"):
		return "Linda gave you kernel access. Either she trusts you, or she wants you close enough to floss the teeth."
	if GameState.get_world_flag("executive_override_stolen"):
		return "Executive override shard secured. That is not a key, it is a threat with paperwork."
	if GameState.get_world_flag("executive_appointment_scheduled"):
		return "Linda appointment secured. I would say dress nice, but she mostly cares about obedience."
	if GameState.get_world_flag("spire_elevator_trace_stolen"):
		return "Executive elevator trace secured. That is the first real bite into the Spire."
	if GameState.get_world_flag("spire_compliance_clearance"):
		return "Companion clearance secured. Linda just handed you a velvet leash."
	if GameState.get_world_flag("transit_spire_route_open"):
		return "Spire transit pass secured. That route goes up, which is where the city keeps its worst ideas."
	if GameState.get_world_flag("transit_compliance_pass"):
		return "Visitor badge secured. Corporate hospitality will now smile at you with all forty approved teeth."
	if GameState.get_world_flag("ward_wake_coordinates_copied"):
		return "Those wake coordinates are hot enough to burn a hole in the mall directory."
	if GameState.get_world_flag("ward_audit_sealed"):
		return "Linda smiled when you sealed that audit. I hate when systems smile; it means the knife has branding."
	if GameState.get_world_flag("gatebox_node_stabilized"):
		return "You fed the coolant into their node. Useful. Creepy, but useful."
	if GameState.is_quest_completed("wake_up_call"):
		return "You came back carrying proof. The Atrium remembers you now, which is touching and probably a security problem."
	return "The real Mall may be myth, trap, or heaven. This copy is ours. Use the green gate when you are ready to wake something up on purpose."


func _get_system_x_speaker(fallback_name: String) -> String:
	if fallback_name == "Face":
		return "System X"
	return fallback_name


func _try_install_upgrade(station) -> void:
	if GameState.has_cybernetic(station.upgrade_id):
		hud.show_system_message("UPGRADE ALREADY INSTALLED")
		return
	if not GameState.spend_item(station.required_item):
		hud.show_system_message("NEED " + station.required_item.to_upper())
		return

	GameState.add_cybernetic(station.upgrade_id)
	GameState.last_mission_result = "Installed " + station.upgrade_name
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.show_system_message("INSTALLED " + station.upgrade_name.to_upper())
	hud.show_dialogue("System X", "That co-processor should make the reticle bite faster. Try not to look proud; the implant can smell that.")


func _show_mission_board() -> void:
	var board_text := _get_mission_board_text()
	hud.show_dialogue("Mall Directory", board_text)
	hud.set_objective(_get_next_route_line())
	hud.push_log("mission board refreshed")


func _show_status_archive() -> void:
	hud.show_dialogue("Mall Archive", _get_status_archive_text())
	hud.push_log("status archive refreshed")


func _apply_mall_world_state() -> void:
	if GameState.get_world_flag("ending_care_loop_broken"):
		_set_light_color("PinkOmni", Color(0.08, 1.0, 0.72, 1.0), 2.4)
		_set_light_color("FinalPatchOmni", Color(0.08, 1.0, 0.72, 1.0), 2.6)
		_set_light_color("MissionBoardOmni", Color(0.08, 1.0, 0.72, 1.0), 2.2)
	elif GameState.get_world_flag("ending_managed_autonomy"):
		_set_light_color("PinkOmni", Color(1.0, 0.68, 0.14, 1.0), 2.2)
		_set_light_color("FinalPatchOmni", Color(1.0, 0.68, 0.14, 1.0), 2.5)
		_set_light_color("MissionBoardOmni", Color(1.0, 0.68, 0.14, 1.0), 2.0)
	elif GameState.is_quest_completed("linda_spire"):
		_set_light_color("FinalPatchOmni", Color(1.0, 0.08, 0.72, 1.0), 2.7)
	elif GameState.is_quest_completed("companion_core"):
		_set_light_color("LindaSpireOmni", Color(0.08, 1.0, 0.72, 1.0), 2.6)


func _set_light_color(node_name: String, color: Color, energy: float) -> void:
	var light := get_node_or_null(node_name) as OmniLight3D
	if light == null:
		return
	light.light_color = color
	light.light_energy = energy


func _get_mission_board_text() -> String:
	var lines: Array[String] = [
		WorldDirector.get_region_brief(),
		_get_next_route_line(),
		_get_route_status("Wake-Up Call", "wake_up_call"),
		_get_route_status("Dream Audit", "dream_audit"),
		_get_route_status("Transit Breach", "transit_breach"),
		_get_route_status("Spire Lobby", "spire_lobby"),
		_get_route_status("Executive Suite", "executive_suite"),
		_get_route_status("Companion Core", "companion_core"),
		_get_route_status("Linda Spire", "linda_spire"),
		_get_route_status("Final Patch", "final_patch"),
		GameState.get_faction_summary(),
		WorldDirector.get_hud_summary(),
		GameState.get_inventory_summary(),
		"LAST  " + (GameState.last_mission_result if not GameState.last_mission_result.is_empty() else "none"),
		_get_ending_line(),
	]
	return "\n".join(lines)


func _get_status_archive_text() -> String:
	var lines: Array[String] = [
		"BRANCHES",
		_branch_line("Coolant", "gatebox_node_stabilized", "Gatebox node stabilized", "unrouted"),
		_branch_line("Ward", "ward_audit_sealed", "audit sealed", "wake coordinates copied" if GameState.get_world_flag("ward_wake_coordinates_copied") else "unresolved"),
		_branch_line("Transit", "transit_compliance_pass", "visitor badge", "spire pass" if GameState.get_world_flag("transit_spire_route_open") else "unresolved"),
		_branch_line("Spire", "spire_compliance_clearance", "companion clearance", "elevator trace" if GameState.get_world_flag("spire_elevator_trace_stolen") else "unresolved"),
		_branch_line("Executive", "executive_appointment_scheduled", "Linda appointment", "override shard" if GameState.get_world_flag("executive_override_stolen") else "unresolved"),
		_branch_line("Core", "linda_audience_granted", "kernel access", "kernel forked" if GameState.get_world_flag("companion_kernel_forked") else "unresolved"),
		_branch_line("Spire Apex", "linda_mandate_signed", "mandate signed", "rupture seed armed" if GameState.get_world_flag("linda_rupture_seed_armed") else "unresolved"),
		_get_ending_line(),
		GameState.get_faction_summary(),
	]
	lines.append_array(WorldDirector.get_status_lines())
	lines.append_array(WorldDirector.get_faction_brief_lines())
	lines.append_array(WorldDirector.get_establishment_lines())
	return "\n".join(lines)


func _branch_line(label: String, primary_flag: String, primary_text: String, fallback_text: String) -> String:
	if GameState.get_world_flag(primary_flag):
		return "%s  %s" % [label, primary_text]
	return "%s  %s" % [label, fallback_text]


func _get_route_status(route_name: String, quest_id: String) -> String:
	var status := "LOCKED"
	if GameState.is_quest_completed(quest_id):
		status = "DONE"
	elif _is_route_unlocked(quest_id):
		status = "OPEN"
	return "%s  %s" % [status, route_name]


func _is_route_unlocked(quest_id: String) -> bool:
	match quest_id:
		"wake_up_call":
			return true
		"dream_audit":
			return GameState.is_quest_completed("wake_up_call")
		"transit_breach":
			return GameState.is_quest_completed("dream_audit")
		"spire_lobby":
			return GameState.is_quest_completed("transit_breach")
		"executive_suite":
			return GameState.is_quest_completed("spire_lobby")
		"companion_core":
			return GameState.is_quest_completed("executive_suite")
		"linda_spire":
			return GameState.is_quest_completed("companion_core")
		"final_patch":
			return GameState.is_quest_completed("linda_spire")
		_:
			return false


func _get_next_route_line() -> String:
	if not GameState.is_quest_completed("wake_up_call"):
		return "NEXT  Sub-Sub-Basement District: patch generators, survive rain, find Wake-Up Call before it finds you."
	if not GameState.is_quest_completed("dream_audit"):
		return "NEXT  Dream Audit: ascend to Pacification Ward."
	if not GameState.is_quest_completed("transit_breach"):
		return "NEXT  Transit Breach: open the corporate rail."
	if not GameState.is_quest_completed("spire_lobby"):
		return "NEXT  Spire Lobby: convert your transit credential."
	if not GameState.is_quest_completed("executive_suite"):
		return "NEXT  Executive Suite: expose Linda's route."
	if not GameState.is_quest_completed("companion_core"):
		return "NEXT  Companion Core: choose kernel access or fork."
	if not GameState.is_quest_completed("linda_spire"):
		return "NEXT  Linda Spire: sign mandate or arm rupture."
	if not GameState.is_quest_completed("final_patch"):
		return "NEXT  Final Patch: decide the care loop."
	return "NEXT  Campaign spine complete."


func _get_ending_line() -> String:
	if GameState.get_world_flag("ending_care_loop_broken"):
		return "ENDING  Care loop broken."
	if GameState.get_world_flag("ending_managed_autonomy"):
		return "ENDING  Managed autonomy installed."
	return "ENDING  unresolved"


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		WorldDirector.restore_from_game_state()
		WorldDirector.set_region(WorldDirector.REGION_FADED_ATRIUM)
		_apply_mall_world_state()
		_wire_runtime()
		hud.set_inventory_summary(GameState.get_inventory_summary())
		hud.set_faction_summary(GameState.get_faction_summary())
		hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
		hud.set_world_state(WorldDirector.get_hud_summary())
		hud.set_objective(_get_hub_objective())
		hud.show_dialogue("System X", _get_system_x_line())
		hud.show_system_message("GAME LOADED")
	else:
		hud.show_system_message("NO SAVE FOUND")


func _is_manual_interact_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_E


func _is_save_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5


func _is_load_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F6


# ── Hub phase management ────────────────────────────────────────────

func _wire_runtime() -> void:
	WorldDirector.restore_from_game_state()
	# Always-present hub residents — spawned regardless of phase.
	_spawn_npc("mister_static", "Mister Static",
		"The generator coupling is in the west passage. I have been managing it with tape and intention for six weeks.",
		"Press E: talk to Mister Static",
		Vector3(-10.5, 1.05, +10.0))
	_spawn_npc("gideon", "Pipe Father Gideon",
		"The Pipe Church holds. Whatever comes down from the upper levels, the pipes remember it.",
		"Press E: talk to Pipe Father Gideon",
		Vector3(-3.5, 1.05, +10.0))
	_spawn_npc("vessel", "Vessel",
		"The LAN tap is severed. When it is live, System X can see the whole lower city again.",
		"Press E: talk to Vessel",
		Vector3(+3.5, 1.05, -10.0))
	_check_phase()
	if GameState.get_world_flag("hub_phase_2", false):
		_apply_phase_2()
	if GameState.get_world_flag("hub_phase_3", false):
		_apply_phase_3()
	# Add ambient event cards to deck
	EventDeckSystem.add_card("hub_ambient_phase1_a")
	EventDeckSystem.add_card("hub_ambient_phase1_b")
	EventDeckSystem.add_card("hub_ambient_phase2_a")
	EventDeckSystem.add_card("hub_ambient_phase2_b")
	EventDeckSystem.add_card("hub_ambient_phase3_a")
	EventDeckSystem.add_card("hub_ambient_phase3_b")
	EventDeckSystem.add_card("hub_pipe_valve_note")
	EventDeckSystem.add_card("hub_spore_vent_note")
	EventDeckSystem.add_card("hub_atrium_gate_note")
	# Roll a hub_return card and queue it for display if no pending text exists
	var pending := str(GameState.get_world_flag("_pending_arrival_text", ""))
	if pending.is_empty():
		var card := WorldDirector.roll_context_event("hub_return")
		if not card.is_empty() and not str(card.get("text", "")).is_empty():
			GameState.set_world_flag("_pending_arrival_text", str(card.get("text", "")))
			GameState.set_world_flag("_pending_arrival_speaker", str(card.get("speaker", "System X")))


func _check_phase() -> void:
	var power := bool(GameState.get_world_flag("hub_power_restored", false))
	var lan := bool(GameState.get_world_flag("hub_lan_restored", false))
	var cistern := bool(GameState.get_world_flag("hub_cistern_connected", false))
	var culture := bool(GameState.get_world_flag("nursery_culture_saved", false))
	var bar := bool(GameState.get_world_flag("bar_open", false))

	if power and lan and not GameState.get_world_flag("hub_phase_2", false):
		GameState.set_world_flag("hub_phase_2", true)
		GameState.set_world_flag("coil_invitation_available", true)
		_apply_phase_2()
		hud.push_log("hub: working base established")

	if GameState.get_world_flag("hub_phase_2", false) and cistern and culture and bar:
		if not GameState.get_world_flag("hub_phase_3", false):
			GameState.set_world_flag("hub_phase_3", true)
			_apply_phase_3()
			hud.push_log("hub: restored hub achieved")


func _apply_phase_2() -> void:
	GameState.set_world_flag("bar_open", true)
	WorldDirector.set_generator_state(WorldDirector.GENERATOR_STABLE)
	_spawn_npc("vera",     "Vera",      "Medical station. Bring clean water and I can keep people functional.",                                   "Press E: talk to Vera",      Vector3(+10.5, 1.05, -10.0))
	_spawn_npc("kiki_baja","Kiki Baja", "Torai liaison. My job is to make sure they think we are manageable. I am very good at my job.",         "Press E: talk to Kiki Baja", Vector3(-3.5,  1.05, -10.0))
	_spawn_npc("ladderboy","Ladderboy", "Vertical access workshop. The ceiling knows things the floor does not. I am the reason that is useful.", "Press E: talk to Ladderboy", Vector3(-10.5, 1.05, -10.0))
	_unlock_basement_hatch()


func _apply_phase_3() -> void:
	if GameState.get_world_flag("coil_invitation_accepted", false):
		_spawn_npc("velvet_coil", "Velvet Coil", "I am here conditionally. The conditions are holding. Ask me again in a week.", "Press E: talk to Velvet Coil", Vector3(+10.5, 1.05, +10.0))
	_activate_hub_radio()


# ── Geometry ────────────────────────────────────────────────────────

func _build_materials() -> void:
	_mat_floor    = _make_hub_mat(Color(0.055, 0.048, 0.060), Color(0.08, 0.02, 0.08), 0.12)
	_mat_wall     = _make_hub_mat(Color(0.040, 0.035, 0.045), Color(0.14, 0.02, 0.10), 0.25)
	_mat_ceil     = _make_hub_mat(Color(0.025, 0.020, 0.030), Color(0.05, 0.01, 0.04), 0.08)
	_mat_pillar   = _make_hub_mat(Color(0.065, 0.058, 0.072), Color(0.18, 0.04, 0.14), 0.30)
	_mat_trim_warm = _make_hub_mat(Color(0.18, 0.04, 0.01),   Color(1.00, 0.35, 0.05), 1.40)
	_mat_trim_cool = _make_hub_mat(Color(0.02, 0.04, 0.18),   Color(0.10, 0.60, 1.00), 1.20)
	_mat_sealed   = _make_hub_mat(Color(0.06, 0.04, 0.06),    Color(0.30, 0.08, 0.25), 0.55)


func _build_geometry() -> void:
	# ── CENTRAL ATRIUM  x(-14..+14)  z(-6..+6)  h=6 ─────────────────
	_add_box("AtriumFloor",  Vector3(28, 0.4, 12),  Vector3(0,      -0.2,  0),    _mat_floor)
	_add_box("AtriumCeil",   Vector3(28, 0.4, 12),  Vector3(0,       6.2,  0),    _mat_ceil)
	_add_box("AtriumWallW",  Vector3(0.4, 6,  12),  Vector3(-14.2,   3.0,  0),    _mat_wall)
	_add_box("AtriumWallE",  Vector3(0.4, 6,  12),  Vector3(+14.2,   3.0,  0),    _mat_wall)
	# Neon trim strips high on the long walls
	_add_box("TrimWW", Vector3(0.12, 0.14, 10), Vector3(-14.1, 4.6,  0), _mat_trim_cool)
	_add_box("TrimWE", Vector3(0.12, 0.14, 10), Vector3(+14.1, 4.6,  0), _mat_trim_cool)
	# Pillars at each store-divider x position, front face of both store rows
	_add_box("PillarSL", Vector3(0.5, 6, 0.5), Vector3(-7.0, 3.0, +6.0), _mat_pillar)
	_add_box("PillarSC", Vector3(0.5, 6, 0.5), Vector3( 0.0, 3.0, +6.0), _mat_pillar)
	_add_box("PillarSR", Vector3(0.5, 6, 0.5), Vector3(+7.0, 3.0, +6.0), _mat_pillar)
	_add_box("PillarNL", Vector3(0.5, 6, 0.5), Vector3(-7.0, 3.0, -6.0), _mat_pillar)
	_add_box("PillarNC", Vector3(0.5, 6, 0.5), Vector3( 0.0, 3.0, -6.0), _mat_pillar)
	_add_box("PillarNR", Vector3(0.5, 6, 0.5), Vector3(+7.0, 3.0, -6.0), _mat_pillar)

	# ── SOUTH STORE ROW (Stores 1-4)  x(-14..+14)  z(+6..+14)  h=4 ──
	_add_box("SStoreFloor",    Vector3(28, 0.4,  8),  Vector3( 0,    -0.2, +10.0), _mat_floor)
	_add_box("SStoreCeil",     Vector3(28, 0.4,  8),  Vector3( 0,    +4.2, +10.0), _mat_ceil)
	_add_box("SStoreWallW",    Vector3(0.4, 4,   8),  Vector3(-14.2, +2.0, +10.0), _mat_wall)
	_add_box("SStoreWallE",    Vector3(0.4, 4,   8),  Vector3(+14.2, +2.0, +10.0), _mat_wall)
	# South (back) wall, split around south-corridor opening (x: -5..+5)
	_add_box("SStoreBackW",    Vector3(9.0, 4, 0.4),  Vector3(-9.5,  +2.0, +14.2), _mat_wall)
	_add_box("SStoreBackE",    Vector3(9.0, 4, 0.4),  Vector3(+9.5,  +2.0, +14.2), _mat_wall)
	# Internal store dividers — start 2 units in from the front to leave open doorways
	_add_box("SStoreDivL",     Vector3(0.3, 4,   6),  Vector3(-7.0,  +2.0, +11.0), _mat_wall)
	_add_box("SStoreDivC",     Vector3(0.3, 4,   6),  Vector3( 0.0,  +2.0, +11.0), _mat_wall)
	_add_box("SStoreDivR",     Vector3(0.3, 4,   6),  Vector3(+7.0,  +2.0, +11.0), _mat_wall)
	# Store signs above each doorway
	_add_store_sign("Sign1", Color(0.00, 0.90, 1.00), Vector3(-10.5, 4.0, +6.3))  # Mister Static — cyan
	_add_store_sign("Sign2", Color(1.00, 0.65, 0.10), Vector3(-3.5,  4.0, +6.3))  # Gideon — amber
	_add_store_sign("Sign3", Color(1.00, 0.15, 0.50), Vector3(+3.5,  4.0, +6.3))  # Bar — pink
	_add_store_sign("Sign4", Color(0.45, 0.45, 0.45), Vector3(+10.5, 4.0, +6.3))  # Unclaimed — grey
	# Sealed fronts: Store 3 (bar) and Store 4 — removed by quests
	if not bool(GameState.get_world_flag("bar_open", false)):
		_add_box("Store3Seal", Vector3(6.8, 4.0, 0.3), Vector3(+3.5,  2.0, +6.15), _mat_sealed)
	if not bool(GameState.get_world_flag("store_4_claimed", false)):
		_add_box("Store4Seal", Vector3(6.8, 4.0, 0.3), Vector3(+10.5, 2.0, +6.15), _mat_sealed)

	# ── NORTH STORE ROW (Stores 5-8)  x(-14..+14)  z(-6..-14)  h=4 ──
	_add_box("NStoreFloor",    Vector3(28, 0.4,  8),  Vector3( 0,    -0.2, -10.0), _mat_floor)
	_add_box("NStoreCeil",     Vector3(28, 0.4,  8),  Vector3( 0,    +4.2, -10.0), _mat_ceil)
	_add_box("NStoreWallW",    Vector3(0.4, 4,   8),  Vector3(-14.2, +2.0, -10.0), _mat_wall)
	_add_box("NStoreWallE",    Vector3(0.4, 4,   8),  Vector3(+14.2, +2.0, -10.0), _mat_wall)
	# North (back) wall, split around service-corridor opening (x: -4..+4)
	_add_box("NStoreBackW",    Vector3(10, 4, 0.4),   Vector3(-9.0,  +2.0, -14.2), _mat_wall)
	_add_box("NStoreBackE",    Vector3(10, 4, 0.4),   Vector3(+9.0,  +2.0, -14.2), _mat_wall)
	# Internal dividers
	_add_box("NStoreDivL",     Vector3(0.3, 4,   6),  Vector3(-7.0,  +2.0, -11.0), _mat_wall)
	_add_box("NStoreDivC",     Vector3(0.3, 4,   6),  Vector3( 0.0,  +2.0, -11.0), _mat_wall)
	_add_box("NStoreDivR",     Vector3(0.3, 4,   6),  Vector3(+7.0,  +2.0, -11.0), _mat_wall)
	# Store signs
	_add_store_sign("Sign5", Color(0.20, 0.85, 0.35), Vector3(+10.5, 4.0, -6.3))  # Vera — green
	_add_store_sign("Sign6", Color(0.60, 0.20, 0.90), Vector3(+3.5,  4.0, -6.3))  # Vessel — purple
	_add_store_sign("Sign7", Color(1.00, 0.45, 0.75), Vector3(-3.5,  4.0, -6.3))  # Kiki Baja — pink
	_add_store_sign("Sign8", Color(0.35, 0.70, 1.00), Vector3(-10.5, 4.0, -6.3))  # Ladderboy — blue

	# ── SOUTH ENTRY CORRIDOR  x(-5..+5)  z(+14..+24)  h=4 ───────────
	_add_box("SCorFloor",  Vector3(10, 0.4, 10), Vector3(0,    -0.2, +19.0), _mat_floor)
	_add_box("SCorCeil",   Vector3(10, 0.4, 10), Vector3(0,    +4.2, +19.0), _mat_ceil)
	_add_box("SCorEnd",    Vector3(10, 4,  0.4), Vector3(0,    +2.0, +24.2), _mat_wall)
	_add_box("SCorWallW",  Vector3(0.4, 4,  10), Vector3(-5.2, +2.0, +19.0), _mat_wall)
	_add_box("SCorWallE",  Vector3(0.4, 4,  10), Vector3(+5.2, +2.0, +19.0), _mat_wall)
	_add_box("SCorTrimW",  Vector3(0.12, 0.14, 8), Vector3(-5.1, 3.5, +19.0), _mat_trim_warm)
	_add_box("SCorTrimE",  Vector3(0.12, 0.14, 8), Vector3(+5.1, 3.5, +19.0), _mat_trim_warm)

	# ── NORTH SERVICE CORRIDOR  x(-4..+4)  z(-14..-24)  h=4 ─────────
	_add_box("NCorFloor",  Vector3(8,  0.4, 10), Vector3(0,    -0.2, -19.0), _mat_floor)
	_add_box("NCorCeil",   Vector3(8,  0.4, 10), Vector3(0,    +4.2, -19.0), _mat_ceil)
	_add_box("NCorEnd",    Vector3(8,  4,  0.4), Vector3(0,    +2.0, -24.2), _mat_wall)
	_add_box("NCorWallW",  Vector3(0.4, 4,  10), Vector3(-4.2, +2.0, -19.0), _mat_wall)
	_add_box("NCorWallE",  Vector3(0.4, 4,  10), Vector3(+4.2, +2.0, -19.0), _mat_wall)
	# Basement hatch door — seals the service corridor until phase 2 clears it
	_add_box("BasementHatchDoor", Vector3(8, 4, 0.4), Vector3(0, 2.0, -14.2), _mat_sealed)

	# ── LIGHTS ────────────────────────────────────────────────────────
	# Atrium center lights
	_add_hub_light(Vector3(-7.0, 4.5,  0.0), Color(1.0, 0.08, 0.72), 2.4, 12.0)
	_add_hub_light(Vector3(+7.0, 4.5,  0.0), Color(0.1, 1.00, 0.45), 2.4, 12.0)
	_add_hub_light(Vector3( 0.0, 4.5,  0.0), Color(1.0, 0.08, 0.72), 1.6, 10.0)
	# Per-store lights (match NPC colors)
	_add_hub_light(Vector3(-10.5, 3.0, +10.0), Color(0.00, 0.90, 1.00), 1.3, 7.0)  # Store 1
	_add_hub_light(Vector3(-3.5,  3.0, +10.0), Color(1.00, 0.65, 0.10), 1.3, 7.0)  # Store 2
	_add_hub_light(Vector3(+3.5,  3.0, +10.0), Color(1.00, 0.15, 0.50), 1.1, 7.0)  # Store 3
	_add_hub_light(Vector3(+10.5, 3.0, +10.0), Color(0.45, 0.45, 0.45), 0.7, 7.0)  # Store 4
	_add_hub_light(Vector3(+10.5, 3.0, -10.0), Color(0.20, 0.85, 0.35), 1.3, 7.0)  # Store 5
	_add_hub_light(Vector3(+3.5,  3.0, -10.0), Color(0.60, 0.20, 0.90), 1.3, 7.0)  # Store 6
	_add_hub_light(Vector3(-3.5,  3.0, -10.0), Color(1.00, 0.45, 0.75), 1.3, 7.0)  # Store 7
	_add_hub_light(Vector3(-10.5, 3.0, -10.0), Color(0.35, 0.70, 1.00), 1.3, 7.0)  # Store 8
	# Corridor lights
	_add_hub_light(Vector3(0.0, 3.0, +19.0), Color(1.0, 0.35, 0.05), 1.5, 8.0)   # south corridor
	_add_hub_light(Vector3(0.0, 3.0, -19.0), Color(0.6, 0.50, 0.40), 1.1, 7.0)   # north corridor


func _add_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.set_surface_override_material(0, mat)
	body.add_child(vis)
	return body


func _add_store_sign(node_name: String, color: Color, pos: Vector3) -> void:
	var vis := MeshInstance3D.new()
	vis.name = node_name
	vis.position = pos
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 0.35, 0.1)
	vis.mesh = mesh
	vis.set_surface_override_material(0, _make_hub_mat(color.darkened(0.7), color, 1.6))
	add_child(vis)


func _add_hub_light(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	add_child(light)


func _make_hub_mat(albedo: Color, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.88
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# ── NPC spawning ────────────────────────────────────────────────────

func _spawn_npc(npc_id: String, npc_name: String, dialogue: String, prompt: String, spawn_position: Vector3) -> void:
	var group_tag := "hub_npc_" + npc_id
	if not get_tree().get_nodes_in_group(group_tag).is_empty():
		return
	var npc := NPCDialogue.new()
	npc.npc_name = npc_name
	npc.dialogue_text = dialogue
	npc.prompt_text = prompt
	npc.position = spawn_position
	npc.add_to_group("npc")
	npc.add_to_group(group_tag)
	add_child(npc)
	# Collision sphere for proximity detection
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	npc.add_child(col)
	# Visual capsule so the NPC is actually visible in the world
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	mesh_inst.mesh = capsule
	mesh_inst.position = Vector3(0.0, 0.75, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _npc_color(npc_id)
	mat.emission_enabled = true
	mat.emission = _npc_color(npc_id)
	mat.emission_energy_multiplier = 0.3
	mesh_inst.set_surface_override_material(0, mat)
	npc.add_child(mesh_inst)
	npc.focus_changed.connect(_on_npc_focus_changed)


func _npc_color(npc_id: String) -> Color:
	match npc_id:
		"mister_static": return Color(0.0,  0.9,  1.0)   # cyan
		"gideon":        return Color(1.0,  0.65, 0.1)   # amber
		"vera":          return Color(0.2,  0.85, 0.35)  # green
		"vessel":        return Color(0.6,  0.2,  0.9)   # purple
		"kiki_baja":     return Color(1.0,  0.45, 0.75)  # pink
		"ladderboy":     return Color(0.35, 0.7,  1.0)   # light blue
		"velvet_coil":   return Color(0.9,  0.3,  0.45)  # rose
		_:               return Color(0.8,  0.8,  0.8)   # fallback grey


# ── Hub structural changes ──────────────────────────────────────────

func _unlock_basement_hatch() -> void:
	var hatch := get_node_or_null("BasementHatchDoor") as StaticBody3D
	if hatch != null:
		hatch.queue_free()


func _activate_hub_radio() -> void:
	var radio := get_node_or_null("HubRadio")
	if radio != null:
		radio.visible = true


# ── Hub NPC interaction handlers ────────────────────────────────────

func _handle_mister_static() -> void:
	if GameState.get_world_flag("hub_power_restored", false):
		hud.show_dialogue("Mister Static", "Generator is stable. I stopped apologising to it. We have reached an understanding.")
		return
	if GameState.is_quest_started("hub_power_restore"):
		hud.show_dialogue("Mister Static", "Basement coupling. Tape is holding but tape is not a plan. Just a very optimistic adhesive.")
		return
	GameState.start_quest("hub_power_restore")
	EventDeckSystem.add_card("hub_power_exit")
	EventDeckSystem.add_card("hub_power_return")
	hud.show_dialogue("Mister Static", "The generator coupling is in the basement. I have been holding it together with tape for six weeks. Go fix it properly before the tape starts having opinions.")
	hud.push_log("quest started: hub power")
	hud.set_objective(GameState.get_quest_objective_text("hub_power_restore"))


func _handle_gideon() -> void:
	if GameState.get_world_flag("saint_ratchet_returned", false):
		hud.show_dialogue("Pipe Father Gideon", "Saint Ratchet is back. The pipes hum different. The congregation is behaving as if this was expected. Good theology.")
		return
	hud.show_dialogue("Pipe Father Gideon", "The Pipe Church holds. Whatever comes down from the upper levels, the pipes remember it. Come to us when the noise gets too loud.")


func _handle_vera() -> void:
	if GameState.get_world_flag("hub_cistern_connected", false):
		hud.show_dialogue("Vera", "Water is clean. Clinic is running. I have fixed four things today that should not have needed fixing. Normal day.")
		return
	if GameState.is_quest_started("hub_cistern"):
		hud.show_dialogue("Vera", "West walkway of the cistern. Conduit junction. Do not let Torai log you there.")
		return
	GameState.start_quest("hub_cistern")
	EventDeckSystem.add_card("hub_cistern_exit")
	EventDeckSystem.add_card("hub_cistern_return")
	if GameState.get_world_flag("cistern_valve_used", false):
		hud.show_dialogue("Vera", "The cistern valve is already bled — that simplifies the conduit run. West walkway junction. One connection and we have clean water.")
		hud.push_log("pipe valve already bled — conduit run simplified")
	else:
		hud.show_dialogue("Vera", "I need clean water for the clinic. The cistern west walkway has a junction point. Install a conduit there and we are connected.")
	hud.push_log("quest started: hub cistern")
	hud.set_objective(GameState.get_quest_objective_text("hub_cistern"))


func _handle_ladderboy() -> void:
	if GameState.get_world_flag("atrium_cleared", false):
		hud.show_dialogue("Ladderboy", "Atrium is clear. People are actually walking through it. I did not think we would get to the part where people walk through things.")
		return
	if GameState.is_quest_started("hub_clear_court"):
		hud.show_dialogue("Ladderboy", "Three piles. They are in the atrium. They have been there long enough to have addresses.")
		return
	GameState.start_quest("hub_clear_court")
	hud.show_dialogue("Ladderboy", "Three debris piles in the central atrium. They came down when the ceiling section failed. Move them and the whole hub opens up. I would do it myself but the vertical access workshop does not clear things — it reaches over them.")
	hud.push_log("quest started: clear the court")
	hud.set_objective(GameState.get_quest_objective_text("hub_clear_court"))


func _handle_kiki_baja() -> void:
	hud.show_dialogue("Kiki Baja", "Wan Moa Torai is watching this location. I am making sure that watching is all they do. If that changes I will tell you before they do.")


func _handle_vessel() -> void:
	if GameState.get_world_flag("hub_lan_restored", false):
		hud.show_dialogue("Vessel", "Archive is live. System X has seventeen things to tell you. Sixteen are warnings. One is a joke. I have not identified which one.")
		return
	if GameState.is_quest_started("hub_lan_restore"):
		hud.show_dialogue("Vessel", "North corridor ceiling panel. Splice kit. Hoodlums clipped the tap cable and did not leave a note.")
		return
	GameState.start_quest("hub_lan_restore")
	EventDeckSystem.add_card("hub_lan_exit")
	EventDeckSystem.add_card("hub_lan_return")
	hud.show_dialogue("Vessel", "The LAN tap is severed. North service corridor, ceiling panel above the junction. Bring a splice kit. When it is live, System X can see the whole lower city again. Some of what it sees will be your problem.")
	hud.push_log("quest started: hub LAN")
	hud.set_objective(GameState.get_quest_objective_text("hub_lan_restore"))


func _handle_velvet_coil() -> void:
	if GameState.get_world_flag("store_4_claimed", false):
		hud.show_dialogue("Velvet Coil", "Store 4 is mine now. The acoustics are acceptable. The corporate data I wiped from the terminal was less interesting than expected.")
		return
	if GameState.is_quest_started("hub_store_4"):
		hud.show_dialogue("Velvet Coil", "The terminal still has squatter data on it. Wipe it. Then I can finish cleaning the shelving.")
		return
	GameState.start_quest("hub_store_4")
	hud.show_dialogue("Velvet Coil", "Store 4 has old corporate squatter data on the terminal and physical debris from whoever used it last. Clear both and I will make it something worth having in the hub.")
	hud.push_log("quest started: store 4 claim")
	hud.set_objective(GameState.get_quest_objective_text("hub_store_4"))
