extends Node3D

# Dead Food Court Bloom — expanded second-floor food court overgrown by bio-mall flora.
# Job: food_court_filter  Objective: pure_water_filter_node
#
# One big room with zones defined by props and level changes, not walls.
# Footprint: 48 wide × 56 long × 10 tall (x -24..+24, z -28..+28, y 0..10)
#
# Zones:
#   Zone 1 — South Entry Court (z +10..+28): spawn, collapsed stalls, menu boards
#   Zone 2 — Main Food Court / Growth Pit (x -10..+10, z -14..+10): sunken bio-flora
#   Zone 3 — West Vendor Area (x -24..-10, z -14..+10): stalls under upper ring
#   Zone 4 — West Upper Ring (x -24..-10, z -20..+10, y=1.8): elevated safe route
#   Zone 5 — North Upper Ring (full width, z -20..-14, y=1.8): filter destination
#   Zone 6 — East Kitchen Wing (x +10..+24, z -14..+10): grease, spore vent, shelter
#   Zone 7 — NW Storage Cellar (x -24..-14, z -28..-20): loot, splice
#   Zone 8 — NE False Sky Breach (x +14..+24, z -28..-20): collapsed ceiling, bio-flora
#   Zone 9 — Far North Rubble (x -14..+14, z -28..-20): open connection area
#
# Routes to the filter (north upper ring):
#   Route 1 — Combat:    cross growth pit, fight security node, up central north ramp
#   Route 2 — Upper ring: SW ramp to west ring, traverse to north ring
#   Route 3 — Kitchen:   east kitchen + spore vent despawns node, NE ramp to north ring
#   Route 4 — Duct:      far-east maintenance passage shortcut south to kitchen
#   Route 5 — Storage:   NW room + NW ramp to north ring (loot detour)

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
var _escortee: Escortee
var _in_growth := false
var _in_grease := false
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_growth: StandardMaterial3D
var _mat_ring: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_rain: StandardMaterial3D
var _mat_grease: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_tile: StandardMaterial3D
var _mat_menu: StandardMaterial3D
var _mat_column: StandardMaterial3D
var _atlas_cutout_cache: Dictionary = {}


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_spawn_enemies()
	_wire_runtime()
	_refresh_hud()
	var last_event := str(GameState.get_world_flag("last_travel_event_title", "Clear Run"))
	hud.show_dialogue("Dead Food Court Bloom", "Travel event: %s. The menu boards are still on. None of the items are food anymore." % last_event)
	hud.present_event.call_deferred("travel", true)
	hud.push_log("dead food court bloom reached")
	_spawn_escort_if_needed()
	EventDeckSystem.add_card("splice_bloom_return")


func _process(delta: float) -> void:
	if _in_growth and player != null and player.global_position.y < 1.2:
		player_health.apply_damage(1.0 * delta)
	if _in_grease and player != null:
		player_health.apply_damage(0.5 * delta)


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
	if GameState.get_world_flag("spore_vent_used", false):
		if _security_node != null and is_instance_valid(_security_node):
			_security_node.queue_free()
			_security_node = null


func _spawn_enemies() -> void:
	# Contested location: faction-themed, threat-scaled enemy profile (refactor §5).
	EnemyLayouts.spawn_profile(self, "dead_food_court_bloom",
		GameState.get_active_threat_band(), GameState.get_active_rival_faction())

	# Splice in east kitchen
	var splice_4 := SPLICE_SCENE.instantiate()
	splice_4.name = "SpliceKitchen"
	splice_4.position = Vector3(17, 1.05, -4)
	splice_4.persistence_id = "dead_food_court_bloom:splice_kitchen"
	splice_4.add_to_group("splice")
	_tune_splice_duo(splice_4, "foodcourt_east_duo")
	splice_4.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice_4)
	splice_4.set_patrol_points(_make_patrol_points([
		Vector3(17, 1.05, -4), Vector3(17, 1.05, 2),
		Vector3(14, 1.05, 4), Vector3(14, 1.05, -8),
	]))

	# Splice in false sky breach area
	var splice_5 := SPLICE_SCENE.instantiate()
	splice_5.name = "SpliceBreach"
	splice_5.position = Vector3(18, 1.05, -24)
	splice_5.persistence_id = "dead_food_court_bloom:splice_breach"
	splice_5.add_to_group("splice")
	_tune_splice_duo(splice_5, "foodcourt_east_duo")
	splice_5.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice_5)
	splice_5.set_patrol_points(_make_patrol_points([
		Vector3(18, 1.05, -24), Vector3(16, 1.05, -22),
		Vector3(20, 1.05, -26), Vector3(18, 1.05, -20),
	]))

	# Splice at the main court edge. Keep the south entry/shelter quiet on arrival;
	# the old patrol started ~7u from the player spawn and could wake the pack instantly.
	var splice_6 := SPLICE_SCENE.instantiate()
	splice_6.name = "SpliceEntry"
	splice_6.position = Vector3(-14, 1.05, 4)
	splice_6.persistence_id = "dead_food_court_bloom:splice_entry"
	splice_6.add_to_group("splice")
	_tune_splice_duo(splice_6, "foodcourt_west_duo")
	splice_6.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice_6)
	splice_6.set_patrol_points(_make_patrol_points([
		Vector3(-14, 1.05, 4), Vector3(-12, 1.05, -2),
		Vector3(-8, 1.05, -6), Vector3(-16, 1.05, -8),
	]))

	# Splice in storage room
	var splice_7 := SPLICE_SCENE.instantiate()
	splice_7.name = "SpliceStorage"
	splice_7.position = Vector3(-18, 1.05, -24)
	splice_7.persistence_id = "dead_food_court_bloom:splice_storage"
	splice_7.add_to_group("splice")
	_tune_splice_duo(splice_7, "foodcourt_west_duo")
	splice_7.item_dropped.connect(_on_splice_item_dropped)
	add_child(splice_7)
	splice_7.set_patrol_points(_make_patrol_points([
		Vector3(-18, 1.05, -24), Vector3(-16, 1.05, -26),
		Vector3(-20, 1.05, -22), Vector3(-18, 1.05, -20),
	]))


