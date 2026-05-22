extends Area3D
class_name ShelterZone

@export var prompt_name := "Pipe Shelter"

var controller


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_find_controller()


func _find_controller() -> void:
	var controllers := get_tree().get_nodes_in_group("toxic_rain_controller")
	if not controllers.is_empty():
		controller = controllers[0]


func _on_body_entered(body: Node3D) -> void:
	if controller == null:
		_find_controller()
	if body.is_in_group("player") and controller != null:
		controller.enter_shelter()


func _on_body_exited(body: Node3D) -> void:
	if controller == null:
		_find_controller()
	if body.is_in_group("player") and controller != null:
		controller.exit_shelter()
