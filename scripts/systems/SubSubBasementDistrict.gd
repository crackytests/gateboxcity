extends Node3D

const RAIN_MUTANT_SCENE := preload("res://scenes/enemies/RainMutant.tscn")
const COOTERS_INTERIOR_SCENE := "res://scenes/levels/CootersInterior.tscn"
const SUITORS_INTERIOR_SCENE := "res://scenes/levels/SuitorsInterior.tscn"
const PIPE_TUNNELS_SCENE := "res://scenes/levels/PipeUtilityTunnels.tscn"
const DEAD_FOOD_COURT_SCENE := "res://scenes/levels/DeadFoodCourtBloom.tscn"
const WATER_CISTERN_SCENE := "res://scenes/levels/WaterReclamationCistern.tscn"
const COLLAPSED_ATRIUM_SCENE := "res://scenes/levels/CollapsedServiceAtrium.tscn"
const FADED_ATRIUM_SCENE := "res://scenes/levels/MallHub.tscn"
const WAKE_UP_CALL_SCENE := "res://scenes/levels/Test_SubSubBasement.tscn"

@onready var hud: HUDController = $HUD
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_npc: NPCDialogue
var focused_exit: MissionExit
var focused_generator
var focused_interactable: WardInteractable
var focused_district_npc: DistrictNPC
var focused_hack_terminal 
var _last_lighting_event := ""
var _streetlight_flicker_time := 0.0
var _streetlight_flicker_step := 0
var _debug_menu: CanvasLayer
var _debug_values_label: Label
var _debug_atlas_label: Label
var _debug_sliders := {}
var _debug_atlas_panels: Array[Sprite3D] = []
var _debug_selected_atlas := 0
var _debug_selected_value := 0
var _debug_keys := [
	"texture_brightness",
	"texture_emission",
	"facade_brightness",
	"ambient_energy",
	"fog_density",
	"wash_light_mult",
	"streetlight_mult",
	"atlas_x",
	"atlas_y",
	"atlas_w",
	"atlas_h",
	"atlas_scale",
]
var _debug_values := {
	"texture_brightness": 0.8,
	"texture_emission": 0.16,
	"facade_brightness": 1.2,
	"ambient_energy": 1.15,
	"fog_density": 0.02,
	"wash_light_mult": 1.0,
	"streetlight_mult": 1.0,
	"atlas_x": 0.0,
	"atlas_y": 0.0,
	"atlas_w": 0.0,
	"atlas_h": 0.0,
	"atlas_scale": 1.0,
}
var rain_mutant


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
	_sync_dreaming_generator_state()
	if WorldDirector.active_event == WorldDirector.EVENT_CLEAR and WorldDirector.get_generator_state() != WorldDirector.GENERATOR_STABLE:
		WorldDirector.trigger_event(WorldDirector.EVENT_TOXIC_RAIN)

	for npc in get_tree().get_nodes_in_group("npc"):
		npc.focus_changed.connect(_on_npc_focus_changed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	for generator in get_tree().get_nodes_in_group("generator"):
		generator.focus_changed.connect(_on_generator_focus_changed)
	for interactable in get_tree().get_nodes_in_group("district_interactable"):
		interactable.focus_changed.connect(_on_interactable_focus_changed)
	for district_npc in get_tree().get_nodes_in_group("district_npc"):
		district_npc.focus_changed.connect(_on_district_npc_focus_changed)
	for hack_terminal in get_tree().get_nodes_in_group("hack_terminal"):
		hack_terminal.focus_changed.connect(_on_hack_terminal_focus_changed)

	var hack_minigame = hud.get_node_or_null("%HackMinigameUI")
	if hack_minigame and hack_minigame.has_signal("hack_completed"):
		hack_minigame.hack_completed.connect(_on_hack_completed)
	if hud.travel_gate_ui != null and not hud.travel_gate_ui.route_selected.is_connected(_on_travel_route_selected):
		hud.travel_gate_ui.route_selected.connect(_on_travel_route_selected)

	_restore_cooters_encounter()
	_refresh_hud()
	_apply_world_lighting()
	_build_debug_tuning_menu()
	_apply_debug_tuning()
	hud.set_objective(_get_objective_text())
	hud.show_dialogue("System X", "Welcome to the district under the imitation of heaven. Rain first, questions later, panic whenever it becomes educational.")
	hud.push_log("sub-sub-basement district linked")


func _process(delta: float) -> void:
	if not _should_flicker_streetlights():
		return

	_streetlight_flicker_time += delta
	if _streetlight_flicker_time < 0.22:
		return

	_streetlight_flicker_time = 0.0
	_streetlight_flicker_step += 1
	_apply_generator_streetlights()
	_apply_canopy_lights()


func _input(event: InputEvent) -> void:
	if _is_debug_menu_key(event):
		_toggle_debug_menu()
		get_viewport().set_input_as_handled()
		return
	if _debug_menu != null and _debug_menu.visible:
		_handle_debug_tuning_input(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _debug_menu != null and _debug_menu.visible:
		return
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
	if focused_generator != null:
		var result: Dictionary = focused_generator.interact()
		hud.show_dialogue(str(result["name"]), str(result["text"]))
		_refresh_hud()
		_apply_world_lighting()
		return

	if focused_hack_terminal != null:
		var result: Dictionary = focused_hack_terminal.interact()
		if result.get("start_hack", false):
			hud.show_dialogue(str(result["name"]), str(result["text"]))
			hud.start_hack(int(result.get("difficulty", 1)))
		else:
			hud.show_dialogue(str(result["name"]), str(result["text"]))
		return

	if focused_interactable != null:
		_handle_district_interactable(focused_interactable)
		return

	if focused_district_npc != null:
		if focused_district_npc.npc_id == "velvet_coil":
			_handle_velvet_coil()
			return
		var line: Dictionary = focused_district_npc.interact()
		hud.show_dialogue(str(line["name"]), str(line["text"]))
		hud.push_log(str(line["text"]).to_lower())
		return

	if focused_npc != null:
		var line: Dictionary = focused_npc.interact()
		var speaker := str(line["name"])
		var text := str(line["text"])
		if speaker == "System X":
			text += "\n" + "\n".join(WorldDirector.get_event_status_lines())
		hud.show_dialogue(speaker, text)
		_refresh_hud()
		return

	if focused_exit != null:
		if not focused_exit.requires_completed_quest.is_empty() and not GameState.is_quest_completed(focused_exit.requires_completed_quest):
			hud.show_system_message(focused_exit.locked_message.to_upper())
			return
		get_tree().change_scene_to_file(focused_exit.target_scene)
		return


func _handle_district_interactable(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"torai_office":
			if GameState.get_world_flag("torai_obligation"):
				_handle_torai_followup()
			else:
				GameState.set_world_flag("torai_obligation", true)
				GameState.add_item("Cheap Poncho")
				GameState.add_reputation("Wan Moa Torai", 1)
				GameState.last_mission_result = "Accepted one more try"
				hud.show_dialogue("Wan Moa Torai", "Because everyone deserves one more try. Here is a poncho. The debt remembers you fondly, which is worse than hate.")
		"cooters":
			if GameState.is_quest_completed("cooters_rain_mutant_contained"):
				get_tree().change_scene_to_file(COOTERS_INTERIOR_SCENE)
				return
			if bool(GameState.get_world_flag("cooters_rain_mutant_active", false)):
				_handle_active_cooters_mutant()
				return
			if GameState.get_world_flag("cooters_neutralizer_claimed"):
				_handle_cooters_followup()
			else:
				GameState.set_world_flag("cooters_neutralizer_claimed", true)
				GameState.add_item("Chemical Neutralizer")
				GameState.add_reputation("System X", 1)
				GameState.last_mission_result = "Cooters rumor claimed"
				hud.show_dialogue("Marbles", "Marbles slides you a Chemical Neutralizer from under the bar like it owes her money. LAN kids are overclocking more than games tonight, so try not to become tonight's example.")
		"suitors":
			if GameState.get_world_flag("suitors_mask_claimed"):
				_handle_suitors_followup()
				return
			else:
				GameState.set_world_flag("suitors_mask_claimed", true)
				GameState.add_item("Sealed Mask")
				GameState.add_reputation("System X", 1)
				GameState.last_mission_result = "Suitors mask claimed"
				hud.show_dialogue("Sunday", "Sunday presses a Sealed Mask into your hands before you ask. Her face does not blink. The lounge remembers rain from other timelines and none of them were flattering.")
		"hoodlum_lan":
			_handle_lan_den()
		"rain_terminal":
			if WorldDirector.is_power_unstable() and not WorldDirector.is_toxic_rain_active():
				hud.show_dialogue("Rain Cycle Terminal", "Brownout mode. The sky controls are currently a suggestion box with electricity. Feed the Dreaming Generator at Pipe Chapel first.")
				_refresh_hud()
				return
			if WorldDirector.is_toxic_rain_active():
				WorldDirector.clear_event()
				hud.show_dialogue("System X", "Rain cycle paused. The false sky is pretending innocence again, huge performance, no notes.")
			else:
				WorldDirector.trigger_event(WorldDirector.EVENT_TOXIC_RAIN)
				hud.show_dialogue("System X", "Rain cycle forced. Pipe shelters are now survival infrastructure, which is a nice phrase for 'stand under the thing or melt.'")
		"dreaming_generator_reliquary":
			_handle_pipe_chapel_generator()
		"town_exit_gate":
			hud.open_travel_gate(_get_travel_routes())
		_:
			hud.show_dialogue(interactable.display_name, "Nothing else happens yet. It has the energy of a prop waiting for a better contract.")
	_refresh_hud()
	_apply_world_lighting()


func _handle_pipe_chapel_generator() -> void:
	var sale := GameState.sell_highest_wasted_potential_to_gideon()
	if sale.is_empty():
		var current := GameState.get_dreaming_generator_potential()
		hud.show_dialogue(
			"Pipe Father Gideon",
			"The Dreaming Generator is inside the chapel now, chewing on all the lives that almost became something. Bring mission loot, failed miracles, broken proofs. I can turn wasted potential into Wan Notes and keep the lights from learning despair.\nPotential: %d/%d." % [current, GameState.DREAMING_GENERATOR_THRESHOLD]
		)
		return

	var item_name := str(sale.get("item_name", "loot"))
	var wan_notes := int(sale.get("wan_notes", 0))
	var potential := int(sale.get("potential", 0))
	var new_total := int(sale.get("new_generator_potential", 0))
	var label := str(sale.get("label", "wasted potential"))
	GameState.mark_quest_completed("dreaming_generator_fed")
	if new_total >= GameState.DREAMING_GENERATOR_THRESHOLD:
		GameState.mark_quest_completed("patch_dreaming_generator")
		GameState.set_world_flag("patch_dreaming_generator", true)
		GameState.mark_quest_completed("dreaming_generator_sustained")
	_sync_dreaming_generator_state()
	hud.show_dialogue(
		"Pipe Father Gideon",
		"Gideon feeds %s into the chapel core: %s. The generator rises by %d wasted potential. Wan Moa Torai honors the sale with %d Wan Notes; System X honors the mistake by tracking every note.\nStored potential: %d/%d." % [
			item_name,
			label,
			potential,
			wan_notes,
			new_total,
			GameState.DREAMING_GENERATOR_THRESHOLD,
		]
	)
	hud.push_log("sold %s for %d wan notes" % [item_name.to_lower(), wan_notes])


func _handle_lan_den() -> void:
	if WorldDirector.active_event == WorldDirector.EVENT_LAN_OUTAGE:
		WorldDirector.set_generator_state(WorldDirector.GENERATOR_SAGGING)
		WorldDirector.trigger_event(WorldDirector.EVENT_POWER_SAG)
		GameState.add_reputation("Gatebox Corporation", 1)
		GameState.add_reputation("Wan Moa Torai", 1)
		GameState.mark_quest_completed("lan_party_brownout_stopped")
		hud.show_dialogue("Ladderboy", "Fine, fine, boring adult mode. Surveillance crawls back online, and my backpack is personally offended. It trained for this.")
	else:
		WorldDirector.set_generator_state(WorldDirector.GENERATOR_OVERLOADED)
		WorldDirector.trigger_event(WorldDirector.EVENT_LAN_OUTAGE)
		GameState.add_reputation("System X", 1)
		GameState.mark_quest_completed("lan_party_brownout_protected")
		hud.show_dialogue("Ladderboy", "LAN party protected. Every camera in two blocks just forgot how eyes work. That is infrastructure, not crime, please clap quietly.")


func _handle_velvet_coil() -> void:
	var upgrades: Array[Dictionary] = []
	for key in CyberneticSurgeryUI.UPGRADE_DB.keys():
		if not GameState.has_cybernetic(str(key)):
			upgrades.append({"id": str(key)})
	hud.show_dialogue("Velvet Coil", "Surgical suite is ready. Pick a slot, pick an implant. I learned this from a VHS tape, two broken androids, and one lawsuit that technically never found me.")
	hud.open_cybernetics(upgrades)


func _handle_cooters_followup() -> void:
	if GameState.is_quest_completed("cooters_rain_sample") and not bool(GameState.get_world_flag("cooters_rain_mutant_active", false)) and not GameState.is_quest_completed("cooters_rain_mutant_contained"):
		_start_cooters_rain_mutant()
		return

	if not GameState.is_quest_completed("cooters_rain_sample"):
		if WorldDirector.is_toxic_rain_active():
			GameState.mark_quest_completed("cooters_rain_sample")
			GameState.add_item("Cooters Bar Credit")
			GameState.add_reputation("System X", 1)
			GameState.last_mission_result = "Cooters rain sample collected"
			hud.show_dialogue("Marbles", "Marbles catches the rain in a chipped shot glass, watches it smoke, and slides you a bar credit. Scientific method, terrible glassware, no refunds.")
		else:
			hud.show_dialogue("Marbles", "I need a live rain sample before I can tell people which organs to worry about first. Force the rain cycle or wait for the sky to get mean on its own schedule.")
		return

	if not GameState.is_quest_completed("torai_salvage_contract"):
		hud.show_dialogue("Marbles", "Take that bar credit to Torai if you want paperwork. They can turn a drink token into a salvage contract and somehow make everyone apologize.")
		return

	hud.show_dialogue("Marbles", "Cooters interior is open if you can handle the smell of ambition and fryer oil. You already proved the rain is battery acid with management experience.")


func _handle_active_cooters_mutant() -> void:
	if rain_mutant == null or not is_instance_valid(rain_mutant):
		_spawn_rain_mutant()

	_grant_cooters_emergency_supplies()

	if rain_mutant != null and is_instance_valid(rain_mutant) and rain_mutant.has_method("can_be_bolted_down") and rain_mutant.can_be_bolted_down():
		_on_rain_mutant_containment_ready()
		return

	var hint := "Shoot the Rain Sac and Mobility Frame, then drag it onto the magenta Cooters pad."
	if rain_mutant != null and is_instance_valid(rain_mutant) and rain_mutant.has_method("get_containment_hint"):
		hint = str(rain_mutant.get_containment_hint())
	hud.show_dialogue("Marbles", hint)


func _grant_cooters_emergency_supplies() -> void:
	if GameState.get_world_flag("cooters_emergency_supplies_claimed"):
		return
	if weapon.current_ammo + weapon.reserve_ammo > 0 and player_health.current_hp > 20.0:
		return

	GameState.set_world_flag("cooters_emergency_supplies_claimed", true)
	weapon.current_ammo = weapon.magazine_size
	weapon.reserve_ammo = maxi(weapon.reserve_ammo, 24)
	weapon.ammo_changed.emit(weapon.current_ammo, weapon.reserve_ammo)
	if player_health.current_hp < 35.0:
		player_health.current_hp = 35.0
		player_health.health_changed.emit(player_health.current_hp, player_health.max_hp)
	hud.push_log("Marbles shoved emergency scrap and a stim through the door")


func _handle_suitors_followup() -> void:
	if not is_inside_tree():
		return
	if not ResourceLoader.exists(SUITORS_INTERIOR_SCENE):
		if hud != null:
			hud.show_dialogue("Suitors", "The Suitors door hums like it knows a secret and refuses to budget for a hallway.")
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(SUITORS_INTERIOR_SCENE)


func _handle_torai_followup() -> void:
	if GameState.is_quest_completed("cooters_rain_sample") and not GameState.is_quest_completed("torai_salvage_contract"):
		GameState.mark_quest_completed("torai_salvage_contract")
		GameState.add_item("Torai Salvage Contract")
		GameState.add_reputation("Wan Moa Torai", 1)
		GameState.last_mission_result = "Torai salvage contract issued"
		hud.show_dialogue("Wan Moa Torai", "Cooters confirms the rain is billable damage. Here is a salvage contract. Congratulations: your survival now has a form number and a tiny legal shadow.")
		return

	if GameState.is_quest_completed("torai_salvage_contract") and not GameState.is_quest_completed("district_side_jobs_intro_done"):
		GameState.mark_quest_completed("district_side_jobs_intro_done")
		hud.show_dialogue("Wan Moa Torai", "You now possess a poncho, a contract, and an obligation. This is the closest our office gets to affection without opening a second ledger.")
		return

	hud.show_dialogue("Wan Moa Torai", "Your one more try is already accruing meaning. Interest too, obviously. Meaning is never free down here.")


func _start_cooters_rain_mutant() -> void:
	GameState.set_world_flag("cooters_rain_mutant_active", true)
	GameState.last_mission_result = "Cooters rain mutant loose"
	WorldDirector.trigger_event(WorldDirector.EVENT_TOXIC_RAIN)
	_spawn_rain_mutant()
	hud.show_dialogue("Marbles", "The rain sample twitched off the bar and became a customer. Contain it under the awning before Cooters gets a second entrance and I start charging it rent.")
	hud.push_log("cooters emergency: rain mutant at the door")


func _restore_cooters_encounter() -> void:
	if GameState.is_quest_completed("cooters_rain_mutant_contained"):
		GameState.set_world_flag("cooters_unlocked", true)
		return
	if bool(GameState.get_world_flag("cooters_rain_mutant_active", false)):
		_spawn_rain_mutant()


func _spawn_rain_mutant() -> void:
	if rain_mutant != null and is_instance_valid(rain_mutant):
		return

	rain_mutant = RAIN_MUTANT_SCENE.instantiate()
	add_child(rain_mutant)
	rain_mutant.global_position = Vector3(6.6, 0.95, -10.6)
	rain_mutant.containment_center = Vector3(9.2, 0.0, -10.5)
	rain_mutant.player_path = NodePath("../Player")
	rain_mutant.body_part_destroyed.connect(_on_rain_mutant_part_destroyed)
	rain_mutant.attacked_player.connect(hud.push_log)
	rain_mutant.containment_ready.connect(_on_rain_mutant_containment_ready)


func _on_rain_mutant_part_destroyed(part_name: String) -> void:
	hud.push_log("rain mutant %s ruptured" % part_name.to_lower())
	if rain_mutant != null and is_instance_valid(rain_mutant) and rain_mutant.has_method("get_containment_hint"):
		hud.show_dialogue("Marbles", str(rain_mutant.get_containment_hint()))


func _on_rain_mutant_containment_ready() -> void:
	if GameState.is_quest_completed("cooters_rain_mutant_contained"):
		return

	if rain_mutant != null and is_instance_valid(rain_mutant):
		rain_mutant.contain()
	GameState.mark_quest_completed("cooters_rain_mutant_contained")
	GameState.set_world_flag("cooters_rain_mutant_active", false)
	GameState.set_world_flag("cooters_unlocked", true)
	GameState.add_reputation("System X", 1)
	GameState.add_item("Marbles Backroom Key")
	GameState.last_mission_result = "Cooters rain mutant contained"
	hud.show_dialogue("Marbles", "Good. You did not kill it; you made it manageable. That is basically bartending with worse shoes. Cooters back room is open.")
	hud.push_log("cooters unlocked")
	_refresh_hud()


func _refresh_hud() -> void:
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.set_objective(_get_objective_text())


func _apply_world_lighting() -> void:
	var generator_light := get_node_or_null("GeneratorOmni") as OmniLight3D
	var sky_light := get_node_or_null("FalseSkyOmni") as OmniLight3D
	var torai_light := get_node_or_null("ToraiOmni") as OmniLight3D
	var slum_light := get_node_or_null("SlumOmni") as OmniLight3D
	var market_light := get_node_or_null("MarketOmni") as OmniLight3D
	var lan_light := get_node_or_null("LANOmni") as OmniLight3D
	var sky_spot := get_node_or_null("SkyOmni") as OmniLight3D
	var dir_light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if generator_light == null or sky_light == null:
		return

	var gen_mat: StandardMaterial3D = null
	var is_sag := WorldDirector.active_event == WorldDirector.EVENT_POWER_SAG
	var is_rain := WorldDirector.active_event == WorldDirector.EVENT_TOXIC_RAIN
	var is_lan := WorldDirector.active_event == WorldDirector.EVENT_LAN_OUTAGE

	match WorldDirector.get_generator_state():
		WorldDirector.GENERATOR_STABLE:
			generator_light.light_color = Color(0.1, 1.0, 0.55)
			generator_light.light_energy = 2.4
			sky_light.light_energy = 1.15
			if gen_mat:
				gen_mat.emission = Color(0.0, 1.0, 0.4)
				gen_mat.emission_energy_multiplier = 2.2
		WorldDirector.GENERATOR_OVERLOADED:
			generator_light.light_color = Color(1.0, 0.12, 0.78)
			generator_light.light_energy = 3.0
			sky_light.light_energy = 0.45
			if gen_mat:
				gen_mat.emission = Color(1.0, 0.08, 0.6)
				gen_mat.emission_energy_multiplier = 3.5
		_:
			generator_light.light_color = Color(0.0, 0.85, 1.0)
			generator_light.light_energy = 1.4
			sky_light.light_energy = 0.7
			if gen_mat:
				gen_mat.emission = Color(0.0, 0.75, 1.0)
				gen_mat.emission_energy_multiplier = 1.2

	if is_sag:
		generator_light.light_energy *= 0.15
		generator_light.light_color = Color(0.6, 0.3, 0.05)
		sky_light.light_energy *= 0.12
		sky_light.light_color = Color(0.15, 0.08, 0.03)
		_set_zone_light(torai_light, 1.7 * 0.2, Color(0.1, 1.0, 0.45))
		_set_zone_light(slum_light, 0.25, Color(0.5, 0.2, 0.04))
		_set_zone_light(market_light, 0.25, Color(0.5, 0.2, 0.04))
		_set_zone_light(lan_light, 0.15, Color(0.4, 0.15, 0.02))
		_set_zone_light(sky_spot, 0.12, Color(0.3, 0.1, 0.02))
		if dir_light != null:
			dir_light.light_energy = 0.04
		if gen_mat:
			gen_mat.emission = Color(0.35, 0.15, 0.02)
			gen_mat.emission_energy_multiplier = 0.3
		if _last_lighting_event != "power_sag":
			hud.push_log("power sag: district lights failing")
		_last_lighting_event = "power_sag"
	elif is_lan:
		generator_light.light_energy *= 0.6
		generator_light.light_color = Color(1.0, 0.5, 0.0)
		sky_light.light_energy *= 0.5
		_set_zone_light(torai_light, 1.7, Color(0.1, 1.0, 0.45))
		_set_zone_light(slum_light, 1.0, Color(1.0, 0.45, 0.08))
		_set_zone_light(market_light, 0.8, Color(0.12, 1.0, 0.55))
		_set_zone_light(lan_light, 2.2, Color(0.08, 1.0, 0.5))
		_set_zone_light(sky_spot, 0.5, Color(0.0, 0.85, 1.0))
		if dir_light != null:
			dir_light.light_energy = 0.08
		if gen_mat:
			gen_mat.emission = Color(1.0, 0.4, 0.0)
			gen_mat.emission_energy_multiplier = 2.0
		_last_lighting_event = "lan_outage"
	else:
		sky_light.light_color = Color(0.22, 0.95, 0.82)
		_set_zone_light(torai_light, 1.7, Color(0.1, 1.0, 0.45))
		_set_zone_light(slum_light, 1.4, Color(1.0, 0.45, 0.08))
		_set_zone_light(market_light, 1.5, Color(0.12, 1.0, 0.55))
		_set_zone_light(lan_light, 1.3, Color(0.08, 1.0, 0.5))
		_set_zone_light(sky_spot, 1.2, Color(0.0, 0.85, 1.0))
		if is_rain:
			sky_light.light_color = Color(0.08, 0.45, 0.35)
			sky_light.light_energy *= 0.65
			_dim_zone_lights(0.7)
			if _last_lighting_event != "toxic_rain":
				hud.push_log("toxic rain: sky is leaking")
			_last_lighting_event = "toxic_rain"
		else:
			_last_lighting_event = "clear"
		if dir_light != null:
			dir_light.light_energy = 0.22
	_apply_generator_streetlights()
	_apply_canopy_lights()
	_apply_debug_tuning()


func _apply_canopy_lights() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var gen_state := WorldDirector.get_generator_state()
	var event_id := WorldDirector.active_event
	var panel_albedo := Color(1.0, 0.96, 0.78, 1.0)
	var panel_emission := Color(0.86, 0.62, 0.24)
	var panel_energy := 0.42
	if gen_state == WorldDirector.GENERATOR_OFFLINE:
		panel_albedo = Color(0.18, 0.15, 0.10, 1.0)
		panel_emission = Color(0.08, 0.02, 0.015)
		panel_energy = 0.02
	elif event_id == WorldDirector.EVENT_LAN_OUTAGE or gen_state == WorldDirector.GENERATOR_OVERLOADED:
		var sky_flicker_on := ((_streetlight_flicker_step % 4) != 0)
		panel_albedo = Color(1.0, 0.50, 0.58, 1.0) if sky_flicker_on else Color(0.32, 0.12, 0.16, 1.0)
		panel_emission = Color(0.92, 0.03, 0.36) if sky_flicker_on else Color(0.18, 0.02, 0.035)
		panel_energy = 1.05 if sky_flicker_on else 0.08
	elif event_id == WorldDirector.EVENT_POWER_SAG or gen_state == WorldDirector.GENERATOR_SAGGING:
		var sag_band_on := ((_streetlight_flicker_step % 3) != 1)
		panel_albedo = Color(0.78, 0.58, 0.25, 1.0) if sag_band_on else Color(0.34, 0.24, 0.13, 1.0)
		panel_emission = Color(0.92, 0.38, 0.03) if sag_band_on else Color(0.18, 0.09, 0.02)
		panel_energy = 0.34 if sag_band_on else 0.08
	elif event_id == WorldDirector.EVENT_TOXIC_RAIN:
		panel_albedo = Color(0.48, 0.86, 0.36, 1.0)
		panel_emission = Color(0.10, 0.82, 0.18)
		panel_energy = 0.58
	elif gen_state == WorldDirector.GENERATOR_STABLE and event_id == WorldDirector.EVENT_CLEAR:
		panel_albedo = Color(1.0, 0.96, 0.78, 1.0)
		panel_emission = Color(0.86, 0.62, 0.24)
		panel_energy = 0.42

	for panel_node in tree.get_nodes_in_group("district_canopy_panel"):
		var panel := panel_node as MeshInstance3D
		if panel == null:
			continue
		var material := panel.get_surface_override_material(0) as StandardMaterial3D
		if material == null:
			continue
		material.albedo_color = panel_albedo
		material.emission = panel_emission
		material.emission_energy_multiplier = panel_energy

	for light_node in tree.get_nodes_in_group("district_canopy_light"):
		var light := light_node as OmniLight3D
		if light == null:
			continue
		var base_energy := float(light.get_meta("base_energy", 2.8))
		var base_color: Color = light.get_meta("base_color", Color(0.0, 0.72, 0.82))
		light.light_color = base_color
		if gen_state == WorldDirector.GENERATOR_OFFLINE:
			light.light_energy = 0.15
			light.light_color = Color(0.04, 0.06, 0.08)
		elif gen_state == WorldDirector.GENERATOR_STABLE and event_id == WorldDirector.EVENT_CLEAR:
			light.light_energy = base_energy
			light.light_color = Color(0.95, 0.72, 0.34)
		elif event_id == WorldDirector.EVENT_LAN_OUTAGE or gen_state == WorldDirector.GENERATOR_OVERLOADED:
			var flicker_on := ((_streetlight_flicker_step + int(light.position.z)) % 5) != 0
			light.light_energy = base_energy * 1.2 if flicker_on else base_energy * 0.2
			light.light_color = Color(1.0, 0.15, 0.72) if int(light.position.x) % 2 == 0 else Color(1.0, 0.55, 0.04)
		elif event_id == WorldDirector.EVENT_POWER_SAG or gen_state == WorldDirector.GENERATOR_SAGGING:
			light.light_energy = base_energy * 0.25
			light.light_color = Color(0.55, 0.28, 0.06)
		elif event_id == WorldDirector.EVENT_TOXIC_RAIN:
			light.light_energy = base_energy * 0.85
			light.light_color = Color(0.12, 1.0, 0.28)
		else:
			light.light_energy = base_energy * 0.7


func _should_flicker_streetlights() -> bool:
	if WorldDirector.active_event in [WorldDirector.EVENT_POWER_SAG, WorldDirector.EVENT_LAN_OUTAGE]:
		return true
	return WorldDirector.get_generator_state() in [WorldDirector.GENERATOR_SAGGING, WorldDirector.GENERATOR_OVERLOADED]


func _apply_generator_streetlights() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var generator_state := WorldDirector.get_generator_state()
	var event_id := WorldDirector.active_event
	for fixture in tree.get_nodes_in_group("generator_streetlight"):
		var node := fixture as Node3D
		if node == null:
			continue

		var base_color: Color = node.get_meta("base_color", Color(0.1, 1.0, 0.72))
		var phase := int(node.get_meta("phase", 0))
		var energy := 1.6
		var bulb_visible := true
		var color := base_color

		if generator_state == WorldDirector.GENERATOR_OFFLINE:
			energy = 0.0
			bulb_visible = false
		elif generator_state == WorldDirector.GENERATOR_STABLE and event_id == WorldDirector.EVENT_CLEAR:
			energy = 2.25
		elif event_id == WorldDirector.EVENT_LAN_OUTAGE or generator_state == WorldDirector.GENERATOR_OVERLOADED:
			var hot_flicker := ((_streetlight_flicker_step + phase) % 4) != 0
			energy = 2.6 if hot_flicker else 0.45
			color = Color(1.0, 0.34, 0.04) if phase % 2 == 0 else Color(1.0, 0.06, 0.72)
		elif event_id == WorldDirector.EVENT_POWER_SAG or generator_state == WorldDirector.GENERATOR_SAGGING:
			var sag_on := ((_streetlight_flicker_step + phase) % 3) == 0
			var weak_on := ((_streetlight_flicker_step + phase) % 5) == 0
			energy = 0.95 if sag_on else (0.28 if weak_on else 0.0)
			bulb_visible = energy > 0.0
			color = Color(0.95, 0.5, 0.12)
		elif event_id == WorldDirector.EVENT_TOXIC_RAIN:
			energy = 1.15
			color = base_color.darkened(0.2)

		_set_streetlight_fixture(node, energy, color, bulb_visible)


func _set_streetlight_fixture(fixture: Node3D, energy: float, color: Color, bulb_visible: bool) -> void:
	var light := fixture.get_node_or_null("LampOmni") as OmniLight3D
	if light != null:
		light.light_energy = energy * float(_debug_values.get("streetlight_mult", 1.0))
		light.light_color = color
		light.omni_range = 5.4 if energy > 1.0 else 3.2

	var bulb := fixture.get_node_or_null("Bulb") as MeshInstance3D
	if bulb == null:
		return
	bulb.visible = bulb_visible
	var material := bulb.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color.darkened(0.45) if bulb_visible else Color(0.03, 0.03, 0.025)
	material.emission = color if bulb_visible else Color.BLACK
	material.emission_energy_multiplier = clampf(energy, 0.0, 2.5)


func _build_debug_tuning_menu() -> void:
	if _debug_menu != null:
		return

	_debug_atlas_panels.clear()
	for panel in get_tree().get_nodes_in_group("district_atlas_panel"):
		var sprite := panel as Sprite3D
		if sprite != null:
			_debug_atlas_panels.append(sprite)

	_debug_menu = CanvasLayer.new()
	_debug_menu.name = "DistrictTuningDebugMenu"
	_debug_menu.layer = 120
	_debug_menu.visible = false
	add_child(_debug_menu)

	var backing := ColorRect.new()
	backing.offset_left = 720.0
	backing.offset_top = 12.0
	backing.offset_right = 1268.0
	backing.offset_bottom = 705.0
	backing.color = Color(0.0, 0.0, 0.0, 0.78)
	_debug_menu.add_child(backing)

	_debug_values_label = Label.new()
	_debug_values_label.offset_left = 734.0
	_debug_values_label.offset_top = 24.0
	_debug_values_label.offset_right = 1255.0
	_debug_values_label.offset_bottom = 515.0
	_debug_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_menu.add_child(_debug_values_label)

	_debug_atlas_label = Label.new()
	_debug_atlas_label.offset_left = 734.0
	_debug_atlas_label.offset_top = 530.0
	_debug_atlas_label.offset_right = 1255.0
	_debug_atlas_label.offset_bottom = 690.0
	_debug_atlas_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_menu.add_child(_debug_atlas_label)

	_load_selected_debug_atlas_values()
	_update_debug_tuning_labels()


func _add_debug_slider(parent: VBoxContainer, label_text: String, key: String, min_value: float, max_value: float, step: float) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(_debug_values.get(key, min_value))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_debug_slider_changed.bind(key))
	_debug_sliders[key] = slider
	parent.add_child(slider)


func _on_debug_slider_changed(value: float, key: String) -> void:
	_debug_values[key] = value
	if key.begins_with("atlas_"):
		_apply_selected_debug_atlas_values()
	else:
		_apply_world_lighting()
	_apply_debug_tuning()
	_update_debug_tuning_labels()


func _handle_debug_tuning_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_UP:
			_debug_selected_value = wrapi(_debug_selected_value - 1, 0, _debug_keys.size())
		KEY_DOWN:
			_debug_selected_value = wrapi(_debug_selected_value + 1, 0, _debug_keys.size())
		KEY_LEFT:
			_nudge_debug_value(-1.0, key_event.shift_pressed)
		KEY_RIGHT:
			_nudge_debug_value(1.0, key_event.shift_pressed)
		KEY_PAGEUP:
			_select_previous_debug_atlas()
		KEY_PAGEDOWN:
			_select_next_debug_atlas()
		KEY_ENTER, KEY_KP_ENTER:
			_print_debug_tuning_values()
	_update_debug_tuning_labels()


func _nudge_debug_value(direction: float, fast: bool) -> void:
	if _debug_keys.is_empty():
		return
	var key: String = _debug_keys[_debug_selected_value]
	var step := _get_debug_step(key) * (10.0 if fast else 1.0)
	var next_value := float(_debug_values.get(key, 0.0)) + direction * step
	var limits := _get_debug_limits(key)
	next_value = clampf(next_value, float(limits.x), float(limits.y))
	_debug_values[key] = next_value
	if key.begins_with("atlas_"):
		_apply_selected_debug_atlas_values()
	else:
		_apply_world_lighting()
	_apply_debug_tuning()


func _get_debug_step(key: String) -> float:
	match key:
		"fog_density":
			return 0.0005
		"atlas_x", "atlas_y", "atlas_w", "atlas_h":
			return 1.0
		"atlas_scale":
			return 0.01
		_:
			return 0.01


func _get_debug_limits(key: String) -> Vector2:
	match key:
		"texture_brightness":
			return Vector2(0.15, 1.2)
		"texture_emission":
			return Vector2(0.0, 0.45)
		"facade_brightness":
			return Vector2(0.2, 1.4)
		"ambient_energy":
			return Vector2(0.0, 2.2)
		"fog_density":
			return Vector2(0.0, 0.02)
		"wash_light_mult":
			return Vector2(0.0, 2.0)
		"streetlight_mult":
			return Vector2(0.0, 3.0)
		"atlas_x", "atlas_y", "atlas_w", "atlas_h":
			return Vector2(0.0, 1254.0)
		"atlas_scale":
			return Vector2(0.25, 3.0)
		_:
			return Vector2(-999.0, 999.0)


func _toggle_debug_menu() -> void:
	if _debug_menu == null:
		_build_debug_tuning_menu()
	_debug_menu.visible = not _debug_menu.visible
	if _debug_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_load_selected_debug_atlas_values()
		_update_debug_tuning_labels()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _select_previous_debug_atlas() -> void:
	if _debug_atlas_panels.is_empty():
		return
	_debug_selected_atlas = wrapi(_debug_selected_atlas - 1, 0, _debug_atlas_panels.size())
	_load_selected_debug_atlas_values()
	_update_debug_tuning_labels()


func _select_next_debug_atlas() -> void:
	if _debug_atlas_panels.is_empty():
		return
	_debug_selected_atlas = wrapi(_debug_selected_atlas + 1, 0, _debug_atlas_panels.size())
	_load_selected_debug_atlas_values()
	_update_debug_tuning_labels()


func _get_selected_debug_atlas() -> Sprite3D:
	if _debug_atlas_panels.is_empty():
		return null
	_debug_selected_atlas = clampi(_debug_selected_atlas, 0, _debug_atlas_panels.size() - 1)
	return _debug_atlas_panels[_debug_selected_atlas]


func _load_selected_debug_atlas_values() -> void:
	var sprite := _get_selected_debug_atlas()
	if sprite == null:
		return
	var region := sprite.region_rect
	_debug_values["atlas_x"] = region.position.x
	_debug_values["atlas_y"] = region.position.y
	_debug_values["atlas_w"] = region.size.x
	_debug_values["atlas_h"] = region.size.y
	_debug_values["atlas_scale"] = sprite.scale.x
	_sync_debug_sliders()


func _apply_selected_debug_atlas_values() -> void:
	var sprite := _get_selected_debug_atlas()
	if sprite == null:
		return
	var region := Rect2(
		float(_debug_values.get("atlas_x", sprite.region_rect.position.x)),
		float(_debug_values.get("atlas_y", sprite.region_rect.position.y)),
		float(_debug_values.get("atlas_w", sprite.region_rect.size.x)),
		float(_debug_values.get("atlas_h", sprite.region_rect.size.y))
	)
	sprite.region_rect = region
	var scale_value := float(_debug_values.get("atlas_scale", 1.0))
	sprite.scale = Vector3(scale_value, scale_value, scale_value)


func _sync_debug_sliders() -> void:
	for key in _debug_sliders.keys():
		var slider := _debug_sliders[key] as HSlider
		if slider != null and _debug_values.has(key):
			slider.set_value_no_signal(float(_debug_values[key]))


func _apply_debug_tuning() -> void:
	var texture_brightness := float(_debug_values.get("texture_brightness", 0.8))
	var texture_emission := float(_debug_values.get("texture_emission", 0.16))
	var facade_brightness := float(_debug_values.get("facade_brightness", 1.2))

	for panel in get_tree().get_nodes_in_group("district_texture_panel"):
		var mesh := panel as MeshInstance3D
		if mesh == null:
			continue
		var material := mesh.get_surface_override_material(0) as StandardMaterial3D
		if material == null:
			continue
		if mesh.is_in_group("district_canopy_panel"):
			continue
		var brightness := facade_brightness if mesh.is_in_group("district_facade_panel") else texture_brightness
		material.albedo_color = Color(brightness, brightness, brightness, 1.0)
		material.emission = Color(0.08, 0.11, 0.095)
		material.emission_energy_multiplier = texture_emission

	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ambient_light_energy = float(_debug_values.get("ambient_energy", 1.15))
		world_environment.environment.fog_density = float(_debug_values.get("fog_density", 0.02))

	var wash_mult := float(_debug_values.get("wash_light_mult", 1.0))
	for light in get_tree().get_nodes_in_group("district_runtime_light"):
		var omni := light as OmniLight3D
		if omni == null:
			continue
		var base_energy := float(omni.get_meta("base_energy", omni.light_energy))
		omni.light_energy = base_energy * wash_mult


func _update_debug_tuning_labels() -> void:
	if _debug_values_label != null:
		var lines: Array[String] = [
			"LEAK STREET TUNING - F9 closes",
			"Up/Down select  Left/Right adjust  Shift=fast",
			"PageUp/PageDown atlas panel  Enter prints values",
			"",
		]
		for i in range(_debug_keys.size()):
			var key: String = _debug_keys[i]
			var marker := "> " if i == _debug_selected_value else "  "
			var format := "%.4f" if key == "fog_density" else "%.2f"
			if key in ["atlas_x", "atlas_y", "atlas_w", "atlas_h"]:
				format = "%.0f"
			lines.append("%s%s  %s" % [marker, key, format % float(_debug_values.get(key, 0.0))])
		_debug_values_label.text = "\n".join(lines)

	if _debug_atlas_label == null:
		return
	var sprite := _get_selected_debug_atlas()
	if sprite == null:
		_debug_atlas_label.text = "No atlas panels found."
		return
	var region := sprite.region_rect
	_debug_atlas_label.text = "atlas %d/%d %s\nregion %.0f, %.0f, %.0f, %.0f | scale %.2f" % [
		_debug_selected_atlas + 1,
		_debug_atlas_panels.size(),
		sprite.name,
		region.position.x,
		region.position.y,
		region.size.x,
		region.size.y,
		sprite.scale.x,
	]


func _print_debug_tuning_values() -> void:
	_update_debug_tuning_labels()
	if _debug_values_label != null:
		print(_debug_values_label.text)
	if _debug_atlas_label != null:
		print(_debug_atlas_label.text)


func _set_zone_light(light: OmniLight3D, energy: float, color: Color) -> void:
	if light == null:
		return
	light.light_energy = energy
	light.light_color = color


func _dim_zone_lights(factor: float) -> void:
	for light_name in ["ToraiOmni", "SlumOmni", "MarketOmni", "LANOmni", "SkyOmni"]:
		var light := get_node_or_null(light_name) as OmniLight3D
		if light != null:
			light.light_energy *= factor


func _get_gen_mat(mesh_node: MeshInstance3D) -> StandardMaterial3D:
	if mesh_node == null:
		return null
	var mat := mesh_node.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return null
	if not mat.resource_local_to_scene:
		var dupe := mat.duplicate()
		mesh_node.set_surface_override_material(0, dupe)
		return dupe
	return mat


func _get_objective_text() -> String:
	if not GameState.active_job_id.is_empty():
		return "Cooters job: %s" % GameState.get_active_job_objective_text()
	if bool(GameState.get_world_flag("cooters_rain_mutant_active", false)):
		return "Cooters emergency: rupture the mutant's key parts, drag it onto the magenta pad, then press E at Cooters."
	if GameState.is_dreaming_generator_failing():
		if GameState.get_sellable_wasted_potential_items().is_empty():
			return "District: take jobs, salvage wasted potential, then feed Gideon's Dreaming Generator."
		return "District: sell mission loot to Gideon at Pipe Chapel to feed the Dreaming Generator."
	if not GameState.get_world_flag("torai_obligation"):
		return "District: visit Wan Moa Torai for weather gear, then choose a route."
	if not GameState.get_world_flag("cooters_neutralizer_claimed") or not GameState.get_world_flag("suitors_mask_claimed"):
		return "District: collect rain countermeasures from Cooters and Suitors."
	if not GameState.is_quest_completed("cooters_rain_sample"):
		return "District job: bring Cooters a live toxic rain sample."
	if not GameState.is_quest_completed("cooters_rain_mutant_contained"):
		return "District job: check on the twitching Cooters rain sample."
	if not GameState.is_quest_completed("suitors_blind_spot"):
		return "District job: protect a LAN outage, then enter Suitors to map the blind spot."
	if not GameState.is_quest_completed("torai_salvage_contract"):
		return "District job: convert the Cooters sample into Torai paperwork."
	return "District: use Cooters, Suitors, the LAN Den, or the Wake-Up Call gate."


func _get_travel_routes() -> Array:
	var active_job := GameState.get_active_job_data()
	var active_destination := str(active_job.get("destination_id", ""))
	return [
		{
			"id": "pipe_utility_tunnels",
			"title": "Pipe Utility Tunnels",
			"description": "Wet maintenance arteries below Leak Street. Cooters jobs point there when the bar wants proof with pipe smell on it.",
			"target_scene": PIPE_TUNNELS_SCENE,
			"locked": active_destination != "pipe_utility_tunnels",
			"locked_reason": "Accept a Cooters job that points to the Pipe Utility Tunnels first.",
		},
		{
			"id": "dead_food_court_bloom",
			"title": "Dead Food Court Bloom",
			"description": "An old second-floor food court overgrown by bio-mall flora and still-lit menu boards.",
			"target_scene": DEAD_FOOD_COURT_SCENE,
			"locked": active_destination != "dead_food_court_bloom",
			"locked_reason": "Accept the Food Court Filter job first.",
		},
		{
			"id": "water_reclamation_cistern",
			"title": "Water Reclamation Cistern",
			"description": "A flooded reclamation room with live conduits, pump controls, and Torai-shaped ownership claims.",
			"target_scene": WATER_CISTERN_SCENE,
			"locked": active_destination != "water_reclamation_cistern",
			"locked_reason": "Accept the Pump Heart Lease job first.",
		},
		{
			"id": "collapsed_service_atrium",
			"title": "Collapsed Service Atrium",
			"description": "A partially submerged mall atrium where only the upper service level still crosses the sludge.",
			"target_scene": COLLAPSED_ATRIUM_SCENE,
			"locked": active_destination != "collapsed_service_atrium",
			"locked_reason": "Accept the Atrium Relay Echo job first.",
		},
		{
			"id": "faded_atrium",
			"title": "Faded Atrium",
			"description": "Return to the exposed second floor of the old submerged mall beside Leak Street.",
			"target_scene": FADED_ATRIUM_SCENE,
			"locked": false,
			"locked_reason": "",
		},
		{
			"id": "wake_up_call",
			"title": "Wake-Up Call",
			"description": "Re-enter the authored mission cell. Very official, very dramatic, bring your best bad decisions.",
			"target_scene": WAKE_UP_CALL_SCENE,
			"locked": GameState.is_dreaming_generator_failing(),
			"locked_reason": "Feed the Dreaming Generator at Pipe Chapel before using this route.",
		},
	]


func _on_travel_route_selected(route_id: String) -> void:
	var selected := {}
	for route in _get_travel_routes():
		if str(route.get("id", "")) == route_id:
			selected = route
			break
	if selected.is_empty():
		hud.show_system_message("ROUTE LOST")
		return
	if bool(selected.get("locked", false)):
		hud.show_dialogue("Leak Street Gate", str(selected.get("locked_reason", "Route locked.")))
		return

	var card := WorldDirector.roll_travel_event(route_id)
	var route_title := str(selected.get("title", route_id))
	GameState.last_mission_result = "Travel to %s: %s" % [route_title, str(card.get("title", "Clear Run"))]
	hud.push_log("travel event: %s" % str(card.get("title", "Clear Run")).to_lower())
	get_tree().change_scene_to_file(str(selected.get("target_scene", "")))


func _update_prompt() -> void:
	if focused_generator != null:
		hud.set_prompt(focused_generator.prompt_text)
	elif focused_interactable != null:
		hud.set_prompt(focused_interactable.prompt_text)
	elif focused_hack_terminal != null:
		hud.set_prompt(focused_hack_terminal.prompt_text)
	elif focused_district_npc != null:
		hud.set_prompt("Press E: talk to %s" % focused_district_npc.npc_name)
	elif focused_npc != null:
		hud.set_prompt(focused_npc.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	else:
		hud.set_prompt("")


func _on_npc_focus_changed(npc: NPCDialogue, has_focus: bool) -> void:
	focused_npc = npc if has_focus else null
	_update_prompt()


func _on_exit_focus_changed(mission_exit: MissionExit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _on_generator_focus_changed(generator, has_focus: bool) -> void:
	focused_generator = generator if has_focus else null
	_update_prompt()


func _on_interactable_focus_changed(interactable: WardInteractable, has_focus: bool) -> void:
	focused_interactable = interactable if has_focus else null
	_update_prompt()


func _on_district_npc_focus_changed(npc: DistrictNPC, has_focus: bool) -> void:
	focused_district_npc = npc if has_focus else null
	_update_prompt()


func _on_hack_terminal_focus_changed(terminal, has_focus: bool) -> void:
	focused_hack_terminal = terminal if has_focus else null
	_update_prompt()


func _on_hack_completed(success: bool, _difficulty: int) -> void:
	if focused_hack_terminal != null:
		focused_hack_terminal.complete_hack(success)
		if success:
			hud.show_dialogue("System X", "Signal routed. Access granted. The terminal blinked like it understood consequences.")
			hud.push_log("hack successful")
		else:
			hud.show_dialogue("System X", "Signal lost. The window closed and pretended it was never open.")
			hud.push_log("hack failed")
		_refresh_hud()


func _on_world_state_changed(_summary: String) -> void:
	_apply_world_lighting()
	hud.set_objective(_get_objective_text())


func _sync_dreaming_generator_state() -> void:
	var potential := GameState.get_dreaming_generator_potential()
	if potential <= 0:
		WorldDirector.set_generator_state(WorldDirector.GENERATOR_OFFLINE)
	elif potential < GameState.DREAMING_GENERATOR_THRESHOLD:
		WorldDirector.set_generator_state(WorldDirector.GENERATOR_SAGGING)
	else:
		WorldDirector.set_generator_state(WorldDirector.GENERATOR_STABLE)


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
		_apply_world_lighting()
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


func _is_debug_menu_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F9


func _is_tab_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB
