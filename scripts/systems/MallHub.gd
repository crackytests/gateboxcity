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

	_apply_mall_world_state()
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.set_objective(_get_hub_objective())
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
