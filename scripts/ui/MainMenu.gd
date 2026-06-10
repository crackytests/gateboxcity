extends Control

const BACKGROUND_PATH := "res://assets/main_menu_background.png"

var _load_panel: VBoxContainer
var _status_label: Label
var _fullscreen_toggle: CheckBox


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build_ui()
	_refresh_load_buttons()


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = _load_background_texture()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.offset_left = 56
	panel.offset_top = 84
	panel.offset_right = 424
	panel.offset_bottom = 636
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "GATEBOX BREACH"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.15, 1.0, 0.42))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CARE OPTIMIZATION BRIEFING // SYSTEM COMPROMISED"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))
	root.add_child(subtitle)

	root.add_child(_menu_button("NEW GAME", _on_new_game))
	root.add_child(_menu_button("LOAD GAME", _on_load_game))

	_load_panel = VBoxContainer.new()
	_load_panel.visible = false
	_load_panel.add_theme_constant_override("separation", 6)
	root.add_child(_load_panel)
	_load_panel.add_child(_slot_button("LOAD AUTOSAVE", GameState.SAVE_SLOT_AUTO))
	_load_panel.add_child(_slot_button("LOAD QUICKSAVE", GameState.SAVE_SLOT_QUICK))
	_load_panel.add_child(_slot_button("LOAD MANUAL", GameState.SAVE_SLOT_MANUAL))

	var settings_label := Label.new()
	settings_label.text = "SETTINGS"
	settings_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.75))
	root.add_child(settings_label)

	_fullscreen_toggle = CheckBox.new()
	_fullscreen_toggle.text = "FULLSCREEN"
	_fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	root.add_child(_fullscreen_toggle)

	root.add_child(_menu_button("QUIT", _on_quit))

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	root.add_child(_status_label)


func _menu_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 38)
	btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.45))
	btn.pressed.connect(callback)
	return btn


func _load_background_texture() -> Texture2D:
	if ResourceLoader.exists(BACKGROUND_PATH):
		var imported := load(BACKGROUND_PATH) as Texture2D
		if imported != null:
			return imported
	var image := Image.new()
	if image.load(BACKGROUND_PATH) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _slot_button(text: String, slot: String) -> Button:
	var btn := _menu_button(text, _load_slot.bind(slot))
	btn.name = "Slot_" + slot
	return btn


func _refresh_load_buttons() -> void:
	if _load_panel == null:
		return
	for child in _load_panel.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var slot := btn.name.trim_prefix("Slot_")
		btn.disabled = not GameState.has_save_file(slot)
		btn.text = GameState.describe_save_slot(slot)


func _on_new_game() -> void:
	GameState.start_new_game()


func _on_load_game() -> void:
	_load_panel.visible = not _load_panel.visible
	_refresh_load_buttons()
	if _status_label != null:
		_status_label.text = "Choose a save slot." if GameState.has_any_save_file() else "No save files found."


func _load_slot(slot: String) -> void:
	if not GameState.load_game(slot):
		_status_label.text = "Load failed."


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_quit() -> void:
	get_tree().quit()