func _tune_splice_duo(splice: Node, pack_id: String) -> void:
	splice.set("pack_id", pack_id)
	splice.set("pack_alert_radius", 7.0)
	splice.set("pack_buff_damage", 1.12)


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
		"lore_terminal":
			_use_lore_terminal()
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


func _use_lore_terminal() -> void:
	var msg := "GATEBOX MEGA MALL — FOOD COURT DIRECTORY v4.7.2\n\n"
	msg += "WELCOME TO TASTE LEVEL! Your one-stop destination for culinary adventure!\n\n"
	msg += "STILL OPEN:\n"
	msg += "  McCruds — McKrunchy Meal Deal (building code compliant, probably)\n"
	msg += "  Shapiro's Kosher Hottie House — closed for Sabbath, then closed forever\n"
	msg += "  Burger Me — management was eaten by the ventilation system\n\n"
	msg += "CLOSED BY ORDER OF CEO LINDA:\n"
	msg += "  Pizza Hovel — 'nutritional output below care standards'\n"
	msg += "  Chuck Chicken — 'the chicken was never chicken'\n"
	msg += "  The Gooey Bar — 'the goo is still under investigation'\n\n"
	msg += "NOTICE: Bio-flora remediation team scheduled. Est. arrival: never."
	hud.show_dialogue("Food Court Directory", msg)
	if not GameState.get_world_flag("bloom_directory_read", false):
		GameState.set_world_flag("bloom_directory_read", true)
		hud.push_log("food court directory archived")


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
	if str(active_job.get("objective_type", "find")) == "deliver":
		# Drop-off: hand over the carried parcel (payout consumes it); no duplicate minted.
		if not GameState.has_item(item_name):
			hud.show_dialogue(interactable.display_name, "You're meant to be carrying %s. Come back when it's actually on you." % item_name)
			return
	else:
		GameState.add_item(item_name)   # find: recover the marked item here
	GameState.mark_job_objective_done(job_id)
	GameState.last_mission_result = "Completed objective: %s" % str(active_job.get("title", job_id))
	hud.show_dialogue(interactable.display_name, "%s recovered. It still smells like the lunch special. That is probably fine." % item_name)
	hud.push_log("cooters job objective complete")
	_refresh_hud()


func _spawn_escort_if_needed() -> void:
	_escortee = Escortee.spawn_for_active_job(self, player, hud, "dead_food_court_bloom", Vector3(-4.0, 1.0, -17.0))
	if _escortee != null:
		_escortee.reached_safety.connect(_on_escort_reached)
		_escortee.died.connect(_on_escort_down)


func _on_escort_reached() -> void:
	var jid := GameState.active_job_id
	if jid.is_empty():
		return
	GameState.mark_job_objective_done(jid)
	GameState.last_mission_result = "Escort delivered: %s" % str(GameState.get_active_job_data().get("title", jid))
	hud.show_dialogue("Escort", "The asset reaches the entrance and sags against the wall. \"We made it. Get me to Marbles before I start thinking about it.\"")
	hud.push_log("escort delivered — return to Cooters for payout")
	_refresh_hud()


func _on_escort_down() -> void:
	hud.show_dialogue("Escort", "The asset stops moving. The run's blown — head out and come back to try the escort again.")
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


func _on_splice_item_dropped(item_name: String) -> void:
	hud.push_log("splice dropped: %s" % item_name.replace("_", " "))
	hud.show_system_message("FOUND " + item_name.to_upper().replace("_", " "))


# ─── MATERIALS ───────────────────────────────────────────────────────────

func _build_materials() -> void:
	_mat_floor = _make_mat(Color(0.48, 0.44, 0.38), Color(0.06, 0.05, 0.03), 0.12, "res://assets/textures/bloom/food_court_floor.png", Vector3(14, 16, 1))
	_mat_wall = _make_mat(Color(0.38, 0.42, 0.36), Color(0.04, 0.06, 0.03), 0.10, "res://assets/textures/bloom/food_court_wall.png", Vector3(12, 6, 1))
	_mat_growth = _make_mat(Color(0.06, 0.16, 0.04), Color(0.35, 1.0, 0.18), 0.7, "res://assets/textures/bloom/bio_bloom_growth.png", Vector3(6, 6, 1))
	# Make the glow follow the bio texture instead of a flat green fill (otherwise
	# the emission washes every growth box to a solid neon block).
	_mat_growth.emission_texture = _mat_growth.albedo_texture
	_mat_growth.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_mat_ring = _make_mat(Color(0.45, 0.48, 0.42), Color(0.02, 0.04, 0.02), 0.08, "res://assets/textures/shared/metal_catwalk_grating.png", Vector3(10, 10, 1))
	_mat_neon = _make_mat(Color(0.02, 0.12, 0.04), Color(0.1, 0.9, 0.05), 1.4, "", Vector3.ONE)
	_mat_rain = _make_mat(Color(0.0, 1.0, 0.5, 0.42), Color(0.0, 1.0, 0.5), 1.2, "", Vector3.ONE)
	_mat_rain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_grease = _make_mat(Color(0.18, 0.14, 0.08), Color(0.06, 0.04, 0.01), 0.15, "res://assets/textures/grease_slick.png", Vector3(4, 4, 1))
	_mat_grease.roughness = 0.12
	_mat_grease.metallic = 0.3
	_mat_metal = _make_mat(Color(0.3, 0.32, 0.28), Color(0.02, 0.03, 0.01), 0.06, "res://assets/textures/scuffed_machine_metal.png", Vector3(2, 2, 1))
	_mat_tile = _make_mat(Color(0.52, 0.50, 0.46), Color(0.04, 0.04, 0.02), 0.08, "res://assets/textures/food_court_table.png", Vector3(6, 6, 1))
	_mat_menu = _make_mat(Color(0.05, 0.04, 0.03), Color(0.9, 0.6, 0.15), 1.8, "", Vector3.ONE)
	_mat_column = _make_mat(Color(0.42, 0.40, 0.38), Color(0.03, 0.03, 0.02), 0.04, "res://assets/textures/concrete_column.png", Vector3(1, 4, 1))


