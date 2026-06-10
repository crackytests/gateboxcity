extends Enemy
class_name RockerFellar

# Rocker Fellar — Big Gates Foundation General.
# Death-metal vampire cyborg. Decadent, theatrical, obscene wealth.
# Six targetable body parts with destruction consequences.
# Three combat phases + final defeat.

signal boss_phase_changed(phase: int)

const FRAME_PATHS := [
	"res://assets/sprites/rocker_fellar/rocker_back.png",
	"res://assets/sprites/rocker_fellar/rocker_back_left.png",
	"res://assets/sprites/rocker_fellar/rocker_left.png",
	"res://assets/sprites/rocker_fellar/rocker_front_left.png",
	"res://assets/sprites/rocker_fellar/rocker_front.png",
	"res://assets/sprites/rocker_fellar/rocker_front_right.png",
	"res://assets/sprites/rocker_fellar/rocker_right.png",
	"res://assets/sprites/rocker_fellar/rocker_back_right.png",
]
const STATE_WINDUP_PATH := "res://assets/sprites/rocker_fellar/state_windup.png"
const STATE_DEFEATED_PATH := "res://assets/sprites/rocker_fellar/state_defeated.png"
const ROCKER_SPRITE_PIXEL_SIZE := 0.0092

var boss_phase := 1
var _stage_core_exposed := false
var _jaw_destroyed := false
var _soul_resonator_destroyed := false
var _left_whip_destroyed := false
var _right_whip_destroyed := false
var _spine_destroyed := false
var _on_stage := true
var _state_windup_texture: Texture2D
var _state_defeated_texture: Texture2D
var _base_visual_scale := Vector3.ONE


func _ready() -> void:
	super()
	_base_visual_scale = $Visuals.scale
	_apply_rocker_sprite_art()
	move_speed = 2.2
	melee_damage = 12.0
	ranged_damage = 8.0
	attack_range = 3.0
	ranged_range = 15.0
	attack_cooldown = 2.0
	# Override defeat logic — boss uses custom defeat
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part:
			part.destroyed.disconnect(_on_part_destroyed)
			part.destroyed.connect(_on_boss_part_destroyed)


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
		velocity.z = move_toward(velocity.z, move_speed, 0.0)
		move_and_slide()
		return

	# Boss always in combat once alerted
	if ai_state == AIState.PATROL:
		ai_state = AIState.COMBAT

	_process_combat(delta)

	var visual_scale := 1.0
	if attack_flash_timer > 0.0:
		visual_scale = 1.0 + attack_flash_timer * 0.35
	$Visuals.scale = _base_visual_scale * visual_scale
	move_and_slide()


func _process_combat(_delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if boss_phase == 1 and _on_stage:
		# Stay on stage, rotate toward player
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		var look_target := Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_squared_to(look_target) > 0.01:
			look_at(look_target, Vector3.UP)
	elif boss_phase == 3 and not _spine_destroyed:
		# Phase 3: aggressive charge behavior
		if dist > attack_range:
			var direction := to_player.normalized()
			velocity.x = direction.x * move_speed * 1.5
			velocity.z = direction.z * move_speed * 1.5
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		# Phase 2: standard chase
		if dist > attack_range:
			var direction := to_player.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)

	_try_boss_attack(dist)


func _try_boss_attack(_dist: float) -> void:
	# The level script owns Rocker Fellar's actual damage so cover checks and
	# big arena telegraphs stay synchronized. This body still moves/faces/charges.
	pass


func _on_boss_part_destroyed(part: BodyPart) -> void:
	part.monitorable = false
	part.visible = false
	body_part_destroyed.emit(part.display_name)
	_show_part_break_effect(part)

	var destroyed_count := get_destroyed_part_count()

	match part.display_name:
		"Jaw Amplifier":
			_jaw_destroyed = true
		"Soul Resonator":
			_soul_resonator_destroyed = true
			# Moral/volatile: freeing the battery's soul corrupts your anchor.
			_trigger_free_soul(part)
		"Left Cable Whip":
			_left_whip_destroyed = true
		"Right Cable Whip":
			_right_whip_destroyed = true
		"Amplifier Spine":
			_spine_destroyed = true
			move_speed *= 0.4
		"Stage Core":
			_defeat()
			return

	# Phase transitions
	if boss_phase == 1 and (_jaw_destroyed or _soul_resonator_destroyed):
		_enter_phase_2()
	if destroyed_count >= 3 and boss_phase < 3:
		_enter_phase_3()
	# Final defeat check — all parts or stage core
	if destroyed_count >= 6:
		_defeat()


func _enter_phase_2() -> void:
	boss_phase = 2
	boss_phase_changed.emit(2)
	_on_stage = false
	# Descend to floor level (handled by level script via signal)
	attack_timer = 0.0


func _enter_phase_3() -> void:
	boss_phase = 3
	boss_phase_changed.emit(3)
	attack_timer = 0.0


func regen_all_parts(amount: float) -> void:
	if is_defeated:
		return
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part and not part.is_destroyed:
			part.current_hp = minf(part.current_hp + amount, part.max_hp)


func get_destroyed_part_count() -> int:
	var count := 0
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part and part.is_destroyed:
			count += 1
	return count


func descend_from_stage() -> void:
	_on_stage = false


func expose_stage_core(exposed: bool) -> void:
	_stage_core_exposed = exposed
	# Find Stage Core body part and adjust its lock difficulty
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part and part.display_name == "Stage Core":
			if exposed:
				part.lock_difficulty_multiplier = 0.8
			else:
				part.lock_difficulty_multiplier = 2.0
			break


func set_telegraph_windup(active: bool) -> void:
	if billboard != null and billboard.has_method("set_windup"):
		billboard.set_windup(active)
	if billboard != null and billboard.has_method("set_override_texture"):
		billboard.set_override_texture(_state_windup_texture if active else null)


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
	if billboard != null and billboard.has_method("set_override_texture"):
		billboard.set_override_texture(_state_defeated_texture)
	defeated.emit()


func is_stage_core_exposed() -> bool:
	return _stage_core_exposed


func get_boss_phase() -> int:
	return boss_phase


func _apply_rocker_sprite_art() -> void:
	if billboard == null:
		return
	billboard.frames.clear()
	billboard.frame_paths = PackedStringArray(FRAME_PATHS)
	billboard.pixel_size = ROCKER_SPRITE_PIXEL_SIZE
	billboard.idle_bob_height = 0.018
	if billboard.has_method("_load_frames_from_paths"):
		billboard._load_frames_from_paths()
	if billboard.has_method("align_bottom_to_origin"):
		billboard.align_bottom_to_origin(0.02)
	_state_windup_texture = _load_texture_from_path(STATE_WINDUP_PATH)
	_state_defeated_texture = _load_texture_from_path(STATE_DEFEATED_PATH)


func _load_texture_from_path(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path) as Texture2D
		if loaded != null:
			return loaded
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	var err := ERR_FILE_CANT_READ
	if not bytes.is_empty():
		err = image.load_png_from_buffer(bytes)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)
