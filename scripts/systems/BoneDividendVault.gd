extends Node3D

## General Bone Dividend confrontation — the Big Gates soul-accounting vault the
## informant points you to. A boss arena: read the ledger, decide what to do
## with the racked souls, and put down the General. Resolution lands back at the
## informant in the hub.

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_exit
var focused_interactable
var _general_announced := false


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
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.has_signal("attacked_player"):
			node.attacked_player.connect(hud.push_log)
		if node.has_signal("defeated"):
			node.defeated.connect(_on_general_defeated)

	GameState.set_world_flag("bone_dividend_vault_entered", true)
	GameState.save_game()
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_objective(_objective())
	hud.show_dialogue("Spooky Ghost", "The ledger led here. Soul batteries racked floor to ceiling, each one logged, each one a person reduced to a line item. And the accountant is home.")
	hud.push_log("bone dividend vault")


func _objective() -> String:
	if GameState.get_world_flag("bone_dividend_general_defeated", false):
		return "General down. Decide what to do with the racked souls, then get out."
	return "Confront General Bone Dividend. Read the ledger. Decide about the racks."


func _on_general_defeated() -> void:
	if _general_announced:
		return
	if not GameState.get_world_flag("bone_dividend_general_defeated", false):
		return
	_general_announced = true
	hud.show_dialogue("Spooky Ghost", "The General stops accounting. The ledger stays. The racks stay. Whatever I do next, I do it on purpose.")
	hud.set_objective(_objective())
	hud.push_log("General Bone Dividend defeated")


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_panel_open():
		return
	if event.is_action_pressed("interact") or _key(event, KEY_E):
		_handle_interact()
	elif event.is_action_pressed("save_game") or _key(event, KEY_F5):
		_save()
	elif event.is_action_pressed("load_game") or _key(event, KEY_F6):
		_load()


func _handle_interact() -> void:
	if focused_interactable != null:
		_use_interactable(focused_interactable)
		return
	if focused_exit != null:
		var scene: String = str(focused_exit.target_scene)
		if scene.is_empty():
			scene = "res://scenes/levels/MallHub.tscn"
		GameState.save_game()
		get_tree().change_scene_to_file(scene)


func _use_interactable(it) -> void:
	match it.interactable_id:
		"ledger_terminal":
			GameState.set_world_flag("bone_dividend_ledger_read", true)
			hud.show_dialogue("Soul Ledger", "Every name a quantity. INTAKE, YIELD, DIVIDEND. Ward 7 is one supplier of dozens. The General did not invent the cruelty — they just made it balance. The totals go back years.")
			hud.push_log("soul ledger read — years of accounting")
		"soul_rack":
			if GameState.get_world_flag("bone_dividend_souls_freed", false):
				hud.show_dialogue("Spooky Ghost", "The racks are dark now. Whatever was in them is wherever freed things go.")
				return
			GameState.set_world_flag("bone_dividend_souls_freed", true)
			if GameState.has_method("add_soul_rot"):
				GameState.add_soul_rot(18)
			GameState.add_reputation("System X", 2)
			hud.show_dialogue("Spooky Ghost", "I open every rack. It is not mercy, exactly — there's nowhere good for them to go. But they don't belong to a ledger anymore. My anchor drinks the cost of that.")
			hud.show_system_message("THE RACKED SOULS ARE RELEASED")
			hud.push_log("soul batteries released — soul-rot up, the right thing done")


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


func _save() -> void:
	hud.show_system_message("GAME SAVED" if GameState.save_game() else "SAVE FAILED")


func _load() -> void:
	if GameState.load_game():
		hud.show_system_message("GAME LOADED")
	else:
		hud.show_system_message("NO SAVE FOUND")


func _key(event: InputEvent, code: int) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == code
