extends CanvasLayer
class_name HUDController

@onready var reticle: Control = %Reticle
@onready var target_label: Label = %TargetLabel
@onready var chance_label: Label = %ChanceLabel
@onready var center_chance_label: Label = %CenterChanceLabel
@onready var hp_label: Label = %PartHpLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var wan_notes_label: Label = %WanNotesLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var quest_log_label: Label = %QuestLogLabel
@onready var prompt_label: Label = %PromptLabel
@onready var dialogue_label: Label = %DialogueLabel
@onready var log_label: Label = %LogLabel
@onready var damage_flash: ColorRect = %DamageFlash
@onready var damage_label: Label = %DamageLabel
@onready var damage_indicators = %DamageIndicators
@onready var stealth_label: Label = %StealthLabel
@onready var death_screen: ColorRect = %DeathScreen
@onready var inventory_ui = %InventoryUI
@onready var cybernetic_ui = %CyberneticSurgeryUI
@onready var hack_ui = %HackMinigameUI
@onready var job_board_ui = %JobBoardUI
@onready var travel_gate_ui = %TravelGateUI
@onready var ghost_term = %GhostTermUI
@onready var shop_ui = %ShopUI
@onready var dialogue_ui = %DialogueUI
@onready var event_card_ui = %EventCardUI

var damage_flash_timer := 0.0
# Dialogue banner auto-fade: holds (scaled to reading length), then fades out and clears.
var _dialogue_timer := 0.0
const DIALOGUE_FADE := 1.0
# Log widget auto-fade: flashes to full on update, holds, then fades to a faint resting alpha
# (it stays ghosted on screen rather than disappearing).
var _log_timer := 0.0
const LOG_HOLD := 5.0
const LOG_FADE := 1.5
const LOG_REST_ALPHA := 0.5
var _last_hp := 0.0
var _last_max_hp := 0.0
var _player: Node3D = null
var _death_active := false
var _dialogue_lock_target: Node = null

# Enemy hacking: cache the currently-targeted part so the hack key can act on it.
var _target_part: BodyPart = null
var _target_lock := 0.0
var _enemy_hack_enemy: Node = null
var _enemy_hack_part: BodyPart = null


func _ready() -> void:
	add_to_group("hud")
	if ghost_term != null and not ghost_term.upgrade_installed.is_connected(_on_cybernetic_upgrade_installed):
		ghost_term.upgrade_installed.connect(_on_cybernetic_upgrade_installed)
	if not GameState.effect_notice.is_connected(_on_effect_notice):
		GameState.effect_notice.connect(_on_effect_notice)
	if not GameState.player_died.is_connected(_on_player_died):
		GameState.player_died.connect(_on_player_died)
	if hack_ui != null:
		if not hack_ui.hack_completed.is_connected(_on_enemy_hack_completed):
			hack_ui.hack_completed.connect(_on_enemy_hack_completed)
		if not hack_ui.closed.is_connected(_clear_enemy_hack):
			hack_ui.closed.connect(_clear_enemy_hack)
	if dialogue_ui != null and not dialogue_ui.closed.is_connected(_on_dialogue_window_closed):
		dialogue_ui.closed.connect(_on_dialogue_window_closed)
	for panel in [shop_ui, job_board_ui, travel_gate_ui, ghost_term]:
		if panel != null and panel.has_signal("closed") and not panel.closed.is_connected(_clear_dialogue_lock):
			panel.closed.connect(_clear_dialogue_lock)
	if not GameState.inventory_changed.is_connected(set_inventory_summary):
		GameState.inventory_changed.connect(set_inventory_summary)
	set_inventory_summary(GameState.get_inventory_summary())


func _unhandled_input(event: InputEvent) -> void:
	# While dead, swallow all input and let any key trigger the respawn.
	if _death_active:
		var pressed := false
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo:
			pressed = true
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			pressed = true
		if pressed:
			_respawn()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("hack"):
		_try_enemy_hack()
		get_viewport().set_input_as_handled()


