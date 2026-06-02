extends Control
class_name GhostTermUI

## GhostTerm — Spooky Ghost's wrist terminal.
## A single tabbed overlay (Pip-Boy style) that unifies stats, inventory,
## quest data, world/faction state, and a rolling log.
## Built entirely in code to match the existing InventoryUI / CyberneticSurgeryUI pattern.
## Reads live game data from the GameState and WorldDirector autoloads.

signal closed
signal upgrade_installed(upgrade_id: String)

const TAB_STAT := 0
const TAB_INV := 1
const TAB_DATA := 2
const TAB_WORLD := 3
const TAB_LOGS := 4
const TAB_WARE := 5

const TAB_NAMES := {
	"stat": TAB_STAT,
	"inv": TAB_INV,
	"data": TAB_DATA,
	"world": TAB_WORLD,
	"logs": TAB_LOGS,
	"ware": TAB_WARE,
}

# Phosphor palette
const COL_PRIMARY := Color(0.2, 1.0, 0.6)
const COL_DIM := Color(0.55, 0.8, 0.6)
const COL_HEADER := Color(0.65, 0.95, 1.0)
const COL_DANGER := Color(1.0, 0.22, 0.82)
const COL_WARN := Color(1.0, 0.7, 0.3)
const COL_BG := Color(0.04, 0.06, 0.04)

# Category -> bbcode color for the inventory tab
const CATEGORY_COLORS := {
	"Currency": "#ffd24a",
	"Protection": "#5fd2ff",
	"Consumable": "#33ff88",
	"Salvage": "#ff9a3a",
	"Permit": "#ff9a3a",
	"Access": "#ff5fc8",
	"Key": "#ff5fc8",
	"Document": "#cfcfcf",
	"Currency ": "#ffd24a",
}

var _tabs: TabContainer
var _title_label: Label
var _status_label: Label

var _stat_rt: RichTextLabel
var _data_rt: RichTextLabel
var _world_rt: RichTextLabel
var _logs_rt: RichTextLabel

var _inv_list: ItemList
var _inv_detail: RichTextLabel
var _inv_use_btn: Button
var _inv_keys: Array = []

# WARE tab
var _ware_available: Array[Dictionary] = []
var _ware_slots_rt: RichTextLabel
var _ware_detail: RichTextLabel
var _ware_list: ItemList
var _ware_install_btn: Button
# Install only happens at Velvet Coil's table (paid in Wan Notes). The player's own GhostTerm
# WARE tab is a read-only viewer of what they're carrying / have installed.
var _ware_install_mode := false

var _hp := 0.0
var _max_hp := 0.0
var _log_history: Array[String] = []


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(tab: String = "inv") -> void:
	# Self-opened terminal: WARE tab is a viewer. Show what the player is carrying; no install.
	_ware_install_mode = false
	_ware_available = _owned_implants()
	visible = true
	var idx: int = int(TAB_NAMES.get(tab, TAB_INV))
	_tabs.current_tab = idx
	refresh_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Open the WARE tab at Velvet Coil's table: lists implants the player is carrying and lets
## them be installed for Wan Notes. (install_mode=false would make it a viewer.)
func open_ware(install_mode := true) -> void:
	_ware_install_mode = install_mode
	_ware_available = _owned_implants()
	if not visible:
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_all()
	_set_tab(TAB_WARE)


# Implants the player is carrying (dropped from enemies) that aren't already installed.
func _owned_implants() -> Array[Dictionary]:
	var owned: Array[Dictionary] = []
	for item_name in GameState.items.keys():
		var id := str(item_name)
		if CyberneticSurgeryUI.UPGRADE_DB.has(id) and not GameState.has_cybernetic(id):
			owned.append({"id": id})
	return owned


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return visible


func set_vitals(current_hp: float, max_hp: float) -> void:
	_hp = current_hp
	_max_hp = max_hp
	if visible and _tabs.current_tab == TAB_STAT:
		_refresh_stat()


func add_log(message: String) -> void:
	if message.strip_edges().is_empty():
		return
	_log_history.append(message)
	if _log_history.size() > 30:
		_log_history = _log_history.slice(_log_history.size() - 30)
	if visible and _tabs.current_tab == TAB_LOGS:
		_refresh_logs()


func refresh_all() -> void:
	_refresh_header()
	_refresh_stat()
	_refresh_inv()
	_refresh_data()
	_refresh_world()
	_refresh_logs()
	_refresh_ware()


# ── Input ───────────────────────────────────────────────────────────

