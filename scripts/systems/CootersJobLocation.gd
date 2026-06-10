extends Node3D

const COOTERS_INTERIOR_SCENE := "res://scenes/levels/CootersInterior.tscn"
const DISTRICT_SCENE := "res://scenes/levels/SubSubBasementDistrict.tscn"
const SECURITY_NODE_SCENE := preload("res://scenes/enemies/SecurityNode.tscn")

@export var location_id := "dead_food_court_bloom"
@export var location_title := "Dead Food Court Bloom"
@export var location_profile := "food_court"

@onready var hud: HUDController = $HUD
@onready var player: Node3D = $Player
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_interactable: WardInteractable
var focused_exit: MissionExit
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_growth: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_hazard: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_location()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Leak Street Gate", "Travel event: %s. %s opens like a bad maintenance note someone left under a wet door." % [last_event, location_title])
	hud.push_log("%s reached" % location_title.to_lower())


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

	for interactable in get_tree().get_nodes_in_group("cooters_job_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for security_node in get_tree().get_nodes_in_group("security_node"):
		security_node.player_path = NodePath("../Player")
		security_node.attacked_player.connect(hud.push_log)
		security_node.defeated.connect(func(): hud.push_log("local security target quiet"))


func _handle_interact() -> void:
	if focused_interactable != null:
		_handle_job_interactable(focused_interactable)
		return
	if focused_exit != null:
		get_tree().change_scene_to_file(focused_exit.target_scene)


func _handle_job_interactable(interactable: WardInteractable) -> void:
	var active_job := GameState.get_active_job_data()
	if active_job.is_empty() or str(active_job.get("destination_id", "")) != location_id:
		hud.show_dialogue(interactable.display_name, "This looks useful, which is exactly how trouble advertises. Marbles did not send you here for it.")
		return

	var job_id := GameState.active_job_id
	if GameState.is_job_objective_done(job_id):
		hud.show_dialogue(interactable.display_name, "You already have the job proof. Get back to Cooters before the receipt changes shape and starts asking for a booth.")
		return

	var required_id := str(active_job.get("objective_interactable", ""))
	if interactable.interactable_id != required_id:
		hud.show_dialogue(interactable.display_name, "Wrong object, correct danger. Current job: %s" % str(active_job.get("objective", "")))
		return

	var item_name := str(active_job.get("objective_item", "Job Proof"))
	GameState.add_item(item_name)
	GameState.mark_job_objective_done(job_id)
	GameState.last_mission_result = "Completed objective: %s" % str(active_job.get("title", job_id))
	hud.show_dialogue(interactable.display_name, "%s secured. Marbles will make this sound easier than it was, because bartenders edit reality for tips." % item_name)
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
		hud.set_objective("%s: return to Cooters or Leak Street." % location_title)
	else:
		hud.set_objective("%s: %s" % [location_title, GameState.get_active_job_objective_text()])


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
	_mat_floor = _make_mat(Color(0.58, 0.66, 0.62), Color(0.02, 0.08, 0.065), 0.16, "res://assets/textures/leak_street/wet_concrete_floor.png", Vector3(4, 4, 1))
	_mat_wall = _make_mat(Color(0.62, 0.68, 0.64), Color(0.015, 0.07, 0.055), 0.12, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(2.4, 2.4, 1))
	_mat_metal = _make_mat(Color(0.5, 0.48, 0.42), Color(0.08, 0.08, 0.06), 0.22, "res://assets/textures/leak_street/patchwork_plate_wall.png", Vector3(2.0, 2.0, 1))
	_mat_growth = _make_mat(Color(0.1, 0.32, 0.16), Color(0.08, 0.75, 0.18), 0.65, "", Vector3.ONE)
	_mat_neon = _make_mat(Color(0.02, 0.12, 0.09), Color(0.0, 1.0, 0.75), 1.55, "", Vector3.ONE)
	_mat_hazard = _make_mat(Color(0.8, 0.22, 0.04), Color(1.0, 0.25, 0.04), 1.35, "", Vector3.ONE)


func _build_location() -> void:
	_add_environment()
	match location_profile:
		"food_court":
			_build_food_court()
		"cistern":
			_build_cistern()
		"atrium":
			_build_atrium()
		_:
			_build_food_court()
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(-3.2, 1.0, 10.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(3.2, 1.0, 10.1), Color(0.08, 1.0, 0.45))


func _add_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.09, 0.17, 0.14)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.12, 0.1)
	env.fog_density = 0.022
	environment.environment = env
	add_child(environment)


