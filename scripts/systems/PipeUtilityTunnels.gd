extends Node3D

# Expanded Pipe Utility Tunnels — 18×48, three zones, flood chamber, catwalk, four approaches.

const COOTERS_INTERIOR_SCENE := "res://scenes/levels/CootersInterior.tscn"
const DISTRICT_SCENE := "res://scenes/levels/SubSubBasementDistrict.tscn"
const SECURITY_NODE_SCENE := preload("res://scenes/enemies/SecurityNode.tscn")
const SPLICE_SCENE := preload("res://scenes/enemies/Splice.tscn")
const FLOOD_DAMAGE_RATE := 1.0

@onready var hud: HUDController = $HUD
@onready var player: Node3D = $Player
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_interactable: WardInteractable
var focused_exit: MissionExit
var _security_node: Node3D
var _in_flood := false
var _flood_active := true
var _flood_visual: MeshInstance3D

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_pipe: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D
var _mat_water: StandardMaterial3D
var _mat_catwalk: StandardMaterial3D
var _mat_cover: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Leak Street Gate", "Travel event: %s. The tunnel locks click behind you like the building just accepted a dare." % last_event)
	hud.push_log("pipe utility tunnels reached")
	EventDeckSystem.add_card("splice_pipes_return")


func _process(_delta: float) -> void:
	if _in_flood and _flood_active and player != null:
		if player.global_position.y < 1.2:
			player_health.apply_damage(FLOOD_DAMAGE_RATE * _delta)


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
	if GameState.get_world_flag("tunnel_drain_used", false):
		_flood_active = false
		if _flood_visual != null and is_instance_valid(_flood_visual):
			_flood_visual.visible = false


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
		"tunnel_drain_valve":
			_use_drain_valve()
		"velvet_coil":
			_handle_velvet_coil_encounter()
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


func _use_drain_valve() -> void:
	if GameState.get_world_flag("tunnel_drain_used", false):
		hud.show_dialogue("Drain Valve", "Already drained. The chamber floor is still damp but it stopped trying to dissolve your boots.")
		return
	GameState.set_world_flag("tunnel_drain_used", true)
	_flood_active = false
	if _flood_visual != null and is_instance_valid(_flood_visual):
		_flood_visual.visible = false
	hud.show_dialogue("Drain Valve", "The drain gurgles and the flood water begins to recede. The chamber floor emerges like something the building was trying to forget.")
	hud.push_log("flood chamber drained")
	_refresh_hud()


func _handle_velvet_coil_encounter() -> void:
	if GameState.get_world_flag("coil_met_in_tunnels", false):
		hud.show_dialogue("Velvet Coil", "Still here. Still thinking about that hub invitation. The acoustics in this passage are almost acceptable. Almost.")
		return
	if not GameState.get_world_flag("coil_invitation_available", false):
		hud.show_dialogue("Velvet Coil", "You should not be able to see me. Come back when the hub is ready for visitors.")
		return
	GameState.set_world_flag("coil_met_in_tunnels", true)
	hud.show_dialogue("Velvet Coil", "A cybernetic surgeon in a pipe tunnel. Yes, I know how it looks. I am scoping the acoustics. Your hub has potential. Tell Gideon I might accept an invitation, if the space is right. The acoustics have to be right.")
	EventDeckSystem.add_card("coil_invitation_card")
	hud.push_log("Velvet Coil encountered in tunnels")


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
	_mat_pipe = _make_mat(Color(0.55, 0.45, 0.34), Color(0.12, 0.07, 0.02), 0.18, "", Vector3(4, 4, 1))
	_mat_neon = _make_mat(Color(0.02, 0.12, 0.09), Color(0.0, 1.0, 0.55), 1.5, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_water = _make_mat(Color(0.02, 0.22, 0.18, 0.65), Color(0.0, 0.6, 0.45), 0.8, "", Vector3.ONE)
	_mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_catwalk = _make_mat(Color(0.45, 0.48, 0.46), Color(0.04, 0.1, 0.08), 0.3, "", Vector3(2, 2, 1))
	_mat_cover = _make_mat(Color(0.42, 0.38, 0.32), Color(0.06, 0.04, 0.01), 0.15, "", Vector3.ONE)


# ---------------------------------------------------------------------------
# Geometry — 18 wide × 48 long (x -9..9, z -24..24)
# Three zones: south (z 0..24), flood chamber (z -12..0), north (z -24..-12)
# ---------------------------------------------------------------------------

func _build_geometry() -> void:
	_build_environment()
	_build_shell()
	_build_flood_chamber()
	_build_catwalk()
	_build_divider_walls()
	_build_upper_east_walk()
	_build_pipe_runs()
	_build_cover()
	_build_interactables()
	_build_creatures()
	_build_exits()
	_add_lights()
	_add_toxic_rain_controller()


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.18, 0.14)
	env.ambient_light_energy = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.12, 0.1)
	env.fog_density = 0.02
	env_node.environment = env
	add_child(env_node)


