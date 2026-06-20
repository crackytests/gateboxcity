extends Node3D

# The Gantry Tier — a large open-air transit interchange under the artificial sky, sitting between
# Leak Street (back), the Comfort Annexe (up the line, rep-gated) and Rocker Fellar Keep (deep below,
# quest-gated). Neutral ground: no garrison, but the toxic-rain sky cycle still bites in the open, so
# shelters matter. A small independent-squatters camp lives in a sheltered nook. Geometry is built in
# code (mirrors the job destinations); the sky/rain cycle reuses ToxicRainController + ShelterZone.

const LEAK_STREET_SCENE := "res://scenes/levels/SubSubBasementDistrict.tscn"
const COMFORT_ANNEXE_SCENE := "res://scenes/levels/ComfortAnnexe_Reception.tscn"
const ROCKER_FELLAR_KEEP_SCENE := "res://scenes/levels/RockerFellarKeep.tscn"
const GOON_SCENE := preload("res://scenes/enemies/GoonMaterial.tscn")

# Gatebox standing needed before the Comfort Annexe reads you as a Comfort Citizen (matches Leak St).
const COMFORT_ANNEXE_REP_GATE := 2
# At or below this Gatebox standing the wellness patrol stops pretending and treats you as hostile.
const GATEBOX_PATROL_HOSTILE_REP := -2

# Where the player lands depending on which door they arrived through (set via _gantry_spawn_hint).
const SPAWN_LEAK_STREET := Vector3(0.0, 1.05, 33.0)
const SPAWN_ANNEXE := Vector3(-35.0, 1.05, -6.0)
const SPAWN_KEEP := Vector3(35.0, 1.05, -6.0)

@onready var hud: HUDController = $HUD
@onready var player: Node3D = $Player
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_npc: NPCDialogue
var focused_exit: MissionExit
var focused_interactable: WardInteractable

var _patrol_hostile := false
var _patrol_provoked := false
var _patrol_officer: NPCDialogue
var _officer_audited := false   # one comfort audit per visit (no rep farming)

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_grating: StandardMaterial3D
var _mat_rail: StandardMaterial3D
var _mat_neon: StandardMaterial3D
var _mat_sky: StandardMaterial3D
var _mat_shack: StandardMaterial3D
var _sky_light: OmniLight3D
var _sky_spot: OmniLight3D


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	WorldDirector.world_state_changed.connect(hud.set_world_state)
	WorldDirector.world_state_changed.connect(_on_world_state_changed)
	WorldDirector.restore_from_game_state()
	WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)

	_build_materials()
	_build_geometry()
	_build_camp()
	_spawn_gatebox_patrol()

	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for interactable in get_tree().get_nodes_in_group("location_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.focus_changed.connect(_on_npc_focus_changed)
	if hud.dialogue_ui != null:
		if not hud.dialogue_ui.closed.is_connected(_on_dialogue_closed):
			hud.dialogue_ui.closed.connect(_on_dialogue_closed)

	_apply_pending_spawn_hint()
	_apply_sky_state()
	_refresh_hud()
	hud.show_dialogue("System X", "The Gantry Tier. Old transit deck nobody owns, which means everybody parks a problem on it. Leak Street behind you, the Annexe up the line, the Keep straight down. Mind the sky — and the Gatebox patrol. They only bite if you've already given them a reason.")
	hud.push_log("gantry tier reached")


func _apply_pending_spawn_hint() -> void:
	var hint := str(GameState.get_world_flag("_gantry_spawn_hint", ""))
	GameState.set_world_flag("_gantry_spawn_hint", "")
	match hint:
		"from_annexe":
			_place_player(SPAWN_ANNEXE, 0.0)
		"from_keep":
			_place_player(SPAWN_KEEP, 0.0)
		_:
			_place_player(SPAWN_LEAK_STREET, PI)   # default: arriving from Leak Street, facing in


func _place_player(pos: Vector3, yaw: float) -> void:
	player.global_position = pos
	player.rotation.y = yaw
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


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


func _handle_interact() -> void:
	if focused_npc != null:
		var nid := str(focused_npc.npc_id)
		if not nid.is_empty() and DialogueDB.has_profile(nid):
			focused_npc.face_player_now()
			hud.open_dialogue(nid, focused_npc)
			return
		match nid:
			"gantry_scavenger":
				_talk_scavenger()
				return
			"annexe_escapee":
				_talk_escapee()
				return
			"gantry_drifter":
				_talk_drifter()
				return
			"gatebox_officer":
				_talk_officer()
				return
		var line: Dictionary = focused_npc.interact()
		hud.open_statement(str(line.get("name", focused_npc.npc_name)), str(line.get("text", "")), focused_npc)
		_refresh_hud()
		return

	if focused_interactable != null:
		_dispatch_interactable(focused_interactable)
		return

	if focused_exit != null:
		_handle_exit(focused_exit)
		return


func _handle_exit(exit: MissionExit) -> void:
	match exit.name:
		"ExitToComfortAnnexe":
			var gatebox_rep := int(GameState.reputation.get("Gatebox Corporation", 0))
			if gatebox_rep < COMFORT_ANNEXE_REP_GATE:
				hud.show_dialogue("Comfort Annexe Portal", "The ward scanner reads you as an intruder, not a Comfort Citizen. Play Gatebox's game — comply at their checkpoints, pay their levies — until the door warms to you.")
				return
		"ExitToRockerFellarKeep":
			var active := bool(GameState.get_world_flag("quest_rocker_fellar_active", false))
			var defeated := bool(GameState.get_world_flag("rocker_fellar_defeated", false))
			if not active and not defeated:
				hud.show_dialogue("Service Lift", "The lift is keyed to a Foundation contract you don't hold. Accept the Rocker Fellar quest from System X or Kiki Baja before you descend.")
				return
			GameState.set_world_flag("_district_spawn_hint", "")
		"ExitToLeakStreet":
			GameState.set_world_flag("_district_spawn_hint", "gantry_door")
	GameState.autosave()
	get_tree().change_scene_to_file(exit.target_scene)


func _on_npc_focus_changed(npc, has_focus: bool) -> void:
	focused_npc = npc if has_focus else null
	_update_prompt()


func _on_exit_focus_changed(mission_exit: MissionExit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_interactable_focus_changed(interactable: WardInteractable, has_focus: bool) -> void:
	focused_interactable = interactable if has_focus else null
	_update_prompt()


func _on_dialogue_closed() -> void:
	_refresh_hud()


func _update_prompt() -> void:
	if focused_npc != null:
		hud.set_prompt(focused_npc.prompt_text)
	elif focused_interactable != null:
		hud.set_prompt(focused_interactable.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	else:
		hud.set_prompt("")


func _refresh_hud() -> void:
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.set_objective("Gantry Tier: transit between Leak Street, the Comfort Annexe, and Rocker Fellar Keep. Shelter from the rain. F5 save, F6 load.")


# ── Sky reaction ────────────────────────────────────────────────────
func _on_world_state_changed(_summary: String) -> void:
	_apply_sky_state()


func _apply_sky_state() -> void:
	if _sky_light == null:
		return
	if WorldDirector.is_toxic_rain_active():
		_sky_light.light_color = Color(0.1, 0.7, 0.45)
		_sky_light.light_energy = 0.7
		if _sky_spot != null:
			_sky_spot.light_color = Color(0.0, 0.85, 0.45)
			_sky_spot.light_energy = 0.5
	else:
		_sky_light.light_color = Color(0.5, 0.55, 0.7)
		_sky_light.light_energy = 1.1
		if _sky_spot != null:
			_sky_spot.light_color = Color(0.55, 0.5, 0.7)
			_sky_spot.light_energy = 0.8


# ── Materials ───────────────────────────────────────────────────────
func _build_materials() -> void:
	_mat_floor = _make_mat(Color(0.5, 0.55, 0.56), Color(0.02, 0.05, 0.06), 0.12, "res://assets/textures/leak_street/wet_concrete_floor.png", Vector3(10, 10, 1))
	_mat_wall = _make_mat(Color(0.55, 0.58, 0.6), Color(0.02, 0.05, 0.05), 0.12, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(8, 4, 1))
	_mat_grating = _make_mat(Color(0.42, 0.46, 0.46), Color(0.03, 0.08, 0.08), 0.25, "res://assets/textures/shared/metal_catwalk_grating.png", Vector3(3, 6, 1))
	_mat_rail = _make_mat(Color(0.35, 0.38, 0.4), Color(0.04, 0.09, 0.1), 0.3, "", Vector3.ONE)
	_mat_neon = _make_mat(Color(0.02, 0.12, 0.12), Color(0.0, 0.9, 0.85), 1.4, "", Vector3.ONE)
	_mat_shack = _make_mat(Color(0.46, 0.42, 0.36), Color(0.05, 0.03, 0.01), 0.14, "res://assets/textures/leak_street/corrugated_shack_metal.png", Vector3(3, 3, 1))
	_mat_sky = _make_mat(Color(0.08, 0.1, 0.16, 0.5), Color(0.12, 0.18, 0.3), 0.7, "res://assets/textures/leak_street/false_sky_glass.png", Vector3(6, 12, 1))
	_mat_sky.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


# ── Geometry ────────────────────────────────────────────────────────
# A large interchange (x roughly -24..24, z -28..36). South arrival deck from Leak Street, a wide
# central concourse, a raised west spur to the Comfort Annexe portal, and a lowered east spur to the
# Rocker Fellar Keep service lift.
func _build_geometry() -> void:
	_build_environment()
	_build_decks()
	_build_undercroft()
	_build_railings()
	_build_false_sky()
	_build_dressing()
	_build_shelters()
	_build_interactables()
	_build_exits()
	_add_lights()
	_add_toxic_rain_controller()


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.13, 0.18)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.1, 0.14)
	env.fog_density = 0.018
	env_node.environment = env
	add_child(env_node)


func _build_decks() -> void:
	# Everything is a single walkable level (top surface y0) over a deep void; the "elevation" of
	# the tier is read through grating catwalks, railings, and the drop below — not height changes,
	# so every route is reliably traversable. The fiction (up to the Annexe, down to the Keep) lives
	# in the exit prompts.
	# Central concourse — the big open plate.  x[-22,22]  z[-13,21]
	_add_box("DeckConcourse", Vector3(44, 0.4, 34), Vector3(0, -0.2, 4), _mat_floor)
	# South arrival deck (from Leak Street), butted onto the concourse at z21.  z[21,39]
	_add_box("DeckArrival", Vector3(20, 0.4, 18), Vector3(0, -0.2, 30), _mat_floor)
	# West spur → Comfort Annexe portal: a grating bridge out to a platform.
	_add_box("BridgeWest", Vector3(6, 0.4, 8), Vector3(-24, -0.2, -6), _mat_grating)   # x[-27,-21] overlaps concourse
	_add_box("PlatAnnexe", Vector3(16, 0.4, 16), Vector3(-34, -0.2, -6), _mat_floor)   # x[-42,-26]
	# East spur → Rocker Fellar Keep service lift: mirror.
	_add_box("BridgeEast", Vector3(6, 0.4, 8), Vector3(24, -0.2, -6), _mat_grating)     # x[21,27] overlaps concourse
	_add_box("PlatKeep", Vector3(16, 0.4, 16), Vector3(34, -0.2, -6), _mat_floor)       # x[26,42]
	# A central grating catwalk strip for sightlines / cover dressing (same level, optional to cross).
	_add_box("CatwalkSpine", Vector3(6, 0.42, 26), Vector3(0, -0.18, 2), _mat_grating)


func _build_undercroft() -> void:
	# A real lower maintenance level under the concourse (y -8), reached by a walkable ramp off the
	# concourse's north edge and fully enclosed so a fall lands here recoverably instead of in a void.
	# Footprint is larger than the concourse so the north rim is open for the ramp to descend onto.
	_add_box("UndercroftFloor", Vector3(50, 0.5, 56), Vector3(0, -8.25, -5), _mat_floor)
	# Perimeter walls (y -8 → 0) — enclose the hall so you can't fall off its edges.
	_add_box("UndercroftWallN", Vector3(50, 8.0, 0.5), Vector3(0, -4.0, -33), _mat_wall)
	_add_box("UndercroftWallS", Vector3(50, 8.0, 0.5), Vector3(0, -4.0, 23), _mat_wall)
	_add_box("UndercroftWallW", Vector3(0.5, 8.0, 56), Vector3(-25, -4.0, -5), _mat_wall)
	_add_box("UndercroftWallE", Vector3(0.5, 8.0, 56), Vector3(25, -4.0, -5), _mat_wall)
	# Descent ramp: top flush with the concourse north edge (z -13, y 0), down to the undercroft
	# floor (~z -29, y -8). The 26° tilt shortens the run, so center z -21 lands the high end on the
	# deck edge and the low end on the floor.
	_add_box("UndercroftRamp", Vector3(10, 0.5, 18), Vector3(0, -4.0, -21), _mat_grating, Vector3(deg_to_rad(-26.0), 0, 0))
	# Side guard rails on the open ramp run.
	_add_box("RampRailW", Vector3(0.3, 1.2, 18), Vector3(-5.2, -3.4, -21), _mat_rail, Vector3(deg_to_rad(-26.0), 0, 0))
	_add_box("RampRailE", Vector3(0.3, 1.2, 18), Vector3(5.2, -3.4, -21), _mat_rail, Vector3(deg_to_rad(-26.0), 0, 0))
	# A "way down" sign hung above the ramp head on the concourse (overhead so it never blocks you).
	_add_box("DownSign", Vector3(2.6, 0.7, 0.2), Vector3(0, 2.7, -12.6), _mat_neon)

	# Support columns under the deck above (visual load-path) + a little cover.
	for col: Array in [[-14.0, -6.0], [14.0, -6.0], [-14.0, 12.0], [14.0, 12.0], [0.0, -24.0]]:
		_add_box("UndercroftColumn", Vector3(1.4, 8.0, 1.4), Vector3(col[0], -4.0, col[1]), _mat_wall)
	for crate: Array in [[-18.0, -22.0], [17.0, -20.0], [-8.0, 16.0], [20.0, 8.0]]:
		_add_box("UndercroftCrate", Vector3(1.6, 1.6, 1.6), Vector3(crate[0], -7.2, crate[1]), _mat_shack)

	# The covered interior is a guaranteed refuge from the toxic-rain cycle — the concourse deck
	# overhead is the roof, so a big bare ShelterZone stands in for it (no awning needed).
	var refuge := ShelterZone.new()
	refuge.name = "UndercroftShelter"
	refuge.position = Vector3(0.0, -6.0, 4.0)
	add_child(refuge)
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(42, 5.0, 32)
	var rcol := CollisionShape3D.new()
	rcol.shape = rshape
	refuge.add_child(rcol)

	# Undercroft lighting.
	for data: Array in [
		[Vector3(0.0, -2.5, -20.0), Color(0.0, 0.7, 1.0), 1.2, 16.0],
		[Vector3(-14.0, -3.0, 0.0), Color(0.2, 0.6, 0.9), 1.0, 14.0],
		[Vector3(14.0, -3.0, 0.0), Color(0.2, 0.6, 0.9), 1.0, 14.0],
		[Vector3(0.0, -3.0, 16.0), Color(0.9, 0.55, 0.2), 1.0, 12.0],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = float(data[3])
		add_child(light)

	# A reward cache for bothering to come down here.
	_add_interactable("undercroft_cache", "Maintenance Cache", "Press E: force the maintenance cache", Vector3(0.0, -7.4, -28.0), Color(0.2, 0.8, 1.0))


func _build_railings() -> void:
	# Waist-high rails around the outer edges so the deck reads as a platform over the drop.
	# West/east concourse rails are split to leave a gap at z[-10,-2] where the spur bridges connect.
	var rails := [
		# [size, pos]
		[Vector3(16, 1.0, 0.3), Vector3(-14, 0.4, -13.2)],   # concourse north edge, west of ramp
		[Vector3(16, 1.0, 0.3), Vector3(14, 0.4, -13.2)],    # concourse north edge, east of ramp
		[Vector3(0.3, 1.0, 23), Vector3(-22.2, 0.4, 9.5)],   # concourse west, north of bridge gap
		[Vector3(0.3, 1.0, 3), Vector3(-22.2, 0.4, -11.5)],  # concourse west, south of bridge gap
		[Vector3(0.3, 1.0, 23), Vector3(22.2, 0.4, 9.5)],    # concourse east, north of bridge gap
		[Vector3(0.3, 1.0, 3), Vector3(22.2, 0.4, -11.5)],   # concourse east, south of bridge gap
		[Vector3(20, 1.0, 0.3), Vector3(0, 0.4, 39.2)],      # arrival south edge
		[Vector3(0.3, 1.0, 18), Vector3(-10.2, 0.4, 30)],    # arrival west edge
		[Vector3(0.3, 1.0, 18), Vector3(10.2, 0.4, 30)],     # arrival east edge
		[Vector3(16, 1.0, 0.3), Vector3(-34, 0.4, -14.2)],   # annexe platform back rail
		[Vector3(16, 1.0, 0.3), Vector3(-34, 0.4, 2.2)],     # annexe platform front rail
		[Vector3(0.3, 1.0, 16), Vector3(-42.2, 0.4, -6)],    # annexe platform far-west rail
		[Vector3(16, 1.0, 0.3), Vector3(34, 0.4, -14.2)],    # keep platform back rail
		[Vector3(16, 1.0, 0.3), Vector3(34, 0.4, 2.2)],      # keep platform front rail
		[Vector3(0.3, 1.0, 16), Vector3(42.2, 0.4, -6)],     # keep platform far-east rail
	]
	for r: Array in rails:
		_add_box("Rail", r[0] as Vector3, r[1] as Vector3, _mat_rail)


func _build_false_sky() -> void:
	# Overhead glass canopy panels — the "imitation of heaven" spanning the whole interchange.
	for px in [-34.0, -17.0, 0.0, 17.0, 34.0]:
		for pz in [-8.0, 8.0, 26.0]:
			_add_box("SkyPanel", Vector3(16, 0.2, 17), Vector3(px, 11.0, pz), _mat_sky)


func _build_dressing() -> void:
	# Support pillars carrying the false-sky canopy — they sell the "deck under a roof" read and
	# break up the long sightlines.
	for col: Array in [
		[-34.0, -6.0], [-17.0, 8.0], [-17.0, -8.0], [0.0, 16.0], [0.0, -8.0],
		[17.0, 8.0], [17.0, -8.0], [34.0, -6.0],
	]:
		_add_box("CanopyPillar", Vector3(1.1, 11.0, 1.1), Vector3(col[0], 5.4, col[1]), _mat_wall)

	# A derelict transit car beached on the concourse — the centerpiece of the dead interchange.
	_add_box("TramBody", Vector3(12.0, 2.6, 3.0), Vector3(7.0, 1.5, 13.0), _mat_shack)
	_add_box("TramWindows", Vector3(12.2, 0.7, 3.05), Vector3(7.0, 2.1, 13.0), _mat_neon)
	_add_box("TramSkirt", Vector3(12.0, 0.5, 3.2), Vector3(7.0, 0.3, 13.0), _mat_wall)
	_add_box("TramCarB", Vector3(8.0, 2.4, 2.8), Vector3(-7.5, 1.4, 16.5), _mat_shack)
	_add_box("TramCarBWin", Vector3(8.2, 0.6, 2.85), Vector3(-7.5, 1.95, 16.5), _mat_neon)

	# A dead departure board on a stanchion near the arrival mouth (also the readable notice prop).
	_add_box("DepartureMast", Vector3(0.4, 4.4, 0.4), Vector3(0.0, 2.2, 20.0), _mat_wall)
	_add_box("DepartureBoard", Vector3(6.5, 2.4, 0.3), Vector3(0.0, 4.2, 20.0), _mat_neon)

	# Old fare turnstiles ranked across the arrival throat.
	for tx in [-6.0, -2.0, 2.0, 6.0]:
		_add_box("Turnstile", Vector3(0.6, 1.1, 1.6), Vector3(tx, 0.55, 22.0), _mat_rail)

	# Sagging cable/conduit runs strung between pillars near the canopy.
	for cz in [-6.0, 4.0, 14.0]:
		_add_box("CableRun", Vector3(46.0, 0.16, 0.16), Vector3(0.0, 8.4, cz), _mat_rail)
	_add_box("ConduitSpine", Vector3(0.2, 0.2, 30.0), Vector3(-2.0, 8.2, 4.0), _mat_rail)

	# Scattered freight + barrels so the open deck isn't sterile.
	for crate: Array in [
		[4.0, -10.0], [-3.0, -11.0], [18.0, 4.0], [-18.0, 6.0], [12.0, -6.0], [-9.0, 18.0],
	]:
		_add_box("FreightCrate", Vector3(1.6, 1.6, 1.6), Vector3(crate[0], 0.8, crate[1]), _mat_shack)
	for barrel: Array in [[5.6, -9.0], [-4.2, -12.0], [13.4, -5.2], [-30.0, -4.0]]:
		_add_box("Barrel", Vector3(0.7, 1.0, 0.7), Vector3(barrel[0], 0.5, barrel[1]), _mat_rail)


func _build_shelters() -> void:
	# Rain cover at the arrival mouth, the camp nook, and each spur platform.
	_add_shelter(Vector3(0.0, 0.0, 34.0))
	_add_shelter(Vector3(-14.0, 0.0, -8.0))
	_add_shelter(Vector3(-34.0, 0.0, -6.0))
	_add_shelter(Vector3(34.0, 0.0, -6.0))


func _build_interactables() -> void:
	_add_interactable("gantry_notice_board", "Departure Board", "Press E: read the dead departure board", Vector3(0.0, 1.4, 18.7), Color(0.0, 0.85, 1.0))
	_add_interactable("salvage_post", "Salvage Post", "Press E: sell salvage to the scavengers", Vector3(-11.4, 0.9, -7.0), Color(0.95, 0.6, 0.2))
	_add_interactable("scavenger_stash", "Scavenger Stash", "Press E: search the stash", Vector3(-18.8, 0.9, -9.2), Color(0.9, 0.7, 0.2))


func _dispatch_interactable(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"gantry_notice_board":
			_read_notice_board()
		"salvage_post":
			hud.show_dialogue("Scavenger Boss", "Drop what you scavenged on the counter. I pay in Wan, not promises.")
			hud.open_sell_shop("Scavenger Boss — Salvage")
		"scavenger_stash":
			_open_stash()
		"undercroft_cache":
			_open_undercroft_cache()
		_:
			hud.show_dialogue(interactable.display_name, "Nothing in it for you yet.")


func _read_notice_board() -> void:
	hud.open_statement("Departure Board",
		"The board still scrolls, powered by spite and a dying capacitor. ARRIVALS: none. DEPARTURES: none. Three routes still flash, half-burned: ▲ LEAK STREET — service nominal. ▲ COMFORT ANNEXE — restricted, comfort clearance required. ▼ KEEP SUBLEVEL — DECOMMISSIONED in a font nobody decommissioned. Underneath, scratched by hand: 'the trains stopped, we didn't.'")


func _open_stash() -> void:
	if bool(GameState.get_world_flag("gantry_stash_looted", false)):
		hud.show_dialogue("Scavenger Stash", "Already stripped. The scavengers re-hide the good stuff daily, but you only get the welcome gift once.")
		return
	GameState.set_world_flag("gantry_stash_looted", true)
	GameState.add_item("Cheap Poncho")
	GameState.add_wan_notes(6)
	GameState.last_mission_result = "Searched the Gantry Tier stash"
	hud.show_dialogue("Scavenger Stash", "Tucked under a panel: a Cheap Poncho and a small roll of Wan Notes. The boss watches you take it and nods once. \"Rain tax. Now you owe us a favor you'll forget.\"")
	hud.push_log("found Cheap Poncho + 6 Wan Notes in the stash")
	_refresh_hud()


func _open_undercroft_cache() -> void:
	if bool(GameState.get_world_flag("gantry_undercroft_cache_looted", false)):
		hud.show_dialogue("Maintenance Cache", "Stripped clean. Whatever Gatebox stashed down here is already on you now.")
		return
	GameState.set_world_flag("gantry_undercroft_cache_looted", true)
	GameState.add_item("gatebox_eye_mk1")
	GameState.add_wan_notes(12)
	GameState.last_mission_result = "Forced the Gantry maintenance cache"
	hud.show_dialogue("Maintenance Cache", "The panel pops on the third hit. Inside: a Gatebox optic still in corporate wrap and a roll of Wan Notes a patrol forgot to log. Carry the optic to the Coil to seat it.")
	hud.push_log("undercroft cache: Gatebox Eye MK1 + 12 Wan Notes")
	_refresh_hud()


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
	col_shape.radius = 1.1
	var collision := CollisionShape3D.new()
	collision.shape = col_shape
	area.add_child(collision)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = color.darkened(0.3)
	core_mat.emission_enabled = true
	core_mat.emission = color
	core_mat.emission_energy_multiplier = 0.9
	var core := MeshInstance3D.new()
	core.name = "BeaconCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.12
	core_mesh.height = 0.24
	core.mesh = core_mesh
	core.set_surface_override_material(0, core_mat)
	area.add_child(core)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = color.darkened(0.5)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 0.6
	var ring := MeshInstance3D.new()
	ring.name = "BeaconRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.26
	ring_mesh.outer_radius = 0.31
	ring.mesh = ring_mesh
	ring.set_surface_override_material(0, ring_mat)
	area.add_child(ring)
	var beacon_light := OmniLight3D.new()
	beacon_light.light_color = color
	beacon_light.light_energy = 1.0
	beacon_light.omni_range = 2.6
	area.add_child(beacon_light)
	return area


func _build_exits() -> void:
	_add_exit("ExitToLeakStreet", "Press E: return to Leak Street", LEAK_STREET_SCENE, Vector3(0.0, 1.0, 39.0), Color(0.08, 1.0, 0.45))
	_add_exit("ExitToComfortAnnexe", "Press E: take the ramp up the line to the Comfort Annexe", COMFORT_ANNEXE_SCENE, Vector3(-41.8, 1.0, -6.0), Color(1.0, 0.4, 0.62), Vector3(0, deg_to_rad(90.0), 0))
	_add_exit("ExitToRockerFellarKeep", "Press E: ride the service lift down to Rocker Fellar Keep", ROCKER_FELLAR_KEEP_SCENE, Vector3(41.8, 1.0, -6.0), Color(1.0, 0.55, 0.1), Vector3(0, deg_to_rad(-90.0), 0))


func _add_lights() -> void:
	# The two named sky lights drive the day/rain reaction (see _apply_sky_state).
	_sky_light = OmniLight3D.new()
	_sky_light.name = "FalseSkyOmni"
	_sky_light.position = Vector3(0, 9.0, 6)
	_sky_light.omni_range = 90.0
	_sky_light.light_energy = 1.1
	add_child(_sky_light)

	_sky_spot = OmniLight3D.new()
	_sky_spot.name = "SkyOmni"
	_sky_spot.position = Vector3(0, 8.5, -8)
	_sky_spot.omni_range = 70.0
	_sky_spot.light_energy = 0.8
	add_child(_sky_spot)

	# Accent lights to read the three termini + the camp.
	for data: Array in [
		[Vector3(0.0, 4.0, 38.0), Color(0.0, 1.0, 0.45), 1.4, 14.0],    # leak street door
		[Vector3(-40.0, 4.0, -6.0), Color(1.0, 0.4, 0.62), 1.6, 14.0],  # annexe portal
		[Vector3(40.0, 4.0, -6.0), Color(1.0, 0.55, 0.1), 1.6, 14.0],   # keep lift
		[Vector3(-14.0, 3.0, -8.0), Color(0.95, 0.6, 0.2), 1.3, 10.0],  # camp barrel fire
		[Vector3(0.0, 4.0, 2.0), Color(0.0, 0.75, 1.0), 1.2, 16.0],     # concourse center
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = float(data[3])
		add_child(light)


# ── Independent squatters camp (Phase 4 fills the NPCs) ─────────────
func _build_camp() -> void:
	# A few corrugated lean-tos in the sheltered northwest nook give the camp a footprint.
	_add_box("CampWall", Vector3(0.3, 2.4, 6.0), Vector3(-19.6, 1.0, -8.0), _mat_shack)
	_add_box("CampLeanTo", Vector3(5.0, 0.2, 4.0), Vector3(-16.0, 2.3, -8.0), _mat_shack, Vector3(deg_to_rad(-10.0), 0, 0))
	_add_box("CampCrate", Vector3(1.2, 1.2, 1.2), Vector3(-12.5, 0.6, -9.5), _mat_shack)
	_add_box("CampCrate2", Vector3(1.0, 1.0, 1.0), Vector3(-13.8, 0.5, -6.4), _mat_shack)
	_add_box("CampBarrelFire", Vector3(0.7, 0.9, 0.7), Vector3(-15.5, 0.45, -7.0), _mat_neon)

	_spawn_camp_npc("gantry_scavenger", "Scavenger Boss", "Press E: talk to the scavenger boss",
		Vector3(-14.4, 0.0, -9.0), "greenline")
	_spawn_camp_npc("annexe_escapee", "Annexe Escapee", "Press E: talk to the escapee",
		Vector3(-12.6, 0.0, -6.2), "greenline_alt")
	# A lone drifter loitering by the dead tram on the far side of the concourse.
	_spawn_camp_npc("gantry_drifter", "Tier Drifter", "Press E: talk to the drifter",
		Vector3(11.0, 0.0, 9.5), "greenline")


func _spawn_camp_npc(npc_id: String, npc_name: String, prompt: String, pos: Vector3, sprite_prefix: String) -> void:
	var npc := NPCDialogue.new()
	npc.npc_id = npc_id
	npc.npc_name = npc_name
	npc.prompt_text = prompt
	npc.position = pos
	npc.rotation_degrees.y = 90.0   # face out toward the concourse
	npc.add_to_group("npc")
	add_child(npc)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.3
	col.shape = shape
	npc.add_child(col)
	if not _add_camp_npc_sprite(npc, sprite_prefix):
		var mesh_inst := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.5
		mesh_inst.mesh = capsule
		mesh_inst.position = Vector3(0.0, 0.75, 0.0)
		mesh_inst.set_surface_override_material(0, _make_mat(Color(0.5, 0.55, 0.5), Color(0.1, 0.4, 0.3), 0.3, "", Vector3.ONE))
		npc.add_child(mesh_inst)


func _add_camp_npc_sprite(npc: NPCDialogue, prefix: String) -> bool:
	var base := "res://assets/sprites/greenline/%s_" % prefix
	var paths := PackedStringArray([
		base + "back.png", base + "back_left.png", base + "left.png", base + "front_left.png",
		base + "front.png", base + "front_right.png", base + "right.png", base + "back_right.png",
	])
	for path in paths:
		if not ResourceLoader.exists(path):
			return false
	var billboard := DirectionalBillboard.new()
	billboard.name = "Sprite3D"
	billboard.frame_paths = paths
	billboard.pixel_size = 0.0032
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.shaded = false
	billboard.double_sided = true
	billboard.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	billboard.position = Vector3(0.0, 0.9, 0.0)
	npc.add_child(billboard)
	return true


# ── Camp conversations (scripted statements; no DialogueDB profile needed) ──
func _talk_scavenger() -> void:
	var lines := [
		"Gantry Tier's the one deck nobody's flagged yet. Foundation thinks it's Gatebox's, Gatebox thinks it's transit's, transit got dissolved. So it's ours, mostly, until somebody reads a map.",
		"You're headed somewhere. Everybody on this deck is headed somewhere — that's the whole personality of the place. Annexe portal's west and up, the Keep lift's east and down. We just live in the middle and tax the view.",
		"Rain comes through the false sky in patches up here. Stand under an awning when the panels go green or you'll learn what 'soluble' means about your own coat.",
	]
	hud.open_statement("Scavenger Boss", lines[randi() % lines.size()])
	_refresh_hud()


func _talk_escapee() -> void:
	if not bool(GameState.get_world_flag("gantry_escapee_intel", false)):
		GameState.set_world_flag("gantry_escapee_intel", true)
		GameState.add_reputation("System X", 1)
		hud.open_statement("Annexe Escapee",
			"You're going UP there? On purpose?\" Her hands won't stay still. \"Listen — the ward reads everyone green. Every single resident, comfort nominal, dream stable. That's not health, that's a number they stopped letting move. I got out wearing pod issue and a face that isn't quite mine. Whatever you're looking for in there, count the residents twice. System X should hear that.")
		hud.push_log("escapee intel logged — System X rep up")
		return
	hud.open_statement("Annexe Escapee",
		"Still here. Still not going back up the line. The Gantry's cold and uninsured, but nothing in it tells me I'm fine while it edits me. Count them twice. That's all I've got.")
	_refresh_hud()


func _talk_drifter() -> void:
	var lines := [
		"I sleep in the dead tram. Best room on the Tier — it remembers being going-somewhere, so it's optimistic. You should sit in it once before you decide what you are.",
		"Watch the boss with the salvage scales. Fair enough, but 'fair' on the Gantry means he only takes the part of you you weren't using. Sell him scrap, not stories.",
		"People come through headed up to the Annexe or down to the Keep. The ones who go up come back wrong-quiet. The ones who go down mostly don't come back. You've got the look of someone who'll try both.",
	]
	hud.open_statement("Tier Drifter", lines[randi() % lines.size()])
	_refresh_hud()


# ── Gatebox patrol (rep-reactive: neutral checkpoint, or hostile if you've crossed Gatebox) ──
# Neutral: two pacified sentinels + a talkable officer who runs a comfort audit (the gatebox_checkpoint
# event card). Fire on a sentinel and the truce breaks. Hostile from the start if Gatebox rep is low
# enough: three sentinels, no conversation.
func _spawn_gatebox_patrol() -> void:
	var gatebox_rep := int(GameState.reputation.get("Gatebox Corporation", 0))
	_patrol_hostile = gatebox_rep <= GATEBOX_PATROL_HOSTILE_REP
	_spawn_patrol_guard(Vector3(4.0, 0.6, 5.0), 1, _patrol_hostile)
	_spawn_patrol_guard(Vector3(-4.0, 0.6, 0.0), 2, _patrol_hostile)
	if _patrol_hostile:
		_spawn_patrol_guard(Vector3(0.0, 0.6, 7.0), 3, true)   # the officer fights too
		hud.push_log("gatebox preservation patrol — flagged you non-compliant")
		hud.show_system_message("GATEBOX PRESERVATION PATROL — HOSTILE")
	else:
		_spawn_patrol_officer(Vector3(0.0, 0.0, 7.0))
		hud.push_log("gatebox wellness patrol holding the concourse — neutral")


func _spawn_patrol_guard(pos: Vector3, idx: int, hostile: bool) -> void:
	var guard := GOON_SCENE.instantiate()
	guard.name = "GateboxSentinel%d" % idx
	guard.position = pos
	# Match EnemyLayouts' "gatebox_android" identity so loot + the compendium read correctly.
	guard.set("faction", "Gatebox")
	guard.set("loot_id", "gatebox")
	guard.set("species_id", "gatebox_android")
	guard.add_to_group("gatebox_patrol")
	if hostile and "player_path" in guard:
		guard.player_path = NodePath("../Player")
	add_child(guard)
	if hostile:
		if guard.has_method("alert"):
			guard.alert()
	else:
		guard.set("patrol_neutral", true)              # walks a beat, won't lock on by sight
		guard.set("patrol_points", _patrol_route(idx))
		guard.damaged.connect(func(_a, _r): _provoke_patrol())   # shoot it → truce breaks
	if guard.has_signal("defeated"):
		guard.defeated.connect(func(): hud.push_log("gatebox sentinel down"))


# Looping beats for the neutral patrol, kept clear of the tram, camp, and the ramp gap.
func _patrol_route(idx: int) -> Array:
	if idx == 2:
		return [Vector3(-6, 0, 4), Vector3(-12, 0, -2), Vector3(-7, 0, -10), Vector3(-2, 0, 2)]
	return [Vector3(8, 0, 3), Vector3(15, 0, -5), Vector3(9, 0, -10), Vector3(2, 0, -3)]


func _spawn_patrol_officer(pos: Vector3) -> void:
	var officer := NPCDialogue.new()
	officer.npc_id = "gatebox_officer"
	officer.npc_name = "Patrol Officer"
	officer.prompt_text = "Press E: submit to the comfort audit"
	officer.position = pos
	officer.rotation_degrees.y = 180.0   # facing the arrival approach
	officer.add_to_group("npc")
	officer.add_to_group("gatebox_patrol_officer")
	add_child(officer)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.3
	col.shape = shape
	officer.add_child(col)
	# Gatebox-pink capsule so the officer reads distinct from the greenline squatters.
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	mesh_inst.mesh = capsule
	mesh_inst.position = Vector3(0.0, 0.8, 0.0)
	mesh_inst.set_surface_override_material(0, _make_mat(Color(0.35, 0.06, 0.2), Color(1.0, 0.2, 0.55), 0.7, "", Vector3.ONE))
	officer.add_child(mesh_inst)
	# focus_changed is wired by the group("npc") loop in _ready (this runs before it).
	_patrol_officer = officer


# Talking to the officer runs the standard Gatebox comfort audit (comply / bury-in-forms / walk past).
func _talk_officer() -> void:
	if _officer_audited:
		hud.open_statement("Patrol Officer", "Your audit is logged for this cycle, Citizen. Move along and stay optimized. Loitering is a comfort risk.")
		return
	if hud.event_card_ui != null:
		var card := WorldDirector.get_named_card("gatebox_checkpoint")
		if not card.is_empty():
			_officer_audited = true
			hud.open_statement("Patrol Officer", "Citizen. Your optimization profile is due for a comfort audit. This is for your wellbeing.")
			hud.event_card_ui.open(card)
			return
	hud.open_statement("Patrol Officer", "Move along, Comfort Citizen. Stay optimized.")


# Firing on a neutral sentinel collapses the truce: the whole patrol turns on you and your Gatebox
# standing takes the hit. The officer abandons the clipboard and joins as a third combatant.
func _provoke_patrol() -> void:
	if _patrol_provoked or _patrol_hostile:
		return
	_patrol_provoked = true
	if _patrol_officer != null and is_instance_valid(_patrol_officer):
		var officer_pos := _patrol_officer.global_position
		_patrol_officer.queue_free()
		_patrol_officer = null
		_spawn_patrol_guard(officer_pos + Vector3(0, 0.6, 0), 3, true)
	for g in get_tree().get_nodes_in_group("gatebox_patrol"):
		g.set("patrol_neutral", false)
		if "player_path" in g:
			g.player_path = NodePath("../Player")
		if g.has_method("alert"):
			g.alert()
	GameState.add_reputation("Gatebox Corporation", -1)
	hud.show_system_message("PATROL PROVOKED — GATEBOX HOSTILE")
	hud.push_log("you fired on the patrol — the truce is over, gatebox standing down")


# ── Helpers (mirrored from the job destinations) ────────────────────
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


func _add_shelter(world_position: Vector3) -> void:
	var shelter := ShelterZone.new()
	shelter.name = "ShelterNook"
	shelter.position = world_position
	add_child(shelter)
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 3.0, 5.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	shelter.add_child(collision)
	_add_box("ShelterAwning", Vector3(6.2, 0.18, 5.2), world_position + Vector3(0.0, 2.4, 0.0), _mat_neon)


func _add_exit(node_name: String, prompt: String, target_scene: String, world_position: Vector3, color: Color, world_rotation := Vector3.ZERO) -> void:
	var exit := MissionExit.new()
	exit.name = node_name
	exit.add_to_group("mission_exit")
	exit.prompt_text = prompt
	exit.target_scene = target_scene
	exit.position = world_position
	exit.rotation = world_rotation
	add_child(exit)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.5, 2.4, 1.4)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	exit.add_child(collision)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = color.darkened(0.3)
	frame_mat.emission_enabled = true
	frame_mat.emission = color
	frame_mat.emission_energy_multiplier = 1.0
	var frame := MeshInstance3D.new()
	frame.name = "ExitFrame"
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(3.7, 2.4, 0.08)
	frame.mesh = frame_mesh
	frame.position = Vector3(0.0, 0.2, -0.05)
	frame.set_surface_override_material(0, frame_mat)
	exit.add_child(frame)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.4, 2.1, 0.12)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = Vector3(0.0, 0.2, 0.0)
	visual.set_surface_override_material(0, _make_mat(color.darkened(0.6), color, 0.4, "res://assets/textures/leak_street/rusted_metal_wall.png", Vector3(3, 2, 1)))
	exit.add_child(visual)


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
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == KEY_E


func _is_save_key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == KEY_F5


func _is_load_key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == KEY_F6


func _is_tab_key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.keycode == KEY_TAB