func _try_enemy_hack() -> void:
	if is_panel_open():
		return
	if _target_part == null or not is_instance_valid(_target_part):
		return
	if not _target_part.hackable or _target_part.is_destroyed or _target_part.hacked:
		return
	if _target_lock < 0.5:
		push_log("hack failed: hold a steady lock on the part first")
		return
	var enemy := _enemy_of_part(_target_part)
	if enemy == null or not enemy.has_method("apply_hack_effect"):
		return
	_enemy_hack_enemy = enemy
	_enemy_hack_part = _target_part
	var difficulty := 2
	if typeof(_target_part.effect_payload) == TYPE_DICTIONARY:
		difficulty = int(_target_part.effect_payload.get("hack_difficulty", 2))
	start_hack(difficulty)


func _on_enemy_hack_completed(success: bool, _difficulty: int) -> void:
	if _enemy_hack_enemy == null:
		return  # this completion belongs to a terminal hack, not an enemy hack
	if is_instance_valid(_enemy_hack_enemy):
		if success:
			_enemy_hack_enemy.apply_hack_effect(_enemy_hack_part)
			if is_instance_valid(_enemy_hack_part):
				_enemy_hack_part.hacked = true
		elif _enemy_hack_enemy.has_method("alert"):
			_enemy_hack_enemy.alert()  # botched hack tips them off
	_clear_enemy_hack()


func _clear_enemy_hack() -> void:
	_enemy_hack_enemy = null
	_enemy_hack_part = null


func _enemy_of_part(part: Node) -> Node:
	var n := part
	while n != null:
		if n is Enemy:
			return n
		n = n.get_parent()
	return null


func _on_effect_notice(text: String) -> void:
	show_system_message(text)


# ── Death / respawn ─────────────────────────────────────────────────

func _on_player_died() -> void:
	if _death_active:
		return
	_death_active = true
	if death_screen != null:
		death_screen.visible = true
	# Keep the HUD live while the rest of the game freezes so the respawn key works.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	push_log("body integrity lost")


func _respawn() -> void:
	_death_active = false
	if death_screen != null:
		death_screen.visible = false
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.clear_death()
	# Reload the last checkpoint; with no save, restart from the hub.
	if not GameState.respawn_from_save():
		get_tree().change_scene_to_file("res://scenes/levels/MallHub.tscn")


func _process(delta: float) -> void:
	_update_stealth_indicator()
	_update_dialogue_fade(delta)
	_update_log_fade(delta)

	if damage_flash_timer <= 0.0:
		return

	damage_flash_timer = maxf(damage_flash_timer - delta, 0.0)
	var alpha := damage_flash_timer / 0.45
	damage_flash.color.a = alpha * 0.32
	damage_label.modulate.a = alpha


# The dialogue banner holds for a read-length-scaled time, fades over DIALOGUE_FADE, then clears.
func _update_dialogue_fade(delta: float) -> void:
	if _dialogue_timer <= 0.0:
		return
	_dialogue_timer = maxf(_dialogue_timer - delta, 0.0)
	if _dialogue_timer <= 0.0:
		dialogue_label.text = ""
		dialogue_label.modulate.a = 1.0
	elif _dialogue_timer < DIALOGUE_FADE:
		dialogue_label.modulate.a = _dialogue_timer / DIALOGUE_FADE


# The log flashes to full on a new line, holds, then settles to a faint resting alpha.
func _update_log_fade(delta: float) -> void:
	if _log_timer <= 0.0:
		return
	_log_timer = maxf(_log_timer - delta, 0.0)
	if _log_timer <= 0.0:
		log_label.modulate.a = LOG_REST_ALPHA
	elif _log_timer < LOG_FADE:
		var f := _log_timer / LOG_FADE
		log_label.modulate.a = LOG_REST_ALPHA + (1.0 - LOG_REST_ALPHA) * f


