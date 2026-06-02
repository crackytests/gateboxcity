extends Control
class_name EventCardUI
# Interactive event-card resolution (refactor §6). An event card shows a narrative and 1-3
# choices; a choice may be plain (text + effects) or a 2d6 stat check (via Dice) that branches
# into success / failure / crit / fumble. Branch effects run through EventDeckSystem so they
# share the card vocabulary (set_flag, add_rep, add_item, remove_item, wan_notes, damage,
# add_card chaining, ...). Built in code to match the other menu UIs.

signal closed

var _card: Dictionary = {}
var _resolved := false
var _title: Label
var _body: RichTextLabel
var _choice_box: VBoxContainer
var _continue_btn: Button


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(card: Dictionary) -> void:
	_card = card
	_resolved = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var heading := str(card.get("title", card.get("speaker", "Something Happens")))
	_title.text = heading.to_upper()
	_body.clear()
	_body.append_text(str(card.get("body", card.get("text", "..."))))
	_continue_btn.visible = false
	_build_choices()


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
	# ESC only exits once resolved (so you can't peek-and-dodge an unresolved check).
	if event.is_action_pressed("ui_cancel") and _resolved:
		_on_continue()
		get_viewport().set_input_as_handled()


func _build_choices() -> void:
	for child in _choice_box.get_children():
		child.queue_free()
	var choices: Array = _card.get("choices", [])
	if choices.is_empty():
		_continue_btn.visible = true
		return
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = _choice_label(ch)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
		btn.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(btn)


func _choice_label(ch: Dictionary) -> String:
	var label := str(ch.get("label", "..."))
	if ch.has("check"):
		var c: Dictionary = ch["check"]
		var attr := str(c.get("attribute", ""))
		var dc := int(c.get("difficulty", 8))
		var mod := Dice.check_modifier(attr, str(c.get("tag", "")))
		return "%s   [%s %s — 2d6%+d vs %d]" % [label, attr, Dice.difficulty_label(dc), mod, dc]
	return label


func _on_choice(index: int) -> void:
	var choices: Array = _card.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var ch: Dictionary = choices[index]
	for child in _choice_box.get_children():
		child.queue_free()
	_body.append_text("\n\n[color=#66e0ff]> %s[/color]" % str(ch.get("label", "")))
	if ch.has("check"):
		var c: Dictionary = ch["check"]
		var res := Dice.roll_check(str(c.get("attribute", "")), int(c.get("difficulty", 8)), str(c.get("tag", "")))
		_body.append_text("\n[color=#888]%s[/color]" % Dice.describe(res))
		_resolve_branch(_pick_branch(ch, res))
	else:
		_resolve_branch(ch)


func _pick_branch(ch: Dictionary, res: Dictionary) -> Dictionary:
	if bool(res.get("crit", false)) and ch.has("crit"):
		return ch["crit"]
	if bool(res.get("fumble", false)) and ch.has("fumble"):
		return ch["fumble"]
	return ch.get("success", {}) if bool(res.get("success", false)) else ch.get("failure", {})


func _resolve_branch(branch: Dictionary) -> void:
	var text := str(branch.get("text", ""))
	if not text.is_empty():
		_body.append_text("\n\n%s" % text)
	EventDeckSystem.apply_effects(branch.get("effects", []))
	_continue_btn.visible = true


func _on_continue() -> void:
	if not _resolved:
		_resolved = true
		EventDeckSystem.expire_card(_card)
	close()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_top = -230
	panel.offset_right = 420
	panel.offset_bottom = 230
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.82))
	_title.add_theme_font_size_override("font_size", 22)
	root.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_following = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_body.add_theme_font_size_override("normal_font_size", 16)
	root.add_child(_body)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	root.add_child(_choice_box)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)
	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE"
	_continue_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	_continue_btn.pressed.connect(_on_continue)
	footer.add_child(_continue_btn)
