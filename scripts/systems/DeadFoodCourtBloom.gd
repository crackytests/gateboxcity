extends Node3D

# Dead Food Court Bloom — ruined second-floor food court overgrown by bio-mall flora.
# Job: food_court_filter  Objective: pure_water_filter_node
#
# Three routes to the filter (north upper ring):
#   Route 1 — Combat:       cross growth pit, fight security node, up central north ramp
#   Route 2 — Upper ring:   SW ramp to west ring, traverse NW corner to north ring
#   Route 3 — Kitchen/Vent: east passage (no pit damage), NE ramp, north ring;
#                           spore vent panel despawns security node for clean approach

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
var _in_growth: bool = false
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_growth: StandardMaterial3D
var _mat_ring: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Dead Food Court Bloom", "Travel event: %s. The menu boards are still on. None of the items are food anymore." % last_event)
	hud.push_log("dead food court bloom reached")
	EventDeckSystem.add_card("splice_bloom_return")


func _process(delta: float) -> void:
	if _in_growth and player != null and player.global_position.y < 1.2:
		player_health.apply_damage(1.0 * delta)


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
			hud.push_log("food court security node neutralized")
			_security_node = null
		)
	for splice in get_tree().get_nodes_in_group("splice"):
		splice.player_path = NodePath("../Player")
		splice.attacked_player.connect(hud.push_log)
		splice.defeated.connect(func(): hud.push_log("splice neutralized"))
	if GameState.get_world_flag("spore_vent_used", false):
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
		"spore_vent_panel":
			_use_spore_vent()
		_:
			_handle_job_node(interactable)


func _use_spore_vent() -> void:
	if GameState.get_world_flag("spore_vent_used", false):
		hud.show_dialogue("Spore Vent Panel", "Already vented. The security node took the spores personally and stopped having opinions.")
		return
	GameState.set_world_flag("spore_vent_used", true)
	GameState.set_world_flag("nursery_culture_saved", true)
	if _security_node != null and is_instance_valid(_security_node):
		_security_node.queue_free()
		_security_node = null
	hud.show_dialogue("Spore Vent Panel", "The grease vent opens and releases a decade of compressed food-court biology directly into the pit. The security node goes quiet in a way that suggests it was not prepared for this ecosystem. The nursery culture survives. Somehow.")
	hud.push_log("spore vent triggered — security node offline, nursery culture preserved")
	_refresh_hud()


