extends Node3D

# Collapsed Service Atrium — vertical mall atrium collapsed into maintenance decks.
# Job: atrium_relay_echo  Objective: atrium_relay_node
#
# Three routes to the relay (north catwalk):
#   Route 1 — Combat:       south ramp to catwalk, fight security node, north along catwalk to relay
#   Route 2 — East hatch:   east ground passage (no sludge), NE ramp to catwalk, approach relay from north
#   Route 3 — Hardlight:    use gate panel on west side, spawns bridge across sludge gap,
#                           NW ramp to catwalk, bypasses security node position

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
var _bridge_body: StaticBody3D
var _in_sludge: bool = false
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_catwalk: StandardMaterial3D
var _mat_sludge: StandardMaterial3D
var _mat_hardlight: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Collapsed Service Atrium", "Travel event: %s. The old banners are still up. They say nothing useful about what the floor became." % last_event)
	hud.push_log("collapsed service atrium reached")
	EventDeckSystem.add_card("splice_atrium_return")


func _process(delta: float) -> void:
	if _in_sludge and player != null and player.global_position.y < 1.2:
		player_health.apply_damage(4.0 * delta)


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
			hud.push_log("atrium security node neutralized")
			_security_node = null
		)
	for splice in get_tree().get_nodes_in_group("splice"):
		splice.player_path = NodePath("../Player")
		splice.attacked_player.connect(hud.push_log)
		splice.defeated.connect(func(): hud.push_log("splice neutralized"))
	if GameState.get_world_flag("atrium_gate_opened", false):
		_spawn_hardlight_bridge()
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
		"hardlight_gate_panel":
			_use_hardlight_gate()
		"hub_debris_pile_1", "hub_debris_pile_2", "hub_debris_pile_3", "store_4_terminal":
			_handle_hub_node(interactable)
		_:
			_handle_job_node(interactable)


func _use_hardlight_gate() -> void:
	if GameState.get_world_flag("atrium_gate_opened", false):
		hud.show_dialogue("Hardlight Gate Panel", "Already active. The bridge is holding. Do not ask the floor pretending to be floor how it feels about this.")
		return
	GameState.set_world_flag("atrium_gate_opened", true)
	_spawn_hardlight_bridge()
	if _security_node != null and is_instance_valid(_security_node):
		_security_node.queue_free()
		_security_node = null
	hud.show_dialogue("Hardlight Gate Panel", "A strip of hardlight extrudes across the gap with the confidence of a system that has not been told the floor is gone. The security node loses its position advantage and stops being relevant.")
	hud.push_log("hardlight bridge extended — security node offline")
	_refresh_hud()


func _spawn_hardlight_bridge() -> void:
	if _bridge_body != null and is_instance_valid(_bridge_body):
		return
	_bridge_body = _add_box("HardlightBridge", Vector3(9, 0.25, 2.2), Vector3(-0.5, 1.35, -5.0), _mat_hardlight)


