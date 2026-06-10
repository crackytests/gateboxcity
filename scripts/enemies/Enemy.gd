extends CharacterBody3D
class_name Enemy

const HAZARD_CLOUD := preload("res://scripts/enemies/HazardCloud.gd")
const LOOT_PICKUP := preload("res://scripts/systems/LootPickup.gd")

signal body_part_destroyed(part_name: String)
signal attacked_player(message: String)
signal defeated
signal item_dropped(item_name: String)

@export var drop_item: String = ""
@export var loot_id: String = ""   # overrides the faction-derived loot table key; "" = derive from faction
@export var move_speed := 2.0
@export var attack_range := 2.2
@export var ranged_range := 8.0
@export var melee_damage := 8.0
@export var ranged_damage := 5.0
@export var attack_cooldown := 1.15
@export var player_path: NodePath
@export var persistence_id := ""
@export var detection_range := 14.0
@export var detection_delay := 0.6  # seconds of line-of-sight before aggro at baseline drift
@export var pacified_dialogue_name := "Gatebox Guard"
@export_multiline var pacified_dialogue_text := "Linda has marked you safe. Please proceed without running."

# ── Flavour / config (data-driven so subclasses stay thin) ──────────
@export var faction := ""
@export var melee_hit_message := "goon material scraped you for %d"
@export var enraged_hit_message := ""  # falls back to melee_hit_message when empty
@export var ranged_hit_message := "right-arm trash cannon hit for %d"

# ── Telegraph / interrupt ───────────────────────────────────────────
# A part carrying telegraph_ability gates a special attack. The enemy winds it
# up (rooting + easing that part's lock); destroying or staggering the part
# during the wind-up cancels the strike and staggers the enemy.
@export var windup_time := 0.75
@export var special_cooldown := 3.0
@export var lunge_range := 6.5
@export var lunge_damage_mult := 1.35
@export var lunge_speed := 13.0          # how hard a lunge/charge physically propels the attacker forward
@export var lunge_dash_time := 0.28      # how long that forward dash velocity holds
@export var can_leap := false            # can hop over obstacles when its path is blocked (e.g. Splice)
@export var leap_force := 7.5            # upward impulse for an obstacle leap
@export var stagger_on_interrupt := 0.7  # seconds of stun when a wind-up is broken

enum AIState { PATROL, COMBAT }
enum AttackState { READY, WINDUP }

@onready var parts_root: Node3D = %BodyParts
@onready var billboard = $Visuals/GreenlineBillboard

var player: Node3D
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var base_move_speed := 0.0
var attack_timer := 0.0
var stun_timer := 0.0
var attack_flash_timer := 0.0
var right_arm_destroyed := false
var is_defeated := false
var is_pacified := false
var _broken_parts: Dictionary = {}   # display_name -> true, for loot (forfeit broken parts)

var ai_state := AIState.PATROL
var patrol_points: Array[Vector3] = []
var _patrol_index := 0
var _patrol_dwell_timer := 0.0
var _patrol_dwell_time := 2.0
var _detection := 0.0  # 0..1; fills while in line of sight, modulated by drift/faction

# Enrage (e.g. Splice losing an arm): temporary melee multiplier with a timer.
var _enrage_active := false
var _enrage_timer := 0.0
var _enrage_mult := 1.0

# Telegraph wind-up state.
var attack_state: AttackState = AttackState.READY
var windup_timer := 0.0
var special_cooldown_timer := 0.0
var _telegraph_part: BodyPart = null

# Forward-dash on a lunge strike + obstacle-hop state.
var _dash_timer := 0.0
var _dash_velocity := Vector3.ZERO
var _dash_damage_pending := 0.0
var _dash_hit_done := false
var _leap_cooldown := 0.0

# Pack coordination.
@export var pack_id := ""               # members of the same pack share a frame-link
@export var is_pack_anchor := false     # while alive, the pack is buffed
@export var pack_buff_damage := 1.25    # melee multiplier while an anchor lives
@export var pack_alert_radius := 12.0   # aggro propagation distance
@export var separation_radius := 1.4    # personal space to avoid stacking
@export var separation_strength := 2.0
var _pack_buffed := false
var _command_active := true   # an anchor only buffs its pack while this holds (command rig intact)
var _behavior_mode := ""      # set by behavior_shift (e.g. "grab", "erratic") — AI flavour hint


