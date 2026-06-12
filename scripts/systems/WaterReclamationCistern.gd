extends Node3D

# Water Reclamation Cistern — flooded utility reservoir and pump service loop.
# Job: cistern_pump_heart  Objective: cistern_filter_core_node
#
# Layout:
#   1. Entry Chamber (south) — spawn, shelter, rain leak
#   2. Main Cistern Basin (center) — reservoir ring, filter beds, pressure vents, security node
#   3. Filtration Gallery (east wing) — pipe racks, filter drums, LAN tap junction
#   4. Pump Control Room (NW) — pump altar, filter core objective, hub conduit junction
#   5. Overhead Pipe Racks (north) — utility detail, not a walkable route
#
# Three routes to the filter core:
#   Route 1 — Combat:       entry → main hall east walkway, fight security node, north to pump room
#   Route 2 — Filter beds:  entry → stepping stones across center, west walkway, pump room
#   Route 3 — Pump valve:   entry → west walkway, use pump valve (disables water + despawns node), cross freely
#   Route 4 — Gallery flank: entry → east into filtration gallery, loop back through the main cistern

const COOTERS_INTERIOR_SCENE := "res://scenes/levels/CootersInterior.tscn"
const DISTRICT_SCENE := "res://scenes/levels/SubSubBasementDistrict.tscn"
const SECURITY_NODE_SCENE := preload("res://scenes/enemies/SecurityNode.tscn")
const SPLICE_SCENE := preload("res://scenes/enemies/Splice.tscn")
const ATLAS_BLACK_ALPHA_CUTOFF := 0.03

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
var _mat_pipe: StandardMaterial3D
var _mat_catwalk: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_warning: StandardMaterial3D
var _mat_steam: StandardMaterial3D
var _atlas_cutout_cache: Dictionary = {}


func _ready() -> void:
	_repair_hub_cistern_flag_drift()
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Water Reclamation Cistern", "Travel event: %s. The water here smells like it has a legal team." % last_event)
	hud.present_event.call_deferred("travel", true)
	hud.push_log("water reclamation cistern reached")
	EventDeckSystem.add_card("splice_cistern_return")


func _repair_hub_cistern_flag_drift() -> void:
	if GameState.is_quest_completed("hub_cistern"):
		return
	if bool(GameState.get_world_flag("hub_cistern_connected", false)):
		GameState.set_world_flag("hub_cistern_connected", false)
		if not GameState.is_quest_started("hub_cistern"):
			GameState.start_quest("hub_cistern")
		GameState.last_mission_result = "Recovered bad cistern state: conduit still needs seating"


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
		"cistern_water_sample":
			_collect_water_sample(interactable)
		"cistern_loot_crate":
			_open_loot_crate(interactable)
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


func _collect_water_sample(interactable: WardInteractable) -> void:
	if GameState.has_item("Water Sample"):
		hud.show_dialogue("Water Sample", "Already collected. Your pockets are not a laboratory.")
		return
	GameState.add_item("Water Sample")
	interactable.queue_free()
	focused_interactable = null
	_update_prompt()
	hud.show_dialogue("Water Sample", "The sample vial fills with something that looks like water and smells like a legal settlement. Marbles might want to know about this.")
	hud.push_log("water sample collected")
	_refresh_hud()


func _open_loot_crate(interactable: WardInteractable) -> void:
	if GameState.has_item("Cistern Salvage Scrap"):
		hud.show_dialogue("Loot Crate", "Already picked clean. The crate is now officially furniture.")
		return
	GameState.add_item("Cistern Salvage Scrap")
	GameState.add_item("Ammo Cache")
	interactable.queue_free()
	focused_interactable = null
	_update_prompt()
	hud.show_dialogue("Loot Crate", "Inside: copper fittings, a sealed capacitor, and a handful of rounds that survived the humidity. Not bad for something floating in reclaimed runoff.")
	hud.push_log("loot crate opened")
	_refresh_hud()


