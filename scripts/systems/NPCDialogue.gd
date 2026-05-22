extends Area3D
class_name NPCDialogue

signal focus_changed(interactable: NPCDialogue, has_focus: bool)

@export var npc_name := "System X"
@export_multiline var dialogue_text := "Signal says you are awake. Bring me the broken display and cripple the goon's right arm."
@export var prompt_text := "Press E: talk to System X"
@export var alternate_world_flag := ""
@export_multiline var alternate_dialogue_text := ""
@export var reputation_faction := ""
@export var reputation_amount := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> Dictionary:
	face_player_now()
	if not reputation_faction.is_empty() and reputation_amount != 0:
		GameState.add_reputation(reputation_faction, reputation_amount)
	var text := dialogue_text
	if not alternate_world_flag.is_empty() and GameState.get_world_flag(alternate_world_flag) and not alternate_dialogue_text.is_empty():
		text = alternate_dialogue_text
	return {
		"name": npc_name,
		"text": text,
	}


func face_player_now() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var look_target := player.global_position
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