func _build_food_court() -> void:
	_add_box("FoodCourtFloor", Vector3(20, 0.35, 22), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("NorthWall", Vector3(20, 3.2, 0.35), Vector3(0, 1.4, -11), _mat_wall)
	_add_box("SouthWall", Vector3(20, 3.2, 0.35), Vector3(0, 1.4, 11), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 3.2, 22), Vector3(-10, 1.4, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 3.2, 22), Vector3(10, 1.4, 0), _mat_wall)
	_add_box("UpperFastFoodRing", Vector3(18, 0.28, 2.4), Vector3(0, 1.55, -6.8), _mat_metal)
	_add_box("KitchenBypass", Vector3(2.4, 0.25, 10), Vector3(-7.5, 1.1, -1.0), _mat_metal, Vector3(0.18, 0, 0))
	_add_box("SnareGrowthPit", Vector3(7.5, 0.2, 5.5), Vector3(0, 0.02, -0.5), _mat_growth)
	_add_box("MenuBoardGlow", Vector3(6.8, 0.12, 0.9), Vector3(0, 2.6, -10.6), _mat_neon)
	_add_job_node("pure_water_filter_node", "Pure Water Filter", "Press E: recover pure water filter", Vector3(0, 1.05, -6.8), Color(0.0, 1.0, 0.75))
	_add_job_node("spore_vent_panel", "Grease-Spore Vent", "Press E: cycle spore vent", Vector3(6.2, 0.9, -1.8), Color(0.7, 1.0, 0.05))
	_add_security_node(Vector3(-2.5, 0.0, -2.0))
	_add_light(Vector3(0, 2.8, -6.8), Color(0.0, 1.0, 0.75), 1.8)
	_add_light(Vector3(2.5, 1.4, -0.4), Color(0.08, 1.0, 0.18), 1.1)


func _build_cistern() -> void:
	_add_box("CisternFloor", Vector3(20, 0.35, 22), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("NorthWall", Vector3(20, 3.2, 0.35), Vector3(0, 1.4, -11), _mat_wall)
	_add_box("SouthWall", Vector3(20, 3.2, 0.35), Vector3(0, 1.4, 11), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 3.2, 22), Vector3(-10, 1.4, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 3.2, 22), Vector3(10, 1.4, 0), _mat_wall)
	_add_box("WaterChannel", Vector3(8.5, 0.12, 16), Vector3(0, 0.05, -0.6), _mat_neon)
	_add_box("WalkwayRingA", Vector3(18, 0.3, 1.8), Vector3(0, 0.35, -7.0), _mat_metal)
	_add_box("WalkwayRingB", Vector3(18, 0.3, 1.8), Vector3(0, 0.35, 5.8), _mat_metal)
	_add_box("PumpControlRoom", Vector3(5.4, 2.0, 2.8), Vector3(-6.2, 0.9, -1.0), _mat_metal)
	_add_box("LiveConduit", Vector3(0.35, 0.35, 13), Vector3(4.8, 0.55, -0.4), _mat_hazard)
	_add_job_node("cistern_filter_core_node", "Cistern Filter Core", "Press E: recover pump core", Vector3(-6.2, 1.35, -1.0), Color(1.0, 0.62, 0.12))
	_add_job_node("pump_valve_panel", "Pump Valve Panel", "Press E: cycle pump valves", Vector3(4.8, 0.95, 5.6), Color(0.0, 1.0, 0.75))
	_add_security_node(Vector3(4.2, 0.0, -5.2))
	_add_light(Vector3(-6.2, 2.3, -1.0), Color(1.0, 0.62, 0.12), 1.7)
	_add_light(Vector3(4.8, 1.8, -0.4), Color(1.0, 0.22, 0.04), 1.2)