func _handle_hub_node(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"hub_cistern_conduit":
			if GameState.get_world_flag("hub_cistern_connected"):
				if not GameState.is_quest_completed("hub_cistern"):
					if not GameState.is_quest_started("hub_cistern"):
						GameState.start_quest("hub_cistern")
					GameState.mark_quest_objective("hub_cistern", "hub_cistern_connected")
					GameState.complete_quest("hub_cistern")
					hud.show_dialogue("Hub Water Conduit", "The flow indicator is already green. GhostTerm logs the conduit as seated and the clinic line as connected. Vera can stop haunting the plumbing now.")
					hud.push_log("hub cistern conduit verified")
					_refresh_hud()
					return
				hud.show_dialogue("Hub Water Conduit", "Already connected. Clean water is running to the clinic. Vera stopped mentioning the pipe smell, which means things are better.")
				return
			if not GameState.is_quest_started("hub_cistern"):
				hud.show_dialogue("Hub Water Conduit", "This teal-marked junction feeds the Faded Atrium clinic line. Vera needs to authorize the conduit run before you start seating pipe like a well-meaning hazard.")
				return
			GameState.mark_quest_objective("hub_cistern", "hub_cistern_connected")
			if GameState.can_complete_quest("hub_cistern"):
				GameState.complete_quest("hub_cistern")
			AudioDirector.play_sfx("generator_restored", -2.0)
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
			AudioDirector.play_sfx("lan_restore", -1.0)
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
	if str(active_job.get("objective_type", "find")) == "deliver":
		# Drop-off: hand over the carried parcel (payout consumes it); no duplicate minted.
		if not GameState.has_item(item_name):
			hud.show_dialogue(interactable.display_name, "You're meant to be carrying %s. Come back when it's actually on you." % item_name)
			return
	else:
		GameState.add_item(item_name)   # find: recover the marked item here
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
	_mat_water = _make_mat(Color(0.02, 0.28, 0.55, 0.72), Color(0.0, 0.45, 0.9), 1.1, "res://assets/textures/water_surface.png", Vector3(4, 4, 1))
	_mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_filter_bed = _make_mat(Color(0.55, 0.52, 0.44), Color(0.06, 0.06, 0.03), 0.14, "res://assets/textures/cistern/filter_bed_aggregate.png", Vector3(4, 4, 1))
	_mat_neon = _make_mat(Color(0.02, 0.08, 0.18), Color(0.0, 0.5, 1.0), 1.5, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_pipe = _make_mat(Color(0.42, 0.36, 0.30), Color(0.04, 0.02, 0.01), 0.06, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(3, 3, 1))
	_mat_catwalk = _make_mat(Color(0.50, 0.48, 0.52), Color(0.03, 0.03, 0.05), 0.12, "res://assets/textures/shared/metal_catwalk_grating.png", Vector3(6, 6, 1))
	_mat_metal = _make_mat(Color(0.40, 0.42, 0.44), Color(0.02, 0.04, 0.06), 0.08, "res://assets/textures/scuffed_machine_metal.png", Vector3(2, 2, 1))
	_mat_warning = _make_mat(Color(0.90, 0.42, 0.02), Color(1.0, 0.35, 0.0), 1.2, "", Vector3.ONE)
	_mat_steam = _make_mat(Color(0.55, 0.90, 1.0, 0.32), Color(0.25, 0.75, 1.0), 0.7, "", Vector3.ONE)
	_mat_steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


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

	_build_entry_chamber()
	_build_main_cistern_hall()
	_build_filtration_gallery()
	_build_pump_control_room()
	_build_upper_catwalk()
	_build_prop_decals()
	_build_interactables()
	_build_enemies()
	_build_exits()
	_add_lights()
	_add_toxic_rain_controller()


func _build_entry_chamber() -> void:
	# South entry pocket: x -5..5, z 8..16. A short vestibule before the main hall.
	_add_box("EntryFloor", Vector3(10, 0.35, 8), Vector3(0, -0.2, 12), _mat_floor)
	_add_box("EntryCeiling", Vector3(10, 0.25, 8), Vector3(0, 4.0, 12), _mat_wall)
	_add_box("EntrySouthWall", Vector3(10, 4.3, 0.35), Vector3(0, 1.9, 16), _mat_wall)
	_add_box("EntryWestWall", Vector3(0.35, 4.3, 8), Vector3(-5, 1.9, 12), _mat_wall)
	_add_box("EntryEastWall", Vector3(0.35, 4.3, 8), Vector3(5, 1.9, 12), _mat_wall)
	# Gap in north wall at x -2..2 for main hall entry (handled by main hall south wall)
	_add_box("EntryNorthWallW", Vector3(3, 4.3, 0.35), Vector3(-3.5, 1.9, 8), _mat_wall)
	_add_box("EntryNorthWallE", Vector3(3, 4.3, 0.35), Vector3(3.5, 1.9, 8), _mat_wall)
	# Shelter in entry
	_add_shelter(Vector3(-3, 0.9, 14))
	_add_rain_leak(Vector3(3.5, 1.4, 13))


func _build_main_cistern_hall() -> void:
	# Main cistern: a low reservoir ring, not a collapsed mall deck.
	_add_box("CisternFloor", Vector3(20, 0.35, 20), Vector3(0, -0.2, -2), _mat_floor)
	_add_box("CisternCeiling", Vector3(20, 0.25, 20), Vector3(0, 4.0, -2), _mat_wall)
	_add_box("CisternNorthWall", Vector3(20, 4.3, 0.35), Vector3(0, 1.9, -12), _mat_wall)
	# South wall has gap for entry chamber (x -2..2)
	_add_box("CisternSouthWallW", Vector3(3, 4.3, 0.35), Vector3(-3.5, 1.9, 8), _mat_wall)
	_add_box("CisternSouthWallE", Vector3(3, 4.3, 0.35), Vector3(3.5, 1.9, 8), _mat_wall)
	# West wall has gap for pump room entry (z -6..-10, x=-10)
	_add_box("CisternWestWallS", Vector3(0.35, 4.3, 8), Vector3(-10, 1.9, 4), _mat_wall)
	_add_box("CisternWestWallN", Vector3(0.35, 4.3, 8), Vector3(-10, 1.9, -8), _mat_wall)
	# East wall has gap for filtration gallery entry (z -6..-2, x=10)
	_add_box("CisternEastWallN", Vector3(0.35, 4.3, 6), Vector3(10, 1.9, -11), _mat_wall)
	_add_box("CisternEastWallS", Vector3(0.35, 4.3, 10), Vector3(10, 1.9, 3), _mat_wall)

	var water_visual := MeshInstance3D.new()
	water_visual.name = "WaterSurface"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(8, 0.04, 18)
	water_visual.mesh = water_mesh
	water_visual.position = Vector3(0, 0.02, -2)
	water_visual.set_surface_override_material(0, _mat_water)
	add_child(water_visual)

	_add_damage_zone("WaterChannelHazard", Vector3(8, 3, 18), Vector3(0, 0, -2))

	# Raised service ring around the basin. It reads as reservoir infrastructure,
	# while the stepping stones remain the only deliberate center crossing.
	_add_box("ServiceRingEast", Vector3(2.2, 0.22, 18.0), Vector3(6.1, 0.08, -2), _mat_catwalk)
	_add_box("ServiceRingWest", Vector3(2.2, 0.22, 18.0), Vector3(-6.1, 0.08, -2), _mat_catwalk)
	_add_box("ServiceRingSouth", Vector3(16.5, 0.22, 1.6), Vector3(0, 0.08, 6.4), _mat_catwalk)
	_add_box("ServiceRingNorth", Vector3(16.5, 0.22, 1.6), Vector3(0, 0.08, -10.4), _mat_catwalk)

	for z_val: float in [5.0, 1.0, -3.0, -7.0]:
		_add_box("FilterBed", Vector3(2.2, 0.5, 2.2), Vector3(0, 0.25, z_val), _mat_filter_bed)

	# Old luxury fountain pieces have been repurposed as rough filters.
	for data: Array in [
		[Vector3(-2.7, 0.55, 4.8), 0.42, 1.1],
		[Vector3(2.7, 0.55, 0.9), 0.34, 0.9],
		[Vector3(-2.7, 0.55, -3.2), 0.38, 1.0],
		[Vector3(2.7, 0.55, -7.0), 0.30, 0.8],
	]:
		_add_visual_cylinder("FountainFilterColumn", float(data[1]), float(data[2]), data[0] as Vector3, _mat_filter_bed)
		_add_box("FilterPourLip", Vector3(1.2, 0.12, 0.35), (data[0] as Vector3) + Vector3(0, 0.65, 0.45), _mat_metal)

	# Pressure-burst markers and steam make this room feel mechanical rather than mall-like.
	for pos: Vector3 in [Vector3(-3.6, 0.95, 2.6), Vector3(3.7, 1.0, -1.8), Vector3(-3.5, 0.9, -6.2)]:
		_add_visual_cylinder("PressureSteam", 0.18, 2.2, pos, _mat_steam)
		_add_box("PressureWarningStripe", Vector3(1.2, 0.1, 0.18), pos + Vector3(0, -0.65, 0), _mat_warning)

	for pos: Vector3 in [Vector3(-9.5, 2.8, -2), Vector3(9.5, 3.2, -2), Vector3(-9.5, 1.4, -2)]:
		var pipe := MeshInstance3D.new()
		pipe.name = "PipeRun"
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.18
		pipe_mesh.bottom_radius = 0.18
		pipe_mesh.height = 18
		pipe.mesh = pipe_mesh
		pipe.position = pos
		pipe.rotation = Vector3(0, 0, PI / 2)
		pipe.set_surface_override_material(0, _mat_pipe)
		add_child(pipe)


func _build_filtration_gallery() -> void:
	# East wing: x 10..18, z -8..0. Narrow pipe gallery.
	_add_box("GalleryFloor", Vector3(9, 0.35, 9), Vector3(14.5, -0.2, -4), _mat_floor)
	_add_box("GalleryCeiling", Vector3(9, 0.25, 9), Vector3(14.5, 4.0, -4), _mat_wall)
	_add_box("GalleryEastWall", Vector3(0.35, 4.3, 9), Vector3(19, 1.9, -4), _mat_wall)
	_add_box("GalleryNorthWall", Vector3(9, 4.3, 0.35), Vector3(14.5, 1.9, -8.5), _mat_wall)
	_add_box("GallerySouthWall", Vector3(9, 4.3, 0.35), Vector3(14.5, 1.9, 0.5), _mat_wall)
	# West wall gap at z -6..-2 aligns with main cistern east wall gap (x=10)
	_add_box("GalleryWestWallN", Vector3(0.35, 4.3, 2.5), Vector3(10, 1.9, -7.25), _mat_wall)
	_add_box("GalleryWestWallS", Vector3(0.35, 4.3, 4.5), Vector3(10, 1.9, 1.75), _mat_wall)

	# Pipe racks along gallery walls
	for x_off: float in [11.0, 17.0]:
		var rack := MeshInstance3D.new()
		rack.name = "PipeRack"
		var rack_mesh := BoxMesh.new()
		rack_mesh.size = Vector3(0.3, 2.5, 7)
		rack.mesh = rack_mesh
		rack.position = Vector3(x_off, 1.25, -4)
		rack.set_surface_override_material(0, _mat_pipe)
		add_child(rack)

	for z_val: float in [-7.0, -5.0, -3.0, -1.0]:
		_add_visual_cylinder("FilterDrum", 0.45, 1.4, Vector3(14.5, 0.7, z_val), _mat_filter_bed, Vector3(PI / 2, 0, 0))
		_add_box("GalleryWarningStripe", Vector3(5.8, 0.08, 0.18), Vector3(14.0, 0.1, z_val + 0.7), _mat_warning)


func _build_pump_control_room() -> void:
	# NW pocket: x -16..-10, z -12..-6. Enclosed pump room.
	_add_box("PumpFloor", Vector3(6, 0.35, 6), Vector3(-13, -0.2, -9), _mat_floor)
	_add_box("PumpCeiling", Vector3(6, 0.25, 6), Vector3(-13, 4.0, -9), _mat_wall)
	_add_box("PumpNorthWall", Vector3(6, 4.3, 0.35), Vector3(-13, 1.9, -12), _mat_wall)
	_add_box("PumpWestWall", Vector3(0.35, 4.3, 6), Vector3(-16, 1.9, -9), _mat_wall)
	# South wall split for entry from main hall west walkway
	_add_box("PumpSouthWallW", Vector3(2, 4.3, 0.35), Vector3(-15, 1.9, -6), _mat_wall)
	_add_box("PumpSouthWallE", Vector3(2, 4.3, 0.35), Vector3(-11, 1.9, -6), _mat_wall)
	# East wall split for upper catwalk connection
	_add_box("PumpEastWallN", Vector3(0.35, 4.3, 2), Vector3(-10, 1.9, -11), _mat_wall)
	_add_box("PumpEastWallS", Vector3(0.35, 4.3, 2), Vector3(-10, 1.9, -7), _mat_wall)

	# Connecting passage from main cistern west gap to pump room south gap
	_add_box("PassageFloor", Vector3(6, 0.35, 6), Vector3(-13, -0.2, -3), _mat_floor)
	_add_box("PassageCeiling", Vector3(6, 0.25, 6), Vector3(-13, 4.0, -3), _mat_wall)
	_add_box("PassageWestWall", Vector3(0.35, 4.3, 6), Vector3(-16, 1.9, -3), _mat_wall)
	# East wall of passage is the main cistern west wall (already has gap)
	# South wall of passage is main cistern interior (open)
	# North wall of passage is the pump room south wall (already has gap)

	# Pump machinery props
	_add_box("PumpHousing", Vector3(2.6, 1.8, 1.6), Vector3(-14, 0.9, -10), _mat_metal)
	_add_visual_cylinder("PumpTank", 0.75, 2.3, Vector3(-12, 1.15, -10.8), _mat_metal)
	_add_visual_cylinder("PressureGauge", 0.28, 0.14, Vector3(-13.0, 1.7, -8.1), _mat_warning, Vector3(PI / 2, 0, 0))
	_add_box("BottledWaterShrineShelf", Vector3(2.6, 0.18, 0.8), Vector3(-15.0, 0.65, -7.1), _mat_metal)
	for x_off: float in [-15.8, -15.2, -14.6]:
		_add_visual_cylinder("ShrineBottle", 0.12, 0.65, Vector3(x_off, 1.05, -7.1), _mat_water)


func _build_upper_catwalk() -> void:
	# Decorative pipe supports only. A walkable elevated route does not fit the
	# existing wall openings, so keep this as believable cistern infrastructure.
	for x_pos: float in [-6.0, 0.0, 6.0]:
		_add_box("NorthPipeBracket", Vector3(1.6, 0.16, 0.45), Vector3(x_pos, 2.45, -11.65), _mat_metal)
	for x_pos: float in [-7.5, -2.5, 2.5, 7.5]:
		var pipe := MeshInstance3D.new()
		pipe.name = "NorthOverheadPipe"
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.12
		pipe_mesh.bottom_radius = 0.12
		pipe_mesh.height = 3.5
		pipe.mesh = pipe_mesh
		pipe.position = Vector3(x_pos, 2.7, -11.75)
		pipe.rotation = Vector3(0, 0, PI / 2)
		pipe.set_surface_override_material(0, _mat_pipe)
		add_child(pipe)


func _build_interactables() -> void:
	# Pump valve — Route 3 environmental. West walkway, south of pump room.
	_add_interactable("pump_valve_panel", "Pump Valve", "Press E: open pump valve", Vector3(-7, 0.95, 2.0), Color(0.0, 0.6, 1.0))

	# Hub quest nodes
	if not GameState.is_quest_completed("hub_cistern"):
		_add_box("HubConduitGuideMast", Vector3(0.24, 2.6, 0.24), Vector3(-6.2, 1.3, -8.5), _mat_neon)
		_add_box("HubConduitGuideSign", Vector3(2.8, 0.55, 0.14), Vector3(-6.2, 2.65, -8.5), _mat_warning)
		_add_box("HubConduitFloorPlate", Vector3(2.8, 0.08, 2.0), Vector3(-6.2, 0.05, -8.5), _mat_warning)
		_add_interactable("hub_cistern_conduit", "Hub Water Conduit", "Press E: install hub water conduit", Vector3(-6.2, 0.95, -8.5), Color(0.1, 1.0, 0.65))
	if not GameState.get_world_flag("hub_lan_restored"):
		_add_interactable("hub_lan_tap", "LAN Tap Junction", "Press E: splice LAN tap", Vector3(14, 0.95, -4), Color(0.2, 0.8, 1.0))

	# Job node — inside pump room
	_add_interactable("cistern_filter_core_node", "Cistern Filter Core", "Press E: recover filter core", Vector3(-13, 0.95, -10), Color(0.0, 1.0, 0.8))

	# Optional content
	_add_interactable("cistern_water_sample", "Water Sample Point", "Press E: collect water sample", Vector3(3, 0.95, -3), Color(0.0, 0.8, 0.6))
	_add_interactable("cistern_loot_crate", "Loot Crate", "Press E: open", Vector3(15, 0.95, -2), Color(0.9, 0.7, 0.2))


func _build_enemies() -> void:
	# Contested location: faction-themed, threat-scaled enemy profile (refactor §5).
	EnemyLayouts.spawn_profile(self, "water_reclamation_cistern",
		GameState.get_active_threat_band(), GameState.get_active_rival_faction())


func _build_exits() -> void:
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 15.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -11.1), Color(0.08, 1.0, 0.45))


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


