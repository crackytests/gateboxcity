extends Node3D
class_name LevelDresser

@export_enum("mall", "faded_atrium", "sub_basement", "sub_basement_district", "ward", "transit", "spire", "executive", "core", "linda", "final") var theme := "sub_basement"

const TEX_WET_FLOOR := "res://assets/textures/leak_street/wet_concrete_floor.png"
const TEX_RUST_WALL := "res://assets/textures/leak_street/rusted_metal_wall.png"
const TEX_CORRUGATED := "res://assets/textures/leak_street/corrugated_shack_metal.png"
const TEX_FALSE_SKY := "res://assets/textures/leak_street/false_sky_glass.png"
const TEX_FALSE_SKY_CANOPY_A := "res://assets/textures/leak_street/false_sky_canopy_grid_a.png"
const TEX_FALSE_SKY_CANOPY_B := "res://assets/textures/leak_street/false_sky_canopy_grid_b.png"
const TEX_CABLE_PIPE := "res://assets/textures/leak_street/cable_pipe_strip.png"
const TEX_PATCHWORK := "res://assets/textures/leak_street/patchwork_settlement_atlas.png"
const TEX_SIGNAGE := "res://assets/textures/leak_street/leak_street_signage_atlas.png"
const TEX_COOTERS := "res://assets/textures/leak_street/cooters_facade.png"
const TEX_SUITORS := "res://assets/textures/leak_street/suitors_facade.png"
const TEX_TORAI := "res://assets/textures/leak_street/wan_moa_torai_facade.png"
const TEX_HOODLUM := "res://assets/textures/leak_street/hoodlum_lan_facade.png"
const TEX_PIPE_CHAPEL := "res://assets/textures/leak_street/pipe_chapel_facade.png"
const TEX_PROPS := "res://assets/textures/leak_street/props_atlas.png"
const TEX_HAZARDS := "res://assets/textures/leak_street/hazard_signs_atlas.png"
const SHELTER_ZONE_SCRIPT := preload("res://scripts/systems/ShelterZone.gd")
const LADDER_ZONE_SCRIPT := preload("res://scripts/systems/LadderZone.gd")

var mat_dark: StandardMaterial3D
var mat_rust: StandardMaterial3D
var mat_green: StandardMaterial3D
var mat_magenta: StandardMaterial3D
var mat_cyan: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_gold: StandardMaterial3D
var mat_glass: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_hide_base_geometry_meshes()
	var props := Node3D.new()
	props.name = "RuntimeDressing"
	add_child(props)

	match theme:
		"mall":
			_dress_mall(props)
		"faded_atrium":
			_dress_faded_atrium(props)
		"sub_basement_district":
			_dress_sub_basement_district(props)
		"ward":
			_dress_ward(props)
		"transit":
			_dress_transit(props)
		"spire":
			_dress_spire(props)
		"executive":
			_dress_executive(props)
		"core":
			_dress_core(props)
		"linda":
			_dress_linda(props)
		"final":
			_dress_final(props)
		_:
			_dress_sub_basement(props)


func _build_materials() -> void:
	mat_dark = _mat(Color(0.025, 0.03, 0.032), Color(0.0, 0.08, 0.05), 0.18)
	mat_rust = _mat(Color(0.24, 0.12, 0.055), Color(0.25, 0.07, 0.015), 0.22)
	mat_green = _mat(Color(0.02, 0.18, 0.08), Color(0.0, 1.0, 0.34), 1.8)
	mat_magenta = _mat(Color(0.22, 0.02, 0.16), Color(1.0, 0.04, 0.72), 2.2)
	mat_cyan = _mat(Color(0.02, 0.1, 0.12), Color(0.0, 0.9, 1.0), 1.6)
	mat_white = _mat(Color(0.58, 0.62, 0.58), Color(0.18, 0.26, 0.24), 0.25)
	mat_gold = _mat(Color(0.46, 0.28, 0.08), Color(1.0, 0.55, 0.08), 0.55)
	mat_glass = _mat(Color(0.08, 0.22, 0.26, 0.42), Color(0.0, 0.75, 0.85), 0.7, true)
	_apply_texture(mat_dark, TEX_RUST_WALL, Vector3(1.2, 1.2, 1.0))
	_apply_texture(mat_rust, TEX_CORRUGATED, Vector3(1.4, 1.4, 1.0))
	_apply_texture(mat_white, TEX_WET_FLOOR, Vector3(1.6, 1.6, 1.0))
	_apply_texture(mat_glass, TEX_FALSE_SKY, Vector3(1.0, 1.0, 1.0))


func _hide_base_geometry_meshes() -> void:
	var base_mesh_paths := [
		"../Geometry/NorthWall/MeshInstance3D",
		"../Geometry/SouthWall/MeshInstance3D",
		"../Geometry/EastWall/MeshInstance3D",
		"../Geometry/WestWall/MeshInstance3D",
	]
	for mesh_path in base_mesh_paths:
		var mesh := get_node_or_null(mesh_path) as MeshInstance3D
		if mesh != null:
			mesh.visible = false


func _dress_sub_basement(root: Node3D) -> void:
	for i in range(5):
		_add_pipe(root, "CeilingPipe%d" % i, Vector3(-7.0 + i * 3.4, 2.28 + (i % 2) * 0.25, -7.8), 3.8, 0.08, 90.0, mat_rust)
	for i in range(4):
		_add_box(root, "ScrapStack%d" % i, Vector3(-6.8 + i * 4.2, 0.18, -7.1 + (i % 2) * 1.2), Vector3(0.75, 0.35, 0.55), mat_rust)
		_add_box(root, "NeonTag%d" % i, Vector3(-6.8 + i * 4.2, 0.62, -7.55 + (i % 2) * 1.2), Vector3(0.5, 0.05, 0.08), mat_magenta if i % 2 == 0 else mat_green)
	_add_pipe(root, "FloorDrainLeft", Vector3(-3.7, 0.03, -2.4), 2.6, 0.05, 0.0, mat_dark)
	_add_pipe(root, "FloorDrainRight", Vector3(3.2, 0.03, -2.7), 2.6, 0.05, 0.0, mat_dark)
	_add_light(root, "LeakGlow", Vector3(-5.5, 1.6, -5.9), Color(0.0, 1.0, 0.42), 1.2, 4.2)


