extends Node
class_name PlayerHealth

signal health_changed(current_hp: float, max_hp: float)
signal damaged(amount: float, current_hp: float, max_hp: float)
signal died

@export var max_hp := 100.0

var current_hp := 0.0


func _ready() -> void:
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


func apply_damage(amount: float) -> void:
	var final_amount := amount
	if GameState.has_cybernetic("soul_baffle"):
		final_amount *= 0.75
	current_hp = maxf(current_hp - final_amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	damaged.emit(final_amount, current_hp, max_hp)
	if current_hp <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)
