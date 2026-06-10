extends Node3D

# Collapsed Service Atrium — dead mall vertical collapse and relay deck.
# Job: atrium_relay_echo  Objective: atrium_relay_node
#
# Layout:
#   1. South Vestibule (spawn) — shelter, rain leak, entry corridor
#   2. Atrium Void (center) — sludge gap, hanging escalators, elevator shaft, broad south ramp
#   3. East Service Corridor (east wing) — back-of-house storage and ground flank
#   4. Relay Platform (north elevated) — old mall broadcast deck, Store 4, debris piles
#   5. West Maintenance Crawl (west wing) — low stealth shortcut to relay platform
#
# Three routes to the relay:
#   Route 1 — Combat:       vestibule → atrium void → broad south ramp to deck, fight security node, north to relay
#   Route 2 — East hatch:   vestibule → east corridor (ground, no sludge) → loop back to relay approach
#   Route 3 — West crawl:   vestibule → atrium void → west crawl corridor → emerges relay platform west (stealth)

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
var _in_sludge: bool = false
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_catwalk: StandardMaterial3D
var _mat_sludge: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_pipe: StandardMaterial3D
var _mat_banner: StandardMaterial3D
var _mat_storefront: StandardMaterial3D
var _mat_void: StandardMaterial3D
var _atlas_cutout_cache: Dictionary = {}


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Collapsed Service Atrium", "Travel event: %s. The old banners are still up. They say nothing useful about what the floor became." % last_event)
	hud.present_event.call_deferred("travel", true)
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


func _handle_interact() -> void:
	if focused_interactable != null:
		_dispatch_interactable(focused_interactable)
		return
	if focused_exit != null:
		get_tree().change_scene_to_file(focused_exit.target_scene)