func _ready() -> void:
	if GameState.is_enemy_defeated(_persistence_key()):
		is_defeated = true
		queue_free()
		return

	base_move_speed = move_speed
	add_to_group("enemy")
	if not player_path.is_empty():
		player = get_node_or_null(player_path)

	for child in parts_root.get_children():
		var part := child as BodyPart
		if part:
			part.destroyed.connect(_on_part_destroyed)
			part.damaged.connect(_on_part_damaged)

	# Resolve the pack buff once all siblings have spawned.
	call_deferred("_refresh_pack_buff")


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector3.ZERO
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)
	attack_flash_timer = maxf(attack_flash_timer - delta, 0.0)
	_leap_cooldown = maxf(_leap_cooldown - delta, 0.0)
	_tick_enrage(delta)

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_pacified or stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		move_and_slide()
		return

	match ai_state:
		AIState.PATROL:
			_process_patrol(delta)
		AIState.COMBAT:
			_process_combat(delta)

	# A lunge strike physically throws the attacker forward for a brief window, overriding
	# the normal chase velocity so the attack actually closes distance / crosses gaps.
	if _dash_timer > 0.0:
		if is_on_floor():
			_dash_timer -= delta
			velocity.x = _dash_velocity.x
			velocity.z = _dash_velocity.z
		else:
			_clear_dash_attack()

	var visual_scale := 1.0
	if attack_flash_timer > 0.0:
		visual_scale = 1.0 + attack_flash_timer * 0.45
	$Visuals.scale = Vector3.ONE * visual_scale

	move_and_slide()
	_resolve_dash_contact()


