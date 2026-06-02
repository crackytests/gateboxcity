extends Enemy
class_name WardResidentGraft

## A failed Big Gates graft — a former pod resident with weapons hardware
## bolted onto a still-partly-human body. Mixed human/hardware parts (the
## HUD labels stay deliberately inconsistent). Behaviour shifts as parts break.
##
## Non-lethal exit: once the weapon arm is destroyed, if the player breaks to
## >8m the graft stops pursuing and shuffles back toward where it came from,
## rather than fighting to the death. Communicated through behaviour, not UI.

@export var leash_distance := 8.0

var _weapon_arm_destroyed := false


func _ready() -> void:
	if faction.is_empty():
		faction = "Big Gates"
	if pack_id.is_empty():
		pack_id = "ward7_grafts"  # the Overseer's command rig buffs these
	melee_hit_message = "the graft claws you for %d"
	super._ready()


func _on_part_destroyed(part: BodyPart) -> void:
	super._on_part_destroyed(part)
	if part.display_name == "GRAFT — RIGHT ARM":
		_weapon_arm_destroyed = true


func _process_combat(delta: float) -> void:
	# With its weapon gone, the broken person inside wins out: if you give it
	# space, it disengages instead of chasing you down.
	if _weapon_arm_destroyed and player != null:
		if global_position.distance_to(player.global_position) > leash_distance:
			ai_state = AIState.PATROL
			_detection = 0.0
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			return
	super._process_combat(delta)
