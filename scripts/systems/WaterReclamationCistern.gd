extends Node3D

# Water Reclamation Cistern — flooded reclamation room with improvised scavenger repairs.
# Job: cistern_pump_heart  Objective: cistern_filter_core_node
#
# Three routes to the filter core (northwest pump room):
#   Route 1 — Combat:        east walkway, fight security node, north walkway, pump room
#   Route 2 — Filter beds:   cross center via stepping stones (above water threshold), west side, pump room
#   Route 3 — Pump valve:    west walkway, use pump valve (disables water + despawns node), cross freely

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
var _in_water: bool = false
var _water_hazard_active: bool = true
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_water: StandardMaterial3D
var _mat_filter_bed: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Water Reclamation Cistern", "Travel event: %s. The water here smells like it has a legal team." % last_event)
	hud.push_log("water reclamation cistern reached")
	EventDeckSystem.add_card("splice_cistern_return")


func _process(delta: float) -> void:
	if _in_water and _water_hazard_active and player != null and player.global_position.y < 1.2:
		player_health.apply_damage(3.0 * delta)


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
			hud.push_log("cistern security node neutralized")
			_security_node = null
		)
	for splice in get_tree().get_nodes_in_group("splice"):
		splice.player_path = NodePath("../Player")
		splice.attacked_player.connect(hud.push_log)
		splice.defeated.connect(func(): hud.push_log("splice neutralized"))
	if GameState.get_world_flag("cistern_valve_used", false):
		_water_hazard_active = false
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
		"pump_valve_panel":
			_use_pump_valve()
		"hub_cistern_conduit", "hub_lan_tap":
			_handle_hub_node(interactable)
		_:
			_handle_job_node(interactable)


func _use_pump_valve() -> void:
	if GameState.get_world_flag("cistern_valve_used", false):
		hud.show_dialogue("Pump Valve", "Already drained. The water went somewhere it will not discuss. The conduit is cooperating for now.")
		return
	GameState.set_world_flag("cistern_valve_used", true)
	_water_hazard_active = false
	if _security_node != null and is_instance_valid(_security_node):
		_security_node.queue_free()
		_security_node = null
	hud.show_dialogue("Pump Valve", "The pump engages with the confidence of machinery that has not been asked nicely in years. The water level drops. The security node on the east walk stops having a reason to be there.")
	hud.push_log("cistern pump valve opened — water neutralized, security node offline")
	_refresh_hud()


