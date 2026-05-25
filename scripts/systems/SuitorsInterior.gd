extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var surveillance_light: OmniLight3D = $SurveillanceLight

var focused_npc: NPCDialogue
var focused_exit: MissionExit
var focused_hack_terminal: HackTerminal


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
	for hack_terminal in get_tree().get_nodes_in_group("hack_terminal"):
		hack_terminal.focus_changed.connect(_on_hack_terminal_focus_changed)

	var hack_minigame = hud.get_node_or_null("%HackMinigameUI")
	if hack_minigame and hack_minigame.has_signal("hack_completed"):
		hack_minigame.hack_completed.connect(_on_hack_completed)

	_apply_surveillance_state()
	_refresh_hud()
	hud.show_dialogue("Sunday", "Welcome to Suitors. Speak softly; the cameras are pretending not to listen, and I hate embarrassing them.")
	hud.push_log("suitors surveillance room entered")


func _unhandled_input(event: InputEvent) -> void:
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


func _handle_interact() -> void:
	if focused_hack_terminal != null:
		var result: Dictionary = focused_hack_terminal.interact()
		if GameState.is_quest_completed("suitors_blind_spot"):
			hud.show_dialogue("Surveillance Choir", "The choir is already humming your absence into every camera. You are being forgotten in tasteful harmony.")
			return
		if WorldDirector.active_event != WorldDirector.EVENT_LAN_OUTAGE:
			hud.show_dialogue("Surveillance Choir", "The cameras are too awake. Start or protect a Hoodlum LAN outage, then route the blind spot from here while the eyes are busy panicking.")
			return
		if result.get("start_hack", false):
			hud.show_dialogue(str(result["name"]), "Sunday opens the surveillance choir. Route the signal while the district cameras are blind and trying to remember where they put you.")
			hud.start_hack(int(result.get("difficulty", 1)))
		else:
			hud.show_dialogue(str(result["name"]), str(result["text"]))
		return

	if focused_npc != null:
		var line: Dictionary = focused_npc.interact()
		hud.show_dialogue(str(line["name"]), str(line["text"]))
		_refresh_hud()
		return

	if focused_exit != null:
		get_tree().change_scene_to_file(focused_exit.target_scene)


func _on_hack_completed(success: bool, _difficulty: int) -> void:
	if focused_hack_terminal == null:
		return
	focused_hack_terminal.complete_hack(success)
	if success:
		GameState.mark_quest_completed("suitors_blind_spot")
		GameState.set_world_flag("suitors_surveillance_jammed", true)
		GameState.add_item("Suitors Access Chit")
		GameState.add_reputation("System X", 1)
		GameState.last_mission_result = "Suitors surveillance choir jammed"
		hud.show_dialogue("Sunday", "There. The cameras remember everyone except you. Do not waste the loneliness; it is expensive when bought honestly.")
		hud.push_log("suitors blind spot mapped")
		_apply_surveillance_state()
		_refresh_hud()
	else:
		hud.show_dialogue("Sunday", "The signal slipped. Smile naturally until the cameras stop being interested. Yes, that is the worst possible instruction.")
		hud.push_log("suitors hack failed")


func _apply_surveillance_state() -> void:
	if surveillance_light == null:
		return
	if GameState.get_world_flag("suitors_surveillance_jammed"):
		surveillance_light.light_color = Color(0.15, 1.0, 0.55)
		surveillance_light.light_energy = 2.0
	else:
		surveillance_light.light_color = Color(0.15, 0.85, 1.0)
		surveillance_light.light_energy = 1.2


func _refresh_hud() -> void:
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	if GameState.is_quest_completed("suitors_blind_spot"):
		hud.set_objective("Suitors: return to the district with Sunday's blind spot.")
	else:
		hud.set_objective("Suitors: protect a LAN outage, then hack the surveillance choir.")


func _update_prompt() -> void:
	if focused_hack_terminal != null:
		hud.set_prompt(focused_hack_terminal.prompt_text)
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


func _on_hack_terminal_focus_changed(terminal: HackTerminal, has_focus: bool) -> void:
	focused_hack_terminal = terminal if has_focus else null
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
		_apply_surveillance_state()
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


func _is_tab_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB
