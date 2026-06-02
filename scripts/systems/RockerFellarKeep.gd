extends Node3D

# Rocker Fellar Keep — Dead city ruins deep beneath Leak Street.
# Collapsed buildings form street canyons. The concert arena is a crater
# where city blocks collapsed into an amphitheater. Collapsed highway
# overpasses form catwalks. Soul batteries glow in a sub-level vault.
# No ceilings in open areas — false sky visible through cracked cavern above.
#
# Zones:
#   1. Lift Plaza        — service lift, collapsed overpass gate, goon guards
#   2. Bass Boulevard    — ruined avenue between building shells, bass debris
#   3. VIP Tower Ruins   — collapsed penthouse (east), health cache, contract
#   4. Undercity Tunnels — subway remnants (west), cage evidence, vault hatch
#   5. The Bowl          — open crater arena, stage, blood pit, overpass catwalks
#   6. Soul Battery Vault — sub-level below tunnels, 4 batteries, soul burn
#
# Routes:
#   Route 1 — Frontal Assault: boulevard → bowl → fight to stage
#   Route 2 — Undercity Sabotage: tunnels → vault → weaken boss → stage flank
#   Route 3 — Tower + Overpass: tower loot → overpass catwalks → elevated attack

const MALLHUB_SCENE := "res://scenes/levels/MallHub.tscn"
const SECURITY_NODE_SCENE := preload("res://scenes/enemies/SecurityNode.tscn")
const GOON_SCENE := preload("res://scenes/enemies/GoonMaterial.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/RockerFellar.tscn")
const SPLICE_SCENE := preload("res://scenes/enemies/Splice.tscn")

@onready var hud: HUDController = $HUD
@onready var player: Node3D = $Player
@onready var player_health: PlayerHealth = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting

var focused_interactable: WardInteractable
var focused_exit: MissionExit

var _boss: Node3D
var _boss_phase := 1
var _boss_regen_rate := 3.0
var _boss_regen_active := true
var _boss_charge_recovery := false
var _boss_charge_recovery_timer := 0.0
var _boss_sonic_timer := 0.0
var _boss_cable_timer := 0.0
var _boss_charge_timer := 0.0
var _blood_pit_spawns: Array[Node3D] = []
var _blood_pit_spawn_timer := 0.0
var _blood_pit_alive_count := 0
var _boss_defeated := false

var _in_blood_pit := false
var _in_soul_burn := false
var _bass_debris_timer := 0.0
var _bass_debris_active := true

var _corridor_enemies: Array[Node3D] = []
var _concert_enemies: Array[Node3D] = []
var _backstage_enemies: Array[Node3D] = []
var _vip_enemies: Array[Node3D] = []
var _vault_enemy: Node3D

var _mat_asphalt: StandardMaterial3D
var _mat_concrete: StandardMaterial3D
var _mat_rubble: StandardMaterial3D
var _mat_building_dark: StandardMaterial3D
var _mat_rust: StandardMaterial3D
var _mat_dead_neon: StandardMaterial3D
var _mat_stage: StandardMaterial3D
var _mat_blood: StandardMaterial3D
var _mat_green_glow: StandardMaterial3D
var _mat_overpass: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_puddle: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	_build_geometry()
	_wire_runtime()
	_refresh_hud()
	hud.show_dialogue("Rocker Fellar Keep", "The service lift grinds to a halt. You step out into dead air and silence. Collapsed buildings on every side. Somewhere ahead, bass vibration throbs through the rubble. The city died here. Something else moved in after.")
	hud.push_log("rocker fellar keep entered")
	if GameState.get_world_flag("rocker_fellar_defeated", false):
		_boss_defeated = true
		_open_extraction()


func _process(delta: float) -> void:
	if _in_blood_pit and player != null and player.global_position.y < 1.2:
		player_health.apply_damage(2.0 * delta)
	if _in_soul_burn and player != null:
		player_health.apply_damage(2.0 * delta)
	if _bass_debris_active:
		_bass_debris_timer += delta
		if _bass_debris_timer >= 8.0:
			_bass_debris_timer = 0.0
			_do_bass_debris()
	if _boss != null and is_instance_valid(_boss) and not _boss_defeated:
		_process_boss(delta)


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
	_wire_enemy_group("keep_goon", _corridor_enemies)
	_wire_enemy_group("keep_concert_enemy", _concert_enemies)
	_wire_enemy_group("keep_backstage_enemy", _backstage_enemies)
	_wire_enemy_group("keep_vip_enemy", _vip_enemies)
	for vault_enemy in get_tree().get_nodes_in_group("keep_vault_enemy"):
		_vault_enemy = vault_enemy
		vault_enemy.player_path = NodePath("../Player")
		vault_enemy.attacked_player.connect(hud.push_log)
		vault_enemy.defeated.connect(func():
			hud.push_log("soul warden neutralized")
			_vault_enemy = null
		)
	for zone in get_tree().get_nodes_in_group("blood_pit_hazard"):
		zone.body_entered.connect(func(body: Node3D):
			if body.is_in_group("player"): _in_blood_pit = true
		)
		zone.body_exited.connect(func(body: Node3D):
			if body.is_in_group("player"): _in_blood_pit = false
		)
	for zone in get_tree().get_nodes_in_group("soul_burn_hazard"):
		zone.body_entered.connect(func(body: Node3D):
			if body.is_in_group("player"): _in_soul_burn = true
		)
		zone.body_exited.connect(func(body: Node3D):
			if body.is_in_group("player"): _in_soul_burn = false
		)
	for boss_node in get_tree().get_nodes_in_group("boss_rocker_fellar"):
		_boss = boss_node
		boss_node.player_path = NodePath("../Player")
		boss_node.attacked_player.connect(hud.push_log)
		boss_node.body_part_destroyed.connect(_on_boss_part_destroyed)
		boss_node.defeated.connect(_on_boss_defeated)
	_check_soul_batteries()
	if GameState.get_world_flag("fellar_vault_opened", false):
		_open_vault_passage()


func _wire_enemy_group(group_name: String, store: Array) -> void:
	for enemy in get_tree().get_nodes_in_group(group_name):
		store.append(enemy)
		enemy.player_path = NodePath("../Player")
		enemy.attacked_player.connect(hud.push_log)
		enemy.defeated.connect(func():
			hud.push_log("enemy neutralized")
			store.erase(enemy)
		)


func _handle_interact() -> void:
	if focused_interactable != null:
		_dispatch_interactable(focused_interactable)
		return
	if focused_exit != null:
		get_tree().change_scene_to_file(focused_exit.target_scene)


func _dispatch_interactable(interactable: WardInteractable) -> void:
	match interactable.interactable_id:
		"quest_gate":
			_use_quest_gate()
		"entrance_loot_crate":
			_use_loot_crate(interactable)
		"bass_debris_warning":
			hud.open_statement("Warning Graffiti", "Spray-painted across a collapsed storefront: THE BUILDING REMEMBERS WHAT THE BASS TELLS IT. HEAD DOWN WHEN THE WALLS SING. Below that, someone else wrote: this is not a metaphor.")
		"vip_health_cache":
			_use_health_cache(interactable)
		"vip_lore_contract":
			_use_lore_contract(interactable)
		"backstage_cage_evidence":
			_use_cage_evidence(interactable)
		"backstage_hatch":
			_use_backstage_hatch()
		"soul_battery_1", "soul_battery_2", "soul_battery_3", "soul_battery_4":
			_destroy_soul_battery(interactable)
		"pyro_charge_1", "pyro_charge_2", "pyro_charge_3":
			_detonate_pyro_charge(interactable)
		"amp_stack_1", "amp_stack_2", "amp_stack_3", "amp_stack_4", \
		"amp_stack_5", "amp_stack_6", "amp_stack_7", "amp_stack_8":
			_destroy_amp_stack(interactable)
		"extraction_lift":
			_use_extraction_lift()
		_:
			hud.show_dialogue(interactable.display_name, "Nothing happens. The dead city stares back.")


func _use_quest_gate() -> void:
	if not GameState.get_world_flag("quest_rocker_fellar_active", false):
		hud.show_dialogue("Collapsed Overpass", "A massive slab of concrete blocks the street. Big Gates Foundation biometric seals glow along the edge. You need System X authorization before the lock recognizes you as a threat worth admitting.")
		return
	if GameState.get_world_flag("rocker_fellar_defeated", false):
		hud.show_dialogue("Collapsed Overpass", "Already cleared. The General is gone. The rubble does not care.")
		return
	var gate_body := get_node_or_null("QuestGateBlock")
	if gate_body != null:
		gate_body.queue_free()
	hud.show_dialogue("Collapsed Overpass", "The biometric seals accept your System X token. Hydraulic pistons grind the concrete slab aside. The bass gets louder. The dead buildings ahead vibrate with it.")
	hud.push_log("boulevard gate opened")


func _use_loot_crate(interactable: WardInteractable) -> void:
	if GameState.get_world_flag("fellar_entrance_loot_used", false):
		hud.show_dialogue(interactable.display_name, "Already picked clean. The crate had a good run. Now it is just geometry with ambitions.")
		return
	GameState.set_world_flag("fellar_entrance_loot_used", true)
	weapon.current_ammo = mini(weapon.current_ammo + 6, weapon.magazine_size)
	weapon.reserve_ammo += 12
	weapon.ammo_changed.emit(weapon.current_ammo, weapon.reserve_ammo)
	player_health.heal(15.0)
	interactable.visible = false
	interactable.set_deferred("monitoring", false)
	hud.show_dialogue("Loot Crate", "A supply crate wedged behind a collapsed pillar. Six rounds for the pistol, twelve in reserve, and a single med patch. Someone stocked this for a siege that ended before it started.")
	hud.push_log("entrance loot recovered — ammo +18, health +15")
	_refresh_hud()


func _use_health_cache(interactable: WardInteractable) -> void:
	if GameState.get_world_flag("fellar_health_cache_used", false):
		hud.show_dialogue(interactable.display_name, "Already taken. The overturned bar has nothing left to give except stains and a view of the crater.")
		return
	player_health.heal(30.0)
	GameState.set_world_flag("fellar_health_cache_used", true)
	hud.show_dialogue("Health Cache", "A med kit behind what used to be a penthouse bar. The label says Gatebox Corporation Executive Wellness. The expiration date is a suggestion from a dead company. You use it anyway.")
	hud.push_log("health restored +30")
	_refresh_hud()


func _use_lore_contract(interactable: WardInteractable) -> void:
	if GameState.get_world_flag("fellar_contract_recovered", false):
		hud.show_dialogue(interactable.display_name, "You already have the contract. The logistics chain it describes has not gotten less horrible with re-reading.")
		return
	GameState.set_world_flag("fellar_contract_recovered", true)
	GameState.add_item("Fellar's Contract Ledger")
	hud.open_statement("Contract Ledger", "A procurement ledger inside a cracked executive desk. It links Big Gates Foundation soul harvesting to Gatebox Corporation logistics and Wan Moa Torai debt collection. Names, dates, tonnage. This is not a small thing. This is the first crack in the foundation.")
	hud.push_log("contract ledger recovered")
	_refresh_hud()


func _use_cage_evidence(interactable: WardInteractable) -> void:
	if GameState.get_world_flag("fellar_cage_evidence_found", false):
		hud.show_dialogue(interactable.display_name, "You already read the cage tags. The names have not improved.")
		return
	GameState.set_world_flag("fellar_cage_evidence_found", true)
	hud.open_statement("Cage Evidence", "Iron cages bolted to the subway platform. Torai shipping tags on each one. Every tag has a name, a debt amount, and a harvest date. The most recent one was three days ago. The cage is still warm.")
	hud.push_log("cage evidence catalogued")