# ─── GEOMETRY ─────────────────────────────────────────────────────────────

func _build_geometry() -> void:
	_build_environment()
	_build_outer_shell()
	_build_growth_pit()
	_build_structural_columns()
	_build_table_islands()
	_build_west_vendor_area()
	_build_west_upper_ring()
	_build_north_upper_ring()
	_build_ramps()
	_build_east_kitchen()
	_build_storage_cellar()
	_build_false_sky_breach()
	_build_far_north_rubble()
	_build_maintenance_passage()
	_build_vendor_stalls()
	_build_menu_boards()
	_build_bio_flora_props()
	_build_interactables()
	_build_exits()
	_build_shelters()
	_build_loot()
	_build_lights()
	_add_toxic_rain_controller()


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.012, 0.007)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.12, 0.05)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.08, 0.03)
	env.fog_density = 0.018
	env_node.environment = env
	add_child(env_node)


func _build_outer_shell() -> void:
	# 48 wide × 56 long × 10 tall
	_add_box("Floor", Vector3(48, 0.35, 56), Vector3(0, -0.2, 0), _mat_floor)
	_add_box("Ceiling", Vector3(48, 0.25, 56), Vector3(0, 9.875, 0), _mat_wall)
	_add_box("NorthWall", Vector3(48, 10.0, 0.35), Vector3(0, 5.0, -28), _mat_wall)
	_add_box("SouthWall", Vector3(48, 10.0, 0.35), Vector3(0, 5.0, 28), _mat_wall)
	_add_box("WestWall", Vector3(0.35, 10.0, 56), Vector3(-24, 5.0, 0), _mat_wall)
	_add_box("EastWall", Vector3(0.35, 10.0, 56), Vector3(24, 5.0, 0), _mat_wall)


func _build_growth_pit() -> void:
	# Central sunken growth area (x -8..+8, z -8..+6) — 16×14 organic mess
	# Sunken floor — the ground here drops 0.5m below the main floor
	var pit_floor := MeshInstance3D.new()
	pit_floor.name = "GrowthPitFloor"
	var pit_mesh := BoxMesh.new()
	pit_mesh.size = Vector3(16, 0.06, 14)
	pit_floor.mesh = pit_mesh
	pit_floor.position = Vector3(0, -0.23, -1)
	pit_floor.set_surface_override_material(0, _mat_growth)
	add_child(pit_floor)

	# Sunken pit collision floor — slightly lower than main floor
	_add_box("GrowthPitFloorCol", Vector3(16, 0.35, 14), Vector3(0, -0.45, -1), _mat_growth)

	# Bio-mound props — raised organic shapes scattered in the pit
	for data: Array in [
		[Vector3(-4, -0.05, -3), Vector3(3.0, 0.7, 2.8)],
		[Vector3(3, 0.0, -1), Vector3(2.5, 0.8, 2.2)],
		[Vector3(-2, -0.1, 2), Vector3(3.2, 0.5, 2.5)],
		[Vector3(5, -0.05, -5), Vector3(2.0, 0.4, 2.0)],
		[Vector3(-6, 0.0, 3), Vector3(2.8, 0.9, 3.0)],
		[Vector3(1, -0.1, -6), Vector3(2.4, 0.6, 2.0)],
		[Vector3(-5, 0.05, -6), Vector3(2.0, 0.5, 2.5)],
		[Vector3(6, -0.05, 2), Vector3(1.8, 0.6, 1.8)],
	]:
		var mound := MeshInstance3D.new()
		mound.mesh = BoxMesh.new()
		mound.mesh.size = data[1] as Vector3
		mound.position = data[0] as Vector3
		mound.set_surface_override_material(0, _mat_growth)
		add_child(mound)

	# Growth pit damage zone — 1 hp/s when player.y < 1.2 (standing on sunken floor)
	_add_damage_zone("GrowthPitHazard", Vector3(16, 3, 14), Vector3(0, 0, -1))

	# Green glow from the pit
	var pit_light := OmniLight3D.new()
	pit_light.position = Vector3(0, 1.0, -1)
	pit_light.light_color = Color(0.12, 0.65, 0.05)
	pit_light.light_energy = 3.0
	pit_light.omni_range = 16.0
	add_child(pit_light)


func _build_structural_columns() -> void:
	# Large structural columns breaking up the food court sight lines
	# 8 columns arranged around the growth pit perimeter
	for data: Array in [
		[Vector3(-9, 0, 4), "ColSWL"],
		[Vector3(-9, 0, -4), "ColNWL"],
		[Vector3(-9, 0, -10), "ColFarNW"],
		[Vector3(9, 0, 4), "ColSER"],
		[Vector3(9, 0, -4), "ColNER"],
		[Vector3(9, 0, -10), "ColFarNE"],
		[Vector3(-3, 0, 8), "ColSCL"],
		[Vector3(3, 0, 8), "ColSCR"],
	]:
		_add_box(data[1] as String, Vector3(1.0, 9.5, 1.0), data[0] as Vector3, _mat_column)


