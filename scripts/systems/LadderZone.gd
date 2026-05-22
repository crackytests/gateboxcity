extends Area3D
class_name LadderZone

@export var climb_speed := 3.2
@export var prompt_name := "Catwalk Ladder"

var _players: Array[PlayerController] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	for player in _players:
		if not is_instance_valid(player):
			continue
		var vertical_input := 0.0
		if Input.is_action_pressed("move_forward"):
			vertical_input += 1.0
		if Input.is_action_pressed("move_back"):
			vertical_input -= 1.0
		if Input.is_action_pressed("jump"):
			vertical_input += 1.0
		if absf(vertical_input) > 0.0:
			player.velocity.y = vertical_input * climb_speed


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and not _players.has(body):
		_players.append(body)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		_players.erase(body)
