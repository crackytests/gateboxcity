extends Node3D

const COMFORT_TEXTURES := preload("res://scripts/systems/ComfortAnnexeTextures.gd")

## Ward 7 — Comfort Annexe, Scene 3: The Sublevel (the truth).
## A still-active Big Gates crime scene. Holds the moral choices: the occupied
## pod, the experiment terminal, the overseer terminal. Entry arms the emergent
## quest. No lore dumps down here — the evidence speaks.

@onready var hud: HUDController = $HUD
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_exit
var focused_interactable
var _sleeper: Node3D
var _sleeper_woken := false
var _sleeper_wake_timer := -1.0


func _ready() -> void:
	COMFORT_TEXTURES.apply_sublevel(self)
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
	# Caged grafts idle until released.
	for caged in get_tree().get_nodes_in_group("caged_graft"):
		caged.is_pacified = true
	var sleepers := get_tree().get_nodes_in_group("sleeper_graft")
	if not sleepers.is_empty():
		_sleeper = sleepers[0]
		_sleeper.is_pacified = true

	# Entry truth-beats.
	GameState.set_world_flag("ward7_sublevel_accessed", true)
	if not GameState.get_world_flag("ward7_attention_sublevel_charged", false):
		GameState.add_gatebox_attention(1)
		GameState.set_world_flag("ward7_attention_sublevel_charged", true)
	_check_emergent_quest()
	GameState.save_game()

	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_objective("Sublevel. The warm lights are gone. This is where the residents went.")
	hud.show_dialogue("Spooky Ghost", "The companion music stops at the stairs. Below: work lights, machinery, and something that used to be a voice.")
	hud.push_log("comfort annexe: sublevel")


func _check_emergent_quest() -> void:
	if GameState.get_world_flag("ward7_quest_logged", false):
		return
	if GameState.get_world_flag("ward7_pod_discrepancy_found", false) and GameState.get_world_flag("ward7_sublevel_accessed", false):
		GameState.set_world_flag("ward7_quest_logged", true)
		GameState.last_mission_result = "Something is wrong at Ward 7."
		hud.show_system_message("LOGGED: Something Wrong At Ward 7")
		hud.push_log("note logged: what's down here is worth reporting")


func _process(delta: float) -> void:
	# The sleeper: not asleep — waiting. Looks up, holds, then attacks.
	if _sleeper == null or not is_instance_valid(_sleeper) or _sleeper_woken:
		return
	if _sleeper_wake_timer < 0.0:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null and p.global_position.distance_to(_sleeper.global_position) < 4.0:
			_sleeper_wake_timer = 2.0
			hud.show_dialogue("Spooky Ghost", "It lifts its head. It looks at me. For a second there is something there — recognition, or the last reflex of a person trying to ask for something.")
	elif _sleeper_wake_timer > 0.0:
		_sleeper_wake_timer = maxf(_sleeper_wake_timer - delta, 0.0)
		if _sleeper_wake_timer <= 0.0:
			_sleeper_woken = true
			_sleeper.is_pacified = false
			if _sleeper.has_method("alert"):
				_sleeper.alert()
			hud.push_log("the sleeper is awake")


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
			return
		GameState.save_game()
		get_tree().change_scene_to_file(scene)