# _input fires before GUI elements consume the event, so ESC/TAB always close
# the panel even when the ItemList or Install button has keyboard focus.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				_set_tab(TAB_STAT)
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_tab(TAB_INV)
				get_viewport().set_input_as_handled()
			KEY_3:
				_set_tab(TAB_DATA)
				get_viewport().set_input_as_handled()
			KEY_4:
				_set_tab(TAB_WORLD)
				get_viewport().set_input_as_handled()
			KEY_5:
				_set_tab(TAB_LOGS)
				get_viewport().set_input_as_handled()
			KEY_6:
				_set_tab(TAB_WARE)
				get_viewport().set_input_as_handled()
			KEY_Q:
				_cycle_tab(-1)
				get_viewport().set_input_as_handled()
			KEY_E:
				_cycle_tab(1)
				get_viewport().set_input_as_handled()
	# Inventory list navigation
	if _tabs.current_tab == TAB_INV:
		if event.is_action_pressed("ui_down"):
			_move_inv_selection(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_move_inv_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if _inv_use_btn != null and _inv_use_btn.visible and not _inv_use_btn.disabled:
				_on_inv_use_pressed()
			get_viewport().set_input_as_handled()
	# Ware list navigation
	if _tabs.current_tab == TAB_WARE:
		if event.is_action_pressed("ui_down"):
			_move_ware_selection(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_move_ware_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if _ware_install_btn != null and not _ware_install_btn.disabled:
				_on_ware_install_pressed()
			get_viewport().set_input_as_handled()


func _set_tab(idx: int) -> void:
	_tabs.current_tab = idx
	_on_tab_changed(idx)


func _cycle_tab(dir: int) -> void:
	_set_tab(wrapi(_tabs.current_tab + dir, 0, _tabs.get_tab_count()))


func _on_tab_changed(idx: int) -> void:
	match idx:
		TAB_STAT: _refresh_stat()
		TAB_INV: _refresh_inv()
		TAB_DATA: _refresh_data()
		TAB_WORLD: _refresh_world()
		TAB_LOGS: _refresh_logs()
		TAB_WARE: _refresh_ware()


# ── Tab content: STAT ───────────────────────────────────────────────

func _refresh_header() -> void:
	_status_label.text = "SPOOKY GHOST    SOUL ANCHOR: %s" % _soul_anchor_status()


func _soul_anchor_status() -> String:
	var rot := _safe_int("soul_rot", 0)
	if rot >= 80:
		return "CRITICAL"
	if rot >= 60:
		return "LEAKING"
	if rot >= 40:
		return "STRESSED"
	return "STABLE"


func _refresh_stat() -> void:
	if _stat_rt == null:
		return
	var lines: Array[String] = []
	var dg_pot := GameState.get_dreaming_generator_potential()
	var dg_max := int(GameState.DREAMING_GENERATOR_MAX_POTENTIAL)
	var rot := _safe_int("soul_rot", 0)

	lines.append("[color=#a6f5c8][b]VITALS[/b][/color]")
	lines.append("BODY INTEGRITY   %s  %d/%d" % [_bar(int(_hp), int(maxf(_max_hp, 1.0)), 12, "#5fd2ff"), int(_hp), int(_max_hp)])
	lines.append("DREAMING GEN     %s  %d/%d" % [_bar(dg_pot, dg_max, 12, "#33ff88"), dg_pot, dg_max])
	lines.append("SOUL ROT         %s  %d/100  [color=#ff5fc8]%s[/color]" % [_bar(rot, 100, 12, "#ff5fc8"), rot, _soul_anchor_status()])
	var drift_val := _safe_int("drift", 0)
	var drift_max := int(GameState.get("DRIFT_MAX") if GameState.get("DRIFT_MAX") != null else 100)
	var drift_desc := str(GameState.get_drift_descriptor()) if GameState.has_method("get_drift_descriptor") else ""
	lines.append("DRIFT            %s  %d/%d  [color=#ff66cc]%s[/color]" % [_bar(drift_val, drift_max, 12, "#ff66cc"), drift_val, drift_max, drift_desc])
	lines.append("")

	lines.append("[color=#a6f5c8][b]CYBERNETICS[/b][/color]  %s" % _cyber_slot_count())
	var slot_map := _installed_by_slot()
	for slot_name in CyberneticSurgeryUI.BODY_SLOTS:
		var installed_id: String = str(slot_map.get(slot_name, ""))
		if installed_id.is_empty():
			lines.append("  [color=#3f5f4f]%-10s[/color] [color=#3f5f4f]— empty —[/color]" % slot_name)
		else:
			var db: Dictionary = CyberneticSurgeryUI.UPGRADE_DB.get(installed_id, {})
			lines.append("  [color=#9bd6b3]%-10s[/color] [color=#20ff66]%s[/color]" % [slot_name, str(db.get("name", installed_id))])
	lines.append("")

	lines.append("[color=#a6f5c8][b]ATTRIBUTES[/b][/color]")
	var attrs: Variant = GameState.get("attributes")
	if typeof(attrs) == TYPE_DICTIONARY and not (attrs as Dictionary).is_empty():
		var a := attrs as Dictionary
		lines.append("  MEAT   STR %d  AGL %d  CON %d" % [int(a.get("STR", 0)), int(a.get("AGL", 0)), int(a.get("CON", 0))])
		lines.append("  MIND   INT %d  PER %d  WIL %d" % [int(a.get("INT", 0)), int(a.get("PER", 0)), int(a.get("WIL", 0))])
		lines.append("  SOUL   EMP %d  LCK %d" % [int(a.get("EMP", 0)), int(a.get("LUCK", 0))])
	else:
		lines.append("  [color=#6f8f7f]— attribute matrix calibrating (Phase 2) —[/color]")

	_stat_rt.text = "\n".join(lines)


func _cyber_slot_count() -> String:
	var filled := 0
	for upgrade_id in GameState.cybernetics.keys():
		if bool(GameState.cybernetics[upgrade_id]):
			filled += 1
	return "(%d/%d slots)" % [filled, CyberneticSurgeryUI.BODY_SLOTS.size()]


func _installed_by_slot() -> Dictionary:
	var result := {}
	for upgrade_id in GameState.cybernetics.keys():
		if not bool(GameState.cybernetics[upgrade_id]):
			continue
		var db: Dictionary = CyberneticSurgeryUI.UPGRADE_DB.get(str(upgrade_id), {})
		var slot := str(db.get("slot", ""))
		if not slot.is_empty():
			result[slot] = str(upgrade_id)
	return result


# ── Tab content: INV ────────────────────────────────────────────────

func _refresh_inv() -> void:
	if _inv_list == null:
		return
	var prev := _inv_list.get_selected_items()
	var prev_idx: int = prev[0] if not prev.is_empty() else 0
	_inv_list.clear()
	_inv_keys.clear()

	if GameState.items.is_empty():
		_inv_detail.text = "[color=#6f8f7f]Inventory empty. The Sub-Sub-Basement gives nothing away for free.[/color]"
		if _inv_use_btn != null:
			_inv_use_btn.visible = false
		return

	# Group items by category for readability
	var grouped := {}
	for item_name in GameState.items.keys():
		if int(GameState.items[item_name]) <= 0:
			continue
		var cat := _category_of(str(item_name))
		if not grouped.has(cat):
			grouped[cat] = []
		grouped[cat].append(str(item_name))

	var cat_order := ["Currency", "Protection", "Consumable", "Access", "Key", "Permit", "Salvage", "Document", "Mission", "Misc"]
	for cat in cat_order:
		if not grouped.has(cat):
			continue
		var color: String = str(CATEGORY_COLORS.get(cat, "#cfcfcf"))
		_inv_list.add_item("— %s —" % cat.to_upper())
		var hdr_idx := _inv_list.item_count - 1
		_inv_list.set_item_selectable(hdr_idx, false)
		_inv_list.set_item_custom_fg_color(hdr_idx, Color.from_string(color, Color.GRAY))
		_inv_keys.append("")  # header placeholder keeps index alignment
		for item_name in grouped[cat]:
			var count := int(GameState.items[item_name])
			var entry: String = ("  %s x%d" % [item_name, count]) if count > 1 else ("  %s" % item_name)
			_inv_list.add_item(entry)
			_inv_keys.append(str(item_name))

	# Restore / clamp selection to a selectable row
	var sel := clampi(prev_idx, 0, maxi(_inv_list.item_count - 1, 0))
	sel = _next_selectable(sel, 1)
	if sel >= 0:
		_inv_list.select(sel)
		_show_inv_detail(sel)


func _next_selectable(start: int, dir: int) -> int:
	var i := start
	var guard := 0
	while i >= 0 and i < _inv_list.item_count and guard < _inv_list.item_count:
		if _inv_list.is_item_selectable(i):
			return i
		i += dir
		guard += 1
	# wrap search from the other end
	i = 0 if dir > 0 else _inv_list.item_count - 1
	guard = 0
	while i >= 0 and i < _inv_list.item_count and guard < _inv_list.item_count:
		if _inv_list.is_item_selectable(i):
			return i
		i += dir
		guard += 1
	return -1


func _move_inv_selection(dir: int) -> void:
	if _inv_list.item_count == 0:
		return
	var cur := _inv_list.get_selected_items()
	var idx: int = cur[0] if not cur.is_empty() else 0
	var next := _next_selectable(wrapi(idx + dir, 0, _inv_list.item_count), dir)
	if next >= 0:
		_inv_list.select(next)
		_inv_list.ensure_current_is_visible()
		_show_inv_detail(next)


func _show_inv_detail(index: int) -> void:
	if index < 0 or index >= _inv_keys.size():
		return
	var item_name := str(_inv_keys[index])
	if item_name.is_empty():
		return
	var db: Dictionary = InventoryUI.ITEM_DB.get(item_name, {})
	var desc := str(db.get("desc", "No data available. Acquired under unclear circumstances."))
	var type := str(db.get("type", _category_of(item_name)))
	var count := int(GameState.items.get(item_name, 0))
	var detail := "[color=#20ff66][b]%s[/b][/color]  [color=#888]x%d[/color]\n[color=#aaa]%s[/color]\n\n%s" % [item_name, count, type, desc]

	var wp: Dictionary = GameState.get_wasted_potential_value(item_name)
	if not wp.is_empty():
		detail += "\n\n[color=#ff9a3a]WASTED POTENTIAL[/color]  %d soul / %d Wan\n[color=#9a7a5a]\"%s\"[/color]" % [
			int(wp.get("potential", 0)), int(wp.get("wan_notes", 0)), str(wp.get("label", ""))
		]

	# Consumables get a USE action.
	if _inv_use_btn != null:
		if GameState.is_consumable(item_name) and count > 0:
			_inv_use_btn.visible = true
			_inv_use_btn.disabled = false
			_inv_use_btn.text = "USE  %s" % item_name
			detail += "\n\n[color=#33ff88]Press ENTER or click USE to consume.[/color]"
		else:
			_inv_use_btn.visible = false
	_inv_detail.text = detail


func _on_inv_use_pressed() -> void:
	var sel := _inv_list.get_selected_items()
	if sel.is_empty():
		return
	var idx: int = sel[0]
	if idx < 0 or idx >= _inv_keys.size():
		return
	var item_name := str(_inv_keys[idx])
	if item_name.is_empty() or not GameState.is_consumable(item_name):
		return
	var result := GameState.use_consumable(item_name)
	if result.is_empty():
		return
	# Inventory contents changed — rebuild the list and reselect a sane row.
	_refresh_inv()


func _category_of(item_name: String) -> String:
	var db: Dictionary = InventoryUI.ITEM_DB.get(item_name, {})
	var type := str(db.get("type", ""))
	match type:
		"Currency": return "Currency"
		"Protection": return "Protection"
		"Consumable": return "Consumable"
		"Access": return "Access"
		"Permit": return "Permit"
		"Salvage": return "Salvage"
		"Document": return "Document"
	# Fallback heuristics for mission/objective items not in ITEM_DB
	if GameState.WASTED_POTENTIAL_VALUES.has(item_name):
		return "Salvage"
	return "Mission"


func _on_inv_item_clicked(index: int, _at: Vector2, _btn: int) -> void:
	if index >= 0 and index < _inv_list.item_count and _inv_list.is_item_selectable(index):
		_show_inv_detail(index)


# ── Tab content: DATA (quest log) ───────────────────────────────────

func _refresh_data() -> void:
	if _data_rt == null:
		return
	var lines: Array[String] = []

	lines.append("[color=#a6f5c8][b]CAMPAIGN[/b][/color]")
	if GameState.is_quest_started("wake_up_call"):
		lines.append("  [color=#b8ffd0]Wake-Up Call[/color]  %s" % _quest_state_tag("wake_up_call"))
		lines.append("  [color=#9bd6b3]> %s[/color]" % GameState.get_quest_objective_text("wake_up_call"))
	else:
		lines.append("  [color=#9bd6b3]> Objective: talk to System X.[/color]")
	lines.append("")

	var hub_quests := GameState.get_active_hub_quests()
	lines.append("[color=#a6f5c8][b]HUB PROJECTS[/b][/color]  (%d active)" % hub_quests.size())
	if hub_quests.is_empty():
		lines.append("  [color=#6f8f7f]> No hub projects active.[/color]")
	else:
		for q in hub_quests:
			lines.append("  [color=#b8ffd0]%s[/color]" % str((q as Dictionary).get("title", "")))
			lines.append("  [color=#9bd6b3]> %s[/color]" % str((q as Dictionary).get("objective_text", "")))
	lines.append("")

	lines.append("[color=#a6f5c8][b]COOTERS JOBS[/b][/color]")
	var active_job := GameState.get_active_job_data()
	if not active_job.is_empty():
		lines.append("  [color=#ffd24a]ACTIVE:[/color] [color=#b8ffd0]%s[/color]" % str(active_job.get("title", "")))
		lines.append("  [color=#9bd6b3]> %s[/color]" % GameState.get_active_job_objective_text())
	else:
		lines.append("  [color=#6f8f7f]No active job. Visit Marbles at Cooters.[/color]")

	var avail: Array = []
	for inst in GameState.board_instances:
		var jid := str((inst as Dictionary).get("id", ""))
		if active_job.is_empty() or str(active_job.get("id", "")) != jid:
			avail.append("%s — %s" % [str((inst as Dictionary).get("title", jid)), str((inst as Dictionary).get("giver", ""))])
	if not avail.is_empty():
		lines.append("  [color=#88c0a0]On the Cooters board:[/color] %s" % ", ".join(avail))
	else:
		lines.append("  [color=#6f8f7f]Board not seen yet — visit Marbles at Cooters.[/color]")

	_data_rt.text = "\n".join(lines)


func _quest_state_tag(quest_id: String) -> String:
	if GameState.is_quest_completed(quest_id):
		return "[color=#5f8f6f][complete][/color]"
	return "[color=#ffd24a][in progress][/color]"


# ── Tab content: WORLD ──────────────────────────────────────────────

func _refresh_world() -> void:
	if _world_rt == null:
		return
	var lines: Array[String] = []

	lines.append("[color=#a6f5c8][b]REGION[/b][/color]")
	lines.append("  %s" % WorldDirector.get_region_name())
	lines.append("  [color=#9bd6b3]%s[/color]" % WorldDirector.get_region_brief())
	lines.append("  SKY  %s    GENERATOR  %s" % [WorldDirector.get_event_name(), WorldDirector.get_generator_state()])
	lines.append("")

	lines.append("[color=#a6f5c8][b]FACTION STANDING[/b][/color]")
	var fac_order := ["System X", "Gatebox Corporation", "Wan Moa Torai", "Linda"]
	for fac in fac_order:
		var rep := int(GameState.reputation.get(fac, 0))
		var stance := str(WorldDirector.FACTIONS.get(fac, {}).get("stance", ""))
		lines.append("  %-16s %s  [color=#ffd24a]%+d[/color]" % [fac, _signed_bar(rep, 8, 8), rep])
		lines.append("    [color=#6f8f7f]%s[/color]" % stance)
	lines.append("")

	lines.append("[color=#a6f5c8][b]HUB DEVELOPMENT[/b][/color]")
	var tracks: Variant = GameState.get("hub_tracks")
	if typeof(tracks) == TYPE_DICTIONARY and not (tracks as Dictionary).is_empty():
		var t := tracks as Dictionary
		lines.append("  POWER    %s  %d" % [_bar(int(t.get("power", 0)), 100, 10, "#ffd24a"), int(t.get("power", 0))])
		lines.append("  WATER    %s  %d" % [_bar(int(t.get("water", 0)), 100, 10, "#5fd2ff"), int(t.get("water", 0))])
		lines.append("  CULTURE  %s  %d" % [_bar(int(t.get("culture", 0)), 100, 10, "#ff5fc8"), int(t.get("culture", 0))])
		lines.append("  DEFENSE  %s  %d" % [_bar(int(t.get("defense", 0)), 100, 10, "#33ff88"), int(t.get("defense", 0))])
	else:
		# Phase 3 not built yet — derive a rough status from existing world flags
		lines.append("  POWER    %s" % _flag_status("hub_power_restored", "restored", "offline"))
		lines.append("  WATER    %s" % _flag_status("hub_cistern_connected", "connected", "unconnected"))
		lines.append("  CULTURE  %s" % _flag_status("coil_invitation_accepted", "broadcasting", "silent"))
		lines.append("  DEFENSE  [color=#6f8f7f]unbuilt (Phase 3)[/color]")

	_world_rt.text = "\n".join(lines)


func _flag_status(flag: String, on_text: String, off_text: String) -> String:
	if bool(GameState.get_world_flag(flag)):
		return "[color=#33ff88]%s[/color]" % on_text
	return "[color=#6f8f7f]%s[/color]" % off_text


# ── Tab content: LOGS ───────────────────────────────────────────────

func _refresh_logs() -> void:
	if _logs_rt == null:
		return
	if _log_history.is_empty():
		_logs_rt.text = "[color=#6f8f7f]> connection established[/color]"
		return
	var lines: Array[String] = []
	for entry in _log_history:
		lines.append("[color=#9bd6b3]> %s[/color]" % entry)
	_logs_rt.text = "\n".join(lines)
	# Scroll to bottom
	_logs_rt.scroll_to_line(maxi(_logs_rt.get_line_count() - 1, 0))


# ── Formatting helpers ──────────────────────────────────────────────

func _bar(value: int, maxv: int, width: int, color: String) -> String:
	var ratio := 0.0
	if maxv > 0:
		ratio = clampf(float(value) / float(maxv), 0.0, 1.0)
	var filled := int(round(ratio * width))
	var empty := width - filled
	return "[color=%s]%s[/color][color=#2a3a2f]%s[/color]" % [color, "█".repeat(filled), "░".repeat(empty)]


func _signed_bar(value: int, span: int, width: int) -> String:
	# Centered bar: negative fills left of center, positive fills right.
	var half := width / 2
	var v := clampi(value, -span, span)
	var units := 0
	if span > 0:
		units = int(round(abs(float(v)) / float(span) * float(half)))
	if v >= 0:
		var pos := "█".repeat(units) + "░".repeat(half - units)
		return "[color=#2a3a2f]%s[/color][color=#33ff88]%s[/color]" % ["░".repeat(half), pos]
	else:
		var neg := "░".repeat(half - units) + "█".repeat(units)
		return "[color=#ff5fc8]%s[/color][color=#2a3a2f]%s[/color]" % [neg, "░".repeat(half)]


func _safe_int(prop: String, default_value: int) -> int:
	var v: Variant = GameState.get(prop)
	if v == null:
		return default_value
	return int(v)


# ── UI construction ─────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_top = -300
	panel.offset_right = 440
	panel.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_PRIMARY
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sb)
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

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "GHOSTTERM"
	_title_label.add_theme_color_override("font_color", COL_PRIMARY)
	_title_label.add_theme_font_size_override("font_size", 24)
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_status_label = Label.new()
	_status_label.text = "SPOOKY GHOST    SOUL ANCHOR: STABLE"
	_status_label.add_theme_color_override("font_color", COL_HEADER)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_status_label)

	# Tab container
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_color_override("font_selected_color", COL_PRIMARY)
	_tabs.add_theme_color_override("font_unselected_color", COL_DIM)
	_tabs.tab_changed.connect(_on_tab_changed)
	vbox.add_child(_tabs)

	_build_stat_tab()
	_build_inv_tab()
	_build_data_tab()
	_build_world_tab()
	_build_logs_tab()
	_build_ware_tab()

	var hint := Label.new()
	hint.text = "TAB / ESC close      1-6 jump      Q / E cycle tabs      ↑↓ navigate      ENTER install"
	hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.48))
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)


