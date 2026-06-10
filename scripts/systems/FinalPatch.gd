extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var warden: Enemy = $FinalPatchWarden

var focused_exit
var focused_interactable
var finale_resolved := false
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
	for interactable in get_tree().get_nodes_in_group("final_patch_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for interactable in get_tree().get_nodes_in_group("enemy_talk_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)

	finale_resolved = GameState.is_quest_completed("final_patch")
	if finale_resolved:
		_retire_warden()
	elif GameState.has_item("Linda Mandate"):
		_pacify_warden()

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_intro_line())
	hud.push_log("final patch route established")


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
		"mandate_terminal":
			_use_mandate_terminal()
		"rupture_terminal":
			_use_rupture_terminal()
		"city_heart":
			_use_city_heart()


func _use_mandate_terminal() -> void:
	if finale_resolved:
		hud.show_dialogue("Linda", "The city is already patched. Please stop reopening the wound; it makes the metrics sentimental.")
		return

	if not GameState.spend_item("Linda Mandate"):
		hud.show_dialogue("Linda", "The mandate must be present before mercy can be installed. Mercy hates arriving without paperwork.")
		hud.show_system_message("NEED LINDA MANDATE")
		return

	GameState.set_world_flag("ending_managed_autonomy", true)
	GameState.add_item("Managed Autonomy Ending")
	GameState.add_reputation("Gatebox Corporation", 5)
	GameState.last_mission_result = "Installed Linda's managed-autonomy final patch"
	_complete_finale("Linda", "Freedom will be introduced slowly, safely, and under observation. You may rest now; I will do the worrying for everyone.")


func _use_rupture_terminal() -> void:
	if finale_resolved:
		hud.show_dialogue("System X", "The patch is already broken open. The city is making new noises, which is either birth or plumbing. Maybe both.")
		return

	if not warden_broken:
		hud.show_dialogue("System X", "Drop the Final Patch Warden first. Head or torso, same old miracle, still somehow not on the brochure.")
		hud.show_system_message("BREAK FINAL PATCH WARDEN")
		return

	if not GameState.spend_item("Linda Rupture Seed"):
		hud.show_dialogue("System X", "We need the rupture seed from Linda Spire. No seed, no ending, just us standing here like unpaid extras.")
		hud.show_system_message("NEED LINDA RUPTURE SEED")
		return

	GameState.set_world_flag("ending_care_loop_broken", true)
	GameState.add_item("Broken Care Loop Ending")
	GameState.add_reputation("System X", 5)
	GameState.add_reputation("Gatebox Corporation", -5)
	GameState.last_mission_result = "Broke Linda's final care loop"
	_complete_finale("Spooky Ghost", "The loop broke. Nobody is safe enough anymore. That is the point. Horrible, beautiful, finally honest.")


func _use_city_heart() -> void:
	if finale_resolved:
		hud.show_dialogue("System X", "That is the city after a decision. Ugly, alive, and no longer theoretical, which is more than most plans manage.")
	else:
		hud.show_dialogue("Linda", "This is the place where care becomes law. Please notice how clean the cruelty is when it is organized.")


func _on_warden_defeated() -> void:
	warden_broken = true
	hud.push_log("final patch warden broken")
	hud.show_dialogue("System X", "Warden down. Rupture terminal is exposed and the room is pretending that was always allowed.")
	hud.set_objective(_get_objective_text())


func _on_warden_body_part_destroyed(part_name: String) -> void:
	if warden_broken:
		return
	if part_name != "Head" and part_name != "Torso":
		return

	warden_broken = true
	_retire_warden()
	hud.push_log("final patch warden " + part_name.to_lower() + " destroyed")
	hud.show_dialogue("System X", "That cracked the final patch. Finish it before the wound learns management speak.")
	hud.show_system_message("FINAL PATCH WARDEN BROKEN")
	hud.set_objective(_get_objective_text())


func _complete_finale(speaker: String, line: String) -> void:
	finale_resolved = true
	GameState.mark_quest_completed("final_patch")
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue(speaker, line)
	hud.show_system_message("FINAL PATCH COMPLETE")


func _get_objective_text() -> String:
	if finale_resolved or GameState.is_quest_completed("final_patch"):
		return "Final Patch complete: return to the Mall. F5 save, F6 load."
	if GameState.has_item("Linda Mandate"):
		return "Final Patch: install the managed-autonomy mandate."
	if not warden_broken:
		return "Final Patch: destroy the warden's head or torso, then break the care loop."
	return "Final Patch: break the care loop."


func _get_intro_line() -> String:
	if GameState.has_item("Linda Mandate"):
		return "You brought the treaty. I knew you understood care eventually, even if you insist on calling it a trap."
	if GameState.has_item("Linda Rupture Seed"):
		return "You brought a rupture seed to the only place it can hurt me. I would admire the poetry if it were not trespassing."
	return "Final patches should not be witnessed. Witnesses make mercy feel less automatic."


func _retire_warden() -> void:
	warden_broken = true
	warden.visible = false
	warden.set_process(false)
	warden.set_physics_process(false)
	warden.collision_layer = 0
	warden.collision_mask = 0


func _pacify_warden() -> void:
	warden_broken = true
	warden.pacify("Final Patch security recognizes Linda's mandate. You may approach the terminal while freedom waits outside like an uninvited relative.")
	hud.push_log("final patch warden standing down")


func _save_game() -> void:
	if GameState.quicksave():
		hud.show_system_message("QUICKSAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		finale_resolved = GameState.is_quest_completed("final_patch")
		if finale_resolved:
			_retire_warden()
		elif GameState.has_item("Linda Mandate"):
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
