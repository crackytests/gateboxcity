extends CharacterBody3D
class_name PlayerController

@export var move_speed := 6.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0022

# ── Crouch / stealth ────────────────────────────────────────────────
@export var crouch_height := 0.9          # capsule height while crouched (standing is 1.8)
@export var crouch_speed_mult := 0.45      # movement penalty while crouched
@export var crouch_camera_y := 0.05        # camera pivot height while crouched
@export var crouch_lerp_speed := 10.0      # how fast the body eases in/out of the crouch
# Crouching dampens your noise signature: enemies pick you up at a shorter range
# and flag you as hostile more slowly. 1.0 = no stealth, lower = sneakier.
@export var crouch_stealth_mult := 0.45

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const STAND_HEIGHT := 1.8

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var look_pitch := 0.0
var base_move_speed := 0.0
var is_climbing := false

var is_crouching := false
var _crouch_t := 0.0          # 0 = fully standing, 1 = fully crouched
var _stand_camera_y := 0.62
# True only after the player frees the cursor with Escape during gameplay. A click
# reclaims the cursor only in that state, so opening any menu can't have its cursor stolen.
var _mouse_freed_by_player := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	base_move_speed = move_speed
	_stand_camera_y = camera_pivot.position.y
	if not GameState.cybernetics_changed.is_connected(_apply_cybernetic_mods):
		GameState.cybernetics_changed.connect(_apply_cybernetic_mods)
	if not GameState.effects_changed.is_connected(_apply_cybernetic_mods):
		GameState.effects_changed.connect(_apply_cybernetic_mods)
	_apply_cybernetic_mods()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Player explicitly freed the cursor for gameplay (not via a menu).
		if not _menu_open():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_mouse_freed_by_player = true
	else:
		var mb := event as InputEventMouseButton
		# Reclaim the cursor only when the player personally released it with Escape, and
		# only on a real left/right click (never a mouse-wheel "button"). This way no menu —
		# HUD or level-specific, enumerated by is_panel_open() or not — can have its cursor
		# stolen by a stray click or scroll that leaks through to gameplay.
		if mb != null and mb.pressed and _is_recapture_button(mb) \
				and _mouse_freed_by_player and not _menu_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_mouse_freed_by_player = false

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		look_pitch = clampf(look_pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		camera_pivot.rotation.x = look_pitch


# Only the primary/secondary buttons should grab the cursor back; wheel and extra
# buttons are excluded so scrolling a menu can't yank the cursor away.
func _is_recapture_button(mb: InputEventMouseButton) -> bool:
	return mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT


func _menu_open() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.has_method("is_panel_open") and hud.is_panel_open()


func _physics_process(delta: float) -> void:
	_update_crouch(delta)

	# Only apply gravity if not climbing
	if not is_climbing and not is_on_floor():
		velocity.y -= gravity * delta

	# Jump first tries to stand up if we're crouched and there's headroom.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	var speed := move_speed * (crouch_speed_mult if is_crouching else 1.0)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction.length() > 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


# ── Crouch ──────────────────────────────────────────────────────────

func _update_crouch(delta: float) -> void:
	var want_crouch := Input.is_action_pressed("crouch")
	# Can't pop back up if something's directly overhead (e.g. inside a crawlspace).
	if not want_crouch and is_crouching and not _has_headroom():
		want_crouch = true
	is_crouching = want_crouch

	var target := 1.0 if is_crouching else 0.0
	_crouch_t = move_toward(_crouch_t, target, crouch_lerp_speed * delta)

	var shape := collision_shape.shape as CapsuleShape3D
	if shape != null:
		var h := lerpf(STAND_HEIGHT, crouch_height, _crouch_t)
		shape.height = h
		# Keep the capsule's feet planted while the top shrinks downward.
		collision_shape.position.y = (h - STAND_HEIGHT) * 0.5

	camera_pivot.position.y = lerpf(_stand_camera_y, crouch_camera_y, _crouch_t)


# True when there's room to extend back to full standing height.
func _has_headroom() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * (crouch_height * 0.5)
	var to := global_position + Vector3.UP * (STAND_HEIGHT * 0.5 + 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


# ── Stealth API (read by enemies) ───────────────────────────────────

# Noise/visibility multiplier: enemies scale their detection range by this.
func get_stealth_mult() -> float:
	return crouch_stealth_mult if is_crouching else 1.0


# Height above the body origin that enemies should sight-check against, so
# crouching actually lets you tuck below waist-high cover.
func get_sight_height() -> float:
	return lerpf(0.8, 0.2, _crouch_t)


func _apply_cybernetic_mods() -> void:
	move_speed = base_move_speed
	if GameState.has_cybernetic("pipewalker_legs"):
		move_speed *= 1.25
	# Sprint Pistons stack multiplicatively with Pipewalker Legs.
	if GameState.has_cybernetic("sprint_pistons"):
		move_speed *= 1.15
	# Drug effects (Jolt speeds you up; Glass/Patch comedowns slow you down).
	move_speed *= GameState.get_speed_multiplier()