func _process_patrol(delta: float) -> void:
	if _has_line_of_sight():
		# Drift mis-ID: corporate units hesitate to flag a heavily-modded target
		# as hostile, while drift-hostile factions lock on faster.
		var stealth := 1.0
		if player.has_method("get_stealth_mult"):
			stealth = player.get_stealth_mult()
		_detection += delta * _detection_rate() * stealth
		if _detection >= 1.0:
			ai_state = AIState.COMBAT
			_on_aggro()
		return
	else:
		_detection = maxf(_detection - delta * 0.5, 0.0)

	if _patrol_dwell_timer > 0.0:
		_patrol_dwell_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		return
	if patrol_points.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		return
	var target := patrol_points[_patrol_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		_patrol_dwell_timer = _patrol_dwell_time
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		var direction := to_target.normalized()
		var patrol_speed := move_speed * 0.5
		velocity.x = direction.x * patrol_speed
		velocity.z = direction.z * patrol_speed
		var look_target := Vector3(target.x, global_position.y, target.z)
		if global_position.distance_squared_to(look_target) > 0.01:
			look_at(look_target, Vector3.UP)


func _process_combat(delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var look_target := Vector3(player.global_position.x, global_position.y, player.global_position.z)

	# Committing to a telegraphed attack roots the enemy in place.
	if attack_state == AttackState.WINDUP:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		if global_position.distance_squared_to(look_target) > 0.01:
			look_at(look_target, Vector3.UP)
		_update_attacks(delta, dist)
		return

	if dist > attack_range:
		var direction := to_player.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(look_target, Vector3.UP)
		# Hop over an obstacle when the path forward is blocked (Splice and other leapers).
		if can_leap and _leap_cooldown <= 0.0 and is_on_floor() and is_on_wall():
			velocity.y = leap_force
			_leap_cooldown = 1.4
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	# Separation steering so packmates flank instead of stacking on one tile.
	var sep := _separation_vector()
	velocity.x += sep.x
	velocity.z += sep.z
	_update_attacks(delta, dist)


# ── Attack selection: telegraphed special, else basic melee ─────────

func _update_attacks(delta: float, dist: float) -> void:
	special_cooldown_timer = maxf(special_cooldown_timer - delta, 0.0)

	if attack_state == AttackState.WINDUP:
		_process_windup(delta)
		return
	if stun_timer > 0.0:
		return

	var tp := _find_telegraph_part()
	if tp != null and special_cooldown_timer <= 0.0:
		if dist <= _telegraph_range(tp.telegraph_ability) and _can_start_telegraph(tp.telegraph_ability):
			_begin_windup(tp)
			return

	if attack_timer <= 0.0 and dist <= attack_range:
		_try_attack(dist)


func _find_telegraph_part() -> BodyPart:
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null and not part.is_destroyed and not part.telegraph_ability.is_empty():
			return part
	return null


func _telegraph_range(ability: String) -> float:
	match ability:
		"ranged_shot", "sonic_beam", "sedative":
			return ranged_range
		"lunge", "charge":
			return lunge_range
		_:
			return attack_range


func _can_start_telegraph(ability: String) -> bool:
	match ability:
		"ranged_shot", "sonic_beam", "sedative":
			return _has_attack_line_of_sight()
		"lunge", "charge":
			return _is_flat_on_ground() and _has_attack_line_of_sight()
		_:
			return true


func _is_flat_on_ground() -> bool:
	if not is_on_floor():
		return false
	if absf(velocity.y) > 0.05:
		return false
	return get_floor_normal().dot(Vector3.UP) >= 0.92


func _begin_windup(part: BodyPart) -> void:
	attack_state = AttackState.WINDUP
	windup_timer = windup_time
	_telegraph_part = part
	part.begin_windup(part.windup_lock_bonus)
	if billboard != null and billboard.has_method("set_windup"):
		billboard.set_windup(true)
	if faction == "Splice" or part.display_name == "Splice Arm":
		AudioDirector.play_sfx("splice_lunge_charge", -1.0)
	elif part.telegraph_ability == "ranged_shot":
		AudioDirector.play_sfx("goon_cannon_charge", -2.0)
	attacked_player.emit("%s charging — break it" % part.display_name)


func _process_windup(delta: float) -> void:
	# Interrupt if the owning part dies or the enemy is staggered mid-charge.
	if _telegraph_part == null or not is_instance_valid(_telegraph_part) \
			or _telegraph_part.is_destroyed or stun_timer > 0.0:
		_cancel_windup(true)
		return
	windup_timer = maxf(windup_timer - delta, 0.0)
	if windup_timer <= 0.0:
		_strike()


func _strike() -> void:
	var ability := _telegraph_part.telegraph_ability
	if player != null:
		var ph := player.find_child("PlayerHealth", true, false)
		var dist := player.global_position.distance_to(global_position)
		if ph != null:
			match ability:
				"ranged_shot", "sonic_beam":
					if dist <= ranged_range and _has_attack_line_of_sight():
						ph.apply_damage(ranged_damage, global_position)
						AudioDirector.play_sfx("goon_cannon_fire", -1.0)
						attacked_player.emit(ranged_hit_message % roundi(ranged_damage))
				"sedative":
					if dist <= ranged_range and _has_attack_line_of_sight():
						ph.apply_damage(ranged_damage * 0.5, global_position)
						GameState.apply_timed_effect("sedated", {
							"label": "Sedated",
							"active_duration": 4.0,
							"active_mods": {"speed_mult": 0.5},
							"log": "sedative spray — your limbs go heavy",
						})
				"lunge", "charge":
					# Physically throw the body forward toward the player, then resolve the hit.
					var lunge_dir := player.global_position - global_position
					lunge_dir.y = 0.0
					if lunge_dir.length() > 0.01:
						_dash_velocity = lunge_dir.normalized() * lunge_speed
						_dash_timer = lunge_dash_time
						_dash_damage_pending = _outgoing_melee() * lunge_damage_mult
						_dash_hit_done = false
					elif dist <= attack_range + 0.6:
						var dmg := _outgoing_melee() * lunge_damage_mult
						ph.apply_damage(dmg, global_position)
						if faction == "Splice" or ability == "lunge":
							AudioDirector.play_sfx("splice_lunge_hit", 0.0)
						attacked_player.emit(melee_hit_message % roundi(dmg))
				_:
					if dist <= attack_range:
						var basic := _outgoing_melee()
						ph.apply_damage(basic, global_position)
						attacked_player.emit(melee_hit_message % roundi(basic))
	attack_flash_timer = 0.22
	_end_windup()
	special_cooldown_timer = special_cooldown


func _cancel_windup(staggered: bool) -> void:
	_end_windup()
	_clear_dash_attack()
	if staggered:
		stun_timer = maxf(stun_timer, stagger_on_interrupt)
	# Whiffed wind-ups recover a little faster than a completed strike.
	special_cooldown_timer = special_cooldown * 0.5


func _end_windup() -> void:
	if _telegraph_part != null and is_instance_valid(_telegraph_part):
		_telegraph_part.end_windup()
	_telegraph_part = null
	attack_state = AttackState.READY
	windup_timer = 0.0
	if billboard != null and billboard.has_method("set_windup"):
		billboard.set_windup(false)


func _resolve_dash_contact() -> void:
	if _dash_damage_pending <= 0.0 or _dash_hit_done or player == null:
		if _dash_timer <= 0.0 and _dash_damage_pending > 0.0:
			_clear_dash_attack()
		return
	var dist := player.global_position.distance_to(global_position)
	if dist > attack_range + 0.75:
		if _dash_timer <= 0.0:
			_clear_dash_attack()
		return
	var ph := player.find_child("PlayerHealth", true, false)
	if ph == null:
		_clear_dash_attack()
		return
	ph.apply_damage(_dash_damage_pending, global_position)
	if faction == "Splice":
		AudioDirector.play_sfx("splice_lunge_hit", 0.0)
	attacked_player.emit(melee_hit_message % roundi(_dash_damage_pending))
	_dash_hit_done = true
	_clear_dash_attack()


func _clear_dash_attack() -> void:
	_dash_timer = 0.0
	_dash_velocity = Vector3.ZERO
	_dash_damage_pending = 0.0
	_dash_hit_done = false


func _on_part_damaged(part: BodyPart, _amount: float, remaining_hp: float) -> void:
	# Getting hit makes an unaware enemy hostile immediately — no line-of-sight needed — and
	# wakes nearby allies through the normal aggro propagation.
	if ai_state != AIState.COMBAT and not is_defeated:
		ai_state = AIState.COMBAT
		_detection = 1.0
		_on_aggro()
	if billboard != null and billboard.has_method("flash_damage"):
		billboard.flash_damage()
	if part.display_name == "Head" and remaining_hp <= part.max_hp * 0.5:
		stun_timer = maxf(stun_timer, 0.35)


func _on_part_destroyed(part: BodyPart) -> void:
	part.monitorable = false
	part.visible = false
	_broken_parts[part.display_name] = true   # breaking a part forfeits its implant drop
	body_part_destroyed.emit(part.display_name)

	_show_part_break_effect(part)
	if billboard != null and billboard.has_method("show_part_broken"):
		billboard.show_part_broken(part.display_name)
	AudioDirector.play_body_part_break(part.display_name)

	_apply_part_destroy_effect(part)


# Data-driven consequence dispatch. Effects + parameters come from the part's
# BodyPartData (or inline BodyPart fields), so new enemies are authored as data.
func _apply_part_destroy_effect(part: BodyPart) -> void:
	var payload: Dictionary = part.effect_payload if typeof(part.effect_payload) == TYPE_DICTIONARY else {}
	match part.on_destroy_effect:
		"stun":
			stun_timer = maxf(stun_timer, part.effect_strength)
		"slow":
			var slow_mult := part.effect_strength if part.effect_strength > 0.0 else 0.5
			var floor_frac := float(payload.get("floor_frac", 0.2))
			move_speed = maxf(move_speed * slow_mult, base_move_speed * floor_frac)
		"disable_ranged":
			right_arm_destroyed = true
			ranged_damage = 0.0
		"reduce_melee_mult":
			if part.effect_strength > 0.0:
				melee_damage *= part.effect_strength
			if bool(payload.get("disable_ranged", false)):
				right_arm_destroyed = true
				ranged_damage = 0.0
		"reduce_melee_flat":
			melee_damage = maxf(melee_damage - part.effect_strength, float(payload.get("floor", 2.0)))
		"enrage":
			_start_enrage(part, payload)
		"detonate":
			_trigger_detonate(part)
		"rupture_cloud":
			_trigger_rupture_cloud(part)
		"free_soul":
			_trigger_free_soul(part)
		"reduce_detection":
			# Sensor crown: blind the unit and kill its alarm/long-range sense.
			detection_range *= (part.effect_strength if part.effect_strength > 0.0 else 0.4)
			var dmsg := str(payload.get("message", ""))
			if not dmsg.is_empty():
				attacked_player.emit(dmsg)
		"behavior_shift":
			_behavior_mode = str(payload.get("mode", ""))
			if payload.has("speed_mult"):
				move_speed *= float(payload.get("speed_mult", 1.0))
			var bmsg := str(payload.get("message", ""))
			if not bmsg.is_empty():
				attacked_player.emit(bmsg)
		"drop_command":
			# Command rig: while intact the anchor buffs its pack. Down it and
			# the controlled grafts go feral (lose the buff).
			_command_active = false
			_notify_pack_changed()
			attacked_player.emit(str(payload.get("message", "command rig down — the grafts go uncontrolled")))
		"grant_loot":
			if payload.has("item"):
				GameState.add_item(str(payload["item"]))
			if payload.has("flag"):
				GameState.set_world_flag(str(payload["flag"]), true)
			var lmsg := str(payload.get("message", ""))
			if not lmsg.is_empty():
				GameState.effect_notice.emit(lmsg)
		"defeat":
			_defeat()
		_:
			pass


func _start_enrage(part: BodyPart, payload: Dictionary) -> void:
	if _enrage_active:
		return
	var mult := part.effect_strength if part.effect_strength > 0.0 else 1.8
	melee_damage *= mult
	_enrage_mult = mult
	_enrage_active = true
	_enrage_timer = float(payload.get("duration", 3.5))
	var msg := str(payload.get("trigger_message", ""))
	if not msg.is_empty():
		attacked_player.emit(msg)


func _tick_enrage(delta: float) -> void:
	if not _enrage_active:
		return
	_enrage_timer = maxf(_enrage_timer - delta, 0.0)
	if _enrage_timer <= 0.0:
		melee_damage /= _enrage_mult
		_enrage_mult = 1.0
		_enrage_active = false


# ── Volatile / moral part effects (Step 3) ──────────────────────────

# A reactor/explosive part: AoE damage at its position. Lethal up close,
# survivable at range — so where you stand when you break it matters.
func _trigger_detonate(part: BodyPart) -> void:
	var dmg := part.effect_strength if part.effect_strength > 0.0 else 15.0
	var radius := part.effect_radius if part.effect_radius > 0.0 else 3.0
	var pos := part.global_position
	if player != null:
		var d := player.global_position.distance_to(pos)
		if d <= radius:
			var ph = player.find_child("PlayerHealth", true, false)
			if ph != null:
				var falloff := clampf(1.0 - d / radius, 0.15, 1.0)
				ph.apply_damage(dmg * falloff, pos)
				attacked_player.emit("reactor blast — %d" % roundi(dmg * falloff))
	_spawn_burst_vfx(pos, radius, Color(1.0, 0.55, 0.1))


# A rupturing sac: leaves a lingering damage cloud.
func _trigger_rupture_cloud(part: BodyPart) -> void:
	var payload: Dictionary = part.effect_payload if typeof(part.effect_payload) == TYPE_DICTIONARY else {}
	var dps := part.effect_strength if part.effect_strength > 0.0 else 5.0
	var radius := part.effect_radius if part.effect_radius > 0.0 else 3.0
	var duration := float(payload.get("duration", 6.0))
	_spawn_hazard_cloud(part.global_position, radius, dps, duration)
	attacked_player.emit("%s ruptures — toxic cloud spreads" % part.display_name)


# A soul battery/resonator: freeing the trapped soul corrupts your anchor
# (soul-rot) and can shift faction standing — a moral target, not a free win.
func _trigger_free_soul(part: BodyPart) -> void:
	var payload: Dictionary = part.effect_payload if typeof(part.effect_payload) == TYPE_DICTIONARY else {}
	var sr := int(payload.get("soul_rot", 8))
	if sr != 0 and GameState.has_method("add_soul_rot"):
		GameState.add_soul_rot(sr)
	var fac := str(payload.get("rep_faction", ""))
	var amt := int(payload.get("rep_amount", 0))
	if not fac.is_empty() and amt != 0 and GameState.reputation.has(fac):
		GameState.add_reputation(fac, amt)
	var msg := str(payload.get("message", "A trapped soul tears loose of the frame and is gone."))
	GameState.effect_notice.emit(msg)
	_spawn_burst_vfx(part.global_position, maxf(part.effect_radius, 2.0), Color(0.8, 0.4, 1.0))


func _spawn_hazard_cloud(pos: Vector3, radius: float, dps: float, duration: float) -> void:
	var cloud := HAZARD_CLOUD.new()
	cloud.setup(radius, dps, duration)
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(cloud)
	cloud.global_position = pos


func _spawn_burst_vfx(pos: Vector3, radius: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.65)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mesh.set_surface_override_material(0, mat)
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(mesh)
	mesh.global_position = pos
	var target_scale := maxf(radius / 0.3, 1.0)
	var t := mesh.create_tween()
	t.set_parallel(true)
	t.tween_property(mesh, "scale", Vector3.ONE * target_scale, 0.38)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.42)
	t.set_parallel(false)
	t.tween_callback(mesh.queue_free)


func _try_attack(distance_to_player: float) -> void:
	if is_pacified or attack_timer > 0.0:
		return

	var player_health := player.find_child("PlayerHealth", true, false)
	if player_health == null:
		return

	# Basic close-range melee. Ranged/lunge specials run through the telegraph
	# system (_update_attacks) so they can be read and interrupted.
	if distance_to_player <= attack_range:
		var dmg := _outgoing_melee()
		player_health.apply_damage(dmg, global_position)
		attack_flash_timer = 0.22
		var msg := enraged_hit_message if (_enrage_active and not enraged_hit_message.is_empty()) else melee_hit_message
		attacked_player.emit(msg % roundi(dmg))
		attack_timer = attack_cooldown


func _defeat() -> void:
	if is_defeated:
		return

	is_defeated = true
	GameState.mark_enemy_defeated(_persistence_key())
	collision_layer = 0
	collision_mask = 0
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null:
			part.monitorable = false
			part.monitoring = false
	if billboard != null and billboard.has_method("show_defeated"):
		billboard.show_defeated()
	if faction == "Splice":
		AudioDirector.play_sfx("splice_death", 0.0)
	_drop_loot()
	if is_pack_anchor:
		attacked_player.emit("pack anchor down — the frame-link drops and the pack softens")
	_notify_pack_changed()
	defeated.emit()


func _persistence_key() -> String:
	if not persistence_id.is_empty():
		return persistence_id
	var scene_path := ""
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	return "%s:%s" % [scene_path, str(get_path())]


# ── Loot drops (refactor §2) ────────────────────────────────────────

func _drop_loot() -> void:
	# Implants drop only for parts left intact; scrap/specials roll independently.
	var intact: Array = []
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null and not _broken_parts.has(part.display_name) and not part.is_destroyed:
			intact.append(part.display_name)
	for item in GameState.roll_loot(_resolve_loot_id(), intact):
		_spawn_loot_pickup(str(item))
	# A scripted guaranteed drop (e.g. a quest item) still works if set.
	if not drop_item.is_empty():
		_spawn_loot_pickup(drop_item)
		item_dropped.emit(drop_item)


func _resolve_loot_id() -> String:
	if not loot_id.is_empty():
		return loot_id
	match faction:
		"Splice": return "splice"
		"Gatebox", "Gatebox Corporation", "Preservation", "Preservation Directive": return "gatebox"
		"Big Gates", "Big Gates Foundation": return "big_gates"
		_: return ""


func _spawn_loot_pickup(item_name: String) -> void:
	if item_name.is_empty():
		return
	var pickup := Area3D.new()
	pickup.set_script(LOOT_PICKUP)
	pickup.item_name = item_name
	pickup.auto_pickup = true
	pickup.collision_layer = 0
	pickup.collision_mask = 1   # detect the player body
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	pickup.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.26, 0.26)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 0.3, 0.0)
	var color := _loot_color(item_name)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.4)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh_inst.set_surface_override_material(0, mat)
	pickup.add_child(mesh_inst)
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(pickup)
	pickup.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.4, randf_range(-0.6, 0.6))
	pickup.picked_up.connect(_on_loot_dropped_picked_up)


