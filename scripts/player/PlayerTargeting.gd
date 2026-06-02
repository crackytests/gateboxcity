extends Node
class_name PlayerTargeting

signal targeting_changed(part: BodyPart, lock_ratio: float, hit_chance: float)

@export var camera: Camera3D
@export var max_distance := 60.0
@export var base_hit_chance := 25.0
@export var max_hit_chance := 95.0
@export var lock_gain_per_second := 0.75
@export var lock_decay_per_second := 1.35
@export var crosshair_pick_radius := 58.0

var current_part: BodyPart
var lock_ratio := 0.0
var hit_chance := 0.0
var base_hit_chance_unmodified := 0.0
var lock_gain_unmodified := 0.0
var crosshair_pick_radius_unmodified := 0.0
var lock_decay_unmodified := 0.0


func _ready() -> void:
	if camera == null:
		camera = get_parent().find_child("Camera3D", true, false) as Camera3D
	base_hit_chance_unmodified = base_hit_chance
	lock_gain_unmodified = lock_gain_per_second
	crosshair_pick_radius_unmodified = crosshair_pick_radius
	lock_decay_unmodified = lock_decay_per_second
	if not GameState.cybernetics_changed.is_connected(_apply_cybernetic_mods):
		GameState.cybernetics_changed.connect(_apply_cybernetic_mods)
	_apply_cybernetic_mods()


func _apply_cybernetic_mods() -> void:
	base_hit_chance = base_hit_chance_unmodified
	lock_gain_per_second = lock_gain_unmodified
	crosshair_pick_radius = crosshair_pick_radius_unmodified
	lock_decay_per_second = lock_decay_unmodified
	if GameState.has_cybernetic("targeting_coprocessor"):
		base_hit_chance += 10.0
		lock_gain_per_second += 0.35
		crosshair_pick_radius += 18.0
	# Mag-Retina surfaces weak points: a flat accuracy edge plus easier pickup.
	if GameState.has_cybernetic("mag_retina"):
		base_hit_chance += 6.0
		crosshair_pick_radius += 10.0
	# Trauma Dampener keeps the lock steady — target lock decays more slowly.
	if GameState.has_cybernetic("trauma_dampener"):
		lock_decay_per_second *= 0.6


func _process(delta: float) -> void:
	var part := _raycast_body_part()

	if part != null:
		if part == current_part:
			var difficulty := maxf(part.lock_difficulty_multiplier, 0.1)
			lock_ratio += (lock_gain_per_second / difficulty) * delta
		else:
			current_part = part
			lock_ratio = 0.08
	else:
		lock_ratio -= lock_decay_per_second * delta
		if lock_ratio <= 0.0:
			current_part = null

	lock_ratio = clampf(lock_ratio, 0.0, 1.0)
	hit_chance = _calculate_hit_chance()
	targeting_changed.emit(current_part, lock_ratio, hit_chance)


func get_targeting_result() -> Dictionary:
	return {
		"has_valid_part": current_part != null and not current_part.is_destroyed,
		"body_part": current_part,
		"lock_ratio": lock_ratio,
		"hit_chance": hit_chance,
	}


func apply_weapon_lock_penalty(retention: float) -> void:
	lock_ratio *= clampf(retention, 0.0, 1.0)


func _calculate_hit_chance() -> float:
	if current_part == null:
		return 0.0

	var surveillance_bonus := 5.0 if GameState.get_world_flag("suitors_surveillance_jammed") else 0.0
	# Drug effects: Glass sharpens aim, the Jolt comedown ruins it.
	var drug_bonus := GameState.get_hit_chance_bonus()
	var part_max := max_hit_chance - current_part.targeting_penalty
	return clampf(lerpf(base_hit_chance + surveillance_bonus + drug_bonus, part_max, lock_ratio), 1.0, 99.0)


func _raycast_body_part() -> BodyPart:
	if camera == null:
		return null

	var viewport_center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(viewport_center)
	var end := origin + camera.project_ray_normal(viewport_center) * max_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 2

	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider := result.get("collider") as BodyPart
		if collider != null:
			return collider

	return _find_body_part_near_crosshair(viewport_center)


func _find_body_part_near_crosshair(viewport_center: Vector2) -> BodyPart:
	var best_part: BodyPart
	var best_score := INF

	for node in get_tree().get_nodes_in_group("body_parts"):
		var part := node as BodyPart
		if part == null or part.is_destroyed or camera.is_position_behind(part.global_position):
			continue

		var screen_position := camera.unproject_position(part.global_position)
		var screen_distance := screen_position.distance_to(viewport_center)
		var active_pick_radius := crosshair_pick_radius + (8.0 if GameState.get_world_flag("suitors_surveillance_jammed") else 0.0)
		if screen_distance > active_pick_radius:
			continue

		var world_distance := camera.global_position.distance_to(part.global_position)
		if world_distance > max_distance:
			continue

		var score := screen_distance + world_distance * 0.02
		if score < best_score:
			best_score = score
			best_part = part

	return best_part
