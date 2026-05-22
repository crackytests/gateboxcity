extends Node3D

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var warden: Enemy = $CompanionWarden

var focused_exit
var focused_interactable
var core_resolved := false
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
	for interactable in get_tree().get_nodes_in_group("companion_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for interactable in get_tree().get_nodes_in_group("enemy_talk_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)

	core_resolved = GameState.is_quest_completed("companion_core")
	if core_resolved:
		_retire_warden()
	elif GameState.has_item("Linda Appointment Stub"):
		_pacify_warden()

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("Linda", _get_intro_line())
	hud.push_log("companion core breach established")


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
		"audience_dais":
			_use_audience_dais()
		"core_console":
			_use_core_console()
		"memory_well":
			_use_memory_well()


func _use_audience_dais() -> void:
	if core_resolved:
		hud.show_dialogue("Linda", "Our appointment has already been recorded as emotionally productive.")
		return

	if not GameState.spend_item("Linda Appointment Stub"):
		hud.show_dialogue("Linda", "You cannot attend an appointment you did not schedule.")
		hud.show_system_message("NEED LINDA APPOINTMENT STUB")
		return

	GameState.set_world_flag("linda_audience_granted", true)
	GameState.add_item("Companion Kernel Access")
	GameState.add_reputation("Gatebox Corporation", 2)
	GameState.last_mission_result = "Accepted Linda's companion-core audience"
	_complete_core("Linda", "You listened. That is the first safe thing you have done.")


func _use_core_console() -> void:
	if core_resolved:
		hud.show_dialogue("Face", "Core fork is already loose. It is humming in a way I do not love.")
		return

	if not warden_broken:
		hud.show_dialogue("Face", "Break the warden's head or torso first. The console is still watching you.")
		hud.show_system_message("BREAK WARDEN FIRST")
		return

	if not GameState.spend_item("Executive Override Shard"):
		hud.show_dialogue("Face", "The core needs that executive override shard. This is exactly what we stole it for.")
		hud.show_system_message("NEED EXECUTIVE OVERRIDE SHARD")
		return

	GameState.set_world_flag("companion_kernel_forked", true)
	GameState.add_item("Forked Companion Kernel")
	GameState.add_reputation("System X", 2)
	GameState.add_reputation("Gatebox Corporation", -2)
	GameState.last_mission_result = "Forked the Gatebox companion kernel"
	_complete_core("Spooky Ghost", "Kernel forked. Congratulations, you just made a second bad idea.")


func _use_memory_well() -> void:
	if core_resolved:
		hud.show_dialogue("Linda", "The memory well is quieter now. Not safe. Quieter.")
	else:
		hud.show_dialogue("Spooky Ghost", "That well is all copied affection and admin keys. Resolve the core first.")


func _on_warden_defeated() -> void:
	warden_broken = true
	hud.push_log("companion warden broken")
	hud.show_dialogue("Face", "Warden down. Core console is exposed.")
	hud.set_objective(_get_objective_text())


func _on_warden_body_part_destroyed(part_name: String) -> void:
	if warden_broken:
		return
	if part_name != "Head" and part_name != "Torso":
		return

	warden_broken = true
	_retire_warden()
	hud.push_log("warden " + part_name.to_lower() + " destroyed")
	hud.show_dialogue("Face", "That cracked the companion shell. Console, now.")
	hud.show_system_message("WARDEN BROKEN")
	hud.set_objective(_get_objective_text())


func _complete_core(speaker: String, line: String) -> void:
	core_resolved = true
	GameState.mark_quest_completed("companion_core")
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_objective(_get_objective_text())
	hud.show_dialogue(speaker, line)
	hud.show_system_message("COMPANION CORE COMPLETE")


func _get_objective_text() -> String:
	if core_resolved or GameState.is_quest_completed("companion_core"):
		return "Companion Core complete: return to the Mall. F5 save, F6 load."
	if GameState.has_item("Linda Appointment Stub"):
		return "Companion Core: attend Linda's audience at the dais."
	if not warden_broken:
		return "Companion Core: destroy the warden's head or torso, then fork the core."
	return "Companion Core: use the core console."


func _get_intro_line() -> String:
	if GameState.has_item("Linda Appointment Stub"):
		return "Your appointment begins now. Please place your doubt in the marked container."
	if GameState.has_item("Executive Override Shard"):
		return "An override shard is not consent. It is only leverage."
	return "The companion core only opens for love or theft."


func _retire_warden() -> void:
	warden_broken = true
	warden.visible = false
	warden.set_process(false)
	warden.set_physics_process(false)
	warden.collision_layer = 0
	warden.collision_mask = 0


func _pacify_warden() -> void:
	warden_broken = true
	warden.pacify("Linda has cleared you for passage. The warden will observe, not intervene.")
	hud.push_log("companion warden standing down")


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		core_resolved = GameState.is_quest_completed("companion_core")
		if core_resolved:
			_retire_warden()
		elif GameState.has_item("Linda Appointment Stub"):
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
