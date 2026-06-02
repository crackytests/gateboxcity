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

var vessel_floor_contact_debug_enabled := false
var vessel_floor_contact_step := 0.01
var vessel_floor_contact_label: Label
var vessel_floor_contact_sprite: Sprite3D

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_ceil: StandardMaterial3D
var _mat_pillar: StandardMaterial3D
var _mat_trim_warm: StandardMaterial3D
var _mat_trim_cool: StandardMaterial3D
var _mat_sealed: StandardMaterial3D
var _mat_upper: StandardMaterial3D
var _mat_railing: StandardMaterial3D
var _mat_esc_off: StandardMaterial3D
var _mat_esc_on: StandardMaterial3D

# Upper-floor tenant stores: floor surface is y=6.4, NPCs sit +1.05 above it like the ground floor.
# Store bay spans z(-9..-16); tenants stand at z=-12.5 behind their counters.
const HUB_UPPER_Y := 7.45
const HUB_UPPER_Z := -12.5
const VESSEL_DAMAGED_TEXTURE := "res://assets/sprites/vessel/vessel_damaged.png"
const VESSEL_DAMAGED_FLOOR_TEXTURE := "res://assets/sprites/vessel/vessel_damaged_floor_contact.png"
const VESSEL_DAMAGED_PIXEL_SIZE := 0.0017425
const VESSEL_REPAIRED_PIXEL_SIZE := 0.00272
const VESSEL_FRAME_PATHS := [
	"res://assets/sprites/vessel/vessel_back.png",
	"res://assets/sprites/vessel/vessel_back_left.png",
	"res://assets/sprites/vessel/vessel_right.png",
	"res://assets/sprites/vessel/vessel_front_right.png",
	"res://assets/sprites/vessel/vessel_front.png",
	"res://assets/sprites/vessel/vessel_front_left.png",
	"res://assets/sprites/vessel/vessel_left.png",
	"res://assets/sprites/vessel/vessel_back_right.png",
]


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

	# Topic-conversation hand-offs: this scene owns its NPCs' shop/surgery services,
	# and refreshes the hub objective after a conversation (a Work topic may start a quest).
	if hud.dialogue_ui != null:
		if not hud.dialogue_ui.service_requested.is_connected(_on_hub_dialogue_service):
			hud.dialogue_ui.service_requested.connect(_on_hub_dialogue_service)
		if not hud.dialogue_ui.closed.is_connected(_on_dialogue_closed):
			hud.dialogue_ui.closed.connect(_on_dialogue_closed)

	_build_materials()
	_build_geometry()
	_apply_mall_world_state()
	_wire_runtime()
	_apply_gate_visibility()
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
	_check_ward7_return()
	# An interactive arrival event may be waiting (visitor, demand, gift). Lines still use the
	# pending-text path above; this only fires cards with choices.
	hud.present_event.call_deferred("hub_return", true)


# Hub-return consequences for the Comfort Annexe (Ward 7). The emergent note is
# logged once; rescued/hidden residents and Big Gates fallout surface here.
func _check_ward7_return() -> void:
	if not GameState.get_world_flag("ward7_quest_logged", false):
		return
	if not GameState.get_world_flag("ward7_return_acknowledged", false):
		GameState.set_world_flag("ward7_return_acknowledged", true)
		hud.push_log("quest logged: Something Wrong At Ward 7")
		if GameState.get_world_flag("ward7_experiment_docs_found", false):
			hud.show_dialogue("Mister Static", "Ward 7. I knew it was up there. I did not know what it was doing. I am not surprised. I am just quiet about it. The Big Gates Informant will want what you pulled.")
		else:
			hud.show_dialogue("Mister Static", "Ward 7. I knew it existed. Whatever you saw in there, keep it close. Corporate calls that building green.")
	if GameState.get_world_flag("ward7_resident_rescued", false) and not GameState.get_world_flag("ward7_survivor_settled", false):
		GameState.set_world_flag("ward7_survivor_settled", true)
		hud.push_log("a Ward 7 survivor is in the squatters' unit now — they don't explain themselves")
	if GameState.get_world_flag("ward7_big_gates_sweep_pending", false) and not GameState.get_world_flag("ward7_big_gates_sweep_armed", false):
		GameState.set_world_flag("ward7_big_gates_sweep_armed", true)
		EventDeckSystem.add_card("big_gates_sweep")
	if GameState.get_world_flag("ward7_linda_wellness_pending", false) and not GameState.get_world_flag("ward7_linda_wellness_armed", false):
		GameState.set_world_flag("ward7_linda_wellness_armed", true)
		EventDeckSystem.add_card("linda_wellness_check")
	# General Bone Dividend resolution — fires once after the vault.
	if GameState.get_world_flag("bone_dividend_general_defeated", false) and not GameState.get_world_flag("bone_dividend_resolved", false):
		GameState.set_world_flag("bone_dividend_resolved", true)
		GameState.add_reputation("System X", 2)
		GameState.add_reputation("Wan Moa Torai", -1)
		if GameState.get_world_flag("bone_dividend_souls_freed", false):
			hud.show_dialogue("Big Gates Informant", "You closed the General's account and emptied the racks. The lower city felt that — a lot of nothing where a lot of suffering used to be filed. It cost you; I can see it on you. It was still right.")
		else:
			hud.show_dialogue("Big Gates Informant", "The General is down and the ledger is ours. You left the racks intact — careful, maybe, or merciful in a way I don't understand yet. Either way, the program has a hole in it now.")
		hud.push_log("General Bone Dividend: account closed")


func _unhandled_input(event: InputEvent) -> void:
	if _is_f11_key(event):
		_toggle_vessel_floor_contact_debug()
		get_viewport().set_input_as_handled()
		return
	if vessel_floor_contact_debug_enabled and _handle_vessel_floor_contact_debug_input(event):
		get_viewport().set_input_as_handled()
		return
	if hud.is_panel_open():
		return
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("toggle_inventory") or _is_tab_key(event):
		hud.toggle_inventory()
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
		# Migrated NPCs (those with a DialogueDB profile) use the topic conversation window.
		# Un-migrated NPCs fall through to the legacy scripted handlers below.
		var nid := str(focused_npc.npc_id)
		if not nid.is_empty() and DialogueDB.has_profile(nid):
			focused_npc.face_player_now()
			hud.open_dialogue(nid)
			return
		# Object/prop interactions (not conversations) keep their scripted handlers.
		match str(focused_npc.npc_name):
			"Damaged Android":
				_handle_vessel_android()
				return
			"Escalator Console":
				_handle_escalator_console()
				return
			"Motor Crate":
				_handle_motor_crate()
				return
			"Bar Door":
				_handle_bar_door()
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
		# Public cyberware terminal — routes to the Velvet Coil install flow (implants you're
		# carrying, paid in Wan Notes). Unifies on the one economy; no more item-cost self-install.
		hud.open_cybernetics()


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
		if GameState.is_quest_completed("rocker_fellar"):
			return "Faded Atrium: Rocker Fellar defeated. The first General has fallen. F5 save, F6 load."
		if GameState.is_quest_started("quest_rocker_fellar"):
			return "Descend to Rocker Fellar Keep. Destroy his body parts, shut down the soul batteries, end the concert. F5 save, F6 load."
		return "Faded Atrium: Wake-Up Call complete. Talk to System X for the next assignment. F5 save, F6 load."
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
	if GameState.is_quest_completed("rocker_fellar"):
		return "Rocker Fellar is offline. His soul batteries are empty and his contract ledger is a problem for three factions. The first crack in the Big Gates Foundation."
	if GameState.get_world_flag("rocker_fellar_defeated"):
		return "Fellar is down. Return to the Atrium and the world will catch up."
	if GameState.is_quest_started("quest_rocker_fellar"):
		return "Rocker Fellar's fortress waits beneath Leak Street. Destroy the soul batteries, dismantle his body parts, and end the concert. Use the deep lift in the district."
	if GameState.is_quest_completed("wake_up_call"):
		# Auto-start the Rocker Fellar quest on first System X contact after Wake-Up Call
		if not GameState.is_quest_started("quest_rocker_fellar"):
			GameState.start_quest("quest_rocker_fellar")
			if hud != null:
				hud.push_log("Quest accepted: Rocker Fellar Keep")
				hud.set_objective(_get_hub_objective())
		return "Big Gates Foundation general spotted in the deep Sub-Sub-Basement. Rocker Fellar — death-metal cyborg, soul harvester, concert fortress. His bass frequency is cracking the pipes three levels up. Go down there and unplug him."
	return "The real Mall may be myth, trap, or heaven. This copy is ours. Use the green gate when you are ready to wake something up on purpose."


