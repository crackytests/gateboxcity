extends Area3D
class_name GeneratorNode

signal focus_changed(generator, has_focus: bool)

@export var prompt_text := "Press E: inspect generator"
@export var required_item := "Illegal Reactor Cell"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> Dictionary:
	var state := WorldDirector.get_generator_state()
	if state == WorldDirector.GENERATOR_STABLE:
		return {
			"name": "Dreaming Generator",
			"text": "The generator is stable. It hums like something asleep but pretending not to dream.",
			"changed": false,
		}

	if GameState.spend_item(required_item):
		WorldDirector.set_generator_state(WorldDirector.GENERATOR_STABLE)
		WorldDirector.clear_event()
		GameState.add_reputation("System X", 1)
		GameState.set_world_flag("patch_dreaming_generator", true)
		GameState.mark_quest_completed("patch_dreaming_generator")
		GameState.last_mission_result = "Dreaming Generator stabilized"
		return {
			"name": "Dreaming Generator",
			"text": "The reactor cell seats with a wet click. The generator steadies. System X owes you a small, suspicious favor.",
			"changed": true,
		}

	WorldDirector.set_generator_state(WorldDirector.GENERATOR_OVERLOADED)
	WorldDirector.trigger_event(WorldDirector.EVENT_POWER_SAG)
	return {
		"name": "Dreaming Generator",
		"text": "The generator coughs into overload. It needs an Illegal Reactor Cell before the district lights get any braver.",
		"changed": true,
	}


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, true)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		focus_changed.emit(self, false)
