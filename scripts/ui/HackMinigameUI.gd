extends Control
class_name HackMinigameUI

signal hack_completed(success: bool, difficulty: int)
signal closed

var _grid_cols := 4
var _grid_rows := 3
var _difficulty := 1
var _source_row := 0
var _grid: Array = []
var _reachable: Array[Vector2i] = []
var _signal_path: Array[Vector2i] = []
var _solved := false
var _time_remaining := 30.0
var _attempt_spent := false

var _timer_label: Label
var _grid_container: GridContainer
var _status_label: Label
var _buttons: Array = []

const SHAPE_STRAIGHT := 0
const SHAPE_BEND := 1
const SHAPE_CROSS := 2

const DIR_UP := 0
const DIR_RIGHT := 1
const DIR_DOWN := 2
const DIR_LEFT := 3


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(difficulty: int) -> void:
	_difficulty = clampi(difficulty, 1, 5)
	_solved = false
	_attempt_spent = false
	_time_remaining = 27.0 - (_difficulty - 1) * 3.0
	# Neural Jack ports straight into the terminal; the Glass drug sharpens focus.
	if GameState.has_cybernetic("neural_jack"):
		_time_remaining += 8.0
	_time_remaining += GameState.get_hack_bonus() * 4.0
	_grid_cols = 3 + _difficulty
	_grid_rows = 2 + _difficulty
	_generate_puzzle()
	_build_buttons()
	_refresh_display()
	_timer_label.text = "TIME  00:%02d" % ceili(_time_remaining)
	_status_label.text = "Route signal from green arrow to right edge"
	_status_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.94))
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible or _solved:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_status_label.text = "SIGNAL LOST — hack failed"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
		_solved = true
		if not _attempt_spent:
			_attempt_spent = true
			hack_completed.emit(false, _difficulty)
	else:
		var secs := ceili(_time_remaining)
		_timer_label.text = "TIME  %02d:%02d" % [int(secs / 60.0), secs % 60]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ── Puzzle Generation ──


func _generate_puzzle() -> void:
	var path := _build_solution_path()
	_source_row = path[0].y
	_grid.clear()
	for r in range(_grid_rows):
		var row_data: Array = []
		for c in range(_grid_cols):
			row_data.append([SHAPE_CROSS, 0])
		_grid.append(row_data)

	for i in range(path.size()):
		var cell: Vector2i = path[i]
		var incoming: int
		var outgoing: int
		if i == 0:
			incoming = DIR_LEFT
		else:
			incoming = _opposite(_dir_between(path[i - 1], cell))
		if i == path.size() - 1:
			outgoing = DIR_RIGHT
		else:
			outgoing = _dir_between(cell, path[i + 1])
		if _are_opposite(incoming, outgoing):
			_grid[cell.y][cell.x] = [SHAPE_STRAIGHT, _straight_rot(incoming)]
		else:
			_grid[cell.y][cell.x] = [SHAPE_BEND, _bend_rot(incoming, outgoing)]

	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	var path_set: Dictionary = {}
	for p in path:
		path_set[p] = true
	for r in range(_grid_rows):
		for c in range(_grid_cols):
			if path_set.has(Vector2i(c, r)):
				continue
			if rng.randi_range(0, 2) == 0:
				_grid[r][c] = [SHAPE_STRAIGHT, rng.randi_range(0, 1)]
			else:
				_grid[r][c] = [SHAPE_BEND, rng.randi_range(0, 3)]

	for p in path:
		var scramble := rng.randi_range(1, 3)
		for _j in range(scramble):
			_grid[p.y][p.x][1] = (_grid[p.y][p.x][1] + 1) % 4

	_refresh_flow()