func _make_scroll_rt() -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = true
	rt.fit_content = false
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_color_override("default_color", Color(0.85, 1.0, 0.9))
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.add_theme_font_size_override("bold_font_size", 15)
	return rt


func _build_stat_tab() -> void:
	_stat_rt = _make_scroll_rt()
	_stat_rt.name = "STAT"
	_tabs.add_child(_stat_rt)


func _build_inv_tab() -> void:
	var root := HBoxContainer.new()
	root.name = "INV"
	root.add_theme_constant_override("separation", 14)
	_tabs.add_child(root)

	_inv_list = ItemList.new()
	_inv_list.custom_minimum_size = Vector2(300, 0)
	_inv_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_list.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_inv_list.add_theme_color_override("font_selected_color", COL_PRIMARY)
	_inv_list.item_clicked.connect(_on_inv_item_clicked)
	root.add_child(_inv_list)

	var detail_col := VBoxContainer.new()
	detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_col.add_theme_constant_override("separation", 8)
	root.add_child(detail_col)

	_inv_detail = RichTextLabel.new()
	_inv_detail.bbcode_enabled = true
	_inv_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_detail.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_inv_detail.add_theme_font_size_override("normal_font_size", 15)
	detail_col.add_child(_inv_detail)

	_inv_use_btn = Button.new()
	_inv_use_btn.text = "USE"
	_inv_use_btn.visible = false
	_inv_use_btn.add_theme_color_override("font_color", COL_PRIMARY)
	_inv_use_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_inv_use_btn.add_theme_font_size_override("font_size", 16)
	_inv_use_btn.pressed.connect(_on_inv_use_pressed)
	detail_col.add_child(_inv_use_btn)


