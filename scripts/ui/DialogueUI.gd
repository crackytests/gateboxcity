extends Control
class_name DialogueUI
# Daggerfall-style conversation window. Driven entirely by DialogueDB; see
# docs/dialogue_system_plan.md. Built in code to match the other menu UIs
# (JobBoardUI, TravelGateUI, ...). open()/open_statement()/close()/is_open().

signal closed
signal service_requested(npc_id: String, service_id: String)

const TONES := ["polite", "normal", "blunt"]
const TABS := [
	{"id": "tell",     "label": "Tell me about"},
	{"id": "where",    "label": "Where is"},
	{"id": "work",     "label": "Work"},
	{"id": "news",     "label": "Any news?"},
	{"id": "services", "label": "Services"},
	{"id": "goodbye",  "label": "Goodbye"},
]

const NPC_COLOR := "ff7bd6"      # pink
const PLAYER_COLOR := "66e0ff"   # cyan — Spooky Ghost
const PLAYER_NAME := "Spooky Ghost"

var _npc_id := ""
var _statement_mode := false
var _current_tab := "tell"
var _transcript_started := false

var _title_label: Label
var _mood_label: Label
var _transcript: RichTextLabel
var _keyword_box: VBoxContainer
var _tone_buttons: Dictionary = {}   # tone -> Button
var _tab_buttons: Dictionary = {}    # tab id -> Button


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(npc_id: String) -> void:
	_npc_id = npc_id
	_statement_mode = false
	_current_tab = "tell"
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_conversation_controls_visible(true)
	DialogueDB.on_open(npc_id)
	var g := DialogueDB.greeting(npc_id)
	_title_label.text = str(g.get("name", npc_id)).to_upper()
	_set_mood(str(g.get("mood", "")))
	_transcript.clear()
	_transcript_started = false
	_say(str(g.get("name", "")), str(g.get("text", "")))
	_highlight_tone(GameState.conversation_tone)
	_select_tab("tell")


# Plain one-shot line in the same window frame (objects, consoles, barks).
func open_statement(speaker: String, text: String) -> void:
	_statement_mode = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_conversation_controls_visible(false)
	_title_label.text = speaker.to_upper()
	_set_mood("")
	_transcript.clear()
	_transcript_started = false
	_say(speaker, text)


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


# ── Interaction ─────────────────────────────────────────────────────

func _select_tab(tab_id: String) -> void:
	_current_tab = tab_id
	for id: String in _tab_buttons.keys():
		_tab_buttons[id].button_pressed = (id == tab_id)
	match tab_id:
		"goodbye":
			close()
		"news":
			_clear_keywords()
			_say_player("Any news?")
			var r := DialogueDB.rumor(_npc_id)
			_say(str(r.get("name", "")), str(r.get("text", "")))
		"services":
			_show_services()
		_:
			_refresh_keywords()


func _refresh_keywords() -> void:
	_clear_keywords()
	var entries := DialogueDB.category_entries(_npc_id, _current_tab)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "(nothing to ask here)"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_keyword_box.add_child(empty)
		return
	for entry: Dictionary in entries:
		var topic_id := str(entry.get("topic_id", ""))
		var state := str(entry.get("state", "known"))
		var btn := Button.new()
		btn.text = str(entry.get("label", topic_id))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		match state:
			"hint":
				# A "?" cue only — not actionable. Learn the keyword elsewhere, then ask it here.
				btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				btn.disabled = true
				btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.7, 0.28))
				btn.tooltip_text = "You have heard this mentioned but do not know enough to ask. Learn more around the city."
			"shrug":
				btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
				btn.pressed.connect(_on_keyword_pressed.bind(topic_id))
			_:
				btn.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
				btn.pressed.connect(_on_keyword_pressed.bind(topic_id))
		_keyword_box.add_child(btn)


func _on_keyword_pressed(topic_id: String) -> void:
	_say_player(_player_question(topic_id))
	var r := DialogueDB.ask(_npc_id, topic_id)
	_say(str(r.get("name", "")), str(r.get("text", "")))
	# Asking can learn topics / fire effects that change the list and the NPC's mood.
	var g := DialogueDB.greeting(_npc_id)
	_set_mood(str(g.get("mood", "")))
	_refresh_keywords()


func _show_services() -> void:
	_clear_keywords()
	var svc := DialogueDB.services(_npc_id)
	if svc.is_empty():
		var none := Label.new()
		none.text = "(no services offered)"
		none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_keyword_box.add_child(none)
		return
	for service_id: String in svc:
		var btn := Button.new()
		btn.text = _service_label(service_id)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		btn.pressed.connect(_on_service_pressed.bind(service_id))
		_keyword_box.add_child(btn)


