extends Control
class_name InventoryUI

signal closed

var _items: Dictionary = {}
var _selected_index := -1
var _item_list: ItemList
var _detail_label: RichTextLabel
var _title_label: Label
var _use_label: Label

const ITEM_DB := {
	"Cheap Poncho": {"desc": "Halves toxic rain damage. Smells like recycled hope.", "type": "Protection", "slot": "Worn"},
	"Sealed Mask": {"desc": "Prevents toxic rain damage entirely. Filters nothing else.", "type": "Protection", "slot": "Face"},
	"Chemical Neutralizer": {"desc": "Neutralizes one chemical hazard. Inventory only for now.", "type": "Consumable", "slot": "Inventory"},
	"Illegal Reactor Cell": {"desc": "Heavy wasted potential. Gideon can feed it to the Dreaming Generator.", "type": "Salvage", "slot": "Chapel"},
	"Wan Note": {"desc": "Sub-Sub-Basement currency. Wan protection, System X tracker, same little bill.", "type": "Currency", "slot": "Wallet"},
	"Cooters Bar Credit": {"desc": "One drink, one rumor, or one bad decision at Cooters.", "type": "Currency", "slot": "Bar"},
	"Suitors Access Chit": {"desc": "Grants access to Suitors back room surveillance feeds.", "type": "Access", "slot": "Key"},
	"Torai Salvage Contract": {"desc": "Legal permission to salvage corporate waste. Legalese optional.", "type": "Permit", "slot": "Contract"},
	"Mall Arcade Token": {"desc": "Currency for the Faded Atrium upgrade kiosk.", "type": "Currency", "slot": "Token"},
	"Jolt": {"desc": "Brickmouth's street stim. Speeds you up hard, then leaves your aim shaking on the comedown.", "type": "Consumable", "slot": "Inventory"},
	"Glass": {"desc": "Clarity cut for runners. Sharpens aim and hacks; the comedown turns your legs to wet sand.", "type": "Consumable", "slot": "Inventory"},
	"Redline": {"desc": "Combat juice. You hit far harder — and bleed far easier once it sours.", "type": "Consumable", "slot": "Inventory"},
	"Patch": {"desc": "Wan Moa Torai field medicine. Restores integrity fast, leaves you briefly foggy.", "type": "Consumable", "slot": "Inventory"},
}

func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(items: Dictionary) -> void:
	AudioDirector.play_sfx("menu_open", -2.0)
	_items = items
	visible = true
	_selected_index = -1
	_refresh_list()
	if _item_list.item_count > 0:
		_selected_index = 0
		_item_list.select(0)
		_show_detail(0)
	else:
		_detail_label.text = ""
		_use_label.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if visible:
		AudioDirector.play_sfx("menu_close", -2.0)
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()


func _move_selection(dir: int) -> void:
	if _item_list.item_count == 0:
		return
	_selected_index = wrapi(_selected_index + dir, 0, _item_list.item_count)
	_item_list.select(_selected_index)
	_item_list.ensure_current_is_visible()
	_show_detail(_selected_index)


func _refresh_list() -> void:
	_item_list.clear()
	var idx := 0
	for item_name in _items.keys():
		var count: int = int(_items[item_name])
		var entry: String = ("%s x%d" % [item_name, count]) as String if count > 1 else (str(item_name)) as String
		_item_list.add_item(entry)
		if idx == _selected_index:
			_item_list.select(idx)
		idx += 1


func _show_detail(index: int) -> void:
	if index < 0 or index >= _items.keys().size():
		_detail_label.text = ""
		_use_label.text = ""
		return
	var item_name: String = _items.keys()[index]
	var db_entry = ITEM_DB.get(item_name, {})
	var desc: String = str(db_entry.get("desc", "No data available."))
	var type: String = str(db_entry.get("type", "Unknown"))
	_detail_label.text = "[color=#20ff66]%s[/color]\n[color=#aaa]%s[/color]\n\n%s" % [item_name, type, desc]
	_use_label.text = ""


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_top = -220
	panel.offset_right = 320
	panel.offset_bottom = 220
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

	_title_label = Label.new()
	_title_label.text = "INVENTORY"
	_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	_title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(240, 300)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_item_list.add_theme_color_override("font_selected_color", Color(0.2, 1.0, 0.6))
	_item_list.item_clicked.connect(_on_item_clicked)
	hbox.add_child(_item_list)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(detail_vbox)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_detail_label.add_theme_font_size_override("normal_font_size", 16)
	detail_vbox.add_child(_detail_label)

	_use_label = Label.new()
	_use_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.62))
	_use_label.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(_use_label)

	var hint := Label.new()
	hint.text = "TAB close  ↑↓ navigate"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)


func _on_item_clicked(index: int, _at: Vector2, _mouse_btn: int) -> void:
	_selected_index = index
	_show_detail(index)
