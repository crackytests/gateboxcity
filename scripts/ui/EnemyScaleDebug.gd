extends Control
class_name EnemyScaleDebug

## Debug tool (F10): scale enemy billboard sprites to match their hitboxes.
## Cycle through every DirectionalBillboard in the current level and tune both
## the sprite and the hitbox live. Each body region is outlined and labelled
## (cyan); the sprite's world footprint is the magenta box. Match them, then
## ENTER prints the values to bake into the enemy scene.
##
## Controls while open:
##   [ / ]            select previous / next enemy
##   up / down        select which field to edit
##   left / right     adjust the selected field   (Shift = x10 step)
##   ENTER            print current values to the output console
##   F10              close
##
## Fields:
##   sprite pixel    sprite size (uniform — texture pixel_size)
##   sprite vert     vertical placement (ground clearance / base Y)
##   hitbox width    hitbox X/Z scale  (aspect)
##   hitbox height   hitbox Y scale    (aspect)

const FIELDS := ["sprite_pixel", "sprite_vert", "hitbox_width", "hitbox_height"]
const FIELD_LABELS := {
	"sprite_pixel": "sprite pixel_size",
	"sprite_vert": "sprite vertical",
	"hitbox_width": "hitbox width (X/Z)",
	"hitbox_height": "hitbox height (Y)",
}

const PIXEL_STEP := 0.0002
const PIXEL_MIN := 0.0005
const PIXEL_MAX := 0.05
const VERT_STEP := 0.02
const HITBOX_STEP := 0.02
const HITBOX_MIN := 0.1
const HITBOX_MAX := 5.0

var _active := false
var _billboards: Array[DirectionalBillboard] = []
var _selected := 0
var _field := 0

var _backing: ColorRect
var _label: Label
var _flash_msg := ""
var _flash_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_panel()
	visible = true  # the Control stays present; contents hide via _active


func _build_panel() -> void:
	_backing = ColorRect.new()
	_backing.color = Color(0.0, 0.0, 0.0, 0.78)
	_backing.position = Vector2(18, 60)
	_backing.size = Vector2(440, 320)
	_backing.visible = false
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backing)

	_label = Label.new()
	_label.position = Vector2(30, 70)
	_label.size = Vector2(420, 300)
	_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7))
	_label.add_theme_font_size_override("font_size", 14)
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.keycode == KEY_F10:
		_toggle()
		get_viewport().set_input_as_handled()
		return

	if not _active:
		return

	match key.keycode:
		KEY_BRACKETLEFT, KEY_PAGEUP:
			_cycle_enemy(-1)
		KEY_BRACKETRIGHT, KEY_PAGEDOWN:
			_cycle_enemy(1)
		KEY_UP:
			_field = wrapi(_field - 1, 0, FIELDS.size())
		KEY_DOWN:
			_field = wrapi(_field + 1, 0, FIELDS.size())
		KEY_LEFT:
			_adjust(-1.0, key.shift_pressed)
		KEY_RIGHT:
			_adjust(1.0, key.shift_pressed)
		KEY_ENTER, KEY_KP_ENTER:
			_print_values()
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	_active = not _active
	_backing.visible = _active
	_label.visible = _active
	if _active:
		_collect_billboards()
	queue_redraw()
	_refresh_label()


func _process(delta: float) -> void:
	if not _active:
		return
	if _billboards.is_empty():
		_collect_billboards()  # pick up enemies that spawned after the menu opened
	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time - delta, 0.0)
	queue_redraw()
	_refresh_label()


# ── Selection ───────────────────────────────────────────────────────

func _collect_billboards() -> void:
	_billboards.clear()
	var root := get_tree().current_scene
	if root != null:
		_collect_recursive(root)
	if _selected >= _billboards.size():
		_selected = 0


func _collect_recursive(node: Node) -> void:
	if node is DirectionalBillboard:
		_billboards.append(node)
	for child in node.get_children():
		_collect_recursive(child)


func _current() -> DirectionalBillboard:
	if _billboards.is_empty():
		return null
	_selected = clampi(_selected, 0, _billboards.size() - 1)
	var bb := _billboards[_selected]
	if not is_instance_valid(bb):
		_collect_billboards()
		return _current()
	return bb


func _cycle_enemy(dir: int) -> void:
	if _billboards.is_empty():
		_collect_billboards()
	if _billboards.is_empty():
		return
	_selected = wrapi(_selected + dir, 0, _billboards.size())


func _enemy_root_for(bb: Node) -> Node:
	var n := bb
	while n != null:
		if n.has_node("BodyParts"):
			return n
		n = n.get_parent()
	return bb.owner if bb.owner != null else bb


