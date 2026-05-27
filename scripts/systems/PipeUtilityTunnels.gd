extends Node3D

const COOTERS_INTERIOR_SCENE := "res://scenes/levels/CootersInterior.tscn"
const DISTRICT_SCENE := "res://scenes/levels/SubSubBasementDistrict.tscn"
const SECURITY_NODE_SCENE := preload("res://scenes/enemies/SecurityNode.tscn")
const SPLICE_SCENE := preload("res://scenes/enemies/Splice.tscn")

@onready var hud: HUDController = $HUD
@onready var player: Node3D = $Player
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_interactable: WardInteractable
var focused_exit: MissionExit
var _security_node: Node3D
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_pipe: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Leak Street Gate", "Travel event: %s. The tunnel locks click behind you like the building just accepted a dare." % last_event)
	hud.push_log("pipe utility tunnels reached")
	EventDeckSystem.add_card("splice_pipes_return")


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_panel_open():
		return
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("toggle_inventory") or _is_tab_key(event):
		hud.toggle_inventory()
	elif event.is_action_pressed("save_game") or _is_save_key(event):
		_save_game()
	elif event.is_action_pressed("load_game") or _is_load_key(event):
		_load_game()


func _wire_runtime() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	WorldDirector.world_state_changed.connect(hud.set_world_state)
	WorldDirector.restore_from_game_state()
	WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)
	for interactable in get_tree().get_nodes_in_group("location_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for sn in get_tree().get_nodes_in_group("security_node"):
		_security_node = sn
		sn.player_path = NodePath("../Player")
		sn.attacked_player.connect(hud.push_log)
		sn.defeated.connect(func():
			hud.push_log("pipe security node neutralized")
			_security_node = null
		)
	for splice in get_tree().get_nodes_in_group("splice"):
		splice.player_path = NodePath("../Player")
		splice.attacked_player.connect(hud.push_log)
		splice.defeated.connect(func(): hud.push_log("splice neutralized"))
	if GameState.get_world_flag("pipe_valve_used", false):
		if _security_node != null and is_instance_valid(_security_node):
			_security_node.queue_free()
			_security_node = null


func _handle_interact() -> void:
	if focused_interactable != null:
		_dispatch_interactable(focused_interactable)
		return
	if focused_exit != null:
		get_tree().change_scene_to_file(focused_exit.target_scene)


func _dispatch_interactable(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"pipe_pressure_valve":
			_use_pipe_valve()
		"hub_generator_coupling":
			_handle_hub_node(interactable)
		_:
			_handle_job_node(interactable)


func _use_pipe_valve() -> void:
	if GameState.get_world_flag("pipe_valve_used", false):
		hud.show_dialogue("Pressure Valve", "Already bled. The tunnel is holding its breath but at least it stopped sweating.")
		return
	GameState.set_world_flag("pipe_valve_used", true)
	if _security_node != null and is_instance_valid(_security_node):
		_security_node.queue_free()
		_security_node = null
	hud.show_dialogue("Pressure Valve", "A wet crack and the pipe pressure drops. Something in the north section stops clicking. The difference between dangerous and currently dangerous.")
	hud.push_log("pipe valve bled — security node offline")
	_refresh_hud()


func _handle_hub_node(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"hub_generator_coupling":
			if GameState.get_world_flag("hub_power_restored"):
				hud.show_dialogue("Generator Coupling", "Already repaired. The coupling is seated. The generator is running on something more reliable than tape and optimism now.")
				return
			if not GameState.is_quest_started("hub_power_restore"):
				hud.show_dialogue("Generator Coupling", "The hub generator runs a coupling through here. Mister Static at the Faded Atrium knows what needs fixing.")
				return
			GameState.mark_quest_objective("hub_power_restore", "hub_power_restored")
			if GameState.can_complete_quest("hub_power_restore"):
				GameState.complete_quest("hub_power_restore")
			hud.show_dialogue("Generator Coupling", "The coupling seats with a solid click that makes the whole pipe section sound less afraid. Hub generator coupling secured.")
			hud.push_log("hub generator coupling repaired")
			GameState.set_world_flag("_pending_arrival_text", "Generator is stable. Coupling held. I have been apologising to it for six weeks — I can stop now.")
			GameState.set_world_flag("_pending_arrival_speaker", "Mister Static")
			_refresh_hud()


func _handle_job_node(interactable: WardInteractable) -> void:
	var active_job := GameState.get_active_job_data()
	if active_job.is_empty():
		hud.show_dialogue(interactable.display_name, "This tunnel work order is not yours. Cooters likes paperwork before danger, which is how you know danger got unionized.")
		return
	var job_id := GameState.active_job_id
	if GameState.is_job_objective_done(job_id):
		hud.show_dialogue(interactable.display_name, "Already secured. Get back to Cooters before the objective grows a second opinion.")
		return
	var required_id := str(GameState.get_job_data(job_id).get("objective_interactable", ""))
	if interactable.interactable_id != required_id:
		hud.show_dialogue(interactable.display_name, "Wrong node. Current job: %s" % str(active_job.get("objective", "")))
		return
	var item_name := str(active_job.get("objective_item", "Tunnel Evidence"))
	GameState.add_item(item_name)
	GameState.mark_job_objective_done(job_id)
	GameState.last_mission_result = "Completed objective: %s" % str(active_job.get("title", job_id))
	hud.show_dialogue(interactable.display_name, "%s secured. Marbles will pretend this was a normal errand, because denial is cheaper than signage." % item_name)
	hud.push_log("cooters job objective complete")
	_refresh_hud()


func _refresh_hud() -> void:
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	if GameState.active_job_id.is_empty():
		hud.set_objective("Pipe Utility Tunnels: return to Cooters or Leak Street.")
	else:
		hud.set_objective("Pipe Utility Tunnels: %s" % GameState.get_active_job_objective_text())


func _update_prompt() -> void:
	if focused_interactable != null:
		hud.set_prompt(focused_interactable.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	else:
		hud.set_prompt("")


func _on_interactable_focus_changed(interactable: WardInteractable, has_focus: bool) -> void:
	focused_interactable = interactable if has_focus else null
	_update_prompt()


func _on_exit_focus_changed(mission_exit: MissionExit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _build_materials() -> void:
	_mat_floor = _make_mat(Color(0.58, 0.66, 0.62), Color(0.02, 0.08, 0.065), 0.18, "res://assets/textures/leak_street/wet_concrete_floor.png", Vector3(8, 8, 1))
	_mat_wall = _make_mat(Color(0.62, 0.68, 0.64), Color(0.015, 0.07, 0.055), 0.14, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(6, 4, 1))
	_mat_pipe = _make_mat(Color(0.55, 0.45, 0.34), Color(0.12, 0.07, 0.02), 0.18, "res://assets/textures/pipes/pipe_metal.png", Vector3(4, 4, 1))
	_mat_neon = _make_mat(Color(0.02, 0.12, 0.09), Color(0.0, 1.0, 0.55), 1.5, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_geometry() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.18, 0.14)
	env.ambient_light_energy = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.12, 0.1)
	env.fog_density = 0.025
	env_node.environment = env
	add_child(env_node)

	# Outer shell — 18 wide × 26 long
	_add_box("Floor", Vector3(18, 0.35, 26), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("Ceiling", Vector3(18, 0.25, 26), Vector3(0, 3.3, 0), _mat_wall)
	_add_box("NorthWall", Vector3(18, 3.6, 0.35), Vector3(0, 1.6, -13), _mat_wall)
	_add_box("SouthWall", Vector3(18, 3.6, 0.35), Vector3(0, 1.6, 13), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 3.6, 26), Vector3(-9, 1.6, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 3.6, 26), Vector3(9, 1.6, 0), _mat_wall)

	# Divider wall splits west passage (x -9 to -2.5) from main corridor (x -2.5 to 9).
	# Gap at south (z > -0.5) lets players enter from either side.
	# Gap at north (z < -10) lets west-passage players rejoin main corridor near the pipe listening node.
	_add_box("DividerWall", Vector3(0.35, 2.8, 9.5), Vector3(-2.5, 1.4, -5.25), _mat_wall)

	# Upper east walk — elevated side platform. Accessed via SE ramp; holds saint_ratchet_node.
	_add_box("UpperEastWalk", Vector3(4, 0.28, 9), Vector3(7, 2.06, -5.5), _mat_wall)
	# SE ramp rises from ground at z ≈ 4 up to upper walk at z ≈ 0. Rotation: atan(2.2/4) ≈ 0.503 rad.
	_add_box("SERamp", Vector3(4, 0.3, 4.8), Vector3(7, 1.1, 2.0), _mat_wall, Vector3(0.503, 0, 0))

	# Overhead pipe runs for atmosphere
	for z_val: float in [-9.5, -5.0, -0.5, 4.5, 9.5]:
		_add_pipe(Vector3(-8.7, 2.8, z_val), 17.4, true)
	for x_val: float in [-6.0, -0.5, 5.5]:
		_add_pipe(Vector3(x_val, 3.1, -12.5), 25.0, false)

	# Environmental interactable — west passage. Using valve despawns the security node (Route 3).
	_add_interactable("pipe_pressure_valve", "Pressure Valve", "Press E: bleed pressure valve", Vector3(-7, 0.95, 0.5), Color(0.85, 0.55, 0.1))

	# Hub quest node — generator coupling. Deep northwest passage, past divider wall gap.
	# Only spawned if not already repaired.
	if not GameState.get_world_flag("hub_power_restored"):
		_add_interactable("hub_generator_coupling", "Generator Coupling", "Press E: repair generator coupling", Vector3(-6.5, 0.95, -10.5), Color(0.9, 0.55, 0.1))

	# Job nodes
	_add_interactable("pipe_blood_sample_node", "Pipe Blood Sample Bulb", "Press E: collect pipe blood", Vector3(-5.5, 0.95, 6.5), Color(0.0, 1.0, 0.55))
	_add_interactable("saint_ratchet_node", "Saint Ratchet", "Press E: recover Saint Ratchet", Vector3(7.2, 2.55, -5.5), Color(1.0, 0.62, 0.12))
	_add_interactable("pipe_listening_node", "Pipe Listening Node", "Press E: listen to the pipes", Vector3(0.5, 0.95, -11.5), Color(1.0, 0.12, 0.68))

	_add_shelter(Vector3(-6.5, 0.9, 4.5))
	_add_rain_leak(Vector3(-1.5, 1.4, -3.0))
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 12.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -12.1), Color(0.08, 1.0, 0.45))
	_add_security_node(Vector3(0.0, 0.0, -7.0))
	_add_splice(Vector3(-4.0, 1.05, -2.0))
	_add_lights()
	_add_toxic_rain_controller()


func _add_box(node_name: String, size: Vector3, world_position: Vector3, material: Material, world_rotation := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	body.rotation = world_rotation
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, material)
	body.add_child(visual)
	return body


func _add_pipe(world_position: Vector3, length: float, horizontal_x: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.16
	mesh.height = length
	var pipe := MeshInstance3D.new()
	pipe.name = "UtilityPipe"
	pipe.mesh = mesh
	pipe.set_surface_override_material(0, _mat_pipe)
	pipe.position = world_position
	pipe.rotation_degrees.z = 90 if horizontal_x else 0
	pipe.rotation_degrees.x = 90 if not horizontal_x else 0
	add_child(pipe)


func _add_interactable(id: String, display_name: String, prompt: String, world_position: Vector3, color: Color) -> WardInteractable:
	var area := WardInteractable.new()
	area.name = display_name.replace(" ", "")
	area.add_to_group("location_interactable")
	area.interactable_id = id
	area.display_name = display_name
	area.prompt_text = prompt
	area.position = world_position
	add_child(area)
	var col_shape := SphereShape3D.new()
	col_shape.radius = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = col_shape
	area.add_child(collision)
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	var mat := _make_mat(color.darkened(0.78), color, 1.7, "", Vector3.ONE)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, mat)
	area.add_child(visual)
	return area


func _add_shelter(world_position: Vector3) -> void:
	var shelter := ShelterZone.new()
	shelter.name = "ShelterNook"
	shelter.position = world_position
	add_child(shelter)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 2.0, 3.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	shelter.add_child(collision)
	_add_box("ShelterAwning", Vector3(4.2, 0.18, 3.4), world_position + Vector3(0.0, 1.2, 0.0), _mat_neon)


func _add_rain_leak(world_position: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 2.8
	var leak := MeshInstance3D.new()
	leak.name = "RainLeakColumn"
	leak.mesh = mesh
	leak.position = world_position
	leak.set_surface_override_material(0, _mat_rain)
	add_child(leak)


func _add_exit(node_name: String, prompt: String, target_scene: String, world_position: Vector3, color: Color) -> void:
	var exit := MissionExit.new()
	exit.name = node_name
	exit.add_to_group("mission_exit")
	exit.prompt_text = prompt
	exit.target_scene = target_scene
	exit.position = world_position
	add_child(exit)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.5, 2.2, 1.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	exit.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.4, 1.6, 0.12)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, _make_mat(color.darkened(0.8), color, 1.4, "", Vector3.ONE))
	exit.add_child(visual)


func _add_security_node(world_position: Vector3) -> void:
	var node := SECURITY_NODE_SCENE.instantiate()
	node.name = "SecurityNode"
	node.position = world_position
	add_child(node)


func _add_splice(world_position: Vector3) -> void:
	var splice := SPLICE_SCENE.instantiate()
	splice.name = "Splice"
	splice.position = world_position
	splice.add_to_group("splice")
	add_child(splice)


func _add_lights() -> void:
	for data: Array in [
		[Vector3(-6.5, 2.3, 4.5), Color(0.0, 1.0, 0.55), 1.6],
		[Vector3(7.2, 2.7, -5.5), Color(1.0, 0.62, 0.12), 1.4],
		[Vector3(0.5, 2.3, -11.5), Color(1.0, 0.12, 0.68), 1.5],
		[Vector3(-7.0, 2.3, 0.5), Color(0.85, 0.55, 0.1), 1.2],
		[Vector3(0.0, 2.5, -7.0), Color(0.0, 0.75, 1.0), 1.8],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = 7.0
		add_child(light)


func _add_toxic_rain_controller() -> void:
	var controller := ToxicRainController.new()
	controller.name = "ToxicRainController"
	controller.player_health_path = NodePath("../Player/PlayerHealth")
	controller.hud_path = NodePath("../HUD")
	add_child(controller)


func _make_mat(albedo: Color, emission: Color, emission_energy: float, texture_path: String, uv_scale: Vector3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.86
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = uv_scale
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	return mat


func _save_game() -> void:
	if GameState.save_game():
		hud.show_system_message("GAME SAVED")
	else:
		hud.show_system_message("SAVE FAILED")


func _load_game() -> void:
	if GameState.load_game():
		WorldDirector.restore_from_game_state()
		WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)
		_refresh_hud()
		hud.show_system_message("GAME LOADED")
	else:
		hud.show_system_message("NO SAVE FOUND")


func _is_manual_interact_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_E


func _is_save_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5


func _is_load_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F6


func _is_tab_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB
