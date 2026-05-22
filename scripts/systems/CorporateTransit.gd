extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var guard: Enemy = $TransitGuard

var focused_exit
var focused_terminal
var terminal_resolved := false
var guard_neutralized := false


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	guard.defeated.connect(_on_guard_defeated)
	guard.body_part_destroyed.connect(_on_guard_body_part_destroyed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for terminal in get_tree().get_nodes_in_group("transit_interactable"):
		terminal.focus_changed.connect(_on_terminal_focus_changed)

	terminal_resolved = GameState.is_quest_completed("transit_breach")
	if terminal_resolved:
		guard_neutralized = true
		_retire_guard()

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_intro_line())
	hud.push_log("corporate transit breach established")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("save_game") or _is_save_key(event):
		_save_game()
	elif event.is_action_pressed("load_game") or _is_load_key(event):
		_load_game()


func _handle_interact() -> void:
	if focused_terminal != null:
		_use_terminal()
		return

	if focused_exit != null:
		get_tree().change_scene_to_file("res://scenes/levels/MallHub.tscn")


func _on_exit_focus_changed(mission_exit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_terminal_focus_changed(terminal, has_focus: bool) -> void:
	focused_terminal = terminal if has_focus else null
	_update_prompt()


func _update_prompt() -> void:
	if focused_terminal != null:
		hud.set_prompt(focused_terminal.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	else:
		hud.set_prompt("")


func _use_terminal() -> void:
	if terminal_resolved or GameState.is_quest_completed("transit_breach"):
		hud.show_dialogue("Face", "The transit pass is already printed. The elevator is starting to believe in you.")
		return

	if not guard_neutralized:
		hud.show_dialogue("Linda", "Security is present for your comfort. Please do not touch the rail controls.")
		hud.show_system_message("DISABLE RIGHT ARM OR DEFEAT GUARD")
		return

	if GameState.get_world_flag("ward_wake_coordinates_copied") and GameState.spend_item("Dream Access Key"):
		GameState.set_world_flag("transit_spire_route_open", true)
		GameState.add_item("Spire Transit Pass")
		GameState.add_reputation("System X", 1)
		GameState.add_reputation("Gatebox Corporation", -1)
		GameState.last_mission_result = "Forged a Spire transit pass from wake coordinates"
		hud.show_dialogue("Spooky Ghost", "Printed you a pass. Very official, if nobody reads it.")
	elif GameState.get_world_flag("ward_audit_sealed") and GameState.spend_item("Corporate Voucher"):
		GameState.set_world_flag("transit_compliance_pass", true)
		GameState.add_item("Gatebox Visitor Badge")
		GameState.add_reputation("Gatebox Corporation", 1)
		GameState.last_mission_result = "Accepted a compliant Gatebox transit badge"
		hud.show_dialogue("Linda", "Your visitor badge has been approved. Please remain grateful in marked areas.")
	else:
		hud.show_dialogue("Face", "The rail wants either a Dream Access Key or a Corporate Voucher. Bureaucracy with teeth.")
		hud.show_system_message("NEED ROUTE CREDENTIAL")
		return

	terminal_resolved = true
	GameState.mark_quest_completed("transit_breach")
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_system_message("TRANSIT BREACH COMPLETE")


func _on_guard_defeated() -> void:
	guard_neutralized = true
	hud.push_log("transit guard offline")
	hud.show_dialogue("Face", "Good. The rail console hates witnesses.")
	hud.set_objective(_get_objective_text())


func _on_guard_body_part_destroyed(part_name: String) -> void:
	if guard_neutralized:
		return
	if part_name != "Right Arm":
		return

	guard_neutralized = true
	_retire_guard()
	hud.push_log("transit guard weapon arm disabled")
	hud.show_dialogue("Face", "That did it. Right arm down, security loop broken. Hit the console.")
	hud.show_system_message("GUARD DISABLED")
	hud.set_objective(_get_objective_text())


func _get_objective_text() -> String:
	if GameState.is_quest_completed("transit_breach") or terminal_resolved:
		return "Transit Breach complete: return to the Mall. F5 save, F6 load."
	if not guard_neutralized:
		return "Transit Breach: destroy the guard's right arm or defeat it, then access the console."
	return "Transit Breach: access the rail console."


func _retire_guard() -> void:
	guard.visible = false
	guard.set_process(false)
	guard.set_physics_process(false)
	guard.collision_layer = 0
	guard.collision_mask = 0


func _get_intro_line() -> String:
	if GameState.get_world_flag("ward_audit_sealed"):
		return "Your compliance route has been provisionally approved."
	if GameState.get_world_flag("ward_wake_coordinates_copied"):
		return "Unauthorized patient data has entered a transit zone. How exciting."
	return "This station is not for unscheduled bodies."


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		terminal_resolved = GameState.is_quest_completed("transit_breach")
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
