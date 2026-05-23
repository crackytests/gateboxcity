extends CanvasLayer
class_name HUDController

@onready var reticle: Control = %Reticle
@onready var target_label: Label = %TargetLabel
@onready var chance_label: Label = %ChanceLabel
@onready var center_chance_label: Label = %CenterChanceLabel
@onready var hp_label: Label = %PartHpLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var quest_log_label: Label = %QuestLogLabel
@onready var prompt_label: Label = %PromptLabel
@onready var dialogue_label: Label = %DialogueLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var faction_label: Label = %FactionLabel
@onready var cybernetic_label: Label = %CyberneticLabel
@onready var world_state_label: Label = %WorldStateLabel
@onready var log_label: Label = %LogLabel
@onready var damage_flash: ColorRect = %DamageFlash
@onready var damage_label: Label = %DamageLabel
@onready var inventory_ui = %InventoryUI
@onready var cybernetic_ui = %CyberneticSurgeryUI
@onready var hack_ui = %HackMinigameUI
@onready var job_board_ui = %JobBoardUI
@onready var travel_gate_ui = %TravelGateUI

var damage_flash_timer := 0.0


func _ready() -> void:
	if cybernetic_ui != null and not cybernetic_ui.upgrade_installed.is_connected(_on_cybernetic_upgrade_installed):
		cybernetic_ui.upgrade_installed.connect(_on_cybernetic_upgrade_installed)


func _process(delta: float) -> void:
	if damage_flash_timer <= 0.0:
		return

	damage_flash_timer = maxf(damage_flash_timer - delta, 0.0)
	var alpha := damage_flash_timer / 0.45
	damage_flash.color.a = alpha * 0.32
	damage_label.modulate.a = alpha


func is_panel_open() -> bool:
	return (inventory_ui != null and inventory_ui.is_open()) or \
		(cybernetic_ui != null and cybernetic_ui.is_open()) or \
		(hack_ui != null and hack_ui.is_open()) or \
		(job_board_ui != null and job_board_ui.is_open()) or \
		(travel_gate_ui != null and travel_gate_ui.is_open())


func toggle_inventory() -> void:
	if cybernetic_ui != null and cybernetic_ui.is_open():
		return
	if hack_ui != null and hack_ui.is_open():
		return
	if job_board_ui != null and job_board_ui.is_open():
		return
	if travel_gate_ui != null and travel_gate_ui.is_open():
		return
	if inventory_ui == null:
		return
	if inventory_ui.is_open():
		inventory_ui.close()
	else:
		inventory_ui.open(GameState.items)


func open_cybernetics(available_upgrades: Array[Dictionary] = []) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if cybernetic_ui == null:
		return
	cybernetic_ui.open(GameState.cybernetics, available_upgrades)


func start_hack(difficulty: int) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if cybernetic_ui != null and cybernetic_ui.is_open():
		cybernetic_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if hack_ui == null:
		return
	hack_ui.open(difficulty)


func open_job_board(jobs: Array, active_job_id: String) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if cybernetic_ui != null and cybernetic_ui.is_open():
		cybernetic_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if travel_gate_ui != null and travel_gate_ui.is_open():
		travel_gate_ui.close()
	if job_board_ui == null:
		return
	job_board_ui.open(jobs, active_job_id)


func open_travel_gate(routes: Array) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		inventory_ui.close()
	if cybernetic_ui != null and cybernetic_ui.is_open():
		cybernetic_ui.close()
	if hack_ui != null and hack_ui.is_open():
		hack_ui.close()
	if job_board_ui != null and job_board_ui.is_open():
		job_board_ui.close()
	if travel_gate_ui == null:
		return
	travel_gate_ui.open(routes)


func update_targeting(part: BodyPart, lock_ratio: float, hit_chance: float) -> void:
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
	if GameState.has_cybernetic("gatebox_eye_mk1"):
		hp_label.text = "PART HP %d/%d" % [ceil(part.current_hp), ceil(part.max_hp)]
	else:
		hp_label.text = "PART HP hidden"


func set_ammo(current: int, reserve: int) -> void:
	ammo_label.text = "SCRAP PISTOL  %02d / %02d" % [current, reserve]


func set_player_health(current_hp: float, max_hp: float) -> void:
	player_health_label.text = "BODY INTEGRITY  %03d / %03d" % [ceili(current_hp), ceili(max_hp)]


func set_objective(text: String) -> void:
	objective_label.text = text
	quest_log_label.text = "QUEST  " + text


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_dialogue(speaker: String, text: String) -> void:
	dialogue_label.text = "%s: %s" % [speaker, text]


func set_inventory_summary(summary: String) -> void:
	inventory_label.text = _compact_inventory_summary(summary)


func set_faction_summary(summary: String) -> void:
	faction_label.text = summary


func set_cybernetic_summary(summary: String) -> void:
	cybernetic_label.text = summary


func set_world_state(summary: String) -> void:
	world_state_label.text = summary


func show_system_message(message: String) -> void:
	damage_flash_timer = 0.45
	damage_flash.color = Color(0.1, 0.8, 0.45, 0.22)
	damage_label.text = message
	damage_label.modulate.a = 1.0
	push_log(message.to_lower())


func show_damage_event(amount: float, current_hp: float, _max_hp: float) -> void:
	damage_flash_timer = 0.45
	damage_flash.color = Color(1, 0.05, 0.22, 0.32)
	damage_label.text = "INTEGRITY BREACH  -%d" % roundi(amount)
	damage_label.modulate.a = 1.0
	push_log("integrity breach: -%d, %d remaining" % [roundi(amount), roundi(current_hp)])


func push_log(message: String) -> void:
	log_label.text = "> " + message


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