func _build_data_tab() -> void:
	_data_rt = _make_scroll_rt()
	_data_rt.name = "DATA"
	_tabs.add_child(_data_rt)


func _build_world_tab() -> void:
	_world_rt = _make_scroll_rt()
	_world_rt.name = "WORLD"
	_tabs.add_child(_world_rt)


func _build_logs_tab() -> void:
	_logs_rt = _make_scroll_rt()
	_logs_rt.name = "LOGS"
	_tabs.add_child(_logs_rt)


# ── Tab content: WARE ───────────────────────────────────────────────

func _build_ware_tab() -> void:
	var root := HBoxContainer.new()
	root.name = "WARE"
	root.add_theme_constant_override("separation", 14)
	_tabs.add_child(root)

	# Left: body slot schematic
	_ware_slots_rt = RichTextLabel.new()
	_ware_slots_rt.bbcode_enabled = true
	_ware_slots_rt.custom_minimum_size = Vector2(230, 0)
	_ware_slots_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ware_slots_rt.add_theme_color_override("default_color", Color(0.85, 1.0, 0.9))
	_ware_slots_rt.add_theme_font_size_override("normal_font_size", 14)
	root.add_child(_ware_slots_rt)

	# Center: implant detail
	_ware_detail = RichTextLabel.new()
	_ware_detail.bbcode_enabled = true
	_ware_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ware_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ware_detail.add_theme_color_override("default_color", Color(0.9, 1.0, 0.94))
	_ware_detail.add_theme_font_size_override("normal_font_size", 15)
	root.add_child(_ware_detail)

	# Right: available list + install button
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(210, 0)
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	var avail_hdr := Label.new()
	avail_hdr.text = "AVAILABLE"
	avail_hdr.add_theme_color_override("font_color", COL_PRIMARY)
	avail_hdr.add_theme_font_size_override("font_size", 13)
	right.add_child(avail_hdr)

	_ware_list = ItemList.new()
	_ware_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ware_list.add_theme_color_override("font_color", COL_HEADER)
	_ware_list.add_theme_color_override("font_selected_color", COL_PRIMARY)
	_ware_list.add_theme_font_size_override("font_size", 14)
	_ware_list.item_selected.connect(_on_ware_item_selected)
	right.add_child(_ware_list)

	_ware_install_btn = Button.new()
	_ware_install_btn.text = "INSTALL"
	_ware_install_btn.disabled = true
	_ware_install_btn.add_theme_color_override("font_color", COL_PRIMARY)
	_ware_install_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_ware_install_btn.add_theme_font_size_override("font_size", 15)
	_ware_install_btn.pressed.connect(_on_ware_install_pressed)
	right.add_child(_ware_install_btn)


