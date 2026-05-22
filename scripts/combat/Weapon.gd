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
@export var targeting: PlayerTargeting
@export var view_texture: Texture2D
@export var fire_texture: Texture2D
@export var recoil_texture: Texture2D
@export var reload_texture: Texture2D
@export var reload_finish_texture: Texture2D
@export_file("*.png") var view_texture_path := "res://assets/sprites/weapon/scrap_pistol_view.png"

var current_ammo := 0
var fire_effect_timer := 0.0
var reload_effect_timer := 0.0
var view_base_position := Vector3.ZERO
var view_base_rotation := Vector3.ZERO
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
	if muzzle_flash != null:
		muzzle_flash.visible = fire_effect_timer > 0.0
		if muzzle_flash.visible:
			var pulse := 1.0 + randf() * 0.35
			muzzle_flash.scale = Vector3.ONE * pulse
	if muzzle_light != null:
		muzzle_light.visible = fire_effect_timer > 0.0

	if view_sprite != null:
		var recoil := (fire_effect_timer / 0.08) * recoil_visual_multiplier if fire_effect_timer > 0.0 else 0.0
		if reload_effect_timer > 0.0 and reload_texture != null:
			if reload_effect_timer > 0.22:
				view_sprite.texture = reload_texture
			elif reload_effect_timer > 0.10 and reload_finish_texture != null:
				view_sprite.texture = reload_finish_texture
			else:
				view_sprite.texture = view_texture
		elif fire_texture != null and view_texture != null:
			if recoil > 0.55:
				view_sprite.texture = fire_texture
			elif recoil > 0.05 and recoil_texture != null:
				view_sprite.texture = recoil_texture
			else:
				view_sprite.texture = view_texture
		var reload_bob := reload_effect_timer / 0.36 if reload_effect_timer > 0.0 else 0.0
		var target_position := view_base_position + Vector3(0.025, -0.025, 0.05) * recoil + Vector3(0.02, -0.035, 0.02) * reload_bob
		var target_rotation := view_base_rotation + Vector3(deg_to_rad(-2.5), deg_to_rad(1.5), deg_to_rad(-1.0)) * recoil + Vector3(deg_to_rad(1.5), deg_to_rad(-1.0), deg_to_rad(0.6)) * reload_bob
		view_sprite.position = view_sprite.position.lerp(target_position, 0.45)
		view_sprite.rotation = view_sprite.rotation.lerp(target_rotation, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		fire()
	elif event.is_action_pressed("reload") or _is_manual_reload_key(event):
		reload()


func fire() -> void:
	if current_ammo <= 0:
		fired.emit("empty magazine - press R")
		return

	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)
	_show_fire_effect()

	if targeting == null:
		fired.emit("shot lost in static")
		return

	var result := targeting.get_targeting_result()
	if result.has_valid_part:
		var roll := randf() * 100.0
		var chance: float = result.hit_chance
		var part: BodyPart = result.body_part
		if roll <= chance:
			var dealt := part.apply_damage(damage, damage_type)
			fired.emit("hit %s for %d" % [part.display_name, roundi(dealt)])
		else:
			fired.emit("missed %s" % part.display_name)
		targeting.apply_weapon_lock_penalty(lock_retention_after_shot)
	else:
		fired.emit("untargeted shot")


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
	reload_effect_timer = 0.36
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
	view_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


func _show_fire_effect() -> void:
	fire_effect_timer = 0.08
	if muzzle_flash != null:
		muzzle_flash.rotation_degrees.z = randf_range(-18.0, 18.0)
		muzzle_flash.visible = true
	if muzzle_light != null:
		muzzle_light.visible = true