# The stealth readout only shows while crouched, reporting whether nearby
# enemies have noticed you: HIDDEN (green), DETECTED (amber), SPOTTED (red).
func _update_stealth_indicator() -> void:
	if stealth_label == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var crouched := false
	if _player != null:
		crouched = bool(_player.get("is_crouching"))
	if not crouched:
		stealth_label.visible = false
		return

	var awareness := 0.0
	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Enemy
		if e != null:
			awareness = maxf(awareness, e.get_awareness())

	stealth_label.visible = true
	if awareness >= 1.0:
		stealth_label.text = "● SPOTTED"
		stealth_label.add_theme_color_override("font_color", Color(1, 0.2, 0.25, 1))
	elif awareness > 0.05:
		stealth_label.text = "◐ DETECTED"
		stealth_label.add_theme_color_override("font_color", Color(1, 0.78, 0.2, 1))
	else:
		stealth_label.text = "● HIDDEN"
		stealth_label.add_theme_color_override("font_color", Color(0.3, 1, 0.5, 1))


func is_panel_open() -> bool:
	return (inventory_ui != null and inventory_ui.is_open()) or \
		(hack_ui != null and hack_ui.is_open()) or \
		(job_board_ui != null and job_board_ui.is_open()) or \
		(travel_gate_ui != null and travel_gate_ui.is_open()) or \
		(shop_ui != null and shop_ui.is_open()) or \
		(dialogue_ui != null and dialogue_ui.is_open()) or \
		(event_card_ui != null and event_card_ui.is_open()) or \
		(ghost_term != null and ghost_term.is_open())


func toggle_inventory() -> void:
	# TAB now opens the unified GhostTerm overlay (defaults to the INV tab).
	open_ghost_term("inv")


func open_ghost_term(tab: String = "inv") -> void:
	if ghost_term == null:
		# Fallback to the legacy inventory panel if the GhostTerm is unavailable.
		if inventory_ui != null and not inventory_ui.is_open():
			inventory_ui.open(GameState.items)
		return
	if _any_contextual_panel_open():
		return
	if ghost_term.is_open():
		ghost_term.close()
	else:
		ghost_term.set_vitals(_last_hp, _last_max_hp)
		ghost_term.open(tab)


func _any_contextual_panel_open() -> bool:
	return (hack_ui != null and hack_ui.is_open()) or \
		(job_board_ui != null and job_board_ui.is_open()) or \
		(travel_gate_ui != null and travel_gate_ui.is_open()) or \
		(shop_ui != null and shop_ui.is_open())


func open_shop(vendor_name: String, offers: Array) -> void:
	if ghost_term != null and ghost_term.is_open():
		ghost_term.close()
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if shop_ui == null:
		return
	shop_ui.open(vendor_name, offers)


func open_dialogue(npc_id: String, speaker_node: Node = null) -> void:
	_close_menu_panels()
	if dialogue_ui == null:
		return
	_set_dialogue_lock(speaker_node)
	dialogue_ui.open(npc_id)


# One-shot line shown in the dialogue frame (objects, consoles, barks).
func open_statement(speaker: String, text: String, speaker_node: Node = null) -> void:
	_close_menu_panels()
	if dialogue_ui == null:
		_clear_dialogue_lock()
		# Fall back to the legacy single-line banner if the dialogue UI is unavailable.
		show_dialogue(speaker, text)
		return
	_set_dialogue_lock(speaker_node)
	dialogue_ui.open_statement(speaker, text)


# Present a context event (travel / leave Cooters / enter Atrium). Interactive cards (those with
# choices) open the EventCardUI for a stat-checked resolution; plain cards show their line in the
# dialogue frame. Returns true if anything fired.
func present_event(context: String, interactive_only := false) -> bool:
	if GameState.consume_load_restore_pending():
		return false
	var card := EventDeckSystem.pick_candidate(context)
	if card.is_empty():
		return false
	if card.has("choices"):
		var choices: Array = card.get("choices", [])
		if choices.is_empty():
			EventDeckSystem.expire_card(card)
			return false
		_close_menu_panels()
		if event_card_ui != null:
			event_card_ui.open(card)
			return true
	if interactive_only:
		return false   # a line card exists but the caller only wants interactive events here
	# Non-interactive: apply + expire and show the line.
	EventDeckSystem.apply_and_expire(card)
	open_statement(str(card.get("speaker", "System X")), str(card.get("text", card.get("body", ""))))
	return true