func _build_table_islands() -> void:
	# Food court table islands — low cover scattered in the main court area
	# These are outside the growth pit, providing cover during combat
	for data: Array in [
		[Vector3(-14, 0.35, 0), Vector3(2.5, 0.7, 1.5), "Table1"],
		[Vector3(-14, 0.35, 6), Vector3(2.5, 0.7, 1.5), "Table2"],
		[Vector3(-12, 0.35, -6), Vector3(2.0, 0.7, 1.5), "Table3"],
		[Vector3(14, 0.35, 2), Vector3(2.5, 0.7, 1.5), "Table4"],
		[Vector3(14, 0.35, -6), Vector3(2.0, 0.7, 1.5), "Table5"],
		[Vector3(-5, 0.35, 10), Vector3(3.0, 0.7, 1.8), "Table6"],
		[Vector3(5, 0.35, 10), Vector3(3.0, 0.7, 1.8), "Table7"],
		[Vector3(-6, 0.35, 16), Vector3(2.5, 0.7, 1.5), "Table8"],
		[Vector3(6, 0.35, 16), Vector3(2.5, 0.7, 1.5), "Table9"],
		[Vector3(-6, 0.35, 22), Vector3(2.5, 0.7, 1.5), "Table10"],
		[Vector3(6, 0.35, 22), Vector3(2.5, 0.7, 1.5), "Table11"],
	]:
		_add_box(data[2] as String, data[1] as Vector3, data[0] as Vector3, _mat_tile)


func _build_west_vendor_area() -> void:
	# Zone 3 — vendor counters along the west wall (x -24..-10)
	# NO full dividing wall — zone flows into the main court
	# Low islands imply a dead queue boundary while leaving broad gaps into the court.
	_add_box("VendorCounterIslandS", Vector3(1.0, 0.85, 5), Vector3(-10.5, 0.425, -4.5), _mat_tile)
	_add_box("VendorCounterIslandN", Vector3(1.0, 0.85, 3.5), Vector3(-10.5, 0.425, 8.25), _mat_tile)

	# Vendor row floor is the same main floor — no wall separation


func _build_west_upper_ring() -> void:
	# Zone 4 — elevated safe route along west wall (x -24..-10, z -20..+10, y=1.8)
	_add_box("WestUpperRing", Vector3(14, 0.28, 30), Vector3(-17, 1.66, -5), _mat_ring)

	# Support pillars under the ring
	for pz: float in [-16, -8, 0, 8]:
		_add_box("WestPillar_%d" % pz, Vector3(0.6, 1.8, 0.6), Vector3(-17, 0.9, pz), _mat_metal)

	# Railing along east edge of west ring (overlooking main court)
	_add_box("WestRingRailing", Vector3(0.12, 0.8, 30), Vector3(-10.1, 2.5, -5), _mat_metal)


func _build_north_upper_ring() -> void:
	# Zone 5 — filter node destination, spans full width (z -20..-14, y=1.8)
	_add_box("NorthUpperRing", Vector3(48, 0.28, 6), Vector3(0, 1.66, -17), _mat_ring)

	# Support pillars under north ring
	for px: float in [-20, -12, -4, 4, 12, 20]:
		_add_box("NorthPillar_%d" % px, Vector3(0.6, 1.8, 0.6), Vector3(px, 0.9, -17), _mat_metal)

	# Railing along south edge of north ring (overlooking growth pit)
	_add_box("NorthRailing", Vector3(48, 0.7, 0.1), Vector3(0, 2.4, -14), _mat_metal)


func _build_ramps() -> void:
	# Route 2: south court to west upper ring. Long and shallow, with landings
	# so the upper deck reads as a walkway instead of a ledge.
	_add_z_ramp("SWRamp", 7.5, Vector3(-17, 0.0, 20.5), Vector3(-17, 1.8, 10.2))

	# Route 1: growth pit edge to north ring. This is the obvious combat route
	# from the pit, so it needs to be visible and walkable from ground level.
	_add_z_ramp("CentralNorthRamp", 6.5, Vector3(0, 0.0, -4.0), Vector3(0, 1.8, -14.2))

	# Route 3: kitchen side approaches to the north ring.
	_add_z_ramp("NERamp", 6.0, Vector3(14, 0.0, -4.8), Vector3(14, 1.8, -14.2))
	_add_z_ramp("FarEastRamp", 5.0, Vector3(20, 0.0, -5.0), Vector3(20, 1.8, -14.2))

	# Route 5: storage/far-north route steps up from the rubble side.
	_add_z_ramp("NWRamp", 5.5, Vector3(-17, 0.0, -26.0), Vector3(-17, 1.8, -20.4))


func _build_east_kitchen() -> void:
	# Zone 6 — kitchen wing (x +10..+24, z -14..+10)
	# Separated from main court by a long counter island (NOT a wall)
	# Counter runs from z -12 to z +2 with a gap at z -4..0
	_add_box("KitchenCounterN", Vector3(1.5, 1.2, 8), Vector3(10, 0.6, -10), _mat_tile)
	_add_box("KitchenCounterS", Vector3(1.5, 1.2, 8), Vector3(10, 0.6, 6), _mat_tile)

	# Grease slick on kitchen floor
	var grease_visual := MeshInstance3D.new()
	grease_visual.name = "GreaseSlick"
	grease_visual.mesh = BoxMesh.new()
	grease_visual.mesh.size = Vector3(10, 0.03, 18)
	grease_visual.position = Vector3(17, 0.015, -2)
	grease_visual.set_surface_override_material(0, _mat_grease)
	add_child(grease_visual)

	# Grease damage zone (0.5 hp/s)
	_add_grease_zone("GreaseHazard", Vector3(10, 0.5, 18), Vector3(17, 0, -2))

	# Kitchen equipment — counters, freezer, pipe rack
	_add_box("KitchenPrepCounter", Vector3(6, 1.0, 1.5), Vector3(17, 0.5, -6), _mat_metal)
	_add_box("FreezerUnit", Vector3(3.0, 3.0, 2.0), Vector3(22, 1.5, -10), _mat_metal)
	_add_box("PipeRack", Vector3(0.3, 4.0, 4.0), Vector3(23.5, 2.0, 0), _mat_metal)
	_add_box("StoveRemains", Vector3(2.0, 1.2, 2.0), Vector3(20, 0.6, 4), _mat_metal)
	_add_box("DishCart", Vector3(1.5, 0.8, 1.5), Vector3(14, 0.4, 6), _mat_metal)