func _refresh_ware() -> void:
	if _ware_slots_rt == null:
		return
	# Always reflect what the player is currently carrying (drops, post-install consumption).
	_ware_available = _owned_implants()

	# ── Left: body slot schematic ─────────────────────────────────
	var slot_lines: Array[String] = []
	slot_lines.append("[color=#a6f5c8][b]BODY SLOTS[/b][/color]")
	var installed_cyb := GameState.cybernetics
	for slot_name in CyberneticSurgeryUI.BODY_SLOTS:
		var found_id := ""
		for uid in installed_cyb.keys():
			if not bool(installed_cyb[uid]):
				continue
			if not CyberneticSurgeryUI.UPGRADE_DB.has(uid):
				continue
			var sdb: Dictionary = CyberneticSurgeryUI.UPGRADE_DB[uid]
			if str(sdb.get("slot", "")) == slot_name:
				found_id = uid
				break
		if found_id.is_empty():
			slot_lines.append("  [color=#3f5f4f]%-11s[/color]  [color=#3f5f4f]— empty[/color]" % slot_name)
		else:
			var fdb: Dictionary = CyberneticSurgeryUI.UPGRADE_DB[found_id]
			slot_lines.append("  [color=#9bd6b3]%-11s[/color]  [color=#20ff66]%s[/color]" % [slot_name, str(fdb.get("name", found_id))])
	_ware_slots_rt.text = "\n".join(slot_lines)

	# ── Right: available implant list ─────────────────────────────
	var prev_sel := -1
	var sel_items := _ware_list.get_selected_items()
	if not sel_items.is_empty():
		prev_sel = sel_items[0]

	_ware_list.clear()
	for upgrade in _ware_available:
		var uid := str(upgrade.get("id", ""))
		var udb: Dictionary = CyberneticSurgeryUI.UPGRADE_DB.get(uid, {})
		var display := str(udb.get("name", uid))
		if GameState.has_cybernetic(uid):
			display += "  [INSTALLED]"
		elif _ware_req_reason(udb) != "":
			display += "  [LOCKED]"
		elif _ware_install_mode and not _ware_can_pay(uid):
			display += "  [NEED %d WAN]" % GameState.implant_install_price(uid)
		_ware_list.add_item(display)

	# Restore selection or prompt
	if prev_sel >= 0 and prev_sel < _ware_list.item_count:
		_ware_list.select(prev_sel)
		_on_ware_item_selected(prev_sel)
	elif _ware_available.is_empty():
		_ware_detail.text = "[color=#6599aa]No implants in your kit. Cyberware drops from the things you put down; bring it here to Velvet Coil.[/color]"
		_ware_install_btn.disabled = true
	else:
		if _ware_install_mode:
			_ware_detail.text = "[color=#6599aa]Select an implant to install.\n\n↑↓ navigate   ENTER to install[/color]"
		else:
			_ware_detail.text = "[color=#6599aa]Implants you are carrying. Take them to Velvet Coil's table to have them installed.[/color]"
		_ware_install_btn.disabled = true
	_ware_install_btn.visible = _ware_install_mode