func _add_visual_cylinder(node_name: String, radius: float, height: float, world_position: Vector3, material: Material, world_rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = world_position
	visual.rotation = world_rotation
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	visual.mesh = mesh
	visual.set_surface_override_material(0, material)
	add_child(visual)
	return visual


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
	# Interactive beacon: a compact glowing core inside a flat halo ring, lit by a soft point
	# light — reads as a deliberate "interact here" marker instead of a blown-out solid disc.
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = color.darkened(0.3)
	core_mat.emission_enabled = true
	core_mat.emission = color
	core_mat.emission_energy_multiplier = 0.9
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.12
	core_mesh.height = 0.24
	var core := MeshInstance3D.new()
	core.name = "BeaconCore"
	core.mesh = core_mesh
	core.set_surface_override_material(0, core_mat)
	area.add_child(core)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = color.darkened(0.5)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 0.6
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.26
	ring_mesh.outer_radius = 0.31
	var ring := MeshInstance3D.new()
	ring.name = "BeaconRing"
	ring.mesh = ring_mesh
	ring.set_surface_override_material(0, ring_mat)
	area.add_child(ring)

	var beacon_light := OmniLight3D.new()
	beacon_light.light_color = color
	beacon_light.light_energy = 1.1
	beacon_light.omni_range = 2.6
	area.add_child(beacon_light)
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
	# Lit doorway: an emissive trim frame behind a textured metal hatch, instead of one flat
	# solid-color panel.
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = color.darkened(0.3)
	frame_mat.emission_enabled = true
	frame_mat.emission = color
	frame_mat.emission_energy_multiplier = 1.0
	var frame := MeshInstance3D.new()
	frame.name = "ExitFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(3.7, 1.9, 0.08)
	frame.mesh = frame_mesh
	frame.position = Vector3(0.0, 0.0, -0.05)
	frame.set_surface_override_material(0, frame_mat)
	exit.add_child(frame)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.4, 1.6, 0.12)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, _make_mat(color.darkened(0.6), color, 0.4, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(3, 2, 1)))
	exit.add_child(visual)


func _add_security_node(world_position: Vector3) -> void:
	var node := SECURITY_NODE_SCENE.instantiate()
	node.name = "SecurityNode"
	node.position = world_position
	node.persistence_id = _enemy_persistence_id("security_node", world_position)
	add_child(node)


func _add_splice(world_position: Vector3) -> void:
	var splice := SPLICE_SCENE.instantiate()
	splice.name = "Splice"
	splice.position = world_position
	splice.persistence_id = _enemy_persistence_id("splice", world_position)
	splice.add_to_group("splice")
	splice.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice)


func _on_splice_item_dropped(item_name: String) -> void:
	hud.push_log("splice dropped: %s" % item_name.replace("_", " "))
	hud.show_system_message("FOUND " + item_name.to_upper().replace("_", " "))


func _enemy_persistence_id(kind: String, pos: Vector3) -> String:
	return "water_reclamation_cistern:%s:%.2f:%.2f:%.2f" % [kind, pos.x, pos.y, pos.z]


func _add_lights() -> void:
	for data: Array in [
		# Entry chamber
		[Vector3(0, 2.5, 12), Color(0.1, 0.6, 0.8), 1.2],
		[Vector3(-3, 2.5, 14), Color(0.1, 0.6, 0.8), 1.0],
		# Main hall
		[Vector3(-7, 2.5, 2), Color(0.0, 0.6, 1.0), 1.4],
		[Vector3(7, 2.5, -5), Color(0.0, 0.75, 1.0), 1.4],
		[Vector3(0, 2.5, -2), Color(0.0, 0.5, 1.0), 1.0],
		[Vector3(-7, 2.5, -8), Color(0.0, 0.5, 0.8), 1.2],
		# Filtration gallery
		[Vector3(14, 2.5, -4), Color(0.0, 0.4, 0.8), 1.0],
		[Vector3(14, 2.5, -6), Color(0.0, 0.3, 0.7), 0.8],
		# Pump control room
		[Vector3(-13, 2.5, -9), Color(0.0, 1.0, 0.8), 1.8],
		[Vector3(-13, 2.5, -11), Color(0.0, 0.8, 0.6), 1.2],
		# Connecting passage
		[Vector3(-13, 2.5, -3), Color(0.0, 0.5, 0.8), 1.0],
		# Upper catwalk
		[Vector3(0, 3.5, -11), Color(0.0, 0.6, 1.0), 1.0],
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


# Copies one 4x4 atlas cell into a texture and keys near-black pixels transparent, matching
# Leak Street's atlas panels so signage does not carry square black backgrounds.
func _atlas_cutout_texture(path: String, col: int, row: int) -> Texture2D:
	var cache_key := "%s:%d:%d" % [path, col, row]
	if _atlas_cutout_cache.has(cache_key):
		return _atlas_cutout_cache[cache_key]
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	var source := texture.get_image()
	if source == null:
		return texture
	var cell_size := Vector2i(floori(float(source.get_width()) / 4.0), floori(float(source.get_height()) / 4.0))
	var crop_rect := Rect2i(Vector2i(col * cell_size.x, row * cell_size.y), cell_size).intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return texture
	var cutout := Image.create(crop_rect.size.x, crop_rect.size.y, false, Image.FORMAT_RGBA8)
	for y in range(crop_rect.size.y):
		for x in range(crop_rect.size.x):
			var color := source.get_pixel(crop_rect.position.x + x, crop_rect.position.y + y)
			if maxf(maxf(color.r, color.g), color.b) <= ATLAS_BLACK_ALPHA_CUTOFF:
				color.a = 0.0
			cutout.set_pixel(x, y, color)
	var cutout_texture := ImageTexture.create_from_image(cutout)
	_atlas_cutout_cache[cache_key] = cutout_texture
	return cutout_texture


# Flat atlas sign rendered as a Sprite3D cutout so near-black atlas backgrounds vanish.
# `facing` aims the front into the room.
func _add_atlas_decal(node_name: String, atlas_path: String, col: int, row: int, width: float, height: float, world_position: Vector3, facing: String, _energy := 1.0, extra_yaw_deg := 0.0) -> void:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.position = world_position
	var yaw := 0.0
	match facing:
		"z-": yaw = 180.0
		"x+": yaw = 90.0
		"x-": yaw = -90.0
		_: yaw = 0.0
	sprite.rotation_degrees = Vector3(0, yaw + extra_yaw_deg, 0)
	sprite.texture = _atlas_cutout_texture(atlas_path, col, row)
	if sprite.texture != null:
		sprite.pixel_size = width / maxf(float(sprite.texture.get_width()), 1.0)
		var rendered_height := float(sprite.texture.get_height()) * sprite.pixel_size
		if rendered_height > 0.0:
			sprite.scale.y = height / rendered_height
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.add_to_group("district_atlas_panel")
	add_child(sprite)


# Corporate stencils, gauges and hazard signage from cistern_props_atlas, flush on walls.
func _build_prop_decals() -> void:
	const ATLAS := "res://assets/textures/cistern_props_atlas.png"
	# [position, width, height, facing, col, row]
	for data: Array in [
		[Vector3(-3.0, 2.6, -11.78), 1.8, 1.8, "z+", 2, 0],   # WAN MOA TORAI stencil — cistern north wall
		[Vector3(3.0, 2.6, -11.78), 1.4, 1.4, "z+", 3, 0],    # PIPE ID WTR-7A tag — north wall
		[Vector3(9.78, 2.4, 3.0), 1.3, 1.3, "x-", 0, 2],      # POTABLE? sign — cistern east wall
		[Vector3(9.78, 2.4, 5.5), 1.4, 1.4, "x-", 3, 3],      # hazard diamond — east wall
		[Vector3(18.78, 2.5, -4.0), 1.5, 1.5, "x-", 1, 0],    # WATER LEVEL gauge — gallery east wall
		[Vector3(14.5, 2.6, -8.28), 1.4, 1.4, "z+", 1, 1],    # FILTER UNIT decal — gallery north wall
		[Vector3(-13.0, 2.6, -11.78), 1.3, 1.3, "z+", 2, 1],  # PSI gauge — pump room north wall
		[Vector3(-9.78, 2.3, -8.0), 1.2, 1.6, "x+", 2, 3],    # DEPTH(M) marker — cistern west wall
	]:
		_add_atlas_decal("PropDecal", ATLAS, int(data[4]), int(data[5]), float(data[1]), float(data[2]), data[0] as Vector3, str(data[3]))


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
