extends Node3D
class_name HazardCloud

## A lingering damage volume left by a ruptured volatile part (toxic / spore).
## Ticks damage to the player while they stand inside it, then dissipates.
## Spawned by Enemy._spawn_hazard_cloud — no scene file needed.

var radius := 3.0
var dps := 5.0
var duration := 6.0
var color := Color(0.2, 1.0, 0.35)

var _elapsed := 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D


func setup(p_radius: float, p_dps: float, p_duration: float, p_color := Color(0.2, 1.0, 0.35)) -> void:
	radius = p_radius
	dps = p_dps
	duration = p_duration
	color = p_color


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	_mesh.mesh = sphere
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.6
	_mesh.set_surface_override_material(0, _mat)
	add_child(_mesh)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return

	# Pulse + fade out over the final second.
	var pulse := 0.16 + absf(sin(Time.get_ticks_msec() * 0.004)) * 0.10
	var fade := clampf((duration - _elapsed) / 1.0, 0.0, 1.0)
	if _mat != null:
		_mat.albedo_color.a = pulse * fade

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.global_position.distance_to(global_position) <= radius:
		var ph = player.find_child("PlayerHealth", true, false)
		if ph != null:
			ph.apply_damage(dps * delta)
