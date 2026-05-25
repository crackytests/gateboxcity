extends Control
class_name TravelGateUI

signal closed
signal route_selected(route_id: String)

var _routes: Array = []
var _selected_index := -1
var _route_list: ItemList
var _detail_label: RichTextLabel
var _travel_button: Button


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(routes: Array) -> void:
	_routes = routes
	_selected_index = -1
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_routes()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh_routes() -> void:
	_route_list.clear()
	for route in _routes:
		var title := str(route.get("title", "Unknown Route"))
		if bool(route.get("locked", false)):
			title += "  [LOCKED]"
		_route_list.add_item(title)
	_detail_label.text = "[color=#20ff66]Choose a route out of Leak Street.[/color]\n\nTravel rolls the route event deck before the scene changes, because even hallways need drama now."
	_travel_button.disabled = true


func _on_route_selected(index: int) -> void:
	_selected_index = index
	if index < 0 or index >= _routes.size():
		_travel_button.disabled = true
		return

	var route: Dictionary = _routes[index]
	var locked := bool(route.get("locked", false))
	var reason := str(route.get("locked_reason", "Route unavailable."))
	var lock_text := "\n\n[color=#ff5588]%s[/color]" % reason if locked else "\n\n[color=#20ff66]Route available. Suspicious, but available.[/color]"
	_detail_label.text = "[color=#20ff66]%s[/color]\n[color=#aaa]Travel Gate route[/color]\n\n%s%s" % [
		str(route.get("title", "Unknown Route")),
		str(route.get("description", "")),
		lock_text,
	]
	_travel_button.disabled = locked


func _on_travel_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _routes.size():
		return
	var route: Dictionary = _routes[_selected_index]
	if bool(route.get("locked", false)):
		return
	route_selected.emit(str(route.get("id", "")))
	close()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_top = -230
	panel.offset_right = 400
	panel.offset_bottom = 230
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
	title.text = "LEAK STREET TRAVEL GATE"
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	title.add_theme_font_size_override("font_size", 23)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_route_list = ItemList.new()
	_route_list.custom_minimum_size = Vector2(250, 0)
	_route_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_route_list.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_route_list.add_theme_color_override("font_selected_color", Color(0.2, 1.0, 0.6))
	_route_list.item_selected.connect(_on_route_selected)
	hbox.add_child(_route_list)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_detail_label.add_theme_font_size_override("normal_font_size", 16)
	hbox.add_child(_detail_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 10)
	vbox.add_child(button_row)

	_travel_button = Button.new()
	_travel_button.text = "TRAVEL"
	_travel_button.disabled = true
	_travel_button.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	_travel_button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_travel_button.pressed.connect(_on_travel_pressed)
	button_row.add_child(_travel_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(close)
	button_row.add_child(close_button)

	var hint := Label.new()
	hint.text = "ESC close  Select route then TRAVEL"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)
