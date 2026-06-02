extends Enemy
class_name GeneralBoneDividend

## Big Gates Foundation General who runs the soul-as-inventory weapons program
## that Ward 7 supplied. A boss built from the data-driven systems: a Reckoning
## Core to defeat, a volatile Soul Battery Rack (free the ledgered souls at a
## soul-rot cost), a Command Crozier that anchors the vault's grafts, a Ledger
## Spine that drops the evidence, and a telegraphed sidearm.


func _ready() -> void:
	if faction.is_empty():
		faction = "Big Gates"
	if pack_id.is_empty():
		pack_id = "bone_dividend_grafts"
	is_pack_anchor = true
	melee_hit_message = "the General's crozier cracks you for %d"
	ranged_hit_message = "ledger-fire stings you for %d"
	super._ready()


func _defeat() -> void:
	if is_defeated:
		return
	# Set the flag before super emits `defeated`, so listeners (the vault) see it.
	GameState.set_world_flag("bone_dividend_general_defeated", true)
	super._defeat()
