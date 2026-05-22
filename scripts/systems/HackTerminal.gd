extends Area3D
class_name HackTerminal

signal focus_changed(terminal: HackTerminal, has_focus: bool)

@export var terminal_id := "generic_hack"
@export var difficulty := 1
@export var prompt_text := "Press E: hack terminal"
@export var display_name := "Hack Terminal"
@export var success_message := "Access granted."
@export var fail_message := "Access denied."
@export var requires_item := ""
@export var reward_item := ""
@export var reward_flag := ""
@export var reward_reputation_faction := ""
@export var reward_reputation_amount := 0
@export var quest_flag := ""

var _hacked := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if GameState.get_world_flag(terminal_id + "_hacked"):
		_hacked = true


func interact() -> Dictionary:
	if _hacked:
		return {"name": display_name, "text": "Terminal already accessed. Signal trace is cold."}
	return {"name": display_name, "text": "INITIATING HACK PROTOCOL...", "start_hack": true, "difficulty": difficulty}


func complete_hack(success: bool) -> void:
	if not success:
		return
	_hacked = true
	GameState.set_world_flag(terminal_id + "_hacked", true)
	if reward_item != "":
		GameState.add_item(reward_item)
	if reward_flag != "":
		GameState.set_world_flag(reward_flag, true)
	if reward_reputation_faction != "":
		GameState.add_reputation(reward_reputation_faction, reward_reputation_amount)
	if quest_flag != "":
		GameState.mark_quest_completed(quest_flag)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