func _get_system_x_speaker(fallback_name: String) -> String:
	if fallback_name == "Face":
		return "System X"
	return fallback_name


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
		_get_route_status("Rocker Fellar Keep", "quest_rocker_fellar"),
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
		"quest_rocker_fellar":
			return GameState.is_quest_completed("wake_up_call")
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
	if not GameState.is_quest_completed("quest_rocker_fellar"):
		return "NEXT  Rocker Fellar Keep: descend to the Big Gates concert fortress. Destroy the General."
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


func _apply_gate_visibility() -> void:
	# A gate is shown only when its route is unlocked (previous quest done) or
	# when the quest is already completed (free return visit). Both conditions
	# collapse to _is_route_unlocked(), which stays true after completion.
	_set_gate_visible("MissionGate",       _is_route_unlocked("wake_up_call"))
	_set_gate_visible("PacificationLift",  _is_route_unlocked("dream_audit"))
	_set_gate_visible("TransitGate",       _is_route_unlocked("transit_breach"))
	_set_gate_visible("SpireGate",         _is_route_unlocked("spire_lobby"))
	_set_gate_visible("ExecutiveGate",     _is_route_unlocked("executive_suite"))
	_set_gate_visible("CompanionCoreGate", _is_route_unlocked("companion_core"))
	_set_gate_visible("LindaSpireGate",    _is_route_unlocked("linda_spire"))
	_set_gate_visible("FinalPatchGate",    _is_route_unlocked("final_patch"))


func _set_gate_visible(node_name: String, gate_on: bool) -> void:
	var gate := get_node_or_null(node_name) as Area3D
	if gate == null:
		return
	gate.visible = gate_on
	gate.monitoring = gate_on
	# Also disable/enable the collision shape so nothing can focus a hidden gate
	for child in gate.get_children():
		var col := child as CollisionShape3D
		if col != null:
			col.disabled = not gate_on


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
		_apply_gate_visibility()
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


func _is_tab_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB


func _is_f11_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F11


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
		Vector3(-12.0, 1.05, +12.5))
	_spawn_npc("gideon", "Pipe Father Gideon",
		"The Pipe Church holds. Whatever comes down from the upper levels, the pipes remember it.",
		"Press E: talk to Pipe Father Gideon",
		Vector3(-4.0, 1.05, +12.5))
	if bool(GameState.get_world_flag("vessel_repaired", false)):
		_spawn_vessel_npc()
	else:
		_spawn_vessel_prop()
	_spawn_escalator_console()
	_spawn_motor_crate()
	_spawn_ward7_npcs()
	_check_phase()
	if GameState.get_world_flag("hub_phase_2", false):
		_apply_phase_2()
	if GameState.get_world_flag("hub_phase_3", false):
		_apply_phase_3()
	_spawn_bar_fixtures()
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
	# Drift-reaction ambient cards (gated by drift threshold world-flags)
	EventDeckSystem.add_card("drift_noticed_return")
	EventDeckSystem.add_card("drift_uncanny_warning")
	EventDeckSystem.add_card("high_drift_surveillance")
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
		hud.push_log("hub: working base established")
		# _apply_phase_2() is called by _wire_runtime() immediately after _check_phase() returns

	if GameState.get_world_flag("hub_phase_2", false) and cistern and culture and bar:
		if not GameState.get_world_flag("hub_phase_3", false):
			GameState.set_world_flag("hub_phase_3", true)
			hud.push_log("hub: restored hub achieved")
			# _apply_phase_3() is called by _wire_runtime() immediately after _check_phase() returns


func _apply_phase_2() -> void:
	WorldDirector.set_generator_state(WorldDirector.GENERATOR_STABLE)
	# Upper-floor tenant stores move in.
	_build_upper_shop("VeraShop",   -12.0, Color(0.20, 0.85, 0.35))
	_spawn_npc("vera",      "Vera",      "Medical station's open. Bring clean water and I can keep people functional. Talk to me and I will patch you up.", "Press E: see Vera (heal)",        Vector3(-12.0, HUB_UPPER_Y, HUB_UPPER_Z), 2.6)
	_build_upper_shop("KikiShop",    -4.0, Color(1.00, 0.45, 0.75))
	_spawn_npc("kiki_baja", "Kiki Baja", "Torai liaison. My job is to make sure they think we are manageable. I am very good at my job.",                  "Press E: talk to Kiki Baja",      Vector3( -4.0, HUB_UPPER_Y, HUB_UPPER_Z), 2.6)
	_build_upper_shop("LadderShop",  +4.0, Color(0.35, 0.70, 1.00))
	_spawn_npc("ladderboy", "Ladderboy", "Vertical access workshop. The ceiling knows things the floor does not. I am the reason that is useful.",          "Press E: talk to Ladderboy",      Vector3( +4.0, HUB_UPPER_Y, HUB_UPPER_Z), 2.6)
	_unlock_basement_hatch()
	# Point the player upstairs. If the escalators are still dead, they need the motor coupling first.
	if bool(GameState.get_world_flag("escalator_repaired", false)):
		hud.push_log("hub: upper stores occupied — Vera, Kiki Baja, Ladderboy")
	else:
		hud.push_log("hub: upper stores occupied — repair the escalators to reach them")


func _apply_phase_3() -> void:
	# Velvet Coil takes the fourth upper store (surgical suite) if her invitation was accepted.
	if GameState.get_world_flag("coil_invitation_accepted", false):
		_build_upper_shop("CoilShop", +12.0, Color(0.90, 0.30, 0.45))
		_spawn_npc("velvet_coil", "Velvet Coil",
			"The surgical suite is conditional and the conditions are holding. Sit on the table when you want hardware.",
			"Press E: Velvet Coil (cybernetics)",
			Vector3(+12.0, HUB_UPPER_Y, HUB_UPPER_Z), 2.6)
	_apply_phase_3_dressing()
	_activate_hub_radio()


func _apply_phase_3_dressing() -> void:
	# The restored hub reads as inhabited: planters from Static's nursery at the south entry,
	# warmer fill light, a couple of "people live here" props. Idempotent.
	if has_node("Phase3Planter1"):
		return
	var planter := _make_hub_mat(Color(0.18, 0.20, 0.14), Color(0.20, 0.85, 0.30), 0.40)
	var foliage := _make_hub_mat(Color(0.10, 0.28, 0.12), Color(0.15, 0.95, 0.35), 0.70)
	# South entry corridor planters (corridor spans z+16..+25, x-7..+7)
	_add_box("Phase3Planter1", Vector3(1.2, 0.6, 1.2), Vector3(-5.5, 0.3, +18.5), planter)
	_add_box("Phase3Foliage1", Vector3(1.0, 1.2, 1.0), Vector3(-5.5, 1.1, +18.5), foliage)
	_add_box("Phase3Planter2", Vector3(1.2, 0.6, 1.2), Vector3(+5.5, 0.3, +18.5), planter)
	_add_box("Phase3Foliage2", Vector3(1.0, 1.2, 1.0), Vector3(+5.5, 1.1, +18.5), foliage)
	# Warmer fill lights now that the hub is lived-in
	_add_hub_light(Vector3(0.0, 4.0, +18.5), Color(0.4, 1.0, 0.5), 1.4, 9.0)
	_add_hub_light(Vector3(0.0, 6.0, 0.0), Color(1.0, 0.7, 0.4), 1.2, 18.0)


# ── Geometry ────────────────────────────────────────────────────────

