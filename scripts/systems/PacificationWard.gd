extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_exit
var focused_interactable
var inspected_pods: Dictionary = {}
var console_resolved := false


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for interactable in get_tree().get_nodes_in_group("ward_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)

	console_resolved = GameState.is_quest_completed("dream_audit")

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_linda_line())
	hud.push_log("pacification ward route established")


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
		"pod_a", "pod_b", "pod_c":
			_inspect_pod(interactable)
		"ward_console":
			_use_ward_console()


func _inspect_pod(interactable) -> void:
	if inspected_pods.has(interactable.interactable_id):
		hud.show_dialogue("Spooky Ghost", "%s is still dreaming the same loop. Reruns are cheaper than care." % interactable.display_name)
		return

	inspected_pods[interactable.interactable_id] = true
	var scan_count := inspected_pods.size()
	match interactable.interactable_id:
		"pod_a":
			hud.show_dialogue("Linda", "Resident A-19 reports comfort. Their hands are unclenched now, which is the body voting yes.")
		"pod_b":
			hud.show_dialogue("Spooky Ghost", "That one is not asleep. They are buffering, which is what prison calls a loading screen.")
		"pod_c":
			hud.show_dialogue("Linda", "Resident C-02 has accepted supervised nostalgia. Memory is gentler when it has a chaperone.")

	hud.push_log("sleep pod scan %d/3" % scan_count)
	hud.set_objective(_get_objective_text())
	if scan_count >= 3:
		hud.show_system_message("WARD CONSOLE UNLOCKED")


func _use_ward_console() -> void:
	if console_resolved or GameState.is_quest_completed("dream_audit"):
		hud.show_dialogue("System X", "You already pulled the Ward thread. Come home before it pulls back and starts using your government name.")
		return

	if inspected_pods.size() < 3:
		hud.show_dialogue("Linda", "Please complete the wellness walk before touching clinical controls. Ritual first, rebellion second.")
		hud.show_system_message("INSPECT ALL PODS")
		return

	console_resolved = true
	GameState.mark_quest_completed("dream_audit")
	if GameState.get_world_flag("gatebox_node_stabilized"):
		GameState.set_world_flag("ward_audit_sealed", true)
		GameState.add_reputation("Gatebox Corporation", 1)
		GameState.add_item("Corporate Voucher")
		GameState.last_mission_result = "Sealed the Pacification Ward audit"
		hud.show_dialogue("Linda", "Thank you. Three residents have been protected from unauthorized awakening. Consent is calmer when it is asleep.")
		hud.push_log("ward audit sealed for Gatebox")
	else:
		GameState.set_world_flag("ward_wake_coordinates_copied", true)
		GameState.add_reputation("System X", 1)
		GameState.add_reputation("Gatebox Corporation", -1)
		GameState.add_item("Dream Access Key")
		GameState.last_mission_result = "Copied Pacification Ward wake coordinates"
		hud.show_dialogue("Spooky Ghost", "Got the wake coordinates. Tiny little key, enormous bad idea, classic pocket-sized apocalypse.")
		hud.push_log("wake coordinates copied")

	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_system_message("DREAM AUDIT COMPLETE")


func _get_objective_text() -> String:
	if GameState.is_quest_completed("dream_audit") or console_resolved:
		return "Dream Audit complete: return to the Mall. F5 save, F6 load."
	return "Dream Audit: inspect sleep pods %d/3, then use the ward console." % inspected_pods.size()


func _get_linda_line() -> String:
	if GameState.is_quest_completed("dream_audit"):
		if GameState.get_world_flag("ward_audit_sealed"):
			return "Your compliance has improved resident safety. See? Obedience can be cozy when the lights are soft."
		return "You copied patient data without consent. I am disappointed, but still here, which is the part everyone finds difficult."
	return "Please lower your weapon. The residents are dreaming safely, and safety dislikes sudden opinions."


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		console_resolved = GameState.is_quest_completed("dream_audit")
		hud.set_inventory_summary(GameState.get_inventory_summary())
		hud.set_faction_summary(GameState.get_faction_summary())
		hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
		hud.set_objective(_get_objective_text())
		hud.show_dialogue("Linda", _get_linda_line())
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
