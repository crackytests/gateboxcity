extends Node
class_name ToxicRainController

@export var player_health_path: NodePath
@export var hud_path: NodePath
@export var tick_interval := 1.0

var shelter_count := 0
var tick_timer := 0.0
var last_exposure_state := ""
var rain_streaks: GPUParticles3D
var rain_splash: GPUParticles3D

@onready var player_health: PlayerHealth = get_node(player_health_path)
@onready var hud: HUDController = get_node(hud_path)
@onready var player: Node3D = player_health.get_parent() as Node3D


func _ready() -> void:
	add_to_group("toxic_rain_controller")
	_build_rain_effects.call_deferred()


func _process(delta: float) -> void:
	_update_rain_effects()
	if not WorldDirector.is_toxic_rain_active():
		tick_timer = 0.0
		last_exposure_state = ""
		return

	if shelter_count > 0:
		_announce_once("sheltered", "pipe shelter blocks the toxic rain")
		tick_timer = 0.0
		return

	var damage := WorldDirector.get_event_damage_per_second()
	if GameState.has_item("Sealed Mask"):
		_announce_once("sealed", "sealed mask filters the toxic rain")
		return
	if GameState.has_item("Cheap Poncho"):
		damage *= 0.5
		_announce_once("poncho", "cheap poncho softens the toxic rain")
	else:
		_announce_once("exposed", "toxic rain eating through exposed gear")

	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		player_health.apply_damage(damage * tick_interval)


func enter_shelter() -> void:
	shelter_count += 1


func exit_shelter() -> void:
	shelter_count = maxi(shelter_count - 1, 0)


func _announce_once(state: String, message: String) -> void:
	if last_exposure_state == state:
		return
	last_exposure_state = state
	hud.push_log(message)


func _build_rain_effects() -> void:
	var root := get_parent() as Node3D
	if root == null:
		return

	rain_streaks = GPUParticles3D.new()
	rain_streaks.name = "ToxicRainStreaks"
	rain_streaks.amount = 360
	rain_streaks.lifetime = 0.85
	rain_streaks.preprocess = 0.65
	rain_streaks.visibility_aabb = AABB(Vector3(-9.0, -7.0, -9.0), Vector3(18.0, 14.0, 18.0))
	rain_streaks.draw_pass_1 = _make_rain_drop_mesh()
	rain_streaks.process_material = _make_rain_streak_material()
	rain_streaks.emitting = false
	root.add_child(rain_streaks)

	rain_splash = GPUParticles3D.new()
	rain_splash.name = "ToxicRainSplash"
	rain_splash.amount = 140
	rain_splash.lifetime = 0.55
	rain_splash.preprocess = 0.35
	rain_splash.visibility_aabb = AABB(Vector3(-6.0, -2.0, -6.0), Vector3(12.0, 4.0, 12.0))
	rain_splash.draw_pass_1 = _make_splash_mesh()
	rain_splash.process_material = _make_rain_splash_material()
	rain_splash.emitting = false
	root.add_child(rain_splash)


func _update_rain_effects() -> void:
	if rain_streaks == null or rain_splash == null or player == null:
		return

	var exposed := WorldDirector.is_toxic_rain_active() and shelter_count <= 0
	rain_streaks.emitting = exposed
	rain_splash.emitting = exposed
	if not exposed:
		return

	var player_position := player.global_position
	rain_streaks.global_position = player_position + Vector3(0.0, 5.0, 0.0)
	rain_splash.global_position = player_position + Vector3(0.0, 0.18, 0.0)


func _make_rain_drop_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.58)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.22, 1.0, 0.76, 0.72)
	material.emission_enabled = true
	material.emission = Color(0.0, 1.0, 0.52)
	material.emission_energy_multiplier = 1.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	return mesh


func _make_splash_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.16, 0.035)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.08, 0.62, 0.58)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.06, 0.55)
	material.emission_energy_multiplier = 1.15
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	return mesh


func _make_rain_streak_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(6.6, 0.2, 6.6)
	material.direction = Vector3(0.18, -1.0, 0.08)
	material.spread = 4.0
	material.gravity = Vector3(0.0, -18.0, 0.0)
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 13.0
	material.angular_velocity_min = -18.0
	material.angular_velocity_max = 18.0
	material.scale_min = 0.55
	material.scale_max = 1.25
	material.color = Color(0.35, 1.0, 0.72, 0.8)
	return material


func _make_rain_splash_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(5.8, 0.05, 5.8)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 82.0
	material.gravity = Vector3(0.0, -4.0, 0.0)
	material.initial_velocity_min = 0.3
	material.initial_velocity_max = 1.3
	material.scale_min = 0.4
	material.scale_max = 1.35
	material.color = Color(1.0, 0.1, 0.62, 0.62)
	return material