func _build_materials() -> void:
	# Structural surfaces: emission is a faint shadow tint only — texture must dominate.
	# Accent surfaces (railing, sealed, pillar): slightly more glow but still texture-primary.
	# Trim strips and active escalator: full neon — they are the light sources.
	_mat_floor     = _make_hub_mat(Color(0.72, 0.68, 0.74), Color(0.40, 0.06, 0.32), 0.07, "res://assets/hub_floor_tile.png",      Vector3(8, 8, 1))
	_mat_wall      = _make_hub_mat(Color(0.68, 0.63, 0.70), Color(0.32, 0.04, 0.26), 0.05, "res://assets/hub_wall_concrete.png",   Vector3(6, 4, 1))
	_mat_ceil      = _make_hub_mat(Color(0.28, 0.25, 0.30), Color(0.10, 0.02, 0.08), 0.05, "res://assets/hub_ceil_panel.png",      Vector3(8, 8, 1))
	_mat_pillar    = _make_hub_mat(Color(0.70, 0.64, 0.72), Color(0.42, 0.08, 0.35), 0.12, "res://assets/hub_pillar_concrete.png", Vector3(3, 4, 1))
	_mat_trim_warm = _make_hub_mat(Color(0.88, 0.55, 0.18), Color(1.00, 0.40, 0.05), 1.60, "res://assets/hub_trim_warm.png",       Vector3(8, 1, 1))
	_mat_trim_cool = _make_hub_mat(Color(0.22, 0.50, 0.88), Color(0.12, 0.72, 1.00), 1.50, "res://assets/hub_trim_cool.png",       Vector3(8, 1, 1))
	_mat_sealed    = _make_hub_mat(Color(0.58, 0.46, 0.58), Color(0.70, 0.10, 0.55), 0.22, "res://assets/hub_sealed_panel.png",    Vector3(4, 3, 1))
	_mat_upper     = _make_hub_mat(Color(0.63, 0.60, 0.66), Color(0.20, 0.06, 0.35), 0.08, "res://assets/hub_upper_floor.png",     Vector3(6, 6, 1))
	_mat_railing   = _make_hub_mat(Color(0.64, 0.58, 0.68), Color(0.50, 0.10, 0.62), 0.22, "res://assets/hub_railing_metal.png",   Vector3(4, 2, 1))
	# Offline escalator: cool neutral-gray albedo so it reads as material, not a glowing slab
	_mat_esc_off   = _make_hub_mat(Color(0.52, 0.50, 0.46), Color(0.65, 0.22, 0.02), 0.16, "res://assets/hub_esc_on.png",          Vector3(6, 1, 1))
	# Active escalator: brighter cyan albedo carries the "on" read; low emission so the step texture stays visible.
	_mat_esc_on    = _make_hub_mat(Color(0.55, 0.80, 0.90), Color(0.10, 0.80, 1.00), 0.35, "res://assets/hub_esc_on.png",          Vector3(6, 1, 1))


func _build_geometry() -> void:
	# ── CENTRAL ATRIUM  x(-16..+16)  z(-9..+9)  h=10 ─────────────────
	# Wider, taller — escalators live in the centre as a focal feature
	_add_box("AtriumFloor", Vector3(32, 0.4, 18),  Vector3(0,     -0.2,  0),    _mat_floor)
	_add_box("AtriumCeil",  Vector3(32, 0.4, 18),  Vector3(0,    +10.2,  0),    _mat_ceil)
	_add_box("AtriumWallW", Vector3(0.4, 10, 18),  Vector3(-16.2, +5.0,  0),    _mat_wall)
	_add_box("AtriumWallE", Vector3(0.4, 10, 18),  Vector3(+16.2, +5.0,  0),    _mat_wall)
	# North wall — solid except for the basement hatch opening (x: -3..+3)
	# North wall is GROUND-FLOOR ONLY (y 0..6). Above y=6 the mezzanine must stay open so the
	# upper walkway connects to the upper store row (z -9..-16) through the entry pillars at z=-9.
	_add_box("AtriumWallNL",   Vector3(13, 6, 0.4), Vector3(-9.5, +3.0, -9.2), _mat_wall)
	_add_box("AtriumWallNR",   Vector3(13, 6, 0.4), Vector3(+9.5, +3.0, -9.2), _mat_wall)
	# Fills above the basement hatch (hatch hole is y 0..4) up to the mezzanine floor (y=6).
	_add_box("AtriumWallNTop", Vector3( 6, 2, 0.4), Vector3( 0.0, +5.0, -9.2), _mat_wall)
	# Only build the hatch if phase 2 hasn't unlocked it yet
	if not bool(GameState.get_world_flag("hub_phase_2", false)):
		_add_box("BasementHatchDoor", Vector3(6, 4, 0.4), Vector3(0, +2.0, -9.2), _mat_sealed)
	# Trim strips on the long walls
	_add_box("TrimWW", Vector3(0.12, 0.14, 16), Vector3(-16.1, +7.5,  0), _mat_trim_cool)
	_add_box("TrimWE", Vector3(0.12, 0.14, 16), Vector3(+16.1, +7.5,  0), _mat_trim_cool)
	_add_box("TrimWWLo", Vector3(0.12, 0.14, 16), Vector3(-16.1, +2.5, 0), _mat_trim_warm)
	_add_box("TrimWELo", Vector3(0.12, 0.14, 16), Vector3(+16.1, +2.5, 0), _mat_trim_warm)
	# Pillars at south store-row junction (z=+9), marking each divider column
	_add_box("PillarSL", Vector3(0.5, 10, 0.5), Vector3(-8.0, +5.0, +9.0), _mat_pillar)
	_add_box("PillarSC", Vector3(0.5, 10, 0.5), Vector3( 0.0, +5.0, +9.0), _mat_pillar)
	_add_box("PillarSR", Vector3(0.5, 10, 0.5), Vector3(+8.0, +5.0, +9.0), _mat_pillar)

	# ── NORTH SERVICE STUB  x(-3..+3)  z(-9..-16)  h=4 ──────────────
	# Small utility passage behind the hatch door
	_add_box("NCorFloor",  Vector3(6, 0.4,  7), Vector3( 0.0, -0.2, -12.5), _mat_floor)
	_add_box("NCorCeil",   Vector3(6, 0.4,  7), Vector3( 0.0, +4.2, -12.5), _mat_ceil)
	_add_box("NCorEnd",    Vector3(6,  4, 0.4), Vector3( 0.0, +2.0, -16.2), _mat_wall)
	_add_box("NCorWallW",  Vector3(0.4, 4,  7), Vector3(-3.2, +2.0, -12.5), _mat_wall)
	_add_box("NCorWallE",  Vector3(0.4, 4,  7), Vector3(+3.2, +2.0, -12.5), _mat_wall)

	# ── SOUTH STORE ROW  x(-16..+16)  z(+9..+16)  h=5  (4 stores @ 8 wide each) ──
	_add_box("SStoreFloor",  Vector3(32, 0.4,  7), Vector3( 0,    -0.2, +12.5), _mat_floor)
	_add_box("SStoreCeil",   Vector3(32, 0.4,  7), Vector3( 0,    +5.2, +12.5), _mat_ceil)
	_add_box("SStoreWallW",  Vector3(0.4, 5,   7), Vector3(-16.2, +2.5, +12.5), _mat_wall)
	_add_box("SStoreWallE",  Vector3(0.4, 5,   7), Vector3(+16.2, +2.5, +12.5), _mat_wall)
	# Back wall split around the wider south corridor opening (x: -7..+7)
	_add_box("SStoreBackW",  Vector3(9, 5, 0.4), Vector3(-11.5, +2.5, +16.2), _mat_wall)
	_add_box("SStoreBackE",  Vector3(9, 5, 0.4), Vector3(+11.5, +2.5, +16.2), _mat_wall)
	# Dividers — 5 units deep from z+11, leaving a 2-unit open doorway
	_add_box("SStoreDivL",   Vector3(0.3, 5, 5), Vector3(-8.0, +2.5, +13.5), _mat_wall)
	_add_box("SStoreDivC",   Vector3(0.3, 5, 5), Vector3( 0.0, +2.5, +13.5), _mat_wall)
	_add_box("SStoreDivR",   Vector3(0.3, 5, 5), Vector3(+8.0, +2.5, +13.5), _mat_wall)
	# Store signs at top of the front face
	_add_store_sign("SSign1", Color(0.00, 0.90, 1.00), Vector3(-12.0, 5.4, +9.3))  # Mister Static
	_add_store_sign("SSign2", Color(1.00, 0.65, 0.10), Vector3( -4.0, 5.4, +9.3))  # Gideon
	_add_store_sign("SSign3", Color(1.00, 0.15, 0.50), Vector3( +4.0, 5.4, +9.3))  # Bar
	_add_store_sign("SSign4", Color(0.45, 0.45, 0.45), Vector3(+12.0, 5.4, +9.3))  # Unclaimed
	# Sealed fronts
	# Store 3 (bar) stays sealed until the Bar quest opens it (requires hub water).
	if not bool(GameState.get_world_flag("bar_open", false)):
		_add_box("Store3Seal", Vector3(7.8, 5.0, 0.3), Vector3( +4.0, 2.5, +9.15), _mat_sealed)
	if not bool(GameState.get_world_flag("store_4_claimed", false)):
		_add_box("Store4Seal", Vector3(7.8, 5.0, 0.3), Vector3(+12.0, 2.5, +9.15), _mat_sealed)

	# ── SOUTH ENTRY CORRIDOR  x(-7..+7)  z(+16..+25)  h=5 ───────────
	_add_box("SCorFloor",  Vector3(14, 0.4,  9), Vector3( 0.0, -0.2, +20.5), _mat_floor)
	_add_box("SCorCeil",   Vector3(14, 0.4,  9), Vector3( 0.0, +5.2, +20.5), _mat_ceil)
	_add_box("SCorEnd",    Vector3(14,  5, 0.4), Vector3( 0.0, +2.5, +25.2), _mat_wall)
	_add_box("SCorWallW",  Vector3(0.4, 5,   9), Vector3(-7.2, +2.5, +20.5), _mat_wall)
	_add_box("SCorWallE",  Vector3(0.4, 5,   9), Vector3(+7.2, +2.5, +20.5), _mat_wall)
	_add_box("SCorTrimW",  Vector3(0.12, 0.14, 7), Vector3(-7.1, +4.0, +20.5), _mat_trim_warm)
	_add_box("SCorTrimE",  Vector3(0.12, 0.14, 7), Vector3(+7.1, +4.0, +20.5), _mat_trim_warm)

	# ── UPPER LEVEL ───────────────────────────────────────────────────
	_build_upper_level()

	# ── LIGHTS ────────────────────────────────────────────────────────
	# Wide atrium — 7 spread lights for even coverage
	_add_hub_light(Vector3(  0.0, 5.5,  0.0), Color(1.0, 0.08, 0.72), 2.8, 16.0)  # centre
	_add_hub_light(Vector3(-12.0, 5.0,  0.0), Color(0.1, 1.00, 0.45), 2.2, 10.0)  # far west
	_add_hub_light(Vector3(+12.0, 5.0,  0.0), Color(1.0, 0.08, 0.72), 2.2, 10.0)  # far east
	_add_hub_light(Vector3( -6.0, 4.5, -5.0), Color(1.0, 0.08, 0.72), 1.8,  9.0)  # NW quad
	_add_hub_light(Vector3( +6.0, 4.5, -5.0), Color(0.1, 1.00, 0.45), 1.8,  9.0)  # NE quad
	_add_hub_light(Vector3( -6.0, 4.5, +5.0), Color(0.1, 1.00, 0.45), 1.8,  9.0)  # SW quad
	_add_hub_light(Vector3( +6.0, 4.5, +5.0), Color(1.0, 0.08, 0.72), 1.8,  9.0)  # SE quad
	# South ground-floor store lights
	_add_hub_light(Vector3(-12.0, 3.5, +12.5), Color(0.00, 0.90, 1.00), 1.5, 8.0)  # Store 1
	_add_hub_light(Vector3( -4.0, 3.5, +12.5), Color(1.00, 0.65, 0.10), 1.5, 8.0)  # Store 2
	_add_hub_light(Vector3( +4.0, 3.5, +12.5), Color(1.00, 0.15, 0.50), 1.0, 8.0)  # Store 3 sealed
	_add_hub_light(Vector3(+12.0, 3.5, +12.5), Color(0.45, 0.45, 0.45), 0.6, 8.0)  # Store 4 dark
	# South corridor
	_add_hub_light(Vector3(0.0, 3.5, +20.5), Color(1.0, 0.35, 0.05), 1.8, 9.0)
	# North hatch stub
	_add_hub_light(Vector3(0.0, 2.5, -12.5), Color(0.5, 0.40, 0.35), 0.9, 6.0)


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
	vis.set_surface_override_material(0, _make_hub_mat(color.darkened(0.7), color, 1.6, "res://assets/hub_sign_face.png", Vector3(1, 1, 1)))
	add_child(vis)


