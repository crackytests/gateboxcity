extends Node3D
class_name Weapon

signal ammo_changed(current: int, reserve: int)
signal fired(message: String)

@export var weapon_data: Resource
@export var damage := 12.0
@export var damage_type := "kinetic"
@export var magazine_size := 12
@export var reserve_ammo := 48
@export var lock_retention_after_shot := 0.45
@export var melee_damage := 22.0
@export var melee_range := 3.0
@export var melee_cooldown := 0.55
@export var targeting: PlayerTargeting
@export var view_texture: Texture2D
@export var fire_texture: Texture2D
@export var fire_animation: Array[Texture2D] = []
@export var fire_effect_duration := 0.42
@export_dir var fire_anim_dir := "res://assets/sprites/weapon/spooky_scrap_pistol/fire_anim"
@export var idle_animation: Array[Texture2D] = []
@export var idle_anim_fps := 15.0
@export_dir var idle_anim_dir := "res://assets/sprites/weapon/spooky_scrap_pistol/idle_anim"
@export var recoil_texture: Texture2D
@export var reload_texture: Texture2D
@export var reload_finish_texture: Texture2D
@export var reload_animation: Array[Texture2D] = []
@export var reload_anim_fps := 24.0
@export var reload_effect_duration := 0.36
@export var reload_scale_multiplier := 1.5
@export_dir var reload_anim_dir := "res://assets/sprites/weapon/spooky_scrap_pistol/reload"
@export_file("*.png") var view_texture_path := "res://assets/sprites/weapon/scrap_pistol_view.png"

var current_ammo := 0
var fire_effect_timer := 0.0
var reload_effect_timer := 0.0
var active_reload_effect_duration := 0.36
var melee_timer := 0.0
var melee_effect_timer := 0.0
var idle_anim_time := 0.0
var view_base_position := Vector3.ZERO
var view_base_rotation := Vector3.ZERO
var view_base_scale := Vector3.ONE
var recoil_visual_multiplier := 1.0
var base_lock_retention_after_shot := 0.0

@onready var view_sprite: Sprite3D = get_node_or_null("ViewSprite") as Sprite3D
@onready var muzzle_flash: MeshInstance3D = get_node_or_null("MuzzleFlash") as MeshInstance3D
@onready var muzzle_light: OmniLight3D = get_node_or_null("MuzzleLight") as OmniLight3D


func _ready() -> void:
	_apply_weapon_data()
	base_lock_retention_after_shot = lock_retention_after_shot
	if not GameState.cybernetics_changed.is_connected(_apply_cybernetic_mods):
		GameState.cybernetics_changed.connect(_apply_cybernetic_mods)
	_apply_cybernetic_mods()
	_bind_targeting()
	_setup_view_sprite()
	current_ammo = magazine_size
	ammo_changed.emit(current_ammo, reserve_ammo)