func _use_backstage_hatch() -> void:
	if GameState.get_world_flag("fellar_vault_opened", false):
		hud.show_dialogue("Vault Hatch", "Already open. The ladder into the soul battery vault waits below.")
		return
	GameState.set_world_flag("fellar_vault_opened", true)
	_open_vault_passage()
	hud.show_dialogue("Vault Hatch", "The hatch releases with a pneumatic hiss. Below, green glow and humming. The soul batteries are charging. You can change that.")
	hud.push_log("soul battery vault opened")


func _open_vault_passage() -> void:
	var hatch_block := get_node_or_null("VaultHatchBlock")
	if hatch_block != null:
		hatch_block.queue_free()


func _destroy_soul_battery(interactable: WardInteractable) -> void:
	var id := interactable.interactable_id
	var flag_name := "fellar_battery_" + id.split("_")[2] + "_destroyed"
	if GameState.get_world_flag(flag_name, false):
		hud.show_dialogue(interactable.display_name, "Already destroyed. The cradle is cold and the soul fog has thinned.")
		return
	GameState.set_world_flag(flag_name, true)
	interactable.visible = false
	interactable.set_deferred("monitoring", false)
	_boss_regen_rate -= 0.75
	if _boss_regen_rate <= 0.0:
		_boss_regen_rate = 0.0
		_boss_regen_active = false
		hud.push_log("all soul batteries destroyed — boss regeneration disabled")
	else:
		hud.push_log("soul battery destroyed — boss regen reduced")
	GameState.add_item("Soul Residue", 2)
	hud.show_dialogue(interactable.display_name, "The battery cradle shatters. Green fog vents upward through the cracked concrete ceiling. A sound like a held breath releasing. Fellar feels it. You feel it too.")
	_check_soul_batteries()
	_refresh_hud()


func _check_soul_batteries() -> void:
	var all_destroyed := true
	for i in range(1, 5):
		if not GameState.get_world_flag("fellar_battery_%d_destroyed" % i, false):
			all_destroyed = false
			break
	if all_destroyed:
		_boss_regen_active = false
		_boss_regen_rate = 0.0
		hud.push_log("all soul batteries destroyed — boss regeneration fully disabled")


func _detonate_pyro_charge(interactable: WardInteractable) -> void:
	var flag_name := "fellar_" + interactable.interactable_id + "_used"
	if GameState.get_world_flag(flag_name, false):
		hud.show_dialogue(interactable.display_name, "Already detonated. Scorch marks and twisted metal. The stage does not need more fire.")
		return
	GameState.set_world_flag(flag_name, true)
	interactable.visible = false
	interactable.set_deferred("monitoring", false)
	# 15 damage in 3-unit radius
	var charge_pos := interactable.global_position
	if player != null:
		var dist := charge_pos.distance_to(player.global_position)
		if dist <= 3.0:
			player_health.apply_damage(15.0)
			hud.push_log("pyrotechnic detonation — 15 damage")
		else:
			hud.push_log("pyrotechnic detonation — you were clear of the blast")
	# Also damage boss if in range
	if _boss != null and is_instance_valid(_boss) and not _boss.is_defeated:
		var boss_dist := charge_pos.distance_to(_boss.global_position)
		if boss_dist <= 3.0:
			if _boss.has_method("get_node") and _boss.has_node("%BodyParts"):
				for child in _boss.get_node("%BodyParts").get_children():
					var part := child as BodyPart
					if part != null and not part.is_destroyed:
						part.apply_damage(20.0)
						break
			hud.push_log("pyrotechnic hit boss — 20 damage")
	hud.show_dialogue(interactable.display_name, "The charge erupts. Fire and smoke. The stage rail buckles. If anything was standing too close, it isn't standing as well now.")


func _destroy_amp_stack(interactable: WardInteractable) -> void:
	var id := interactable.interactable_id
	var flag_name := "fellar_" + id + "_destroyed"
	if GameState.get_world_flag(flag_name, false):
		hud.show_dialogue(interactable.display_name, "Already destroyed. A sparking crater in the wall where a speaker cabinet used to be.")
		return
	GameState.set_world_flag(flag_name, true)
	interactable.visible = false
	interactable.set_deferred("monitoring", false)
	var amp_alive := 8
	for i in range(1, 9):
		if GameState.get_world_flag("fellar_amp_stack_%d_destroyed" % i, false):
			amp_alive -= 1
	hud.push_log("amp stack destroyed — %d of 8 remaining" % amp_alive)
	hud.show_dialogue(interactable.display_name, "The amp stack sparks, buckles, and collapses. One less speaker feeding Fellar's shockwaves. The bass gets a little less certain.")
	if amp_alive == 0 and not GameState.get_world_flag("fellar_amp_stacks_destroyed", false):
		GameState.set_world_flag("fellar_amp_stacks_destroyed", true)
		hud.push_log("all amp stacks destroyed — boss sonic damage eliminated")
	_refresh_hud()


func _use_extraction_lift() -> void:
	if not _boss_defeated:
		hud.show_dialogue("Extraction Point", "A service lift shaft sealed with Big Gates biometrics. Requires a General's signature. Rocker Fellar is still performing. End the show first.")
		return
	GameState.set_world_flag("rocker_fellar_defeated", true)
	GameState.set_world_flag("quest_rocker_fellar_complete", true)
	GameState.add_item("Fellar's Jaw Amplifier")
	GameState.add_item("General's Insignia")
	GameState.add_reputation("System X", 3)
	GameState.add_reputation("Gatebox Corporation", -2)
	hud.show_dialogue("Extraction Lift", "The lift accepts Fellar's insignia. As you rise, the dead city falls away — the blood pit, the amp stacks bolted to rubble, the empty stage. The contract ledger weighs heavy. The city is about to learn what its foundations are made of.")
	hud.push_log("rocker fellar defeated — extraction complete")
	_refresh_hud()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(MALLHUB_SCENE)


# ---- Boss Logic ----