func _build_upper_shop(prefix: String, cx: float, accent: Color) -> void:
	# Fits inside one upper store bay (z -9..-16). Floor surface is y=6.4.
	# The tenant NPC stands at z=-12.5; the counter sits in front (toward the z=-9 doorway),
	# shelving against the back wall, plus one character prop per tenant.
	if has_node(prefix + "Counter"):
		return
	var floor_top := 6.4
	var body_mat := _make_hub_mat(Color(0.26, 0.24, 0.28), accent, 0.30)
	var accent_mat := _make_hub_mat(accent.darkened(0.5), accent, 0.85)
	# Service counter facing the doorway
	_add_box(prefix + "Counter",     Vector3(3.6, 1.0, 0.6),  Vector3(cx, floor_top + 0.5, -11.2), body_mat)
	_add_box(prefix + "CounterTrim", Vector3(3.6, 0.08, 0.10), Vector3(cx, floor_top + 1.02, -10.88), accent_mat)
	# Back shelving against the north wall
	_add_box(prefix + "Shelf",     Vector3(5.2, 2.0, 0.4),   Vector3(cx, floor_top + 1.0, -15.7), body_mat)
	_add_box(prefix + "ShelfGlow", Vector3(5.2, 0.10, 0.12), Vector3(cx, floor_top + 1.7, -15.45), accent_mat)
	# A stocked crate to the side
	_add_box(prefix + "Crate", Vector3(0.9, 0.9, 0.9), Vector3(cx + 2.4, floor_top + 0.45, -14.2), body_mat)
	# Per-tenant character prop
	match prefix:
		"VeraShop":
			_add_box(prefix + "Cot", Vector3(2.2, 0.5, 1.0), Vector3(cx - 1.8, floor_top + 0.25, -13.8), body_mat)
		"KikiShop":
			_add_box(prefix + "Terminal", Vector3(0.7, 0.5, 0.5), Vector3(cx, floor_top + 1.25, -11.2), accent_mat)
		"LadderShop":
			_add_box(prefix + "Ladder",  Vector3(0.16, 3.0, 0.16), Vector3(cx - 2.3, floor_top + 1.5, -15.6), accent_mat)
			_add_box(prefix + "Ladder2", Vector3(0.16, 2.4, 0.16), Vector3(cx + 1.9, floor_top + 1.2, -15.6), body_mat)
		"CoilShop":
			_add_box(prefix + "OpTable", Vector3(2.4, 0.6, 1.1), Vector3(cx - 1.6, floor_top + 0.3, -13.8), accent_mat)


