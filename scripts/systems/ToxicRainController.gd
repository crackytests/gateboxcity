extends Node
class_name ToxicRainController

@export var player_health_path: NodePath
@export var hud_path: NodePath
@export var tick_interval := 1.0

var shelter_count := 0
var tick_timer := 0.0
var last_exposure_state := ""

@onready var player_health: PlayerHealth = get_node(player_health_path)
@onready var hud: HUDController = get_node(hud_path)


func _ready() -> void:
	add_to_group("toxic_rain_controller")


func _process(delta: float) -> void:
	if not WorldDirector.is_toxic_rain_active():
		tick_timer = 0.0
		last_exposure_state = ""
		return

	if shelter_count > 0:
		_announce_once("sheltered", "pipe shelter blocks the toxic rain")
		tick_timer = 0.0
		return

	var damage := WorldDirector.get_event_damage_per_second()
	if GameState.has_item("Sealed Mask"):
		_announce_once("sealed", "sealed mask filters the toxic rain")
		return
	if GameState.has_item("Cheap Poncho"):
		damage *= 0.5
		_announce_once("poncho", "cheap poncho softens the toxic rain")
	else:
		_announce_once("exposed", "toxic rain eating through exposed gear")

	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		player_health.apply_damage(damage * tick_interval)


func enter_shelter() -> void:
	shelter_count += 1


func exit_shelter() -> void:
	shelter_count = maxi(shelter_count - 1, 0)


func _announce_once(state: String, message: String) -> void:
	if last_exposure_state == state:
		return
	last_exposure_state = state
	hud.push_log(message)