func _build_storage_cellar() -> void:
	# Zone 7 — NW storage (x -24..-14, z -28..-20)
	# Enclosed room — east wall with door gap at z -22..-24
	_add_box("StorageEastWallN", Vector3(0.35, 4.0, 2), Vector3(-14, 2.0, -20.5), _mat_wall)
	_add_box("StorageEastWallS", Vector3(0.35, 4.0, 4), Vector3(-14, 2.0, -26), _mat_wall)
	# South wall
	_add_box("StorageSouthWall", Vector3(10, 3.0, 0.35), Vector3(-19, 1.5, -28), _mat_wall)
	# North wall uses outer north wall

	# Interior props
	_add_box("ShelfUnit1", Vector3(4, 3.0, 0.8), Vector3(-21, 1.5, -24), _mat_metal)
	_add_box("ShelfUnit2", Vector3(4, 2.5, 0.8), Vector3(-21, 1.25, -22), _mat_metal)
	_add_box("SupplyCrate1", Vector3(1.5, 1.0, 1.2), Vector3(-17, 0.5, -26), _mat_metal)
	_add_box("SupplyCrate2", Vector3(1.2, 0.8, 1.5), Vector3(-15, 0.4, -22), _mat_metal)

	# Dim cold light
	var storage_light := OmniLight3D.new()
	storage_light.position = Vector3(-19, 3.5, -24)
	storage_light.light_color = Color(0.4, 0.5, 0.6)
	storage_light.light_energy = 0.6
	storage_light.omni_range = 8.0
	add_child(storage_light)


func _build_false_sky_breach() -> void:
	# Zone 8 — NE breach (x +14..+24, z -28..-20)
	# West wall with door gap at z -22..-24
	_add_box("BreachWestWallN", Vector3(0.35, 4.0, 2), Vector3(14, 2.0, -20.5), _mat_wall)
	_add_box("BreachWestWallS", Vector3(0.35, 4.0, 4), Vector3(14, 2.0, -26), _mat_wall)

	# Collapsed ceiling — bright false-sky panel above
	var sky_breach := MeshInstance3D.new()
	sky_breach.name = "FalseSkyBreach"
	sky_breach.mesh = BoxMesh.new()
	sky_breach.mesh.size = Vector3(8, 0.1, 6)
	sky_breach.position = Vector3(19, 8.5, -24)
	var sky_mat := _make_mat(Color(0.1, 0.3, 0.5), Color(0.2, 0.6, 0.9), 4.0, "", Vector3.ONE)
	sky_breach.set_surface_override_material(0, sky_mat)
	add_child(sky_breach)

	# Hanging bio-flora growing through the breach
	for data: Array in [
		[Vector3(16, 6.0, -22), Vector3(2.0, 3.5, 2.0)],
		[Vector3(20, 5.5, -25), Vector3(2.5, 4.0, 2.2)],
		[Vector3(18, 7.0, -26), Vector3(1.5, 3.0, 1.8)],
		[Vector3(22, 5.0, -23), Vector3(1.8, 2.8, 1.5)],
	]:
		var cluster := MeshInstance3D.new()
		cluster.mesh = BoxMesh.new()
		cluster.mesh.size = data[1] as Vector3
		cluster.position = data[0] as Vector3
		cluster.set_surface_override_material(0, _mat_growth)
		add_child(cluster)

	# Breach light — bright false-sky illumination flooding down
	var breach_light := OmniLight3D.new()
	breach_light.position = Vector3(19, 7.0, -24)
	breach_light.light_color = Color(0.3, 0.6, 0.9)
	breach_light.light_energy = 3.0
	breach_light.omni_range = 14.0
	add_child(breach_light)


func _build_far_north_rubble() -> void:
	# Zone 9 — open area connecting NW storage and NE breach (x -14..+14, z -28..-20)
	# Rubble and debris, no walls — connects to both side rooms
	for data: Array in [
		[Vector3(-6, 0.3, -22), Vector3(3.0, 0.6, 2.0)],
		[Vector3(4, 0.25, -24), Vector3(2.5, 0.5, 1.8)],
		[Vector3(-2, 0.2, -26), Vector3(2.0, 0.4, 1.5)],
		[Vector3(8, 0.35, -22), Vector3(2.2, 0.7, 1.6)],
		[Vector3(-10, 0.3, -25), Vector3(1.8, 0.6, 2.2)],
		[Vector3(0, 0.15, -20), Vector3(4.0, 0.3, 1.0)],
	]:
		var rubble := MeshInstance3D.new()
		rubble.mesh = BoxMesh.new()
		rubble.mesh.size = data[1] as Vector3
		rubble.position = data[0] as Vector3
		rubble.set_surface_override_material(0, _mat_growth)
		add_child(rubble)

	# Dim rubble area light
	var rubble_light := OmniLight3D.new()
	rubble_light.position = Vector3(0, 3.0, -24)
	rubble_light.light_color = Color(0.15, 0.25, 0.12)
	rubble_light.light_energy = 0.6
	rubble_light.omni_range = 10.0
	add_child(rubble_light)


