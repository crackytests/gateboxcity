extends Node
class_name QuestSystem

signal objective_changed(text: String)
signal quest_completed(quest_id: String)

var active_quest_id := ""
# True while replaying an already-completed Wake-Up Call. Lets the mission be re-run for its
# rewards without clearing the permanent campaign milestone (is_quest_completed stays true so
# the Dream Audit route and hub gates remain unlocked).
var _replaying := false

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
	if _replaying:
		return
	if GameState.is_quest_completed("wake_up_call"):
		# Already cleared once — start a fresh replay run instead of blocking.
		begin_replay()
		return
	if active_quest_id.is_empty():
		active_quest_id = "wake_up_call"
	GameState.start_quest("wake_up_call")
	objective_changed.emit(get_objective_text())


# Begin a repeat run of an already-completed Wake-Up Call. Resets the per-run objective steps
# so they must be redone, but leaves the campaign-completion flag intact.
func begin_replay() -> void:
	if not GameState.is_quest_completed("wake_up_call"):
		return
	_replaying = true
	active_quest_id = "wake_up_call"
	if GameState.quest_states.has("wake_up_call"):
		(GameState.quest_states["wake_up_call"] as Dictionary)["objectives"] = {}
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
	if not GameState.can_complete_quest("wake_up_call"):
		return false
	if _replaying:
		return true
	return GameState.is_quest_started("wake_up_call") \
		and not GameState.is_quest_completed("wake_up_call")


func complete_active_quest() -> void:
	if not can_extract():
		return
	var quest_id := "wake_up_call"
	# On a replay the campaign milestone is already set — keep it; just grant the run payout.
	if not _replaying:
		GameState.complete_quest(quest_id)
	_replaying = false
	active_quest_id = ""
	objective_changed.emit("Objective complete: return to the Faded Atrium.")
	quest_completed.emit(quest_id)


func get_objective_text() -> String:
	if not _replaying:
		if not GameState.is_quest_started("wake_up_call"):
			return "Objective: talk to System X."
		if GameState.is_quest_completed("wake_up_call"):
			return "Objective complete: return to the Faded Atrium."
	var display_done := GameState.is_quest_step_done("wake_up_call", "display_recovered")
	var arm_done    := GameState.is_quest_step_done("wake_up_call", "arm_disabled")
	var coolant_done := GameState.is_quest_step_done("wake_up_call", "coolant_routed")
	var display_status := "done" if display_done else "needed"
	var arm_status     := "done" if arm_done else "needed"
	var coolant_status := "stabilized" if coolant_done else "unclaimed"
	var title := "Wake-Up Call (replay)" if _replaying else "Wake-Up Call"
	return "%s: display (%s), right arm (%s), coolant (%s), extract." % [
		title, display_status, arm_status, coolant_status
	]
