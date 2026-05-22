extends Area3D
class_name LootPickup

signal picked_up(item_name: String)

@export var item_name := "Broken Gatebox Display"
@export var auto_pickup := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if auto_pickup and body.is_in_group("player"):
		picked_up.emit(item_name)
		queue_free()
