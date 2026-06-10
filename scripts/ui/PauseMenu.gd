extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

var _panel: PanelContainer
var _status_label: Label
var _was_mouse_captured := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build_ui()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_main_menu_scene():
		return
	if _panel.visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true
	_refresh_slot_buttons()
	_status_label.text = "ESC resume"


func close() -> void:
	_panel.visible = false
	get_tree().paused = false
	if _was_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "PausePanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -230
	_panel.offset_top = -245
	_panel.offset_right = 230
	_panel.offset_bottom = 245
	add_child(_panel)
	_panel.visibility_changed.connect(func(): dim.visible = _panel.visible)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "SYSTEM PAUSED"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.15, 1.0, 0.45))
	root.add_child(title)

	root.add_child(_button("RESUME", close))
	root.add_child(_button("MANUAL SAVE", _manual_save))
	root.add_child(_button("QUICKSAVE", _quick_save))

	var load_label := Label.new()
	load_label.text = "LOAD"
	load_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.75))
	root.add_child(load_label)

	root.add_child(_slot_button("Load Autosave", GameState.SAVE_SLOT_AUTO))
	root.add_child(_slot_button("Load Quicksave", GameState.SAVE_SLOT_QUICK))
	root.add_child(_slot_button("Load Manual", GameState.SAVE_SLOT_MANUAL))

	root.add_child(_button("QUIT TO MAIN MENU", _quit_to_menu))
	root.add_child(_button("QUIT DESKTOP", _quit_desktop))

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	root.add_child(_status_label)


func _button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.45))
	btn.pressed.connect(callback)
	return btn


func _slot_button(text: String, slot: String) -> Button:
	var btn := _button(text, _load_slot.bind(slot))
	btn.name = "Slot_" + slot
	return btn


func _refresh_slot_buttons() -> void:
	for node in _panel.find_children("Slot_*", "Button", true, false):
		var btn := node as Button
		if btn == null:
			continue
		var slot := btn.name.trim_prefix("Slot_")
		btn.disabled = not GameState.has_save_file(slot)
		btn.text = GameState.describe_save_slot(slot)


func _manual_save() -> void:
	_status_label.text = "Manual save written." if GameState.save_game(GameState.SAVE_SLOT_MANUAL) else "Manual save failed."
	_refresh_slot_buttons()


func _quick_save() -> void:
	_status_label.text = "Quicksave written." if GameState.quicksave() else "Quicksave failed."
	_refresh_slot_buttons()


func _load_slot(slot: String) -> void:
	var ok := GameState.load_game(slot)
	if ok:
		close()
	else:
		_status_label.text = "Load failed."


func _quit_to_menu() -> void:
	close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit_desktop() -> void:
	get_tree().quit()


func _is_main_menu_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == MAIN_MENU_SCENE
