extends Enemy
class_name BigGatesOverseer

## Mid-level Big Gates operative running the Comfort Annexe sublevel. Not a
## General. Acts as the pack ANCHOR for the failed grafts: while its command
## rig is intact it buffs them (the base pack system). Destroy the rig and the
## grafts go feral; destroy the data spine for partial evidence; the sidearm
## mount carries its ranged weapon.


func _ready() -> void:
	if faction.is_empty():
		faction = "Big Gates"
	if pack_id.is_empty():
		pack_id = "ward7_grafts"
	is_pack_anchor = true
	melee_hit_message = "the overseer cracks you for %d"
	ranged_hit_message = "overseer sidearm — %d"
	super._ready()


func _defeat() -> void:
	if is_defeated:
		return
	super._defeat()
	GameState.set_world_flag("ward7_overseer_defeated", true)
