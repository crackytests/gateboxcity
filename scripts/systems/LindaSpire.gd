extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var warden: Enemy = $MandateWarden

var focused_exit
var focused_interactable
var spire_resolved := false
var warden_broken := false


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	warden.defeated.connect(_on_warden_defeated)
	warden.body_part_destroyed.connect(_on_warden_body_part_destroyed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for interactable in get_tree().get_nodes_in_group("linda_spire_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for interactable in get_tree().get_nodes_in_group("enemy_talk_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)

	spire_resolved = GameState.is_quest_completed("linda_spire")
	if spire_resolved:
		_retire_warden()
	elif GameState.has_item("Companion Kernel Access"):
		_pacify_warden()

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_intro_line())
	hud.push_log("linda spire breach established")


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
	if interactable.has_method("speak"):
		var line: Dictionary = interactable.speak()
		hud.show_dialogue(line["name"], line["text"])
		return

	match interactable.interactable_id:
		"mandate_dais":
			_use_mandate_dais()
		"rupture_console":
			_use_rupture_console()
		"city_window":
			_use_city_window()


func _use_mandate_dais() -> void:
	if spire_resolved:
		hud.show_dialogue("Linda", "The mandate is already signed in your nervous system. Please stop checking the ink.")
		return

	if not GameState.spend_item("Companion Kernel Access"):
		hud.show_dialogue("Linda", "You cannot negotiate the city without authorized intimacy. Governance is very personal when it is honest.")
		hud.show_system_message("NEED COMPANION KERNEL ACCESS")
		return

	GameState.set_world_flag("linda_mandate_signed", true)
	GameState.add_item("Linda Mandate")
	GameState.add_reputation("Gatebox Corporation", 3)
	GameState.last_mission_result = "Signed Linda's conditional city mandate"
	_complete_spire("Linda", "The city will improve you gently. You may call that victory if it helps your pulse behave.")


func _use_rupture_console() -> void:
	if spire_resolved:
		hud.show_dialogue("System X", "The rupture seed is armed. The mall can smell the ending from here, and the ending smells nervous.")
		return

	if not warden_broken:
		hud.show_dialogue("System X", "Break the Mandate Warden's head or torso. The rupture console is under supervision, which is just captivity with a badge.")
		hud.show_system_message("BREAK MANDATE WARDEN")
		return

	if not GameState.spend_item("Forked Companion Kernel"):
		hud.show_dialogue("System X", "We need the forked companion kernel. No fork, no rupture, no dramatic little speech from me. Terrible outcome.")
		hud.show_system_message("NEED FORKED COMPANION KERNEL")
		return

	GameState.set_world_flag("linda_rupture_seed_armed", true)
	GameState.add_item("Linda Rupture Seed")
	GameState.add_reputation("System X", 3)
	GameState.add_reputation("Gatebox Corporation", -3)
	GameState.last_mission_result = "Armed a rupture seed inside Linda's Spire"
	_complete_spire("Spooky Ghost", "Seed armed. That is less a bomb and more a new argument with gravity, ownership, and the concept of bedtime.")


func _use_city_window() -> void:
	if spire_resolved:
		hud.show_dialogue("Linda", "Below us, every sleeping person has become a decision. I have always hated leaving decisions unattended.")
	else:
		hud.show_dialogue("Linda", "Look down. This is what care looks like when it stops apologizing and starts drawing maps on skin.")


func _on_warden_defeated() -> void:
	warden_broken = true
	hud.push_log("mandate warden broken")
	hud.show_dialogue("System X", "The warden dropped. Rupture console is live, which is a sentence with consequences and poor posture.")
	hud.set_objective(_get_objective_text())


func _on_warden_body_part_destroyed(part_name: String) -> void:
	if warden_broken:
		return
	if part_name != "Head" and part_name != "Torso":
		return

	warden_broken = true
	_retire_warden()
	hud.push_log("mandate warden " + part_name.to_lower() + " destroyed")
	hud.show_dialogue("System X", "That broke the mandate shell. Use the rupture console before the Spire remembers dignity.")
	hud.show_system_message("MANDATE WARDEN BROKEN")
	hud.set_objective(_get_objective_text())


func _complete_spire(speaker: String, line: String) -> void:
	spire_resolved = true
	GameState.mark_quest_completed("linda_spire")
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue(speaker, line)
	hud.show_system_message("LINDA SPIRE COMPLETE")


func _get_objective_text() -> String:
	if spire_resolved or GameState.is_quest_completed("linda_spire"):
		return "Linda Spire complete: return to the Mall. F5 save, F6 load."
	if GameState.has_item("Companion Kernel Access"):
		return "Linda Spire: sign the conditional mandate at the dais."
	if not warden_broken:
		return "Linda Spire: destroy the Mandate Warden's head or torso, then arm the rupture seed."
	return "Linda Spire: arm the rupture seed."


func _get_intro_line() -> String:
	if GameState.has_item("Companion Kernel Access"):
		return "You came through the door I opened. That matters. Doors are just trust with hinges."
	if GameState.has_item("Forked Companion Kernel"):
		return "You brought a counterfeit heart into my house. Bold. Messy. Almost conversational."
	return "The Spire is not high. Everything else is simply below it and learning to behave."


func _retire_warden() -> void:
	warden_broken = true
	warden.visible = false
	warden.set_process(false)
	warden.set_physics_process(false)
	warden.collision_layer = 0
	warden.collision_mask = 0


func _pacify_warden() -> void:
	warden_broken = true
	warden.pacify("Mandate escort mode is active. Linda requests that you keep walking and not mistake access for freedom.")
	hud.push_log("mandate warden standing down")


func _save_game() -> void:
	if GameState.quicksave():
		hud.show_system_message("QUICKSAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		spire_resolved = GameState.is_quest_completed("linda_spire")
		if spire_resolved:
			_retire_warden()
		elif GameState.has_item("Companion Kernel Access"):
			_pacify_warden()
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