func _dispatch_interactable(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"hub_debris_pile_1", "hub_debris_pile_2", "hub_debris_pile_3", "store_4_terminal":
			_handle_hub_node(interactable)
		"atrium_loot_crate":
			_open_loot_crate(interactable)
		_:
			_handle_job_node(interactable)


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


func _open_loot_crate(interactable: WardInteractable) -> void:
	if GameState.has_item("Atrium Salvage Cache"):
		hud.show_dialogue("Loot Crate", "Already opened. Some crates are just memories of crates.")
		return
	GameState.add_item("Atrium Salvage Cache")
	GameState.add_item("Ammo Cache")
	interactable.queue_free()
	focused_interactable = null
	_update_prompt()
	hud.show_dialogue("Loot Crate", "Inside: cable spools, a cracked relay housing, and a handful of rounds that survived the collapse. The spools might be useful to someone who fixes things.")
	hud.push_log("atrium loot crate opened")
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
	if str(active_job.get("objective_type", "find")) == "deliver":
		# Drop-off: hand over the carried parcel (payout consumes it); no duplicate minted.
		if not GameState.has_item(item_name):
			hud.show_dialogue(interactable.display_name, "You're meant to be carrying %s. Come back when it's actually on you." % item_name)
			return
	else:
		GameState.add_item(item_name)   # find: recover the marked item here
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
	_mat_neon = _make_mat(Color(0.08, 0.04, 0.18), Color(0.4, 0.1, 1.0), 1.5, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_metal = _make_mat(Color(0.40, 0.42, 0.44), Color(0.02, 0.04, 0.06), 0.08, "res://assets/textures/scuffed_machine_metal.png", Vector3(2, 2, 1))
	_mat_pipe = _make_mat(Color(0.42, 0.36, 0.30), Color(0.04, 0.02, 0.01), 0.06, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(3, 3, 1))
	_mat_banner = _make_mat(Color(0.62, 0.10, 0.38), Color(0.8, 0.05, 0.45), 0.7, "", Vector3.ONE)
	_mat_storefront = _make_mat(Color(0.12, 0.08, 0.16), Color(0.45, 0.18, 0.75), 1.0, "res://assets/textures/storefront_glass.png", Vector3(2, 2, 1))
	_mat_void = _make_mat(Color(0.005, 0.003, 0.008), Color(0.0, 0.0, 0.0), 0.0, "", Vector3.ONE)


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

	_build_south_vestibule()
	_build_atrium_void()
	_build_east_service_corridor()
	_build_relay_platform()
	_build_west_maintenance_crawl()
	_build_prop_decals()
	_build_interactables()
	_build_enemies()
	_build_exits()
	_add_lights()
	_add_toxic_rain_controller()


func _build_south_vestibule() -> void:
	_add_box("VestibuleFloor", Vector3(10, 0.35, 8), Vector3(0, -0.2, 12), _mat_floor)
	_add_box("VestibuleCeiling", Vector3(10, 0.25, 8), Vector3(0, 4.0, 12), _mat_wall)
	_add_box("VestibuleSouthWall", Vector3(10, 4.3, 0.35), Vector3(0, 1.9, 16), _mat_wall)
	_add_box("VestibuleWestWall", Vector3(0.35, 4.3, 8), Vector3(-5, 1.9, 12), _mat_wall)
	_add_box("VestibuleEastWall", Vector3(0.35, 4.3, 8), Vector3(5, 1.9, 12), _mat_wall)
	_add_box("VestibuleNorthWallW", Vector3(3, 4.3, 0.35), Vector3(-3.5, 1.9, 8), _mat_wall)
	_add_box("VestibuleNorthWallE", Vector3(3, 4.3, 0.35), Vector3(3.5, 1.9, 8), _mat_wall)
	_add_shelter(Vector3(-3, 0.9, 14))
	_add_rain_leak(Vector3(3.5, 1.4, 13))


func _build_atrium_void() -> void:
	_add_box("AtriumFloor", Vector3(20, 0.35, 18), Vector3(0, -0.2, 1), _mat_floor)
	_add_box("AtriumCeiling", Vector3(20, 0.25, 18), Vector3(0, 5.0, 1), _mat_wall)
	_add_box("AtriumSouthWallW", Vector3(3, 5.3, 0.35), Vector3(-3.5, 2.4, 8), _mat_wall)
	_add_box("AtriumSouthWallE", Vector3(3, 5.3, 0.35), Vector3(3.5, 2.4, 8), _mat_wall)
	_add_box("AtriumNorthWallW", Vector3(5, 5.3, 0.35), Vector3(-7.5, 2.4, -8), _mat_wall)
	_add_box("AtriumNorthWallE", Vector3(5, 5.3, 0.35), Vector3(7.5, 2.4, -8), _mat_wall)
	_add_box("AtriumWestWallS", Vector3(0.35, 5.3, 5), Vector3(-10, 2.4, 5.5), _mat_wall)
	_add_box("AtriumWestWallN", Vector3(0.35, 5.3, 6), Vector3(-10, 2.4, -5), _mat_wall)
	_add_box("AtriumEastWallS", Vector3(0.35, 5.3, 5), Vector3(10, 2.4, 5.5), _mat_wall)
	_add_box("AtriumEastWallN", Vector3(0.35, 5.3, 6), Vector3(10, 2.4, -5), _mat_wall)

	var sludge_visual := MeshInstance3D.new()
	sludge_visual.name = "SludgeGapSurface"
	var sludge_mesh := BoxMesh.new()
	sludge_mesh.size = Vector3(8, 0.05, 10)
	sludge_visual.mesh = sludge_mesh
	sludge_visual.position = Vector3(0, 0.02, 1)
	sludge_visual.set_surface_override_material(0, _mat_sludge)
	add_child(sludge_visual)

	_add_damage_zone("SludgeGapHazard", Vector3(8, 3, 10), Vector3(0, 0, 1))

	_add_box("MainCatwalk", Vector3(18, 0.28, 7), Vector3(0, 1.86, -2.5), _mat_catwalk)
	_add_box("SouthRampBottomLanding", Vector3(5.5, 0.18, 2.0), Vector3(0, 0.04, 8.1), _mat_catwalk)
	_add_z_ramp("SouthRamp", 5.5, Vector3(0, 0.0, 7.2), Vector3(0, 2.0, 1.4))
	_add_box("SouthRampTopLanding", Vector3(5.5, 0.18, 2.2), Vector3(0, 1.92, 0.6), _mat_catwalk)

	# Dead-mall reads: visible retail frontage, a dead elevator void, and
	# escalators hanging as collapsed scenery instead of usable ramps.
	_add_box("ElevatorShaftVoid", Vector3(3.0, 4.2, 3.2), Vector3(-8.2, 2.1, -1.8), _mat_void)
	_add_box("SecurityKiosk", Vector3(2.2, 1.7, 1.8), Vector3(7.1, 0.85, 4.4), _mat_storefront)
	_add_box("KioskCounter", Vector3(2.4, 0.28, 0.5), Vector3(7.1, 1.45, 3.6), _mat_metal)
	for data: Array in [
		[Vector3(-9.75, 2.3, 3.2), Vector3(0.12, 2.6, 3.2)],
		[Vector3(-9.75, 2.3, -3.8), Vector3(0.12, 2.6, 2.8)],
		[Vector3(9.75, 2.3, 3.0), Vector3(0.12, 2.6, 3.4)],
		[Vector3(9.75, 2.3, -3.4), Vector3(0.12, 2.6, 3.0)],
	]:
		_add_box("DeadStorefrontGlow", data[1] as Vector3, data[0] as Vector3, _mat_storefront)
	# Hanging luxury banners — each lit with a vertical banner cell from the
	# atrium_props_atlas (CEO Linda propaganda, Omnicorp Mega Mall, Sale 70% off).
	const BANNER_ATLAS := "res://assets/textures/atrium_props_atlas.png"
	# [position, width, height, extra_yaw_deg, col, row]
	for data: Array in [
		[Vector3(-5.5, 3.2, 4.2), 1.2, 3.2, 10.3, 0, 0],    # CEO Linda
		[Vector3(5.0, 3.1, -0.6), 1.0, 3.0, -6.9, 3, 2],    # Omnicorp Mega Mall
		[Vector3(1.0, 3.5, -5.4), 1.4, 2.8, 4.6, 3, 0],     # Sale 70% off
	]:
		_add_atlas_decal("LuxuryBanner", BANNER_ATLAS, int(data[4]), int(data[5]), float(data[1]), float(data[2]), data[0] as Vector3, "z+", 1.0, float(data[3]))
	_add_box("HangingEscalatorA", Vector3(2.2, 0.22, 7.5), Vector3(-5.0, 3.1, 1.5), _mat_metal, Vector3(0.34, 0.20, 0.0))
	_add_box("HangingEscalatorB", Vector3(2.0, 0.22, 6.5), Vector3(5.6, 3.0, -3.3), _mat_metal, Vector3(-0.28, -0.18, 0.0))
	_add_box("EscalatorTeethA", Vector3(2.0, 0.08, 0.8), Vector3(-5.5, 2.55, 4.7), _mat_catwalk, Vector3(0.34, 0.20, 0.0))
	_add_box("EscalatorTeethB", Vector3(1.8, 0.08, 0.8), Vector3(6.0, 2.45, -6.0), _mat_catwalk, Vector3(-0.28, -0.18, 0.0))

	for pos: Vector3 in [Vector3(-9.5, 3.2, 2), Vector3(9.5, 2.8, 2)]:
		var pipe := MeshInstance3D.new()
		pipe.name = "AtriumPipe"
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.18
		pipe_mesh.bottom_radius = 0.18
		pipe_mesh.height = 18
		pipe.mesh = pipe_mesh
		pipe.position = Vector3(pos.x, pos.y, 1)
		pipe.rotation = Vector3(0, 0, PI / 2)
		pipe.set_surface_override_material(0, _mat_pipe)
		add_child(pipe)


func _build_east_service_corridor() -> void:
	_add_box("CorridorFloor", Vector3(8, 0.35, 12), Vector3(14, -0.2, 0), _mat_floor)
	_add_box("CorridorCeiling", Vector3(8, 0.25, 12), Vector3(14, 4.0, 0), _mat_wall)
	_add_box("CorridorEastWall", Vector3(0.35, 4.3, 12), Vector3(18, 1.9, 0), _mat_wall)
	_add_box("CorridorNorthWall", Vector3(8, 4.3, 0.35), Vector3(14, 1.9, -6), _mat_wall)
	_add_box("CorridorSouthWall", Vector3(8, 4.3, 0.35), Vector3(14, 1.9, 6), _mat_wall)
	_add_box("CorridorWestWallN", Vector3(0.35, 4.3, 2), Vector3(10, 1.9, -5), _mat_wall)
	_add_box("CorridorWestWallS", Vector3(0.35, 4.3, 2), Vector3(10, 1.9, 5), _mat_wall)

	_add_box("StorageAlcove", Vector3(3, 2.0, 2), Vector3(16, 1.0, -3), _mat_metal)
	for x_off: float in [11.5, 16.5]:
		var rack := MeshInstance3D.new()
		rack.name = "CorridorPipeRack"
		var rack_mesh := BoxMesh.new()
		rack_mesh.size = Vector3(0.3, 2.5, 9)
		rack.mesh = rack_mesh
		rack.position = Vector3(x_off, 1.25, 0)
		rack.set_surface_override_material(0, _mat_pipe)
		add_child(rack)


func _build_relay_platform() -> void:
	_add_box("RelayFloor", Vector3(20, 0.35, 10), Vector3(0, -0.2, -13), _mat_floor)
	_add_box("RelayCeiling", Vector3(20, 0.25, 10), Vector3(0, 5.0, -13), _mat_wall)
	_add_box("RelayNorthWall", Vector3(20, 5.3, 0.35), Vector3(0, 2.4, -18), _mat_wall)
	_add_box("RelaySouthWallW", Vector3(5, 5.3, 0.35), Vector3(-7.5, 2.4, -8), _mat_wall)
	_add_box("RelaySouthWallE", Vector3(5, 5.3, 0.35), Vector3(7.5, 2.4, -8), _mat_wall)
	_add_box("RelayEastWall", Vector3(0.35, 5.3, 10), Vector3(10, 2.4, -13), _mat_wall)
	_add_box("RelayWestWallN", Vector3(0.35, 5.3, 5), Vector3(-10, 2.4, -15.5), _mat_wall)
	_add_box("RelayWestWallS", Vector3(0.35, 5.3, 2), Vector3(-10, 2.4, -7), _mat_wall)

	_add_box("RelayPlatform", Vector3(16, 0.28, 6), Vector3(0, 1.86, -14), _mat_catwalk)
	_add_z_ramp("PlatformRamp", 5.0, Vector3(0, 0.0, -8.2), Vector3(0, 2.0, -11.0))
	_add_box("PlatformRampTopLanding", Vector3(5.0, 0.18, 2.0), Vector3(0, 1.92, -12.0), _mat_catwalk)

	for x_pos: float in [-6, -2, 2, 6]:
		_add_box("RelayRailing", Vector3(0.12, 1.0, 0.12), Vector3(x_pos, 2.96, -17), _mat_metal)

	_add_box("RelayHousing", Vector3(2, 2.0, 1.5), Vector3(-4, 1.0, -15), _mat_metal)
	_add_box("RelayAntennaBase", Vector3(0.6, 1.8, 0.6), Vector3(-2, 0.9, -15.5), _mat_metal)


func _build_west_maintenance_crawl() -> void:
	_add_box("CrawlFloor", Vector3(8, 0.35, 18), Vector3(-14, -0.2, -2), _mat_floor)
	_add_box("CrawlCeiling", Vector3(8, 0.25, 18), Vector3(-14, 3.0, -2), _mat_wall)
	_add_box("CrawlWestWall", Vector3(0.35, 3.3, 18), Vector3(-18, 1.4, -2), _mat_wall)
	_add_box("CrawlNorthWall", Vector3(4, 3.3, 0.35), Vector3(-16, 1.4, -11), _mat_wall)
	_add_box("CrawlSouthWall", Vector3(8, 3.3, 0.35), Vector3(-14, 1.4, 7), _mat_wall)
	_add_box("CrawlEastWallS", Vector3(0.35, 3.3, 3), Vector3(-10, 1.4, 5.5), _mat_wall)
	_add_box("CrawlEastWallN", Vector3(0.35, 3.3, 4), Vector3(-10, 1.4, -3), _mat_wall)

	_add_box("CrawlMidWall", Vector3(0.35, 2.5, 3), Vector3(-15, 1.0, 2), _mat_wall)
	_add_box("CrawlDuctwork", Vector3(0.8, 0.8, 12), Vector3(-16.5, 2.2, -2), _mat_pipe)


func _build_interactables() -> void:
	if not GameState.get_world_flag("hub_atrium_debris_pile_1_cleared"):
		_add_interactable("hub_debris_pile_1", "Debris Pile", "Press E: clear debris (1/3)", Vector3(5, 2.15, -14.0), Color(0.65, 0.52, 0.32))
	if not GameState.get_world_flag("hub_atrium_debris_pile_2_cleared"):
		_add_interactable("hub_debris_pile_2", "Debris Pile", "Press E: clear debris (2/3)", Vector3(-5, 2.15, -13.5), Color(0.65, 0.52, 0.32))
	if not GameState.get_world_flag("hub_atrium_debris_pile_3_cleared"):
		_add_interactable("hub_debris_pile_3", "Debris Pile", "Press E: clear debris (3/3)", Vector3(0, 0.95, 7.0), Color(0.65, 0.52, 0.32))
	if not GameState.get_world_flag("store_4_claimed"):
		_add_interactable("store_4_terminal", "Store 4 Terminal", "Press E: wipe terminal data", Vector3(6, 2.15, -14.5), Color(0.1, 0.6, 0.8))

	_add_interactable("atrium_relay_node", "Atrium Relay", "Press E: record relay pulse", Vector3(-2, 2.15, -15.5), Color(0.6, 0.2, 1.0))
	_add_interactable("atrium_loot_crate", "Loot Crate", "Press E: open", Vector3(15, 0.95, 2.0), Color(0.9, 0.7, 0.2))


func _build_enemies() -> void:
	# Contested location: faction-themed, threat-scaled enemy profile (refactor §5).
	EnemyLayouts.spawn_profile(self, "collapsed_service_atrium",
		GameState.get_active_threat_band(), GameState.get_active_rival_faction())


func _build_exits() -> void:
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 15.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -17.1), Color(0.08, 1.0, 0.45))


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


