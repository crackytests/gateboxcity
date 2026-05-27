extends Node3D
class_name SecurityNode

signal body_part_destroyed(part_name: String)
signal attacked_player(message: String)
signal defeated

@export var attack_range := 11.0
@export var attack_damage := 6.0
@export var attack_cooldown := 1.25
@export var player_path: NodePath

@onready var parts_root: Node3D = %BodyParts
@onready var visual_root: Node3D = $Visuals
@onready var pulse_light: OmniLight3D = $PulseLight

var player: Node3D
var attack_timer := 0.0
var flash_timer := 0.0
var lens_destroyed := false
var antenna_destroyed := false
var is_defeated := false


func _ready() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path)

	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null:
			part.destroyed.connect(_on_part_destroyed)
			part.damaged.connect(_on_part_damaged)


func _process(delta: float) -> void:
	if is_defeated:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	flash_timer = maxf(flash_timer - delta, 0.0)

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		return

	visual_root.rotate_y(delta * 0.65)
	if flash_timer > 0.0:
		visual_root.scale = Vector3.ONE * (1.0 + flash_timer * 0.25)
	else:
		visual_root.scale = Vector3.ONE

	_try_attack()


func _try_attack() -> void:
	if attack_timer > 0.0 or player == null:
		return

	var distance := global_position.distance_to(player.global_position)
	var active_range := attack_range * (0.55 if antenna_destroyed else 1.0)
	if distance > active_range:
		return

	if not _has_line_of_sight():
		return

	var player_health := player.find_child("PlayerHealth", true, false)
	if player_health == null:
		return

	var damage := attack_damage * (0.45 if lens_destroyed else 1.0)
	player_health.apply_damage(damage)
	flash_timer = 0.25
	pulse_light.light_energy = 3.0
	attacked_player.emit("security node pulse hit for %d" % roundi(damage))
	attack_timer = attack_cooldown * (1.45 if antenna_destroyed else 1.0)


func _has_line_of_sight() -> bool:
	if player == null:
		return false
	var from := global_position + Vector3.UP * 0.5
	var to := player.global_position + Vector3.UP * 0.8
	var dist := from.distance_to(to)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_dist := from.distance_to(result.position)
	return hit_dist >= dist - 0.5


func _on_part_damaged(_part: BodyPart, _amount: float, _remaining_hp: float) -> void:
	flash_timer = 0.18
	pulse_light.light_energy = 2.4


func _on_part_destroyed(part: BodyPart) -> void:
	part.monitorable = false
	part.monitoring = false
	part.visible = false
	body_part_destroyed.emit(part.display_name)

	if part.display_name == "Lens":
		lens_destroyed = true
	elif part.display_name == "Antenna":
		antenna_destroyed = true
	elif part.display_name == "Core":
		_defeat()


func _defeat() -> void:
	if is_defeated:
		return

	is_defeated = true
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null:
			part.monitorable = false
			part.monitoring = false
	visual_root.visible = false
	pulse_light.visible = false
	defeated.emit()
