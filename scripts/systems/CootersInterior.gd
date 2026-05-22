extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_npc: NPCDialogue
var focused_exit: MissionExit


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
	if focused_npc != null:
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
	hud.set_objective("Cooters: talk to Marbles or return to the district.")


func _update_prompt() -> void:
	if focused_npc != null:
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
