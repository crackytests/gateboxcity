extends Control
class_name CyberneticSurgeryUI

signal closed
signal upgrade_installed(upgrade_id: String)

var _installed: Dictionary = {}
var _available_upgrades: Array[Dictionary] = []
var _selected_slot := -1
var _slots_vbox: VBoxContainer
var _detail_label: RichTextLabel
var _install_list: ItemList
var _install_label: Label
var _install_button: Button

const BODY_SLOTS := ["Head", "Eyes", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "Spine", "Soul Slot"]
const SLOT_COLORS := {
	"Head": Color(0.9, 0.9, 1.0),
	"Eyes": Color(0.3, 1.0, 0.9),
	"Torso": Color(0.65, 0.95, 1.0),
	"Right Arm": Color(0.2, 1.0, 0.6),
	"Left Arm": Color(0.2, 1.0, 0.6),
	"Right Leg": Color(1.0, 0.7, 0.3),
	"Left Leg": Color(1.0, 0.7, 0.3),
	"Spine": Color(1.0, 0.22, 0.82),
	"Soul Slot": Color(0.8, 0.4, 1.0),
}

const UPGRADE_DB := {
	"targeting_coprocessor": {"name": "Targeting Co-Processor", "slot": "Head", "desc": "Improves reticle pickup, base hit chance, and lock speed. Bootstrapped from hacked corporate targeting hardware.", "cost": "Suitors Access Chit", "cost_item": "Suitors Access Chit", "cost_count": 1},
	"gatebox_eye_mk1": {"name": "Gatebox Eye MK1", "slot": "Eyes", "desc": "Reveals enemy body part HP when targeting. Corporate surplus with warranty voided by bullet holes.", "cost": "Cooters Bar Credit", "cost_item": "Cooters Bar Credit", "cost_count": 1},
	"black_market_armature": {"name": "Black-Market Armature", "slot": "Right Arm", "desc": "Reduces weapon kick and preserves more target lock after shots. Installed in a pipe alley by someone who learned surgery from a VHS tape.", "cost": "Torai Salvage Contract", "cost_item": "Torai Salvage Contract", "cost_count": 1},
	"pipewalker_legs": {"name": "Pipewalker Legs", "slot": "Right Leg", "desc": "Improves movement speed. Smells like industrial lubricant and ambition.", "cost": "Cheap Poncho", "cost_item": "Cheap Poncho", "cost_count": 1},
	"soul_baffle": {"name": "Soul Baffle", "slot": "Torso", "desc": "Reduces incoming integrity damage. Nobody is sure what it does to your dreams.", "cost": "Chemical Neutralizer", "cost_item": "Chemical Neutralizer", "cost_count": 1},
}


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(installed: Dictionary, available: Array[Dictionary] = []) -> void:
	_installed = installed
	_available_upgrades = available
	visible = true
	_selected_slot = -1
	_refresh_slots()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func get_selected_install_id() -> String:
	if _install_list.get_selected_items().is_empty():
		return ""
	var idx: int = _install_list.get_selected_items()[0]
	if idx < 0 or idx >= _available_upgrades.size():
		return ""
	return str(_available_upgrades[idx].get("id", ""))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh_slots() -> void:
	for child in _slots_vbox.get_children():
		child.queue_free()
	for slot_name in BODY_SLOTS:
		var btn := Button.new()
		btn.text = _slot_display(slot_name)
		btn.add_theme_color_override("font_color", SLOT_COLORS.get(slot_name, Color.WHITE))
		btn.add_theme_font_size_override("font_size", 15)
		var callable := _on_slot_selected.bind(slot_name)
		btn.pressed.connect(callable)
		_slots_vbox.add_child(btn)
	_refresh_install_list()


func _slot_display(slot_name: String) -> String:
	var upgrade_id: String = _find_installed_in_slot(slot_name)
	if upgrade_id != "":
		var db: Dictionary = UPGRADE_DB[upgrade_id] as Dictionary
		return "  %s: %s" % [slot_name, str(db.get("name", upgrade_id))]
	return "  %s: [empty]" % slot_name


func _find_installed_in_slot(slot_name: String) -> String:
	for upgrade_id in _installed.keys():
		if not bool(_installed[upgrade_id]):
			continue
		if not UPGRADE_DB.has(upgrade_id):
			continue
		var db: Dictionary = UPGRADE_DB[upgrade_id] as Dictionary
		if str(db.get("slot", "")) == slot_name:
			return upgrade_id
	return ""


func _refresh_install_list() -> void:
	_install_list.clear()
	for upgrade in _available_upgrades:
		var id: String = str(upgrade.get("id", ""))
		var db: Dictionary = UPGRADE_DB.get(id, {})
		var display: String = str(db.get("name", id))
		if GameState.has_cybernetic(id):
			display += " [INSTALLED]"
		elif not _can_pay_cost(db):
			display += " [NEED %s]" % str(db.get("cost", "payment"))
		_install_list.add_item(display)
	_install_label.text = "%d available" % _available_upgrades.size()


