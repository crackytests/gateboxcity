extends Enemy
class_name PacificationWarden

## Gatebox Pacification Ward security unit. Corporate faction — a high-drift
## player reads as "one of them" and the Warden is slow to flag them. Its
## sedative sprayer telegraphs a slowing spray; restraint arm grabs; sensor
## crown carries its alarm/long-range sense; tank backpack ruptures a sedative
## cloud. All part consequences are authored as data on the scene.


func _ready() -> void:
	if faction.is_empty():
		faction = "Gatebox"
	melee_hit_message = "the warden's restraint arm clamps you for %d"
	ranged_hit_message = "sedative dart clips you for %d"
	super._ready()
