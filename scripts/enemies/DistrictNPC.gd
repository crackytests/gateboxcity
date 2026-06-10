extends CharacterBody3D
class_name DistrictNPC

signal focus_changed(npc: DistrictNPC, has_focus: bool)

@export var npc_name := "District Resident"
@export var npc_id := ""
@export_group("Movement")
@export var wander_radius := 4.0
@export var move_speed := 1.2
@export var idle_duration := 3.0
@export var walk_duration := 2.0
@export_group("Dialogue")
@export_multiline var default_lines: PackedStringArray = [
	"The rain tastes like policy.",
	"Somewhere above us, someone is being cared for against their will.",
]
@export_multiline var rain_lines: PackedStringArray = [
	"Get under something before your skin forgets how to heal.",
	"The rain is worse today. Someone angered the false sky.",
]
@export_multiline var sag_lines: PackedStringArray = [
	"Power is flickering again. The generator has opinions.",
	"Darkness means the surveillance is rebooting. Move fast.",
]
@export_multiline var lan_lines: PackedStringArray = [
	"The Hoodlums are at it again. Whole block just went dark.",
	"Enjoy the blind spots while they last.",
]
@export_multiline var stable_lines: PackedStringArray = [
	"Generator is humming clean. Does not mean safe, just predictable.",
]
@export_group("Faction Dialogue")
@export var rep_check_faction := ""
@export var rep_threshold := 2
@export_multiline var high_rep_lines: PackedStringArray = []
@export_multiline var low_rep_lines: PackedStringArray = []

var home_position := Vector3.ZERO
var wander_target := Vector3.ZERO
var state_timer := 0.0
var is_walking := false
var bark_cooldown := 0.0
var _has_barked := false
var _dialogue_locked := false
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float


func _ready() -> void:
	home_position = global_position
	_pick_next_state()
	var detect := _get_detect_area()
	if detect != null:
		detect.body_entered.connect(_on_body_entered)
		detect.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _dialogue_locked:
		is_walking = false
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	state_timer -= delta
	bark_cooldown = maxf(bark_cooldown - delta, 0.0)

	if is_walking:
		var to_target := wander_target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.3 or state_timer <= 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
			_pick_next_state()
		else:
			var dir := to_target.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			look_at(Vector3(wander_target.x, global_position.y, wander_target.z), Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if state_timer <= 0.0:
			_pick_next_state()

	move_and_slide()


func get_bark_line() -> String:
	var lines := _get_active_lines()
	if lines.is_empty():
		return ""
	return lines[randi() % lines.size()]


func interact() -> Dictionary:
	face_player_now()
	var line := get_bark_line()
	if line.is_empty():
		line = "..."
	return {
		"name": npc_name,
		"text": line,
	}


func face_player_now() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	is_walking = false
	velocity.x = 0.0
	velocity.z = 0.0
	var look_target := player.global_position
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)


func set_dialogue_locked(locked: bool) -> void:
	_dialogue_locked = locked
	if locked:
		is_walking = false
		velocity.x = 0.0
		velocity.z = 0.0


func _pick_next_state() -> void:
	if is_walking or randf() < 0.5:
		is_walking = true
		state_timer = walk_duration + randf() * 1.5
		var angle := randf() * TAU
		var dist := randf() * wander_radius
		wander_target = home_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	else:
		is_walking = false
		state_timer = idle_duration + randf() * 2.0


func _get_detect_area() -> Area3D:
	return get_node_or_null("DetectArea") as Area3D


func _get_active_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	if not rep_check_faction.is_empty():
		var rep := int(GameState.reputation.get(rep_check_faction, 0))
		if rep >= rep_threshold and not high_rep_lines.is_empty():
			lines.append_array(high_rep_lines)
		elif rep <= -rep_threshold and not low_rep_lines.is_empty():
			lines.append_array(low_rep_lines)

	if not lines.is_empty() and randf() < 0.4:
		return lines

	match WorldDirector.active_event:
		WorldDirector.EVENT_TOXIC_RAIN:
			if not rain_lines.is_empty():
				lines.append_array(rain_lines)
		WorldDirector.EVENT_POWER_SAG:
			if not sag_lines.is_empty():
				lines.append_array(sag_lines)
		WorldDirector.EVENT_LAN_OUTAGE:
			if not lan_lines.is_empty():
				lines.append_array(lan_lines)
		_:
			if WorldDirector.get_generator_state() == WorldDirector.GENERATOR_STABLE and not stable_lines.is_empty():
				lines.append_array(stable_lines)

	if lines.is_empty():
		lines.append_array(default_lines)

	return lines


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)
		if bark_cooldown <= 0.0 and not _has_barked:
			_has_barked = true
			bark_cooldown = 12.0


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
		_has_barked = false