func _build_solution_path() -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	var start_row := rng.randi_range(0, _grid_rows - 1)
	var path: Array[Vector2i] = [Vector2i(0, start_row)]
	var visited: Dictionary = {Vector2i(0, start_row): true}
	var current := Vector2i(0, start_row)

	while current.x < _grid_cols - 1:
		var candidates: Array[Vector2i] = []
		var right := Vector2i(current.x + 1, current.y)
		if right.x < _grid_cols and not visited.has(right):
			candidates.append(right)
			candidates.append(right)
		if current.y > 0:
			var up := Vector2i(current.x, current.y - 1)
			if not visited.has(up):
				candidates.append(up)
		if current.y < _grid_rows - 1:
			var down := Vector2i(current.x, current.y + 1)
			if not visited.has(down):
				candidates.append(down)
		if candidates.is_empty():
			var forced := Vector2i(current.x + 1, current.y)
			if forced.x < _grid_cols:
				candidates.append(forced)
			else:
				break
		var next: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		path.append(next)
		visited[next] = true
		current = next
	return path


# ── Direction Helpers ──


func _dir_between(from: Vector2i, to: Vector2i) -> int:
	if to.x > from.x:
		return DIR_RIGHT
	if to.x < from.x:
		return DIR_LEFT
	if to.y > from.y:
		return DIR_DOWN
	return DIR_UP


func _opposite(d: int) -> int:
	return (d + 2) % 4


func _are_opposite(a: int, b: int) -> bool:
	return (a + 2) % 4 == b


func _straight_rot(incoming: int) -> int:
	if incoming == DIR_UP or incoming == DIR_DOWN:
		return 0
	return 1


func _bend_rot(incoming: int, outgoing: int) -> int:
	for r in range(4):
		var c1 := (DIR_UP + r) % 4
		var c2 := (DIR_RIGHT + r) % 4
		if (c1 == incoming and c2 == outgoing) or (c1 == outgoing and c2 == incoming):
			return r
	return 0


func _next_pos(row: int, col: int, dir: int) -> Vector2i:
	match dir:
		DIR_UP:
			return Vector2i(col, row - 1)
		DIR_DOWN:
			return Vector2i(col, row + 1)
		DIR_LEFT:
			return Vector2i(col - 1, row)
		DIR_RIGHT:
			return Vector2i(col + 1, row)
	return Vector2i(col, row)


# ── Cell Connections ──


func _get_connections(row: int, col: int) -> Array:
	var cell: Array = _grid[row][col]
	var shape: int = cell[0]
	var rot: int = cell[1]
	match shape:
		SHAPE_STRAIGHT:
			return [(DIR_UP + rot) % 4, (DIR_DOWN + rot) % 4]
		SHAPE_BEND:
			return [(DIR_UP + rot) % 4, (DIR_RIGHT + rot) % 4]
		SHAPE_CROSS:
			return [DIR_UP, DIR_RIGHT, DIR_DOWN, DIR_LEFT]
	return []


# ── Signal Tracing ──


func _refresh_flow() -> void:
	_reachable = _find_reachable()
	_signal_path.clear()
	_trace_solution()


func _find_reachable() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = []
	var source_conn := _get_connections(_source_row, 0)
	if not DIR_LEFT in source_conn:
		return result
	queue.append([Vector2i(0, _source_row), DIR_LEFT])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var cell: Vector2i = item[0]
		var entry_side: int = item[1]
		if visited.has(cell):
			continue
		visited[cell] = true
		var conn := _get_connections(cell.y, cell.x)
		if not entry_side in conn:
			continue
		result.append(cell)
		for exit_dir in conn:
			if exit_dir == entry_side:
				continue
			var next := _next_pos(cell.y, cell.x, exit_dir)
			if next.x < 0 or next.x >= _grid_cols or next.y < 0 or next.y >= _grid_rows:
				continue
			if visited.has(next):
				continue
			queue.append([next, _opposite(exit_dir)])
	return result


func _trace_solution() -> bool:
	var visited: Dictionary = {}
	return _trace(_source_row, 0, DIR_LEFT, visited)


func _trace(row: int, col: int, entry_side: int, visited: Dictionary) -> bool:
	var key := Vector2i(col, row)
	if col == _grid_cols - 1:
		var edge_conn := _get_connections(row, col)
		if entry_side in edge_conn and DIR_RIGHT in edge_conn:
			_signal_path.append(key)
			return true
		return false
	if visited.has(key):
		return false
	visited[key] = true
	var conn := _get_connections(row, col)
	if not entry_side in conn:
		return false
	_signal_path.append(key)
	for exit_dir in conn:
		if exit_dir == entry_side:
			continue
		var next := _next_pos(row, col, exit_dir)
		if next.x < 0 or next.x >= _grid_cols or next.y < 0 or next.y >= _grid_rows:
			continue
		if _trace(next.y, next.x, _opposite(exit_dir), visited.duplicate()):
			return true
	_signal_path.pop_back()
	return false