func _on_ware_item_selected(index: int) -> void:
	if index < 0 or index >= _ware_available.size():
		_ware_install_btn.disabled = true
		return
	var uid := str(_ware_available[index].get("id", ""))
	var db: Dictionary = CyberneticSurgeryUI.UPGRADE_DB.get(uid, {})
	var slot_name := str(db.get("slot", "?"))
	var already := GameState.has_cybernetic(uid)
	var slot_occ := _ware_find_slot(slot_name) != ""
	var can_pay := _ware_can_pay(uid)
	var req := _ware_req_reason(db)
	var price := GameState.implant_install_price(uid)
	var drift_raw := int(db.get("drift", 0))
	var drift_eff := _ware_effective_drift(drift_raw)
	var drift_tag := ""
	if drift_raw > 0:
		if drift_eff < drift_raw:
			drift_tag = "  |  [color=#ff66cc]Drift +%d[/color] [color=#888](was +%d, Spine Relay)[/color]" % [drift_eff, drift_raw]
		else:
			drift_tag = "  |  [color=#ff66cc]Drift +%d[/color]" % drift_eff

	_ware_detail.text = "[color=#20ff66]%s[/color]\n[color=#aaa]Slot: %s  |  Install: %d Wan Notes%s[/color]\n\n%s" % [
		str(db.get("name", uid)),
		slot_name,
		price,
		drift_tag,
		str(db.get("desc", "No data.")),
	]
	_ware_install_btn.visible = _ware_install_mode
	if not _ware_install_mode:
		_ware_detail.text += "\n\n[color=#6599aa]Carried. Take it to Velvet Coil to install.[/color]"
		_ware_install_btn.disabled = true
	elif already:
		_ware_detail.text += "\n\n[color=#ff5588]Already installed.[/color]"
		_ware_install_btn.disabled = true
	elif slot_occ:
		_ware_detail.text += "\n\n[color=#ffaa44]Slot %s is occupied.[/color]" % slot_name
		_ware_install_btn.disabled = true
	elif req != "":
		_ware_detail.text += "\n\n[color=#ff5588]Locked: %s[/color]" % req
		_ware_install_btn.disabled = true
	elif not can_pay:
		_ware_detail.text += "\n\n[color=#ff5588]Not enough Wan Notes (need %d).[/color]" % price
		_ware_install_btn.disabled = true
	else:
		_ware_detail.text += "\n\n[color=#20ff66]Ready. Coil installs for %d Wan Notes.[/color]" % price
		_ware_install_btn.disabled = false