func _parts_root(enemy: Node) -> Node3D:
	return enemy.get_node_or_null("BodyParts") as Node3D


# ── Adjustment ──────────────────────────────────────────────────────

func _adjust(direction: float, fast: bool) -> void:
	var bb := _current()
	if bb == null:
		return
	var mult := 10.0 if fast else 1.0
	match FIELDS[_field]:
		"sprite_pixel":
			bb.pixel_size = clampf(bb.pixel_size + direction * PIXEL_STEP * mult, PIXEL_MIN, PIXEL_MAX)
			if bb.bottom_align_to_origin:
				bb.align_bottom_to_origin(bb.ground_clearance)
		"sprite_vert":
			var step := direction * VERT_STEP * mult
			if bb.bottom_align_to_origin:
				bb.align_bottom_to_origin(maxf(bb.ground_clearance + step, -5.0))
			else:
				bb.base_y += step
				bb.position.y = bb.base_y
		"hitbox_width":
			var pr := _parts_root(_enemy_root_for(bb))
			if pr != null:
				var s := pr.scale
				var w := clampf(s.x + direction * HITBOX_STEP * mult, HITBOX_MIN, HITBOX_MAX)
				pr.scale = Vector3(w, s.y, w)
		"hitbox_height":
			var pr2 := _parts_root(_enemy_root_for(bb))
			if pr2 != null:
				var s2 := pr2.scale
				var h := clampf(s2.y + direction * HITBOX_STEP * mult, HITBOX_MIN, HITBOX_MAX)
				pr2.scale = Vector3(s2.x, h, s2.z)


func _print_values() -> void:
	var bb := _current()
	if bb == null:
		return
	var enemy := _enemy_root_for(bb)
	var line := "[EnemyScaleDebug] %s  ->  pixel_size = %.5f" % [enemy.name, bb.pixel_size]
	if bb.bottom_align_to_origin:
		line += "   ground_clearance = %.3f" % bb.ground_clearance
	else:
		line += "   base_y = %.3f" % bb.base_y
	var pr := _parts_root(enemy)
	if pr != null:
		line += "   BodyParts.scale = (%.3f, %.3f, %.3f)" % [pr.scale.x, pr.scale.y, pr.scale.z]
	print(line)
	_flash_msg = "printed to console"
	_flash_time = 1.5


# ── Hitbox / sprite measurement ─────────────────────────────────────

func _part_shape_transform(part: BodyPart) -> Transform3D:
	var shape_node := part.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		return part.global_transform * shape_node.transform
	return part.global_transform


func _shape_half_extents(part: BodyPart) -> Vector3:
	var shape_node := part.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return Vector3(0.3, 0.3, 0.3)
	var s := shape_node.shape
	if s is BoxShape3D:
		return (s as BoxShape3D).size * 0.5
	if s is SphereShape3D:
		var r := (s as SphereShape3D).radius
		return Vector3(r, r, r)
	if s is CapsuleShape3D:
		var cap := s as CapsuleShape3D
		return Vector3(cap.radius, cap.height * 0.5, cap.radius)
	return Vector3(0.3, 0.3, 0.3)


func _hitbox_aabb(enemy: Node) -> AABB:
	var box := AABB()
	var started := false
	var parts_root := _parts_root(enemy)
	if parts_root == null:
		return box
	for child in parts_root.get_children():
		var part := child as BodyPart
		if part == null or part.is_destroyed:
			continue
		var xf := _part_shape_transform(part)
		var half := _shape_half_extents(part)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner := xf.origin + xf.basis * Vector3(half.x * sx, half.y * sy, half.z * sz)
					if not started:
						box = AABB(corner, Vector3.ZERO)
						started = true
					else:
						box = box.expand(corner)
	return box


# ── Drawing ─────────────────────────────────────────────────────────

func _draw() -> void:
	if not _active:
		return
	var bb := _current()
	var cam := get_viewport().get_camera_3d()
	if bb == null or cam == null:
		return
	var enemy := _enemy_root_for(bb)

	# Cyan: every body region, individually outlined and labelled.
	var parts_root := _parts_root(enemy)
	if parts_root != null:
		for child in parts_root.get_children():
			var part := child as BodyPart
			if part == null:
				continue
			var col := Color(0.45, 0.45, 0.45, 0.7) if part.is_destroyed else Color(0.2, 0.9, 1.0)
			_draw_part_region(part, cam, col)

	# Magenta: sprite footprint (billboard quad in world space).
	_draw_sprite_box(bb, cam, Color(1.0, 0.25, 0.85))


