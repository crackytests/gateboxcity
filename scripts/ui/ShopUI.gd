extends Control
class_name ShopUI

## Generic vendor panel. A list of offers, a detail pane, and a BUY button.
## Each offer is a Dictionary:
##   {item, label, desc, price_item, price_count}
## Opened via HUDController.open_shop(vendor_name, offers).

signal closed

var _vendor := "VENDOR"
var _mode := "buy"  # "buy" or "sell"
var _offers: Array = []
var _list: ItemList
var _detail: RichTextLabel
var _buy_button: Button
var _title_label: Label
var _wallet_label: Label


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(vendor_name: String, offers: Array) -> void:
	_mode = "buy"
	_vendor = vendor_name
	_offers = offers
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.text = vendor_name.to_upper()
	_buy_button.text = "BUY"
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Sell mode: the list is built from the player's sellable wasted-potential
## loot. Selling pays Wan Notes and feeds the Dreaming Generator.
func open_sell(vendor_name: String) -> void:
	_mode = "sell"
	_vendor = vendor_name
	_offers = []
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.text = vendor_name.to_upper()
	_buy_button.text = "SELL"
	_refresh()
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
		return
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if not _buy_button.disabled:
			_on_buy_pressed()
		get_viewport().set_input_as_handled()


func _move_selection(dir: int) -> void:
	if _list.item_count == 0:
		return
	var sel := _list.get_selected_items()
	var cur: int = sel[0] if not sel.is_empty() else -1
	var next := clampi(cur + dir, 0, _list.item_count - 1)
	_list.select(next)
	_on_offer_selected(next)


func _refresh() -> void:
	var prev := -1
	var sel := _list.get_selected_items()
	if not sel.is_empty():
		prev = sel[0]

	# Sell mode rebuilds its offers from the player's current loot each refresh.
	if _mode == "sell":
		_offers = GameState.get_sellable_wasted_potential_items()

	_list.clear()
	for offer in _offers:
		if _mode == "sell":
			_list.add_item("%s x%d   (%d Wan)" % [
				str(offer.get("item_name", "?")),
				int(offer.get("count", 1)),
				int(offer.get("wan_notes", 0)),
			])
		else:
			var entry := "%s   (%s)" % [str(offer.get("label", offer.get("item", "?"))), _price_text(offer)]
			if not _can_afford(offer):
				entry += "  [NEED]"
			_list.add_item(entry)

	_wallet_label.text = _wallet_text()

	if _offers.is_empty():
		if _mode == "sell":
			_detail.text = "[color=#6f8f7f]No wasted potential to sell. Bring Gideon mission scrap, failed miracles, broken proofs.[/color]"
		else:
			_detail.text = "[color=#6f8f7f]Nothing for sale right now.[/color]"
		_buy_button.disabled = true
		return
	var restore := prev if prev >= 0 and prev < _list.item_count else 0
	_list.select(restore)
	_on_offer_selected(restore)


func _on_offer_selected(index: int) -> void:
	if index < 0 or index >= _offers.size():
		_buy_button.disabled = true
		return
	var offer: Dictionary = _offers[index]

	if _mode == "sell":
		_detail.text = "[color=#20ff66]%s[/color]  [color=#888]x%d[/color]\n[color=#aaa]Value: %d Wan Notes  |  +%d generator potential[/color]\n\n[color=#9a7a5a]\"%s\"[/color]\n\n[color=#20ff66]ENTER or SELL to trade one to Gideon.[/color]" % [
			str(offer.get("item_name", "?")),
			int(offer.get("count", 1)),
			int(offer.get("wan_notes", 0)),
			int(offer.get("potential", 0)),
			str(offer.get("label", "")),
		]
		_buy_button.disabled = false
		return

	var afford := _can_afford(offer)
	_detail.text = "[color=#20ff66]%s[/color]\n[color=#aaa]Price: %s[/color]\n\n%s" % [
		str(offer.get("label", offer.get("item", "?"))),
		_price_text(offer),
		str(offer.get("desc", "No data.")),
	]
	if afford:
		_detail.text += "\n\n[color=#20ff66]Affordable. ENTER or BUY to purchase.[/color]"
		_buy_button.disabled = false
	else:
		_detail.text += "\n\n[color=#ff5588]You can't cover the tab.[/color]"
		_buy_button.disabled = true


func _on_buy_pressed() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	var index: int = sel[0]
	if index < 0 or index >= _offers.size():
		return
	var offer: Dictionary = _offers[index]

	if _mode == "sell":
		GameState.sell_wasted_potential_item(str(offer.get("item_name", "")))
		_refresh()
		return

	if not _can_afford(offer):
		return
	var price_item := str(offer.get("price_item", ""))
	var price_count := int(offer.get("price_count", 0))
	if price_count > 0 and not price_item.is_empty():
		if not GameState.spend_item(price_item, price_count):
			return
	GameState.add_item(str(offer.get("item", "")), int(offer.get("count", 1)))
	_refresh()


func _can_afford(offer: Dictionary) -> bool:
	var price_item := str(offer.get("price_item", ""))
	var price_count := int(offer.get("price_count", 0))
	if price_item.is_empty() or price_count <= 0:
		return true
	return GameState.has_item(price_item, price_count)


func _price_text(offer: Dictionary) -> String:
	var price_item := str(offer.get("price_item", ""))
	var price_count := int(offer.get("price_count", 0))
	if price_item.is_empty() or price_count <= 0:
		return "free"
	return "%d x %s" % [price_count, price_item]


func _wallet_text() -> String:
	var wan := GameState.get_wan_notes()
	var credit := int(GameState.items.get("Cooters Bar Credit", 0))
	var base := "WALLET   %d Wan Note   %d Cooters Bar Credit" % [wan, credit]
	if _mode == "sell":
		base += "    GENERATOR  %d/%d" % [
			GameState.get_dreaming_generator_potential(),
			GameState.DREAMING_GENERATOR_THRESHOLD,
		]
	return base


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_top = -245
	panel.offset_right = 420
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

	_title_label = Label.new()
	_title_label.text = "VENDOR"
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.82))
	_title_label.add_theme_font_size_override("font_size", 23)
	vbox.add_child(_title_label)

	_wallet_label = Label.new()
	_wallet_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.52))
	_wallet_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_wallet_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(300, 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_list.add_theme_color_override("font_selected_color", Color(0.2, 1.0, 0.6))
	_list.item_selected.connect(_on_offer_selected)
	hbox.add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_detail.add_theme_font_size_override("normal_font_size", 16)
	hbox.add_child(_detail)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 10)
	vbox.add_child(button_row)

	_buy_button = Button.new()
	_buy_button.text = "BUY"
	_buy_button.disabled = true
	_buy_button.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	_buy_button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_buy_button.pressed.connect(_on_buy_pressed)
	button_row.add_child(_buy_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(close)
	button_row.add_child(close_button)

	var hint := Label.new()
	hint.text = "ESC close   ↑↓ navigate   ENTER buy"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)
