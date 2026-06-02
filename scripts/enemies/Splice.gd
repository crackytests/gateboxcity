extends Enemy
class_name Splice

## Splice gang cyborg. All part-destruction consequences (Wire Skull stun,
## Graft Shell defeat, Splice Arm enrage, Drag Frame slow) now live in the
## splice_*.tres body-part data and are dispatched by the base Enemy. This
## subclass only sets Splice-specific flavour and its default drop.


func _ready() -> void:
	if drop_item.is_empty():
		drop_item = "neural_splice"
	if faction.is_empty():
		faction = "Splice"  # drift-hostile: locks on faster the more modded you are
	melee_hit_message = "splice drove the frame into you for %d"
	enraged_hit_message = "splice berserk — frame impact %d"
	super._ready()