func _dress_mall(root: Node3D) -> void:
	for i in range(6):
		var x := -8.4 + i * 3.35
		_add_box(root, "DeadStoreSign%d" % i, Vector3(x, 2.05, -8.75), Vector3(1.0, 0.18, 0.06), mat_magenta if i % 2 == 0 else mat_green)
		_add_box(root, "MallBench%d" % i, Vector3(x, 0.32, 6.2), Vector3(1.0, 0.18, 0.35), mat_rust)
	for i in range(4):
		_add_box(root, "DirectoryShard%d" % i, Vector3(-9.2, 0.95, -6.0 + i * 3.8), Vector3(0.08, 0.8, 0.55), mat_glass)
	_add_light(root, "MuzakGlow", Vector3(0, 2.4, 0), Color(1.0, 0.08, 0.56), 0.9, 8.0)


func _dress_faded_atrium(root: Node3D) -> void:
	for i in range(5):
		var x := -8.0 + i * 4.0
		_add_box(root, "CounterfeitStorefront%d" % i, Vector3(x, 1.25, -8.75), Vector3(1.35, 0.95, 0.05), mat_glass)
		_add_box(root, "DeadEscalatorStep%d" % i, Vector3(-4.0 + i * 1.0, 0.16 + i * 0.08, 1.5 + i * 0.45), Vector3(0.42, 0.08, 0.62), mat_rust)
	for i in range(4):
		_add_box(root, "FalseSkylightPanel%d" % i, Vector3(-6.0 + i * 4.0, 3.05, -1.0), Vector3(1.2, 0.04, 0.8), mat_cyan)
	_add_light(root, "AtriumFalseSkyGlow", Vector3(0.0, 2.7, -1.0), Color(0.32, 0.95, 0.82), 0.8, 9.0)


func _dress_sub_basement_district(root: Node3D) -> void:
	_add_arcade_floor(root)
	_add_arcade_storefront_walls(root)
	_add_arcade_canopy(root)
	_add_arcade_facades(root)
	_add_arcade_signs(root)
	_add_arcade_catwalk(root)
	_add_arcade_depth_silhouettes(root)
	_add_generator_streetlights(root)
	_add_arcade_lighting(root)


func _add_arcade_floor(root: Node3D) -> void:
	for x_i in range(4):
		for z_i in range(12):
			var x := -5.25 + x_i * 3.5
			var z := -21.0 + z_i * 3.8
			_add_floor_panel(root, "ArcadeFloorTile%d_%d" % [x_i, z_i], Vector3(x, 0.032, z), Vector2(3.42, 3.72), 90.0 * float((x_i + z_i) % 4), TEX_WET_FLOOR)
	for side in [-1, 1]:
		for z_i in range(12):
			var z := -21.0 + z_i * 3.8
			_add_floor_panel(root, "ArcadeSideWalk%d_%d" % [side, z_i], Vector3(8.3 * side, 0.034, z), Vector2(2.55, 3.72), 90.0 * float((z_i + side) % 4), TEX_WET_FLOOR)
	for z in [-15.5, -3.5, 10.5]:
		for i in range(3):
			_add_floor_panel(root, "AlleyMouthFloor%.1f_%d" % [z, i], Vector3(12.3 + i * 3.1, 0.036, z), Vector2(3.0, 3.1), 90.0 * float(i % 2), TEX_WET_FLOOR)
			_add_floor_panel(root, "AlleyMouthFloorWest%.1f_%d" % [z, i], Vector3(-12.3 - i * 3.1, 0.036, z + 5.0), Vector2(3.0, 3.1), 90.0 * float((i + 1) % 2), TEX_WET_FLOOR)


func _add_arcade_storefront_walls(root: Node3D) -> void:
	var bays := [
		{"z": -18.0, "texture": TEX_CORRUGATED},
		{"z": -13.4, "texture": TEX_RUST_WALL},
		{"z": -8.8, "texture": TEX_CORRUGATED},
		{"z": -4.2, "texture": TEX_RUST_WALL},
		{"z": 0.4, "texture": TEX_CORRUGATED},
		{"z": 5.0, "texture": TEX_RUST_WALL},
		{"z": 9.6, "texture": TEX_CORRUGATED},
		{"z": 14.2, "texture": TEX_RUST_WALL},
		{"z": 18.8, "texture": TEX_CORRUGATED},
	]
	for i in range(bays.size()):
		var z := float(bays[i]["z"])
		var texture := str(bays[i]["texture"])
		_add_textured_panel(root, "EastStorefrontWall%d" % i, Vector3(10.62, 1.78, z), Vector2(4.35, 3.55), -90.0, texture)
		_add_textured_panel(root, "WestStorefrontWall%d" % i, Vector3(-10.62, 1.78, z), Vector2(4.35, 3.55), 90.0, texture)
		_add_invisible_solid_box(root, "EastStorefrontBlocker%d" % i, Vector3(10.86, 1.45, z), Vector3(0.28, 1.45, 2.15))
		_add_invisible_solid_box(root, "WestStorefrontBlocker%d" % i, Vector3(-10.86, 1.45, z), Vector3(0.28, 1.45, 2.15))
	for z in [-19.2, 19.2]:
		for x_i in range(6):
			var x := -8.75 + x_i * 3.5
			var texture := TEX_RUST_WALL if x_i % 2 == 0 else TEX_CORRUGATED
			_add_textured_panel(root, "ArcadeEndWall%d_%d" % [int(z), x_i], Vector3(x, 1.8, z), Vector2(3.42, 3.55), 0.0 if z < 0.0 else 180.0, texture)
		_add_invisible_solid_box(root, "ArcadeEndBlocker%d" % int(z), Vector3(0.0, 1.45, z), Vector3(10.1, 1.45, 0.18))


func _add_arcade_canopy(root: Node3D) -> void:
	_add_high_false_sky(root)
	_add_street_fixtures(root)
	_add_canopy_vertical_elements(root)


