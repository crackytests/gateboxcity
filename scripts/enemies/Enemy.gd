extends CharacterBody3D
class_name Enemy

signal body_part_destroyed(part_name: String)
signal attacked_player(message: String)
signal defeated
signal item_dropped(item_name: String)

@export var drop_item: String = ""
@export var move_speed := 2.0
@export var attack_range := 2.2
@export var ranged_range := 8.0
@export var melee_damage := 8.0
@export var ranged_damage := 5.0
@export var attack_cooldown := 1.15
@export var player_path: NodePath
@export var detection_range := 14.0
@export var pacified_dialogue_name := "Gatebox Guard"
@export_multiline var pacified_dialogue_text := "Linda has marked you safe. Please proceed without running."

enum AIState { PATROL, COMBAT }

@onready var parts_root: Node3D = %BodyParts
@onready var billboard = $Visuals/GreenlineBillboard

var player: Node3D
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var base_move_speed := 0.0
var attack_timer := 0.0
var stun_timer := 0.0
var attack_flash_timer := 0.0
var right_arm_destroyed := false
var is_defeated := false
var is_pacified := false

var ai_state := AIState.PATROL
var patrol_points: Array[Vector3] = []
var _patrol_index := 0
var _patrol_dwell_timer := 0.0
var _patrol_dwell_time := 2.0


func _ready() -> void:
	base_move_speed = move_speed
	if not player_path.is_empty():
		player = get_node_or_null(player_path)

	for child in parts_root.get_children():
		var part := child as BodyPart
		if part:
			part.destroyed.connect(_on_part_destroyed)
			part.damaged.connect(_on_part_damaged)


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)
	attack_flash_timer = maxf(attack_flash_timer - delta, 0.0)

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_pacified or stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		move_and_slide()
		return

	match ai_state:
		AIState.PATROL:
			_process_patrol(delta)
		AIState.COMBAT:
			_process_combat(delta)

	var visual_scale := 1.0
	if attack_flash_timer > 0.0:
		visual_scale = 1.0 + attack_flash_timer * 0.45
	$Visuals.scale = Vector3.ONE * visual_scale

	move_and_slide()


func _process_patrol(delta: float) -> void:
	if _has_line_of_sight():
		ai_state = AIState.COMBAT
		return
	if _patrol_dwell_timer > 0.0:
		_patrol_dwell_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		return
	if patrol_points.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		return
	var target := patrol_points[_patrol_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		_patrol_dwell_timer = _patrol_dwell_time
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		var direction := to_target.normalized()
		var patrol_speed := move_speed * 0.5
		velocity.x = direction.x * patrol_speed
		velocity.z = direction.z * patrol_speed
		var look_target := Vector3(target.x, global_position.y, target.z)
		if global_position.distance_squared_to(look_target) > 0.01:
			look_at(look_target, Vector3.UP)


func _process_combat(_delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > attack_range:
		var direction := to_player.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	_try_attack(to_player.length())


func _on_part_damaged(part: BodyPart, _amount: float, remaining_hp: float) -> void:
	if billboard != null and billboard.has_method("flash_damage"):
		billboard.flash_damage()
	if part.display_name == "Head" and remaining_hp <= part.max_hp * 0.5:
		stun_timer = maxf(stun_timer, 0.35)


func _on_part_destroyed(part: BodyPart) -> void:
	part.monitorable = false
	part.visible = false
	body_part_destroyed.emit(part.display_name)

	_show_part_break_effect(part)
	if billboard != null and billboard.has_method("show_part_broken"):
		billboard.show_part_broken(part.display_name)

	if part.display_name.contains("Leg"):
		move_speed = maxf(move_speed * 0.55, base_move_speed * 0.25)
	elif part.display_name == "Right Arm":
		right_arm_destroyed = true
	elif part.display_name == "Head":
		stun_timer = 3.0
		_defeat()
	elif part.display_name == "Torso":
		_defeat()


func _try_attack(distance_to_player: float) -> void:
	if is_pacified or attack_timer > 0.0:
		return

	var player_health := player.find_child("PlayerHealth", true, false)
	if player_health == null:
		return

	if distance_to_player <= attack_range:
		player_health.apply_damage(melee_damage)
		attack_flash_timer = 0.22
		attacked_player.emit("goon material scraped you for %d" % roundi(melee_damage))
		attack_timer = attack_cooldown
	elif distance_to_player <= ranged_range and not right_arm_destroyed:
		player_health.apply_damage(ranged_damage)
		attack_flash_timer = 0.22
		attacked_player.emit("right-arm trash cannon hit for %d" % roundi(ranged_damage))
		attack_timer = attack_cooldown * 1.4


func _defeat() -> void:
	if is_defeated:
		return

	is_defeated = true
	collision_layer = 0
	collision_mask = 0
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null:
			part.monitorable = false
			part.monitoring = false
	if billboard != null and billboard.has_method("show_defeated"):
		billboard.show_defeated()
	if not drop_item.is_empty():
		GameState.add_item(drop_item)
		item_dropped.emit(drop_item)
	defeated.emit()


func pacify(dialogue_text := "") -> void:
	is_pacified = true
	move_speed = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	if not dialogue_text.is_empty():
		pacified_dialogue_text = dialogue_text


func is_talkable() -> bool:
	return is_pacified and not is_defeated


func face_player_now() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var look_target := player.global_position
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)


func get_pacified_dialogue() -> Dictionary:
	return {
		"name": pacified_dialogue_name,
		"text": pacified_dialogue_text
	}


func _show_part_break_effect(part: BodyPart) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	marker.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.05, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.02, 0.12, 1.0)
	material.emission_energy_multiplier = 2.3
	marker.set_surface_override_material(0, material)

	$Visuals.add_child(marker)
	marker.global_position = part.global_position
	marker.name = part.display_name.replace(" ", "") + "BreakMarker"


func _has_line_of_sight() -> bool:
	if player == null:
		return false
	var from := global_position + Vector3.UP * 0.8
	var to := player.global_position + Vector3.UP * 0.8
	var dist := from.distance_to(to)
	if dist > detection_range:
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_dist := from.distance_to(result.position)
	return hit_dist >= dist - 0.5


func set_patrol_points(points: Array[Vector3]) -> void:
	patrol_points = points
	_patrol_index = 0


func alert() -> void:
	ai_state = AIState.COMBAT