func _process_boss(delta: float) -> void:
	if _boss.is_defeated or _boss.is_pacified:
		return
	if _boss_regen_active and _boss_regen_rate > 0.0:
		if _boss.has_method("regen_all_parts"):
			_boss.regen_all_parts(_boss_regen_rate * delta)
	match _boss_phase:
		1: _process_phase_1(delta)
		2: _process_phase_2(delta)
		3: _process_phase_3(delta)
	if _boss_phase >= 2:
		_blood_pit_spawn_timer += delta
		if _blood_pit_spawn_timer >= 15.0 and _blood_pit_alive_count < 6:
			_blood_pit_spawn_timer = 0.0
			_spawn_blood_pit_horror()


func _process_phase_1(delta: float) -> void:
	_boss_sonic_timer += delta
	if _boss_sonic_timer >= 3.0:
		_boss_sonic_timer = 0.0
		_do_boss_sonic_attack()


func _process_phase_2(delta: float) -> void:
	_boss_cable_timer += delta
	var dist := _boss.global_position.distance_to(player.global_position)
	if dist <= 3.0 and _boss_cable_timer >= 1.5:
		_boss_cable_timer = 0.0
		_do_boss_cable_attack()
	elif dist > 3.0:
		_boss_sonic_timer += delta
		if _boss_sonic_timer >= 3.0:
			_boss_sonic_timer = 0.0
			_do_boss_sonic_attack()


func _process_phase_3(delta: float) -> void:
	if _boss_charge_recovery:
		_boss_charge_recovery_timer -= delta
		if _boss_charge_recovery_timer <= 0.0:
			_boss_charge_recovery = false
		return
	_boss_charge_timer += delta
	if _boss_charge_timer >= 5.0:
		_boss_charge_timer = 0.0
		_do_boss_charge()


func _do_boss_sonic_attack() -> void:
	if _boss == null or not is_instance_valid(_boss): return
	var dist := _boss.global_position.distance_to(player.global_position)
	if dist > 15.0: return
	var amp_stacks_alive := 8
	for i in range(1, 9):
		if GameState.get_world_flag("fellar_amp_%d_destroyed" % i, false):
			amp_stacks_alive -= 1
	var damage_mult := float(amp_stacks_alive) / 8.0
	player_health.apply_damage(8.0 * damage_mult)
	hud.push_log("boss sonic shockwave — %.0f damage" % (8.0 * damage_mult))


func _do_boss_cable_attack() -> void:
	player_health.apply_damage(12.0)
	hud.push_log("boss cable whip — 12 damage")


func _do_boss_charge() -> void:
	player_health.apply_damage(18.0)
	player.set_meta("stun_timer", 1.5)
	hud.push_log("boss charge — 18 damage — stunned")
	_boss_charge_recovery = true
	_boss_charge_recovery_timer = 2.0
	if _boss != null and is_instance_valid(_boss) and _boss.has_method("expose_stage_core"):
		_boss.expose_stage_core(true)


func _on_boss_part_destroyed(part_name: String) -> void:
	hud.push_log("boss part destroyed: %s" % part_name)
	var destroyed_count := 0
	if _boss != null and is_instance_valid(_boss) and _boss.has_method("get_destroyed_part_count"):
		destroyed_count = _boss.get_destroyed_part_count()
	elif _boss != null and is_instance_valid(_boss) and _boss.get("is_defeated"):
		destroyed_count = 3
	match part_name:
		"Jaw Amplifier":
			if _boss_phase == 1: _enter_phase_2()
		"Soul Resonator":
			if _boss_phase == 1: _enter_phase_2()
		"Amplifier Spine":
			hud.push_log("boss spine shattered — movement reduced 60%")
			if _boss != null and is_instance_valid(_boss):
				_boss.move_speed *= 0.4
	if destroyed_count >= 3 and _boss_phase < 3:
		_enter_phase_3()
	_refresh_hud()


func _enter_phase_2() -> void:
	_boss_phase = 2
	hud.push_log("boss entered phase 2 — encore")
	hud.show_dialogue("Rocker Fellar", "The General descends from the stage into the crater floor. Cable whips uncoil. The concert has become personal. The blood pit starts to bubble.")
	_boss_sonic_timer = 0.0
	_boss_cable_timer = 0.0
	if _boss != null and is_instance_valid(_boss) and _boss.has_method("descend_from_stage"):
		_boss.descend_from_stage()


func _enter_phase_3() -> void:
	_boss_phase = 3
	hud.push_log("boss entered phase 3 — feedback loop")
	hud.show_dialogue("Rocker Fellar", "The amplifier spine blazes. Fellar charges across the crater floor. The stage core is exposed during recovery — aim for the back.")
	_boss_charge_timer = 0.0


func _on_boss_defeated() -> void:
	_boss_defeated = true
	GameState.set_world_flag("rocker_fellar_defeated", true)
	hud.push_log("rocker fellar defeated")
	hud.show_dialogue("Rocker Fellar", "The Stage Core overloads. Fellar shatters into feedback static and collapsed chrome. The bass stops. The dead city is quiet again. The extraction shaft is now active.")
	_open_extraction()
	for horror in _blood_pit_spawns:
		if is_instance_valid(horror): horror.queue_free()
	_blood_pit_spawns.clear()
	_refresh_hud()


func _spawn_blood_pit_horror() -> void:
	var horror := GOON_SCENE.instantiate()
	var rx := randf_range(-6.0, 6.0)
	var rz := randf_range(-46.0, -42.0)
	horror.position = Vector3(rx, -0.5, rz)
	horror.name = "BloodPitHorror"
	horror.add_to_group("blood_pit_horror")
	add_child(horror)
	horror.player_path = NodePath("../Player")
	horror.move_speed = 3.5
	horror.attacked_player.connect(hud.push_log)
	horror.defeated.connect(func():
		hud.push_log("blood pit horror destroyed")
		_blood_pit_alive_count -= 1
		_blood_pit_spawns.erase(horror)
	)
	_blood_pit_spawns.append(horror)
	_blood_pit_alive_count += 1
	hud.push_log("blood pit horror claws up from the crater")


func _open_extraction() -> void:
	var exit_node := get_node_or_null("ExtractionLift")
	if exit_node != null:
		exit_node.prompt_text = "Press E: extraction lift — return to Faded Atrium"