func _add_hub_light(pos: Vector3, color: Color, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	add_child(light)


func _build_upper_level() -> void:
	# ── MEZZANINE RING  y=6 ──────────────────────────────────────────
	# Escalators top out at z=-4, so the north strip starts there.
	# Combined north strip + upper-store floor is one continuous slab.
	_add_box("UpperNFloor",  Vector3(32, 0.4, 12), Vector3( 0.0, 6.2, -10.0), _mat_upper)  # z(-4..-16)
	_add_box("UpperSFloor",  Vector3(32, 0.4,  5), Vector3( 0.0, 6.2,  +6.5), _mat_upper)  # z(+4..+9)
	_add_box("UpperEFloor",  Vector3( 7, 0.4,  8), Vector3(+12.5, 6.2,  0.0), _mat_upper)  # x(+9..+16)
	_add_box("UpperWFloor",  Vector3( 7, 0.4,  8), Vector3(-12.5, 6.2,  0.0), _mat_upper)  # x(-16..-9)

	# ── UPPER NORTH STORE ROW  z(-9..-16)  y=6..y=10 ────────────────
	# Phase-2/3 stores live on the second floor.
	_add_box("UStoreCeil",   Vector3(32, 0.4, 7), Vector3( 0.0, 10.2, -12.5), _mat_ceil)
	_add_box("UStoreWallN",  Vector3(32, 4, 0.4), Vector3( 0.0,  8.0, -16.2), _mat_wall)
	_add_box("UStoreWallW",  Vector3(0.4, 4,  7), Vector3(-16.2, 8.0, -12.5), _mat_wall)
	_add_box("UStoreWallE",  Vector3(0.4, 4,  7), Vector3(+16.2, 8.0, -12.5), _mat_wall)
	# Dividers — 5 deep from z-11, leaving a 2-unit open doorway at z-9
	_add_box("UStoreDivL",   Vector3(0.3, 4, 5), Vector3(-8.0, 8.0, -13.5), _mat_wall)
	_add_box("UStoreDivC",   Vector3(0.3, 4, 5), Vector3( 0.0, 8.0, -13.5), _mat_wall)
	_add_box("UStoreDivR",   Vector3(0.3, 4, 5), Vector3(+8.0, 8.0, -13.5), _mat_wall)
	# Entry pillars at upper-store threshold
	_add_box("UPillarL",  Vector3(0.5, 4, 0.5), Vector3(-8.0, 8.0, -9.0), _mat_pillar)
	_add_box("UPillarC",  Vector3(0.5, 4, 0.5), Vector3( 0.0, 8.0, -9.0), _mat_pillar)
	_add_box("UPillarR",  Vector3(0.5, 4, 0.5), Vector3(+8.0, 8.0, -9.0), _mat_pillar)
	# Store signs (always shown — empty storefronts until NPCs arrive)
	_add_store_sign("USign1", Color(0.20, 0.85, 0.35), Vector3(-12.0, 9.3, -9.3))  # Vera
	_add_store_sign("USign2", Color(1.00, 0.45, 0.75), Vector3( -4.0, 9.3, -9.3))  # Kiki Baja
	_add_store_sign("USign3", Color(0.35, 0.70, 1.00), Vector3( +4.0, 9.3, -9.3))  # Ladderboy
	_add_store_sign("USign4", Color(0.90, 0.30, 0.45), Vector3(+12.0, 9.3, -9.3))  # Velvet Coil

	# ── MEZZANINE RAILINGS ───────────────────────────────────────────
	# North inner edge (z=-4): gap at x(-4..+4) for escalator exit
	_add_box("RailNL", Vector3(12, 0.8, 0.15), Vector3(-10.0, 6.8, -4.0), _mat_railing)
	_add_box("RailNR", Vector3(12, 0.8, 0.15), Vector3(+10.0, 6.8, -4.0), _mat_railing)
	# South inner edge (z=+4): full width
	_add_box("RailS",  Vector3(32, 0.8, 0.15), Vector3(  0.0, 6.8, +4.0), _mat_railing)
	# East/west inner edges
	_add_box("RailE",  Vector3(0.15, 0.8, 8), Vector3(+9.0, 6.8, 0.0), _mat_railing)
	_add_box("RailW",  Vector3(0.15, 0.8, 8), Vector3(-9.0, 6.8, 0.0), _mat_railing)
	# Neon trim on railing tops
	_add_box("URailTrimNL", Vector3(12, 0.08, 0.10), Vector3(-10.0, 7.25, -4.0), _mat_trim_cool)
	_add_box("URailTrimNR", Vector3(12, 0.08, 0.10), Vector3(+10.0, 7.25, -4.0), _mat_trim_cool)
	_add_box("URailTrimS",  Vector3(32, 0.08, 0.10), Vector3(  0.0, 7.25, +4.0), _mat_trim_warm)
	_add_box("URailTrimE",  Vector3(0.10, 0.08, 8),  Vector3( +9.0, 7.25,  0.0), _mat_trim_warm)
	_add_box("URailTrimW",  Vector3(0.10, 0.08, 8),  Vector3( -9.0, 7.25,  0.0), _mat_trim_cool)

	# ── CENTRAL ESCALATORS ───────────────────────────────────────────
	# Two side-by-side ramps at x=±1.5, rising from z=+4 (y=0) to z=-4 (y=6)
	# Ramp length = sqrt(6²+8²) = 10, angle = 36.87°
	var esc_mat := _mat_esc_on if bool(GameState.get_world_flag("escalator_repaired", false)) else _mat_esc_off
	_add_ramp("EscRampL", Vector3(2.6, 0.4, 10.0), Vector3(-1.5, 3.0, 0.0), +36.87, esc_mat)
	_add_ramp("EscRampR", Vector3(2.6, 0.4, 10.0), Vector3(+1.5, 3.0, 0.0), +36.87, esc_mat)
	# Centre divider and outer walls (same slope)
	_add_ramp("EscDiv",     Vector3(0.18, 1.6, 10.0), Vector3(0.0,  3.75, 0.0), +36.87, _mat_pillar)
	_add_ramp("EscWallL",   Vector3(0.18, 1.6, 10.0), Vector3(-4.1, 3.75, 0.0), +36.87, _mat_wall)
	_add_ramp("EscWallR",   Vector3(0.18, 1.6, 10.0), Vector3(+4.1, 3.75, 0.0), +36.87, _mat_wall)
	# Barrier across the bottom entrance when escalators are offline
	if not bool(GameState.get_world_flag("escalator_repaired", false)):
		_add_box("EscBarrier", Vector3(9.5, 2.0, 0.3), Vector3(0.0, 1.0, +4.3), _mat_sealed)

	# ── UPPER LEVEL LIGHTS ───────────────────────────────────────────
	# Mezzanine ambient
	_add_hub_light(Vector3(+12.5, 7.5,  0.0), Color(0.3, 0.7, 1.0), 1.6, 9.0)  # east walk
	_add_hub_light(Vector3(-12.5, 7.5,  0.0), Color(0.3, 0.7, 1.0), 1.6, 9.0)  # west walk
	_add_hub_light(Vector3(  0.0, 7.5, +7.0), Color(1.0, 0.35, 0.05), 1.4, 9.0)  # south bridge
	_add_hub_light(Vector3(  0.0, 7.5, -7.0), Color(0.1, 0.8, 1.00), 1.4, 9.0)  # north bridge
	# Upper store lights (dim until phase activates)
	_add_hub_light(Vector3(-12.0, 9.0, -12.5), Color(0.20, 0.85, 0.35), 1.2, 8.0)  # Vera
	_add_hub_light(Vector3( -4.0, 9.0, -12.5), Color(1.00, 0.45, 0.75), 1.2, 8.0)  # Kiki Baja
	_add_hub_light(Vector3( +4.0, 9.0, -12.5), Color(0.35, 0.70, 1.00), 1.2, 8.0)  # Ladderboy
	_add_hub_light(Vector3(+12.0, 9.0, -12.5), Color(0.90, 0.30, 0.45), 1.0, 8.0)  # Velvet Coil


func _add_ramp(node_name: String, size: Vector3, pos: Vector3, rot_x_deg: float, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = Vector3(rot_x_deg, 0.0, 0.0)
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


func _make_hub_mat(albedo: Color, emission: Color, emission_energy: float, texture_path: String = "", uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.88
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = uv_scale
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	return mat


# ── NPC spawning ────────────────────────────────────────────────────

func _spawn_npc(npc_id: String, npc_name: String, dialogue: String, prompt: String, spawn_position: Vector3, focus_radius: float = 1.2) -> void:
	var group_tag := "hub_npc_" + npc_id
	if not get_tree().get_nodes_in_group(group_tag).is_empty():
		return
	var npc := NPCDialogue.new()
	npc.npc_id = npc_id
	npc.npc_name = npc_name
	npc.dialogue_text = dialogue
	npc.prompt_text = prompt
	npc.position = spawn_position
	npc.add_to_group("npc")
	npc.add_to_group(group_tag)
	add_child(npc)
	# Collision sphere for proximity detection (wider for shop NPCs standing behind counters)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = focus_radius
	col.shape = shape
	npc.add_child(col)
	if npc_id == "vessel":
		_add_vessel_directional_sprite(npc)
	else:
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


func _add_vessel_directional_sprite(npc: NPCDialogue) -> void:
	var billboard := DirectionalBillboard.new()
	billboard.name = "Sprite3D"
	billboard.frame_paths = PackedStringArray(VESSEL_FRAME_PATHS)
	billboard.texture = load("res://assets/sprites/vessel/vessel_front.png")
	billboard.pixel_size = VESSEL_REPAIRED_PIXEL_SIZE
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.shaded = false
	billboard.double_sided = true
	billboard.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	billboard.idle_bob_height = 0.025
	npc.add_child(billboard)
	billboard._load_frames_from_paths()
	billboard.align_bottom_to_origin(0.02)


func _npc_color(npc_id: String) -> Color:
	match npc_id:
		"mister_static": return Color(0.0,  0.9,  1.0)   # cyan
		"gideon":        return Color(1.0,  0.65, 0.1)   # amber
		"vera":          return Color(0.2,  0.85, 0.35)  # green
		"vessel":        return Color(0.6,  0.2,  0.9)   # purple
		"kiki_baja":     return Color(1.0,  0.45, 0.75)  # pink
		"ladderboy":     return Color(0.35, 0.7,  1.0)   # light blue
		"velvet_coil":   return Color(0.9,  0.3,  0.45)  # rose
		"brickmouth_ronnie": return Color(0.85, 0.75, 0.2)  # sickly yellow
		"big_gates_informant": return Color(0.95, 0.45, 0.15)  # ember orange
		"ward7_survivor": return Color(0.7, 0.7, 0.78)  # washed-out pale
		_:               return Color(0.8,  0.8,  0.8)   # fallback grey


# Ward 7 (Comfort Annexe) consequence NPCs. The informant appears once you've
# been inside; the rescued resident settles in the bar if you brought them out.
func _spawn_ward7_npcs() -> void:
	if GameState.get_world_flag("ward7_entered", false):
		_spawn_npc("big_gates_informant", "Big Gates Informant",
			"You went to Ward 7. We should talk about what you saw — quietly.",
			"Press E: talk to the Big Gates Informant",
			Vector3(-7.5, 1.05, +6.0), 1.6)
	if GameState.get_world_flag("ward7_survivor_settled", false):
		_spawn_npc("ward7_survivor", "Ward 7 Survivor",
			"...",
			"Press E: the Ward 7 survivor",
			Vector3(+5.5, 1.05, +10.5), 1.6)


# ── Bar (Store 3) — phase-3 social beat, gated on hub water ──────────

func _spawn_bar_fixtures() -> void:
	# The bar slot only does anything once the hub has power+LAN (phase 2).
	if not bool(GameState.get_world_flag("hub_phase_2", false)):
		return
	if bool(GameState.get_world_flag("bar_open", false)):
		_open_bar_interior()
	else:
		_spawn_bar_door()


func _spawn_bar_door() -> void:
	var group_tag := "hub_bar_door"
	if not get_tree().get_nodes_in_group(group_tag).is_empty():
		return
	var npc := NPCDialogue.new()
	npc.npc_name = "Bar Door"
	npc.dialogue_text = "Sealed shutter. Store 3."
	npc.prompt_text = "Press E: examine the sealed bar"
	npc.position = Vector3(+4.0, 1.05, +8.3)  # atrium side of the Store 3 seal
	npc.add_to_group("npc")
	npc.add_to_group(group_tag)
	add_child(npc)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	col.shape = shape
	npc.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.7, 0.25)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 0.35, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.07, 0.04)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.10)
	mat.emission_energy_multiplier = 0.6
	mesh_inst.set_surface_override_material(0, mat)
	npc.add_child(mesh_inst)
	npc.focus_changed.connect(_on_npc_focus_changed)


