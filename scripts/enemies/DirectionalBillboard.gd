extends Sprite3D
class_name DirectionalBillboard

@export var frames: Array[Texture2D] = []
@export var frame_paths: PackedStringArray = []
@export var target_camera_path: NodePath
@export var idle_bob_height := 0.04
@export var idle_bob_speed := 2.0

var target_camera: Camera3D
var base_y := 0.0
var flash_timer := 0.0
var break_flash_timer := 0.0
var defeated := false
var broken_parts: Array[String] = []


func _ready() -> void:
	base_y = position.y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_load_frames_from_paths()
	if not target_camera_path.is_empty():
		target_camera = get_node_or_null(target_camera_path) as Camera3D


func _process(_delta: float) -> void:
	flash_timer = maxf(flash_timer - _delta, 0.0)
	break_flash_timer = maxf(break_flash_timer - _delta, 0.0)
	if break_flash_timer > 0.0:
		var pulse := 0.55 + absf(sin(Time.get_ticks_msec() * 0.035)) * 0.45
		modulate = Color(1.0, 0.08 + pulse * 0.35, 0.08, 1.0)
	elif not broken_parts.is_empty():
		modulate = Color(1.0, 0.78, 0.58, 1.0)
	else:
		modulate = Color(1.0, 0.35, 0.35, 1.0) if flash_timer > 0.0 else Color.WHITE
	scale = scale.lerp(Vector3.ONE, 0.12)

	if target_camera == null:
		target_camera = get_viewport().get_camera_3d()
	if target_camera == null:
		return

	_face_camera_yaw()
	_update_direction_frame()
	position.y = base_y + sin(Time.get_ticks_msec() * 0.001 * idle_bob_speed) * idle_bob_height
	if defeated:
		rotation_degrees.z = lerpf(rotation_degrees.z, 90.0, 0.1)


func flash_damage() -> void:
	flash_timer = 0.16


func show_part_broken(part_name: String) -> void:
	if not broken_parts.has(part_name):
		broken_parts.append(part_name)
	break_flash_timer = 0.9
	scale = Vector3.ONE * 1.16


func show_defeated() -> void:
	defeated = true
	modulate = Color(0.45, 0.9, 0.55, 0.75)


func _face_camera_yaw() -> void:
	var look_target: Vector3 = target_camera.global_position
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)


func _update_direction_frame() -> void:
	if frames.size() < 8:
		return

	var to_camera: Vector3 = target_camera.global_position - global_position
	to_camera.y = 0.0
	to_camera = to_camera.normalized()

	var enemy_forward: Vector3 = -get_parent().global_transform.basis.z
	enemy_forward.y = 0.0
	enemy_forward = enemy_forward.normalized()

	var signed_angle: float = rad_to_deg(atan2(enemy_forward.cross(to_camera).y, enemy_forward.dot(to_camera)))
	var bucket: int = int(round(signed_angle / 45.0) * 45)
	if bucket < 0:
		bucket += 360

	var index: int = _bucket_to_frame_index(bucket % 360)
	texture = frames[index]


func _bucket_to_frame_index(bucket: int) -> int:
	match bucket:
		180:
			return 0
		135:
			return 1
		90:
			return 2
		45:
			return 3
		0, 360:
			return 4
		315:
			return 5
		270:
			return 6
		225:
			return 7
		_:
			return 4


func _load_frames_from_paths() -> void:
	if not frames.is_empty() or frame_paths.is_empty():
		return

	for path in frame_paths:
		var image := Image.new()
		var bytes := FileAccess.get_file_as_bytes(path)
		var err := ERR_FILE_CANT_READ
		if not bytes.is_empty():
			err = image.load_png_from_buffer(bytes)
		if err != OK:
			push_warning("Could not load billboard frame: " + path)
			continue

		var image_texture := ImageTexture.create_from_image(image)
		frames.append(image_texture)

	if frames.size() > 4:
		texture = frames[4]
