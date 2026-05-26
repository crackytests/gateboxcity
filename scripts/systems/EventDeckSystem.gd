extends Node

var _deck: Array[Dictionary] = []

signal card_triggered(card: Dictionary)


func add_card(card_data: Variant) -> void:
	var card := _coerce_card(card_data)
	if card.is_empty():
		return
	_deck.append(card.duplicate(true))


func _coerce_card(card_data: Variant) -> Dictionary:
	if typeof(card_data) == TYPE_DICTIONARY:
		return card_data as Dictionary
	if typeof(card_data) == TYPE_STRING:
		var named_card := WorldDirector.get_named_card(str(card_data))
		if not named_card.is_empty():
			return named_card
		push_warning("Unknown event deck card id: " + str(card_data))
	return {}


func remove_cards_by_tag(tag: String) -> void:
	_deck = _deck.filter(func(c: Dictionary) -> bool:
		return not (c.get("tags", []) as Array).has(tag))


func remove_cards_by_id(card_id: String) -> void:
	_deck = _deck.filter(func(c: Dictionary) -> bool:
		return str(c.get("id", "")) != card_id)


func get_candidates(context: String) -> Array:
	var result: Array = []
	for card: Dictionary in _deck:
		var contexts: Array = card.get("contexts", [])
		if not contexts.has(context):
			continue
		if not _check_conditions(card.get("conditions", {})):
			continue
		result.append(card.duplicate(true))
	return result


func apply_and_expire(card: Dictionary) -> void:
	_apply_effects(card.get("effects", []))
	var card_id := str(card.get("id", ""))
	if card_id.is_empty():
		return
	var expires_after: int = int(card.get("expires_after", -1))
	if expires_after == 0:
		remove_cards_by_id(card_id)
		card_triggered.emit(card)
		return
	if expires_after > 0:
		for i in range(_deck.size()):
			if str(_deck[i].get("id", "")) == card_id:
				_deck[i]["expires_after"] = expires_after - 1
				if int(_deck[i].get("expires_after", 0)) <= 0:
					_deck.remove_at(i)
				break
	card_triggered.emit(card)


func get_deck_for_save() -> Array:
	return _deck.duplicate(true)


func restore_from_save(data: Array) -> void:
	_deck = []
	for item in data:
		if typeof(item) == TYPE_DICTIONARY:
			_deck.append((item as Dictionary).duplicate(true))


func _check_conditions(conditions: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	for key: String in conditions.keys():
		var val = conditions[key]
		match key:
			"flag_true":
				if not bool(GameState.get_world_flag(str(val))):
					return false
			"flag_false":
				if bool(GameState.get_world_flag(str(val))):
					return false
			"has_item":
				if not GameState.has_item(str(val)):
					return false
			"active_job":
				if GameState.active_job_id != str(val):
					return false
			"any_active_job":
				if bool(val) and GameState.active_job_id.is_empty():
					return false
			"rep_gte":
				var arr: Array = val if typeof(val) == TYPE_ARRAY else []
				if arr.size() >= 2 and int(GameState.reputation.get(str(arr[0]), 0)) < int(arr[1]):
					return false
			"rep_lte":
				var arr: Array = val if typeof(val) == TYPE_ARRAY else []
				if arr.size() >= 2 and int(GameState.reputation.get(str(arr[0]), 0)) > int(arr[1]):
					return false
	return true


func _apply_effects(effects: Array) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		match str(effect.get("type", "")):
			"set_event":
				WorldDirector.trigger_event(str(effect.get("event_id", "")))
			"add_item":
				GameState.add_item(str(effect.get("item", "")), int(effect.get("count", 1)))
			"add_rep":
				GameState.add_reputation(str(effect.get("faction", "")), int(effect.get("amount", 0)))
			"set_flag":
				GameState.set_world_flag(str(effect.get("flag", "")), effect.get("value", true))
			"add_card":
				var new_card := WorldDirector.get_named_card(str(effect.get("card_id", "")))
				if not new_card.is_empty():
					add_card(new_card)
			"remove_tag":
				remove_cards_by_tag(str(effect.get("tag", "")))