func _add_high_false_sky(root: Node3D) -> void:
	var sky_group := Node3D.new()
	sky_group.name = "HighFalseSky"
	root.add_child(sky_group)

	for i in range(7):
		var z := -24.0 + i * 8.5
		var offset_x := 0.4 * float(i % 3 - 1)
		var height := 11.0 + 2.5 * sin(float(i) * 1.1)
		var yaw_nudge := 0.6 * float((i * 3) % 5 - 2)
		var canopy_texture := TEX_FALSE_SKY_CANOPY_A if i % 2 == 0 else TEX_FALSE_SKY_CANOPY_B
		var panel := _add_sky_panel(sky_group, "HighSkyPanel%d" % i, Vector3(offset_x, height, z), Vector2(22.0, 9.5), yaw_nudge, canopy_texture)
		panel.add_to_group("district_canopy_panel")

	for side_val in [-1, 1]:
		var side: float = float(side_val)
		for i in range(4):
			var z := -22.0 + i * 12.0
			var x := 18.0 * side
			var height := 10.5 + 1.8 * sin(float(i) * 1.7 + side)
			var yaw := -90.0 * side + 0.3 * float(i % 3)
			var canopy_texture := TEX_FALSE_SKY_CANOPY_B if int(i + side) % 2 == 0 else TEX_FALSE_SKY_CANOPY_A
			var panel := _add_sky_panel(sky_group, "HighSkySide_%d_%d" % [side, i], Vector3(x, height, z), Vector2(12.0, 9.0), yaw, canopy_texture)
			panel.add_to_group("district_canopy_panel")

	for i in range(5):
		var z := -24.0 + i * 12.0
		var height := 12.5 + 1.2 * float(i % 3)
		_add_sky_underside_glow(sky_group, "SkyGlow%d" % i, Vector3(0.0, height - 0.5, z), Color(0.0, 0.72, 0.82), 2.8)

	for i in range(4):
		var z := -18.0 + i * 14.0
		_add_seam(sky_group, "SkySeam%d" % i, Vector3(0.0, 10.2 + float(i % 2) * 1.5, z), 18.0)


func _add_street_fixtures(root: Node3D) -> void:
	var fixtures := Node3D.new()
	fixtures.name = "StreetFixtures"
	root.add_child(fixtures)

	for side in [-1, 1]:
		_add_pipe(fixtures, "HangingCableBundle%d" % side, Vector3(8.5 * side, 4.2, -2.0), 18.0, 0.04, 0.0, mat_dark)


func _add_arcade_catwalk(root: Node3D) -> void:
	var catwalk := Node3D.new()
	catwalk.name = "CatwalkNetwork"
	root.add_child(catwalk)

	_add_catwalk_spines(catwalk)
	_add_catwalk_crossings(catwalk)
	_add_catwalk_collision_deck(catwalk)
	_add_catwalk_access(catwalk)
	_add_catwalk_cover(catwalk)
	_add_catwalk_lights(catwalk)


func _add_catwalk_spines(group: Node3D) -> void:
	for side_val in [-1, 1]:
		var sx: float = float(side_val)
		var x := 3.8 * sx
		_add_box(group, "SpineWalk_%d_a" % side_val, Vector3(x, 3.0, -17.5), Vector3(1.35, 0.06, 3.0), mat_dark)
		_add_box(group, "SpineWalk_%d_b" % side_val, Vector3(x, 3.0, -7.0), Vector3(1.35, 0.06, 3.8), mat_dark)
		_add_box(group, "SpineWalk_%d_c" % side_val, Vector3(x, 3.0, 3.0), Vector3(1.35, 0.06, 3.8), mat_dark)
		_add_box(group, "SpineWalk_%d_d" % side_val, Vector3(x, 3.0, 12.0), Vector3(1.35, 0.06, 2.8), mat_dark)
		_add_box(group, "SpineWalk_%d_e" % side_val, Vector3(x, 3.0, 18.0), Vector3(1.35, 0.06, 2.0), mat_dark)
		_add_solid_box(group, "NorthEndCap_%d" % side_val, Vector3(x, 3.0, -19.0), Vector3(1.35, 0.06, 0.55), mat_dark)
		_add_solid_box(group, "SouthEndCap_%d" % side_val, Vector3(x, 3.0, 19.0), Vector3(1.35, 0.06, 0.55), mat_dark)
		_add_solid_box(group, "SpineRail_%d_inner" % side_val, Vector3(x - 0.55 * sx, 3.28, 0.0), Vector3(0.04, 0.42, 32.0), mat_rust)
		_add_solid_box(group, "SpineRail_%d_outer_north_a" % side_val, Vector3(x + 0.55 * sx, 3.28, -11.0), Vector3(0.04, 0.42, 10.0), mat_rust)
		_add_solid_box(group, "SpineRail_%d_outer_north_b" % side_val, Vector3(x + 0.55 * sx, 3.28, -2.0), Vector3(0.04, 0.42, 4.0), mat_rust)
		_add_solid_box(group, "SpineRail_%d_outer_mid_a" % side_val, Vector3(x + 0.55 * sx, 3.28, 1.5), Vector3(0.04, 0.42, 3.5), mat_rust)
		_add_solid_box(group, "SpineRail_%d_outer_mid_b" % side_val, Vector3(x + 0.55 * sx, 3.28, 10.0), Vector3(0.04, 0.42, 5.0), mat_rust)
		_add_solid_box(group, "SpineRail_%d_outer_south" % side_val, Vector3(x + 0.55 * sx, 3.28, 18.0), Vector3(0.04, 0.42, 3.0), mat_rust)