func _on_loot_dropped_picked_up(item_name: String) -> void:
	GameState.add_item(item_name)
	GameState.effect_notice.emit("salvaged: " + item_name)


func _loot_color(item_name: String) -> Color:
	if item_name == "neural_splice":
		return Color(0.7, 0.3, 1.0)        # purple — quest splice
	if GameState.is_implant_item(item_name):
		return Color(0.2, 1.0, 0.6)        # green — installable cyberware
	return Color(0.85, 0.7, 0.3)           # amber — scrap


func pacify(dialogue_text := "") -> void:
	is_pacified = true
	move_speed = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	if not dialogue_text.is_empty():
		pacified_dialogue_text = dialogue_text


func is_talkable() -> bool:
	return is_pacified and not is_defeated


func face_player_now() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var look_target := player.global_position
	look_target.y = global_position.y
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)


func get_pacified_dialogue() -> Dictionary:
	return {
		"name": pacified_dialogue_name,
		"text": pacified_dialogue_text
	}


func _show_part_break_effect(part: BodyPart) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	marker.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.05, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.02, 0.12, 1.0)
	material.emission_energy_multiplier = 2.3
	marker.set_surface_override_material(0, material)

	$Visuals.add_child(marker)
	marker.global_position = part.global_position
	marker.name = part.display_name.replace(" ", "") + "BreakMarker"


