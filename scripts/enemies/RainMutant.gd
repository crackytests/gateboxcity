extends Enemy
class_name RainMutant

signal containment_ready

@export var containment_center := Vector3(18.0, 0.0, -6.0)
@export var containment_radius := 4.0
@export var rain_regen_per_second := 6.0
@export var containment_dialogue_name := "Cooters Rain Mutant"
@export_multiline var containment_dialogue_text := "The mutant folds under the awning, still alive, still leaking, now technically a tenant. Marbles bolts the door around it."

var rain_sac_destroyed := false
var mobility_frame_destroyed := false
var contained := false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if contained or is_defeated:
		return

	if WorldDirector.is_toxic_rain_active() and not _is_in_containment_zone():
		_regenerate_parts(delta)

	_check_containment()


func _on_part_destroyed(part: BodyPart) -> void:
	# Base Enemy applies the data-driven destruction effect (reduce melee, slow,
	# stun, etc.). RainMutant only layers on the containment tracking flags.
	super._on_part_destroyed(part)

	match part.display_name:
		"Rain Sac":
			rain_sac_destroyed = true
		"Mobility Frame":
			mobility_frame_destroyed = true

	_check_containment()


func contain() -> void:
	if contained:
		return

	contained = true
	is_pacified = true
	move_speed = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	pacified_dialogue_name = containment_dialogue_name
	pacified_dialogue_text = containment_dialogue_text
	if billboard != null and billboard.has_method("show_defeated"):
		billboard.show_defeated()


func is_ready_for_containment() -> bool:
	return rain_sac_destroyed and mobility_frame_destroyed and _is_in_containment_zone()


func can_be_bolted_down() -> bool:
	return _is_in_containment_zone() and (rain_sac_destroyed or mobility_frame_destroyed)


func get_containment_hint() -> String:
	if contained:
		return "It is already bolted down. Cooters is open, and everyone is pretending this was normal bar maintenance."
	if can_be_bolted_down():
		return "It is hurt and near the door. Hit E at Cooters to bolt it down before it learns tenancy law."
	if not rain_sac_destroyed and not mobility_frame_destroyed:
		return "Shoot the Rain Sac and Mobility Frame, then drag it over near the Cooters door. Simple, awful, very on brand."
	if not rain_sac_destroyed:
		return "Mobility is wrecked. Now rupture the Rain Sac before it drinks more sky and gets inspirational."
	if not mobility_frame_destroyed:
		return "Rain Sac is ruptured. Now break the Mobility Frame so it cannot crawl out and become a district metaphor."
	if not _is_in_containment_zone():
		return "Both key parts are broken. Lure it near the Cooters door, then hit E before Marbles invents a worse plan."
	return "Both key parts are broken and it is by the door. Hit E at Cooters to bolt it down and call that a social contract."


func _check_containment() -> void:
	if contained:
		return
	if can_be_bolted_down():
		containment_ready.emit()


func _is_in_containment_zone() -> bool:
	var flat_position := Vector2(global_position.x, global_position.z)
	var flat_center := Vector2(containment_center.x, containment_center.z)
	return flat_position.distance_to(flat_center) <= containment_radius


func _regenerate_parts(delta: float) -> void:
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part == null or part.is_destroyed:
			continue
		part.current_hp = minf(part.max_hp, part.current_hp + rain_regen_per_second * delta)
