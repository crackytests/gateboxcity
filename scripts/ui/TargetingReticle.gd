extends Control
class_name TargetingReticle

@export var reticle_color := Color(0.2, 1.0, 0.6, 0.95)
@export var unlocked_radius := 28.0
@export var locked_radius := 8.0

var lock_ratio := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_lock_ratio(value: float) -> void:
	lock_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := lerpf(unlocked_radius, locked_radius, lock_ratio)
	var gap := radius * 0.35
	var arm := radius * 0.75
	var width := 2.0

	draw_line(center + Vector2(-gap, 0), center + Vector2(-arm, 0), reticle_color, width)
	draw_line(center + Vector2(gap, 0), center + Vector2(arm, 0), reticle_color, width)
	draw_line(center + Vector2(0, -gap), center + Vector2(0, -arm), reticle_color, width)
	draw_line(center + Vector2(0, gap), center + Vector2(0, arm), reticle_color, width)
	draw_arc(center, radius, 0.0, TAU, 36, reticle_color, 1.0)
