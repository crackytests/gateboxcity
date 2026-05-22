extends Area3D
class_name EnemyTalkZone

signal focus_changed(interactable: EnemyTalkZone, has_focus: bool)

@export var interactable_id := "pacified_goon"
@export var prompt_text := "Press E: talk"
@export var display_name := "Pacified Goon"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_available() -> bool:
	var enemy := get_parent() as Enemy
	return enemy != null and enemy.is_talkable()


func speak() -> Dictionary:
	var enemy := get_parent() as Enemy
	if enemy != null:
		enemy.face_player_now()
		return enemy.get_pacified_dialogue()

	return {
		"name": display_name,
		"text": "Standing down."
	}


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and is_available():
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