func _on_ware_install_pressed() -> void:
	if not _ware_install_mode:
		return   # installs only happen at Velvet Coil's table
	if _ware_list.get_selected_items().is_empty():
		return
	var index: int = _ware_list.get_selected_items()[0]
	if index < 0 or index >= _ware_available.size():
		return
	var uid := str(_ware_available[index].get("id", ""))
	if uid.is_empty() or GameState.has_cybernetic(uid):
		return
	var db: Dictionary = CyberneticSurgeryUI.UPGRADE_DB.get(uid, {})
	var slot_name := str(db.get("slot", ""))
	if _ware_find_slot(slot_name) != "":
		return
	if _ware_req_reason(db) != "":
		return
	if not _ware_spend(uid):
		_ware_detail.text += "\n\n[color=#ff5588]Payment failed.[/color]"
		_ware_install_btn.disabled = true
		return
	var drift_cost := int(db.get("drift", 0))
	GameState.add_cybernetic(uid, drift_cost)
	upgrade_installed.emit(uid)
	_refresh_ware()
	var drift_line := ""
	if drift_cost > 0:
		var eff := _ware_effective_drift(drift_cost)
		drift_line = "\n\n[color=#ff66cc]Drift +%d  —>  %d/%d  %s[/color]" % [
			eff, GameState.get_drift(), GameState.DRIFT_MAX, GameState.get_drift_descriptor()
		]
	_ware_detail.text = "[color=#20ff66]%s installed.[/color]\n\n%s%s" % [
		str(db.get("name", uid)), str(db.get("desc", "")), drift_line
	]
	_ware_install_btn.disabled = true


