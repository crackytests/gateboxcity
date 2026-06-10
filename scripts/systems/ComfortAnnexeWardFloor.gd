extends Node3D

const COMFORT_TEXTURES := preload("res://scripts/systems/ComfortAnnexeTextures.gd")

## Ward 7 — Comfort Annexe, Scene 2: The Ward Floor (the math).
## The pod grid shows more red (empty-but-logged) than green. The nursing
## terminal explains the discrepancy and arms the emergent quest. One Warden,
## one failed graft from the crawlspace, and a restricted door to the sublevel.

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_exit
var focused_interactable
var focused_terminal
var _nurse_talks := 0
var _graft: Node3D
var _graft_seen := false


func _ready() -> void:
	COMFORT_TEXTURES.apply_ward_floor(self)
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
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.has_signal("attacked_player"):
			node.attacked_player.connect(hud.push_log)
	var hack_ui = hud.get_node_or_null("%HackMinigameUI")
	if hack_ui != null and not hack_ui.hack_completed.is_connected(_on_hack_completed):
		hack_ui.hack_completed.connect(_on_hack_completed)

	var grafts := get_tree().get_nodes_in_group("graft")
	if not grafts.is_empty():
		_graft = grafts[0]

	GameState.save_game()  # autosave on scene entry
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_objective("Ward Floor. Count the red pods. Read the nursing terminal.")
	hud.show_dialogue("Spooky Ghost", "847 residents on the sign upstairs. I can count the green pods from here. It isn't 847.")
	hud.push_log("comfort annexe: ward floor")


func _process(_delta: float) -> void:
	if _graft_seen or _graft == null or not is_instance_valid(_graft):
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null and p.global_position.distance_to(_graft.global_position) < 7.0:
		_graft_seen = true
		GameState.set_world_flag("ward7_first_graft_encountered", true)
		hud.show_dialogue("Spooky Ghost", "Something in the crawlspace. Scraping. It stops when I stop. It is not maintenance.")
		hud.push_log("something is moving in the row H crawlspace")


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
			return
		GameState.save_game()
		get_tree().change_scene_to_file(scene)


func _use_interactable(interactable) -> void:
	match interactable.interactable_id:
		"nursing_terminal":
			GameState.set_world_flag("ward7_pod_discrepancy_found", true)
			hud.show_dialogue("Nursing Terminal", "847 registered. 612 in pods. 235 on TEMPORARY LEAVE — flagged by an admin credential that fits no Gatebox format. The restricted corridor lock was swapped 4 months back: third-party compatible. Sublevel maintenance booked weekly under the same fake account.")
			hud.push_log("nursing terminal: 235 residents 'checked out' by a forged admin")
			hud.set_objective("235 residents missing. The restricted corridor leads down. Find out.")
		"nurse_companion":
			_nurse_talks += 1
			if _nurse_talks == 1:
				hud.show_dialogue("Companion Unit", "Welcome. Your loved one is resting comfortably. Would you like me to walk you to their pod?")
			else:
				GameState.set_world_flag("ward7_companion_unit_questioned", true)
				hud.show_dialogue("Companion Unit", "That area is currently undergoing scheduled maintenance. We appreciate your patience and care.")
				hud.push_log("the companion has said that about the door for four months")
		"wrong_pod":
			hud.show_dialogue("Spooky Ghost", "This pod's padding is pushed out, not in. Pressure marks on the inside walls. Whatever left here pushed its way out, and it was bigger than a sleeping person.")


func _on_hack_completed(success: bool, _difficulty: int) -> void:
	if focused_terminal == null or focused_terminal.terminal_id != "ward7_restricted_corridor":
		return
	if success:
		focused_terminal.complete_hack(true)
		var door = get_node_or_null("RestrictedDoor")
		if door != null:
			door.queue_free()
		hud.show_system_message("RESTRICTED CORRIDOR OPEN")
		hud.show_dialogue("Spooky Ghost", "Lock's third-party. Whoever put it here did not want Gatebox opening it either.")
	else:
		hud.show_system_message("LOCK HELD")


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
	hud.show_system_message("QUICKSAVED" if GameState.quicksave() else "SAVE FAILED")


func _load() -> void:
	if GameState.load_game():
		hud.show_system_message("GAME LOADED")
	else:
		hud.show_system_message("NO SAVE FOUND")


func _key(event: InputEvent, code: int) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == code
