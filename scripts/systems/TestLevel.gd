extends Node3D

@onready var player: PlayerController = $Player
@onready var hud: HUDController = $HUD
@onready var targeting: PlayerTargeting = $Player/PlayerTargeting
@onready var player_health = $Player/PlayerHealth
@onready var weapon: Weapon = $Player/CameraPivot/Camera3D/WeaponMount/ScrapPistol
@onready var enemy: Enemy = $GoonMaterial
@onready var reinforcement: Enemy = $GateboxReinforcement
@onready var inventory = $Systems/InventorySystem
@onready var quest = $Systems/QuestSystem
@onready var factions = $Systems/FactionSystem

var focused_npc
var focused_exit
var focused_coolant


func _ready() -> void:
	targeting.targeting_changed.connect(hud.update_targeting)
	weapon.targeting = targeting
	weapon.ammo_changed.connect(hud.set_ammo)
	weapon.fired.connect(hud.push_log)
	player_health.health_changed.connect(hud.set_player_health)
	player_health.damaged.connect(hud.show_damage_event)
	player_health.died.connect(_on_player_died)
	WorldDirector.world_state_changed.connect(hud.set_world_state)
	WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)
	_connect_enemy(enemy)
	if GameState.get_world_flag("gatebox_node_stabilized"):
		_connect_enemy(reinforcement)
		hud.push_log("world event: Gatebox node spawned reinforcement")
	else:
		reinforcement.queue_free()
	inventory.inventory_changed.connect(hud.set_inventory_summary)
	quest.objective_changed.connect(hud.set_objective)
	quest.quest_completed.connect(_on_quest_completed)
	factions.reputation_changed.connect(hud.set_faction_summary)
	for pickup in get_tree().get_nodes_in_group("loot"):
		pickup.picked_up.connect(_on_loot_picked_up)
		if not pickup.auto_pickup:
			pickup.body_entered.connect(_on_coolant_focus_entered.bind(pickup))
			pickup.body_exited.connect(_on_coolant_focus_exited.bind(pickup))
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.focus_changed.connect(_on_npc_focus_changed)
	for mission_exit in get_tree().get_nodes_in_group("mission_exit"):
		mission_exit.focus_changed.connect(_on_exit_focus_changed)
	hud.update_targeting(null, 0.0, 0.0)
	hud.set_ammo(weapon.current_ammo, weapon.reserve_ammo)
	hud.set_player_health(player_health.current_hp, player_health.max_hp)
	hud.set_objective(quest.get_objective_text())
	hud.set_inventory_summary(GameState.get_inventory_summary())
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
	hud.set_world_state(WorldDirector.get_hud_summary())
	hud.push_log("connection established: sub-sub-basement test cell")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or _is_manual_interact_key(event):
		_handle_interact()
	elif event.is_action_pressed("save_game") or _is_save_key(event):
		if GameState.save_game():
			hud.show_system_message("GAME SAVED")
		else:
			hud.show_system_message("SAVE FAILED")
	elif event.is_action_pressed("load_game") or _is_load_key(event):
		if GameState.load_game():
			WorldDirector.restore_from_game_state()
			WorldDirector.set_region(WorldDirector.REGION_SUB_BASEMENT)
			hud.set_inventory_summary(GameState.get_inventory_summary())
			hud.set_faction_summary(GameState.get_faction_summary())
			hud.set_cybernetic_summary(GameState.get_cybernetic_summary())
			hud.set_world_state(WorldDirector.get_hud_summary())
			hud.show_system_message("GAME LOADED")
		else:
			hud.show_system_message("NO SAVE FOUND")


func _on_loot_picked_up(item_name: String) -> void:
	inventory.add_item(item_name)
	GameState.add_item(item_name)
	if item_name == "Broken Gatebox Display":
		quest.mark_display_recovered()
	hud.push_log("scavenged " + item_name)


func _connect_enemy(enemy_node: Enemy) -> void:
	enemy_node.body_part_destroyed.connect(_on_enemy_part_destroyed.bind(enemy_node))
	enemy_node.attacked_player.connect(hud.push_log)
	enemy_node.defeated.connect(_on_enemy_defeated.bind(enemy_node))


func _on_enemy_part_destroyed(part_name: String, enemy_node: Enemy) -> void:
	if part_name == "Right Arm":
		quest.mark_right_arm_disabled()
	var enemy_label := "reinforcement" if enemy_node == reinforcement else "goon"
	hud.push_log(enemy_label + " " + part_name.to_lower() + " destroyed")