func _use_interactable(it) -> void:
	match it.interactable_id:
		"transfer_log":
			GameState.set_world_flag("ward7_transfer_log_read", true)
			hud.show_dialogue("Transfer Log", "235 transferred to sublevel. 178 conversion attempts. 57 VIABLE. 121 NON-VIABLE — disposal noted. It's written in Gatebox's own clean corporate format. That is the most disturbing thing in the building.")
			hud.push_log("transfer log: 235 in, 57 viable, 121 disposed")
		"experiment_download":
			if GameState.get_world_flag("ward7_experiment_docs_found", false):
				hud.show_dialogue("Experiment Terminal", "Already copied. The full scope is on your deck and it will not get less heavy.")
				return
			GameState.set_world_flag("ward7_experiment_docs_found", true)
			GameState.add_item("Experiment Data")
			GameState.add_reputation("System X", 1)
			hud.show_dialogue("Experiment Terminal", "Authorization codes. Weapon-testing objectives. Next intake from Ward 7: two days out, 40 residents flagged. Downloaded. Big Gates is going to notice this is gone.")
			hud.push_log("experiment docs downloaded — Big Gates now hostile")
		"experiment_destroy":
			if GameState.get_world_flag("ward7_terminal_destroyed", false):
				return
			GameState.set_world_flag("ward7_terminal_destroyed", true)
			GameState.set_world_flag("ward7_linda_wellness_pending", true)
			GameState.add_gatebox_attention(2)
			var et = get_node_or_null("ExperimentTerminal")
			if et != null:
				et.queue_free()
			hud.show_dialogue("Spooky Ghost", "Smashed it. The operation's blind now — but so is anyone who wanted the evidence. Including me.")
			hud.push_log("experiment terminal destroyed — evidence gone, attention up")
		"occupied_pod_wake":
			if _pod_resolved():
				return
			GameState.set_world_flag("ward7_resident_rescued", true)
			GameState.apply_timed_effect("escort_burden", {"label": "Escorting", "active_duration": 30.0, "active_mods": {"speed_mult": 0.8}, "log": "you wake the resident — disoriented, slow, leaning on you"})
			hud.show_dialogue("Spooky Ghost", "They wake wrong — too fast, no medical support. But they wake. Now I have to walk them out of here.")
			hud.push_log("resident woken — escort active")
		"occupied_pod_hide":
			if _pod_resolved():
				return
			GameState.set_world_flag("ward7_resident_hidden", true)
			hud.show_dialogue("Spooky Ghost", "Forged a check-out, same trick Big Gates used. They stay asleep, logged as transferred. Invisible to the system. Maybe that protects them. Maybe it just loses them.")
			hud.push_log("resident hidden — logged as transferred")
		"holding_pen_end":
			GameState.set_world_flag("ward7_held_grafts_ended", true)
			GameState.add_gatebox_attention(1)
			for caged in get_tree().get_nodes_in_group("caged_graft"):
				if caged.has_method("_defeat"):
					caged._defeat()
			hud.show_dialogue("Spooky Ghost", "There's no button to fix this. Only the one to end it. The cage logs the override. Gatebox will see it eventually.")
			hud.push_log("held grafts ended via cage controls")
		"holding_pen_release":
			for caged in get_tree().get_nodes_in_group("caged_graft"):
				caged.is_pacified = false
				if caged.has_method("alert"):
					caged.alert()
			var cage = get_node_or_null("HoldingCage")
			if cage != null:
				cage.queue_free()
			hud.show_dialogue("Spooky Ghost", "Bad idea. They are not grateful, and they are not friendly.")
			hud.push_log("holding pen opened")
		"overseer_terminal_destroy":
			if not _overseer_down():
				hud.show_dialogue("Overseer Terminal", "Locked while the Overseer still breathes. Deal with that first.")
				return
			GameState.set_world_flag("ward7_overseer_terminal_destroyed", true)
			GameState.set_world_flag("ward7_big_gates_sweep_pending", true)
			hud.show_dialogue("Spooky Ghost", "Reporting node's dark. Big Gates loses contact with Ward 7. They'll send someone to find out why — and soon.")
			hud.push_log("overseer terminal destroyed — Big Gates sweep incoming")
		"overseer_terminal_spoof":
			if not _overseer_down():
				hud.show_dialogue("Overseer Terminal", "Locked while the Overseer still breathes.")
				return
			GameState.set_world_flag("ward7_overseer_terminal_spoofed", true)
			hud.show_dialogue("Spooky Ghost", "Falsified the report. As far as Big Gates knows, the installation is humming along. Buys time. Time is the only currency down here.")
			hud.push_log("overseer terminal spoofed — normal operation faked")
		"disposal_marker":
			hud.show_dialogue("Spooky Ghost", "This is where the 121 went. I don't need a terminal to read this room. I'd rather not read it twice.")


func _pod_resolved() -> bool:
	return GameState.get_world_flag("ward7_resident_rescued", false) or GameState.get_world_flag("ward7_resident_hidden", false)


func _overseer_down() -> bool:
	return GameState.get_world_flag("ward7_overseer_defeated", false)


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
	hud.show_system_message("QUICKSAVED" if GameState.quicksave() else "SAVE FAILED")


func _load() -> void:
	if GameState.load_game():
		hud.show_system_message("GAME LOADED")
	else:
		hud.show_system_message("NO SAVE FOUND")


func _key(event: InputEvent, code: int) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == code