func _handle_bar_door() -> void:
	if not bool(GameState.get_world_flag("hub_cistern_connected", false)):
		hud.show_dialogue("System X", "Store 3 is a bar with a dead tap. Vera's cistern conduit feeds this wall too — connect the hub water first, then opening the shutter means something other than dust.")
		hud.set_objective("Connect hub water (Vera's cistern quest) to open the bar.")
		return
	_open_bar()


func _open_bar() -> void:
	GameState.set_world_flag("bar_open", true)
	var seal := get_node_or_null("Store3Seal") as StaticBody3D
	if seal != null:
		seal.queue_free()
	for node in get_tree().get_nodes_in_group("hub_bar_door"):
		node.remove_from_group("hub_bar_door")
		node.queue_free()
	focused_npc = null
	_update_prompt()
	_open_bar_interior()
	_relocate_vessel_to_bar()
	hud.show_dialogue("Vessel", "Shutter's up, tap's wet. This is the Cooters mall branch and I keep it. Marbles has the original; I have the one with better structural integrity and worse regulars. Sit down.")
	hud.push_log("hub: the bar is open")
	# Opening the bar may complete the phase-3 conditions.
	_check_phase()
	if GameState.get_world_flag("hub_phase_3", false):
		_apply_phase_3()


func _open_bar_interior() -> void:
	# Store 3 ground-floor bay: x=+4, z(+9..+16), floor surface y=0.
	if not has_node("BarCounter"):
		var body := _make_hub_mat(Color(0.20, 0.16, 0.10), Color(1.0, 0.35, 0.10), 0.45)
		var glow := _make_hub_mat(Color(0.30, 0.10, 0.05), Color(1.0, 0.45, 0.10), 1.20)
		_add_box("BarCounter",     Vector3(5.0, 1.1, 0.7),  Vector3(+4.0, 0.55, +10.8), body)
		_add_box("BarCounterTrim", Vector3(5.0, 0.08, 0.10), Vector3(+4.0, 1.12, +10.46), glow)
		_add_box("BarBackbar",     Vector3(5.5, 2.2, 0.4),  Vector3(+4.0, 1.10, +15.6), body)
		_add_box("BarBottles",     Vector3(4.5, 0.5, 0.25), Vector3(+4.0, 1.70, +15.4), glow)
		_add_box("BarStool1", Vector3(0.4, 0.7, 0.4), Vector3(+2.4, 0.35, +9.9), body)
		_add_box("BarStool2", Vector3(0.4, 0.7, 0.4), Vector3(+4.0, 0.35, +9.9), body)
		_add_box("BarStool3", Vector3(0.4, 0.7, 0.4), Vector3(+5.6, 0.35, +9.9), body)
		_add_hub_light(Vector3(+4.0, 3.0, +12.5), Color(1.0, 0.45, 0.10), 1.8, 8.0)
	# Vessel tends this bar — relocated here by _relocate_vessel_to_bar() / spawned at the bar on load.
	# Brickmouth Ronnie works the end of the bar as the resident pharmacist.
	_spawn_npc("brickmouth_ronnie", "Brickmouth Ronnie",
		"End of the bar. I sell what gets you through the next hour, not the next year. Comedown's on you.",
		"Press E: Brickmouth Ronnie (pharmacy)",
		Vector3(+6.6, 1.05, +10.2), 2.4)


# ── Hub structural changes ──────────────────────────────────────────

func _unlock_basement_hatch() -> void:
	var hatch := get_node_or_null("BasementHatchDoor") as StaticBody3D
	if hatch != null:
		hatch.queue_free()