func _handle_hub_node(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"hub_cistern_conduit":
			if GameState.get_world_flag("hub_cistern_connected"):
				hud.show_dialogue("Cistern Conduit Junction", "Already connected. Clean water is running to the clinic. Vera stopped mentioning the pipe smell, which means things are better.")
				return
			if not GameState.is_quest_started("hub_cistern"):
				hud.show_dialogue("Cistern Conduit Junction", "There is a junction point here waiting for a conduit run. Vera at the Faded Atrium would know the full spec.")
				return
			GameState.mark_quest_objective("hub_cistern", "hub_cistern_connected")
			if GameState.can_complete_quest("hub_cistern"):
				GameState.complete_quest("hub_cistern")
			hud.show_dialogue("Cistern Conduit Junction", "The conduit seats and the flow indicator goes green. Clean water is now running to the hub clinic.")
			hud.push_log("hub cistern conduit connected")
			GameState.set_world_flag("_pending_arrival_text", "Water is clean. Clinic is running. Whatever you did in the cistern, it worked. I will not ask about the smell.")
			GameState.set_world_flag("_pending_arrival_speaker", "Vera")
			_refresh_hud()
		"hub_lan_tap":
			if GameState.get_world_flag("hub_lan_restored"):
				hud.show_dialogue("LAN Tap Junction", "Already spliced. System X can see the lower city again. What it sees is mostly your problem now.")
				return
			if not GameState.is_quest_started("hub_lan_restore"):
				hud.show_dialogue("LAN Tap Junction", "Severed cable in the ceiling panel. The hub LAN runs through here. Vessel at the Faded Atrium knows what needs splicing.")
				return
			GameState.mark_quest_objective("hub_lan_restore", "hub_lan_restored")
			if GameState.can_complete_quest("hub_lan_restore"):
				GameState.complete_quest("hub_lan_restore")
			hud.show_dialogue("LAN Tap Junction", "The splice holds. The tap cable goes live with a tone that sounds like relief. Hub LAN restored.")
			hud.push_log("hub LAN tap spliced")
			GameState.set_world_flag("_pending_arrival_text", "Archive is live. System X has seventeen things to tell you. Sixteen are warnings. I have decided one is a joke and I am sticking to it.")
			GameState.set_world_flag("_pending_arrival_speaker", "Vessel")
			_refresh_hud()


func _handle_job_node(interactable: WardInteractable) -> void:
	var active_job := GameState.get_active_job_data()
	if active_job.is_empty():
		hud.show_dialogue(interactable.display_name, "Not your lease. Wan Moa Torai has opinions about unpermitted salvage, and so does the water.")
		return
	var job_id := GameState.active_job_id
	if GameState.is_job_objective_done(job_id):
		hud.show_dialogue(interactable.display_name, "Already secured. Get back to Cooters before the pipe system re-categorizes you as inventory.")
		return
	var required_id := str(GameState.get_job_data(job_id).get("objective_interactable", ""))
	if interactable.interactable_id != required_id:
		hud.show_dialogue(interactable.display_name, "Wrong component. Current job: %s" % str(active_job.get("objective", "")))
		return
	var item_name := str(active_job.get("objective_item", "Cistern Component"))
	GameState.add_item(item_name)
	GameState.mark_job_objective_done(job_id)
	GameState.last_mission_result = "Completed objective: %s" % str(active_job.get("title", job_id))
	hud.show_dialogue(interactable.display_name, "%s removed. The pump is now running on trust and historical momentum." % item_name)
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
		hud.set_objective("Water Reclamation Cistern: return to Cooters or Leak Street.")
	else:
		hud.set_objective("Water Reclamation Cistern: %s" % GameState.get_active_job_objective_text())


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
	_mat_floor = _make_mat(Color(0.52, 0.56, 0.58), Color(0.01, 0.04, 0.06), 0.10, "res://assets/textures/leak_street/wet_concrete_floor.png", Vector3(8, 8, 1))
	_mat_wall = _make_mat(Color(0.48, 0.54, 0.58), Color(0.01, 0.03, 0.05), 0.08, "res://assets/textures/cistern/cistern_wall.png", Vector3(6, 4, 1))
	_mat_water = _make_mat(Color(0.02, 0.28, 0.55, 0.72), Color(0.0, 0.45, 0.9), 1.1, "", Vector3.ONE)
	_mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_filter_bed = _make_mat(Color(0.55, 0.52, 0.44), Color(0.06, 0.06, 0.03), 0.14, "res://assets/textures/cistern/filter_bed_aggregate.png", Vector3(4, 4, 1))
	_mat_neon = _make_mat(Color(0.02, 0.08, 0.18), Color(0.0, 0.5, 1.0), 1.5, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_geometry() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.007, 0.01, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.1, 0.16)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.06, 0.1)
	env.fog_density = 0.028
	env_node.environment = env
	add_child(env_node)

	# Outer shell — 20 wide × 24 long
	_add_box("Floor", Vector3(20, 0.35, 24), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("Ceiling", Vector3(20, 0.25, 24), Vector3(0, 4.0, 0), _mat_wall)
	_add_box("NorthWall", Vector3(20, 4.3, 0.35), Vector3(0, 1.9, -12), _mat_wall)
	_add_box("SouthWall", Vector3(20, 4.3, 0.35), Vector3(0, 1.9, 12), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 4.3, 24), Vector3(-10, 1.9, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 4.3, 24), Vector3(10, 1.9, 0), _mat_wall)

	# Water visual — translucent plane covering the center channel (x -3.5..3.5)
	var water_visual := MeshInstance3D.new()
	water_visual.name = "WaterSurface"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(7, 0.04, 22)
	water_visual.mesh = water_mesh
	water_visual.position = Vector3(0, 0.02, 0)
	water_visual.set_surface_override_material(0, _mat_water)
	add_child(water_visual)

	# Water hazard Area3D — 3 hp/s when player.y < 1.2 (filter beds lift player above threshold)
	_add_damage_zone("WaterChannelHazard", Vector3(7, 3, 22), Vector3(0, 0, 0))

	# Filter bed stepping stones — Route 2 crossing. Surface y = 0.5; player center ≈ 1.55 (above 1.2 threshold).
	for z_val: float in [4.0, 0.0, -4.0]:
		_add_box("FilterBed", Vector3(2.2, 0.5, 2.2), Vector3(0, 0.25, z_val), _mat_filter_bed)

	# Pump control room — northwest corner pocket. South wall split to leave a 2-unit doorway at x -8..-6,
	# allowing entry from the west walkway northward. East wall unchanged.
	_add_box("PumpRoomSouthWallW", Vector3(2.0, 3.5, 0.35), Vector3(-9.0, 1.6, -8.0), _mat_wall)
	_add_box("PumpRoomSouthWallE", Vector3(2.0, 3.5, 0.35), Vector3(-5.5, 1.6, -8.0), _mat_wall)
	_add_box("PumpRoomEastWall", Vector3(0.35, 3.5, 3.5), Vector3(-4.5, 1.6, -10.25), _mat_wall)

	# Pump valve panel — Route 3 environmental. On west walkway. Disables water and despawns node.
	_add_interactable("pump_valve_panel", "Pump Valve", "Press E: open pump valve", Vector3(-7, 0.95, 0.0), Color(0.0, 0.6, 1.0))

	# Hub quest nodes — only spawn if not yet resolved.
	if not GameState.get_world_flag("hub_cistern_connected"):
		_add_interactable("hub_cistern_conduit", "Cistern Conduit Junction", "Press E: install water conduit", Vector3(-7.5, 0.95, -4.5), Color(0.1, 0.8, 0.6))
	if not GameState.get_world_flag("hub_lan_restored"):
		_add_interactable("hub_lan_tap", "LAN Tap Junction", "Press E: splice LAN tap", Vector3(8.0, 0.95, -10.5), Color(0.2, 0.8, 1.0))

	# Job node — inside pump room pocket
	_add_interactable("cistern_filter_core_node", "Cistern Filter Core", "Press E: recover filter core", Vector3(-7, 0.95, -9.5), Color(0.0, 1.0, 0.8))

	_add_shelter(Vector3(-7, 0.9, 7.0))
	_add_rain_leak(Vector3(7.5, 1.4, 3.0))
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 11.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -11.1), Color(0.08, 1.0, 0.45))
	_add_security_node(Vector3(7.0, 0.0, -5.0))
	_add_splice(Vector3(7.0, 1.05, 2.0))
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
			_in_water = true
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_in_water = false
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
		[Vector3(-7.0, 2.5, -9.5), Color(0.0, 1.0, 0.8), 1.8],
		[Vector3(-7.0, 2.5, 0.0), Color(0.0, 0.6, 1.0), 1.4],
		[Vector3(7.0, 2.5, -5.0), Color(0.0, 0.75, 1.0), 1.4],
		[Vector3(0.0, 2.5, 4.0), Color(0.0, 0.5, 1.0), 1.0],
		[Vector3(-7.0, 2.5, 7.0), Color(0.1, 0.6, 0.8), 1.2],
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
