extends CharacterBody3D
class_name Escortee

# Sprint B5 — the escort objective's follower. A stranded asset waiting deep in a job destination.
# It idles at its rescue point until the player reaches it, then lag-follows them to the extraction
# point (the level entrance, captured when the run starts). It carries its own integrity and takes
# chip damage when hostile enemies crowd it, so the player protects it by positioning. Reaching the
# extraction alive completes the objective; dropping to zero loses it (re-enter the level to retry).

signal reached_safety
signal died

@export var max_hp := 65.0
@export var move_speed := 5.4
@export var follow_distance := 2.4        # stops this far from the player
@export var activation_radius := 4.5      # starts following once the player gets this close
@export var catchup_distance := 16.0      # if stranded behind, snap closer (no navmesh out here)
@export var goal_radius := 4.0            # within this of the extraction = delivered
@export var hazard_radius := 2.8          # a COMBAT enemy this close chips integrity
@export var hazard_dps := 7.0

var current_hp := 0.0
var is_following := false
var is_down := false
var is_safe := false
var extraction_goal := Vector3.ZERO

var _player: Node3D
var _hud
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _label: Label3D
var _mesh_mat: StandardMaterial3D
var _hp_bucket := -1
var _hazard_log_cooldown := 0.0


# Wire the asset before it enters the tree. extraction is where it must be walked back to (alive).
func setup(player: Node3D, hud, extraction: Vector3) -> void:
	_player = player
	_hud = hud
	extraction_goal = extraction


func _ready() -> void:
	current_hp = max_hp
	add_to_group("escortee")
	# Stand on the floor (mask layer 1) but don't block movement or catch weapon-fire (layer 0).
	collision_layer = 0
	collision_mask = 1
	_build_visuals()
	_update_label()


func _build_visuals() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.38
	capsule_mesh.height = 1.6
	mesh_inst.mesh = capsule_mesh
	mesh_inst.position = Vector3(0, 0.9, 0)
	_mesh_mat = StandardMaterial3D.new()
	_mesh_mat.albedo_color = Color(0.1, 0.5, 0.62)
	_mesh_mat.emission_enabled = true
	_mesh_mat.emission = Color(0.2, 0.85, 1.0)   # cyan = friendly, distinct from hostile magenta
	_mesh_mat.emission_energy_multiplier = 0.9
	mesh_inst.set_surface_override_material(0, _mesh_mat)
	add_child(mesh_inst)

	_label = Label3D.new()
	_label.text = "ESCORT"
	_label.position = Vector3(0, 2.15, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true             # a simple always-visible HUD callout in the world
	_label.fixed_size = true
	_label.pixel_size = 0.0024
	_label.modulate = Color(0.5, 0.95, 1.0)
	_label.outline_modulate = Color(0, 0, 0, 0.8)
	_label.outline_size = 10
	add_child(_label)


func _physics_process(delta: float) -> void:
	if _hazard_log_cooldown > 0.0:
		_hazard_log_cooldown -= delta
	if is_down or is_safe or _player == null:
		return

	# Stay grounded.
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	var to_player := _player.global_position - global_position
	var flat_dist := Vector2(to_player.x, to_player.z).length()

	if not is_following:
		# Wait to be found.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if flat_dist <= activation_radius:
			_activate()
		return

	# Lag-follow: only close the gap when the player has pulled ahead.
	if flat_dist > catchup_distance:
		# Stranded on geometry — snap up behind the player so the escort can't soft-lock.
		var behind := _player.global_transform.basis.z.normalized()
		global_position = _player.global_position + behind * 1.8
	elif flat_dist > follow_distance:
		var dir := to_player
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

	_take_hazard_damage(delta)
	_check_extraction()


func _activate() -> void:
	is_following = true
	if _hud != null:
		_hud.push_log("escort: asset is following — get it to the entrance alive")
		if _hud.has_method("show_dialogue"):
			_hud.show_dialogue("Escort", "It latches onto you the second you're close. \"You're the way out? Then I'm whatever you are now. Don't stop.\"")


func _take_hazard_damage(delta: float) -> void:
	var threat := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == null or not (e is Enemy):
			continue
		var en := e as Enemy
		if en.is_defeated or en.is_pacified:
			continue
		if en.ai_state != Enemy.AIState.COMBAT:
			continue
		if en.global_position.distance_to(global_position) <= hazard_radius:
			threat = true
			break
	if threat:
		_apply_damage(hazard_dps * delta)
		if _hazard_log_cooldown <= 0.0 and _hud != null:
			_hud.push_log("escort: asset is taking fire — clear the threat")
			_hazard_log_cooldown = 2.5


func _apply_damage(amount: float) -> void:
	if is_down or is_safe:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	_update_label()
	if current_hp <= 0.0:
		_go_down()


func _go_down() -> void:
	is_down = true
	is_following = false
	if _mesh_mat != null:
		_mesh_mat.emission = Color(0.5, 0.5, 0.5)
		_mesh_mat.emission_energy_multiplier = 0.3
	if _label != null:
		_label.text = "ESCORT DOWN"
		_label.modulate = Color(0.8, 0.3, 0.3)
	if _hud != null:
		_hud.push_log("escort lost — the asset is down")
	died.emit()


func _check_extraction() -> void:
	if extraction_goal == Vector3.ZERO:
		return
	var flat := Vector2(global_position.x - extraction_goal.x, global_position.z - extraction_goal.z).length()
	if flat <= goal_radius:
		is_safe = true
		is_following = false
		velocity = Vector3.ZERO
		if _label != null:
			_label.text = "ESCORT SAFE"
			_label.modulate = Color(0.4, 1.0, 0.5)
		reached_safety.emit()


func _update_label() -> void:
	if _label == null:
		return
	var bucket := int(ceil(current_hp / max_hp * 4.0))   # quarters
	if bucket == _hp_bucket and not is_down:
		return
	_hp_bucket = bucket
	if not is_down and not is_safe:
		_label.text = "ESCORT  %d%%" % int(round(current_hp / max_hp * 100.0))
		# Shade the label from cyan toward warning red as it gets hurt.
		var frac := current_hp / max_hp
		_label.modulate = Color(1.0 - frac * 0.5, 0.5 + frac * 0.45, frac, 1.0)


# ── Spawning ────────────────────────────────────────────────────────
# Call from a destination's _ready. If the active job is an escort pointed at this destination and
# isn't already done, drops the asset at `rescue_position` and returns it; otherwise returns null.
static func spawn_for_active_job(host: Node3D, player: Node3D, hud, destination_id: String, rescue_position: Vector3) -> Escortee:
	if player == null or GameState.active_job_id.is_empty():
		return null
	var job := GameState.get_active_job_data()
	if str(job.get("objective_type", "")) != "escort":
		return null
	if str(job.get("destination_id", "")) != destination_id:
		return null
	if GameState.is_job_objective_done(GameState.active_job_id):
		return null   # already walked out — don't respawn it
	var e := Escortee.new()
	e.setup(player, hud, player.global_position)   # extraction = where the player entered
	host.add_child(e)
	e.global_position = rescue_position
	return e