func _process(delta: float) -> void:
	fire_effect_timer = maxf(fire_effect_timer - delta, 0.0)
	reload_effect_timer = maxf(reload_effect_timer - delta, 0.0)
	melee_timer = maxf(melee_timer - delta, 0.0)
	melee_effect_timer = maxf(melee_effect_timer - delta, 0.0)
	idle_anim_time += delta

	if muzzle_flash != null:
		muzzle_flash.visible = fire_effect_timer > 0.0
		if muzzle_flash.visible:
			var pulse := 1.0 + randf() * 0.35
			muzzle_flash.scale = Vector3.ONE * pulse
	if muzzle_light != null:
		muzzle_light.visible = fire_effect_timer > 0.0

	if view_sprite != null:
		var fire_ratio := fire_effect_timer / fire_effect_duration if fire_effect_duration > 0.0 and fire_effect_timer > 0.0 else 0.0
		var recoil := fire_ratio * recoil_visual_multiplier if fire_effect_timer > 0.0 else 0.0
		if reload_effect_timer > 0.0:
			if reload_animation.size() > 0:
				var reload_progress := _reload_progress()
				var frame_index := clampi(floori(reload_progress * float(reload_animation.size())), 0, reload_animation.size() - 1)
				view_sprite.texture = reload_animation[frame_index]
			elif reload_texture != null:
				var reload_ratio := reload_effect_timer / active_reload_effect_duration if active_reload_effect_duration > 0.0 else 0.0
				if reload_ratio > 0.62:
					view_sprite.texture = reload_texture
				elif reload_ratio > 0.28 and reload_finish_texture != null:
					view_sprite.texture = reload_finish_texture
				else:
					view_sprite.texture = _current_idle_texture()
			else:
				view_sprite.texture = _current_idle_texture()
		elif fire_texture != null and view_texture != null:
			if fire_animation.size() > 0 and fire_effect_timer > 0.0:
				var fire_progress := clampf(1.0 - fire_ratio, 0.0, 0.999)
				var frame_index := clampi(floori(fire_progress * float(fire_animation.size())), 0, fire_animation.size() - 1)
				view_sprite.texture = fire_animation[frame_index]
			elif recoil > 0.55:
				view_sprite.texture = fire_texture
			elif recoil > 0.05 and recoil_texture != null:
				view_sprite.texture = recoil_texture
			else:
				view_sprite.texture = _current_idle_texture()
		var reload_bob := reload_effect_timer / active_reload_effect_duration if active_reload_effect_duration > 0.0 and reload_effect_timer > 0.0 else 0.0
		var melee_lunge := melee_effect_timer / 0.18 if melee_effect_timer > 0.0 else 0.0
		var target_position := view_base_position + Vector3(0.025, -0.025, 0.05) * recoil + Vector3(0.02, -0.035, 0.02) * reload_bob + Vector3(-0.06, 0.02, -0.12) * melee_lunge
		var target_rotation := view_base_rotation + Vector3(deg_to_rad(-2.5), deg_to_rad(1.5), deg_to_rad(-1.0)) * recoil + Vector3(deg_to_rad(1.5), deg_to_rad(-1.0), deg_to_rad(0.6)) * reload_bob + Vector3(deg_to_rad(2.0), deg_to_rad(-9.0), deg_to_rad(4.0)) * melee_lunge
		var target_scale := view_base_scale * (reload_scale_multiplier if reload_effect_timer > 0.0 else 1.0)
		view_sprite.position = view_sprite.position.lerp(target_position, 0.45)
		view_sprite.rotation = view_sprite.rotation.lerp(target_rotation, 0.45)
		view_sprite.scale = view_sprite.scale.lerp(target_scale, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		fire()
	elif event.is_action_pressed("melee"):
		melee()
	elif event.is_action_pressed("reload") or _is_manual_reload_key(event):
		reload()


func fire() -> void:
	if current_ammo <= 0:
		AudioDirector.play_sfx("scrap_pistol_dry_fire")
		fired.emit("empty magazine - press R")
		return

	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)
	_show_fire_effect()
	AudioDirector.play_sfx("scrap_pistol_fire", -0.5, 1.0)

	if targeting == null:
		fired.emit("shot lost in static")
		return

	var result := targeting.get_targeting_result()
	if result.has_valid_part:
		var roll := randf() * 100.0
		var chance: float = result.hit_chance
		var part: BodyPart = result.body_part
		if roll <= chance:
			var dealt := part.apply_damage(damage * GameState.get_damage_multiplier(), damage_type)
			fired.emit("hit %s for %d" % [part.display_name, roundi(dealt)])
		else:
			AudioDirector.play_sfx("target_miss_static", -9.0)
			fired.emit("missed %s" % part.display_name)
		targeting.apply_weapon_lock_penalty(lock_retention_after_shot)
	else:
		fired.emit("untargeted shot")


func melee() -> void:
	if melee_timer > 0.0:
		return
	melee_timer = melee_cooldown
	melee_effect_timer = 0.18

	var reach := melee_range
	var dmg := melee_damage
	# Salvage Graft extends reach and hits considerably harder.
	if GameState.has_cybernetic("left_arm_graft"):
		reach *= 1.3
		dmg *= 1.6
	dmg *= GameState.get_damage_multiplier()

	if targeting == null:
		fired.emit("melee swing — no target")
		return
	var result := targeting.get_targeting_result()
	if not result.has_valid_part:
		fired.emit("melee swing — nothing in reach")
		return
	var part: BodyPart = result.body_part
	var cam := targeting.camera
	var dist := 999.0
	if cam != null:
		dist = cam.global_position.distance_to(part.global_position)
	if dist > reach:
		fired.emit("melee swing — too far, close in")
		return
	# Melee always connects at this range; no hit-chance roll.
	var dealt := part.apply_damage(dmg, "kinetic")
	AudioDirector.play_sfx("melee_scrap_hit", 0.0, randf_range(0.94, 1.04))
	fired.emit("melee smash %s for %d" % [part.display_name, roundi(dealt)])