func _build_maintenance_passage() -> void:
	# Route 4 — narrow passage along far east wall (x +22..+24, z -14..+10)
	# Low ceiling section, bypasses the kitchen entirely
	_add_box("DuctWestWall", Vector3(0.2, 3.0, 24), Vector3(22, 1.5, -2), _mat_metal)
	_add_box("DuctCeiling", Vector3(2, 0.15, 24), Vector3(23, 3.0, -2), _mat_metal)

	# Pipe props
	_add_box("DuctPipe1", Vector3(0.15, 2.8, 0.15), Vector3(23.3, 1.5, 4), _mat_metal)
	_add_box("DuctPipe2", Vector3(0.15, 2.8, 0.15), Vector3(23.3, 1.5, -4), _mat_metal)
	_add_box("DuctPipe3", Vector3(0.15, 2.8, 0.15), Vector3(23.3, 1.5, -10), _mat_metal)

	# Dim passage light
	var duct_light := OmniLight3D.new()
	duct_light.position = Vector3(23, 2.0, -2)
	duct_light.light_color = Color(0.4, 0.3, 0.1)
	duct_light.light_energy = 0.3
	duct_light.omni_range = 10.0
	add_child(duct_light)


func _build_vendor_stalls() -> void:
	# Vendor counters along the west wall — 5 bays with real frontage and
	# abandoned queue lanes, leaving x -13..-10 as the public walking aisle.
	for i: int in range(5):
		var z_pos := -10.0 + i * 5.0
		_add_box("VendorCounter%d" % i, Vector3(4.8, 0.9, 1.6), Vector3(-20.6, 0.45, z_pos), _mat_tile)
		_add_box("VendorShelf%d" % i, Vector3(0.6, 1.8, 3.2), Vector3(-23.4, 0.9, z_pos), _mat_metal)
		_add_visual_box("QueueMat%d" % i, Vector3(5.4, 0.035, 3.4), Vector3(-15.5, 0.025, z_pos), _mat_floor)
		_add_visual_box("QueueRailA%d" % i, Vector3(0.12, 0.55, 3.1), Vector3(-13.0, 0.275, z_pos), _mat_metal)
		_add_visual_box("QueueRailB%d" % i, Vector3(0.12, 0.55, 3.1), Vector3(-17.8, 0.275, z_pos), _mat_metal)
		for post_z: float in [z_pos - 1.45, z_pos + 1.45]:
			_add_visual_box("QueuePostA%d_%d" % [i, roundi(post_z * 10.0)], Vector3(0.22, 0.8, 0.22), Vector3(-13.0, 0.4, post_z), _mat_metal)
			_add_visual_box("QueuePostB%d_%d" % [i, roundi(post_z * 10.0)], Vector3(0.22, 0.8, 0.22), Vector3(-17.8, 0.4, post_z), _mat_metal)

	# Broken overhead sign bands give the row a readable food-court silhouette —
	# each lit with a vendor sign cell from the food_court_props_atlas.
	const VENDOR_ATLAS := "res://assets/textures/food_court_props_atlas.png"
	var band_cells := [[1, 0], [2, 0], [0, 0], [2, 2], [0, 3]]
	var bands := [
		Vector3(-20.6, 2.35, -10.0),
		Vector3(-20.6, 2.35, -5.0),
		Vector3(-20.6, 2.35, 0.0),
		Vector3(-20.6, 2.35, 5.0),
		Vector3(-20.6, 2.35, 10.0),
	]
	for i: int in range(bands.size()):
		var cell: Array = band_cells[i % band_cells.size()]
		# Spans 4.8 along X above the vendor counters, facing the south aisle.
		_add_atlas_decal("VendorSignBand", VENDOR_ATLAS, int(cell[0]), int(cell[1]), 4.8, 0.7, bands[i], "z+", 1.2)


func _build_menu_boards() -> void:
	# Glowing menu boards on walls — each samples a different cell of the
	# food_court_props_atlas (McCruds, Burger Me, Mega Combo, directory, CEO Linda
	# closure notice, Glop Star, deals board, etc.).
	const ATLAS := "res://assets/textures/food_court_props_atlas.png"
	var cells := [[0, 0], [1, 0], [2, 0], [2, 1], [3, 1], [2, 2], [0, 3], [1, 1]]
	# [position, width, height, facing]
	var boards := [
		[Vector3(-23.78, 3.5, 4), 2.5, 1.5, "x+"],
		[Vector3(-23.78, 3.5, -4), 2.5, 1.5, "x+"],
		[Vector3(-23.78, 3.5, -14), 2.5, 1.5, "x+"],
		[Vector3(-10.18, 3.0, 8), 2.5, 1.2, "z-"],
		[Vector3(10.18, 3.0, 8), 2.5, 1.2, "z-"],
		[Vector3(-23.78, 3.5, -22), 2.5, 1.5, "x+"],
		[Vector3(23.78, 3.0, -6), 2.0, 1.2, "x-"],
		[Vector3(23.78, 3.0, 4), 2.0, 1.2, "x-"],
		[Vector3(-4, 6.0, 11.95), 3.0, 1.5, "z+"],
		[Vector3(4, 6.0, 11.95), 3.0, 1.5, "z+"],
	]
	for i: int in range(boards.size()):
		var data: Array = boards[i]
		var cell: Array = cells[i % cells.size()]
		_add_atlas_decal("MenuBoard", ATLAS, int(cell[0]), int(cell[1]), float(data[1]), float(data[2]), data[0] as Vector3, str(data[3]), 1.4)


