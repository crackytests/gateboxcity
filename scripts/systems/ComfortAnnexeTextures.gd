extends RefCounted
class_name ComfortAnnexeTextures

const TEX_DIR := "res://assets/textures/comfort_annexe/"

static var _cache: Dictionary = {}


static func apply_reception(root: Node) -> void:
	_apply_to_paths(root, [
		["Floor/MeshInstance3D", "annexe_floor_sterile_tile.png", Vector3(5, 9, 1)],
		["WallWest/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(4, 8, 1)],
		["WallEast/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(4, 8, 1)],
		["WallNorth/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(4, 2, 1)],
		["WallSouth/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(4, 2, 1)],
		["CompanionKiosk/MeshInstance3D", "reception_kiosk_face.png", Vector3.ONE],
		["IntakeTerminal/MeshInstance3D", "reception_kiosk_face.png", Vector3.ONE],
		["SecurityTerminal/MeshInstance3D", "security_terminal_face.png", Vector3.ONE],
		["CheckpointGate/MeshInstance3D", "holding_cage_bars.png", Vector3(3, 1, 1)],
	])


static func apply_ward_floor(root: Node) -> void:
	_apply_to_paths(root, [
		["Floor/MeshInstance3D", "annexe_floor_sterile_tile.png", Vector3(6, 10, 1)],
		["WallWest/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(5, 9, 1)],
		["WallEast/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(5, 9, 1)],
		["WallNorth/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(5, 2, 1)],
		["WallSouth/MeshInstance3D", "annexe_wall_care_panel.png", Vector3(5, 2, 1)],
		["NurseStation", "ward_pod_status_atlas.png", Vector3.ONE],
		["NurseCompanion/MeshInstance3D", "reception_kiosk_face.png", Vector3.ONE],
		["RestrictedTerminal/MeshInstance3D", "security_terminal_face.png", Vector3.ONE],
		["RestrictedDoor/MeshInstance3D", "security_terminal_face.png", Vector3.ONE],
	])
	var pods := root.get_node_or_null("Pods")
	if pods != null:
		for child in pods.get_children():
			_apply_to_mesh(child, "ward_pod_shell.png", Vector3.ONE, "ward_pod_glass.png")
	_apply_to_mesh(root.get_node_or_null("WrongPod/MeshInstance3D"), "ward_pod_shell.png", Vector3.ONE, "ward_pod_glass.png")


static func apply_sublevel(root: Node) -> void:
	_apply_to_paths(root, [
		["Floor/MeshInstance3D", "sublevel_floor_dirty_concrete.png", Vector3(5, 12, 1)],
		["WallWest/MeshInstance3D", "sublevel_wall_service_tile.png", Vector3(4, 10, 1)],
		["WallEast/MeshInstance3D", "sublevel_wall_service_tile.png", Vector3(4, 10, 1)],
		["TransferLog/MeshInstance3D", "experiment_terminal_face.png", Vector3.ONE],
		["ExperimentTerminal", "experiment_terminal_face.png", Vector3.ONE],
		["OverseerTerminal", "experiment_terminal_face.png", Vector3.ONE],
		["OccupiedPod", "ward_pod_shell.png", Vector3.ONE],
		["HoldingCage/MeshInstance3D", "holding_cage_bars.png", Vector3(3, 2, 1)],
	])


static func _apply_to_paths(root: Node, entries: Array) -> void:
	for entry in entries:
		_apply_to_mesh(root.get_node_or_null(str(entry[0])), str(entry[1]), entry[2])


static func _apply_to_mesh(node: Node, texture_name: String, uv_scale: Vector3, emission_texture_name := "") -> void:
	var mesh := node as MeshInstance3D
	if mesh == null:
		return
	var material := mesh.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	var texture := _load_png(texture_name)
	if texture == null:
		return
	var local_material := material.duplicate() as StandardMaterial3D
	local_material.resource_local_to_scene = true
	local_material.albedo_texture = texture
	local_material.uv1_scale = uv_scale
	if not emission_texture_name.is_empty():
		var emission_texture := _load_png(emission_texture_name)
		if emission_texture != null:
			local_material.emission_texture = emission_texture
			local_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mesh.set_surface_override_material(0, local_material)


static func _load_png(texture_name: String) -> Texture2D:
	if _cache.has(texture_name):
		return _cache[texture_name]
	var image := Image.new()
	var result := image.load(TEX_DIR + texture_name)
	if result != OK:
		push_warning("Comfort Annexe texture missing: %s" % texture_name)
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[texture_name] = texture
	return texture
