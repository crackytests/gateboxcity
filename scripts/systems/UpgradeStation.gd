extends Area3D
class_name UpgradeStation

signal focus_changed(station: UpgradeStation, has_focus: bool)

@export var upgrade_id := "targeting_coprocessor"
@export var upgrade_name := "Targeting Co-Processor"
@export var required_item := "Mall Arcade Token"
@export var prompt_text := "Press E: install Targeting Co-Processor"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
