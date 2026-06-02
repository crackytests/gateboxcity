extends Node
# EnemyLayouts — data-driven, faction-themed, threat-scaled enemy spawns for the quest
# locations (refactor §5). Registered as an autoload (EnemyLayouts).
#
# Each location defines candidate `points` and a set of `profiles` keyed by the faction that
# currently contests it and a threat `band` range. spawn_profile() picks a profile matching the
# requested band (preferring a faction if asked) and spawns its enemy set. Every profile keeps at
# least one Splice so neural_splice (the Vessel quest) is always obtainable.

# Base enemy scenes usable in random quest garrisons. NOTE: named bosses/minibosses
# (Rocker Fellar, the Big Gates Overseer, General Bone Dividend) are deliberately excluded —
# they belong to their own authored levels, not shuffled quest spawns.
var SCENES: Dictionary = {
	"splice":        "res://scenes/enemies/Splice.tscn",
	"security_node": "res://scenes/enemies/SecurityNode.tscn",
	"goon":          "res://scenes/enemies/GoonMaterial.tscn",
	"ward_graft":    "res://scenes/enemies/WardResidentGraft.tscn",
}

# Data-driven enemy templates: a base scene re-flavored for a faction with its own name, loot
# table, and stat tweaks. Lets new rank-and-file enemies exist without bespoke scenes. These
# replace the boss/miniboss that used to anchor the Big Gates profiles.
var TEMPLATES: Dictionary = {
	# Big Gates corporate muscle — the heavy that replaces the Overseer's role in a garrison.
	"foundation_enforcer": {"scene": "goon", "faction": "Big Gates", "name": "Foundation Enforcer",
		"loot": "big_gates", "hp_mult": 1.4, "damage_mult": 1.2},
	# A soul-tech turret variant — replaces Bone Dividend's heavy presence.
	"soul_drone": {"scene": "security_node", "faction": "Big Gates", "name": "Soul Harvester Drone",
		"loot": "big_gates", "hp_mult": 1.25},
	# A grafted laborer — cheap Big Gates fodder.
	"tithe_servitor": {"scene": "goon", "faction": "Big Gates", "name": "Tithe Servitor",
		"loot": "big_gates", "hp_mult": 0.85, "damage_mult": 0.9},
}

# points: [sn, a, b, c]  (security-node slot + three combatant slots)
var LAYOUTS: Dictionary = {
	"pipe_utility_tunnels": {
		# p1 pulled back from z=4 to z=-8: entry is at (-6.5, 10), so the old slot sat ~6.5u away
		# (inside the 14u detection radius) and aggroed on arrival. Now ~18u — past detection.
		"points": [[0, 2, -8], [-4, 1.05, -8], [3, 1.05, -20], [-1, 1.05, -6]],
		"profiles": [
			{"faction": "Splice", "band": [1, 2], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "splice", "p": 1, "pack": "pipe", "anchor": true},
				{"e": "splice", "p": 2, "pack": "pipe"}]},
			{"faction": "Gatebox", "band": [2, 3], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "goon", "p": 1, "pack": "pipe_gb", "anchor": true},
				{"e": "goon", "p": 2, "pack": "pipe_gb"},
				{"e": "splice", "p": 3}]},
			{"faction": "Big Gates", "band": [3, 4], "spawns": [
				{"e": "soul_drone", "p": 0},
				{"e": "ward_graft", "p": 1},
				{"e": "foundation_enforcer", "p": 2},
				{"e": "splice", "p": 3}]},
		],
	},
	"dead_food_court_bloom": {
		"points": [[0, 0, -4], [6, 1.05, 2], [-3, 1.05, -10], [0, 1.05, -4]],
		"profiles": [
			{"faction": "Splice", "band": [1, 2], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "splice", "p": 1, "pack": "bloom", "anchor": true},
				{"e": "splice", "p": 2, "pack": "bloom"}]},
			{"faction": "Gatebox", "band": [2, 3], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "goon", "p": 1, "pack": "bloom_gb", "anchor": true},
				{"e": "splice", "p": 2}]},
			{"faction": "Big Gates", "band": [3, 4], "spawns": [
				{"e": "soul_drone", "p": 0},
				{"e": "tithe_servitor", "p": 1},
				{"e": "splice", "p": 2},
				{"e": "foundation_enforcer", "p": 3}]},
		],
	},
	"water_reclamation_cistern": {
		# p1 pulled back from z=1 to z=-3 (entry at (-3, 14)): ~15.8u → ~19.7u, clear of detection.
		"points": [[7, 0, -6], [7, 1.05, -3], [14, 1.05, -6], [10, 1.05, -2]],
		"profiles": [
			{"faction": "Splice", "band": [1, 2], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "splice", "p": 1, "pack": "cistern", "anchor": true},
				{"e": "splice", "p": 2, "pack": "cistern"}]},
			{"faction": "Gatebox", "band": [2, 3], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "goon", "p": 1, "pack": "cistern_gb", "anchor": true},
				{"e": "goon", "p": 2, "pack": "cistern_gb"},
				{"e": "splice", "p": 3}]},
			{"faction": "Big Gates", "band": [3, 4], "spawns": [
				{"e": "soul_drone", "p": 0},
				{"e": "ward_graft", "p": 1},
				{"e": "foundation_enforcer", "p": 2},
				{"e": "splice", "p": 3}]},
		],
	},
	"collapsed_service_atrium": {
		# p1 pulled back from z=0 to z=-5 (entry at (-3, 14)): old slot sat exactly 14u dead ahead
		# (right at the detection edge). Now ~19u.
		"points": [[0, 2, -4], [-3, 1.05, -5], [14, 1.05, 1], [5, 1.05, -2]],
		"profiles": [
			{"faction": "Splice", "band": [1, 2], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "splice", "p": 1, "pack": "atrium", "anchor": true},
				{"e": "splice", "p": 2, "pack": "atrium"}]},
			{"faction": "Gatebox", "band": [2, 3], "spawns": [
				{"e": "security_node", "p": 0},
				{"e": "goon", "p": 1, "pack": "atrium_gb", "anchor": true},
				{"e": "splice", "p": 2}]},
			{"faction": "Big Gates", "band": [3, 4], "spawns": [
				{"e": "soul_drone", "p": 0},
				{"e": "foundation_enforcer", "p": 1},
				{"e": "splice", "p": 2},
				{"e": "tithe_servitor", "p": 3}]},
		],
	},
}


