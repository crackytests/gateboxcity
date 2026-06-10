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
var _lock_build_sfx_timer := 0.0
var _ready_sfx_played := false
var _current_target_owner: Node


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
	_lock_build_sfx_timer = maxf(_lock_build_sfx_timer - delta, 0.0)

	if part != null:
		var target_owner := _target_owner(part)
		if part == current_part:
			var difficulty := maxf(part.lock_difficulty_multiplier, 0.1)
			lock_ratio += (lock_gain_per_second / difficulty) * delta
		else:
			var is_new_enemy := target_owner != null and target_owner != _current_target_owner
			current_part = part
			_current_target_owner = target_owner
			lock_ratio = 0.08
			_ready_sfx_played = false
			_lock_build_sfx_timer = 0.25
			if is_new_enemy:
				AudioDirector.play_sfx("target_lock_begin", -6.0)
	else:
		if current_part != null and not _is_part_targetable(current_part):
			_clear_lock()
		else:
			lock_ratio -= lock_decay_per_second * delta
			if lock_ratio <= 0.0:
				_clear_lock()

	lock_ratio = clampf(lock_ratio, 0.0, 1.0)
	hit_chance = _calculate_hit_chance()
	_update_lock_sfx()
	targeting_changed.emit(current_part, lock_ratio, hit_chance)


func get_targeting_result() -> Dictionary:
	_refresh_current_part_for_fire()
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


func _refresh_current_part_for_fire() -> void:
	var fresh_part := _raycast_body_part()
	if fresh_part == null:
		if current_part == null or not _is_part_targetable(current_part):
			_clear_lock()
			lock_ratio = 0.0
			hit_chance = 0.0
		return

	if fresh_part != current_part:
		_current_target_owner = _target_owner(fresh_part)
		current_part = fresh_part
		lock_ratio = maxf(lock_ratio, 0.08)
		_ready_sfx_played = false
	hit_chance = _calculate_hit_chance()


func _update_lock_sfx() -> void:
	if current_part == null or not _is_part_targetable(current_part):
		return
	if lock_ratio >= 0.92:
		if not _ready_sfx_played:
			AudioDirector.play_sfx("target_lock_ready", -4.0)
			_ready_sfx_played = true
		return
	if lock_ratio >= 0.22 and _lock_build_sfx_timer <= 0.0:
		AudioDirector.play_sfx("target_lock_build", -11.0, lerpf(0.9, 1.08, lock_ratio))
		_lock_build_sfx_timer = 0.48


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
		if _is_part_targetable(collider):
			return collider

	return _find_body_part_near_crosshair(viewport_center)


func _find_body_part_near_crosshair(viewport_center: Vector2) -> BodyPart:
	var best_part: BodyPart
	var best_score := INF

	for node in get_tree().get_nodes_in_group("body_parts"):
		var part := node as BodyPart
		if not _is_part_targetable(part) or camera.is_position_behind(part.global_position):
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


func _clear_lock() -> void:
	current_part = null
	_current_target_owner = null
	lock_ratio = 0.0
	hit_chance = 0.0
	_ready_sfx_played = false


func _is_part_targetable(part: BodyPart) -> bool:
	if part == null or part.is_destroyed:
		return false
	var owner_node := _target_owner(part)
	if owner_node != null:
		var defeated = owner_node.get("is_defeated")
		if defeated != null and bool(defeated):
			return false
	return true


func _target_owner(part: BodyPart) -> Node:
	if part == null:
		return null
	var parent := part.get_parent()
	if parent == null:
		return part
	var grandparent := parent.get_parent()
	return grandparent if grandparent != null else parent