func reload() -> void:
	if current_ammo >= magazine_size:
		fired.emit("magazine already full")
		return
	if reserve_ammo <= 0:
		fired.emit("no reserve scrap")
		return

	var needed := magazine_size - current_ammo
	var loaded := mini(needed, reserve_ammo)
	current_ammo += loaded
	reserve_ammo -= loaded
	ammo_changed.emit(current_ammo, reserve_ammo)
	AudioDirector.play_sfx("scrap_pistol_reload", -1.0, randf_range(0.97, 1.03))
	# Jolt's stim shortens the reload animation.
	active_reload_effect_duration = _base_reload_effect_duration() * GameState.get_reload_multiplier()
	reload_effect_timer = active_reload_effect_duration
	var prefix := "reloaded"
	if weapon_data != null and not weapon_data.reload_log.is_empty():
		prefix = weapon_data.reload_log
	fired.emit("%s %d rounds" % [prefix, loaded])


func _is_manual_reload_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_R


func _apply_weapon_data() -> void:
	if weapon_data == null:
		return

	damage = weapon_data.get("damage")
	damage_type = weapon_data.get("damage_type")
	magazine_size = weapon_data.get("magazine_size")
	reserve_ammo = weapon_data.get("reserve_ammo")
	lock_retention_after_shot = weapon_data.get("lock_retention_after_shot")


func _apply_cybernetic_mods() -> void:
	lock_retention_after_shot = base_lock_retention_after_shot
	recoil_visual_multiplier = 1.0
	if GameState.has_cybernetic("black_market_armature"):
		lock_retention_after_shot = clampf(base_lock_retention_after_shot + 0.18, 0.0, 0.95)
		recoil_visual_multiplier = 0.68


func _bind_targeting() -> void:
	if targeting != null:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		targeting = player.find_child("PlayerTargeting", true, false) as PlayerTargeting


func _setup_view_sprite() -> void:
	if view_sprite == null:
		return

	view_base_position = view_sprite.position
	view_base_rotation = view_sprite.rotation
	view_base_scale = view_sprite.scale
	view_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if fire_animation.is_empty():
		_load_anim_frames(fire_anim_dir, fire_animation)
	if idle_animation.is_empty():
		_load_anim_frames(idle_anim_dir, idle_animation)
	if reload_animation.is_empty():
		_load_anim_frames(reload_anim_dir, reload_animation)
	if view_texture != null:
		view_sprite.texture = view_texture
	else:
		var loaded_texture := ResourceLoader.load(view_texture_path) as Texture2D
		if loaded_texture != null:
			view_sprite.texture = loaded_texture

	if muzzle_flash != null:
		muzzle_flash.visible = false
	if muzzle_light != null:
		muzzle_light.visible = false


# Auto-loads sequential frames (001.png, 002.png, ...) from a directory into the
# given typed array. Raw PNG loading keeps new frame folders usable before the
# editor creates .import metadata for them.
func _load_anim_frames(dir: String, into: Array) -> void:
	if dir.is_empty():
		return
	var base := dir.rstrip("/")
	var i := 1
	while true:
		var path := "%s/%03d.png" % [base, i]
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			break
		var tex := _load_texture(path)
		if tex == null:
			break
		into.append(tex)
		i += 1


func _load_texture(path: String) -> Texture2D:
	var imported_texture := ResourceLoader.load(path) as Texture2D
	if imported_texture != null:
		return imported_texture

	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


# The current resting-pose texture: the looping idle animation if loaded,
# otherwise the static view texture.
func _current_idle_texture() -> Texture2D:
	if idle_animation.size() > 0 and idle_anim_fps > 0.0:
		var idx := int(idle_anim_time * idle_anim_fps) % idle_animation.size()
		return idle_animation[idx]
	return view_texture


func _base_reload_effect_duration() -> float:
	if reload_animation.size() > 0 and reload_anim_fps > 0.0:
		return float(reload_animation.size()) / reload_anim_fps
	return reload_effect_duration


func _reload_progress() -> float:
	if active_reload_effect_duration <= 0.0:
		return 0.0
	return clampf(1.0 - (reload_effect_timer / active_reload_effect_duration), 0.0, 0.999)


func _show_fire_effect() -> void:
	fire_effect_timer = fire_effect_duration
	if muzzle_flash != null:
		muzzle_flash.rotation_degrees.z = randf_range(-18.0, 18.0)
		muzzle_flash.visible = true
	if muzzle_light != null:
		muzzle_light.visible = true
