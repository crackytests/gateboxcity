extends Control
class_name CyberEyeOverlay

## Cybereye targeting overlay. When the player has the Gatebox Eye MK1 or the
## Mag-Retina installed, every enemy body region within range gets a bracketed
## highlight, a colour-coded HP bar, and a live damage readout. Destroyed parts
## are crossed out. The Mag-Retina additionally flags each enemy's weakest
## living region as the optimal target.

@export var max_range := 60.0
@export var flash_time := 0.35

var _hp_cache: Dictionary = {}   # part instance id -> last seen current_hp
var _flash: Dictionary = {}      # part instance id -> remaining flash time


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _eye_active() -> bool:
	return GameState.has_cybernetic("gatebox_eye_mk1") or GameState.has_cybernetic("mag_retina")


func _process(delta: float) -> void:
	if not _eye_active():
		if not _flash.is_empty() or not _hp_cache.is_empty():
			_flash.clear()
			_hp_cache.clear()
			queue_redraw()
		return

	# Track per-part HP so a fresh hit pulses the bracket.
	for node in get_tree().get_nodes_in_group("body_parts"):
		var part := node as BodyPart
		if part == null:
			continue
		var id := part.get_instance_id()
		var prev: float = _hp_cache.get(id, part.current_hp)
		if part.current_hp < prev:
			_flash[id] = flash_time
		_hp_cache[id] = part.current_hp

	for id in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)

	queue_redraw()