func _on_enemy_defeated(enemy_node: Enemy) -> void:
	quest.mark_goon_defeated()
	_spawn_enemy_loot(enemy_node)
	var enemy_label := "reinforcement" if enemy_node == reinforcement else "goon material"
	hud.push_log(enemy_label + " collapsed")


func _on_player_died() -> void:
	hud.push_log("body integrity failed")


func _on_npc_focus_changed(npc, has_focus: bool) -> void:
	focused_npc = npc if has_focus else null
	_update_prompt()


func _on_exit_focus_changed(mission_exit, has_focus: bool) -> void:
	focused_exit = mission_exit if has_focus else null
	_update_prompt()


func _handle_interact() -> void:
	if focused_npc != null:
		var line: Dictionary = focused_npc.interact()
		hud.show_dialogue(line["name"], line["text"])
		quest.start_wake_up_call()
		hud.push_log("job accepted: wake-up call")
		return

	if focused_exit != null:
		if quest.can_extract():
			quest.complete_active_quest()
		else:
			hud.push_log("extraction gate rejects incomplete job")
		return

	if focused_coolant != null:
		_route_soul_coolant()


func _update_prompt() -> void:
	if focused_npc != null:
		hud.set_prompt(focused_npc.prompt_text)
	elif focused_exit != null:
		hud.set_prompt(focused_exit.prompt_text)
	elif focused_coolant != null:
		hud.set_prompt("Press E: route soul coolant to Gatebox node")
	else:
		hud.set_prompt("")


func _on_quest_completed(_quest_id: String) -> void:
	inventory.add_item("Mall Arcade Token")
	GameState.add_item("Mall Arcade Token")
	factions.add_reputation("System X", 1)
	factions.add_reputation("Gatebox Corporation", -1)
	GameState.add_reputation("System X", 1)
	GameState.add_reputation("Gatebox Corporation", -1)
	GameState.mark_quest_completed(_quest_id)
	GameState.last_mission_result = "Wake-Up Call complete"
	if quest.soul_coolant_routed:
		GameState.set_world_flag("gatebox_node_stabilized", true)
		GameState.last_mission_result = "Wake-Up Call complete: node stabilized"
	hud.show_dialogue("System X", "Beautiful. The display still has dream residue on it. Atrium door is open, which is the building's way of clapping with hinges.")
	hud.push_log("wake-up call complete")
	call_deferred("_return_to_hub")


func _is_manual_interact_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_E


func _is_save_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5


func _is_load_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F6


func _return_to_hub() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/levels/MallHub.tscn")


func _on_coolant_focus_entered(body: Node3D, pickup) -> void:
	if body.is_in_group("player"):
		focused_coolant = pickup
		_update_prompt()


func _on_coolant_focus_exited(body: Node3D, pickup) -> void:
	if body.is_in_group("player") and focused_coolant == pickup:
		focused_coolant = null
		_update_prompt()


func _route_soul_coolant() -> void:
	quest.mark_soul_coolant_routed()
	GameState.set_world_flag("gatebox_node_stabilized", true)
	GameState.add_reputation("Gatebox Corporation", 1)
	GameState.add_reputation("System X", -1)
	hud.set_faction_summary(GameState.get_faction_summary())
	hud.show_dialogue("Linda", "Thank you for choosing stabilization. Your care has been noted, indexed, and placed somewhere tender.")
	hud.push_log("soul coolant routed to Gatebox node")
	focused_coolant.queue_free()
	focused_coolant = null
	_update_prompt()


func _spawn_enemy_loot(enemy_node: Enemy) -> void:
	var drop_position := enemy_node.global_position + Vector3(0.0, 0.35, 0.0)
	var pickup := Area3D.new()
	pickup.name = "BoneLatticeBracket"
	pickup.add_to_group("loot")
	pickup.set_script(load("res://scripts/systems/LootPickup.gd"))
	pickup.item_name = "Big Gates Bone-Lattice Bracket"

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.4, 0.7)
	shape.shape = box
	pickup.add_child(shape)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.25, 0.7)
	mesh_instance.mesh = mesh
	pickup.add_child(mesh_instance)

	add_child(pickup)
	pickup.global_position = drop_position
	pickup.picked_up.connect(_on_loot_picked_up)
