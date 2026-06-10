extends Control
class_name DamageIndicators

# Directional damage markers for the AR HUD. HUDController computes a camera-relative bearing for
# each hit (0 = straight ahead, +clockwise) and calls add_hit(); we draw fading chevrons on a ring
# around the reticle pointing toward each hit's source. Cyan for normal hits, magenta for heavy.

const DURATION := 1.3
const RING_RADIUS := 118.0
const COLOR_NORMAL := Color(0.3, 1.0, 1.0)     # cyan
const COLOR_HEAVY := Color(1.0, 0.22, 0.82)    # magenta

var _hits: Array = []   # each: {"angle": float, "t": float, "heavy": bool}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func add_hit(angle: float, heavy: bool) -> void:
	_hits.append({"angle": angle, "t": DURATION, "heavy": heavy})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _hits.is_empty():
		set_process(false)
		return
	for h in _hits:
		h["t"] -= delta
	_hits = _hits.filter(func(h): return float(h["t"]) > 0.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	for h in _hits:
		var life := clampf(float(h["t"]) / DURATION, 0.0, 1.0)
		var col: Color = (COLOR_HEAVY if bool(h["heavy"]) else COLOR_NORMAL)
		col.a = life
		var ang := float(h["angle"])
		# 0 = up (straight ahead), +clockwise. Outward direction on the ring:
		var outward := Vector2(sin(ang), -cos(ang))
		var p := center + outward * RING_RADIUS
		_draw_chevron(p, outward, col)


func _draw_chevron(p: Vector2, outward: Vector2, col: Color) -> void:
	var right := Vector2(outward.y, -outward.x)
	var tip := p + outward * 15.0
	var l := p - outward * 3.0 + right * 12.0
	var r := p - outward * 3.0 - right * 12.0
	draw_colored_polygon(PackedVector2Array([tip, l, r]), col)
	# thin outline for the AR "drawn" feel
	var outline := Color(col.r, col.g, col.b, col.a * 0.9)
	draw_polyline(PackedVector2Array([tip, l, r, tip]), outline, 2.0, true)