func _draw() -> void:
	if not _eye_active():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var font := ThemeDB.fallback_font
	var use_mag := GameState.has_cybernetic("mag_retina")
	var weak_parts := _weak_points_per_enemy(cam) if use_mag else {}

	for node in get_tree().get_nodes_in_group("body_parts"):
		var part := node as BodyPart
		if part == null:
			continue
		var origin := part.global_position
		if cam.is_position_behind(origin):
			continue
		if cam.global_position.distance_to(origin) > max_range:
			continue
		var rect := _screen_rect_for(part, cam)
		if rect.size == Vector2.ZERO:
			continue

		if part.is_destroyed:
			_draw_destroyed(rect, font, part)
			continue

		var ratio := part.get_hp_ratio()
		var col := _hp_color(ratio)
		var flashing: bool = _flash.has(part.get_instance_id())
		if flashing:
			col = Color(1.0, 1.0, 1.0)

		# A part winding up an attack gets a pulsing warning highlight — shoot it
		# to interrupt.
		if part.in_windup:
			var pulse := 0.5 + absf(sin(Time.get_ticks_msec() * 0.018)) * 0.5
			var warn := Color(1.0, 0.5 + pulse * 0.3, 0.1, 1.0)
			_draw_brackets(rect, warn, 3.0)
			_draw_hp_bar(rect, ratio, warn)
			draw_string(font, rect.position + Vector2(2, -14), "%s  ! INTERRUPT" % part.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, warn)
			continue

		var is_weak: bool = use_mag and weak_parts.get(_enemy_key(part), null) == part
		_draw_brackets(rect, col, 2.5 if (flashing or is_weak) else 1.6)
		_draw_hp_bar(rect, ratio, col)
		_draw_label(rect, font, part, col, is_weak)

		# Extra intel tags below the region.
		var tag_y := rect.end.y + 2.0
		if part.volatile:
			draw_string(font, Vector2(rect.position.x, tag_y + 11.0), "VOLATILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.45, 0.1))
			tag_y += 12.0
		if part.hackable:
			draw_string(font, Vector2(rect.position.x, tag_y + 11.0), "HACKABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.85, 1.0))


# ── Per-enemy weak point (lowest current HP living region) ──────────

func _enemy_key(part: BodyPart) -> Object:
	return part.owner if part.owner != null else part


func _weak_points_per_enemy(cam: Camera3D) -> Dictionary:
	var best: Dictionary = {}      # enemy -> BodyPart
	var best_hp: Dictionary = {}   # enemy -> float
	for node in get_tree().get_nodes_in_group("body_parts"):
		var part := node as BodyPart
		if part == null or part.is_destroyed:
			continue
		if cam.is_position_behind(part.global_position):
			continue
		if cam.global_position.distance_to(part.global_position) > max_range:
			continue
		var key := _enemy_key(part)
		if not best_hp.has(key) or part.current_hp < float(best_hp[key]):
			best_hp[key] = part.current_hp
			best[key] = part
	return best


# ── Geometry ────────────────────────────────────────────────────────

func _screen_rect_for(part: BodyPart, cam: Camera3D) -> Rect2:
	var half := Vector3(0.3, 0.3, 0.3)
	var shape_node := part.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape != null:
		var s := shape_node.shape
		if s is BoxShape3D:
			half = (s as BoxShape3D).size * 0.5
		elif s is SphereShape3D:
			var r := (s as SphereShape3D).radius
			half = Vector3(r, r, r)
		elif s is CapsuleShape3D:
			var cap := s as CapsuleShape3D
			half = Vector3(cap.radius, cap.height * 0.5, cap.radius)

	var basis := part.global_transform.basis
	var center := part.global_position
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := center + basis * Vector3(half.x * sx, half.y * sy, half.z * sz)
				if cam.is_position_behind(corner):
					return Rect2()  # straddles the camera plane — skip
				var sp := cam.unproject_position(corner)
				min_p.x = minf(min_p.x, sp.x)
				min_p.y = minf(min_p.y, sp.y)
				max_p.x = maxf(max_p.x, sp.x)
				max_p.y = maxf(max_p.y, sp.y)
	return Rect2(min_p, max_p - min_p)


# ── Drawing helpers ─────────────────────────────────────────────────

func _draw_brackets(rect: Rect2, color: Color, width: float) -> void:
	var arm := clampf(minf(rect.size.x, rect.size.y) * 0.32, 5.0, 16.0)
	var l := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var bl := Vector2(rect.position.x, rect.end.y)
	var br := rect.end
	# Top-left
	draw_line(l, l + Vector2(arm, 0), color, width)
	draw_line(l, l + Vector2(0, arm), color, width)
	# Top-right
	draw_line(tr, tr + Vector2(-arm, 0), color, width)
	draw_line(tr, tr + Vector2(0, arm), color, width)
	# Bottom-left
	draw_line(bl, bl + Vector2(arm, 0), color, width)
	draw_line(bl, bl + Vector2(0, -arm), color, width)
	# Bottom-right
	draw_line(br, br + Vector2(-arm, 0), color, width)
	draw_line(br, br + Vector2(0, -arm), color, width)


func _draw_hp_bar(rect: Rect2, ratio: float, color: Color) -> void:
	var bar_w := clampf(rect.size.x, 18.0, 90.0)
	var bar_h := 3.0
	var pos := Vector2(rect.position.x + (rect.size.x - bar_w) * 0.5, rect.position.y - 7.0)
	draw_rect(Rect2(pos, Vector2(bar_w, bar_h)), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(Rect2(pos, Vector2(bar_w * clampf(ratio, 0.0, 1.0), bar_h)), color, true)


func _draw_label(rect: Rect2, font: Font, part: BodyPart, color: Color, is_weak: bool) -> void:
	var text := "%s  %d/%d" % [part.display_name, ceili(part.current_hp), ceili(part.max_hp)]
	if is_weak:
		text = "%s  [WEAK]" % text
	var label_color := Color(1.0, 0.22, 0.82) if is_weak else color
	var pos := Vector2(rect.position.x, rect.position.y - 11.0)
	# A faint backing so the text reads against bright scenery.
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)


func _draw_destroyed(rect: Rect2, font: Font, part: BodyPart) -> void:
	var col := Color(0.45, 0.45, 0.45, 0.7)
	draw_line(rect.position, rect.end, col, 1.5)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), col, 1.5)
	draw_string(font, rect.position + Vector2(0, -3.0), "%s  DOWN" % part.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _hp_color(ratio: float) -> Color:
	# Red at 0, amber mid, green at full.
	if ratio < 0.5:
		return Color(1.0, 0.2, 0.2).lerp(Color(1.0, 0.85, 0.2), ratio * 2.0)
	return Color(1.0, 0.85, 0.2).lerp(Color(0.2, 1.0, 0.5), (ratio - 0.5) * 2.0)
