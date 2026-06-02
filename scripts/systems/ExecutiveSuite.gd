extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var auditor: Enemy = $ComplianceAuditor

var focused_exit
var focused_interactable
var suite_resolved := false
var auditor_broken := false


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	auditor.defeated.connect(_on_auditor_defeated)
	auditor.body_part_destroyed.connect(_on_auditor_body_part_destroyed)
	for security_node in get_tree().get_nodes_in_group("security_node"):
		security_node.attacked_player.connect(hud.push_log)
		security_node.defeated.connect(_on_security_node_defeated)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for interactable in get_tree().get_nodes_in_group("executive_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)

	suite_resolved = GameState.is_quest_completed("executive_suite")
	if suite_resolved or GameState.has_item("Companion Clearance"):
		_retire_auditor()

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_intro_line())
	hud.push_log("executive suite breach established")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("save_game") or _is_save_key(event):
		_save_game()
	elif event.is_action_pressed("load_game") or _is_load_key(event):
		_load_game()


func _handle_interact() -> void:
	if focused_interactable != null:
		_use_interactable(focused_interactable)
		return

	if focused_exit != null:
		get_tree().change_scene_to_file("res://scenes/levels/MallHub.tscn")


func _on_exit_focus_changed(mission_exit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_interactable_focus_changed(interactable, has_focus: bool) -> void:
	focused_interactable = interactable if has_focus else null
	_update_prompt()


func _update_prompt() -> void:
	if focused_interactable != null:
		hud.set_prompt(focused_interactable.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	else:
		hud.set_prompt("")


func _use_interactable(interactable) -> void:
	match interactable.interactable_id:
		"admin_desk":
			_use_admin_desk()
		"override_console":
			_use_override_console()


func _use_admin_desk() -> void:
	if suite_resolved:
		hud.show_dialogue("Linda", "The appointment is already scheduled. Please do not schedule it twice; eagerness becomes a symptom at this altitude.")
		return

	if not GameState.spend_item("Companion Clearance"):
		hud.show_dialogue("Linda", "This desk only opens for approved companion clearance. Desks are loyal when properly frightened.")
		hud.show_system_message("NEED COMPANION CLEARANCE")
		return

	GameState.set_world_flag("executive_appointment_scheduled", true)
	GameState.add_item("Linda Appointment Stub")
	GameState.add_reputation("Gatebox Corporation", 1)
	GameState.last_mission_result = "Scheduled a Linda executive appointment"
	_complete_suite("Linda", "Your appointment stub has been issued. Please bring your entire self, including the parts pretending not to want approval.")


func _use_override_console() -> void:
	if suite_resolved:
		hud.show_dialogue("System X", "Override shard is already in your pocket. It is probably judging us, and I resent how fair that is.")
		return

	if not auditor_broken:
		hud.show_dialogue("System X", "Break the auditor first. Head or torso. The console needs silence, and the auditor is one long complaint with legs.")
		hud.show_system_message("BREAK AUDITOR FIRST")
		return

	if not GameState.spend_item("Executive Elevator Trace"):
		hud.show_dialogue("System X", "We need the elevator trace from the lobby before this console will cough up anything useful. Right now it is just expensive furniture with opinions.")
		hud.show_system_message("NEED EXECUTIVE ELEVATOR TRACE")
		return

	GameState.set_world_flag("executive_override_stolen", true)
	GameState.add_item("Executive Override Shard")
	GameState.add_reputation("System X", 1)
	GameState.add_reputation("Gatebox Corporation", -1)
	GameState.last_mission_result = "Stole an executive override shard"
	_complete_suite("Spooky Ghost", "Shard acquired. Tiny executive permission slip. Deeply cursed, laminated by people who say family at meetings.")


func _on_auditor_defeated() -> void:
	auditor_broken = true
	hud.push_log("compliance auditor broken")
	hud.show_dialogue("System X", "Auditor is down. Pull the override before Linda reassigns the room and makes us thank it.")
	hud.set_objective(_get_objective_text())


func _on_security_node_defeated() -> void:
	hud.push_log("executive security node offline")
	hud.show_dialogue("System X", "That node was auditing your pulse. Rude machine, dead machine, beautiful paperwork-free ending.")


func _on_auditor_body_part_destroyed(part_name: String) -> void:
	if auditor_broken:
		return
	if part_name != "Head" and part_name != "Torso":
		return

	auditor_broken = true
	_retire_auditor()
	hud.push_log("auditor " + part_name.to_lower() + " destroyed")
	hud.show_dialogue("System X", "That broke the audit loop. Console is yours, which is not the same as safe, but look at us growing.")
	hud.show_system_message("AUDITOR BROKEN")
	hud.set_objective(_get_objective_text())


func _complete_suite(speaker: String, line: String) -> void:
	suite_resolved = true
	GameState.mark_quest_completed("executive_suite")
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue(speaker, line)
	hud.show_system_message("EXECUTIVE SUITE COMPLETE")


func _get_objective_text() -> String:
	if suite_resolved or GameState.is_quest_completed("executive_suite"):
		return "Executive Suite complete: return to the Mall. F5 save, F6 load."
	if GameState.has_item("Companion Clearance"):
		return "Executive Suite: use companion clearance at the admin desk."
	if not auditor_broken:
		return "Executive Suite: destroy the auditor's head or torso, then access the override console."
	return "Executive Suite: access the override console."


func _get_intro_line() -> String:
	if GameState.has_item("Companion Clearance"):
		return "Welcome to executive intake. Your compliance smells almost natural, like a flower grown in a spreadsheet."
	if GameState.has_item("Executive Elevator Trace"):
		return "An unauthorized elevator trace has entered a managed thought environment. Please keep your crime moisturized."
	return "Executive access requires a cleaner lie. Yours still has fingerprints."


func _retire_auditor() -> void:
	auditor_broken = true
	auditor.visible = false
	auditor.set_process(false)
	auditor.set_physics_process(false)
	auditor.collision_layer = 0
	auditor.collision_mask = 0


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		suite_resolved = GameState.is_quest_completed("executive_suite")
		if suite_resolved:
			_retire_auditor()
		hud.set_inventory_summary(GameState.get_inventory_summary())
		hud.set_faction_summary(GameState.get_faction_summary())
		hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
		hud.set_objective(_get_objective_text())
		hud.show_dialogue("Linda", _get_intro_line())
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