func _do_bass_debris() -> void:
	if player == null: return
	var pz := player.global_position.z
	if pz > -2.0 or pz < -28.0: return
	hud.push_log("bass vibration — building debris falls from above")
	player_health.apply_damage(8.0)


# ---- Geometry & Materials ----

func _build_materials() -> void:
	_mat_asphalt = _make_mat(Color(0.18, 0.16, 0.14), Color(0.02, 0.02, 0.02), 0.1, "", Vector3(4, 4, 1))
	_mat_concrete = _make_mat(Color(0.28, 0.26, 0.24), Color(0.01, 0.01, 0.01), 0.05, "", Vector3(3, 3, 1))
	_mat_rubble = _make_mat(Color(0.22, 0.20, 0.18), Color(0.01, 0.01, 0.01), 0.08, "", Vector3.ONE)
	_mat_building_dark = _make_mat(Color(0.12, 0.11, 0.10), Color(0.005, 0.005, 0.005), 0.05, "", Vector3(2, 2, 1))
	_mat_rust = _make_mat(Color(0.45, 0.28, 0.15), Color(0.08, 0.04, 0.01), 0.2, "", Vector3.ONE)
	_mat_dead_neon = _make_mat(Color(0.08, 0.06, 0.08), Color(0.3, 0.0, 0.3), 0.8, "", Vector3.ONE)
	_mat_stage = _make_mat(Color(0.15, 0.08, 0.08), Color(0.4, 0.1, 0.1), 1.5, "", Vector3(4, 8, 1))
	_mat_blood = _make_mat(Color(0.15, 0.02, 0.02), Color(0.3, 0.0, 0.0), 1.0, "", Vector3.ONE)
	_mat_green_glow = _make_mat(Color(0.05, 0.15, 0.05), Color(0.0, 0.8, 0.2), 2.0, "", Vector3.ONE)
	_mat_overpass = _make_mat(Color(0.25, 0.25, 0.22), Color(0.02, 0.02, 0.02), 0.1, "", Vector3(2, 6, 1))
	_mat_metal = _make_mat(Color(0.3, 0.3, 0.28), Color(0.05, 0.05, 0.05), 0.15, "", Vector3.ONE)
	_mat_puddle = _make_mat(Color(0.05, 0.12, 0.08, 0.6), Color(0.0, 0.2, 0.1), 0.5, "", Vector3.ONE)
	_mat_puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_geometry() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.05, 0.07)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.02, 0.04)
	env.fog_density = 0.018
	env_node.environment = env
	add_child(env_node)

	# --- Zone 1: Lift Plaza (south entry, z 0..12) ---
	_add_box("LiftPlazaFloor", Vector3(16, 0.5, 12), Vector3(0, -0.25, 6), _mat_asphalt)
	_add_box("PlazaSouthWall", Vector3(16, 5.5, 0.35), Vector3(0, 2.75, 12), _mat_building_dark)
	_add_box("PlazaEastShell", Vector3(0.35, 4.0, 8), Vector3(8, 2.0, 4), _mat_building_dark)
	_add_box("PlazaWestShell", Vector3(0.35, 4.0, 8), Vector3(-8, 2.0, 4), _mat_building_dark)
	_add_box("PlazaNorthLeft", Vector3(5, 4.5, 0.35), Vector3(-5.5, 2.25, 0), _mat_building_dark)
	_add_box("PlazaNorthRight", Vector3(5, 4.5, 0.35), Vector3(5.5, 2.25, 0), _mat_building_dark)
	_add_box("QuestGateBlock", Vector3(4, 3.0, 1.5), Vector3(0, 1.5, 0), _mat_rust)
	for rd: Array in [[-4, 3], [5, 9], [-6, 7], [3, 5]]:
		_add_box("PlazaRubble", Vector3(1.5, 0.8, 1.5), Vector3(rd[0], 0.4, rd[1]), _mat_rubble)
	_add_interactable("quest_gate", "Collapsed Overpass", "Press E: force gate open", Vector3(0, 1.5, -0.5), Color(0.85, 0.55, 0.1))
	_add_interactable("entrance_loot_crate", "Loot Crate", "Press E: search supply crate", Vector3(-5, 0.95, 8), Color(0.7, 0.55, 0.2))

	# --- Zone 2: Bass Boulevard (z -20..0) ---
	_add_box("BoulevardFloor", Vector3(16, 0.5, 20), Vector3(0, -0.25, -10), _mat_asphalt)
	_add_box("BlvdEastSouth", Vector3(0.35, 6.0, 6), Vector3(8, 3.0, -3), _mat_building_dark)
	_add_box("BlvdEastNorth", Vector3(0.35, 6.0, 6), Vector3(8, 3.0, -17), _mat_building_dark)
	_add_box("BlvdWestSouth", Vector3(0.35, 6.0, 6), Vector3(-8, 3.0, -3), _mat_building_dark)
	_add_box("BlvdWestNorth", Vector3(0.35, 6.0, 6), Vector3(-8, 3.0, -17), _mat_building_dark)
	for rd: Array in [[-3, -4], [4, -8], [-5, -14], [2, -2], [6, -12], [-6, -10]]:
		_add_box("BlvdRubble", Vector3(2.0, 1.0, 2.0), Vector3(rd[0], 0.5, rd[1]), _mat_rubble)
	# Toxic puddles (visual)
	for pp: Vector3 in [Vector3(-2, 0.01, -7), Vector3(4, 0.01, -15)]:
		var pm := BoxMesh.new()
		pm.size = Vector3(3.0, 0.05, 2.5)
		var pv := MeshInstance3D.new()
		pv.mesh = pm
		pv.set_surface_override_material(0, _mat_puddle)
		pv.position = pp
		add_child(pv)
	_add_interactable("bass_debris_warning", "Warning Graffiti", "Press E: read graffiti", Vector3(-5, 1.5, -10), Color(0.85, 0.2, 0.2))
	# Dead neon sign (visual)
	var nm := BoxMesh.new()
	nm.size = Vector3(6.0, 0.8, 0.1)
	var nv := MeshInstance3D.new()
	nv.mesh = nm
	nv.set_surface_override_material(0, _mat_dead_neon)
	nv.position = Vector3(0, 4.5, -10)
	add_child(nv)

	# --- Zone 3: VIP Tower Ruins (east, z -14..-6, x 6..14) ---
	_add_box("VIPFloor", Vector3(8, 0.5, 8), Vector3(10, -0.25, -10), _mat_concrete)
	_add_box("VIPNorth", Vector3(8, 3.5, 0.35), Vector3(10, 1.75, -14), _mat_building_dark)
	_add_box("VIPEast", Vector3(0.35, 3.5, 8), Vector3(14, 1.75, -10), _mat_building_dark)
	_add_box("VIPSouth", Vector3(8, 3.5, 0.35), Vector3(10, 1.75, -6), _mat_building_dark)
	_add_box("VIPCeiling", Vector3(6, 0.25, 6), Vector3(10, 3.0, -10), _mat_building_dark)
	_add_box("VIPRubble1", Vector3(2.0, 1.0, 1.5), Vector3(8, 0.5, -12), _mat_rubble)
	_add_box("VIPRubble2", Vector3(1.5, 0.8, 2.0), Vector3(12, 0.4, -8), _mat_rubble)
	_add_interactable("vip_health_cache", "Health Cache", "Press E: search health cache", Vector3(8, 0.95, -12), Color(0.2, 0.8, 0.2))
	_add_interactable("vip_lore_contract", "Contract Ledger", "Press E: examine contract", Vector3(12, 0.95, -12), Color(0.8, 0.6, 0.1))

	# --- Zone 4: Undercity Tunnels (west, z -14..-6, x -14..-6) ---
	_add_box("UCFloor", Vector3(8, 0.5, 8), Vector3(-10, -0.25, -10), _mat_concrete)
	_add_box("UCNorth", Vector3(8, 3.5, 0.35), Vector3(-10, 1.75, -14), _mat_building_dark)
	_add_box("UCWest", Vector3(0.35, 3.5, 8), Vector3(-14, 1.75, -10), _mat_building_dark)
	_add_box("UCSouth", Vector3(8, 3.5, 0.35), Vector3(-10, 1.75, -6), _mat_building_dark)
	_add_box("UCEiling", Vector3(8, 0.25, 8), Vector3(-10, 1.5, -10), _mat_building_dark)
	_add_box("VaultHatchBlock", Vector3(2, 0.1, 2), Vector3(-10, -0.05, -14), _mat_metal)
	_add_box("UCRubble1", Vector3(1.5, 0.8, 1.5), Vector3(-12, 0.4, -8), _mat_rubble)
	_add_box("UCRubble2", Vector3(2.0, 0.6, 1.0), Vector3(-8, 0.3, -12), _mat_rubble)
	_add_interactable("backstage_cage_evidence", "Cage Evidence", "Press E: examine cages", Vector3(-12, 0.95, -10), Color(0.8, 0.4, 0.1))
	_add_interactable("backstage_hatch", "Vault Hatch", "Press E: open vault hatch", Vector3(-10, 0.05, -14), Color(0.2, 0.8, 0.2))

	# --- Zone 5: The Bowl (crater arena, z -48..-20, x -16..16) ---
	_add_box("BowlFloor", Vector3(32, 0.5, 28), Vector3(0, -0.25, -34), _mat_asphalt)
	_add_box("BowlEast", Vector3(0.35, 8.5, 28), Vector3(16, 4.25, -34), _mat_building_dark)
	_add_box("BowlWest", Vector3(0.35, 8.5, 28), Vector3(-16, 4.25, -34), _mat_building_dark)
	_add_box("BowlNorth", Vector3(32, 8.5, 0.35), Vector3(0, 4.25, -48), _mat_building_dark)
	_add_box("BowlSouthL", Vector3(12, 8.5, 0.35), Vector3(-10, 4.25, -20), _mat_building_dark)
	_add_box("BowlSouthR", Vector3(12, 8.5, 0.35), Vector3(10, 4.25, -20), _mat_building_dark)
	# Stage (elevated north end)
	_add_box("StagePlatform", Vector3(12, 0.28, 8), Vector3(0, 1.66, -44), _mat_stage)
	_add_ramp("StageRamp", Vector3(4, 0.2, 8), Vector3(0, 0.9, -36), _mat_metal, 0.227)
	# Blood pit (sunken center)
	_add_box("BloodPitFloor", Vector3(16, 0.5, 8), Vector3(0, -1.25, -34), _mat_blood)
	_add_box("BloodPitN", Vector3(16, 1.5, 0.35), Vector3(0, -0.25, -30), _mat_building_dark)
	_add_box("BloodPitS", Vector3(16, 1.5, 0.35), Vector3(0, -0.25, -38), _mat_building_dark)
	_add_box("BloodPitE", Vector3(0.35, 1.5, 8), Vector3(8, -0.25, -34), _mat_building_dark)
	_add_box("BloodPitW", Vector3(0.35, 1.5, 8), Vector3(-8, -0.25, -34), _mat_building_dark)
	var blood_area := Area3D.new()
	blood_area.name = "BloodPitHazard"
	blood_area.add_to_group("blood_pit_hazard")
	blood_area.position = Vector3(0, -0.5, -34)
	add_child(blood_area)
	var bs := BoxShape3D.new()
	bs.size = Vector3(15.0, 2.0, 7.0)
	var bc := CollisionShape3D.new()
	bc.shape = bs
	blood_area.add_child(bc)
	# Collapsed highway overpasses (catwalks)
	_add_box("NorthCatwalk", Vector3(32, 0.2, 2), Vector3(0, 5.4, -45), _mat_overpass)
	_add_box("SouthCatwalk", Vector3(32, 0.2, 2), Vector3(0, 5.4, -21), _mat_overpass)
	for side: int in [-1, 1]:
		for zp: float in [-45.0, -21.0]:
			_add_box("CatPillar", Vector3(0.4, 5.5, 0.4), Vector3(side * 14, 2.75, zp), _mat_metal)
	# Catwalk access ramps — NE/NW for north catwalk, SE/SW for south catwalk
	_add_ramp("NorthCatRampE", Vector3(2.5, 0.2, 8), Vector3(13, 2.7, -41), _mat_metal, 0.55)
	_add_ramp("NorthCatRampW", Vector3(2.5, 0.2, 8), Vector3(-13, 2.7, -41), _mat_metal, 0.55)
	_add_ramp("SouthCatRampE", Vector3(2.5, 0.2, 8), Vector3(13, 2.7, -25), _mat_metal, -0.55)
	_add_ramp("SouthCatRampW", Vector3(2.5, 0.2, 8), Vector3(-13, 2.7, -25), _mat_metal, -0.55)
	_add_box("OvpRubble1", Vector3(3, 0.8, 1.5), Vector3(-8, 5.9, -45), _mat_rubble)
	_add_box("OvpRubble2", Vector3(2, 0.6, 1.5), Vector3(6, 5.8, -21), _mat_rubble)
	# Pyrotechnic charges on stage front rail (3 charges)
	for i: int in range(3):
		var px := -4.0 + i * 4.0
		_add_interactable("pyro_charge_%d" % (i + 1), "Pyrotechnic Charge %d" % (i + 1), "Press E: detonate charge", Vector3(px, 2.15, -40), Color(1.0, 0.8, 0.0))
	# Amp stacks (8 along east/west walls)
	var amp_pos: Array[Vector3] = [
		Vector3(14, 1.05, -24), Vector3(14, 1.05, -30),
		Vector3(14, 1.05, -36), Vector3(14, 1.05, -42),
		Vector3(-14, 1.05, -24), Vector3(-14, 1.05, -30),
		Vector3(-14, 1.05, -36), Vector3(-14, 1.05, -42),
	]
	for i: int in range(8):
		_add_interactable("amp_stack_%d" % (i + 1), "Amp Stack %d" % (i + 1), "Press E: destroy amp stack", amp_pos[i], Color(1.0, 0.4, 0.0))
	for rd: Array in [[-10, -25], [10, -35], [-6, -42], [8, -28], [-12, -38], [5, -22]]:
		_add_box("BowlRubble", Vector3(2.5, 1.2, 2.0), Vector3(rd[0], 0.6, rd[1]), _mat_rubble)
	_add_exit("ExtractionLift", "Press E: extraction lift — return to Faded Atrium", MALLHUB_SCENE, Vector3(0, 1.0, -48.1), Color(0.1, 0.8, 0.3))

	# --- Zone 6: Soul Battery Vault (below undercity, y -2..0) ---
	_add_box("VaultFloor", Vector3(12, 0.5, 6), Vector3(0, -2.25, -51), _mat_concrete)
	_add_box("VaultCeiling", Vector3(12, 0.25, 6), Vector3(0, -0.125, -51), _mat_building_dark)
	_add_box("VaultN", Vector3(12, 2.0, 0.35), Vector3(0, -1.25, -54), _mat_building_dark)
	_add_box("VaultS", Vector3(12, 2.0, 0.35), Vector3(0, -1.25, -48), _mat_building_dark)
	_add_box("VaultE", Vector3(0.35, 2.0, 6), Vector3(6, -1.25, -51), _mat_building_dark)
	_add_box("VaultW", Vector3(0.35, 2.0, 6), Vector3(-6, -1.25, -51), _mat_building_dark)
	var burn_area := Area3D.new()
	burn_area.name = "SoulBurnHazard"
	burn_area.add_to_group("soul_burn_hazard")
	burn_area.position = Vector3(0, -1.5, -51)
	add_child(burn_area)
	var burns := BoxShape3D.new()
	burns.size = Vector3(10.0, 1.5, 4.0)
	var burnc := CollisionShape3D.new()
	burnc.shape = burns
	burn_area.add_child(burnc)
	var bat_pos: Array[Vector3] = [
		Vector3(-4, -1.55, -50), Vector3(4, -1.55, -50),
		Vector3(-4, -1.55, -52), Vector3(4, -1.55, -52),
	]
	for i: int in range(4):
		_add_interactable("soul_battery_%d" % (i + 1), "Soul Battery %d" % (i + 1), "Press E: destroy soul battery", bat_pos[i], Color(0.0, 0.8, 0.2))

	# Enemies
	_spawn_enemies()
	_add_lights()


