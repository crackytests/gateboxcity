extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_npc: NPCDialogue
var focused_exit: MissionExit
var focused_interactable: WardInteractable


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	WorldDirector.world_state_changed.connect(hud.set_world_state)
	WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)

	for npc in get_tree().get_nodes_in_group("npc"):
		npc.focus_changed.connect(_on_npc_focus_changed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for interactable in get_tree().get_nodes_in_group("district_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	if hud.job_board_ui != null and not hud.job_board_ui.job_accepted.is_connected(_on_job_board_accepted):
		hud.job_board_ui.job_accepted.connect(_on_job_board_accepted)

	_refresh_hud()
	hud.show_dialogue("Marbles", "Welcome to Cooters. No fighting the contained rain mutant unless it starts a tab.")
	hud.push_log("cooters back room unlocked")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("save_game") or _is_save_key(event):
		_save_game()
	elif event.is_action_pressed("load_game") or _is_load_key(event):
		_load_game()


func _handle_interact() -> void:
	if focused_interactable != null:
		_handle_interactable(focused_interactable)
		return

	if focused_npc != null:
		if focused_npc.npc_name == "Marbles":
			_handle_marbles()
			return
		var line: Dictionary = focused_npc.interact()
		hud.show_dialogue(str(line["name"]), str(line["text"]))
		_refresh_hud()
		return

	if focused_exit != null:
		get_tree().change_scene_to_file(focused_exit.target_scene)


func _refresh_hud() -> void:
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.set_objective(_get_objective_text())


func _handle_interactable(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"cooters_job_board":
			hud.open_job_board(GameState.get_available_jobs(), GameState.active_job_id)
		_:
			hud.show_dialogue(interactable.display_name, "Cooters has not found a use for that yet.")


func _handle_marbles() -> void:
	var active_job := GameState.get_active_job_data()
	if active_job.is_empty():
		hud.show_dialogue("Marbles", "Board is on the wall. Take one job at a time; the building gets jealous if we call it logistics.")
		_refresh_hud()
		return

	if GameState.is_job_objective_done(GameState.active_job_id):
		var paid_job := GameState.complete_active_job()
		if paid_job.is_empty():
			hud.show_dialogue("Marbles", "Something about your tab got weird. Try the board again.")
		else:
			hud.show_dialogue("Marbles", "Good work. Payment: %s. Do not spend it all on liquids with opinions." % str(paid_job.get("reward_text", "bar credit")))
			hud.push_log("cooters job paid: %s" % str(paid_job.get("title", "job")).to_lower())
		_refresh_hud()
		return

	hud.show_dialogue("Marbles", str(active_job.get("details", active_job.get("objective", "Finish the job and come back breathing."))))
	_refresh_hud()


func _on_job_board_accepted(job_id: String) -> void:
	if GameState.accept_job(job_id):
		var job := GameState.get_job_data(job_id)
		hud.show_dialogue("Marbles", "Posted and witnessed: %s. Use the Leak Street gate, then come back when the job stops moving." % str(job.get("title", job_id)))
		hud.push_log("cooters job accepted: %s" % str(job.get("title", job_id)).to_lower())
	else:
		hud.show_dialogue("Marbles", "One job at a time. Cooters is a bar, not a personality disorder.")
	_refresh_hud()


func _get_objective_text() -> String:
	if GameState.active_job_id.is_empty():
		return "Cooters: choose a job from the board or return to Leak Street."
	return "Cooters job: %s" % GameState.get_active_job_objective_text()


func _update_prompt() -> void:
	if focused_interactable != null:
		hud.set_prompt(focused_interactable.prompt_text)
	elif focused_npc != null:
		hud.set_prompt(focused_npc.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	else:
		hud.set_prompt("")


func _on_npc_focus_changed(npc: NPCDialogue, has_focus: bool) -> void:
	focused_npc = npc if has_focus else null
	_update_prompt()


func _on_exit_focus_changed(mission_exit: MissionExit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_interactable_focus_changed(interactable: WardInteractable, has_focus: bool) -> void:
	focused_interactable = interactable if has_focus else null
	_update_prompt()


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		WorldDirector.restore_from_game_state()
		WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)
		_refresh_hud()
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