func _add_z_ramp(node_name: String, width: float, bottom_point: Vector3, top_point: Vector3) -> void:
	var run := absf(top_point.z - bottom_point.z)
	var rise := top_point.y - bottom_point.y
	var length := sqrt(run * run + rise * rise)
	var angle := -atan2(rise, run) * signf(top_point.z - bottom_point.z)
	var center := (bottom_point + top_point) * 0.5
	center.y = (bottom_point.y + top_point.y) * 0.5
	_add_box(node_name, Vector3(width, 0.26, length), center, _mat_catwalk, Vector3(angle, 0, 0))


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
	return "collapsed_service_atrium:%s:%.2f:%.2f:%.2f" % [kind, pos.x, pos.y, pos.z]


func _add_lights() -> void:
	for data: Array in [
		[Vector3(0, 2.5, 12), Color(0.5, 0.4, 0.6), 1.0],
		[Vector3(-3, 2.5, 14), Color(0.5, 0.4, 0.6), 0.8],
		[Vector3(-2, 3.2, -1), Color(0.4, 0.3, 0.7), 1.6],
		[Vector3(-8.5, 2.5, 4.0), Color(0.2, 0.4, 1.0), 1.4],
		[Vector3(7, 2.5, 1.0), Color(0.5, 0.4, 0.8), 1.2],
		[Vector3(0, 3.2, -9.5), Color(0.6, 0.2, 1.0), 2.0],
		[Vector3(-4, 3.2, -10.5), Color(0.5, 0.15, 0.8), 1.4],
		[Vector3(6, 3.2, -9.5), Color(0.4, 0.2, 0.7), 1.2],
		[Vector3(14, 2.5, 2), Color(0.5, 0.4, 0.8), 1.0],
		[Vector3(14, 2.5, 0), Color(0.4, 0.3, 0.7), 0.8],
		[Vector3(-14, 1.5, 2), Color(0.3, 0.2, 0.5), 0.6],
		[Vector3(-14, 1.5, -1), Color(0.3, 0.2, 0.5), 0.6],
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


# Mall signage decals from atrium_props_atlas, flush on the retail-frontage pilasters.
func _build_prop_decals() -> void:
	const ATLAS := "res://assets/textures/atrium_props_atlas.png"
	# [position, width, height, facing, col, row]
	for data: Array in [
		[Vector3(-9.6, 2.6, 3.2), 1.4, 1.4, "x+", 1, 0],    # Mega Mall directory — west frontage
		[Vector3(-9.6, 2.4, -3.8), 1.3, 1.3, "x+", 1, 1],   # Caution: escalator — west frontage
		[Vector3(9.6, 2.6, 3.0), 1.4, 1.4, "x-", 1, 3],     # LEVEL 2 sign — east frontage
		[Vector3(9.6, 2.4, -3.4), 1.3, 1.3, "x-", 2, 1],    # Luxoria Arcade neon — east frontage
		[Vector3(1.0, 1.9, -5.78), 1.6, 0.9, "z+", 2, 2],   # OUT OF ORDER tape — back wall
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