func _add_catwalk_crossings(group: Node3D) -> void:
	var crossings := [
		{"z": -12.0, "x_west": -3.8, "x_east": 3.8},
		{"z": -2.0, "x_west": -3.8, "x_east": 3.8},
		{"z": 8.0, "x_west": -3.8, "x_east": 3.8},
		{"z": 16.0, "x_west": -3.8, "x_east": 3.8},
	]
	for i in range(crossings.size()):
		var c: Dictionary = crossings[i]
		var z: float = float(c["z"])
		var x_w: float = float(c["x_west"])
		var x_e: float = float(c["x_east"])
		var span := x_e - x_w
		var cx := (x_w + x_e) * 0.5
		_add_box(group, "CrossBridge%d" % i, Vector3(cx, 3.0, z), Vector3(2.35, 0.06, 1.0), mat_dark)
		_add_box(group, "CrossBridgeWestWing%d" % i, Vector3(-2.025, 3.0, z), Vector3(0.425, 0.06, 1.0), mat_dark)
		_add_box(group, "CrossBridgeEastWing%d" % i, Vector3(2.025, 3.0, z), Vector3(0.425, 0.06, 1.0), mat_dark)
		_add_solid_box(group, "CrossRailN%d" % i, Vector3(cx, 3.28, z + 0.55), Vector3(absf(span), 0.36, 0.04), mat_rust)
		_add_solid_box(group, "CrossRailS%d" % i, Vector3(cx, 3.28, z - 0.55), Vector3(absf(span), 0.36, 0.04), mat_rust)


func _add_catwalk_collision_deck(group: Node3D) -> void:
	const SMOOTH_DECK_Y := 3.95
	for side_val in [-1, 1]:
		var sx: float = float(side_val)
		_add_invisible_solid_box(group, "SmoothSpineDeck_%d" % side_val, Vector3(3.8 * sx, SMOOTH_DECK_Y, 0.0), Vector3(1.75, 0.12, 38.0))
	var crossings := [-12.0, -2.0, 8.0, 16.0]
	for i in range(crossings.size()):
		_add_invisible_solid_box(group, "SmoothCrossDeck%d" % i, Vector3(0.0, SMOOTH_DECK_Y, crossings[i]), Vector3(8.1, 0.12, 1.55))


func _add_catwalk_access(group: Node3D) -> void:
	var ladders := [
		{"x": -5.35, "z": -16.0, "side": -1},
		{"x": -5.35, "z": 5.0, "side": -1},
		{"x": -5.35, "z": 14.0, "side": -1},
		{"x": 5.35, "z": -16.0, "side": 1},
		{"x": 5.35, "z": 5.0, "side": 1},
		{"x": 5.35, "z": 14.0, "side": 1},
	]
	for i in range(ladders.size()):
		var lx: float = float(ladders[i]["x"])
		var lz: float = float(ladders[i]["z"])
		var side: float = float(ladders[i]["side"])
		_add_solid_box(group, "LadderFrame%d" % i, Vector3(lx, 1.75, lz), Vector3(0.12, 3.0, 0.5), mat_rust)
		_add_solid_box(group, "LadderRail%d_a" % i, Vector3(lx, 1.75, lz - 0.22), Vector3(0.05, 3.0, 0.05), mat_dark)
		_add_solid_box(group, "LadderRail%d_b" % i, Vector3(lx, 1.75, lz + 0.22), Vector3(0.05, 3.0, 0.05), mat_dark)
		for rung in range(8):
			var ry := 0.45 + rung * 0.35
			_add_solid_box(group, "Ladder%d_Rung%d" % [i, rung], Vector3(lx, ry, lz), Vector3(0.1, 0.04, 0.4), mat_rust)
		_add_ladder_zone(group, "LadderZone%d" % i, Vector3(lx - side * 0.5, 2.35, lz), Vector3(1.8, 5.1, 1.45))


func _add_catwalk_cover(group: Node3D) -> void:
	var covers := [
		{"x": -3.8, "z": -8.0, "w": 1.8, "d": 16.0},
		{"x": -3.8, "z": 8.0, "w": 1.8, "d": 16.0},
		{"x": 3.8, "z": -8.0, "w": 1.8, "d": 16.0},
		{"x": 3.8, "z": 8.0, "w": 1.8, "d": 16.0},
		{"x": 0.0, "z": -12.0, "w": 8.4, "d": 2.4},
		{"x": 0.0, "z": -2.0, "w": 8.4, "d": 2.4},
		{"x": 0.0, "z": 8.0, "w": 8.4, "d": 2.4},
		{"x": 0.0, "z": 16.0, "w": 8.4, "d": 2.4},
		{"x": -6.5, "z": 12.0, "w": 4.0, "d": 3.6},
		{"x": 0.0, "z": 2.5, "w": 4.8, "d": 4.2},
		{"x": 6.5, "z": 8.5, "w": 4.0, "d": 4.2},
		{"x": -3.8, "z": 19.3, "w": 1.8, "d": 4.5},
		{"x": 3.8, "z": 19.3, "w": 1.8, "d": 4.5},
	]
	for i in range(covers.size()):
		var cx: float = float(covers[i]["x"])
		var cz: float = float(covers[i]["z"])
		var cw: float = float(covers[i]["w"])
		var cd: float = float(covers[i]["d"])
		_add_ceiling_panel(group, "CatwalkCover%d" % i, Vector3(cx, 3.48, cz), Vector2(cw, cd), 0.0, TEX_CORRUGATED)
		_add_box(group, "CoverBeam%d_a" % i, Vector3(cx - cw * 0.45, 3.38, cz), Vector3(0.06, 0.06, cd * 0.48), mat_rust)
		_add_box(group, "CoverBeam%d_b" % i, Vector3(cx + cw * 0.45, 3.38, cz), Vector3(0.06, 0.06, cd * 0.48), mat_rust)
		_add_shelter_zone(group, "CatwalkShelter%d" % i, Vector3(cx, 1.8, cz), Vector3(cw, 3.2, cd))


