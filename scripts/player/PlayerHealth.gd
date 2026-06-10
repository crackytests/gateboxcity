extends Node
class_name PlayerHealth

signal health_changed(current_hp: float, max_hp: float)
# source_position: world-space origin of the hit (Vector3) for the directional indicator, or
# null for abstract/environmental damage with no single direction.
signal damaged(amount: float, current_hp: float, max_hp: float, source_position)
signal died

@export var max_hp := 100.0
## Bio-Reactor Mesh: HP regenerated per second once out of combat.
@export var bioreactor_regen_per_second := 4.0
## Seconds after taking damage before the Bio-Reactor Mesh resumes regen.
@export var bioreactor_combat_cooldown := 5.0

var current_hp := 0.0
var _regen_lockout := 0.0


func _ready() -> void:
	# Endoskeletal Brace raises the body's integrity ceiling.
	if GameState.has_cybernetic("endoskeletal_brace"):
		max_hp += 20.0
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)
	if not GameState.player_heal_requested.is_connected(_on_heal_requested):
		GameState.player_heal_requested.connect(_on_heal_requested)
	if not GameState.player_damage_requested.is_connected(apply_damage):
		GameState.player_damage_requested.connect(apply_damage)


func _process(delta: float) -> void:
	_regen_lockout = maxf(_regen_lockout - delta, 0.0)
	# Bio-Reactor Mesh slowly knits integrity back together out of combat.
	if not GameState.has_cybernetic("bioreactor_mesh"):
		return
	if _regen_lockout > 0.0 or current_hp <= 0.0 or current_hp >= max_hp:
		return
	current_hp = minf(current_hp + bioreactor_regen_per_second * delta, max_hp)
	health_changed.emit(current_hp, max_hp)


func apply_damage(amount: float, source_position = null) -> void:
	var final_amount := amount
	if GameState.has_cybernetic("soul_baffle"):
		final_amount *= 0.75
	# Drug comedowns (e.g. Redline) can leave you taking more damage.
	final_amount *= GameState.get_damage_taken_multiplier()
	_regen_lockout = bioreactor_combat_cooldown
	current_hp = maxf(current_hp - final_amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	damaged.emit(final_amount, current_hp, max_hp, source_position)
	if current_hp <= 0.0:
		died.emit()
		GameState.notify_player_died()


func _on_heal_requested(amount: float) -> void:
	heal(amount)


func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)