func _handle_job_node(interactable: WardInteractable) -> void:
	var active_job := GameState.get_active_job_data()
	if active_job.is_empty():
		hud.show_dialogue(interactable.display_name, "Not your job. The filter has opinions about who touches it, and you have not filled out the paperwork.")
		return
	var job_id := GameState.active_job_id
	if GameState.is_job_objective_done(job_id):
		hud.show_dialogue(interactable.display_name, "Already secured. Get back to Cooters before the plants figure out what you took.")
		return
	var required_id := str(GameState.get_job_data(job_id).get("objective_interactable", ""))
	if interactable.interactable_id != required_id:
		hud.show_dialogue(interactable.display_name, "Wrong node. Current job: %s" % str(active_job.get("objective", "")))
		return
	var item_name := str(active_job.get("objective_item", "Food Court Evidence"))
	GameState.add_item(item_name)
	GameState.mark_job_objective_done(job_id)
	GameState.last_mission_result = "Completed objective: %s" % str(active_job.get("title", job_id))
	hud.show_dialogue(interactable.display_name, "%s recovered. It still smells like the lunch special. That is probably fine." % item_name)
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
		hud.set_objective("Dead Food Court Bloom: return to Cooters or Leak Street.")
	else:
		hud.set_objective("Dead Food Court Bloom: %s" % GameState.get_active_job_objective_text())


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
	_mat_floor = _make_mat(Color(0.48, 0.44, 0.38), Color(0.06, 0.05, 0.03), 0.12, "res://assets/textures/bloom/food_court_floor.png", Vector3(8, 8, 1))
	_mat_wall = _make_mat(Color(0.38, 0.42, 0.36), Color(0.04, 0.06, 0.03), 0.10, "res://assets/textures/bloom/food_court_wall.png", Vector3(6, 4, 1))
	_mat_growth = _make_mat(Color(0.06, 0.16, 0.04), Color(0.12, 0.65, 0.05), 0.95, "res://assets/textures/bloom/bio_bloom_growth.png", Vector3(3, 3, 1))
	_mat_ring = _make_mat(Color(0.45, 0.48, 0.42), Color(0.02, 0.04, 0.02), 0.08, "res://assets/textures/shared/metal_catwalk_grating.png", Vector3(6, 6, 1))
	_mat_neon = _make_mat(Color(0.02, 0.12, 0.04), Color(0.1, 0.9, 0.05), 1.4, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_geometry() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.007)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.12, 0.05)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.08, 0.03)
	env.fog_density = 0.03
	env_node.environment = env
	add_child(env_node)

	# Outer shell — 22 wide × 24 long
	_add_box("Floor", Vector3(22, 0.35, 24), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("Ceiling", Vector3(22, 0.25, 24), Vector3(0, 4.2, 0), _mat_wall)
	_add_box("NorthWall", Vector3(22, 4.5, 0.35), Vector3(0, 2.0, -12), _mat_wall)
	_add_box("SouthWall", Vector3(22, 4.5, 0.35), Vector3(0, 2.0, 12), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 4.5, 24), Vector3(-11, 2.0, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 4.5, 24), Vector3(11, 2.0, 0), _mat_wall)

	# Growth pit visual — organic floor tile covering the seating pit area (x -5..5, z -7..5)
	var pit_visual := MeshInstance3D.new()
	pit_visual.name = "GrowthPitFloor"
	var pit_mesh := BoxMesh.new()
	pit_mesh.size = Vector3(10, 0.06, 12)
	pit_visual.mesh = pit_mesh
	pit_visual.position = Vector3(0, 0.02, -1)
	pit_visual.set_surface_override_material(0, _mat_growth)
	add_child(pit_visual)

	# Growth pit Area3D — snare growth damage zone (1 hp/s when player.y < 1.2)
	_add_damage_zone("GrowthPitHazard", Vector3(10, 3, 12), Vector3(0, 0, -1))

	# West upper ring — the safer slow route (surface y = 1.65)
	# Spans x -11..-5, z -11..6. SW ramp at south end connects to ground.
	_add_box("WestUpperRing", Vector3(6, 0.28, 17), Vector3(-8, 1.51, -2.5), _mat_ring)

	# North upper ring — filter node destination (surface y = 1.65)
	# Spans x -11..11, z -11..-6. Three ramps feed into it.
	_add_box("NorthUpperRing", Vector3(22, 0.28, 5), Vector3(0, 1.51, -8.5), _mat_ring)

	# SW ramp — Route 2 entry. Rises from ground (z ≈ 9) to west upper ring (z ≈ 6, y 1.65).
	# atan(1.65/3) ≈ 0.503 rad. Center at (-8, 0.82, 7.5).
	_add_box("SWRamp", Vector3(6, 0.3, 3.5), Vector3(-8, 0.82, 7.5), _mat_ring, Vector3(0.503, 0, 0))

	# Central north ramp — Route 1 exit. From ground pit area (z ≈ -4) up to north ring (z ≈ -7).
	_add_box("CentralNorthRamp", Vector3(5, 0.3, 3.5), Vector3(0, 0.82, -5.5), _mat_ring, Vector3(0.503, 0, 0))

	# NE ramp — Route 3 (kitchen bypass) to north ring. At east passage x ≈ 8.
	_add_box("NERamp", Vector3(4, 0.3, 3.5), Vector3(8, 0.82, -5.5), _mat_ring, Vector3(0.503, 0, 0))

	# Kitchen corridor partial wall — east side of pit. Defines the kitchen bypass lane.
	_add_box("KitchenWestWall", Vector3(0.35, 4.5, 14), Vector3(5, 2.0, 0.5), _mat_wall)

	# Spore vent panel — Route 3 environmental. On east wall, kitchen bypass lane.
	_add_interactable("spore_vent_panel", "Spore Vent Panel", "Press E: trigger grease-spore vent", Vector3(10.5, 0.95, 4.0), Color(0.9, 0.5, 0.05))

	# Job node — on north upper ring
	_add_interactable("pure_water_filter_node", "Pure Water Filter", "Press E: recover filter", Vector3(-4, 1.85, -10.0), Color(0.0, 0.85, 1.0))

	_add_shelter(Vector3(8, 0.9, 7.0))
	_add_rain_leak(Vector3(-9, 1.4, -2.0))
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 11.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -11.1), Color(0.08, 1.0, 0.45))
	_add_security_node(Vector3(0.0, 0.0, -3.0))
	_add_splice(Vector3(2.0, 1.05, -0.5))
	_add_lights()
	_add_toxic_rain_controller()


func _add_damage_zone(zone_name: String, size: Vector3, world_pos: Vector3) -> void:
	var area := Area3D.new()
	area.name = zone_name
	area.position = world_pos
	add_child(area)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_in_growth = true
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_in_growth = false
	)


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
	splice.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice)


func _on_splice_item_dropped(item_name: String) -> void:
	hud.push_log("splice dropped: %s" % item_name.replace("_", " "))
	hud.show_system_message("FOUND " + item_name.to_upper().replace("_", " "))


func _add_lights() -> void:
	for data: Array in [
		[Vector3(8, 2.5, 6.0), Color(0.7, 0.5, 0.1), 1.4],
		[Vector3(-8, 2.8, -2.5), Color(0.1, 0.8, 0.05), 1.6],
		[Vector3(-4, 2.8, -10.0), Color(0.0, 0.85, 1.0), 1.8],
		[Vector3(0, 2.3, -3.0), Color(0.15, 0.7, 0.05), 1.2],
		[Vector3(10.5, 2.5, 3.5), Color(0.9, 0.5, 0.05), 1.2],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = 8.0
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
	mat.roughness = 0.88
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
