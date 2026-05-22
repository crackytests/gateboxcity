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

var current_hp := 0.0
var is_destroyed := false


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