func _close_menu_panels() -> void:
	if event_card_ui != null and event_card_ui.is_open():
		event_card_ui.close()
	if ghost_term != null and ghost_term.is_open():
		ghost_term.close()
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if shop_ui != null and shop_ui.is_open():
		shop_ui.close()


func _set_dialogue_lock(speaker_node: Node) -> void:
	_clear_dialogue_lock()
	_dialogue_lock_target = speaker_node
	if _dialogue_lock_target != null and is_instance_valid(_dialogue_lock_target) and _dialogue_lock_target.has_method("set_dialogue_locked"):
		_dialogue_lock_target.set_dialogue_locked(true)


func _on_dialogue_window_closed() -> void:
	# Service handlers run immediately after DialogueUI.close(). Defer release so a shop/job board/
	# cybernetics panel can take over the lock for the same speaker.
	_release_dialogue_lock_if_no_service.call_deferred()


func _release_dialogue_lock_if_no_service() -> void:
	if _service_panel_open():
		return
	_clear_dialogue_lock()


func _service_panel_open() -> bool:
	return (shop_ui != null and shop_ui.is_open()) or \
		(job_board_ui != null and job_board_ui.is_open()) or \
		(travel_gate_ui != null and travel_gate_ui.is_open()) or \
		(ghost_term != null and ghost_term.is_open())


func _clear_dialogue_lock() -> void:
	if _dialogue_lock_target != null and is_instance_valid(_dialogue_lock_target) and _dialogue_lock_target.has_method("set_dialogue_locked"):
		_dialogue_lock_target.set_dialogue_locked(false)
	_dialogue_lock_target = null


func open_sell_shop(vendor_name: String) -> void:
	if ghost_term != null and ghost_term.is_open():
		ghost_term.close()
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if shop_ui == null:
		return
	shop_ui.open_sell(vendor_name)


func open_cybernetics(available_upgrades: Array[Dictionary] = []) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if ghost_term == null:
		return
	ghost_term.open_ware(true)   # Coil's table: install enabled, paid in Wan Notes


func start_hack(difficulty: int) -> void:
	if ghost_term != null and ghost_term.is_open():
		ghost_term.close()
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if hack_ui == null:
		return
	hack_ui.open(difficulty)


func open_job_board(jobs: Array, active_job_id: String) -> void:
	if ghost_term != null and ghost_term.is_open():
		ghost_term.close()
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if job_board_ui == null:
		return
	job_board_ui.open(jobs, active_job_id)


func open_travel_gate(routes: Array) -> void:
	if ghost_term != null and ghost_term.is_open():
		ghost_term.close()
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui == null:
		return
	travel_gate_ui.open(routes)


func update_targeting(part: BodyPart, lock_ratio: float, hit_chance: float) -> void:
	_target_part = part
	_target_lock = lock_ratio
	if reticle.has_method("set_lock_ratio"):
		reticle.set_lock_ratio(lock_ratio)

	if part == null:
		target_label.text = "NO TARGET"
		chance_label.text = "--%"
		center_chance_label.text = "--%"
		hp_label.text = ""
		return

	target_label.text = part.display_name.to_upper()
	chance_label.text = "%02d%%" % roundi(hit_chance)
	center_chance_label.text = "%02d%%" % roundi(hit_chance)
	if GameState.has_cybernetic("gatebox_eye_mk1") or GameState.has_cybernetic("mag_retina"):
		hp_label.text = "PART HP %d/%d" % [ceil(part.current_hp), ceil(part.max_hp)]
	else:
		hp_label.text = "PART HP hidden"


func set_ammo(current: int, reserve: int) -> void:
	ammo_label.text = "SCRAP PISTOL  %02d / %02d" % [current, reserve]


func set_player_health(current_hp: float, max_hp: float) -> void:
	player_health_label.text = "BODY INTEGRITY  %03d / %03d" % [ceili(current_hp), ceili(max_hp)]
	_last_hp = current_hp
	_last_max_hp = max_hp
	if ghost_term != null:
		ghost_term.set_vitals(current_hp, max_hp)


