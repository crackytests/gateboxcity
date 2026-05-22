extends Node
class_name QuestSystem

signal objective_changed(text: String)
signal quest_completed(quest_id: String)

var active_quest_id := ""
var display_recovered := false
var right_arm_disabled := false
var goon_defeated := false
var soul_coolant_routed := false
var completed := false


func start_wake_up_call() -> void:
	if active_quest_id.is_empty():
		active_quest_id = "wake_up_call"
		objective_changed.emit(get_objective_text())


func mark_display_recovered() -> void:
	display_recovered = true
	objective_changed.emit(get_objective_text())


func mark_right_arm_disabled() -> void:
	right_arm_disabled = true
	objective_changed.emit(get_objective_text())


func mark_goon_defeated() -> void:
	goon_defeated = true
	right_arm_disabled = true
	objective_changed.emit(get_objective_text())


func mark_soul_coolant_routed() -> void:
	soul_coolant_routed = true
	objective_changed.emit(get_objective_text())


func can_extract() -> bool:
	return active_quest_id == "wake_up_call" and display_recovered and (right_arm_disabled or goon_defeated) and not completed


func complete_active_quest() -> void:
	if not can_extract():
		return

	completed = true
	objective_changed.emit("Objective complete: return to the Mall of the Future.")
	quest_completed.emit(active_quest_id)


func get_objective_text() -> String:
	if active_quest_id.is_empty():
		return "Objective: talk to System X."
	if completed:
		return "Objective complete: return to the Mall of the Future."

	var display_status := "done" if display_recovered else "needed"
	var arm_status := "defeated" if goon_defeated else ("done" if right_arm_disabled else "needed")
	var coolant_status := "stabilized" if soul_coolant_routed else "unclaimed"
	return "Wake-Up Call: display (%s), right arm (%s), coolant (%s), extract." % [display_status, arm_status, coolant_status]
