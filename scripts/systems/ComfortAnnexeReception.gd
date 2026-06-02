extends Node3D

## Ward 7 — Comfort Annexe, Scene 1: Reception (the lie).
## A functioning-looking Gatebox ward. No quest on entry; the building teaches.
## Mirrors the PacificationWard level pattern: HUD wiring, mission_exit +
## ward_interactable groups, a HackTerminal checkpoint, one Warden patrol.

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_exit
var focused_interactable
var focused_terminal
var _dead_unit_spent := false


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
	for terminal in get_tree().get_nodes_in_group("hack_terminal"):
		terminal.focus_changed.connect(_on_terminal_focus_changed)
	var hack_ui = hud.get_node_or_null("%HackMinigameUI")
	if hack_ui != null and not hack_ui.hack_completed.is_connected(_on_hack_completed):
		hack_ui.hack_completed.connect(_on_hack_completed)

	# Entry: no quest. The building writes the first flag and draws corporate notice.
	GameState.set_world_flag("ward7_entered", true)
	if not GameState.get_world_flag("ward7_attention_entry_charged", false):
		GameState.add_gatebox_attention(1)
		GameState.set_world_flag("ward7_attention_entry_charged", true)

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_objective("Comfort Annexe — Reception. Nobody briefed you. Look around.")
	hud.show_dialogue("Spooky Ghost", "Front door opened for me without a fight. That is its own kind of wrong.")
	hud.push_log("comfort annexe: reception")


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
	if focused_terminal != null:
		var result: Dictionary = focused_terminal.interact()
		if result.get("start_hack", false):
			hud.show_dialogue(str(result["name"]), str(result["text"]))
			hud.start_hack(int(result.get("difficulty", 1)))
		else:
			hud.show_dialogue(str(result["name"]), str(result["text"]))
		return
	if focused_interactable != null:
		_use_interactable(focused_interactable)
		return
	if focused_exit != null:
		var scene: String = str(focused_exit.target_scene)
		if scene.is_empty():
			scene = "res://scenes/levels/MallHub.tscn"
		GameState.save_game()
		get_tree().change_scene_to_file(scene)


func _use_interactable(interactable) -> void:
	match interactable.interactable_id:
		"intake_terminal":
			GameState.set_world_flag("ward7_intake_terminal_read", true)
			hud.show_dialogue("Wellness Intake", "847 registered residents. All green. Comfort ratings nominal, dream stability nominal. Most recent check-ins: this morning, auto-updated. Everyone is fine. The screen is very sure about that.")
			hud.push_log("intake: 847 residents, all logged green")
			var kiosk = get_node_or_null("CompanionKiosk/PromoAudio")
			if kiosk != null:
				kiosk.stop()
				hud.show_system_message("COMPANION PROMO LOOP DISABLED")
		"companion_kiosk":
			hud.show_dialogue("Companion Kiosk", "...rest easy. Your loved one is safe with us. Rest easy. Your loved one is— [the loop swallows a word and continues].")
		"dead_companion":
			if _dead_unit_spent:
				hud.show_dialogue("Spooky Ghost", "It's dark again. Whatever it almost said, it isn't saying it twice.")
				return
			_dead_unit_spent = true
			GameState.set_world_flag("ward7_dead_unit_activated", true)
			hud.show_dialogue("Companion Unit", "Welcome to comfort. Welcome to comfort. Please do not — [the approved words bend around something else] — please do not let them. Welcome to comfort.")
			hud.push_log("the dead companion unit said something off-script")


func _on_hack_completed(success: bool, _difficulty: int) -> void:
	if focused_terminal == null:
		return
	if focused_terminal.terminal_id != "ward7_security_terminal":
		return
	if success:
		focused_terminal.complete_hack(true)
		GameState.set_world_flag("ward7_commlog_found", true)
		var gate = get_node_or_null("CheckpointGate")
		if gate != null:
			gate.queue_free()
		hud.show_dialogue("Security Terminal", "Gate released. Maintenance log, last entry: external comm relay offline 4 months. Nobody filed it. Somebody wanted it quiet.")
		hud.show_system_message("CHECKPOINT OPEN")
		hud.push_log("security: comm relay deliberately offline")
	else:
		hud.show_system_message("SOFT ALARM — WARDEN INVESTIGATING")
		for node in get_tree().get_nodes_in_group("enemy"):
			if node.has_method("alert"):
				node.alert()


func _on_exit_focus_changed(mission_exit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_interactable_focus_changed(interactable, has_focus: bool) -> void:
	focused_interactable = interactable if has_focus else null
	_update_prompt()


func _on_terminal_focus_changed(terminal, has_focus: bool) -> void:
	focused_terminal = terminal if has_focus else null
	_update_prompt()


func _update_prompt() -> void:
	if focused_terminal != null:
		hud.set_prompt(focused_terminal.prompt_text)
	elif focused_interactable != null:
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
