extends Enemy
class_name Splice

var _berserk_active := false


func _ready() -> void:
	if drop_item.is_empty():
		drop_item = "neural_splice"
	super._ready()
var _berserk_timer := 0.0

const BERSERK_MULT := 1.8
const BERSERK_DURATION := 3.5


func _physics_process(delta: float) -> void:
	if _berserk_active:
		_berserk_timer = maxf(_berserk_timer - delta, 0.0)
		if _berserk_timer <= 0.0:
			melee_damage /= BERSERK_MULT
			_berserk_active = false
	super._physics_process(delta)


func _on_part_destroyed(part: BodyPart) -> void:
	part.monitorable = false
	part.visible = false
	body_part_destroyed.emit(part.display_name)
	_show_part_break_effect(part)
	if billboard != null and billboard.has_method("show_part_broken"):
		billboard.show_part_broken(part.display_name)

	match part.display_name:
		"Wire Skull":
			stun_timer = maxf(stun_timer, 2.0)
		"Graft Shell":
			_defeat()
		"Splice Arm":
			if not _berserk_active:
				_berserk_active = true
				_berserk_timer = BERSERK_DURATION
				melee_damage *= BERSERK_MULT
				attacked_player.emit("splice lost the arm — frame running hot now")
		"Drag Frame":
			move_speed = maxf(move_speed * 0.2, 0.15)


func _try_attack(distance_to_player: float) -> void:
	if is_pacified or attack_timer > 0.0:
		return
	var ph := player.find_child("PlayerHealth", true, false)
	if ph == null:
		return
	if distance_to_player <= attack_range:
		ph.apply_damage(melee_damage)
		attack_flash_timer = 0.22
		if _berserk_active:
			attacked_player.emit("splice berserk — frame impact %d" % roundi(melee_damage))
		else:
			attacked_player.emit("splice drove the frame into you for %d" % roundi(melee_damage))
		attack_timer = attack_cooldown