func _build_bio_flora_props() -> void:
	# Bio-flora clusters scattered around pit edges and main court
	var clusters: Array[Array] = [
		[Vector3(-10, 0.3, 0), Vector3(2.0, 0.8, 2.5)],
		[Vector3(-10, 0.25, 6), Vector3(1.5, 0.6, 2.0)],
		[Vector3(10, 0.2, -4), Vector3(1.8, 0.5, 2.2)],
		[Vector3(10, 0.35, 4), Vector3(2.2, 0.8, 2.0)],
		[Vector3(-12, 0.15, -4), Vector3(1.2, 0.4, 1.5)],
		[Vector3(-14, 0.2, 4), Vector3(1.0, 0.5, 1.2)],
		[Vector3(0, 0.2, 10), Vector3(4.0, 0.4, 1.5)],
		[Vector3(7, 0.25, 10), Vector3(2.0, 0.5, 1.5)],
		[Vector3(-7, 0.2, 10), Vector3(2.0, 0.5, 1.5)],
		[Vector3(-16, 0.15, -8), Vector3(1.5, 0.3, 1.0)],
		[Vector3(12, 0.2, -10), Vector3(1.8, 0.4, 1.5)],
		[Vector3(-4, 0.15, -14), Vector3(3.0, 0.3, 1.2)],
		[Vector3(4, 0.2, -14), Vector3(2.5, 0.4, 1.5)],
	]
	for data: Array in clusters:
		var cluster := MeshInstance3D.new()
		cluster.name = "BioFloraCluster"
		cluster.mesh = BoxMesh.new()
		cluster.mesh.size = data[1] as Vector3
		cluster.position = data[0] as Vector3
		cluster.set_surface_override_material(0, _mat_growth)
		add_child(cluster)

	# Vine growth on kitchen counter island
	var vine := MeshInstance3D.new()
	vine.name = "WallVine"
	vine.mesh = BoxMesh.new()
	vine.mesh.size = Vector3(0.15, 4.0, 8)
	vine.position = Vector3(10.1, 2.0, -2)
	vine.set_surface_override_material(0, _mat_growth)
	add_child(vine)


func _build_interactables() -> void:
	# Spore vent panel — kitchen east wall
	_add_interactable("spore_vent_panel", "Spore Vent Panel", "Press E: trigger grease-spore vent", Vector3(23, 0.95, 2), Color(0.9, 0.5, 0.05))

	# Pure water filter — on north upper ring
	_add_interactable("pure_water_filter_node", "Pure Water Filter", "Press E: recover filter", Vector3(-4, 2.0, -17), Color(0.0, 0.85, 1.0))

	# Lore terminal — vendor row
	_add_interactable("lore_terminal", "Food Court Directory", "Press E: read directory", Vector3(-22, 0.95, 0), Color(0.9, 0.7, 0.1))


func _build_exits() -> void:
	# South exit to Cooters
	_add_exit("ExitToCooters", "Press E: return to Cooters", COOTERS_INTERIOR_SCENE, Vector3(0.0, 1.0, 27.1), Color(1.0, 0.08, 0.62))
	# North exit to Leak Street
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", DISTRICT_SCENE, Vector3(0.0, 1.0, -27.1), Color(0.08, 1.0, 0.45))


func _build_shelters() -> void:
	# Vendor shelter: a surviving queue alcove under the west upper ring.
	_add_shelter("VendorQueueShelter", Vector3(-14.5, 0.9, 8.8), Vector3(4.8, 2.5, 3.6), Vector3(5.2, 0.18, 3.9), _mat_ring)
	_add_visual_box("VendorShelterBackPanel", Vector3(0.18, 1.4, 3.6), Vector3(-16.9, 0.7, 8.8), _mat_metal)
	_add_visual_box("VendorShelterSidePanel", Vector3(4.6, 1.1, 0.18), Vector3(-14.5, 0.55, 10.6), _mat_metal)

	# Kitchen shelter: a dry service pass beneath the old exhaust hood.
	_add_shelter("KitchenHoodShelter", Vector3(20.5, 0.9, 6.8), Vector3(4.6, 2.5, 3.6), Vector3(5.0, 0.22, 4.0), _mat_metal)
	_add_visual_box("KitchenHoodBack", Vector3(4.8, 1.3, 0.18), Vector3(20.5, 0.65, 8.7), _mat_metal)
	_add_visual_box("KitchenHoodDuct", Vector3(1.2, 2.2, 1.2), Vector3(20.5, 2.9, 6.8), _mat_metal)

	# South shelter: a collapsed directory kiosk beside the entry, off the main path.
	_add_shelter("EntryKioskShelter", Vector3(-10.0, 0.9, 23.2), Vector3(4.4, 2.5, 3.8), Vector3(4.8, 0.18, 4.1), _mat_menu)
	_add_visual_box("EntryKioskBack", Vector3(4.6, 1.6, 0.18), Vector3(-10.0, 0.8, 25.1), _mat_menu)
	_add_visual_box("EntryKioskSide", Vector3(0.18, 1.2, 3.7), Vector3(-12.4, 0.6, 23.2), _mat_metal)


func _build_loot() -> void:
	_add_loot_pickup("Ammo Scrap", Vector3(-19, 0.5, -4))
	_add_loot_pickup("Chemical Neutralizer", Vector3(-17, 0.5, -24))
	_add_loot_pickup("Ammo Scrap", Vector3(19, 0.5, -24))
	_add_loot_pickup("Soul Coolant Vial", Vector3(-2, 0.5, 20))
	_add_loot_pickup("Ammo Scrap", Vector3(15, 0.5, 4))
	_add_loot_pickup("Wan Note", Vector3(-20, 0.5, 0))