# ── Interaction ──


func _on_node_clicked(row: int, col: int) -> void:
	if _solved:
		return
	if row < 0 or row >= _grid_rows or col < 0 or col >= _grid_cols:
		return
	_grid[row][col][1] = (_grid[row][col][1] + 1) % 4
	_refresh_flow()
	if _signal_path.size() > 0 and _trace_solution():
		_solved = true
		_status_label.text = "SIGNAL LOCKED — hack successful"
		_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		if not _attempt_spent:
			_attempt_spent = true
			hack_completed.emit(true, _difficulty)
	else:
		_status_label.text = "NO PATH — rotate nodes to route signal"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_refresh_display()


# ── Display ──


func _build_buttons() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	_buttons.clear()
	_grid_container.columns = _grid_cols
	for r in range(_grid_rows):
		for c in range(_grid_cols):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(52, 52)
			btn.add_theme_font_size_override("font_size", 24)
			var callable := _on_node_clicked.bind(r, c)
			btn.pressed.connect(callable)
			_grid_container.add_child(btn)
			_buttons.append(btn)


func _refresh_display() -> void:
	for r in range(_grid_rows):
		for c in range(_grid_cols):
			var idx := r * _grid_cols + c
			if idx >= _buttons.size():
				continue
			var btn: Button = _buttons[idx]
			var conn := _get_connections(r, c)
			btn.text = _symbol_for(conn)
			var color := Color(0.45, 0.65, 0.75)
			if _is_in_solution(c, r):
				color = Color(0.2, 1.0, 0.6)
			elif _is_reachable(c, r):
				color = Color(0.3, 0.85, 0.95)
			if r == _source_row and c == 0:
				color = Color(1.0, 0.95, 0.4) if not _is_reachable(c, r) else Color(0.2, 1.0, 0.6)
			btn.add_theme_color_override("font_color", color)


func _is_in_solution(col: int, row: int) -> bool:
	return _signal_path.has(Vector2i(col, row))


func _is_reachable(col: int, row: int) -> bool:
	return _reachable.has(Vector2i(col, row))


func _symbol_for(conn: Array) -> String:
	var up := DIR_UP in conn
	var right := DIR_RIGHT in conn
	var down := DIR_DOWN in conn
	var left := DIR_LEFT in conn
	if up and down and left and right:
		return "╋"
	if up and down and not left and not right:
		return "┃"
	if left and right and not up and not down:
		return "━"
	if up and right and not down and not left:
		return "└"
	if right and down and not up and not left:
		return "┌"
	if down and left and not up and not right:
		return "┐"
	if left and up and not down and not right:
		return "┘"
	if up and down and right and not left:
		return "┣"
	if up and down and left and not right:
		return "┫"
	if up and left and right and not down:
		return "┻"
	if down and left and right and not up:
		return "┳"
	return "·"


# ── UI Construction ──


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_top = -260
	panel.offset_right = 320
	panel.offset_bottom = 260
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "HACK TERMINAL — Signal Routing"
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_timer_label = Label.new()
	_timer_label.text = "TIME  00:27"
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.62))
	_timer_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_timer_label)

	var legend := Label.new()
	legend.text = "  yellow = entry    cyan = connected    green = solved path"
	legend.add_theme_color_override("font_color", Color(0.5, 0.6, 0.55))
	legend.add_theme_font_size_override("font_size", 12)
	vbox.add_child(legend)

	_grid_container = GridContainer.new()
	_grid_container.columns = _grid_cols
	_grid_container.add_theme_constant_override("h_separation", 4)
	_grid_container.add_theme_constant_override("v_separation", 4)
	_grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_grid_container)

	_status_label = Label.new()
	_status_label.text = "Route signal from green arrow to right edge"
	_status_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.94))
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	var hint := Label.new()
	hint.text = "Click to rotate  ESC close"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