func _on_slot_selected(slot_name: String) -> void:
	var upgrade_id: String = _find_installed_in_slot(slot_name)
	if upgrade_id != "":
		var db: Dictionary = UPGRADE_DB.get(upgrade_id, {})
		_detail_label.text = "[color=#20ff66]%s[/color]\n[color=#aaa]Slot: %s[/color]\n\n%s\n\n[color=#ff5588]Installed. Remove at a proper surgical station.[/color]" % [
			str(db.get("name", upgrade_id)),
			slot_name,
			str(db.get("desc", "No data."))
		]
	else:
		_detail_label.text = "[color=#6599aa]%s[/color]\n\nEmpty slot. Select an available implant and click INSTALL." % slot_name
	_install_button.disabled = true


func _on_upgrade_selected(index: int) -> void:
	if index < 0 or index >= _available_upgrades.size():
		_install_button.disabled = true
		return
	var id: String = str(_available_upgrades[index].get("id", ""))
	var db: Dictionary = UPGRADE_DB.get(id, {})
	var slot_name: String = str(db.get("slot", "?"))
	var already_installed := GameState.has_cybernetic(id)
	var slot_occupied := _find_installed_in_slot(slot_name) != ""
	var can_pay := _can_pay_cost(db)

	_detail_label.text = "[color=#20ff66]%s[/color]\n[color=#aaa]Slot: %s  |  Cost: %s[/color]\n\n%s" % [
		str(db.get("name", id)),
		slot_name,
		str(db.get("cost", "???")),
		str(db.get("desc", "No data."))
	]
	if already_installed:
		_detail_label.text += "\n\n[color=#ff5588]Already installed.[/color]"
		_install_button.disabled = true
	elif slot_occupied:
		_detail_label.text += "\n\n[color=#ffaa44]Slot %s is occupied. Remove the existing implant first.[/color]" % slot_name
		_install_button.disabled = true
	elif not can_pay:
		_detail_label.text += "\n\n[color=#ff5588]Missing payment: %s.[/color]" % str(db.get("cost", "unknown"))
		_install_button.disabled = true
	else:
		_detail_label.text += "\n\n[color=#20ff66]Ready to install.[/color]"
		_install_button.disabled = false


func _on_install_pressed() -> void:
	if _install_list.get_selected_items().is_empty():
		return
	var index: int = _install_list.get_selected_items()[0]
	if index < 0 or index >= _available_upgrades.size():
		return
	var id: String = str(_available_upgrades[index].get("id", ""))
	if id.is_empty() or GameState.has_cybernetic(id):
		return
	var db: Dictionary = UPGRADE_DB.get(id, {})
	var slot_name: String = str(db.get("slot", ""))
	if _find_installed_in_slot(slot_name) != "":
		return
	if not _spend_cost(db):
		_detail_label.text += "\n\n[color=#ff5588]Payment failed.[/color]"
		_install_button.disabled = true
		return
	GameState.add_cybernetic(id)
	upgrade_installed.emit(id)
	_refresh_slots()
	_detail_label.text = "[color=#20ff66]%s installed.[/color]\n\n%s" % [
		str(db.get("name", id)),
		str(db.get("desc", ""))
	]
	_install_button.disabled = true


func _can_pay_cost(db: Dictionary) -> bool:
	var cost_item := str(db.get("cost_item", ""))
	var cost_count := int(db.get("cost_count", 0))
	if cost_item.is_empty() or cost_count <= 0:
		return true
	return GameState.has_item(cost_item, cost_count)


func _spend_cost(db: Dictionary) -> bool:
	var cost_item := str(db.get("cost_item", ""))
	var cost_count := int(db.get("cost_count", 0))
	if cost_item.is_empty() or cost_count <= 0:
		return true
	return GameState.spend_item(cost_item, cost_count)


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_top = -250
	panel.offset_right = 380
	panel.offset_bottom = 250
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
	title.text = "CYBERNETIC SURGERY"
	title.add_theme_color_override("font_color", Color(1.0, 0.22, 0.82))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(left_vbox)

	var body_label := Label.new()
	body_label.text = "BODY SLOTS"
	body_label.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	body_label.add_theme_font_size_override("font_size", 14)
	left_vbox.add_child(body_label)

	_slots_vbox = VBoxContainer.new()
	_slots_vbox.add_theme_constant_override("separation", 4)
	_slots_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_slots_vbox)

	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(center_vbox)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_detail_label.add_theme_font_size_override("normal_font_size", 15)
	center_vbox.add_child(_detail_label)

	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(right_vbox)

	var avail_label := Label.new()
	avail_label.text = "AVAILABLE"
	avail_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	avail_label.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(avail_label)

	_install_list = ItemList.new()
	_install_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_install_list.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_install_list.add_theme_color_override("font_selected_color", Color(0.2, 1.0, 0.6))
	_install_list.item_selected.connect(_on_upgrade_selected)
	right_vbox.add_child(_install_list)

	_install_button = Button.new()
	_install_button.text = "INSTALL"
	_install_button.disabled = true
	_install_button.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	_install_button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_install_button.add_theme_font_size_override("font_size", 16)
	_install_button.pressed.connect(_on_install_pressed)
	right_vbox.add_child(_install_button)

	_install_label = Label.new()
	_install_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_install_label.add_theme_font_size_override("font_size", 13)
	right_vbox.add_child(_install_label)

	var hint := Label.new()
	hint.text = "ESC close  Select implant then click INSTALL"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)
