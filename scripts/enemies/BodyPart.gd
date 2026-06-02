extends Area3D
class_name BodyPart

signal damaged(part: BodyPart, amount: float, remaining_hp: float)
signal destroyed(part: BodyPart)

@export var body_part_data: Resource
@export var display_name := "Body Part"
@export var max_hp := 25.0
@export var targeting_penalty := 0.0
@export var lock_difficulty_multiplier := 1.0
@export var armor_value := 0.0

# Data-driven destruction behaviour (see BodyPartData). These can be set
# inline on the node (RainMutant) or copied from a body_part_data resource.
@export var part_role := "limb"
@export var on_destroy_effect := ""
@export var effect_strength := 0.0
@export var effect_radius := 0.0
@export var effect_payload: Dictionary = {}
@export var telegraph_ability := ""
@export var windup_lock_bonus := 0.0
@export var volatile := false
@export var hackable := false
@export var weak_point := false

var current_hp := 0.0
var is_destroyed := false
var hacked := false

# Telegraph wind-up: while true, this part owns an attack that's charging and
# its lock is temporarily eased so the player can lock + shoot it to cancel.
var in_windup := false
var _stored_lock := 0.0


func begin_windup(lock_bonus: float) -> void:
	if in_windup:
		return
	in_windup = true
	_stored_lock = lock_difficulty_multiplier
	lock_difficulty_multiplier = maxf(0.3, lock_difficulty_multiplier - lock_bonus)


func end_windup() -> void:
	if not in_windup:
		return
	in_windup = false
	lock_difficulty_multiplier = _stored_lock


func _ready() -> void:
	add_to_group("body_parts")
	_apply_body_part_data()
	current_hp = max_hp
	collision_layer = 2
	collision_mask = 0


func apply_damage(amount: float, _damage_type := "kinetic") -> float:
	if is_destroyed:
		return 0.0

	var final_damage := maxf(amount - armor_value, 1.0)
	current_hp = maxf(current_hp - final_damage, 0.0)
	damaged.emit(self, final_damage, current_hp)

	if current_hp <= 0.0:
		is_destroyed = true
		destroyed.emit(self)

	return final_damage


func get_hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return current_hp / max_hp


func _apply_body_part_data() -> void:
	if body_part_data == null:
		return

	display_name = body_part_data.get("display_name")
	max_hp = body_part_data.get("max_hp")
	targeting_penalty = body_part_data.get("targeting_penalty")
	lock_difficulty_multiplier = body_part_data.get("lock_difficulty_multiplier")
	armor_value = body_part_data.get("armor_value")

	# Behaviour fields (resources authored before these existed return null/defaults).
	part_role = str(body_part_data.get("part_role") if body_part_data.get("part_role") != null else "limb")
	on_destroy_effect = str(body_part_data.get("on_destroy_effect") if body_part_data.get("on_destroy_effect") != null else "")
	effect_strength = float(body_part_data.get("effect_strength") if body_part_data.get("effect_strength") != null else 0.0)
	effect_radius = float(body_part_data.get("effect_radius") if body_part_data.get("effect_radius") != null else 0.0)
	var payload = body_part_data.get("effect_payload")
	effect_payload = payload if typeof(payload) == TYPE_DICTIONARY else {}
	telegraph_ability = str(body_part_data.get("telegraph_ability") if body_part_data.get("telegraph_ability") != null else "")
	windup_lock_bonus = float(body_part_data.get("windup_lock_bonus") if body_part_data.get("windup_lock_bonus") != null else 0.0)
	volatile = bool(body_part_data.get("volatile") if body_part_data.get("volatile") != null else false)
	hackable = bool(body_part_data.get("hackable") if body_part_data.get("hackable") != null else false)
	weak_point = bool(body_part_data.get("weak_point") if body_part_data.get("weak_point") != null else false)
