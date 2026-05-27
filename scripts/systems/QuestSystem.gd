extends Node
class_name QuestSystem

signal objective_changed(text: String)
signal quest_completed(quest_id: String)

var active_quest_id := ""

# Computed — reads directly from GameState so it survives save/load cycles.
var soul_coolant_routed: bool:
	get:
		return GameState.is_quest_step_done("wake_up_call", "coolant_routed")


func _ready() -> void:
	_sync_from_game_state()


# Call after GameState.load_game() to re-derive local state from persisted data.
func _sync_from_game_state() -> void:
	if GameState.is_quest_started("wake_up_call") and not GameState.is_quest_completed("wake_up_call"):
		active_quest_id = "wake_up_call"
	else:
		active_quest_id = ""


func start_wake_up_call() -> void:
	if GameState.is_quest_completed("wake_up_call"):
		return
	if active_quest_id.is_empty():
		active_quest_id = "wake_up_call"
	GameState.start_quest("wake_up_call")
	objective_changed.emit(get_objective_text())


func mark_display_recovered() -> void:
	GameState.mark_quest_objective("wake_up_call", "display_recovered")
	objective_changed.emit(get_objective_text())


func mark_right_arm_disabled() -> void:
	GameState.mark_quest_objective("wake_up_call", "arm_disabled")
	objective_changed.emit(get_objective_text())


func mark_goon_defeated() -> void:
	# Defeating the goon counts as disabling the arm.
	GameState.mark_quest_objective("wake_up_call", "arm_disabled")
	objective_changed.emit(get_objective_text())


func mark_soul_coolant_routed() -> void:
	GameState.mark_quest_objective("wake_up_call", "coolant_routed")
	objective_changed.emit(get_objective_text())


func can_extract() -> bool:
	return GameState.is_quest_started("wake_up_call") \
		and not GameState.is_quest_completed("wake_up_call") \
		and GameState.can_complete_quest("wake_up_call")


func complete_active_quest() -> void:
	if not can_extract():
		return
	var quest_id := "wake_up_call"
	GameState.complete_quest(quest_id)
	active_quest_id = ""
	objective_changed.emit("Objective complete: return to the Mall of the Future.")
	quest_completed.emit(quest_id)


func get_objective_text() -> String:
	if not GameState.is_quest_started("wake_up_call"):
		return "Objective: talk to System X."
	if GameState.is_quest_completed("wake_up_call"):
		return "Objective complete: return to the Mall of the Future."
	var display_done := GameState.is_quest_step_done("wake_up_call", "display_recovered")
	var arm_done    := GameState.is_quest_step_done("wake_up_call", "arm_disabled")
	var coolant_done := GameState.is_quest_step_done("wake_up_call", "coolant_routed")
	var display_status := "done" if display_done else "needed"
	var arm_status     := "done" if arm_done else "needed"
	var coolant_status := "stabilized" if coolant_done else "unclaimed"
	return "Wake-Up Call: display (%s), right arm (%s), coolant (%s), extract." % [
		display_status, arm_status, coolant_status
	]