func set_objective(text: String) -> void:
	objective_label.text = text
	quest_log_label.text = "QUEST  " + text


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_dialogue(speaker: String, text: String) -> void:
	if speaker.is_empty() and text.is_empty():
		dialogue_label.text = ""        # explicit clear
		_dialogue_timer = 0.0
		return
	dialogue_label.text = "%s: %s" % [speaker, text]
	dialogue_label.modulate.a = 1.0
	# Hold longer for longer lines so they stay readable, then fade.
	_dialogue_timer = clampf(4.0 + text.length() * 0.045, 6.0, 16.0) + DIALOGUE_FADE


# These four readouts were removed from the always-on AR HUD (redundant — the data lives in the
# GhostTerm tabs / menus). Setters kept as no-ops so existing callers + GameState signal
# connections stay valid without edits.
func set_inventory_summary(_summary: String) -> void:
	if wan_notes_label != null:
		wan_notes_label.text = "WAN %03d" % GameState.get_wan_notes()


func set_faction_summary(_summary: String) -> void:
	pass


func set_cybernetic_summary(_summary: String) -> void:
	pass


func set_world_state(_summary: String) -> void:
	pass


func show_system_message(message: String) -> void:
	AudioDirector.play_ui_message(message)
	# VCR rewind scramble on load. Guaranteed trigger (every _load_game shows "GAME LOADED");
	# the autoload's _input path also fires it earlier when input is delivered, and ScreenFX's
	# _busy guard dedupes so it only plays once.
	if message.to_lower().contains("loaded") and ScreenFX != null:
		ScreenFX.rewind()
	damage_flash_timer = 0.45
	damage_flash.color = Color(0.1, 0.8, 0.45, 0.22)
	damage_label.text = message
	damage_label.modulate.a = 1.0
	push_log(message.to_lower())


func show_damage_event(amount: float, current_hp: float, _max_hp: float, source_position = null) -> void:
	damage_flash_timer = 0.45
	damage_flash.color = Color(1, 0.05, 0.22, 0.32)
	damage_label.text = "INTEGRITY BREACH  -%d" % roundi(amount)
	damage_label.modulate.a = 1.0
	push_log("integrity breach: -%d, %d remaining" % [roundi(amount), roundi(current_hp)])
	# Directional marker: arrow on the reticle ring pointing at the hit's source (camera-relative).
	# Abstract/environmental damage passes null — just the number, no arrow.
	if source_position != null and damage_indicators != null:
		var cam := _get_player_camera()
		if cam != null:
			var local: Vector3 = cam.global_transform.affine_inverse() * (source_position as Vector3)
			var bearing := atan2(local.x, -local.z)   # 0 = straight ahead, +clockwise
			damage_indicators.add_hit(bearing, amount >= 12.0)


func _get_player_camera() -> Camera3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return null
	return _player.find_child("Camera3D", true, false) as Camera3D


func push_log(message: String) -> void:
	log_label.text = "> " + message
	log_label.modulate.a = 1.0
	_log_timer = LOG_HOLD + LOG_FADE
	if ghost_term != null:
		ghost_term.add_log(message)


func _compact_inventory_summary(summary: String) -> String:
	const PREFIX := "INVENTORY  "
	const MAX_ITEMS_VISIBLE := 2
	if not summary.begins_with(PREFIX):
		return summary
	if summary == "INVENTORY  empty":
		return summary

	var item_text := summary.substr(PREFIX.length())
	var item_names := item_text.split(", ", false)
	if item_names.size() <= MAX_ITEMS_VISIBLE:
		return summary

	var visible_items := item_names.slice(0, MAX_ITEMS_VISIBLE)
	return PREFIX + ", ".join(visible_items) + ", +%d more" % (item_names.size() - MAX_ITEMS_VISIBLE)


func _on_cybernetic_upgrade_installed(_upgrade_id: String) -> void:
	set_inventory_summary(GameState.get_inventory_summary())
	set_cybernetic_summary(GameState.get_cybernetic_summary())
	push_log("cybernetic installed")
