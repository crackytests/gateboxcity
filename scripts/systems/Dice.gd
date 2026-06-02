class_name Dice
# 2d6 stat-check core for event resolution (and future systems).
# See docs/loot_quest_event_refactor_plan.md §1.
#
#   total = 2d6 + attribute modifier + gear bonus (cyberware/drugs matching the check tag)
#   success = total >= difficulty
#   natural double-6 = critical success (auto-succeed); natural double-1 = fumble (auto-fail)
#
# Callable statically: Dice.roll_check("WIL", Dice.DC_TRICKY, "intimidate")

# Difficulty bands.
const DC_ROUTINE := 6
const DC_TRICKY := 8
const DC_HARD := 10
const DC_SEVERE := 12

# Cyberware → { check_tag: bonus }. An installed implant adds its bonus to matching checks.
# Drugs/active effects add on top via GameState.get_check_bonus() if that method exists (added
# when the pharmacy is retuned). Tags: force break intimidate dodge flee sneak endure resist
# hack analyze spot aim read persuade charm calm.
const CHECK_BONUSES := {
	"targeting_coprocessor": {"aim": 1},
	"gatebox_eye_mk1":       {"spot": 1, "aim": 1},
	"black_market_armature": {"aim": 1},
	"pipewalker_legs":       {"dodge": 1, "flee": 1},
	"soul_baffle":           {"endure": 1, "resist": 1},
	"neural_jack":           {"hack": 2, "analyze": 1},
	"whisper_filter":        {"sneak": 2},
	"mag_retina":            {"spot": 2, "aim": 1},
	"endoskeletal_brace":    {"endure": 2, "force": 1},
	"bioreactor_mesh":       {"endure": 1},
	"left_arm_graft":        {"force": 2, "break": 2, "intimidate": 1},
	"trauma_dampener":       {"aim": 1, "endure": 1},
	"sprint_pistons":        {"dodge": 1, "flee": 2},
	"spine_relay":           {"analyze": 1},
	"drift_syphon":          {"resist": 1},
	"soul_anchor_tap":       {"resist": 1, "read": 1},
	"preservation_blocker":  {"sneak": 1},
}


# Rolls a check. Returns a result dict the UI can render and branch on:
#   {success, total, dice:[a,b], mod, gear, crit, fumble, difficulty, attribute, tag}
static func roll_check(attribute: String, difficulty: int, check_tag := "") -> Dictionary:
	var a := randi_range(1, 6)
	var b := randi_range(1, 6)
	var mod := attribute_mod(attribute)
	var gear := gear_bonus(check_tag)
	var total := a + b + mod + gear
	var crit := a == 6 and b == 6
	var fumble := a == 1 and b == 1
	var success := total >= difficulty
	if crit:
		success = true
	elif fumble:
		success = false
	return {
		"success": success, "total": total, "dice": [a, b], "mod": mod, "gear": gear,
		"crit": crit, "fumble": fumble, "difficulty": difficulty,
		"attribute": attribute, "tag": check_tag,
	}


# The player's static bonus for a check, so the UI can preview odds before the roll.
static func attribute_mod(attribute: String) -> int:
	return int(GameState.attributes.get(attribute, 0))


static func gear_bonus(check_tag: String) -> int:
	if check_tag.is_empty():
		return 0
	var total := 0
	for cyber_id: String in CHECK_BONUSES.keys():
		if GameState.has_cybernetic(cyber_id):
			total += int((CHECK_BONUSES[cyber_id] as Dictionary).get(check_tag, 0))
	# Drug/active-effect contribution (optional; added when the pharmacy is retuned).
	if GameState.has_method("get_check_bonus"):
		total += int(GameState.get_check_bonus(check_tag))
	return total


# Total static modifier (attribute + gear) — convenience for previews.
static func check_modifier(attribute: String, check_tag := "") -> int:
	return attribute_mod(attribute) + gear_bonus(check_tag)


# Human-readable band label for a difficulty value.
static func difficulty_label(difficulty: int) -> String:
	if difficulty <= DC_ROUTINE:
		return "Routine"
	if difficulty <= DC_TRICKY:
		return "Tricky"
	if difficulty <= DC_HARD:
		return "Hard"
	return "Severe"


# A compact one-line summary of a completed roll, for transcripts/logs.
static func describe(result: Dictionary) -> String:
	var dice: Array = result.get("dice", [0, 0])
	var tag := str(result.get("attribute", ""))
	var line := "%s check: 2d6 (%d+%d) +%d" % [tag, int(dice[0]), int(dice[1]), int(result.get("mod", 0))]
	if int(result.get("gear", 0)) != 0:
		line += " +%d gear" % int(result["gear"])
	line += " = %d vs %d" % [int(result.get("total", 0)), int(result.get("difficulty", 0))]
	if result.get("crit", false):
		line += " — CRIT"
	elif result.get("fumble", false):
		line += " — FUMBLE"
	elif result.get("success", false):
		line += " — success"
	else:
		line += " — fail"
	return line