func _has_line_of_sight() -> bool:
	if player == null:
		return false
	# Crouching lowers the point we sight-check, so the player can tuck below cover.
	var player_eye := 0.8
	if player.has_method("get_sight_height"):
		player_eye = player.get_sight_height()
	var from := global_position + Vector3.UP * 0.8
	var to := player.global_position + Vector3.UP * player_eye
	var dist := from.distance_to(to)
	# Whisper Filter dampens the player's noise signature, shrinking the range
	# at which enemies pick them up.
	var effective_range := detection_range
	if GameState.has_cybernetic("whisper_filter"):
		effective_range *= 0.55
	# Crouch/stealth shrinks the pickup range further.
	if player.has_method("get_stealth_mult"):
		effective_range *= player.get_stealth_mult()
	if dist > effective_range:
		return false
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_dist := from.distance_to(result.position)
	return hit_dist >= dist - 0.5


func _has_attack_line_of_sight() -> bool:
	if player == null:
		return false
	var player_eye := 0.8
	if player.has_method("get_sight_height"):
		player_eye = player.get_sight_height()
	var from := global_position + Vector3.UP * 0.8
	var to := player.global_position + Vector3.UP * player_eye
	var dist := from.distance_to(to)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_dist := from.distance_to(result.position)
	return hit_dist >= dist - 0.5