func _build_shell() -> void:
	# South section floor — z 0..24
	_add_box("FloorSouth", Vector3(18, 0.35, 24), Vector3(0, -0.2, 12), _mat_floor)
	# Flood chamber floor — z -12..0, lowered ~1m
	_add_box("FloorChamber", Vector3(18, 0.35, 12), Vector3(0, -1.2, -6), _mat_floor)
	# North section floor — z -24..-12
	_add_box("FloorNorth", Vector3(18, 0.35, 12), Vector3(0, -0.2, -18), _mat_floor)
	# Ceiling spans full length — raised to y=6.0 for 4m headroom above catwalk
	_add_box("Ceiling", Vector3(18, 0.25, 48), Vector3(0, 6.0, 0), _mat_wall)
	# Outer walls — raised to match new ceiling height
	_add_box("NorthWall", Vector3(18, 6.3, 0.35), Vector3(0, 3.15, -24), _mat_wall)
	_add_box("SouthWall", Vector3(18, 6.3, 0.35), Vector3(0, 3.15, 24), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 6.3, 48), Vector3(-9, 3.15, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 6.3, 48), Vector3(9, 3.15, 0), _mat_wall)

	# Chamber edge walls — gaps for chamber ramps (x=-6..-2) and catwalk stairs (x=1.5..4.5).
	# South ledge (z=0 line)
	_add_box("ChamberLedgeSW1", Vector3(3, 1.2, 0.35), Vector3(-7.5, 0.4, 0), _mat_wall)
	_add_box("ChamberLedgeSW2", Vector3(3.5, 1.2, 0.35), Vector3(-0.25, 0.4, 0), _mat_wall)
	_add_box("ChamberLedgeSW3", Vector3(4.5, 1.2, 0.35), Vector3(6.75, 0.4, 0), _mat_wall)
	# North ledge (z=-12 line) — same gap pattern
	_add_box("ChamberLedgeNW1", Vector3(3, 1.2, 0.35), Vector3(-7.5, 0.4, -12), _mat_wall)
	_add_box("ChamberLedgeNW2", Vector3(3.5, 1.2, 0.35), Vector3(-0.25, 0.4, -12), _mat_wall)
	_add_box("ChamberLedgeNW3", Vector3(4.5, 1.2, 0.35), Vector3(6.75, 0.4, -12), _mat_wall)

	# Chamber ramps — west side at x=-4, separated from catwalk stairs at x=3
	# South ramp: z=0 ground to z=-3 chamber floor. rx=-0.32 makes +Z end UP (ground), -Z DOWN (chamber)
	_add_box("SouthRampDown", Vector3(4, 0.2, 3), Vector3(-4, -0.5, -1.5), _mat_floor, Vector3(-0.32, 0, 0))
	# North ramp: z=-9 chamber to z=-12 ground. rx=+0.32 makes -Z end UP (ground), +Z DOWN (chamber)
	_add_box("NorthRampUp", Vector3(4, 0.2, 3), Vector3(-4, -0.5, -10.5), _mat_floor, Vector3(0.32, 0, 0))


func _build_flood_chamber() -> void:
	# Flood damage zone — Area3D covers the lowered chamber
	var flood_area := Area3D.new()
	flood_area.name = "FloodZone"
	flood_area.position = Vector3(0, -0.5, -6)
	add_child(flood_area)
	var flood_shape := BoxShape3D.new()
	flood_shape.size = Vector3(16, 2.5, 10)
	var flood_col := CollisionShape3D.new()
	flood_col.shape = flood_shape
	flood_area.add_child(flood_col)
	flood_area.body_entered.connect(_on_flood_body_entered)
	flood_area.body_exited.connect(_on_flood_body_exited)

	# Water surface visual
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(16, 0.08, 10)
	_flood_visual = MeshInstance3D.new()
	_flood_visual.name = "FloodWater"
	_flood_visual.mesh = water_mesh
	_flood_visual.position = Vector3(0, -0.6, -6)
	_flood_visual.set_surface_override_material(0, _mat_water)
	add_child(_flood_visual)


func _on_flood_body_entered(body: Node3D) -> void:
	if body == player:
		_in_flood = true


func _on_flood_body_exited(body: Node3D) -> void:
	if body == player:
		_in_flood = false


