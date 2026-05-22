extends Area3D
class_name WardInteractable

signal focus_changed(interactable: WardInteractable, has_focus: bool)

@export var interactable_id := ""
@export var prompt_text := "Press E: inspect"
@export var display_name := "Ward Object"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