func _draw_part_region(part: BodyPart, cam: Camera3D, color: Color) -> void:
	var xf := _part_shape_transform(part)
	var half := _shape_half_extents(part)
	var smin := Vector2(INF, INF)
	var smax := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := xf.origin + xf.basis * Vector3(half.x * sx, half.y * sy, half.z * sz)
				if cam.is_position_behind(corner):
					return
				var sp := cam.unproject_position(corner)
				smin.x = minf(smin.x, sp.x)
				smin.y = minf(smin.y, sp.y)
				smax.x = maxf(smax.x, sp.x)
				smax.y = maxf(smax.y, sp.y)
	draw_rect(Rect2(smin, smax - smin), color, false, 1.5)
	draw_string(ThemeDB.fallback_font, smin + Vector2(2, -3), part.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _draw_sprite_box(bb: DirectionalBillboard, cam: Camera3D, color: Color) -> void:
	var tex := bb.texture
	if tex == null:
		return
	var w := float(tex.get_width()) * bb.pixel_size
	var h := float(tex.get_height()) * bb.pixel_size
	var center := bb.global_position
	var right := cam.global_transform.basis.x
	var up := Vector3.UP
	var corners := [
		center - right * (w * 0.5) - up * (h * 0.5),
		center + right * (w * 0.5) - up * (h * 0.5),
		center + right * (w * 0.5) + up * (h * 0.5),
		center - right * (w * 0.5) + up * (h * 0.5),
	]
	var pts := PackedVector2Array()
	for c in corners:
		if cam.is_position_behind(c):
			return
		pts.append(cam.unproject_position(c))
	pts.append(pts[0])
	draw_polyline(pts, color, 2.0)
	draw_string(ThemeDB.fallback_font, pts[3] + Vector2(2, -4), "SPRITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


# ── Readout panel ───────────────────────────────────────────────────

func _refresh_label() -> void:
	if _label == null or not _active:
		return
	var bb := _current()
	if bb == null:
		_label.text = "ENEMY SPRITE SCALE  (F10 close)\n\nNo enemy sprites found in this level."
		return
	var enemy := _enemy_root_for(bb)
	var box := _hitbox_aabb(enemy)
	var pr := _parts_root(enemy)
	var tex := bb.texture
	var sprite_h := float(tex.get_height()) * bb.pixel_size if tex != null else 0.0
	var sprite_w := float(tex.get_width()) * bb.pixel_size if tex != null else 0.0
	var hit_h := box.size.y
	var hit_w := maxf(box.size.x, box.size.z)
	var region_count := 0
	if pr != null:
		for child in pr.get_children():
			if child is BodyPart:
				region_count += 1

	var lines := [
		"ENEMY SPRITE SCALE DEBUG    (F10 close)",
		"enemy %d / %d : %s   (%d regions)" % [_selected + 1, _billboards.size(), enemy.name, region_count],
		"[ / ] select enemy   up/down field   left/right edit   enter print",
		"",
	]
	# Field rows with a cursor on the active one.
	lines.append(_field_row("sprite_pixel", "%.5f" % bb.pixel_size))
	var vert_val := ("%.3f (clearance)" % bb.ground_clearance) if bb.bottom_align_to_origin else ("%.3f (base Y)" % bb.base_y)
	lines.append(_field_row("sprite_vert", vert_val))
	var hw := pr.scale.x if pr != null else 1.0
	var hh := pr.scale.y if pr != null else 1.0
	lines.append(_field_row("hitbox_width", "%.3f x" % hw))
	lines.append(_field_row("hitbox_height", "%.3f x" % hh))
	lines.append("")
	lines.append("sprite  H x W : %.2f x %.2f m  (magenta)" % [sprite_h, sprite_w])
	lines.append("hitbox  H x W : %.2f x %.2f m  (cyan)" % [hit_h, hit_w])
	lines.append("  height : %s    width : %s" % [_match_tag(sprite_h, hit_h), _match_tag(sprite_w, hit_w)])
	if _flash_time > 0.0:
		lines.append("")
		lines.append("> %s" % _flash_msg)
	_label.text = "\n".join(lines)


func _field_row(field: String, value: String) -> String:
	var cursor := "> " if FIELDS[_field] == field else "  "
	return "%s%-20s : %s" % [cursor, str(FIELD_LABELS.get(field, field)), value]


func _match_tag(a: float, b: float) -> String:
	if b <= 0.0:
		return "n/a"
	var ratio := a / b
	if absf(ratio - 1.0) <= 0.05:
		return "MATCH"
	return "%.0f%%" % (ratio * 100.0)