func _add_catwalk_lights(group: Node3D) -> void:
	var catwalk_lights := [
		{"pos": Vector3(-3.8, 2.85, -10.0), "color": Color(0.1, 1.0, 0.72), "energy": 1.0},
		{"pos": Vector3(3.8, 2.85, -4.0), "color": Color(1.0, 0.12, 0.72), "energy": 0.9},
		{"pos": Vector3(-3.8, 2.85, 5.0), "color": Color(0.05, 0.85, 1.0), "energy": 1.0},
		{"pos": Vector3(3.8, 2.85, 12.0), "color": Color(0.7, 1.0, 0.15), "energy": 0.85},
		{"pos": Vector3(0.0, 2.85, -12.0), "color": Color(0.0, 0.9, 0.95), "energy": 0.8},
		{"pos": Vector3(0.0, 2.85, -2.0), "color": Color(1.0, 0.55, 0.12), "energy": 0.8},
		{"pos": Vector3(0.0, 2.85, 8.0), "color": Color(0.0, 0.9, 0.95), "energy": 0.8},
	]
	for cl in catwalk_lights:
		var cl_pos: Vector3 = cl["pos"]
		var cl_color: Color = cl["color"]
		var cl_energy: float = float(cl["energy"])
		_add_light(group, "CatwalkLight_%.0f_%.0f" % [cl_pos.x, cl_pos.z], cl_pos, cl_color, cl_energy, 5.5)
		_add_box(group, "CatlightFixture_%.0f_%.0f" % [cl_pos.x, cl_pos.z], Vector3(cl_pos.x, cl_pos.y + 0.12, cl_pos.z), Vector3(0.25, 0.04, 0.12), mat_rust)
		_add_pipe(group, "CatlightDrop_%.0f_%.0f" % [cl_pos.x, cl_pos.z], Vector3(cl_pos.x, cl_pos.y + 0.3, cl_pos.z), 0.25, 0.015, 0.0, mat_dark)


func _add_canopy_vertical_elements(root: Node3D) -> void:
	var pylons := Node3D.new()
	pylons.name = "CanopyVerticals"
	root.add_child(pylons)

	for side_val in [-1, 1]:
		var side: float = float(side_val)
		for i in range(3):
			var z := -14.0 + i * 14.0
			var x := 11.5 * side
			_add_solid_box(pylons, "SupportPylon_%d_%d" % [side, i], Vector3(x, 5.5, z), Vector3(0.28, 11.0, 0.28), mat_dark)
			_add_box(pylons, "PylonCap_%d_%d" % [side, i], Vector3(x, 11.0, z), Vector3(0.55, 0.08, 0.55), mat_cyan if i % 2 == 0 else mat_magenta)
			_add_pipe(pylons, "PylonCable_%d_%d" % [side, i], Vector3(x - side * 0.2, 7.5, z + 0.15), 8.0, 0.035, 90.0, mat_rust)


func _add_sky_panel(root: Node3D, node_name: String, local_position: Vector3, size: Vector2, yaw_degrees: float, texture_path: String) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.position = local_position
	item.rotation_degrees = Vector3(90.0, yaw_degrees, 0.0)
	var material := StandardMaterial3D.new()
	var texture := _texture_from_path(texture_path)
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 0.96, 0.78, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.emission_enabled = true
	material.emission = Color(0.86, 0.62, 0.24)
	material.emission_energy_multiplier = 0.42
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.84
	item.set_surface_override_material(0, material)
	item.add_to_group("district_texture_panel")
	root.add_child(item)
	return item


