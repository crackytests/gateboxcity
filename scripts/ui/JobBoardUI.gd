extends Control
class_name JobBoardUI

signal closed
signal job_accepted(job_id: String)

var _jobs: Array = []
var _active_job_id := ""
var _selected_index := -1
var _job_list: ItemList
var _detail_label: RichTextLabel
var _accept_button: Button


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(jobs: Array, active_job_id: String) -> void:
	_jobs = jobs
	_active_job_id = active_job_id
	_selected_index = -1
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_jobs()
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


func _refresh_jobs() -> void:
	_job_list.clear()
	for job in _jobs:
		var title := str(job.get("title", "Untitled Job"))
		var status := str(job.get("status", "available"))
		_job_list.add_item("%s  [%s]" % [title, status.to_upper()])
	_detail_label.text = "[color=#20ff66]Pick a Cooters job.[/color]\n\nOne active job at a time. Marbles pays when the objective is done and the story still has all its limbs."
	_accept_button.disabled = true


func _on_job_selected(index: int) -> void:
	_selected_index = index
	if index < 0 or index >= _jobs.size():
		_accept_button.disabled = true
		return

	var job: Dictionary = _jobs[index]
	var status := str(job.get("status", "available"))
	var lock_text := ""
	if status == "paid":
		lock_text = "\n\n[color=#777777]Paid out. Marbles says congratulations from a safe liability distance.[/color]"
	elif status == "active":
		lock_text = "\n\n[color=#ffaa44]Already active. Ask Marbles before the job invents a subplot.[/color]"
	elif status == "ready for payout":
		lock_text = "\n\n[color=#20ff66]Objective complete. Report to Marbles for payment and light judgment.[/color]"
	elif not _active_job_id.is_empty():
		lock_text = "\n\n[color=#ff5588]Finish your active job before taking another.[/color]"
	else:
		lock_text = "\n\n[color=#20ff66]Ready to accept.[/color]"

	var threat := int(job.get("threat_band", 2))
	var threat_names: Array[String] = ["—", "Low", "Moderate", "High", "Severe"]
	var threat_label: String = threat_names[clampi(threat, 0, 4)]
	_detail_label.text = "[color=#20ff66]%s[/color]\n[color=#aaa]From: %s  |  Destination: %s  |  Threat: %s[/color]\n[color=#aaa]Reward: %s[/color]\n\n%s\n\n[color=#66ddff]%s[/color]%s" % [
		str(job.get("title", "Untitled Job")),
		str(job.get("giver", "Marbles")),
		str(job.get("destination", "Unknown")),
		threat_label,
		str(job.get("reward_text", "")),
		str(job.get("short_desc", "")),
		str(job.get("objective", "")),
		lock_text,
	]
	_accept_button.disabled = status != "available" or not _active_job_id.is_empty()


func _on_accept_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _jobs.size():
		return
	var job: Dictionary = _jobs[_selected_index]
	var job_id := str(job.get("id", ""))
	if job_id.is_empty():
		return
	job_accepted.emit(job_id)
	close()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -430
	panel.offset_top = -245
	panel.offset_right = 430
	panel.offset_bottom = 245
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
	title.text = "COOTERS JOB BOARD"
	title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.82))
	title.add_theme_font_size_override("font_size", 23)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_job_list = ItemList.new()
	_job_list.custom_minimum_size = Vector2(280, 0)
	_job_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_job_list.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_job_list.add_theme_color_override("font_selected_color", Color(0.2, 1.0, 0.6))
	_job_list.item_selected.connect(_on_job_selected)
	hbox.add_child(_job_list)

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

	_accept_button = Button.new()
	_accept_button.text = "ACCEPT"
	_accept_button.disabled = true
	_accept_button.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	_accept_button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_accept_button.pressed.connect(_on_accept_pressed)
	button_row.add_child(_accept_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(close)
	button_row.add_child(close_button)

	var hint := Label.new()
	hint.text = "ESC close  Select job then ACCEPT"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)
