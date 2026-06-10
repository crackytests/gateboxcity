extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_exit
var focused_interactable
var lobby_resolved := false


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for interactable in get_tree().get_nodes_in_group("spire_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for security_node in get_tree().get_nodes_in_group("security_node"):
		security_node.attacked_player.connect(hud.push_log)
		security_node.defeated.connect(_on_security_node_defeated)

	lobby_resolved = GameState.is_quest_completed("spire_lobby")
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_intro_line())
	hud.push_log("spire lobby route established")


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
		"reception":
			_use_reception()
		"service_panel":
			_use_service_panel()
		"elevator":
			_use_elevator()


func _use_reception() -> void:
	if lobby_resolved:
		hud.show_dialogue("Linda", "Reception has already filed your presence under acceptable anomaly. Please do not become interesting twice.")
		return

	if not GameState.spend_item("Gatebox Visitor Badge"):
		hud.show_dialogue("Linda", "Reception requires a visitor badge, a smile, and fewer questions. Two of those can be faked.")
		hud.show_system_message("NEED GATEBOX VISITOR BADGE")
		return

	GameState.set_world_flag("spire_compliance_clearance", true)
	GameState.add_item("Companion Clearance")
	GameState.add_reputation("Gatebox Corporation", 1)
	GameState.last_mission_result = "Accepted Spire lobby compliance clearance"
	_complete_lobby("Linda", "Thank you for checking in. Your companion clearance has been provisioned, polished, and made slightly too personal.")


func _use_service_panel() -> void:
	if lobby_resolved:
		hud.show_dialogue("Spooky Ghost", "Panel is dry. Already stole the meaningful bits. It is just wall confidence now.")
		return

	if not GameState.spend_item("Spire Transit Pass"):
		hud.show_dialogue("System X", "That panel wants the forged Spire pass. It is picky for a wall rectangle with screws showing.")
		hud.show_system_message("NEED SPIRE TRANSIT PASS")
		return

	GameState.set_world_flag("spire_elevator_trace_stolen", true)
	GameState.add_item("Executive Elevator Trace")
	GameState.add_reputation("System X", 1)
	GameState.add_reputation("Gatebox Corporation", -1)
	GameState.last_mission_result = "Stole an executive elevator trace from the Spire lobby"
	_complete_lobby("Spooky Ghost", "Elevator trace copied. Upper floors now have a little door-shaped problem with your name misspelled on it.")


func _use_elevator() -> void:
	if lobby_resolved:
		hud.push_log("launching executive elevator")
		get_tree().change_scene_to_file("res://scenes/levels/ExecutiveSuite.tscn")
	else:
		hud.show_dialogue("Linda", "Executive floors are not available from an unprocessed body. Please become paperwork first.")
		hud.show_system_message("RESOLVE LOBBY ACCESS FIRST")


func _complete_lobby(speaker: String, line: String) -> void:
	lobby_resolved = true
	GameState.mark_quest_completed("spire_lobby")
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue(speaker, line)
	hud.show_system_message("SPIRE LOBBY COMPLETE")


func _on_security_node_defeated() -> void:
	hud.push_log("security node offline")
	hud.show_dialogue("System X", "Nice. Corporate reception just lost an eye. Somewhere a lobby fern feels unsafe.")


func _get_objective_text() -> String:
	if lobby_resolved or GameState.is_quest_completed("spire_lobby"):
		return "Spire Lobby complete: return to the Mall. F5 save, F6 load."
	if GameState.has_item("Gatebox Visitor Badge"):
		return "Spire Lobby: check in at reception, or find another way through."
	if GameState.has_item("Spire Transit Pass"):
		return "Spire Lobby: use the service panel to steal elevator routing."
	return "Spire Lobby: find a usable access credential."


func _get_intro_line() -> String:
	if GameState.get_world_flag("transit_compliance_pass"):
		return "Welcome, visitor. Please enjoy approved verticality and refrain from developing upward ambition."
	if GameState.get_world_flag("transit_spire_route_open"):
		return "This lobby does not recognize your pass, which means it recognizes it perfectly and hates the bit."
	return "You have reached a floor where politeness is enforced and sincerity is searched at the door."


func _save_game() -> void:
	if GameState.quicksave():
		hud.show_system_message("QUICKSAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		lobby_resolved = GameState.is_quest_completed("spire_lobby")
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