func _spawn_enemies() -> void:
	# Zone 1: plaza goons — patrol north-south along their side
	_add_goon(Vector3(-3, 0, -2), "keep_goon", [Vector3(-3, 0, -4), Vector3(-3, 0, 3)])
	_add_goon(Vector3(3, 0, -2), "keep_goon", [Vector3(3, 0, -4), Vector3(3, 0, 3)])
	# Zone 2: boulevard goons — patrol along the avenue
	_add_goon(Vector3(-2, 0, -6), "keep_goon", [Vector3(-2, 0, -3), Vector3(-2, 0, -10)])
	_add_goon(Vector3(2, 0, -12), "keep_goon", [Vector3(2, 0, -9), Vector3(2, 0, -16)])
	_add_enemy_splice(Vector3(0, 0, -16), "keep_goon", [Vector3(0, 0, -16), Vector3(-2, 0, -18)])
	# Zone 3: VIP Tower guards — patrol inside the ruins
	_add_goon(Vector3(9, 0, -8), "keep_vip_enemy", [Vector3(9, 0, -8), Vector3(12, 0, -12)])
	_add_goon(Vector3(12, 0, -11), "keep_vip_enemy", [Vector3(12, 0, -11), Vector3(8, 0, -9)])
	# Zone 5: concert enemies (stationary amp operators)
	for p: Vector3 in [Vector3(-12, 0, -26), Vector3(-12, 0, -30), Vector3(12, 0, -26), Vector3(12, 0, -30)]:
		_add_security(p, "keep_concert_enemy")
	# Zone 4: undercity cable fiends — patrol between corridor and back area
	_add_enemy_splice(Vector3(-12, 0, -8), "keep_backstage_enemy", [Vector3(-12, 0, -8), Vector3(-10, 0, -12)])
	_add_enemy_splice(Vector3(-8, 0, -12), "keep_backstage_enemy", [Vector3(-8, 0, -12), Vector3(-12, 0, -9)])
	# Zone 6: soul warden — small vault patrol
	_add_goon(Vector3(0, -1.55, -51), "keep_vault_enemy", [Vector3(-3, -1.55, -50), Vector3(3, -1.55, -52)])
	# Boss on stage (no patrol)
	var boss := BOSS_SCENE.instantiate()
	boss.name = "RockerFellar"
	boss.position = Vector3(0, 1.8, -44)
	boss.add_to_group("boss_rocker_fellar")
	add_child(boss)
	boss.alert()