func _build_catwalk() -> void:
	# Catwalk spans the flood chamber overhead — surface y≈2.0, player y≈3.05 (safe from flood)
	_add_box("Catwalk", Vector3(8, 0.28, 10), Vector3(0, 1.86, -6), _mat_catwalk)
	# Catwalk railings (visual only, thin walls)
	_add_box("CatwalkRailW", Vector3(0.12, 0.8, 10), Vector3(-4, 2.4, -6), _mat_catwalk)
	_add_box("CatwalkRailE", Vector3(0.12, 0.8, 10), Vector3(4, 2.4, -6), _mat_catwalk)

	# Catwalk stairs — east side at x=3, separated from chamber ramps at x=-4
	# South stairs: z=4 ground to z=-1 catwalk. rx=+0.38 makes -Z end UP (catwalk)
	_add_box("CatwalkStairsS", Vector3(3, 0.2, 5), Vector3(3, 1.0, 1.5), _mat_catwalk, Vector3(0.38, 0, 0))
	# North stairs: z=-9.5 catwalk to z=-14.5 ground. rx=-0.38 makes +Z end UP (catwalk)
	_add_box("CatwalkStairsN", Vector3(3, 0.2, 5), Vector3(3, 1.0, -12), _mat_catwalk, Vector3(-0.38, 0, 0))


func _build_divider_walls() -> void:
	# Two segments creating west bypass passage with a mid-crossing gap for flanking.
	# Segment 1: z 0 to -8 (south half of crossing)
	_add_box("Divider1", Vector3(0.35, 2.8, 8), Vector3(-2.5, 1.4, -4), _mat_wall)
	# Segment 2: z -10 to -18 (north half)
	_add_box("Divider2", Vector3(0.35, 2.8, 8), Vector3(-2.5, 1.4, -14), _mat_wall)
	# Gap at z -8..-10 (2 units) allows crossing between west passage and main corridor.


func _build_upper_east_walk() -> void:
	# Elevated walkway along east wall — extended southward to z=6 so SE ramp connects properly.
	# Surface y≈2.55, player y≈3.6 (safe from flood). Saint Ratchet shrine at north end.
	_add_box("UpperEastWalk", Vector3(4, 0.28, 24), Vector3(7, 2.41, -6), _mat_catwalk)
	# SE ramp: high end (-Z) meets walkway south edge at z=6, low end (+Z) at ground z≈10.8.
	# Center at z=8.4, rx=+0.503 makes -Z end UP (walkway level)
	_add_box("SERamp", Vector3(4, 0.3, 4.8), Vector3(7, 1.2, 8.4), _mat_catwalk, Vector3(0.503, 0, 0))
	# NE ramp descends from walkway (z≈-18) down to north section floor (z≈-22). rx=-0.503 makes +Z end UP (walkway)
	_add_box("NERamp", Vector3(4, 0.3, 4.8), Vector3(7, 1.5, -20), _mat_catwalk, Vector3(-0.503, 0, 0))
	# Railing along inner edge of walkway
	_add_box("EastWalkRailInner", Vector3(0.12, 0.7, 24), Vector3(5.05, 2.85, -6), _mat_catwalk)


func _build_pipe_runs() -> void:
	# Horizontal pipes along z-axis (east-west runs) — near ceiling at y≈5.3
	for z_val: float in [-22.0, -16.0, -10.0, -4.0, 2.0, 8.0, 16.0, 22.0]:
		_add_pipe(Vector3(-8.7, 5.3, z_val), 17.4, true)
	# Vertical pipes along x-axis (north-south runs) — centered at y≈5.5
	for x_val: float in [-6.0, -0.5, 5.5]:
		_add_pipe(Vector3(x_val, 5.5, -23.5), 47.0, false)
	# Extra atmosphere pipes in chamber — mid-height for visual density
	for z_val: float in [-8.0, -4.0]:
		_add_pipe(Vector3(3.5, 4.0, z_val), 7.0, true)
		_add_pipe(Vector3(-5.0, 4.0, z_val), 7.0, true)


func _build_cover() -> void:
	# Half-cover pipe clusters in the main corridor — provide concealment from security node.
	_add_box("CoverCluster1", Vector3(1.8, 1.2, 1.8), Vector3(2.5, 0.6, -4), _mat_cover)
	_add_box("CoverCluster2", Vector3(1.5, 1.0, 1.5), Vector3(-1.5, 0.5, -8), _mat_cover)
	_add_box("CoverCluster3", Vector3(2.0, 1.3, 1.2), Vector3(4.0, 0.65, -9), _mat_cover)
	# Debris in south corridor
	_add_box("DebrisS1", Vector3(2.2, 0.6, 1.4), Vector3(3.5, 0.3, 14), _mat_cover)
	_add_box("DebrisS2", Vector3(1.6, 0.5, 1.8), Vector3(-4.0, 0.25, 10), _mat_cover)
	# Machinery block in north section
	_add_box("MachineryN1", Vector3(2.5, 1.5, 2.0), Vector3(-5.0, 0.75, -20), _mat_cover)
	_add_box("MachineryN2", Vector3(1.8, 1.2, 1.5), Vector3(4.0, 0.6, -18), _mat_cover)