func _build_lights() -> void:
	# Main court — amber and green mixed
	for data: Array in [
		# Main food court
		[Vector3(0, 6.0, 4), Color(0.7, 0.5, 0.1), 1.5, 14.0],
		[Vector3(0, 6.0, -4), Color(0.15, 0.7, 0.05), 1.2, 12.0],
		[Vector3(-6, 6.0, 0), Color(0.6, 0.45, 0.1), 1.0, 10.0],
		[Vector3(6, 6.0, 0), Color(0.6, 0.45, 0.1), 1.0, 10.0],
		# South entry court
		[Vector3(-8, 5.0, 16), Color(0.8, 0.6, 0.15), 1.2, 10.0],
		[Vector3(8, 5.0, 16), Color(0.8, 0.5, 0.1), 1.2, 10.0],
		[Vector3(0, 5.0, 22), Color(0.7, 0.55, 0.12), 0.8, 8.0],
		# West vendor row
		[Vector3(-17, 4.0, 2), Color(0.7, 0.5, 0.1), 1.0, 8.0],
		[Vector3(-17, 4.0, -6), Color(0.1, 0.8, 0.05), 1.0, 8.0],
		[Vector3(-17, 4.0, -14), Color(0.6, 0.4, 0.08), 0.8, 6.0],
		# North ring
		[Vector3(-10, 4.0, -17), Color(0.0, 0.85, 1.0), 1.8, 10.0],
		[Vector3(10, 4.0, -17), Color(0.0, 0.85, 1.0), 1.8, 10.0],
		[Vector3(0, 4.0, -17), Color(0.0, 0.7, 0.9), 1.5, 10.0],
		# East kitchen
		[Vector3(17, 4.0, -4), Color(0.9, 0.5, 0.05), 1.2, 10.0],
		[Vector3(17, 4.0, 4), Color(0.7, 0.5, 0.1), 0.8, 8.0],
		# Far north
		[Vector3(0, 5.0, -24), Color(0.15, 0.3, 0.12), 0.6, 8.0],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = float(data[3])
		add_child(light)

	# Rain leak columns — toxic rain visual drips
	_add_rain_leak(Vector3(-14, 3.0, -4))
	_add_rain_leak(Vector3(6, 3.5, 12))
	_add_rain_leak(Vector3(-6, 2.5, -14))
	_add_rain_leak(Vector3(12, 3.0, -8))
	_add_rain_leak(Vector3(-10, 2.0, -17))
	_add_rain_leak(Vector3(4, 3.0, 20))


# ─── HELPER FUNCTIONS ─────────────────────────────────────────────────────

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


func _add_grease_zone(zone_name: String, size: Vector3, world_pos: Vector3) -> void:
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
			_in_grease = true
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			_in_grease = false
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


func _add_visual_box(node_name: String, size: Vector3, world_position: Vector3, material: Material, world_rotation := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = world_position
	visual.rotation = world_rotation
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.set_surface_override_material(0, material)
	add_child(visual)
	return visual


func _add_z_ramp(node_name: String, width: float, bottom_point: Vector3, top_point: Vector3) -> void:
	var run := absf(top_point.z - bottom_point.z)
	var rise := top_point.y - bottom_point.y
	var length := sqrt(run * run + rise * rise)
	var angle := -atan2(rise, run) * signf(top_point.z - bottom_point.z)
	var center := (bottom_point + top_point) * 0.5
	center.y = (bottom_point.y + top_point.y) * 0.5

	_add_box(node_name, Vector3(width, 0.28, length), center, _mat_ring, Vector3(angle, 0, 0))
	_add_box(node_name + "BottomLanding", Vector3(width, 0.16, 2.2), bottom_point + Vector3(0.0, 0.04, 0.0), _mat_ring)
	_add_box(node_name + "TopLanding", Vector3(width, 0.16, 2.4), top_point + Vector3(0.0, -0.08, 0.0), _mat_ring)
	_add_visual_box(node_name + "LeftCurb", Vector3(0.18, 0.45, length), center + Vector3(-width * 0.5, 0.24, 0.0), _mat_metal, Vector3(angle, 0, 0))
	_add_visual_box(node_name + "RightCurb", Vector3(0.18, 0.45, length), center + Vector3(width * 0.5, 0.24, 0.0), _mat_metal, Vector3(angle, 0, 0))


func _add_interactable(id: String, disp_name: String, prompt: String, world_position: Vector3, color: Color) -> WardInteractable:
	var area := WardInteractable.new()
	area.name = disp_name.replace(" ", "")
	area.add_to_group("location_interactable")
	area.interactable_id = id
	area.display_name = disp_name
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


func _add_loot_pickup(item_name: String, world_position: Vector3) -> void:
	var loot := LootPickup.new()
	loot.name = "Loot_" + item_name.replace(" ", "")
	loot.item_name = item_name
	loot.position = world_position
	add_child(loot)
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(0.8, 0.8, 0.8)
	var collision := CollisionShape3D.new()
	collision.shape = col_shape
	loot.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.4, 0.4)
	var mat := _make_mat(Color(0.6, 0.5, 0.1), Color(0.9, 0.7, 0.1), 1.0, "", Vector3.ONE)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.set_surface_override_material(0, mat)
	loot.add_child(visual)
	loot.picked_up.connect(func(picked_name: String) -> void:
		hud.push_log("picked up: %s" % picked_name.replace("_", " "))
		hud.show_system_message("FOUND " + picked_name.to_upper().replace("_", " "))
	)


func _add_shelter(node_name: String, world_position: Vector3, shape_size: Vector3, awning_size: Vector3, awning_material: Material) -> void:
	var shelter := ShelterZone.new()
	shelter.name = node_name
	shelter.position = world_position
	add_child(shelter)
	var shape := BoxShape3D.new()
	shape.size = shape_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	shelter.add_child(collision)
	_add_box(node_name + "Awning", awning_size, world_position + Vector3(0.0, 1.5, 0.0), awning_material)


func _add_rain_leak(world_position: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.28
	mesh.height = 4.0
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


func _add_toxic_rain_controller() -> void:
	var controller := ToxicRainController.new()
	controller.name = "ToxicRainController"
	controller.player_health_path = NodePath("../Player/PlayerHealth")
	controller.hud_path = NodePath("../HUD")
	add_child(controller)


func _make_patrol_points(points: Array) -> Array[Vector3]:
	var typed_points: Array[Vector3] = []
	for point: Vector3 in points:
		typed_points.append(point)
	return typed_points


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
# `facing` aims the front face into the room: "z+", "z-", "x+", "x-".
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