func _move_ware_selection(delta: int) -> void:
	if _ware_list == null or _ware_list.item_count == 0:
		return
	var sel := _ware_list.get_selected_items()
	var cur := sel[0] if not sel.is_empty() else -1
	var next := clampi(cur + delta, 0, _ware_list.item_count - 1)
	_ware_list.select(next)
	_on_ware_item_selected(next)


# ── WARE helpers ────────────────────────────────────────────────────

func _ware_find_slot(slot_name: String) -> String:
	for uid in GameState.cybernetics.keys():
		if not bool(GameState.cybernetics[uid]):
			continue
		if not CyberneticSurgeryUI.UPGRADE_DB.has(uid):
			continue
		var db: Dictionary = CyberneticSurgeryUI.UPGRADE_DB[uid]
		if str(db.get("slot", "")) == slot_name:
			return uid
	return ""


func _ware_can_pay(uid: String) -> bool:
	# Must be carrying the implant and able to cover Coil's Wan Note install fee.
	return GameState.has_item(uid) and GameState.get_wan_notes() >= GameState.implant_install_price(uid)


func _ware_spend(uid: String) -> bool:
	var price := GameState.implant_install_price(uid)
	if GameState.get_wan_notes() < price or not GameState.has_item(uid):
		return false
	if not GameState.spend_wan_notes(price):
		return false
	GameState.spend_item(uid, 1)   # the physical implant is consumed in the install
	return true


func _ware_effective_drift(raw: int) -> int:
	if raw <= 0:
		return 0
	if GameState.has_cybernetic("spine_relay"):
		return int(ceil(float(raw) * 0.5))
	return raw


func _ware_req_reason(db: Dictionary) -> String:
	if db.has("req_rep_min"):
		var r: Dictionary = db["req_rep_min"]
		var fac := str(r.get("faction", ""))
		var need := int(r.get("amount", 0))
		var have := int(GameState.reputation.get(fac, 0))
		if have < need:
			return "%s rep %d+ required (have %d)" % [fac, need, have]
	if db.has("req_rep_max"):
		var r2: Dictionary = db["req_rep_max"]
		var fac2 := str(r2.get("faction", ""))
		var ceil_r := int(r2.get("amount", 0))
		var have2 := int(GameState.reputation.get(fac2, 0))
		if have2 > ceil_r:
			return "%s rep must be %d or lower (have %d)" % [fac2, ceil_r, have2]
	if db.has("req_soul_rot_max"):
		var sr_max := int(db.get("req_soul_rot_max", 0))
		var sr_val := int(GameState.get("soul_rot") if GameState.get("soul_rot") != null else 0)
		if sr_val > sr_max:
			return "soul reads too corrupted (soul-rot %d, max %d)" % [sr_val, sr_max]
	return ""