func _on_service_pressed(service_id: String) -> void:
	# Hand off to whoever owns the panels for this NPC (the location script, usually).
	service_requested.emit(_npc_id, service_id)
	close()


func _on_tone_pressed(tone: String) -> void:
	DialogueDB.set_tone(_npc_id, tone)
	_highlight_tone(tone)
	var g := DialogueDB.greeting(_npc_id)
	_set_mood(str(g.get("mood", "")))
	if _current_tab not in ["news", "services", "goodbye"]:
		_refresh_keywords()


# ── Presentation helpers ────────────────────────────────────────────

func _say(speaker: String, text: String, color := NPC_COLOR) -> void:
	# RichTextLabel.text does not update on append_text(), so track the separator ourselves.
	if _transcript_started:
		_transcript.append_text("\n\n")
	_transcript_started = true
	_transcript.append_text("[color=#%s]%s:[/color] %s" % [color, speaker, text])


func _say_player(text: String) -> void:
	_say(PLAYER_NAME, text, PLAYER_COLOR)


# Phrase the player's prompt to match the tab the keyword was asked from.
func _player_question(topic_id: String) -> String:
	match _current_tab:
		"work": return "Anything that needs doing?"
		"where": return "Where can I find %s?" % DialogueDB.topic_label(topic_id)
		_: return "Tell me about %s." % DialogueDB.topic_label(topic_id)


func _set_mood(mood: String) -> void:
	_mood_label.text = "" if mood.is_empty() else "( %s )" % mood


func _highlight_tone(active: String) -> void:
	for tone: String in _tone_buttons.keys():
		_tone_buttons[tone].button_pressed = (tone == active)


func _clear_keywords() -> void:
	for child in _keyword_box.get_children():
		child.queue_free()


func _set_conversation_controls_visible(show_topics: bool) -> void:
	# In statement mode only the transcript + Goodbye remain.
	for id: String in _tab_buttons.keys():
		_tab_buttons[id].visible = show_topics or id == "goodbye"
	for tone: String in _tone_buttons.keys():
		_tone_buttons[tone].visible = show_topics
	_keyword_box.visible = show_topics


func _service_label(service_id: String) -> String:
	match service_id:
		"shop": return "Browse goods"
		"sell": return "Sell wasted potential"
		"pharmacy": return "Buy from the pharmacy"
		"job_board": return "Cooters job board"
		"travel": return "Travel"
		"cybernetics": return "Surgical suite"
		_: return service_id.capitalize()


# ── UI construction ─────────────────────────────────────────────────

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_top = -260
	panel.offset_right = 460
	panel.offset_bottom = 260
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Header: NPC name + mood word.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.82))
	_title_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_title_label)
	_mood_label = Label.new()
	_mood_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_mood_label.add_theme_font_size_override("font_size", 16)
	_mood_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mood_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_mood_label)

	# Body: transcript | (tabs + keyword list).
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = true
	_transcript.scroll_following = true
	_transcript.custom_minimum_size = Vector2(520, 0)
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_transcript.add_theme_font_size_override("normal_font_size", 16)
	body.add_child(_transcript)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(300, 0)
	body.add_child(right)

	var tab_grid := GridContainer.new()
	tab_grid.columns = 2
	tab_grid.add_theme_constant_override("h_separation", 6)
	tab_grid.add_theme_constant_override("v_separation", 6)
	right.add_child(tab_grid)
	for tab: Dictionary in TABS:
		var tb := Button.new()
		tb.text = str(tab["label"])
		tb.toggle_mode = true
		tb.pressed.connect(_select_tab.bind(str(tab["id"])))
		tab_grid.add_child(tb)
		_tab_buttons[str(tab["id"])] = tb

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_keyword_box = VBoxContainer.new()
	_keyword_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keyword_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_keyword_box)

	# Footer: tone bar + hint.
	var tone_row := HBoxContainer.new()
	tone_row.add_theme_constant_override("separation", 8)
	root.add_child(tone_row)
	var tone_caption := Label.new()
	tone_caption.text = "Tone:"
	tone_caption.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	tone_row.add_child(tone_caption)
	for tone: String in TONES:
		var btn := Button.new()
		btn.text = tone.capitalize()
		btn.toggle_mode = true
		btn.pressed.connect(_on_tone_pressed.bind(tone))
		tone_row.add_child(btn)
		_tone_buttons[tone] = btn

	var hint := Label.new()
	hint.text = "ESC close    Tone shifts how they take you"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	root.add_child(hint)
