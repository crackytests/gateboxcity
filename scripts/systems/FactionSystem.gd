extends Node
class_name FactionSystem

signal reputation_changed(summary: String)

var reputation: Dictionary = {
	"System X": 0,
	"Gatebox Corporation": 0,
	"Wan Moa Torai": 0,
	"Linda": 0,
}


func add_reputation(faction_name: String, amount: int) -> void:
	reputation[faction_name] = int(reputation.get(faction_name, 0)) + amount
	reputation_changed.emit(get_summary())


func get_summary() -> String:
	return "REP  System X %+d  Gatebox %+d  Torai %+d" % [
		int(reputation.get("System X", reputation.get("Sub-Basement Resistance", 0))),
		int(reputation.get("Gatebox Corporation", 0)),
		int(reputation.get("Wan Moa Torai", 0)),
	]