func _handle_hub_node(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"hub_debris_pile_1", "hub_debris_pile_2", "hub_debris_pile_3":
			var pile_flag := interactable.interactable_id.replace("hub_debris_", "hub_atrium_debris_") + "_cleared"
			_clear_debris_pile(interactable, pile_flag)
		"store_4_terminal":
			if bool(GameState.get_world_flag("store_4_claimed", false)):
				hud.show_dialogue("Store 4 Terminal", "Already wiped. Velvet Coil is making it something worth having. The shelving situation is improving.")
				return
			if not GameState.is_quest_started("hub_store_4"):
				hud.show_dialogue("Store 4 Terminal", "Old corporate squatter data still on this terminal. Velvet Coil at the Faded Atrium has context on what needs clearing.")
				return
			GameState.mark_quest_objective("hub_store_4", "store_4_cleared")
			if GameState.can_complete_quest("hub_store_4"):
				GameState.complete_quest("hub_store_4")
			interactable.queue_free()
			focused_interactable = null
			_update_prompt()
			hud.show_dialogue("Store 4 Terminal", "The squatter partition wipes clean. Store 4 is empty and legal, which is either a fresh start or a threat depending on who is counting.")
			hud.push_log("store 4 terminal wiped")
			GameState.set_world_flag("_pending_arrival_text", "Store 4 is mine now. The acoustics are acceptable. The data I wiped was less interesting than expected, which is always the way.")
			GameState.set_world_flag("_pending_arrival_speaker", "Velvet Coil")
			_refresh_hud()


func _clear_debris_pile(interactable: WardInteractable, pile_flag: String) -> void:
	if bool(GameState.get_world_flag(pile_flag, false)):
		hud.show_dialogue("Debris Pile", "Already cleared. Three down. The atrium has floor again.")
		return
	if not GameState.is_quest_started("hub_clear_court"):
		hud.show_dialogue("Debris Pile", "Structural debris from the ceiling collapse. Ladderboy at the Faded Atrium has a plan for clearing the atrium.")
		return
	GameState.set_world_flag(pile_flag, true)
	interactable.queue_free()
	focused_interactable = null
	_update_prompt()
	var done_1 := bool(GameState.get_world_flag("hub_atrium_debris_pile_1_cleared", false))
	var done_2 := bool(GameState.get_world_flag("hub_atrium_debris_pile_2_cleared", false))
	var done_3 := bool(GameState.get_world_flag("hub_atrium_debris_pile_3_cleared", false))
	var cleared_count := (1 if done_1 else 0) + (1 if done_2 else 0) + (1 if done_3 else 0)
	if cleared_count >= 3:
		GameState.mark_quest_objective("hub_clear_court", "atrium_cleared")
		if GameState.can_complete_quest("hub_clear_court"):
			GameState.complete_quest("hub_clear_court")
		hud.show_dialogue("Debris", "Third pile cleared. The atrium has floor again. Ladderboy will be insufferably correct about how this changes the traffic flow.")
		hud.push_log("hub atrium fully cleared")
		GameState.set_world_flag("_pending_arrival_text", "Atrium is clear. People are walking through it. I did not think we would get to that part. I was wrong, which is fine, I do it on purpose sometimes.")
		GameState.set_world_flag("_pending_arrival_speaker", "Ladderboy")
	else:
		hud.show_dialogue("Debris Pile", "Pile cleared. %d of 3 done. Keep going — the atrium has two more opinions about how the floor should look." % cleared_count)
		hud.push_log("atrium debris pile cleared (%d/3)" % cleared_count)
	_refresh_hud()


func _handle_job_node(interactable: WardInteractable) -> void:
	var active_job := GameState.get_active_job_data()
	if active_job.is_empty():
		hud.show_dialogue(interactable.display_name, "Not your relay. System X has paperwork about who gets to hear the customer-service choir.")
		return
	var job_id := GameState.active_job_id
	if GameState.is_job_objective_done(job_id):
		hud.show_dialogue(interactable.display_name, "Already recorded. Get back to Cooters before the relay starts charging for ambient noise.")
		return
	var required_id := str(GameState.get_job_data(job_id).get("objective_interactable", ""))
	if interactable.interactable_id != required_id:
		hud.show_dialogue(interactable.display_name, "Wrong node. Current job: %s" % str(active_job.get("objective", "")))
		return
	var item_name := str(active_job.get("objective_item", "Atrium Recording"))
	GameState.add_item(item_name)
	GameState.mark_job_objective_done(job_id)
	GameState.last_mission_result = "Completed objective: %s" % str(active_job.get("title", job_id))
	hud.show_dialogue(interactable.display_name, "%s captured. The relay was still broadcasting the old welcome message. It sounded like it meant it." % item_name)
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
		hud.set_objective("Collapsed Service Atrium: return to Cooters or Leak Street.")
	else:
		hud.set_objective("Collapsed Service Atrium: %s" % GameState.get_active_job_objective_text())


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
	_mat_floor = _make_mat(Color(0.42, 0.40, 0.44), Color(0.03, 0.02, 0.04), 0.10, "res://assets/textures/atrium/mall_floor_tile.png", Vector3(8, 8, 1))
	_mat_wall = _make_mat(Color(0.38, 0.36, 0.40), Color(0.02, 0.02, 0.03), 0.08, "res://assets/textures/atrium/mall_wall_panel.png", Vector3(6, 4, 1))
	_mat_catwalk = _make_mat(Color(0.50, 0.48, 0.52), Color(0.03, 0.03, 0.05), 0.12, "res://assets/textures/shared/metal_catwalk_grating.png", Vector3(6, 6, 1))
	_mat_sludge = _make_mat(Color(0.06, 0.10, 0.06, 0.85), Color(0.04, 0.14, 0.04), 0.6, "res://assets/textures/atrium/sludge_surface.png", Vector3(3, 3, 1))
	_mat_sludge.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hardlight = _make_mat(Color(0.05, 0.3, 0.9, 0.82), Color(0.1, 0.5, 1.0), 2.0, "", Vector3.ONE)
	_mat_hardlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_neon = _make_mat(Color(0.08, 0.04, 0.18), Color(0.4, 0.1, 1.0), 1.5, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_geometry() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.06, 0.14)
	env.ambient_light_energy = 0.80
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.03, 0.08)
	env.fog_density = 0.03
	env_node.environment = env
	add_child(env_node)

	# Outer shell — 20 wide × 24 long
	_add_box("Floor", Vector3(20, 0.35, 24), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("Ceiling", Vector3(20, 0.25, 24), Vector3(0, 5.0, 0), _mat_wall)
	_add_box("NorthWall", Vector3(20, 5.3, 0.35), Vector3(0, 2.3, -12), _mat_wall)
	_add_box("SouthWall", Vector3(20, 5.3, 0.35), Vector3(0, 2.3, 12), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 5.3, 24), Vector3(-10, 2.3, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 5.3, 24), Vector3(10, 2.3, 0), _mat_wall)

	# Sludge gap visual — dark organic surface in center area (x -4..4, z -9..1)
	var sludge_visual := MeshInstance3D.new()
	sludge_visual.name = "SludgeGapSurface"
	var sludge_mesh := BoxMesh.new()
	sludge_mesh.size = Vector3(8, 0.05, 10)
	sludge_visual.mesh = sludge_mesh
	sludge_visual.position = Vector3(0, 0.02, -4)
	sludge_visual.set_surface_override_material(0, _mat_sludge)
	add_child(sludge_visual)

	# Sludge hazard Area3D — 4 hp/s when player.y < 1.2
	# Sludge gap covers center x -4..4, z -9..1. Catwalk and bridge lifts player above threshold.
	_add_damage_zone("SludgeGapHazard", Vector3(8, 3, 10), Vector3(0, 0, -4))

	# Main catwalk — elevated deck spanning full width at z -5..-12 (surface y = 2.0)
	# Route 1 and Route 3 end here. Security node blocks south approach at catwalk center.
	_add_box("MainCatwalk", Vector3(20, 0.28, 7), Vector3(0, 1.86, -8.5), _mat_catwalk)

	# South ramp — Route 1 entry. Rises from ground at z ≈ 4 to catwalk at z ≈ -3 (span 7, rise 2.0m).
	# atan(2.0/7) ≈ 0.278 rad. Center at (0, 1.0, 0.5).
	_add_box("SouthRamp", Vector3(4, 0.3, 7.3), Vector3(0, 1.0, 0.5), _mat_catwalk, Vector3(0.278, 0, 0))

	# NE ramp — Route 2 (east hatch passage). From east ground (z ≈ -2) up to catwalk (z ≈ -5, span 3).
	# atan(2.0/3) ≈ 0.588 rad. Center at (7, 1.0, -3.5).
	_add_box("NERamp", Vector3(4, 0.3, 3.6), Vector3(7, 1.0, -3.5), _mat_catwalk, Vector3(0.588, 0, 0))

	# NW ramp — Route 3 (hardlight bridge approach). Mirror of NE ramp on west side.
	_add_box("NWRamp", Vector3(4, 0.3, 3.6), Vector3(-7, 1.0, -3.5), _mat_catwalk, Vector3(0.588, 0, 0))

	# Interior east wall — defines east hatch passage (Route 2 lane). Runs from south to gap.
	_add_box("EastHatchWall", Vector3(0.35, 5.3, 14), Vector3(4.5, 2.3, 0.5), _mat_wall)

	# Hardlight gate panel — Route 3 environmental. West ground, accessible before crossing sludge.
	_add_interactable("hardlight_gate_panel", "Hardlight Gate Panel", "Press E: extend hardlight bridge", Vector3(-8.5, 0.95, -2.0), Color(0.2, 0.4, 1.0))

	# Hub quest nodes — debris piles and Store 4 terminal. Only spawn if not yet cleared.
	if not GameState.get_world_flag("hub_atrium_debris_pile_1_cleared"):
		_add_interactable("hub_debris_pile_1", "Debris Pile", "Press E: clear debris (1/3)", Vector3(7.5, 0.95, 5.0), Color(0.65, 0.52, 0.32))
	if not GameState.get_world_flag("hub_atrium_debris_pile_2_cleared"):
		_add_interactable("hub_debris_pile_2", "Debris Pile", "Press E: clear debris (2/3)", Vector3(-7.0, 0.95, 4.0), Color(0.65, 0.52, 0.32))
	if not GameState.get_world_flag("hub_atrium_debris_pile_3_cleared"):
		_add_interactable("hub_debris_pile_3", "Debris Pile", "Press E: clear debris (3/3)", Vector3(0.0, 0.95, 8.5), Color(0.65, 0.52, 0.32))
	if not GameState.get_world_flag("store_4_claimed"):
		_add_interactable("store_4_terminal", "Store 4 Terminal", "Press E: wipe terminal data", Vector3(8.5, 0.95, -0.5), Color(0.1, 0.6, 0.8))

	# Relay node — north end of catwalk. The hardlight bridge and NW ramp give a clean approach from west.
	_add_interactable("atrium_relay_node", "Atrium Relay", "Press E: record relay pulse", Vector3(-2, 2.15, -10.5), Color(0.6, 0.2, 1.0))

	_add_shelter(Vector3(7, 0.9, 7.0))
	_add_rain_leak(Vector3(-7.5, 1.4, 3.0))
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 11.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -11.1), Color(0.08, 1.0, 0.45))
	_add_security_node(Vector3(0.0, 2.0, -5.5))
	_add_splice(Vector3(-3.0, 1.05, 5.0))
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
			_in_sludge = true
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_in_sludge = false
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
	add_child(splice)


func _add_lights() -> void:
	for data: Array in [
		[Vector3(-2, 3.2, -10.5), Color(0.6, 0.2, 1.0), 2.0],
		[Vector3(-8.5, 2.5, -2.0), Color(0.2, 0.4, 1.0), 1.4],
		[Vector3(7, 2.5, -3.5), Color(0.5, 0.4, 0.8), 1.2],
		[Vector3(0, 3.2, -8.5), Color(0.4, 0.3, 0.7), 1.6],
		[Vector3(7, 2.5, 7.0), Color(0.5, 0.4, 0.6), 1.0],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = 9.0
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