func _add_sky_underside_glow(root: Node3D, node_name: String, local_position: Vector3, color: Color, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = local_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 22.0
	light.add_to_group("district_canopy_light")
	light.set_meta("base_energy", energy)
	light.set_meta("base_color", color)
	root.add_child(light)
	return light


func _add_seam(root: Node3D, node_name: String, local_position: Vector3, length: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.position = local_position
	item.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	item.scale = Vector3(0.025, 0.025, length * 0.5)
	item.set_surface_override_material(0, mat_dark)
	root.add_child(item)
	return item


func _add_arcade_facades(root: Node3D) -> void:
	const FACADE_SIZE := Vector2(7.4, 7.4)
	const FACADE_CENTER_Y := 2.95
	_add_textured_panel(root, "CootersFacadeArt", Vector3(10.42, FACADE_CENTER_Y, -10.5), FACADE_SIZE, -90.0, TEX_COOTERS)
	_add_textured_panel(root, "ToraiFacadeArt", Vector3(10.42, FACADE_CENTER_Y, 8.5), FACADE_SIZE, -90.0, TEX_TORAI)
	_add_textured_panel(root, "SuitorsFacadeArt", Vector3(-10.42, FACADE_CENTER_Y, -1.0), FACADE_SIZE, 90.0, TEX_SUITORS)
	_add_textured_panel(root, "HoodlumLanFacadeArt", Vector3(-10.42, FACADE_CENTER_Y, -13.8), FACADE_SIZE, 90.0, TEX_HOODLUM)
	_add_textured_panel(root, "PipeChapelFacadeArt", Vector3(-10.42, FACADE_CENTER_Y, 12.2), FACADE_SIZE, 90.0, TEX_PIPE_CHAPEL)
	_add_textured_panel(root, "SystemXFacadePanel", Vector3(10.42, 2.25, 16.0), Vector2(4.5, 3.1), -90.0, TEX_RUST_WALL)
	_add_box(root, "GeneratorPedestal", Vector3(0.0, 0.28, 2.5), Vector3(1.5, 0.28, 1.5), mat_dark)
	_add_box(root, "GeneratorCoreGlow", Vector3(0.0, 1.0, 2.5), Vector3(0.34, 0.72, 0.34), mat_cyan)


func _add_arcade_signs(root: Node3D) -> void:
	_add_atlas_panel(root, "LeakStreetOverheadSign", Vector3(0.0, 3.05, -17.85), Vector2(4.7, 0.56), 0.0, TEX_SIGNAGE, Rect2(150, 30, 1180, 215), Color(0.0, 1.0, 1.0), 0.5)
	_add_atlas_panel(root, "CootersBladeSign", Vector3(9.95, 3.42, -10.6), Vector2(2.05, 0.45), -90.0, TEX_SIGNAGE, Rect2(45, 285, 590, 205), Color(1.0, 0.05, 0.7), 0.5)
	_add_atlas_panel(root, "SuitorsSmallSign", Vector3(-9.95, 3.35, -1.0), Vector2(1.95, 0.45), 90.0, TEX_SIGNAGE, Rect2(630, 265, 620, 240), Color(1.0, 0.05, 0.9), 0.45)
	_add_atlas_panel(root, "ToraiOfficeSign", Vector3(9.95, 3.35, 8.5), Vector2(2.15, 0.42), -90.0, TEX_SIGNAGE, Rect2(20, 555, 615, 220), Color(0.8, 1.0, 0.1), 0.42)
	_add_atlas_panel(root, "HoodlumLanSign", Vector3(-9.95, 3.35, -13.8), Vector2(2.0, 0.42), 90.0, TEX_SIGNAGE, Rect2(33, 761, 590, 250), Color(1.0, 0.08, 0.75), 0.44)
	_add_atlas_panel(root, "SystemXSign", Vector3(9.95, 2.95, 16.0), Vector2(1.8, 0.44), -90.0, TEX_SIGNAGE, Rect2(630, 525, 620, 220), Color(0.0, 0.9, 1.0), 0.42)
	_add_atlas_panel(root, "PipeChapelSign", Vector3(-9.95, 3.35, 12.2), Vector2(2.05, 0.44), 90.0, TEX_SIGNAGE, Rect2(670, 760, 650, 220), Color(0.0, 0.9, 1.0), 0.4)
	_add_atlas_panel(root, "RainShelterSignA", Vector3(-3.0, 2.35, 5.2), Vector2(1.35, 0.4), 180.0, TEX_HAZARDS, Rect2(650, 30, 620, 290), Color(0.65, 1.0, 0.15), 0.28)
	_add_atlas_panel(root, "ToxicRainWallSign", Vector3(10.0, 2.0, -4.0), Vector2(0.7, 1.2), -90.0, TEX_HAZARDS, Rect2(10, 10, 260, 550), Color(0.0, 0.9, 1.0), 0.18)
	_add_atlas_panel(root, "GridSagWarningSign", Vector3(-10.0, 2.0, 6.0), Vector2(1.25, 0.5), 90.0, TEX_HAZARDS, Rect2(270, 320, 420, 245), Color(1.0, 0.62, 0.04), 0.2)
	_add_atlas_panel(root, "MaskRequiredSign", Vector3(-10.0, 2.0, -5.5), Vector2(1.35, 0.5), 90.0, TEX_HAZARDS, Rect2(20, 800, 660, 270), Color(1.0, 0.05, 0.7), 0.2)
	_add_atlas_panel(root, "PropsVendingPanel", Vector3(10.0, 1.35, 13.6), Vector2(0.9, 1.25), -90.0, TEX_PROPS, Rect2(930, 20, 300, 452), Color(1.0, 0.05, 0.65), 0.2)
	_add_atlas_panel(root, "PropsServerRackA", Vector3(-10.0, 1.45, -16.0), Vector2(0.72, 1.35), 90.0, TEX_PROPS, Rect2(450, 10, 315, 455), Color(0.0, 0.8, 1.0), 0.16)


func _add_arcade_depth_silhouettes(root: Node3D) -> void:
	for side in [-1, 1]:
		for i in range(4):
			var z: float = -15.5 + float(i) * 10.0
			var x: float = 15.0 * float(side)
			for j in range(2):
				var panel_z := z - 1.32 + float(j) * 2.64
				_add_textured_panel(root, "AlleyDeepWall%d_%d_%d" % [side, i, j], Vector3(x, 1.55, panel_z), Vector2(2.55, 3.0), -90.0 if side > 0 else 90.0, TEX_RUST_WALL if (i + j) % 2 == 0 else TEX_CORRUGATED)
			_add_box(root, "AlleyGlow%d_%d" % [side, i], Vector3(x - side * 0.08, 1.8, z + 1.6), Vector3(0.04, 0.12, 0.75), mat_cyan if i % 2 == 0 else mat_magenta)
	for z in [-18.5, 18.5]:
		for x_i in range(4):
			var x := -5.85 + x_i * 3.9
			_add_textured_panel(root, "FarArcadeContinuation%.1f_%d" % [z, x_i], Vector3(x, 1.6, z), Vector2(3.75, 2.9), 0.0 if z < 0.0 else 180.0, TEX_RUST_WALL if x_i % 2 == 0 else TEX_CORRUGATED)


func _add_arcade_lighting(root: Node3D) -> void:
	_add_light(root, "DistrictTextureWash", Vector3(0.0, 2.2, 0.0), Color(0.36, 0.54, 0.48), 0.22, 15.5)
	_add_light(root, "ArcadeCanopyGlow", Vector3(0.0, 3.0, -2.0), Color(0.0, 0.9, 0.95), 0.55, 17.0)
	_add_light(root, "CootersPinkWash", Vector3(7.6, 1.85, -10.5), Color(1.0, 0.08, 0.72), 0.42, 5.8)
	_add_light(root, "LANFlickerGlow", Vector3(-7.6, 1.9, -13.8), Color(0.08, 1.0, 0.5), 0.38, 6.2)


func _add_generator_streetlights(root: Node3D) -> void:
	var fixtures := [
		{"name": "StreetlightA", "pos": Vector3(-3.4, 2.75, -16.0), "color": Color(0.1, 1.0, 0.72), "phase": 0},
		{"name": "StreetlightB", "pos": Vector3(3.4, 2.75, -11.0), "color": Color(1.0, 0.12, 0.72), "phase": 1},
		{"name": "StreetlightC", "pos": Vector3(-3.4, 2.75, -5.0), "color": Color(0.05, 0.85, 1.0), "phase": 2},
		{"name": "StreetlightD", "pos": Vector3(3.4, 2.75, 1.0), "color": Color(0.7, 1.0, 0.15), "phase": 3},
		{"name": "StreetlightE", "pos": Vector3(-3.4, 2.75, 7.0), "color": Color(1.0, 0.12, 0.72), "phase": 4},
		{"name": "StreetlightF", "pos": Vector3(3.4, 2.75, 13.5), "color": Color(0.05, 0.85, 1.0), "phase": 5},
	]
	for fixture in fixtures:
		var fixture_position: Vector3 = fixture["pos"]
		var fixture_color: Color = fixture["color"]
		_add_hanging_streetlight(root, str(fixture["name"]), fixture_position, fixture_color, int(fixture["phase"]))


func _add_hanging_streetlight(root: Node3D, node_name: String, local_position: Vector3, color: Color, phase: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = local_position
	holder.add_to_group("generator_streetlight")
	holder.set_meta("phase", phase)
	holder.set_meta("base_color", color)
	root.add_child(holder)

	_add_box(holder, "DropCable", Vector3(0.0, 0.28, 0.0), Vector3(0.03, 0.32, 0.03), mat_dark)
	_add_box(holder, "Housing", Vector3(0.0, -0.04, 0.0), Vector3(0.55, 0.08, 0.18), mat_rust)
	var bulb_mat := _mat(Color(color.r * 0.55, color.g * 0.55, color.b * 0.55), color, 1.4)
	bulb_mat.resource_local_to_scene = true
	var bulb := _add_box(holder, "Bulb", Vector3(0.0, -0.13, 0.0), Vector3(0.44, 0.035, 0.08), bulb_mat)
	bulb.add_to_group("generator_streetlight_bulb")
	var light := OmniLight3D.new()
	light.name = "LampOmni"
	light.position = Vector3(0.0, -0.22, 0.0)
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 5.2
	holder.add_child(light)
	return holder


func _dress_ward(root: Node3D) -> void:
	for i in range(4):
		var x := -6.2 + i * 4.1
		_add_box(root, "SleepPodShell%d" % i, Vector3(x, 0.58, -5.9), Vector3(1.15, 0.38, 0.72), mat_white)
		_add_box(root, "SleepPodGlass%d" % i, Vector3(x, 0.78, -5.25), Vector3(0.95, 0.18, 0.06), mat_glass)
		_add_pipe(root, "IVRail%d" % i, Vector3(x, 1.55, -5.55), 1.2, 0.035, 90.0, mat_cyan)
	for i in range(3):
		_add_box(root, "CarePanel%d" % i, Vector3(-7.5 + i * 7.5, 1.6, 7.85), Vector3(0.9, 0.55, 0.06), mat_green)
	_add_light(root, "WardPulse", Vector3(0.0, 2.0, -4.8), Color(0.55, 1.0, 0.86), 1.0, 7.5)


func _dress_transit(root: Node3D) -> void:
	for i in range(2):
		_add_pipe(root, "Rail%dA" % i, Vector3(-1.15 + i * 2.3, 0.06, 0.2), 16.0, 0.045, 0.0, mat_cyan)
		_add_pipe(root, "Rail%dB" % i, Vector3(-1.15 + i * 2.3, 0.08, 0.2), 16.0, 0.025, 0.0, mat_dark)
	for i in range(5):
		_add_box(root, "PlatformStripe%d" % i, Vector3(-7.2 + i * 3.6, 0.035, -3.1), Vector3(0.8, 0.035, 0.12), mat_magenta)
		_add_box(root, "AdPanel%d" % i, Vector3(-7.5 + i * 3.7, 1.65, 8.9), Vector3(0.8, 0.65, 0.05), mat_green if i % 2 == 0 else mat_magenta)
	_add_light(root, "TransitLineGlow", Vector3(0, 1.6, 0.0), Color(0.0, 0.75, 1.0), 1.0, 9.0)


func _dress_spire(root: Node3D) -> void:
	for i in range(5):
		var x := -6.5 + i * 3.25
		_add_box(root, "QueuePost%d" % i, Vector3(x, 0.65, -2.8), Vector3(0.08, 0.65, 0.08), mat_gold)
		_add_box(root, "HoloRope%d" % i, Vector3(x + 1.5, 0.92, -2.8), Vector3(1.25, 0.04, 0.035), mat_cyan)
	for i in range(4):
		_add_box(root, "CompliancePanel%d" % i, Vector3(-8.8, 1.55, -6.0 + i * 3.3), Vector3(0.05, 0.6, 0.9), mat_green)
	_add_light(root, "ReceptionWash", Vector3(-4.8, 2.2, -5.1), Color(0.0, 0.9, 1.0), 1.1, 7.0)


func _dress_executive(root: Node3D) -> void:
	for i in range(4):
		_add_box(root, "FilingObelisk%d" % i, Vector3(-7.5 + i * 5.0, 0.8, 6.9), Vector3(0.45, 0.8, 0.45), mat_dark)
		_add_box(root, "GoldTrim%d" % i, Vector3(-7.5 + i * 5.0, 1.55, 6.9), Vector3(0.52, 0.08, 0.52), mat_gold)
	for i in range(3):
		_add_box(root, "ExecutiveScreen%d" % i, Vector3(-6.5 + i * 6.5, 1.75, -8.7), Vector3(1.15, 0.65, 0.05), mat_magenta)
	_add_light(root, "SuitePaperGlow", Vector3(0, 2.2, -5.7), Color(1.0, 0.16, 0.7), 1.0, 8.0)


func _dress_core(root: Node3D) -> void:
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var pos := Vector3(cos(angle) * 4.2, 0.95, -1.0 + sin(angle) * 4.2)
		_add_box(root, "MemoryStack%d" % i, pos, Vector3(0.38, 0.95, 0.38), mat_cyan if i % 2 == 0 else mat_dark)
		_add_pipe(root, "CoreCable%d" % i, Vector3(pos.x * 0.5, 0.08, pos.z * 0.5), 2.8, 0.035, rad_to_deg(angle), mat_magenta)
	_add_light(root, "KernelMist", Vector3(0, 2.1, -2.0), Color(0.0, 1.0, 0.78), 1.3, 8.0)


func _dress_linda(root: Node3D) -> void:
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		_add_box(root, "MandatePillar%d" % i, Vector3(cos(angle) * 6.5, 1.2, -1.5 + sin(angle) * 4.0), Vector3(0.32, 1.2, 0.32), mat_gold)
		_add_box(root, "LindaRibbon%d" % i, Vector3(cos(angle) * 5.2, 2.25, -1.5 + sin(angle) * 3.2), Vector3(0.75, 0.06, 0.06), mat_magenta)
	for i in range(3):
		_add_box(root, "CareLawPanel%d" % i, Vector3(-7.5 + i * 7.5, 1.8, 8.75), Vector3(1.0, 0.7, 0.05), mat_green)
	_add_light(root, "LindaHalo", Vector3(0, 2.6, -5.8), Color(1.0, 0.12, 0.68), 1.4, 9.0)


func _dress_final(root: Node3D) -> void:
	for i in range(7):
		var x := -7.2 + i * 2.4
		_add_box(root, "PatchRib%d" % i, Vector3(x, 1.2, -7.7), Vector3(0.08, 1.2, 0.26), mat_white if i % 2 == 0 else mat_dark)
		_add_box(root, "RuptureGlyph%d" % i, Vector3(x, 0.08, -3.0 + (i % 3) * 2.1), Vector3(0.7, 0.04, 0.08), mat_magenta)
	for i in range(4):
		_add_pipe(root, "CareLoopConduit%d" % i, Vector3(-5.0 + i * 3.4, 0.06, 5.6), 3.0, 0.05, 90.0, mat_cyan)
	_add_light(root, "FinalWarning", Vector3(0, 2.2, -5.8), Color(1.0, 0.08, 0.14), 1.2, 8.5)


func _mat(albedo: Color, emission: Color, energy: float, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.84
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _texture_from_path(texture_path: String) -> Texture2D:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


func _apply_texture(material: StandardMaterial3D, texture_path: String, uv_scale := Vector3.ONE) -> void:
	var texture := _texture_from_path(texture_path)
	if texture == null:
		return
	material.albedo_color = Color(0.78, 0.82, 0.78, material.albedo_color.a)
	material.albedo_texture = texture
	material.uv1_scale = uv_scale


func _textured_mat(texture_path: String, emission := Color.BLACK, energy := 0.0, transparent := false) -> StandardMaterial3D:
	var material := _mat(Color.WHITE, emission, energy, transparent)
	var texture := _texture_from_path(texture_path)
	return _configure_textured_mat(material, texture)


func _textured_mat_from_texture(texture: Texture2D, emission := Color.BLACK, energy := 0.0, transparent := false) -> StandardMaterial3D:
	var material := _mat(Color.WHITE, emission, energy, transparent)
	return _configure_textured_mat(material, texture)


func _configure_textured_mat(material: StandardMaterial3D, texture: Texture2D) -> StandardMaterial3D:
	material.albedo_texture = texture
	material.albedo_color = Color(0.62, 0.68, 0.64, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.emission_enabled = true
	material.emission = Color(0.08, 0.11, 0.095)
	material.emission_energy_multiplier = 0.08
	if texture != null:
		material.emission_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _atlas_texture(texture_path: String, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture_from_path(texture_path)
	atlas.region = region
	return atlas


func _add_textured_panel(root: Node3D, node_name: String, local_position: Vector3, size: Vector2, yaw_degrees: float, texture_path: String, emission := Color.BLACK, energy := 0.0) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.position = local_position
	item.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	item.set_surface_override_material(0, _textured_mat(texture_path, emission, energy))
	item.add_to_group("district_texture_panel")
	if node_name.contains("Floor"):
		item.add_to_group("district_floor_panel")
	elif node_name.contains("Wall"):
		item.add_to_group("district_wall_panel")
	elif node_name.contains("Facade"):
		item.add_to_group("district_facade_panel")
	root.add_child(item)
	return item


func _add_atlas_panel(root: Node3D, node_name: String, local_position: Vector3, size: Vector2, yaw_degrees: float, texture_path: String, region: Rect2, _emission := Color.BLACK, _energy := 0.0) -> Sprite3D:
	var item := Sprite3D.new()
	item.name = node_name
	item.position = local_position
	item.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	item.texture = _texture_from_path(texture_path)
	item.region_enabled = true
	item.region_rect = region
	item.centered = true
	item.pixel_size = size.x / maxf(region.size.x, 1.0)
	var rendered_height := region.size.y * item.pixel_size
	if rendered_height > 0.0:
		item.scale.y = size.y / rendered_height
	item.modulate = Color(1.0, 1.0, 1.0, 1.0)
	item.shaded = false
	item.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	item.add_to_group("district_atlas_panel")
	item.set_meta("debug_region", region)
	item.set_meta("debug_size", size)
	root.add_child(item)
	return item


func _add_floor_panel(root: Node3D, node_name: String, local_position: Vector3, size: Vector2, yaw_degrees: float, texture_path: String) -> MeshInstance3D:
	var item := _add_textured_panel(root, node_name, local_position, size, yaw_degrees, texture_path)
	item.rotation_degrees.x = -90.0
	return item


func _add_ceiling_panel(root: Node3D, node_name: String, local_position: Vector3, size: Vector2, yaw_degrees: float, texture_path: String) -> MeshInstance3D:
	var item := _add_textured_panel(root, node_name, local_position, size, yaw_degrees, texture_path)
	item.rotation_degrees.x = 90.0
	return item


func _add_solid_box(root: Node3D, node_name: String, local_position: Vector3, local_scale: Vector3, material: Material, rotation_degrees_value := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	body.rotation_degrees = rotation_degrees_value
	root.add_child(body)

	var shape := BoxShape3D.new()
	shape.size = local_scale * 2.0
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)

	_add_box(body, "MeshInstance3D", Vector3.ZERO, local_scale, material)
	return body


func _add_shelter_zone(root: Node3D, node_name: String, local_position: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = local_position
	area.script = SHELTER_ZONE_SCRIPT
	root.add_child(area)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	area.add_child(collision)
	return area


func _add_invisible_solid_box(root: Node3D, node_name: String, local_position: Vector3, local_scale: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	root.add_child(body)

	var shape := BoxShape3D.new()
	shape.size = local_scale * 2.0
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	return body


func _add_ladder_zone(root: Node3D, node_name: String, local_position: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = local_position
	area.script = LADDER_ZONE_SCRIPT
	root.add_child(area)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	area.add_child(collision)
	return area


func _add_box(root: Node3D, node_name: String, local_position: Vector3, local_scale: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.position = local_position
	item.scale = local_scale
	item.set_surface_override_material(0, material)
	root.add_child(item)
	return item


func _add_pipe(root: Node3D, node_name: String, local_position: Vector3, length: float, radius: float, yaw_degrees: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	var item := MeshInstance3D.new()
	item.name = node_name
	item.mesh = mesh
	item.position = local_position
	item.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	item.rotate_y(deg_to_rad(yaw_degrees))
	item.set_surface_override_material(0, material)
	root.add_child(item)
	return item


func _add_light(root: Node3D, node_name: String, local_position: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = local_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.add_to_group("district_runtime_light")
	light.set_meta("base_energy", energy)
	root.add_child(light)
	return light