func set_patrol_points(points: Array[Vector3]) -> void:
	patrol_points = points
	_patrol_index = 0


func alert() -> void:
	ai_state = AIState.COMBAT
	_detection = 1.0


# Player-facing awareness read by the HUD stealth indicator.
# 0 = oblivious, 1 = fully aggroed; partial values mean "investigating".
func get_awareness() -> float:
	if is_defeated or is_pacified:
		return 0.0
	if ai_state == AIState.COMBAT:
		return 1.0
	return _detection


# ── Drift mis-ID ────────────────────────────────────────────────────

func _detection_rate() -> float:
	var base := 1.0 / maxf(detection_delay, 0.05)
	var d := 0
	if GameState.has_method("get_drift"):
		d = GameState.get_drift()
	var t := clampf(float(d) / 100.0, 0.0, 1.0)
	if _is_corporate_faction():
		# Reads as "one of them" — much slower to flag as hostile.
		return base * lerpf(1.0, 0.15, t)
	if _is_drift_hostile_faction():
		# Smells the modification — locks on faster.
		return base * lerpf(1.0, 2.0, t)
	return base


func _is_corporate_faction() -> bool:
	return faction in ["Gatebox", "Gatebox Corporation", "Preservation", "Preservation Directive"]


func _is_drift_hostile_faction() -> bool:
	return faction in ["Splice", "street", "Big Gates", "Big Gates Foundation"]