func _build_atrium() -> void:
	_add_box("AtriumFloor", Vector3(20, 0.35, 22), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("NorthWall", Vector3(20, 3.2, 0.35), Vector3(0, 1.4, -11), _mat_wall)
	_add_box("SouthWall", Vector3(20, 3.2, 0.35), Vector3(0, 1.4, 11), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 3.2, 22), Vector3(-10, 1.4, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 3.2, 22), Vector3(10, 1.4, 0), _mat_wall)
	_add_box("SludgeGap", Vector3(7.2, 0.12, 12), Vector3(0, 0.0, -0.8), _mat_growth)
	_add_box("HangingCatwalkA", Vector3(2.2, 0.28, 15), Vector3(-4.5, 1.8, -1.0), _mat_metal)
	_add_box("HangingCatwalkB", Vector3(8.0, 0.28, 2.0), Vector3(0, 1.8, -7.0), _mat_metal)
	_add_box("RampToCatwalk", Vector3(2.1, 0.25, 6.8), Vector3(-4.5, 0.78, 5.4), _mat_metal, Vector3(-0.28, 0, 0))
	_add_box("HardlightGate", Vector3(4.2, 1.9, 0.18), Vector3(1.8, 1.2, -7.0), _mat_neon)
	_add_job_node("atrium_relay_node", "Mall Relay Choir", "Press E: record relay echo", Vector3(-4.5, 2.4, -7.0), Color(0.0, 0.82, 1.0))
	_add_job_node("hardlight_gate_panel", "Hardlight Gate Panel", "Press E: pulse barrier", Vector3(5.5, 0.95, -7.0), Color(1.0, 0.08, 0.62))
	_add_security_node(Vector3(3.0, 0.0, -1.0))
	_add_light(Vector3(-4.5, 2.8, -7.0), Color(0.0, 0.82, 1.0), 1.8)
	_add_light(Vector3(1.8, 1.8, -7.0), Color(1.0, 0.08, 0.62), 1.2)


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


func _add_job_node(id: String, display_name: String, prompt: String, world_position: Vector3, color: Color) -> void:
	var area := WardInteractable.new()
	area.name = display_name.replace(" ", "")
	area.add_to_group("cooters_job_interactable")
	area.interactable_id = id
	area.display_name = display_name
	area.prompt_text = prompt
	area.position = world_position
	add_child(area)

	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)

	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	var material := _make_mat(color.darkened(0.78), color, 1.7, "", Vector3.ONE)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, material)
	area.add_child(visual)


func _add_exit(node_name: String, prompt: String, target_scene: String, world_position: Vector3, color: Color) -> void:
	var exit := MissionExit.new()
	exit.name = node_name
	exit.add_to_group("mission_exit")
	exit.prompt_text = prompt
	exit.target_scene = target_scene
	exit.position = world_position
	add_child(exit)

	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 2.2, 1.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	exit.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 1.6, 0.12)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, _make_mat(color.darkened(0.8), color, 1.4, "", Vector3.ONE))
	exit.add_child(visual)


func _add_security_node(world_position: Vector3) -> void:
	var node := SECURITY_NODE_SCENE.instantiate()
	node.name = "JobLocationSecurityNode"
	node.position = world_position
	node.persistence_id = "cooters_job:%s:security_node:%.2f:%.2f:%.2f" % [location_id, world_position.x, world_position.y, world_position.z]
	add_child(node)


func _add_light(world_position: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = world_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 7.5
	add_child(light)


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
	if GameState.quicksave():
		hud.show_system_message("QUICKSAVED")
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