# Spawns one profile at a location and returns it. host = the level node to parent enemies under.
# band selects the profile; preferred_faction biases the pick (the quest giver's rival).
func spawn_profile(host: Node, location_id: String, band: int = 2, preferred_faction := "") -> Dictionary:
	var loc: Dictionary = LAYOUTS.get(location_id, {})
	if loc.is_empty():
		return {}
	var points: Array = loc.get("points", [])
	var profiles: Array = loc.get("profiles", [])
	var chosen := _pick_profile(profiles, band, preferred_faction)
	if chosen.is_empty():
		return {}
	for spec: Dictionary in chosen.get("spawns", []):
		var idx := int(spec.get("p", 0))
		var pos := Vector3.ZERO
		if idx >= 0 and idx < points.size():
			var pt: Array = points[idx]
			pos = Vector3(float(pt[0]), float(pt[1]), float(pt[2]))
		_spawn_one(host, spec, pos)
	return chosen


# Drop a small ambush group near a world position (used by hostile event outcomes). enemy_keys
# are scene/template keys (e.g. ["splice","splice"] or ["gatebox_enforcer"]).
func spawn_ambush(host: Node, enemy_keys: Array, near: Vector3) -> void:
	if host == null:
		return
	var n := enemy_keys.size()
	for i in n:
		# Fan them out a couple metres in front of / around the target point.
		var angle := TAU * float(i) / float(maxi(n, 1))
		var offset := Vector3(cos(angle) * 2.0, 0.0, sin(angle) * 2.0 - 2.0)
		_spawn_one(host, {"e": str(enemy_keys[i]), "alert": true}, near + offset)


func _pick_profile(profiles: Array, band: int, preferred_faction: String) -> Dictionary:
	var eligible: Array = []
	for p: Dictionary in profiles:
		var b: Array = p.get("band", [1, 4])
		if b.size() >= 2 and band >= int(b[0]) and band <= int(b[1]):
			eligible.append(p)
	if eligible.is_empty():
		eligible = profiles
	if eligible.is_empty():
		return {}
	if not preferred_faction.is_empty():
		for p: Dictionary in eligible:
			if str(p.get("faction", "")) == preferred_faction:
				return p
	return eligible[randi() % eligible.size()]


func _spawn_one(host: Node, spec: Dictionary, pos: Vector3) -> void:
	# Resolve a template (faction-flavored variant) down to its base scene + overrides.
	var key := str(spec.get("e", ""))
	var tmpl: Dictionary = TEMPLATES.get(key, {})
	var base_key := str(tmpl.get("scene", key))
	var path := str(SCENES.get(base_key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return
	enemy.position = pos
	if spec.has("pack"):
		enemy.set("pack_id", str(spec["pack"]))
	if bool(spec.get("anchor", false)):
		enemy.set("is_pack_anchor", true)
	# Template identity (faction/loot/name) applied before _ready.
	if tmpl.has("faction"):
		enemy.set("faction", str(tmpl["faction"]))
	if tmpl.has("loot"):
		enemy.set("loot_id", str(tmpl["loot"]))
	if tmpl.has("name"):
		enemy.name = str(tmpl["name"])
	if base_key == "splice":
		enemy.add_to_group("splice")
	elif base_key == "security_node":
		enemy.add_to_group("security_node")   # destinations wire the turret via this group
	# Ambush spawns arrive after the destination's _ready wiring pass, so they must point
	# themselves at the player (the garrison gets this from the location's group loop instead).
	if bool(spec.get("alert", false)) and "player_path" in enemy and host.has_node("Player"):
		enemy.player_path = NodePath("../Player")
	host.add_child(enemy)
	# Ambush spawns hit the ground already hostile.
	if bool(spec.get("alert", false)) and enemy.has_method("alert"):
		enemy.call_deferred("alert")
	# Stat tweaks apply after _ready (so body-part HP is already initialized from data).
	if not tmpl.is_empty():
		_apply_template_stats(enemy, tmpl)
	# Optional patrol path (array of [x,y,z]).
	if spec.has("patrol") and enemy.has_method("set_patrol_points"):
		var pts: Array[Vector3] = []
		for pp in spec["patrol"]:
			pts.append(Vector3(float(pp[0]), float(pp[1]), float(pp[2])))
		enemy.set_patrol_points(pts)


func _apply_template_stats(enemy: Node3D, tmpl: Dictionary) -> void:
	var hp_mult := float(tmpl.get("hp_mult", 1.0))
	if hp_mult != 1.0:
		var parts_root := enemy.get_node_or_null("BodyParts")
		if parts_root != null:
			for child in parts_root.get_children():
				if child is BodyPart:
					var bp := child as BodyPart
					bp.max_hp *= hp_mult
					bp.current_hp = bp.max_hp
	var dmg_mult := float(tmpl.get("damage_mult", 1.0))
	if dmg_mult != 1.0:
		if "melee_damage" in enemy:
			enemy.melee_damage *= dmg_mult
		if "ranged_damage" in enemy:
			enemy.ranged_damage *= dmg_mult
