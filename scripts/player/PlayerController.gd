extends CharacterBody3D
class_name PlayerController

@export var move_speed := 6.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0022

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera3D

var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var look_pitch := 0.0
var base_move_speed := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	base_move_speed = move_speed
	if not GameState.cybernetics_changed.is_connected(_apply_cybernetic_mods):
		GameState.cybernetics_changed.connect(_apply_cybernetic_mods)
	_apply_cybernetic_mods()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		look_pitch = clampf(look_pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		camera_pivot.rotation.x = look_pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction.length() > 0.0:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()


func _apply_cybernetic_mods() -> void:
	move_speed = base_move_speed
	if GameState.has_cybernetic("pipewalker_legs"):
		move_speed = base_move_speed * 1.25