# ── Hacking (alternative to destruction for hackable parts) ─────────

func can_be_hacked() -> bool:
	if is_defeated or is_pacified:
		return false
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part != null and part.hackable and not part.is_destroyed and not part.hacked:
			return true
	return false


# Applied by the HUD when the player completes a hack on a hackable part.
func apply_hack_effect(part: BodyPart) -> void:
	if part == null:
		return
	var payload: Dictionary = part.effect_payload if typeof(part.effect_payload) == TYPE_DICTIONARY else {}
	var dur := float(payload.get("hack_stun", 5.0))
	stun_timer = maxf(stun_timer, dur)
	if attack_state == AttackState.WINDUP:
		_cancel_windup(false)
	if billboard != null and billboard.has_method("flash_damage"):
		billboard.flash_damage()
	attacked_player.emit("%s hacked — system locked for %ds" % [part.display_name, roundi(dur)])


# ── Pack coordination ───────────────────────────────────────────────

# Melee damage actually dealt, folding in the pack-anchor buff. Kept separate
# from melee_damage so it composes with the enrage multiplier.
func _outgoing_melee() -> float:
	return melee_damage * (pack_buff_damage if _pack_buffed else 1.0)


func _on_aggro() -> void:
	_refresh_pack_buff()
	if faction == "Splice":
		AudioDirector.play_sfx("splice_aggro", -1.0)
	# One-hop alert: wake nearby pack/faction allies that are still on patrol.
	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Enemy
		if e == null or e == self or e.is_defeated or e.ai_state == AIState.COMBAT:
			continue
		if not _is_ally(e):
			continue
		if global_position.distance_to(e.global_position) <= pack_alert_radius:
			e.ai_state = AIState.COMBAT
			e._detection = 1.0
			e._refresh_pack_buff()


func _is_ally(e: Enemy) -> bool:
	if not pack_id.is_empty() and e.pack_id == pack_id:
		return true
	return not faction.is_empty() and e.faction == faction


func _refresh_pack_buff() -> void:
	_pack_buffed = _has_living_anchor()


func _has_living_anchor() -> bool:
	if pack_id.is_empty():
		return false
	if is_pack_anchor and not is_defeated and _command_active:
		return true
	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Enemy
		if e != null and e.pack_id == pack_id and e.is_pack_anchor and not e.is_defeated and e._command_active:
			return true
	return false


# Called when a pack member dies so survivors recompute their buff.
func _notify_pack_changed() -> void:
	if pack_id.is_empty():
		return
	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Enemy
		if e != null and e != self and e.pack_id == pack_id:
			e._refresh_pack_buff()


# Push away from nearby allies so a pack surrounds the player instead of
# collapsing onto one point. Returns a velocity contribution (X/Z).
func _separation_vector() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemy"):
		var other := node as Node3D
		if other == null or other == self:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var d := away.length()
		if d > 0.01 and d < separation_radius:
			push += away.normalized() * ((separation_radius - d) / separation_radius)
	return push * separation_strength
