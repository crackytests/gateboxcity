extends Area3D
class_name MissionExit

signal focus_changed(exit: MissionExit, has_focus: bool)

@export var prompt_text := "Press E: extract"
@export var target_scene := ""
@export var requires_completed_quest := ""
@export var locked_message := "Route locked."


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