func _build_interactables() -> void:
	# Environmental — pressure valve (south section, kills security node)
	_add_interactable("pipe_pressure_valve", "Pressure Valve", "Press E: bleed pressure valve", Vector3(-7, 0.95, 6), Color(0.85, 0.55, 0.1))

	# Environmental — drain valve (on catwalk over flood chamber, forces elevated route access)
	_add_interactable("tunnel_drain_valve", "Drain Valve", "Press E: drain flood chamber", Vector3(5, 2.5, -6), Color(0.2, 0.6, 0.9))

	# Hub quest node — generator coupling (deep north-west, past divider wall)
	if not GameState.get_world_flag("hub_power_restored"):
		_add_interactable("hub_generator_coupling", "Generator Coupling", "Press E: repair generator coupling", Vector3(-6.5, 0.95, -22), Color(0.9, 0.55, 0.1))

	# Job nodes — spread across the three zones
	_add_interactable("pipe_blood_sample_node", "Pipe Blood Sample Bulb", "Press E: collect pipe blood", Vector3(-5.5, 0.95, 18), Color(0.0, 1.0, 0.55))
	_add_interactable("saint_ratchet_node", "Saint Ratchet", "Press E: recover Saint Ratchet", Vector3(7.2, 2.55, -16), Color(1.0, 0.62, 0.12))
	_add_interactable("pipe_listening_node", "Pipe Listening Node", "Press E: listen to the pipes", Vector3(0.5, 0.95, -22), Color(1.0, 0.12, 0.68))

	# Velvet Coil NPC — west bypass passage (only if hub phase 2 ready)
	if GameState.get_world_flag("coil_invitation_available", false):
		_add_interactable("velvet_coil", "Velvet Coil", "Press E: talk", Vector3(-6.5, 1.05, -9), Color(0.7, 0.2, 0.9))

	# Shelter zones
	_add_shelter(Vector3(-6.5, 0.9, 10))
	_add_shelter(Vector3(-5.0, 0.9, -20))

	# Rain leak visuals — hang from ceiling at y=6.0
	_add_rain_leak(Vector3(-1.5, 4.6, -4))
	_add_rain_leak(Vector3(2.0, 4.6, 14))


func _build_creatures() -> void:
	# Security node on catwalk — elevated threat over flood chamber
	_add_security_node(Vector3(0.0, 2.0, -6.0))
	# Splice in south corridor
	_add_splice(Vector3(-4.0, 1.05, 14.0))
	# Second splice in north section for pressure
	_add_splice(Vector3(3.0, 1.05, -20.0))


func _build_exits() -> void:
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 24.1), Color(1.0, 0.08, 0.62))
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -24.1), Color(0.08, 1.0, 0.45))


func _add_lights() -> void:
	for data: Array in [
		# South section
		[Vector3(0.0, 4.2, 18.0), Color(0.0, 1.0, 0.55), 1.6, 12.0],
		[Vector3(-6.5, 4.0, 10.0), Color(0.0, 1.0, 0.55), 1.4, 10.0],
		[Vector3(-7.0, 4.0, 6.0), Color(0.85, 0.55, 0.1), 1.2, 8.0],
		[Vector3(3.0, 4.0, 14.0), Color(0.0, 0.75, 1.0), 1.3, 10.0],
		# Flood chamber
		[Vector3(0.0, 4.2, -6.0), Color(0.0, 0.6, 0.45), 2.0, 14.0],
		[Vector3(-5.0, 4.0, -4.0), Color(0.0, 0.5, 0.4), 1.0, 8.0],
		[Vector3(5.0, 4.0, -8.0), Color(0.0, 0.5, 0.4), 1.0, 8.0],
		[Vector3(7.5, 4.0, -6.0), Color(0.2, 0.6, 0.9), 1.2, 7.0],
		# North section
		[Vector3(7.2, 4.3, -16.0), Color(1.0, 0.62, 0.12), 1.4, 10.0],
		[Vector3(0.5, 4.0, -22.0), Color(1.0, 0.12, 0.68), 1.5, 10.0],
		[Vector3(-5.0, 4.0, -20.0), Color(0.0, 1.0, 0.55), 1.3, 8.0],
		[Vector3(4.0, 4.0, -18.0), Color(0.0, 0.75, 1.0), 1.2, 8.0],
		[Vector3(-6.5, 4.0, -22.0), Color(0.9, 0.55, 0.1), 1.1, 7.0],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = float(data[3])
		add_child(light)


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

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
	splice.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice)


func _on_splice_item_dropped(item_name: String) -> void:
	hud.push_log("splice dropped: %s" % item_name.replace("_", " "))
	hud.show_system_message("FOUND " + item_name.to_upper().replace("_", " "))


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