func _add_box(node_name: String, size: Vector3, world_position: Vector3, material: Material, world_rotation := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	body.rotation = world_rotation
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.set_surface_override_material(0, material)
	body.add_child(vis)
	return body


func _add_ramp(node_name: String, size: Vector3, world_position: Vector3, material: Material, x_rot: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	body.rotation = Vector3(x_rot, 0, 0)
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.set_surface_override_material(0, material)
	body.add_child(vis)


func _add_interactable(id: String, disp_name: String, prompt: String, world_position: Vector3, color: Color) -> WardInteractable:
	var area := WardInteractable.new()
	area.name = disp_name.replace(" ", "")
	area.add_to_group("location_interactable")
	area.interactable_id = id
	area.display_name = disp_name
	area.prompt_text = prompt
	area.position = world_position
	add_child(area)
	var cs := SphereShape3D.new()
	cs.radius = 1.0
	var col := CollisionShape3D.new()
	col.shape = cs
	area.add_child(col)
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	var mat := _make_mat(color.darkened(0.78), color, 1.7, "", Vector3.ONE)
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.set_surface_override_material(0, mat)
	area.add_child(vis)
	return area


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
	var col := CollisionShape3D.new()
	col.shape = shape
	exit.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.4, 1.6, 0.12)
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.set_surface_override_material(0, _make_mat(color.darkened(0.8), color, 1.4, "", Vector3.ONE))
	exit.add_child(vis)


func _add_goon(pos: Vector3, group: String, patrol_points: Array[Vector3] = []) -> void:
	var goon := GOON_SCENE.instantiate()
	goon.name = "Goon"
	goon.position = pos
	goon.add_to_group(group)
	add_child(goon)
	if not patrol_points.is_empty():
		goon.set_patrol_points(patrol_points)


func _add_enemy_splice(pos: Vector3, group: String, patrol_points: Array[Vector3] = []) -> void:
	var sp := SPLICE_SCENE.instantiate()
	sp.name = "Splice"
	sp.position = pos
	sp.add_to_group(group)
	sp.item_dropped.connect(_on_splice_item_dropped)
	add_child(sp)
	if not patrol_points.is_empty():
		sp.set_patrol_points(patrol_points)


func _on_splice_item_dropped(item_name: String) -> void:
	hud.push_log("splice dropped: %s" % item_name.replace("_", " "))
	hud.show_system_message("FOUND " + item_name.to_upper().replace("_", " "))


func _add_security(pos: Vector3, group: String) -> void:
	var sn := SECURITY_NODE_SCENE.instantiate()
	sn.name = "AmpStackOperator"
	sn.position = pos
	sn.add_to_group(group)
	add_child(sn)


func _add_lights() -> void:
	for data: Array in [
		[Vector3(0, 3.0, 6), Color(0.6, 0.4, 0.2), 1.2, 8.0],
		[Vector3(-4, 3.0, 9), Color(0.6, 0.4, 0.2), 0.8, 8.0],
		[Vector3(0, 4.0, -5), Color(0.4, 0.1, 0.4), 1.0, 10.0],
		[Vector3(0, 4.0, -15), Color(0.4, 0.1, 0.4), 1.0, 10.0],
		[Vector3(-4, 3.0, -10), Color(0.6, 0.3, 0.1), 0.6, 10.0],
		[Vector3(10, 2.5, -10), Color(0.7, 0.5, 0.2), 1.0, 6.0],
		[Vector3(-10, 1.3, -10), Color(0.4, 0.5, 0.5), 0.8, 6.0],
		[Vector3(0, 6.0, -44), Color(0.6, 0.1, 0.1), 2.5, 12.0],
		[Vector3(-4, 6.0, -44), Color(0.4, 0.0, 0.5), 1.5, 12.0],
		[Vector3(4, 6.0, -44), Color(0.4, 0.0, 0.5), 1.5, 12.0],
		[Vector3(0, 1.0, -34), Color(0.4, 0.05, 0.05), 1.8, 8.0],
		[Vector3(-10, 5.0, -30), Color(0.5, 0.3, 0.1), 1.2, 10.0],
		[Vector3(10, 5.0, -30), Color(0.5, 0.3, 0.1), 1.2, 10.0],
		[Vector3(0, 5.5, -45), Color(0.2, 0.2, 0.5), 0.8, 10.0],
		[Vector3(0, 5.5, -21), Color(0.2, 0.2, 0.5), 0.8, 10.0],
		[Vector3(0, -0.5, -51), Color(0.0, 0.6, 0.2), 2.0, 5.0],
		[Vector3(-3, -0.5, -51), Color(0.0, 0.4, 0.15), 1.2, 5.0],
		[Vector3(3, -0.5, -51), Color(0.0, 0.4, 0.15), 1.2, 5.0],
	]:
		var light := OmniLight3D.new()
		light.position = data[0] as Vector3
		light.light_color = data[1] as Color
		light.light_energy = float(data[2])
		light.omni_range = float(data[3])
		add_child(light)


func _make_mat(albedo: Color, emission: Color, emission_energy: float, _texture_path: String, uv_scale: Vector3) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.86
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = uv_scale
	return mat


func _refresh_hud() -> void:
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.set_objective("Rocker Fellar Keep: descend into the dead city and end the General's concert.")


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