func _activate_hub_radio() -> void:
	# Build the hub radio prop near the central atrium once (phase 3 social texture).
	if has_node("HubRadio"):
		return
	var radio_mat := _make_hub_mat(Color(0.12, 0.10, 0.14), Color(1.0, 0.45, 0.10), 0.9)
	_add_box("HubRadio", Vector3(0.8, 0.9, 0.5), Vector3(-6.0, 0.45, +6.5), radio_mat)
	_add_box("HubRadioGlow", Vector3(0.6, 0.10, 0.10), Vector3(-6.0, 0.75, +6.76), _make_hub_mat(Color(0.3, 0.1, 0.05), Color(1.0, 0.55, 0.15), 1.4))
	_add_hub_light(Vector3(-6.0, 1.5, +6.5), Color(1.0, 0.5, 0.15), 1.0, 5.0)


# ── Hub NPC interaction handlers ────────────────────────────────────
# Conversational NPCs (Static, Gideon, Vera, Ladderboy, Kiki, Vessel, Velvet Coil, Ronnie) are
# data-driven now — see DialogueDB.NPC_PROFILES. Their shop/surgery services are routed by
# _on_hub_dialogue_service below; only the object/prop handlers remain hardcoded here.

func _on_hub_dialogue_service(npc_id: String, service_id: String) -> void:
	match service_id:
		"sell":
			hud.open_sell_shop("Pipe Father Gideon — Wasted Potential")
		"pharmacy":
			hud.open_shop("Brickmouth Ronnie — Pharmacy", _ronnie_offers())
		"cybernetics":
			hud.open_cybernetics()   # Coil installs implants you're carrying, paid in Wan Notes


func _on_dialogue_closed() -> void:
	# A Work topic may have started a quest mid-conversation; refresh the hub objective.
	hud.set_objective(_get_hub_objective())


func _ronnie_offers() -> Array:
	return [
		{"item": "Jolt", "label": "Jolt", "desc": GameState.CONSUMABLES["Jolt"]["desc"],
			"price_item": "Wan Note", "price_count": 5},
		{"item": "Glass", "label": "Glass", "desc": GameState.CONSUMABLES["Glass"]["desc"],
			"price_item": "Wan Note", "price_count": 5},
		{"item": "Redline", "label": "Redline", "desc": GameState.CONSUMABLES["Redline"]["desc"],
			"price_item": "Wan Note", "price_count": 7},
		{"item": "Patch", "label": "Patch (heal)", "desc": GameState.CONSUMABLES["Patch"]["desc"],
			"price_item": "Wan Note", "price_count": 12},
	]


func _spawn_vessel_npc() -> void:
	# Vessel (the repaired bunny android) stands in the atrium for the LAN quest, then tends the
	# hub's Cooters bar branch once it's open. (Marbles keeps the original Cooters elsewhere.)
	if bool(GameState.get_world_flag("bar_open", false)):
		_spawn_npc("vessel", "Vessel",
			"Hub tap's open. This is the Cooters mall branch — I keep this one.",
			"Press E: talk to Vessel",
			Vector3(+4.0, 0.0, +12.5), 2.6)
	else:
		_spawn_npc("vessel", "Vessel",
			"The LAN tap is severed. When it is live, System X can see the whole lower city again.",
			"Press E: talk to Vessel",
			Vector3(+7.5, 0.0, +0.5))


func _relocate_vessel_to_bar() -> void:
	# Despawn the atrium Vessel and respawn it behind the bar (bar_open must already be true).
	for node in get_tree().get_nodes_in_group("hub_npc_vessel"):
		if is_instance_valid(node):
			node.remove_from_group("hub_npc_vessel")
			node.queue_free()
	_spawn_vessel_npc()


func _spawn_vessel_prop() -> void:
	var group_tag := "hub_npc_vessel"
	if not get_tree().get_nodes_in_group(group_tag).is_empty():
		return
	var npc := NPCDialogue.new()
	npc.npc_name = "Damaged Android"
	npc.dialogue_text = "Offline."
	npc.prompt_text = "Press E: examine android"
	# Slumped against the east atrium wall, beside the mission board cluster.
	npc.position = Vector3(+15.92, 0.0, +0.5)
	npc.add_to_group("npc")
	npc.add_to_group(group_tag)
	add_child(npc)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	npc.add_child(col)
	_add_vessel_damaged_sprite(npc)
	npc.focus_changed.connect(_on_npc_focus_changed)


func _add_vessel_damaged_sprite(npc: NPCDialogue) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.texture = load(VESSEL_DAMAGED_TEXTURE)
	sprite.pixel_size = VESSEL_DAMAGED_PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.no_depth_test = false
	sprite.position = Vector3(0.0, 0.612, 0.0)
	sprite.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	npc.add_child(sprite)

	var floor_contact := Sprite3D.new()
	floor_contact.name = "FloorContactSprite3D"
	floor_contact.texture = load(VESSEL_DAMAGED_FLOOR_TEXTURE)
	floor_contact.pixel_size = VESSEL_DAMAGED_PIXEL_SIZE
	floor_contact.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_contact.shaded = false
	floor_contact.double_sided = true
	floor_contact.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	floor_contact.no_depth_test = false
	floor_contact.flip_h = true
	floor_contact.position = Vector3(-0.357, 0.025, 0.017)
	floor_contact.rotation_degrees = Vector3(90.0, -90.0, 180.0)
	npc.add_child(floor_contact)
	vessel_floor_contact_sprite = floor_contact


func _toggle_vessel_floor_contact_debug() -> void:
	vessel_floor_contact_debug_enabled = not vessel_floor_contact_debug_enabled
	if vessel_floor_contact_debug_enabled:
		vessel_floor_contact_sprite = _find_vessel_floor_contact_sprite()
		_ensure_vessel_floor_contact_debug_label()
		_update_vessel_floor_contact_debug_label()
		print("[VesselFloorContact] debug enabled")
	else:
		if vessel_floor_contact_label != null:
			vessel_floor_contact_label.visible = false
		print("[VesselFloorContact] debug disabled")


func _handle_vessel_floor_contact_debug_input(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	if vessel_floor_contact_sprite == null:
		vessel_floor_contact_sprite = _find_vessel_floor_contact_sprite()
	if vessel_floor_contact_sprite == null:
		print("[VesselFloorContact] no FloorContactSprite3D found")
		return true

	var delta := Vector3.ZERO
	match key_event.keycode:
		KEY_LEFT:
			delta.x -= vessel_floor_contact_step
		KEY_RIGHT:
			delta.x += vessel_floor_contact_step
		KEY_PAGEUP:
			delta.y += vessel_floor_contact_step
		KEY_PAGEDOWN:
			delta.y -= vessel_floor_contact_step
		KEY_UP:
			delta.z -= vessel_floor_contact_step
		KEY_DOWN:
			delta.z += vessel_floor_contact_step
		KEY_BRACKETLEFT:
			vessel_floor_contact_step = maxf(0.001, vessel_floor_contact_step * 0.5)
			_update_vessel_floor_contact_debug_label()
			print("[VesselFloorContact] step = %.4f" % vessel_floor_contact_step)
			return true
		KEY_BRACKETRIGHT:
			vessel_floor_contact_step = minf(0.25, vessel_floor_contact_step * 2.0)
			_update_vessel_floor_contact_debug_label()
			print("[VesselFloorContact] step = %.4f" % vessel_floor_contact_step)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_print_vessel_floor_contact_position()
			return true
		_:
			return false

	vessel_floor_contact_sprite.position += delta
	_update_vessel_floor_contact_debug_label()
	_print_vessel_floor_contact_position()
	return true


func _find_vessel_floor_contact_sprite() -> Sprite3D:
	for node in get_tree().get_nodes_in_group("hub_npc_vessel"):
		if not is_instance_valid(node):
			continue
		var sprite := node.get_node_or_null("FloorContactSprite3D") as Sprite3D
		if sprite != null:
			return sprite
	return null


func _ensure_vessel_floor_contact_debug_label() -> void:
	if vessel_floor_contact_label != null:
		vessel_floor_contact_label.visible = true
		return
	var layer := CanvasLayer.new()
	layer.name = "VesselFloorContactDebugLayer"
	layer.layer = 100
	add_child(layer)
	vessel_floor_contact_label = Label.new()
	vessel_floor_contact_label.name = "VesselFloorContactDebugLabel"
	vessel_floor_contact_label.position = Vector2(24.0, 280.0)
	vessel_floor_contact_label.add_theme_font_size_override("font_size", 16)
	vessel_floor_contact_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.65))
	layer.add_child(vessel_floor_contact_label)


func _update_vessel_floor_contact_debug_label() -> void:
	if vessel_floor_contact_label == null:
		return
	var pos := Vector3.ZERO
	if vessel_floor_contact_sprite != null:
		pos = vessel_floor_contact_sprite.position
	vessel_floor_contact_label.text = "VESSEL FOOT DEBUG F11\nArrows X/Z  PgUp/PgDn Y  [/] step  Enter print\npos Vector3(%.3f, %.3f, %.3f)  step %.4f" % [
		pos.x,
		pos.y,
		pos.z,
		vessel_floor_contact_step,
	]


func _print_vessel_floor_contact_position() -> void:
	if vessel_floor_contact_sprite == null:
		return
	var pos := vessel_floor_contact_sprite.position
	print("[VesselFloorContact] position = Vector3(%.4f, %.4f, %.4f)" % [pos.x, pos.y, pos.z])


func _spawn_escalator_console() -> void:
	if bool(GameState.get_world_flag("escalator_repaired", false)):
		return
	var group_tag := "hub_npc_escalator"
	if not get_tree().get_nodes_in_group(group_tag).is_empty():
		return
	var npc := NPCDialogue.new()
	npc.npc_name = "Escalator Console"
	npc.dialogue_text = "Offline."
	npc.prompt_text = "Press E: check escalator status"
	# Placed beside the bottom of the central escalators
	npc.position = Vector3(+5.5, 1.05, +3.8)
	npc.add_to_group("npc")
	npc.add_to_group(group_tag)
	add_child(npc)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.4
	col.shape = shape
	npc.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.75, 0.28)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 0.38, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.07, 0.04)
	mat.emission_enabled = true
	mat.emission = Color(0.80, 0.30, 0.05)
	mat.emission_energy_multiplier = 0.65
	mesh_inst.set_surface_override_material(0, mat)
	npc.add_child(mesh_inst)
	npc.focus_changed.connect(_on_npc_focus_changed)


func _spawn_motor_crate() -> void:
	# Only exists while the escalator is broken and the coupling hasn't been found.
	if bool(GameState.get_world_flag("escalator_repaired", false)):
		return
	if bool(GameState.get_world_flag("escalator_motor_found", false)):
		return
	var group_tag := "hub_motor_crate"
	if not get_tree().get_nodes_in_group(group_tag).is_empty():
		return
	var npc := NPCDialogue.new()
	npc.npc_name = "Motor Crate"
	npc.dialogue_text = "Yellow-tagged crate. Escalator parts inside."
	npc.prompt_text = "Press E: search crate"
	npc.position = Vector3(+2.5, 0.0, -8.2)  # atrium side of the hatch, accessible before phase 2
	npc.add_to_group("npc")
	npc.add_to_group(group_tag)
	add_child(npc)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	npc.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.5, 0.6)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 0.25, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.22, 0.04)
	mat.emission_enabled = true
	mat.emission = Color(0.90, 0.65, 0.05)
	mat.emission_energy_multiplier = 0.75
	mesh_inst.set_surface_override_material(0, mat)
	npc.add_child(mesh_inst)
	npc.focus_changed.connect(_on_npc_focus_changed)


func _handle_motor_crate() -> void:
	if bool(GameState.get_world_flag("escalator_motor_found", false)):
		hud.show_dialogue("System X", "Crate is empty. Motor coupling already retrieved.")
		return
	GameState.set_world_flag("escalator_motor_found", true)
	focused_npc = null
	_update_prompt()
	for node in get_tree().get_nodes_in_group("hub_motor_crate"):
		node.queue_free()
	hud.show_dialogue("System X", "Escalator motor coupling recovered. Return to the console beside the escalators.")
	hud.push_log("found: escalator motor coupling")
	hud.set_objective("Bring the motor coupling to the escalator console.")


func _handle_vessel_android() -> void:
	if bool(GameState.get_world_flag("vessel_repaired", false)):
		return
	# Developer bypass flag
	if bool(GameState.get_world_flag("vessel_repair_complete", false)):
		_repair_vessel()
		return
	# If the player is carrying a neural splice, consume it and repair
	if GameState.spend_item("neural_splice"):
		_repair_vessel()
		return
	# No splice in hand — show intro or reminder
	var already_told := bool(GameState.get_world_flag("vessel_quest_given", false))
	GameState.set_world_flag("vessel_quest_given", true)
	if already_told:
		hud.show_dialogue("System X", "Android repair still requires a neural splice component. Defeat a Splice enemy in the job destinations below.")
	else:
		hud.show_dialogue("System X", "Bunny-class companion android, generation four or earlier. Motor cortex corrupted, memory lattice fragmented, power cell depleted. This unit can be restored. Find a neural splice component — Splice enemies carry them — and return here.")
		hud.push_log("quest started: vessel repair")
		hud.set_objective("Find a neural splice component. Splice enemies drop them in the job destinations. Return to the damaged android.")


func _repair_vessel() -> void:
	GameState.set_world_flag("vessel_repaired", true)
	for node in get_tree().get_nodes_in_group("hub_npc_vessel"):
		node.remove_from_group("hub_npc_vessel")
		node.queue_free()
	focused_npc = null
	_update_prompt()
	_spawn_vessel_npc()
	hud.show_dialogue("Vessel", "Restart sequence complete. Memory lattice partial but functional. I know what I am and what needs to happen. The LAN tap is severed — I will explain.")
	hud.push_log("android repaired: Vessel is online")
	hud.set_objective("Talk to Vessel about the LAN tap.")


func _handle_escalator_console() -> void:
	if bool(GameState.get_world_flag("escalator_repaired", false)):
		hud.show_dialogue("System X", "Escalators running. Upper level is open.")
		return
	if bool(GameState.get_world_flag("escalator_motor_found", false)):
		_repair_escalator()
		return
	# First visit: flag it so repeat visits just show a reminder
	var already_told := bool(GameState.get_world_flag("escalator_quest_given", false))
	GameState.set_world_flag("escalator_quest_given", true)
	if already_told:
		hud.show_dialogue("Ladderboy", "Still waiting on that motor coupling. Yellow-tagged crate — it is near the north hatch, right here in the atrium.")
	else:
		hud.show_dialogue("Ladderboy", "Escalator motor coupling is fried on both units. There is a yellow-tagged crate near the north hatch — maintenance leftovers. Bring it back and I will have both running inside two hours.")
		hud.push_log("quest started: escalator repair")
		hud.set_objective("Find the yellow-tagged crate near the north hatch. Return the motor coupling to the escalator console.")


func _repair_escalator() -> void:
	GameState.set_world_flag("escalator_repaired", true)
	for node in get_tree().get_nodes_in_group("hub_npc_escalator"):
		node.remove_from_group("hub_npc_escalator")
		node.queue_free()
	if focused_npc != null and str(focused_npc.npc_name) == "Escalator Console":
		focused_npc = null
		_update_prompt()
	# Remove barrier panel
	var barrier := get_node_or_null("EscBarrier") as StaticBody3D
	if barrier: barrier.queue_free()
	# Add running lights above ramps
	_add_hub_light(Vector3(+12.5, 5.0, 0.0), Color(0.10, 0.78, 1.0), 2.2, 7.0)
	_add_hub_light(Vector3(-12.5, 5.0, 0.0), Color(0.10, 0.78, 1.0), 2.2, 7.0)
	hud.show_dialogue("Ladderboy", "Both escalators running. Upper level is open. The mall just got taller.")
	hud.push_log("escalators repaired: upper level accessible")
	hud.set_objective("Upper level unlocked. Explore the mezzanine.")
