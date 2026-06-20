extends Node

signal cybernetics_changed
signal inventory_changed(summary: String)
signal reputation_changed(summary: String)
signal effects_changed
signal effect_notice(text: String)
signal player_heal_requested(amount: float)
signal player_damage_requested(amount: float)
signal player_died

var items: Dictionary = {}
var wan_notes: int = 0   # the sole currency (virtualized through the "Wan Note" item API)
var reputation: Dictionary = {
	"System X": 0,
	"Gatebox Corporation": 0,
	"Wan Moa Torai": 0,
	"Linda": 0,
}
var completed_quests: Dictionary = {}
var active_job_id := ""
var active_job_run_id := 0
var day := 1                # advances when Spooky rests; drives the daily job-board refresh
var _jobs_built_day := 0    # the day the current board was rolled (so re-entering Cooters keeps it)
var available_jobs: Array = [
	"pipe_blood_sample",
	"ratchet_saint",
	"listen_to_the_pipes",
	"food_court_filter",
	"cistern_pump_heart",
	"atrium_relay_echo",
]
var completed_jobs: Dictionary = {}
var job_flags: Dictionary = {}
var last_mission_result := ""
var world_flags: Dictionary = {}
var quest_states: Dictionary = {}
var cybernetics: Dictionary = {}
var defeated_enemies: Dictionary = {}  # persistence_key -> true
var bestiary_kills: Dictionary = {}    # species_id -> int (drives the GhostTerm compendium reveal)

# ── Dialogue system (Daggerfall-style topics) ───────────────────────
var known_topics: Dictionary = {}      # topic_id -> true (the keyword codex)
var npc_disposition: Dictionary = {}   # npc_id -> int 0..100 (seeded from faction on first read)
var conversation_tone := "normal"      # "polite" | "normal" | "blunt", remembered between talks

# ── Phase 2: attributes & drift ─────────────────────────────────────
# IZ2-derived attribute matrix. Soft flavour for now; wired into rolls later.
var attributes: Dictionary = {
	"STR": 2, "AGL": 3, "CON": 2,   # MEAT
	"INT": 4, "PER": 3, "WIL": 2,   # MIND
	"EMP": 1, "LUCK": 2,            # SOUL
}
# Drift: estrangement from unmodified humanity. Rises on cybernetic installs.
var drift: int = 0
# Soul-rot: corruption of the soul anchor. Rises from freeing trapped souls,
# soul-tech, and Preservation compliance (full system is Phase 6). 0..100.
var soul_rot: int = 0
const SOUL_ROT_MAX := 100
# Gatebox attention: how much corporate notice the player has drawn by
# trespassing in Gatebox installations (Comfort Annexe etc.). One-way-ish ratchet.
var gatebox_attention_level: int = 0

# ── Save location & death ───────────────────────────────────────────
# Where the player was when they last saved, so a load drops them back in the
# right scene at the right spot rather than at the level's default entrance.
var saved_scene_path := ""
var _save_px := 0.0
var _save_py := 0.0
var _save_pz := 0.0
var _save_pyaw := 0.0
var _save_php := 100.0
var _has_saved_location := false
var _is_dead := false
var _force_reload_pending := false
var _load_restore_pending := false
var _new_game_intro_pending := false

const DRIFT_MAX := 100
const DRIFT_FLAG_NOTICED := "drift_noticed"   # 21+: Gatebox grows attentive
const DRIFT_FLAG_UNCANNY := "drift_uncanny"   # 41+: citizens uneasy
const DRIFT_FLAG_SCANNED := "drift_scanned"   # 61+: Preservation scans climb
const DRIFT_FLAG_HIGH := "high_drift"         # 81+: unique NPC reactions

# ── Loot: enemy cyberware drops + scrap (refactor §2) ───────────────
# Enemies drop the implant tied to a body part you left INTACT (break the part → forfeit it).
# Keyed by loot_id (Enemy resolves this from its faction by default). `parts` maps a part's
# display_name → the implant it yields while that part is unbroken. Drops are deliberately rare.
var ENEMY_LOOT: Dictionary = {
	"splice": {
		"drop_chance": 0.28,
		"parts": {
			"Wire Skull": "whisper_filter",
			"Graft Shell": "soul_baffle",
			"Splice Arm": "black_market_armature",
			"Drag Frame": "sprint_pistons",
		},
		"scrap": ["Bent Actuator", "Fried Cortex Chip"],
		"scrap_chance": 0.45,
		"special": [{"item": "neural_splice", "chance": 0.5}],   # bunny/Vessel quest
	},
	"gatebox": {
		"drop_chance": 0.24,
		"parts": {
			"Head": "gatebox_eye_mk1",
			"Torso": "soul_baffle",
			"Right Arm": "targeting_coprocessor",
			"Left Arm": "trauma_dampener",
			"Right Leg": "pipewalker_legs",
			"Left Leg": "sprint_pistons",
		},
		"scrap": ["Cracked Optic", "Bent Actuator"],
		"scrap_chance": 0.4,
		"special": [],
	},
	"big_gates": {
		# Big Gates rank-and-file (Foundation Enforcer / Tithe Servitor) are goon-framed, so the
		# loot keys to goon part display-names. Higher-band faction → richer implants.
		"drop_chance": 0.22,
		"parts": {
			"Head": "mag_retina",
			"Torso": "bioreactor_mesh",
			"Right Arm": "endoskeletal_brace",
			"Left Arm": "spine_relay",
			"Right Leg": "pipewalker_legs",
			"Left Leg": "sprint_pistons",
		},
		"scrap": ["Leaking Cell", "Fried Cortex Chip"],
		"scrap_chance": 0.4,
		"special": [],
	},
}

# Ruined implant parts: sell-only scrap (Wan Note value). May be crafting inputs later.
const SCRAP_VALUES := {
	"Cracked Optic": 3,
	"Bent Actuator": 3,
	"Fried Cortex Chip": 4,
	"Leaking Cell": 5,
}

const LADDERBOY_IMPLANT_REPAIR_RECIPES := [
	{"broken": "Cracked Optic", "implant": "gatebox_eye_mk1", "wan": 10},
	{"broken": "Cracked Optic", "implant": "mag_retina", "wan": 16},
	{"broken": "Bent Actuator", "implant": "pipewalker_legs", "wan": 10},
	{"broken": "Bent Actuator", "implant": "sprint_pistons", "wan": 12},
	{"broken": "Bent Actuator", "implant": "black_market_armature", "wan": 18},
	{"broken": "Fried Cortex Chip", "implant": "targeting_coprocessor", "wan": 14},
	{"broken": "Fried Cortex Chip", "implant": "neural_jack", "wan": 18},
	{"broken": "Fried Cortex Chip", "implant": "trauma_dampener", "wan": 14},
	{"broken": "Leaking Cell", "implant": "soul_baffle", "wan": 14},
	{"broken": "Leaking Cell", "implant": "endoskeletal_brace", "wan": 16},
	{"broken": "Leaking Cell", "implant": "bioreactor_mesh", "wan": 24},
]

# Implant rarity → drop weight (rarer = lower weight) and later install price / scrap value.
const IMPLANT_TIERS := {
	"black_market_armature": "uncommon", "left_arm_graft": "uncommon",
	"trauma_dampener": "uncommon", "mag_retina": "uncommon",
	"endoskeletal_brace": "uncommon", "neural_jack": "uncommon", "spine_relay": "uncommon",
	"bioreactor_mesh": "rare", "drift_syphon": "rare",
	"soul_anchor_tap": "rare", "preservation_blocker": "rare",
	# everything else defaults to "common"
}

# ── Consumables / Drugs ─────────────────────────────────────────────
# Brickmouth Ronnie's pharmacy. Each drug grants an "active" buff for a
# duration, then drops into a "comedown" penalty before clearing. Modifier
# keys: speed_mult / reload_mult / damage_mult / damage_taken_mult are
# multiplicative (default 1.0); hit_chance_bonus / hack_bonus are additive.
# "heal" is applied instantly on use.
const CONSUMABLES := {
	"Jolt": {
		"label": "Jolt",
		"desc": "Sub-Sub-Basement street stim. The floor speeds up to meet you. Then your hands forget how to hold still.",
		"use_log": "Jolt hits — everything quickens.",
		"comedown_log": "Jolt comedown — the shakes set in, aim's gone loose.",
		"active_duration": 24.0,
		"active_mods": {"speed_mult": 1.30, "reload_mult": 0.65},
		"comedown_duration": 16.0,
		"comedown_mods": {"hit_chance_bonus": -18.0},
	},
	"Glass": {
		"label": "Glass",
		"desc": "A clarity drug cut for runners and hackers. The world snaps into focus and terminals stop arguing. You get heavy when it leaves.",
		"use_log": "Glass settles — the world goes sharp and quiet.",
		"comedown_log": "Glass comedown — limbs full of wet sand.",
		"active_duration": 24.0,
		"active_mods": {"hit_chance_bonus": 16.0, "hack_bonus": 2.0},
		"comedown_duration": 14.0,
		"comedown_mods": {"speed_mult": 0.80},
	},
	"Redline": {
		"label": "Redline",
		"desc": "Combat juice. Every hit lands harder. So does every hit you take, once it sours.",
		"use_log": "Redline floods in — you hit like a falling ceiling.",
		"comedown_log": "Redline comedown — skin like wet paper.",
		"active_duration": 18.0,
		"active_mods": {"damage_mult": 1.55},
		"comedown_duration": 18.0,
		"comedown_mods": {"damage_taken_mult": 1.30},
	},
	"Patch": {
		"label": "Patch",
		"desc": "Wan Moa Torai field medicine. Seals you up fast. Tastes like mint and apology, leaves you a little soft behind the eyes.",
		"use_log": "Patch seals you up.",
		"comedown_log": "Patch fog — everything's a half-second slow.",
		"heal": 45.0,
		"active_duration": 0.0,
		"active_mods": {},
		"comedown_duration": 8.0,
		"comedown_mods": {"speed_mult": 0.90},
	},
}

# Active timed effects from consumed drugs. Each entry:
#   {id, label, phase: "active"|"comedown", time_left, active_mods,
#    comedown_mods, comedown_duration, comedown_log}
# Untyped Array so Array.filter() results assign back cleanly.
var active_effects: Array = []

const SAVE_SLOT_MANUAL := "manual"
const SAVE_SLOT_QUICK := "quick"
const SAVE_SLOT_AUTO := "auto"
const SAVE_PATH := "user://gatebox_save.json"
const QUICK_SAVE_PATH := "user://gatebox_quicksave.json"
const AUTO_SAVE_PATH := "user://gatebox_autosave.json"
const WAN_NOTE_ITEM := "Wan Note"
const DREAMING_GENERATOR_POTENTIAL_FLAG := "dreaming_generator_potential"
const DREAMING_GENERATOR_THRESHOLD := 40
const DREAMING_GENERATOR_MAX_POTENTIAL := 140

const WASTED_POTENTIAL_VALUES := {
	"Pipe Blood Sample": {"wan_notes": 12, "potential": 20, "label": "alive enough to disappoint a pipe"},
	"Saint Ratchet": {"wan_notes": 18, "potential": 28, "label": "a miracle with stripped threading"},
	"Pipe Listening Notes": {"wan_notes": 10, "potential": 16, "label": "recorded confession from infrastructure"},
	"Pure Water Filter": {"wan_notes": 20, "potential": 30, "label": "clean water that never reached a mouth"},
	"Cistern Filter Core": {"wan_notes": 24, "potential": 35, "label": "a public good with private paperwork"},
	"Atrium Relay Packet": {"wan_notes": 16, "potential": 24, "label": "a mall announcement nobody survived to hear"},
	"Cooters Bar Credit": {"wan_notes": 5, "potential": 8, "label": "unspent vice"},
	"Cooters Rumor Token": {"wan_notes": 6, "potential": 10, "label": "a secret that almost became useful"},
	"Chemical Neutralizer": {"wan_notes": 8, "potential": 7, "label": "safety deferred until resale"},
	"Illegal Reactor Cell": {"wan_notes": 30, "potential": 45, "label": "stolen fire with paperwork burns"},
	"Torai Salvage Contract": {"wan_notes": 9, "potential": 12, "label": "labor waiting to become debt"},
	"Broken Gatebox Display": {"wan_notes": 7, "potential": 14, "label": "comfort that failed before it could comfort"},
	"Marbles Backroom Key": {"wan_notes": 4, "potential": 5, "label": "access with nowhere clean to go"},
}

const COOTERS_JOBS := {
	"pipe_blood_sample": {
		"title": "Pipe Blood Sample",
		"short_desc": "Bring Marbles a living drip from the utility tunnels before it develops opinions.",
		"details": "The utility pipes below Leak Street are sweating something that moves against gravity, which is rude and probably billable. Find a clean sample bulb, collect Pipe Blood Sample, and bring it back before it starts arguing with the glass.",
		"objective": "Collect Pipe Blood Sample in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Cooters Bar Credit, System X +1",
		"reward_item": "Cooters Bar Credit",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pipe Blood Sample",
		"objective_interactable": "pipe_blood_sample_node",
		"event_cards_on_accept": ["pipe_blood_sample_exit", "pipe_blood_sample_travel"],
		"event_cards_on_complete": ["pipe_blood_sample_return"],
	},
	"ratchet_saint": {
		"title": "Saint Ratchet",
		"short_desc": "Recover a pipe-cult relic before Torai invoices the miracle.",
		"details": "Pipe Father Gideon says Saint Ratchet fell into a utility runoff channel and started blessing the bolts, which is very moving if you are a bolt. Marbles says bring it back before Wan Moa Torai puts a lien on the miracle.",
		"objective": "Recover Saint Ratchet in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Chemical Neutralizer, Torai +1",
		"reward_item": "Chemical Neutralizer",
		"reward_count": 1,
		"reward_faction": "Wan Moa Torai",
		"reward_rep": 1,
		"objective_item": "Saint Ratchet",
		"objective_interactable": "saint_ratchet_node",
		"event_cards_on_accept": ["ratchet_saint_exit", "ratchet_saint_travel"],
		"event_cards_on_complete": ["ratchet_saint_return"],
	},
	"listen_to_the_pipes": {
		"title": "Listen To The Pipes",
		"short_desc": "Record the pipe choir where the ceiling leaks sideways.",
		"details": "There is a listening node under the main drain, because apparently the building needed a mouth and a diary. Put your head where the pipes tell you not to and bring Marbles whatever the lower city says back.",
		"objective": "Use the pipe listening node in the Pipe Utility Tunnels.",
		"destination": "Pipe Utility Tunnels",
		"destination_id": "pipe_utility_tunnels",
		"reward_text": "Cooters Rumor Token, System X +1",
		"reward_item": "Cooters Rumor Token",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pipe Listening Notes",
		"objective_interactable": "pipe_listening_node",
		"event_cards_on_accept": ["listen_pipes_exit", "listen_pipes_travel"],
		"event_cards_on_complete": ["listen_pipes_return"],
	},
	"food_court_filter": {
		"title": "Food Court Filter",
		"short_desc": "Pull a clean water filter from the plant-choked food court.",
		"details": "The old food court is trying to become a greenhouse with teeth, a sentence nobody should have to say before lunch. Stay on the slow upper ring for clean angles, or cut through the seating pit if you trust decorative plants with your ankles.",
		"objective": "Recover the Pure Water Filter from Dead Food Court Bloom.",
		"destination": "Dead Food Court Bloom",
		"destination_id": "dead_food_court_bloom",
		"reward_text": "Cooters Bar Credit, System X +1",
		"reward_item": "Cooters Bar Credit",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Pure Water Filter",
		"objective_interactable": "pure_water_filter_node",
		"event_cards_on_accept": ["food_court_exit", "food_court_travel"],
		"event_cards_on_complete": ["food_court_return"],
	},
	"cistern_pump_heart": {
		"title": "Pump Heart Lease",
		"short_desc": "Borrow a pump core from a flooded reclamation room.",
		"details": "Wan Moa Torai says the pump core is unpaid inventory. Marbles says the water gets less bitey when it is gone. Both of them are calling this a favor, which means watch the wet floor around the live conduit.",
		"objective": "Recover the Cistern Filter Core from Water Reclamation Cistern.",
		"destination": "Water Reclamation Cistern",
		"destination_id": "water_reclamation_cistern",
		"reward_text": "Chemical Neutralizer, Torai +1",
		"reward_item": "Chemical Neutralizer",
		"reward_count": 1,
		"reward_faction": "Wan Moa Torai",
		"reward_rep": 1,
		"objective_item": "Cistern Filter Core",
		"objective_interactable": "cistern_filter_core_node",
		"event_cards_on_accept": ["cistern_exit", "cistern_travel"],
		"event_cards_on_complete": ["cistern_return"],
	},
	"atrium_relay_echo": {
		"title": "Atrium Relay Echo",
		"short_desc": "Record a relay pulse from the collapsed mall atrium.",
		"details": "There is an old mall relay above a sludge gap, still whispering customer-service hymns through System X static. Use the catwalk. Do not trust the floor pretending to be floor; that is how floors get promoted.",
		"objective": "Use the comms relay in Collapsed Service Atrium.",
		"destination": "Collapsed Service Atrium",
		"destination_id": "collapsed_service_atrium",
		"reward_text": "Cooters Rumor Token, System X +1",
		"reward_item": "Cooters Rumor Token",
		"reward_count": 1,
		"reward_faction": "System X",
		"reward_rep": 1,
		"objective_item": "Atrium Relay Packet",
		"objective_interactable": "atrium_relay_node",
		"event_cards_on_accept": ["atrium_relay_exit", "atrium_relay_travel"],
		"event_cards_on_complete": ["atrium_relay_return"],
	},
}

# ── Dynamic Cooters jobs (refactor §4) ──────────────────────────────
# Authored, faction-sourced templates. Each visit to Cooters shuffles the pool and instances a
# few (build_job_board). An instance rolls its location (from `locations`), enemy threat band +
# contesting faction, and a Wan Note reward; items are an occasional bonus. Instances carry the
# same fields the destinations + JobBoardUI already read (objective_interactable/objective_item/
# destination), so no destination code changes.
#
# objective_type: "find" (recover an item at a location's objective node — reuses existing nodes),
# "kill_loot" (defeat the garrison until target_loot drops), "deliver" (carry deliver_item to a
# location's drop-off node). giver = faction/NPC the job comes from (flavor + event linkage).
# Each `locations` entry: {id, node, item, title} for that destination's objective node.
var COOTERS_JOB_TEMPLATES: Dictionary = {
	"marbles_pipe_sample": {
		"giver": "Marbles", "faction": "System X", "objective_type": "find",
		"short_desc": "Bring Marbles a living drip from the utility pipes before it argues with the glass.",
		"threat_band": 1, "rival_faction": "Splice", "reward_wan_notes": [10, 16],
		"reward_item_chance": 0.3, "reward_item_pool": ["Cooters Bar Credit", "Bent Actuator"],
		"faction_rep": {"System X": 1},
		"event_cards_on_accept": ["pipe_blood_sample_exit", "pipe_blood_sample_travel"],
		"event_cards_on_complete": ["pipe_blood_sample_return"],
		"locations": [
			{"id": "pipe_utility_tunnels", "node": "pipe_blood_sample_node", "item": "Pipe Blood Sample", "title": "Pipe Blood Sample"},
		],
	},
	"gideon_saint_ratchet": {
		"giver": "Pipe Father Gideon", "faction": "System X", "objective_type": "find",
		"short_desc": "Recover a pipe-cult relic before Torai invoices the miracle.",
		"threat_band": 2, "rival_faction": "Splice", "reward_wan_notes": [14, 20],
		"reward_item_chance": 0.3, "reward_item_pool": ["Chemical Neutralizer"],
		"reward_cyberware_pool": ["soul_baffle", "trauma_dampener"],
		"faction_rep": {"System X": 1},
		"event_cards_on_accept": ["ratchet_saint_exit", "ratchet_saint_travel"],
		"event_cards_on_complete": ["ratchet_saint_return"],
		"locations": [
			{"id": "pipe_utility_tunnels", "node": "saint_ratchet_node", "item": "Saint Ratchet", "title": "Saint Ratchet"},
		],
	},
	"vera_water_filter": {
		"giver": "Vera", "faction": "System X", "objective_type": "find",
		"short_desc": "Pull a clean water filter from the plant-choked food court.",
		"threat_band": 2, "rival_faction": "Gatebox", "reward_wan_notes": [14, 22],
		"reward_item_chance": 0.35, "reward_item_pool": ["Chemical Neutralizer", "Cracked Optic"],
		"faction_rep": {"System X": 1},
		"event_cards_on_accept": ["food_court_exit", "food_court_travel"],
		"event_cards_on_complete": ["food_court_return"],
		"locations": [
			{"id": "dead_food_court_bloom", "node": "pure_water_filter_node", "item": "Pure Water Filter", "title": "Pure Water Filter"},
		],
	},
	"torai_cistern_core": {
		"giver": "Wan Moa Torai", "faction": "Wan Moa Torai", "objective_type": "find",
		"short_desc": "Borrow a pump core from a flooded reclamation room. Unpaid inventory, technically.",
		"threat_band": 2, "rival_faction": "Gatebox", "reward_wan_notes": [16, 24],
		"reward_item_chance": 0.3, "reward_item_pool": ["Chemical Neutralizer", "Leaking Cell"],
		"faction_rep": {"Wan Moa Torai": 1},
		"event_cards_on_accept": ["cistern_exit", "cistern_travel"],
		"event_cards_on_complete": ["cistern_return"],
		"locations": [
			{"id": "water_reclamation_cistern", "node": "cistern_filter_core_node", "item": "Cistern Filter Core", "title": "Pump Heart Lease"},
		],
	},
	"systemx_atrium_relay": {
		"giver": "System X", "faction": "System X", "objective_type": "find",
		"short_desc": "Record a relay pulse from the collapsed mall atrium.",
		"threat_band": 2, "rival_faction": "Big Gates", "reward_wan_notes": [16, 24],
		"reward_item_chance": 0.3, "reward_item_pool": ["Cooters Rumor Token"],
		"faction_rep": {"System X": 1},
		"event_cards_on_accept": ["atrium_relay_exit", "atrium_relay_travel"],
		"event_cards_on_complete": ["atrium_relay_return"],
		"locations": [
			{"id": "collapsed_service_atrium", "node": "atrium_relay_node", "item": "Atrium Relay Packet", "title": "Atrium Relay Echo"},
		],
	},
	"kiki_salvage_haul": {
		"giver": "Kiki Baja", "faction": "Wan Moa Torai", "objective_type": "kill_loot",
		"short_desc": "Torai wants salvaged actuators. Strip them off whatever is guarding the cistern.",
		"threat_band": 2, "rival_faction": "Gatebox", "reward_wan_notes": [18, 26],
		"reward_item_chance": 0.25, "reward_item_pool": ["Cooters Bar Credit"],
		"faction_rep": {"Wan Moa Torai": 1},
		"target_loot": "Bent Actuator", "target_loot_label": "a salvaged actuator",
		"locations": [
			{"id": "water_reclamation_cistern", "title": "Actuator Salvage"},
			{"id": "pipe_utility_tunnels", "title": "Actuator Salvage"},
		],
	},
	"ronnie_optics_run": {
		"giver": "Brickmouth Ronnie", "faction": "System X", "objective_type": "kill_loot",
		"short_desc": "Ronnie needs cracked optics for a batch he will not describe. Pull them off the guards.",
		"threat_band": 2, "rival_faction": "Gatebox", "reward_wan_notes": [16, 24],
		"reward_item_chance": 0.3, "reward_item_pool": ["Jolt", "Glass"],
		"faction_rep": {},
		"target_loot": "Cracked Optic", "target_loot_label": "a cracked optic",
		"locations": [
			{"id": "dead_food_court_bloom", "title": "Optics Run"},
			{"id": "collapsed_service_atrium", "title": "Optics Run"},
		],
	},
	"gideon_relic_delivery": {
		"giver": "Pipe Father Gideon", "faction": "System X", "objective_type": "deliver",
		"short_desc": "Carry a blessed pipe-cult relic down to the chapel shrine without losing it to the dark.",
		"threat_band": 1, "rival_faction": "Splice", "reward_wan_notes": [12, 18],
		"reward_item_chance": 0.2, "reward_item_pool": ["Chemical Neutralizer"],
		"faction_rep": {"System X": 1},
		"deliver_item": "Blessed Ratchet Relic",
		"locations": [
			{"id": "pipe_utility_tunnels", "node": "saint_ratchet_node", "title": "Relic Delivery"},
		],
	},
	"static_listen_post": {
		"giver": "Mister Static", "faction": "System X", "objective_type": "find",
		"short_desc": "Static wants a clean recording from the pipe choir before the Splice retune it into something worse.",
		"threat_band": 1, "rival_faction": "Splice", "reward_wan_notes": [12, 18],
		"reward_item_chance": 0.3, "reward_item_pool": ["Cooters Rumor Token", "Cooters Bar Credit"],
		"reward_unlock": "systemx_safehouse_known", "reward_unlock_label": "System X safehouse intel",
		"faction_rep": {"System X": 1},
		"event_cards_on_complete": ["systemx_safehouse_cache"],
		"locations": [
			{"id": "pipe_utility_tunnels", "node": "pipe_listening_node", "item": "Pipe Choir Recording", "title": "Listening Post"},
		],
	},
	"static_cortex_pull": {
		"giver": "Mister Static", "faction": "System X", "objective_type": "kill_loot",
		"short_desc": "Static needs intact cortex chips for a patch he keeps calling 'maintenance.' Strip them off whatever bites back.",
		"threat_band": 2, "rival_faction": "Splice", "reward_wan_notes": [18, 26],
		"reward_item_chance": 0.25, "reward_item_pool": ["Glass"],
		"reward_cyberware_pool": ["neural_jack", "targeting_coprocessor"],
		"faction_rep": {"System X": 1},
		"target_loot": "Fried Cortex Chip", "target_loot_label": "a fried cortex chip",
		"locations": [
			{"id": "pipe_utility_tunnels", "title": "Cortex Pull"},
			{"id": "collapsed_service_atrium", "title": "Cortex Pull"},
		],
	},
	"torai_cell_collection": {
		"giver": "Kiki Baja", "faction": "Wan Moa Torai", "objective_type": "kill_loot",
		"short_desc": "Torai is short on reactor cells and long on enemies who carry them. Math, basically.",
		"threat_band": 3, "rival_faction": "Big Gates", "reward_wan_notes": [22, 30],
		"reward_item_chance": 0.3, "reward_item_pool": ["Patch", "Chemical Neutralizer"],
		"reward_cyberware": "bioreactor_mesh",
		"faction_rep": {"Wan Moa Torai": 1},
		"target_loot": "Leaking Cell", "target_loot_label": "a leaking reactor cell",
		"locations": [
			{"id": "collapsed_service_atrium", "title": "Cell Collection"},
		],
	},
	"ronnie_blackmarket_pull": {
		"giver": "Brickmouth Ronnie", "faction": "System X", "objective_type": "kill_loot",
		"short_desc": "Ronnie wants salvaged actuators for an armature he is definitely not building in a bathroom.",
		"threat_band": 2, "rival_faction": "Splice", "reward_wan_notes": [16, 24],
		"reward_item_chance": 0.3, "reward_item_pool": ["Jolt", "Redline"],
		"reward_cyberware": "black_market_armature",
		"faction_rep": {},
		"target_loot": "Bent Actuator", "target_loot_label": "a salvaged actuator",
		"locations": [
			{"id": "pipe_utility_tunnels", "title": "Black-Market Pull"},
			{"id": "water_reclamation_cistern", "title": "Black-Market Pull"},
		],
	},
	"gideon_mercy_drop": {
		"giver": "Pipe Father Gideon", "faction": "System X", "objective_type": "deliver",
		"short_desc": "Carry a flask of soul coolant down to the drowned pump and bless the machine before it boils a saint.",
		"threat_band": 2, "rival_faction": "Splice", "reward_wan_notes": [14, 20],
		"reward_item_chance": 0.25, "reward_item_pool": ["Chemical Neutralizer"],
		"faction_rep": {"System X": 1},
		"deliver_item": "Soul Coolant Flask",
		"locations": [
			{"id": "water_reclamation_cistern", "node": "cistern_filter_core_node", "title": "Mercy Drop"},
		],
	},
	"vera_relay_cache": {
		"giver": "Vera", "faction": "System X", "objective_type": "deliver",
		"short_desc": "Run a sealed System X cache up to the atrium relay so Yoko and the Pee Kid can hear past the corporate wall.",
		"threat_band": 2, "rival_faction": "Gatebox", "reward_wan_notes": [16, 22],
		"reward_item_chance": 0.2, "reward_item_pool": ["Cooters Rumor Token"],
		"faction_rep": {"System X": 1},
		"deliver_item": "System X Relay Cache",
		"locations": [
			{"id": "collapsed_service_atrium", "node": "atrium_relay_node", "title": "Relay Cache"},
		],
	},
	"gideon_escort_pilgrim": {
		"giver": "Pipe Father Gideon", "faction": "System X", "objective_type": "escort",
		"short_desc": "A pipe-cult pilgrim wandered too deep and won't move for anyone but a stranger. Walk them out alive.",
		"threat_band": 1, "rival_faction": "Splice", "reward_wan_notes": [16, 22],
		"reward_item_chance": 0.3, "reward_item_pool": ["Cooters Bar Credit", "Chemical Neutralizer"],
		"faction_rep": {"System X": 1},
		"escort_label": "a stranded pilgrim",
		"locations": [
			{"id": "pipe_utility_tunnels", "title": "Pilgrim's Way Out"},
		],
	},
	"vera_escort_resident": {
		"giver": "Vera", "faction": "System X", "objective_type": "escort",
		"short_desc": "A resident is pinned in the bloom and the spores are arguing with their lungs. Get them to the door.",
		"threat_band": 2, "rival_faction": "Splice", "reward_wan_notes": [20, 28],
		"reward_item_chance": 0.3, "reward_item_pool": ["Patch", "Chemical Neutralizer"],
		"reward_cyberware_pool": ["soul_baffle"],
		"faction_rep": {"System X": 1},
		"escort_label": "a trapped resident",
		"locations": [
			{"id": "dead_food_court_bloom", "title": "Bloom Extraction"},
		],
	},
	"torai_escort_debtor": {
		"giver": "Kiki Baja", "faction": "Wan Moa Torai", "objective_type": "escort",
		"short_desc": "Torai wants a debtor back in one piece — they're worth more talking than inventoried. Big Gates disagrees.",
		"threat_band": 2, "rival_faction": "Gatebox", "reward_wan_notes": [22, 30],
		"reward_item_chance": 0.25, "reward_item_pool": ["Cooters Rumor Token"],
		"faction_rep": {"Wan Moa Torai": 1},
		"escort_label": "a Torai debtor",
		"locations": [
			{"id": "collapsed_service_atrium", "title": "Debtor Recovery"},
			{"id": "water_reclamation_cistern", "title": "Debtor Recovery"},
		],
	},
}

# The shuffled board (rolled instances) and the active job instance.
var board_instances: Array = []
var active_job_instance: Dictionary = {}

var QUEST_DEFS: Dictionary = {
	"wake_up_call": {
		"title": "Wake-Up Call",
		"type": "campaign",
		"objectives": [
			{"id": "display_recovered", "text": "Recover the broken display", "required": true},
			{"id": "arm_disabled", "text": "Disable the goon's right arm", "required": true},
			{"id": "coolant_routed", "text": "Route soul coolant (optional)", "required": false},
		],
	},
	"hub_power_restore": {
		"title": "Restore Hub Power",
		"type": "hub",
		"giver": "Mister Static",
		"active_flag": "quest_hub_power_active",
		"done_flag": "hub_power_restored",
		"objectives": [
			{"id": "hub_power_restored", "text": "Repair the generator coupling", "required": true, "done_flag": "hub_power_restored"},
		],
		"objective_text_active": "Hub: repair the generator coupling in the basement.",
		"objective_text_done": "Hub power restored.",
	},
	"hub_lan_restore": {
		"title": "Restore Hub LAN",
		"type": "hub",
		"giver": "Vessel",
		"active_flag": "quest_hub_lan_active",
		"done_flag": "hub_lan_restored",
		"objectives": [
			{"id": "hub_lan_restored", "text": "Restore the LAN tap in the Water Reclamation Cistern", "required": true, "done_flag": "hub_lan_restored"},
		],
		"objective_text_active": "Hub: restore the LAN tap in the Water Reclamation Cistern (east end of the upper walkway).",
		"objective_text_done": "Hub LAN restored.",
	},
	"hub_cistern": {
		"title": "Connect Hub Water",
		"type": "hub",
		"giver": "Vera",
		"active_flag": "quest_hub_cistern_active",
		"done_flag": "hub_cistern_connected",
		"objectives": [
			{"id": "hub_cistern_connected", "text": "Install the water conduit at the cistern junction", "required": true, "done_flag": "hub_cistern_connected"},
		],
		"objective_text_active": "Hub: install the water conduit at the teal mast on the west service ring of the Water Reclamation Cistern, just before the pump room.",
		"objective_text_done": "Hub water connected.",
	},
	"hub_clear_court": {
		"title": "Clear the Court",
		"type": "hub",
		"giver": "Ladderboy",
		"active_flag": "quest_clear_court_active",
		"done_flag": "atrium_cleared",
		"objectives": [
			{"id": "atrium_cleared", "text": "Clear three debris piles in the Collapsed Service Atrium relay deck", "required": true, "done_flag": "atrium_cleared"},
		],
		"objective_text_active": "Hub: travel to the Collapsed Service Atrium and clear three marked debris piles on/near the relay deck.",
		"objective_text_done": "Hub atrium cleared.",
	},
	"hub_store_4": {
		"title": "Claim Store 4",
		"type": "hub",
		"giver": "Velvet Coil",
		"active_flag": "quest_store_4_active",
		"done_flag": "store_4_claimed",
		"objectives": [
			{"id": "store_4_cleared", "text": "Wipe the terminal and clear debris in Store 4", "required": true},
		],
		"objective_text_active": "Hub: wipe the terminal and clear the debris in Store 4.",
		"objective_text_done": "Store 4 claimed.",
	},
	"quest_rocker_fellar": {
		"title": "Rocker Fellar Keep",
		"type": "campaign",
		"giver": "System X",
		"active_flag": "quest_rocker_fellar_active",
		"done_flag": "rocker_fellar_defeated",
		"objectives": [
			{"id": "rocker_fellar_defeated", "text": "Defeat Rocker Fellar in his concert fortress", "required": true, "done_flag": "rocker_fellar_defeated"},
		],
		"objective_text_active": "Descend to Rocker Fellar Keep. Destroy his body parts, shut down the soul batteries, end the concert.",
		"objective_text_done": "Rocker Fellar defeated. The first General has fallen.",
	},
}


func add_item(item_name: String, count := 1) -> void:
	# Wan Notes are the sole currency — virtualized into a dedicated int so they read
	# as a wallet, not a stacked item, while every existing shop/cost path keeps working.
	if item_name == WAN_NOTE_ITEM:
		wan_notes = maxi(wan_notes + count, 0)
		inventory_changed.emit(get_inventory_summary())
		return
	items[item_name] = int(items.get(item_name, 0)) + count
	inventory_changed.emit(get_inventory_summary())


func spend_item(item_name: String, count := 1) -> bool:
	if item_name == WAN_NOTE_ITEM:
		if wan_notes < count:
			return false
		wan_notes -= count
		inventory_changed.emit(get_inventory_summary())
		return true
	if int(items.get(item_name, 0)) < count:
		return false

	items[item_name] = int(items[item_name]) - count
	if int(items[item_name]) <= 0:
		items.erase(item_name)
	inventory_changed.emit(get_inventory_summary())
	return true


func has_item(item_name: String, count := 1) -> bool:
	if item_name == WAN_NOTE_ITEM:
		return wan_notes >= count
	return int(items.get(item_name, 0)) >= count


# ── Wan Note wallet (the sole currency) ─────────────────────────────

func get_wan_notes() -> int:
	return wan_notes


func add_wan_notes(amount: int) -> void:
	add_item(WAN_NOTE_ITEM, amount)


func spend_wan_notes(amount: int) -> bool:
	return spend_item(WAN_NOTE_ITEM, amount)


# Wan Note price to have an implant installed at Velvet Coil, by rarity tier.
const IMPLANT_PRICES := {"common": 8, "uncommon": 16, "rare": 28}

func implant_install_price(implant_id: String) -> int:
	return int(IMPLANT_PRICES.get(str(IMPLANT_TIERS.get(implant_id, "common")), 8))


# Wan Note value Gideon pays to scrap an implant (less than install cost) or a ruined part.
func scrap_value(item_name: String) -> int:
	if SCRAP_VALUES.has(item_name):
		return int(SCRAP_VALUES[item_name])
	if is_implant_item(item_name):
		match str(IMPLANT_TIERS.get(item_name, "common")):
			"rare": return 14
			"uncommon": return 8
			_: return 4
	return 0


# ── Consumables / status effects ────────────────────────────────────

func is_consumable(item_name: String) -> bool:
	return CONSUMABLES.has(item_name)


# Spend one of item_name and apply its effect. Returns a result dict
# {ok, label, log} on success, or {} if the item isn't usable / not held.
func use_consumable(item_name: String) -> Dictionary:
	if not CONSUMABLES.has(item_name) or not has_item(item_name):
		return {}
	var c: Dictionary = CONSUMABLES[item_name]
	spend_item(item_name, 1)

	var heal := float(c.get("heal", 0.0))
	if heal > 0.0:
		player_heal_requested.emit(heal)

	var active_dur := float(c.get("active_duration", 0.0))
	var comedown_dur := float(c.get("comedown_duration", 0.0))
	if active_dur > 0.0 or comedown_dur > 0.0:
		_add_effect(item_name, c)

	effects_changed.emit()
	var log_line := str(c.get("use_log", "used %s" % item_name))
	effect_notice.emit(log_line)
	return {"ok": true, "label": str(c.get("label", item_name)), "log": log_line}


# Public hook so enemies/environment can apply a timed debuff to the player
# (e.g. a Pacification Warden's sedative). Uses the same effect pipeline as drugs.
#   config: {label, active_duration, active_mods, comedown_duration, comedown_mods, log}
func apply_timed_effect(id: String, config: Dictionary) -> void:
	_add_effect(id, config)
	effects_changed.emit()
	var log_line := str(config.get("log", ""))
	if not log_line.is_empty():
		effect_notice.emit(log_line)


func _add_effect(id: String, c: Dictionary) -> void:
	# Re-using the same drug refreshes its timer rather than stacking.
	active_effects = active_effects.filter(func(e): return str(e.get("id", "")) != id)
	var entry := {
		"id": id,
		"label": str(c.get("label", id)),
		"active_mods": (c.get("active_mods", {}) as Dictionary).duplicate(),
		"comedown_mods": (c.get("comedown_mods", {}) as Dictionary).duplicate(),
		"comedown_duration": float(c.get("comedown_duration", 0.0)),
		"comedown_log": str(c.get("comedown_log", "")),
	}
	var active_dur := float(c.get("active_duration", 0.0))
	if active_dur > 0.0:
		entry["phase"] = "active"
		entry["time_left"] = active_dur
	else:
		entry["phase"] = "comedown"
		entry["time_left"] = entry["comedown_duration"]
	active_effects.append(entry)


func _process(delta: float) -> void:
	if active_effects.is_empty():
		return
	var changed := false
	var survivors: Array = []
	for e in active_effects:
		e["time_left"] = float(e["time_left"]) - delta
		if float(e["time_left"]) > 0.0:
			survivors.append(e)
			continue
		# Phase elapsed: active -> comedown, or comedown -> expire.
		if str(e["phase"]) == "active" and float(e["comedown_duration"]) > 0.0:
			e["phase"] = "comedown"
			e["time_left"] = float(e["comedown_duration"])
			survivors.append(e)
			var cl := str(e.get("comedown_log", ""))
			if not cl.is_empty():
				effect_notice.emit(cl)
		changed = true
	active_effects = survivors
	if changed:
		effects_changed.emit()


func get_active_effects() -> Array:
	return active_effects


func _effect_mods_for(e: Dictionary) -> Dictionary:
	return e["active_mods"] if str(e.get("phase", "")) == "active" else e["comedown_mods"]


func _effect_product(key: String) -> float:
	var v := 1.0
	for e in active_effects:
		var mods: Dictionary = _effect_mods_for(e)
		if mods.has(key):
			v *= float(mods[key])
	return v


func _effect_sum(key: String) -> float:
	var v := 0.0
	for e in active_effects:
		var mods: Dictionary = _effect_mods_for(e)
		if mods.has(key):
			v += float(mods[key])
	return v


func get_speed_multiplier() -> float:
	return _effect_product("speed_mult")


func get_reload_multiplier() -> float:
	return _effect_product("reload_mult")


func get_damage_multiplier() -> float:
	return _effect_product("damage_mult")


func get_damage_taken_multiplier() -> float:
	return _effect_product("damage_taken_mult")


func get_hit_chance_bonus() -> float:
	return _effect_sum("hit_chance_bonus")


func get_hack_bonus() -> int:
	return int(round(_effect_sum("hack_bonus")))


func get_wasted_potential_value(item_name: String) -> Dictionary:
	return WASTED_POTENTIAL_VALUES.get(item_name, {}).duplicate(true)


func get_sellable_wasted_potential_items() -> Array:
	var sellable := []
	for item_name in items.keys():
		var id := str(item_name)
		if int(items.get(item_name, 0)) <= 0:
			continue
		if WASTED_POTENTIAL_VALUES.has(id):
			var data: Dictionary = get_wasted_potential_value(id)
			data["item_name"] = id
			data["count"] = int(items[item_name])
			sellable.append(data)
		elif is_implant_item(id):
			# Unwanted dropped implants scrap to Gideon for Wan Notes (less than install cost).
			sellable.append({
				"item_name": id, "count": int(items[item_name]),
				"label": "salvaged %s" % _item_display_name(id),
				"wan_notes": scrap_value(id), "potential": 0,
			})
		elif is_scrap_item(id):
			sellable.append({
				"item_name": id, "count": int(items[item_name]),
				"label": "ruined %s" % id, "wan_notes": scrap_value(id), "potential": 0,
			})
	sellable.sort_custom(func(a, b): return int(a.get("wan_notes", 0)) > int(b.get("wan_notes", 0)))
	return sellable


func get_ladderboy_implant_repair_offers() -> Array:
	var offers := []
	for recipe: Dictionary in LADDERBOY_IMPLANT_REPAIR_RECIPES:
		var broken := str(recipe.get("broken", ""))
		var implant_id := str(recipe.get("implant", ""))
		if broken.is_empty() or implant_id.is_empty():
			continue
		if not CyberneticSurgeryUI.UPGRADE_DB.has(implant_id):
			continue
		if has_cybernetic(implant_id):
			continue
		var db: Dictionary = CyberneticSurgeryUI.UPGRADE_DB[implant_id]
		var implant_name := str(db.get("name", implant_id))
		var slot := str(db.get("slot", "Body"))
		offers.append({
			"item": implant_id,
			"label": "Rebuild: %s" % implant_name,
			"desc": "Ladderboy turns one %s into a usable %s implant for the %s slot.\n\n%s\n\nCoil still has to install it after you buy the bench work." % [
				broken,
				implant_name,
				slot,
				str(db.get("desc", "")),
			],
			"wan_price": int(recipe.get("wan", 0)),
			"cost_items": {broken: 1},
			"count": 1,
		})
	return offers


func sell_highest_wasted_potential_to_gideon() -> Dictionary:
	var sellable := get_sellable_wasted_potential_items()
	if sellable.is_empty():
		return {}
	return sell_wasted_potential_item(str(sellable[0].get("item_name", "")))


# Sell one unit of a specific wasted-potential item to Gideon: pays Wan Notes,
# feeds the Dreaming Generator, and advances the generator quest flags.
func sell_wasted_potential_item(item_name: String) -> Dictionary:
	if item_name.is_empty():
		return {}
	# Scrap path: implants and ruined parts sell for flat Wan Notes (no generator feed).
	if not WASTED_POTENTIAL_VALUES.has(item_name) and (is_implant_item(item_name) or is_scrap_item(item_name)):
		if not spend_item(item_name):
			return {}
		var value := scrap_value(item_name)
		add_wan_notes(value)
		last_mission_result = "Scrapped %s to Gideon for %d Wan Notes" % [_item_display_name(item_name), value]
		inventory_changed.emit(get_inventory_summary())
		return {"item_name": item_name, "label": "scrap", "wan_notes": value, "potential": 0}
	if not WASTED_POTENTIAL_VALUES.has(item_name):
		return {}
	if not spend_item(item_name):
		return {}

	var data := get_wasted_potential_value(item_name)
	var payout := int(data.get("wan_notes", 0))
	var potential := int(data.get("potential", 0))
	add_wan_notes(payout)
	add_dreaming_generator_potential(potential)
	mark_quest_completed("dreaming_generator_fed")
	var new_total := get_dreaming_generator_potential()
	if new_total >= DREAMING_GENERATOR_THRESHOLD:
		mark_quest_completed("patch_dreaming_generator")
		set_world_flag("patch_dreaming_generator", true)
		mark_quest_completed("dreaming_generator_sustained")
	last_mission_result = "Sold %s to Gideon for %d Wan Notes" % [item_name, payout]
	inventory_changed.emit(get_inventory_summary())
	return {
		"item_name": item_name,
		"label": str(data.get("label", "wasted potential")),
		"wan_notes": payout,
		"potential": potential,
		"new_generator_potential": new_total,
	}


func add_dreaming_generator_potential(amount: int) -> int:
	var current := get_dreaming_generator_potential()
	current = clampi(current + amount, 0, DREAMING_GENERATOR_MAX_POTENTIAL)
	set_world_flag(DREAMING_GENERATOR_POTENTIAL_FLAG, current)
	return current


func consume_dreaming_generator_potential(amount: int) -> int:
	var current := get_dreaming_generator_potential()
	current = clampi(current - amount, 0, DREAMING_GENERATOR_MAX_POTENTIAL)
	set_world_flag(DREAMING_GENERATOR_POTENTIAL_FLAG, current)
	return current


func get_dreaming_generator_potential() -> int:
	return int(get_world_flag(DREAMING_GENERATOR_POTENTIAL_FLAG, 30))


func is_dreaming_generator_failing() -> bool:
	return get_dreaming_generator_potential() < DREAMING_GENERATOR_THRESHOLD


func add_reputation(faction_name: String, amount: int) -> void:
	reputation[faction_name] = int(reputation.get(faction_name, 0)) + amount
	reputation_changed.emit(get_faction_summary())


func mark_quest_completed(quest_id: String) -> void:
	completed_quests[quest_id] = true


func is_quest_completed(quest_id: String) -> bool:
	if bool(completed_quests.get(quest_id, false)):
		return true
	var state: Dictionary = quest_states.get(quest_id, {})
	if bool(state.get("completed", false)):
		return true
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	var done_flag := str(def.get("done_flag", ""))
	return not done_flag.is_empty() and bool(get_world_flag(done_flag, false))


const JOB_BOARD_SIZE := 4

# Roll the Cooters board. Jobs refresh once per day (via resting on the cot), so re-entering
# Cooters on the same day keeps the same board. The active job stays off the board.
func build_job_board() -> Array:
	if not board_instances.is_empty() and day == _jobs_built_day:
		return board_instances
	board_instances = []
	_jobs_built_day = day
	var keys: Array = COOTERS_JOB_TEMPLATES.keys()
	keys.shuffle()
	for tid in keys:
		if board_instances.size() >= JOB_BOARD_SIZE:
			break
		if str(tid) == active_job_id:
			continue
		var inst := instance_job(str(tid))
		if not inst.is_empty():
			board_instances.append(inst)
	return board_instances


# Spooky beds down: a day turns over, which rolls a fresh job board. Returns the new day number.
func advance_day() -> int:
	day += 1
	build_job_board()   # day != _jobs_built_day now, so this rerolls
	return day


# Roll a concrete job from a template: pick a location, threat band, contesting faction, and a
# Wan Note reward (items are an occasional bonus). The instance carries the fields destinations
# and the board UI already read.
func instance_job(template_id: String) -> Dictionary:
	var t: Dictionary = COOTERS_JOB_TEMPLATES.get(template_id, {})
	if t.is_empty():
		return {}
	var locs: Array = t.get("locations", [])
	if locs.is_empty():
		return {}
	var loc: Dictionary = locs[randi() % locs.size()]
	var wan_range: Array = t.get("reward_wan_notes", [10, 16])
	var wan := randi_range(int(wan_range[0]), int(wan_range[1]))
	var item := ""
	var pool: Array = t.get("reward_item_pool", [])
	if randf() < float(t.get("reward_item_chance", 0.0)) and not pool.is_empty():
		item = str(pool[randi() % pool.size()])
	# Bonus payout shapes (B2): a guaranteed implant the Coil can install, and/or a world-flag
	# unlock (a discount, a route, a shop opening). Single value or rolled from a *_pool array.
	var cyber := str(t.get("reward_cyberware", ""))
	var cyber_pool: Array = t.get("reward_cyberware_pool", [])
	if cyber.is_empty() and not cyber_pool.is_empty():
		cyber = str(cyber_pool[randi() % cyber_pool.size()])
	var unlock := str(t.get("reward_unlock", ""))
	var unlock_label := str(t.get("reward_unlock_label", ""))
	var otype := str(t.get("objective_type", "find"))
	var dest_id := str(loc.get("id", ""))
	var inst := {
		"id": template_id,
		"giver": str(t.get("giver", "Marbles")),
		"faction": str(t.get("faction", "")),
		"objective_type": otype,
		"title": str(loc.get("title", t.get("giver", "Job"))),
		"short_desc": str(t.get("short_desc", "")),
		"destination": _location_title(dest_id),
		"destination_id": dest_id,
		"threat_band": int(t.get("threat_band", 2)),
		"rival_faction": str(t.get("rival_faction", "")),
		"reward_wan_notes": wan,
		"reward_item": item,
		"reward_cyberware": cyber,
		"reward_unlock": unlock,
		"reward_unlock_label": unlock_label,
		"faction_rep": t.get("faction_rep", {}),
		"event_cards_on_accept": t.get("event_cards_on_accept", []),
		"event_cards_on_complete": t.get("event_cards_on_complete", []),
	}
	match otype:
		"find":
			inst["objective_interactable"] = str(loc.get("node", ""))
			inst["objective_item"] = str(loc.get("item", "the marked item"))
			inst["objective"] = "Recover %s in %s." % [inst["objective_item"], inst["destination"]]
		"kill_loot":
			inst["target_loot"] = str(t.get("target_loot", ""))
			inst["objective"] = "Recover %s from whatever contests %s." % [str(t.get("target_loot_label", "the loot")), inst["destination"]]
		"deliver":
			inst["objective_interactable"] = str(loc.get("node", ""))
			inst["deliver_item"] = str(t.get("deliver_item", ""))
			inst["objective_item"] = str(t.get("deliver_item", ""))   # drop-off node message
			inst["objective"] = "Carry %s to the drop-off in %s." % [inst["deliver_item"], inst["destination"]]
		"escort":
			inst["escort_label"] = str(t.get("escort_label", "the asset"))
			inst["objective"] = "Find %s stranded deep in %s and walk it back to the entrance alive." % [inst["escort_label"], inst["destination"]]
	var bonus := ""
	if not item.is_empty():
		bonus += "  +  " + _item_display_name(item)
	if not cyber.is_empty():
		bonus += "  +  " + _item_display_name(cyber) + " (implant)"
	if not unlock.is_empty():
		bonus += "  +  " + (unlock_label if not unlock_label.is_empty() else "unlock")
	inst["reward_text"] = "%d Wan Notes%s" % [wan, bonus]
	return inst


func _location_title(id: String) -> String:
	match id:
		"pipe_utility_tunnels": return "Pipe Utility Tunnels"
		"dead_food_court_bloom": return "Dead Food Court Bloom"
		"water_reclamation_cistern": return "Water Reclamation Cistern"
		"collapsed_service_atrium": return "Collapsed Service Atrium"
	return id.capitalize()


func get_job_data(job_id: String) -> Dictionary:
	if job_id == active_job_id and not active_job_instance.is_empty():
		var j := active_job_instance.duplicate(true)
		j["status"] = get_job_status(job_id)
		return j
	for b: Dictionary in board_instances:
		if str(b.get("id", "")) == job_id:
			var jb := b.duplicate(true)
			jb["status"] = get_job_status(job_id)
			return jb
	return {}


func get_available_jobs() -> Array:
	if board_instances.is_empty():
		build_job_board()
	var jobs: Array = []
	for inst: Dictionary in board_instances:
		var j: Dictionary = inst.duplicate(true)
		j["status"] = get_job_status(str(inst.get("id", "")))
		jobs.append(j)
	return jobs


func accept_job(template_id: String) -> bool:
	if not active_job_id.is_empty():
		return false
	var inst: Dictionary = {}
	for b: Dictionary in board_instances:
		if str(b.get("id", "")) == template_id:
			inst = b.duplicate(true)
			break
	if inst.is_empty():
		inst = instance_job(template_id)
	if inst.is_empty():
		return false
	active_job_id = template_id
	active_job_instance = inst
	active_job_run_id += 1
	active_job_instance["run_id"] = active_job_run_id
	job_flags.erase(_objective_flag(template_id))
	# Drive the contested-location enemy spawns (EnemyLayouts reads these).
	set_world_flag("_active_threat_band", int(inst.get("threat_band", 2)))
	set_world_flag("_active_rival_faction", str(inst.get("rival_faction", "")))
	# Deliver jobs hand you the parcel up front.
	if str(inst.get("objective_type", "")) == "deliver":
		var di := str(inst.get("deliver_item", ""))
		if not di.is_empty():
			add_item(di)
	for card_id: String in inst.get("event_cards_on_accept", []):
		var card := WorldDirector.get_named_card(str(card_id))
		if not card.is_empty():
			EventDeckSystem.add_card(card)
	# Auto-link faction event chains: the giver may demand a cut on the way out, the contesting
	# (rival) faction may ambush en route. (Cards expire after one fire.)
	_seed_event_card(_faction_demand_card(str(inst.get("faction", ""))))
	_seed_event_card(_faction_ambush_card(str(inst.get("rival_faction", ""))))
	# The contesting faction also shakes you down on the way in — for Gatebox-contested jobs this
	# is the checkpoint where complying earns Gatebox standing (the path toward the Comfort Annexe).
	_seed_event_card(_faction_demand_card(str(inst.get("rival_faction", ""))))
	last_mission_result = "Accepted job from %s: %s" % [str(inst.get("giver", "Marbles")), str(inst.get("title", template_id))]
	return true


func _seed_event_card(card_id: String) -> void:
	if card_id.is_empty():
		return
	var card := WorldDirector.get_named_card(card_id)
	if not card.is_empty():
		EventDeckSystem.add_card(card)


# The contesting faction's intercept on the way out (a demand from the giver's people).
func _faction_demand_card(faction: String) -> String:
	match faction:
		"Wan Moa Torai": return "torai_demand_core"
		"Gatebox", "Gatebox Corporation": return "gatebox_checkpoint"
		_: return ""


# The rival faction's en-route ambush.
func _faction_ambush_card(faction: String) -> String:
	match faction:
		"Splice": return "splice_ambush"
		"Gatebox", "Gatebox Corporation": return "gatebox_enforcers"
		"Big Gates", "Big Gates Foundation": return "biggates_harvesters"
		"Wan Moa Torai": return "torai_ambush"
		_: return ""


# A grateful follow-up from the giver, seen back at the Atrium after the job.
func _faction_gift_card(faction: String) -> String:
	match faction:
		"System X": return "systemx_tipoff"
		"Wan Moa Torai": return "torai_gift"
		"Gatebox", "Gatebox Corporation": return "gatebox_commendation"
		"Big Gates", "Big Gates Foundation": return "biggates_recruiter"
		_: return "grateful_resident_gift"


func clear_active_job() -> void:
	active_job_id = ""
	active_job_instance = {}
	set_world_flag("_active_threat_band", 2)
	set_world_flag("_active_rival_faction", "")


func abandon_active_job() -> bool:
	if active_job_id.is_empty():
		return false
	EventDeckSystem.remove_cards_by_tag(active_job_id + "_active")
	last_mission_result = "Abandoned job: %s" % str(active_job_instance.get("title", active_job_id))
	clear_active_job()
	return true


func get_active_job_data() -> Dictionary:
	if active_job_id.is_empty():
		return {}
	return get_job_data(active_job_id)


func get_active_job_run_key() -> String:
	if active_job_id.is_empty():
		return ""
	var run_id := int(active_job_instance.get("run_id", active_job_run_id))
	if run_id <= 0:
		return active_job_id
	return "%s:%d" % [active_job_id, run_id]


func get_job_status(job_id: String) -> String:
	if active_job_id == job_id:
		return "ready for payout" if is_job_objective_done(job_id) else "active"
	if not active_job_id.is_empty():
		return "unavailable"
	return "available"


func is_job_completed(_job_id: String) -> bool:
	return false   # templates are repeatable; no permanent completion


func mark_job_objective_done(job_id: String) -> void:
	if job_id.is_empty() or job_id != active_job_id:
		return
	job_flags[_objective_flag(job_id)] = true


func is_job_objective_done(job_id: String) -> bool:
	if job_id != active_job_id or active_job_instance.is_empty():
		return false
	if str(active_job_instance.get("objective_type", "find")) == "kill_loot":
		return has_item(str(active_job_instance.get("target_loot", "")))
	return bool(job_flags.get(_objective_flag(job_id), false))


func complete_active_job() -> Dictionary:
	if active_job_id.is_empty() or active_job_instance.is_empty():
		return {}
	if not is_job_objective_done(active_job_id):
		return {}
	var inst := active_job_instance.duplicate(true)
	var otype := str(inst.get("objective_type", "find"))
	# Hand over the proof of the work.
	if otype == "kill_loot":
		spend_item(str(inst.get("target_loot", "")))
	elif otype == "deliver":
		var di := str(inst.get("deliver_item", ""))
		if not has_item(di):
			return {}   # lost the parcel — no payout
		spend_item(di, int(items.get(di, 0)))   # hand over every copy you're carrying
	# Pay out: Wan Notes primary, an occasional item, plus faction rep.
	add_wan_notes(int(inst.get("reward_wan_notes", 0)))
	var item := str(inst.get("reward_item", ""))
	if not item.is_empty():
		add_item(item)
	# Bonus rewards (B2): a carried implant (installable at the Coil) and/or a world-flag unlock.
	var cyber := str(inst.get("reward_cyberware", ""))
	if not cyber.is_empty() and is_implant_item(cyber):
		add_item(cyber)
	var unlock := str(inst.get("reward_unlock", ""))
	if not unlock.is_empty():
		set_world_flag(unlock, true)
	var rep: Dictionary = inst.get("faction_rep", {})
	for fac in rep.keys():
		add_reputation(str(fac), int(rep[fac]))
	EventDeckSystem.remove_cards_by_tag(active_job_id + "_active")
	for card_id: String in inst.get("event_cards_on_complete", []):
		var card := WorldDirector.get_named_card(str(card_id))
		if not card.is_empty():
			EventDeckSystem.add_card(card)
	# A grateful follow-up from the giver faction will surface next time you reach the Atrium.
	_seed_event_card(_faction_gift_card(str(inst.get("faction", ""))))
	last_mission_result = "Completed job: %s (+%d Wan)" % [str(inst.get("title", "job")), int(inst.get("reward_wan_notes", 0))]
	# Drift Syphon bleeds accumulated strangeness into the generator on each closed job.
	if has_cybernetic("drift_syphon") and drift > 0:
		var bled := mini(drift, 8)
		reduce_drift(bled)
		add_dreaming_generator_potential(bled)
		effect_notice.emit("Drift Syphon vented %d drift into the Dreaming Generator." % bled)
	clear_active_job()
	return inst


func get_active_job_objective_text() -> String:
	if active_job_id.is_empty() or active_job_instance.is_empty():
		return ""
	if is_job_objective_done(active_job_id):
		return "Return to Marbles for payment: %s." % str(active_job_instance.get("title", "job"))
	return str(active_job_instance.get("objective", "Complete the active job."))


func set_world_flag(flag_name: String, value = true) -> void:
	world_flags[flag_name] = value


func get_world_flag(flag_name: String, default_value = false):
	return world_flags.get(flag_name, default_value)


# ── Dialogue system helpers ─────────────────────────────────────────

# ── Loot rolls (refactor §2) ────────────────────────────────────────

# Rolls an enemy's drops given which part display_names are still intact at death.
# Returns a list of item ids to spawn. Implant is weighted toward intact parts and is rare;
# scrap is more common; specials (e.g. neural_splice) roll independently.
func roll_loot(loot_id: String, intact_parts: Array) -> Array:
	var drops: Array = []
	var prof: Dictionary = ENEMY_LOOT.get(loot_id, {})
	if prof.is_empty():
		return drops
	# Implant drop — only from parts left unbroken.
	var part_map: Dictionary = prof.get("parts", {})
	var candidates: Array = []
	for part_name in part_map.keys():
		if intact_parts.has(part_name):
			candidates.append(str(part_map[part_name]))
	if not candidates.is_empty() and randf() < float(prof.get("drop_chance", 0.25)):
		var pick := _weighted_implant(candidates)
		if not pick.is_empty():
			drops.append(pick)
	# Scrap — more common.
	var scrap: Array = prof.get("scrap", [])
	if not scrap.is_empty() and randf() < float(prof.get("scrap_chance", 0.4)):
		drops.append(str(scrap[randi() % scrap.size()]))
	# Specials — independent rolls.
	for sp in prof.get("special", []):
		if typeof(sp) == TYPE_DICTIONARY and randf() < float((sp as Dictionary).get("chance", 0.0)):
			var item := str((sp as Dictionary).get("item", ""))
			if not item.is_empty():
				drops.append(item)
	return drops


func _weighted_implant(ids: Array) -> String:
	var total := 0
	var weights: Array = []
	for id in ids:
		var w := _tier_weight(str(id))
		weights.append(w)
		total += w
	if total <= 0:
		return str(ids[0]) if not ids.is_empty() else ""
	var r := randi_range(1, total)
	var cursor := 0
	for i in ids.size():
		cursor += int(weights[i])
		if r <= cursor:
			return str(ids[i])
	return str(ids[0])


func _tier_weight(implant_id: String) -> int:
	match str(IMPLANT_TIERS.get(implant_id, "common")):
		"rare": return 1
		"uncommon": return 2
		_: return 4


# Threat band + contesting faction for the location being entered. Set by the active job (P5);
# defaults give a moderate, varied "contested location" feel before quests drive them.
func get_active_threat_band() -> int:
	return int(get_world_flag("_active_threat_band", 2))


func get_active_rival_faction() -> String:
	return str(get_world_flag("_active_rival_faction", ""))


func is_implant_item(item_name: String) -> bool:
	return CyberneticSurgeryUI.UPGRADE_DB.has(item_name)


func is_scrap_item(item_name: String) -> bool:
	return SCRAP_VALUES.has(item_name)


# ── Enemy compendium / bestiary (refactor: GhostTerm CODEX tab) ──────
# Progressive reveal: killing a species more times unlocks more of its entry.
const BESTIARY_TIER_NAMED := 1      # name + sprite
const BESTIARY_TIER_WEAKPOINTS := 3 # weak-point list + break effects
const BESTIARY_TIER_DROPS := 6      # which items it can drop
const BESTIARY_TIER_PERCENTS := 10  # exact drop chances

# Rank-and-file roster. Drops/percentages are read live from ENEMY_LOOT[loot_id] (one source of
# truth); loot_id "" means the unit yields no salvage. sprite "" falls back to a placeholder panel.
var BESTIARY: Dictionary = {
	"splice": {
		"name": "Splice", "faction": "Splice", "loot_id": "splice",
		"sprite": "res://assets/sprites/splice/splice_front.png",
		"weak_points": [
			{"part": "Wire Skull", "effect": "Staggers the Splice when cracked."},
			{"part": "Graft Shell", "effect": "Core plating — destroying it puts the Splice down."},
			{"part": "Splice Arm", "effect": "Breaking it sends the Splice into a brief berserk."},
			{"part": "Drag Frame", "effect": "Wrecking the legs slows it to a crawl."},
		],
	},
	"goon": {
		"name": "Gatebox Goon", "faction": "Gatebox", "loot_id": "gatebox",
		"sprite": "res://assets/sprites/goon_material/goon_material_front.png",
		"weak_points": [
			{"part": "Head", "effect": "Heavy hits here stagger it."},
			{"part": "Right Arm", "effect": "Disables its trash-cannon ranged fire."},
			{"part": "Torso", "effect": "Core mass — destroying it drops the goon."},
			{"part": "Left Arm / Legs", "effect": "Reduces its melee and mobility."},
		],
	},
	"gatebox_android": {
		"name": "Gatebox Sentinel", "faction": "Gatebox", "loot_id": "gatebox",
		"sprite": "res://assets/sprites/goon_material/goon_material_front.png",
		"weak_points": [
			{"part": "Torso", "effect": "Fast but fragile — core hits put it down quickly."},
			{"part": "Legs", "effect": "Kills its closing speed, its main threat."},
		],
	},
	"foundation_enforcer": {
		"name": "Foundation Enforcer", "faction": "Big Gates", "loot_id": "big_gates",
		"sprite": "res://assets/sprites/goon_material/goon_material_front.png",
		"weak_points": [
			{"part": "Head", "effect": "Staggers the heavy."},
			{"part": "Torso", "effect": "Reinforced — destroying it ends the fight."},
			{"part": "Arms / Legs", "effect": "Cuts its heavy melee and advance."},
		],
	},
	"tithe_servitor": {
		"name": "Tithe Servitor", "faction": "Big Gates", "loot_id": "big_gates",
		"sprite": "res://assets/sprites/goon_material/goon_material_front.png",
		"weak_points": [
			{"part": "Torso", "effect": "Lightly built fodder — folds fast."},
			{"part": "Head", "effect": "Staggers it."},
		],
	},
	"security_node": {
		"name": "Security Node", "faction": "Gatebox", "loot_id": "",
		"sprite": "",
		"weak_points": [
			{"part": "Lens", "effect": "Blinds it — drops its accuracy."},
			{"part": "Antenna", "effect": "Severs its alarm/coordination."},
			{"part": "Core", "effect": "Destroys the turret outright."},
		],
	},
	"soul_drone": {
		"name": "Soul Harvester Drone", "faction": "Big Gates", "loot_id": "",
		"sprite": "",
		"weak_points": [
			{"part": "Lens", "effect": "Cripples its targeting."},
			{"part": "Core", "effect": "Destroys the drone."},
		],
	},
	"ward_graft": {
		"name": "Ward Resident Graft", "faction": "Big Gates", "loot_id": "",
		"sprite": "",
		"weak_points": [
			{"part": "Graft — Right Arm", "effect": "The weapon graft — breaking it disarms the assault."},
			{"part": "Conversion Rig — Torso", "effect": "The bolted-on rig; destroying it ends the wretch."},
			{"part": "Head", "effect": "What's left of the person — staggers it."},
		],
	},
	"rain_mutant": {
		"name": "Rain Mutant", "faction": "", "loot_id": "",
		"sprite": "res://assets/sprites/rain_mutant/rain_mutant_front.png",
		"weak_points": [
			{"part": "Rain Sac", "effect": "Rupture it to stop the mutant drinking the toxic rain."},
			{"part": "Mobility Frame", "effect": "Break it so the thing can't crawl off the pad."},
		],
	},
}


func record_kill(species_id: String) -> void:
	if species_id.is_empty():
		return
	bestiary_kills[species_id] = int(bestiary_kills.get(species_id, 0)) + 1


func get_kills(species_id: String) -> int:
	return int(bestiary_kills.get(species_id, 0))


# 0 = unseen, then named / weak-points / drops / percentages as kills accrue.
func bestiary_tier(species_id: String) -> int:
	var k := get_kills(species_id)
	if k <= 0:
		return 0
	if k >= BESTIARY_TIER_PERCENTS:
		return 4
	if k >= BESTIARY_TIER_DROPS:
		return 3
	if k >= BESTIARY_TIER_WEAKPOINTS:
		return 2
	return 1


# Kills still needed before the next reveal tier (0 if fully unlocked).
func bestiary_kills_to_next(species_id: String) -> int:
	var k := get_kills(species_id)
	for threshold in [BESTIARY_TIER_NAMED, BESTIARY_TIER_WEAKPOINTS, BESTIARY_TIER_DROPS, BESTIARY_TIER_PERCENTS]:
		if k < threshold:
			return threshold - k
	return 0


# Display lines for an enemy's drops. with_percents adds the exact chances (top reveal tier).
func bestiary_drop_lines(species_id: String, with_percents: bool) -> Array:
	var lines: Array = []
	var entry: Dictionary = BESTIARY.get(species_id, {})
	var loot_id := str(entry.get("loot_id", ""))
	var prof: Dictionary = ENEMY_LOOT.get(loot_id, {})
	if loot_id.is_empty() or prof.is_empty():
		lines.append("No salvage — this unit leaves nothing recoverable.")
		return lines
	# Implants (only from body parts you leave INTACT).
	var part_map: Dictionary = prof.get("parts", {})
	if not part_map.is_empty():
		if with_percents:
			lines.append("Cyberware drop: %d%% (from a part you leave intact)" % roundi(float(prof.get("drop_chance", 0.0)) * 100.0))
		else:
			lines.append("Cyberware drop (leave the part intact):")
		for part_name in part_map.keys():
			lines.append("   • %s → %s" % [str(part_name), _item_display_name(str(part_map[part_name]))])
	# Scrap.
	var scrap: Array = prof.get("scrap", [])
	if not scrap.is_empty():
		var scrap_names: Array = []
		for s in scrap:
			scrap_names.append(str(s))
		if with_percents:
			lines.append("Ruined parts: %d%% — %s" % [roundi(float(prof.get("scrap_chance", 0.0)) * 100.0), ", ".join(scrap_names)])
		else:
			lines.append("Ruined parts: %s" % ", ".join(scrap_names))
	# Specials (e.g. neural_splice).
	for sp in prof.get("special", []):
		if typeof(sp) != TYPE_DICTIONARY:
			continue
		var item := str((sp as Dictionary).get("item", ""))
		if item.is_empty():
			continue
		if with_percents:
			lines.append("Special: %s — %d%%" % [_item_display_name(item), roundi(float((sp as Dictionary).get("chance", 0.0)) * 100.0)])
		else:
			lines.append("Special: %s" % _item_display_name(item))
	return lines


func learn_topic(topic_id: String) -> void:
	if topic_id.is_empty():
		return
	known_topics[topic_id] = true


func has_topic(topic_id: String) -> bool:
	return bool(known_topics.get(topic_id, false))


# Disposition 0..100, seeded from the NPC's faction standing on first contact, then stored.
func get_disposition(npc_id: String, faction := "") -> int:
	if not npc_disposition.has(npc_id):
		npc_disposition[npc_id] = _seed_disposition(faction)
	return int(npc_disposition[npc_id])


func adjust_disposition(npc_id: String, delta: int, faction := "") -> int:
	var current := get_disposition(npc_id, faction)
	current = clampi(current + delta, 0, 100)
	npc_disposition[npc_id] = current
	return current


func _seed_disposition(faction: String) -> int:
	# Neutral 50, shifted by your standing with the NPC's faction (capped +/-30).
	if faction.is_empty():
		return 50
	var rep := int(reputation.get(faction, 0))
	return clampi(50 + clampi(rep * 5, -30, 30), 0, 100)


# Maps a 0..100 disposition to the three authoring tiers used by NPC profiles.
func disposition_tier(value: int) -> String:
	if value >= 70:
		return "warm"
	if value >= 35:
		return "neutral"
	return "cold"


func add_cybernetic(upgrade_id: String, drift_amount: int = 0) -> void:
	cybernetics[upgrade_id] = true
	if drift_amount != 0:
		add_drift(drift_amount)
	cybernetics_changed.emit()


func has_cybernetic(upgrade_id: String) -> bool:
	return bool(cybernetics.get(upgrade_id, false))


# ── Drift ───────────────────────────────────────────────────────────

func add_drift(amount: int) -> int:
	var effective := amount
	# Spine Relay routes the cybernetics through one bus, halving new drift gain.
	if amount > 0 and has_cybernetic("spine_relay"):
		effective = int(ceil(float(amount) * 0.5))
	drift = clampi(drift + effective, 0, DRIFT_MAX)
	_apply_drift_thresholds()
	cybernetics_changed.emit()
	return drift


func reduce_drift(amount: int) -> int:
	drift = clampi(drift - amount, 0, DRIFT_MAX)
	_apply_drift_thresholds()
	cybernetics_changed.emit()
	return drift


func get_drift() -> int:
	return drift


func add_soul_rot(amount: int) -> int:
	soul_rot = clampi(soul_rot + amount, 0, SOUL_ROT_MAX)
	cybernetics_changed.emit()  # STAT tab / soul anchor status refresh
	return soul_rot


func get_soul_rot() -> int:
	return soul_rot


func add_gatebox_attention(amount: int) -> int:
	gatebox_attention_level = maxi(gatebox_attention_level + amount, 0)
	return gatebox_attention_level


func get_drift_descriptor() -> String:
	if drift >= 81:
		return "uncanny"
	if drift >= 61:
		return "flagged"
	if drift >= 41:
		return "unsettling"
	if drift >= 21:
		return "noticed"
	return "human enough"


func _apply_drift_thresholds() -> void:
	set_world_flag(DRIFT_FLAG_NOTICED, drift >= 21)
	set_world_flag(DRIFT_FLAG_UNCANNY, drift >= 41)
	set_world_flag(DRIFT_FLAG_SCANNED, drift >= 61)
	set_world_flag(DRIFT_FLAG_HIGH, drift >= 81)


func get_inventory_summary() -> String:
	var wallet := "WAN %d" % wan_notes
	if items.is_empty():
		return wallet + "   ·   INVENTORY  empty"

	var parts: Array[String] = []
	for item_name in items.keys():
		parts.append("%s x%d" % [_item_display_name(str(item_name)), items[item_name]])
	return wallet + "   ·   INVENTORY  " + ", ".join(parts)


# Implants are stored under their machine id; show the readable name in the inventory line.
func _item_display_name(item_name: String) -> String:
	if CyberneticSurgeryUI.UPGRADE_DB.has(item_name):
		return str((CyberneticSurgeryUI.UPGRADE_DB[item_name] as Dictionary).get("name", item_name))
	return item_name


func get_faction_summary() -> String:
	return "REP  System X %+d  Gatebox %+d  Torai %+d" % [
		int(reputation.get("System X", reputation.get("Sub-Basement Resistance", 0))),
		int(reputation.get("Gatebox Corporation", 0)),
		int(reputation.get("Wan Moa Torai", 0)),
	]


func get_cybernetic_summary() -> String:
	if cybernetics.is_empty():
		return "CYBERNETICS  none"

	var names: Array[String] = []
	for upgrade_id in cybernetics.keys():
		if bool(cybernetics[upgrade_id]):
			names.append(_display_upgrade_name(upgrade_id))
	return "CYBERNETICS  " + ", ".join(names)


func mark_enemy_defeated(enemy_key: String) -> void:
	if enemy_key.is_empty():
		return
	defeated_enemies[enemy_key] = true


func is_enemy_defeated(enemy_key: String) -> bool:
	if enemy_key.is_empty():
		return false
	return bool(defeated_enemies.get(enemy_key, false))


func has_save_file(slot := SAVE_SLOT_MANUAL) -> bool:
	return FileAccess.file_exists(_save_path_for_slot(slot))


func has_any_save_file() -> bool:
	for slot in [SAVE_SLOT_MANUAL, SAVE_SLOT_QUICK, SAVE_SLOT_AUTO]:
		if has_save_file(slot):
			return true
	return false


func get_latest_save_slot() -> String:
	var best_slot := ""
	var best_time := -1
	for slot in [SAVE_SLOT_MANUAL, SAVE_SLOT_QUICK, SAVE_SLOT_AUTO]:
		var path := _save_path_for_slot(slot)
		if not FileAccess.file_exists(path):
			continue
		var modified := FileAccess.get_modified_time(path)
		if modified > best_time:
			best_time = modified
			best_slot = slot
	return best_slot


func save_game(slot := SAVE_SLOT_MANUAL) -> bool:
	_capture_location()
	var data := {
		"save_slot": str(slot),
		"saved_at": Time.get_unix_time_from_system(),
		"location": {
			"scene": saved_scene_path,
			"x": _save_px, "y": _save_py, "z": _save_pz,
			"yaw": _save_pyaw, "hp": _save_php,
		},
		"items": items,
		"wan_notes": wan_notes,
		"reputation": reputation,
		"completed_quests": completed_quests,
		"day": day,
		"active_job_id": active_job_id,
		"active_job_run_id": active_job_run_id,
		"active_job_instance": active_job_instance,
		"board_instances": board_instances,
		"available_jobs": available_jobs,
		"completed_jobs": completed_jobs,
		"job_flags": job_flags,
		"world_flags": world_flags,
		"quest_states": quest_states,
		"cybernetics": cybernetics,
		"defeated_enemies": defeated_enemies,
		"bestiary_kills": bestiary_kills,
		"known_topics": known_topics,
		"npc_disposition": npc_disposition,
		"conversation_tone": conversation_tone,
		"attributes": attributes,
		"drift": drift,
		"soul_rot": soul_rot,
		"gatebox_attention_level": gatebox_attention_level,
		"last_mission_result": last_mission_result,
		"event_deck": EventDeckSystem.get_deck_for_save(),
	}
	var file := FileAccess.open(_save_path_for_slot(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func quicksave() -> bool:
	return save_game(SAVE_SLOT_QUICK)


func autosave() -> bool:
	return save_game(SAVE_SLOT_AUTO)


func load_game(slot := SAVE_SLOT_MANUAL) -> bool:
	var path := _save_path_for_slot(slot)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	items = parsed.get("items", {})
	wan_notes = int(parsed.get("wan_notes", 0))
	# Migrate any legacy Wan Notes that were stored as an inventory item into the wallet int.
	if items.has(WAN_NOTE_ITEM):
		wan_notes += int(items.get(WAN_NOTE_ITEM, 0))
		items.erase(WAN_NOTE_ITEM)
	reputation = parsed.get("reputation", reputation)
	_migrate_reputation_keys()
	completed_quests = parsed.get("completed_quests", {})
	day = int(parsed.get("day", 1))
	active_job_id = str(parsed.get("active_job_id", ""))
	active_job_run_id = int(parsed.get("active_job_run_id", 0))
	active_job_instance = parsed.get("active_job_instance", {})
	board_instances = parsed.get("board_instances", [])
	_jobs_built_day = day   # keep the restored board for the current day (no reshuffle on load)
	available_jobs = parsed.get("available_jobs", COOTERS_JOBS.keys())
	for job_id in COOTERS_JOBS.keys():
		if not available_jobs.has(job_id):
			available_jobs.append(job_id)
	completed_jobs = parsed.get("completed_jobs", {})
	job_flags = parsed.get("job_flags", {})
	world_flags = parsed.get("world_flags", {})
	quest_states = parsed.get("quest_states", {})
	_repair_loaded_save_inconsistencies()
	cybernetics = parsed.get("cybernetics", {})
	defeated_enemies = parsed.get("defeated_enemies", {})
	bestiary_kills = parsed.get("bestiary_kills", {})
	known_topics = parsed.get("known_topics", {})
	npc_disposition = parsed.get("npc_disposition", {})
	conversation_tone = str(parsed.get("conversation_tone", "normal"))
	attributes = parsed.get("attributes", attributes)
	drift = int(parsed.get("drift", 0))
	soul_rot = int(parsed.get("soul_rot", 0))
	gatebox_attention_level = int(parsed.get("gatebox_attention_level", 0))
	_apply_drift_thresholds()
	last_mission_result = str(parsed.get("last_mission_result", ""))
	EventDeckSystem.restore_from_save(parsed.get("event_deck", []))

	var loc: Dictionary = parsed.get("location", {}) if typeof(parsed.get("location")) == TYPE_DICTIONARY else {}
	saved_scene_path = str(loc.get("scene", ""))
	_save_px = float(loc.get("x", 0.0))
	_save_py = float(loc.get("y", 0.0))
	_save_pz = float(loc.get("z", 0.0))
	_save_pyaw = float(loc.get("yaw", 0.0))
	_save_php = float(loc.get("hp", 100.0))
	_has_saved_location = not saved_scene_path.is_empty()
	_is_dead = false
	_load_restore_pending = true
	# Drop the player back where they saved once the current frame settles. For a
	# same-scene load this just teleports; for a different scene it travels there.
	call_deferred("_apply_loaded_location")
	return true


func load_latest_save() -> bool:
	var slot := get_latest_save_slot()
	if slot.is_empty():
		return false
	return load_game(slot)


func describe_save_slot(slot: String) -> String:
	var path := _save_path_for_slot(slot)
	if not FileAccess.file_exists(path):
		return "%s  EMPTY" % _save_slot_label(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "%s  UNREADABLE" % _save_slot_label(slot)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "%s  CORRUPT" % _save_slot_label(slot)
	var loc: Dictionary = parsed.get("location", {}) if typeof(parsed.get("location")) == TYPE_DICTIONARY else {}
	var scene_name := str(loc.get("scene", "unknown")).get_file().get_basename()
	var saved_at := int(parsed.get("saved_at", 0))
	var time_text := "unknown time"
	if saved_at > 0:
		var dt := Time.get_datetime_dict_from_unix_time(saved_at)
		time_text = "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	return "%s  %s  %s" % [_save_slot_label(slot), scene_name, time_text]


func start_new_game() -> void:
	_reset_runtime_state()
	_new_game_intro_pending = true
	get_tree().change_scene_to_file("res://scenes/levels/MallHub.tscn")


func consume_new_game_intro_pending() -> bool:
	if not _new_game_intro_pending:
		return false
	_new_game_intro_pending = false
	return true


func _save_path_for_slot(slot) -> String:
	match str(slot):
		SAVE_SLOT_AUTO:
			return AUTO_SAVE_PATH
		SAVE_SLOT_QUICK:
			return QUICK_SAVE_PATH
		_:
			return SAVE_PATH


func _save_slot_label(slot: String) -> String:
	match slot:
		SAVE_SLOT_AUTO:
			return "AUTOSAVE"
		SAVE_SLOT_QUICK:
			return "QUICKSAVE"
		_:
			return "MANUAL"


func _reset_runtime_state() -> void:
	items = {}
	wan_notes = 0
	reputation = {
		"System X": 0,
		"Gatebox Corporation": 0,
		"Wan Moa Torai": 0,
		"Linda": 0,
	}
	completed_quests = {}
	day = 1
	_jobs_built_day = 0
	active_job_id = ""
	active_job_run_id = 0
	active_job_instance = {}
	board_instances = []
	available_jobs = [
		"pipe_blood_sample",
		"ratchet_saint",
		"listen_to_the_pipes",
		"food_court_filter",
		"cistern_pump_heart",
		"atrium_relay_echo",
	]
	completed_jobs = {}
	job_flags = {}
	last_mission_result = ""
	world_flags = {}
	quest_states = {}
	cybernetics = {}
	defeated_enemies = {}
	known_topics = {}
	npc_disposition = {}
	conversation_tone = "normal"
	attributes = {
		"STR": 2, "AGL": 3, "CON": 2,
		"INT": 4, "PER": 3, "WIL": 2,
		"EMP": 1, "LUCK": 2,
	}
	drift = 0
	soul_rot = 0
	gatebox_attention_level = 0
	active_effects = []
	saved_scene_path = ""
	_save_px = 0.0
	_save_py = 0.0
	_save_pz = 0.0
	_save_pyaw = 0.0
	_save_php = 100.0
	_has_saved_location = false
	_is_dead = false
	_force_reload_pending = false
	_load_restore_pending = false
	_new_game_intro_pending = false
	EventDeckSystem.restore_from_save([])
	inventory_changed.emit(get_inventory_summary())
	reputation_changed.emit(get_faction_summary())
	effects_changed.emit()


func _repair_loaded_save_inconsistencies() -> void:
	for quest_id in QUEST_DEFS.keys():
		if is_quest_completed(str(quest_id)):
			completed_quests[str(quest_id)] = true
			if quest_states.has(quest_id):
				quest_states[quest_id]["completed"] = true
	if bool(world_flags.get("hub_cistern_connected", false)) and not bool(completed_quests.get("hub_cistern", false)):
		world_flags["hub_cistern_connected"] = false
		start_quest("hub_cistern")
		last_mission_result = "Recovered bad cistern state: conduit still needs seating"


# ── Save location ───────────────────────────────────────────────────

func _capture_location() -> void:
	var scene := get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		saved_scene_path = scene.scene_file_path
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		_save_px = p.global_position.x
		_save_py = p.global_position.y
		_save_pz = p.global_position.z
		_save_pyaw = p.rotation.y
		var ph := p.find_child("PlayerHealth", true, false)
		if ph != null and "current_hp" in ph:
			_save_php = float(ph.current_hp)


func _apply_loaded_location() -> void:
	var force := _force_reload_pending
	_force_reload_pending = false
	# Legacy saves without a stored spot: leave the player where they are.
	if not _has_saved_location and not force:
		return
	var cur := ""
	if get_tree().current_scene != null:
		cur = get_tree().current_scene.scene_file_path
	var target := saved_scene_path
	if target.is_empty():
		target = cur
	if force or (not target.is_empty() and target != cur):
		_begin_travel(target)
	else:
		_teleport_player_to_save()


func _begin_travel(target: String) -> void:
	get_tree().change_scene_to_file(target)
	_apply_spawn_when_ready(target)


# Coroutine: wait for the destination scene to finish loading, then place the player.
func _apply_spawn_when_ready(target: String) -> void:
	for _i in 16:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == target:
			await get_tree().process_frame  # let the level's _ready spawn the player
			_teleport_player_to_save()
			return


func _teleport_player_to_save() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	# Only override position when we actually have a stored spot (legacy saves don't).
	if _has_saved_location:
		p.global_position = Vector3(_save_px, _save_py, _save_pz)
		p.rotation.y = _save_pyaw
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
	var ph := p.find_child("PlayerHealth", true, false)
	if ph != null and "current_hp" in ph:
		# Never restore into a dead body; a checkpoint always leaves you standing.
		var max_hp := float(ph.max_hp)
		ph.current_hp = clampf(_save_php, 1.0, max_hp)
		ph.health_changed.emit(ph.current_hp, max_hp)
	_load_restore_pending = false


func consume_load_restore_pending() -> bool:
	if not _load_restore_pending:
		return false
	_load_restore_pending = false
	return true


# ── Death & respawn ─────────────────────────────────────────────────

func notify_player_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	player_died.emit()


func clear_death() -> void:
	_is_dead = false


# Reload the last save and force the destination scene to rebuild (so enemies,
# hazards, and pickups reset). Returns false when there's no save to fall back on.
func respawn_from_save() -> bool:
	if not has_any_save_file():
		return false
	if not load_latest_save():
		return false
	_force_reload_pending = true
	return true


func _display_upgrade_name(upgrade_id: String) -> String:
	match upgrade_id:
		"targeting_coprocessor":
			return "Targeting Co-Processor"
		"gatebox_eye_mk1":
			return "Gatebox Eye MK1"
		"black_market_armature":
			return "Black-Market Armature"
		"pipewalker_legs":
			return "Pipewalker Legs"
		"soul_baffle":
			return "Soul Baffle"
		_:
			return upgrade_id.capitalize()


func _migrate_reputation_keys() -> void:
	if reputation.has("Sub-Basement Resistance") and not reputation.has("System X"):
		reputation["System X"] = reputation["Sub-Basement Resistance"]
	if not reputation.has("Wan Moa Torai"):
		reputation["Wan Moa Torai"] = 0
	if not reputation.has("Linda"):
		reputation["Linda"] = 0


func _objective_flag(job_id: String) -> String:
	return "%s_objective_done" % job_id


# ── Unified quest system ────────────────────────────────────────────

func start_quest(quest_id: String) -> bool:
	if not QUEST_DEFS.has(quest_id):
		return false
	if not quest_states.has(quest_id):
		quest_states[quest_id] = {"objectives": {}}
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("active_flag"):
		set_world_flag(str(def.get("active_flag")), true)
	return true


func is_quest_started(quest_id: String) -> bool:
	if quest_states.has(quest_id):
		return true
	# Backward compat: fall back to active_flag world_flag for pre-unified saves
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("active_flag"):
		return bool(get_world_flag(str(def.get("active_flag"))))
	return false


func mark_quest_objective(quest_id: String, obj_id: String) -> void:
	if not quest_states.has(quest_id):
		quest_states[quest_id] = {"objectives": {}}
	var state: Dictionary = quest_states[quest_id]
	if not state.has("objectives"):
		state["objectives"] = {}
	state["objectives"][obj_id] = true
	# Propagate to world_flag if the objective defines one
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	for obj in def.get("objectives", []):
		if str((obj as Dictionary).get("id", "")) == obj_id:
			var done_flag := str((obj as Dictionary).get("done_flag", ""))
			if not done_flag.is_empty():
				set_world_flag(done_flag, true)
			break


func is_quest_step_done(quest_id: String, obj_id: String) -> bool:
	var qs: Dictionary = quest_states.get(quest_id, {})
	var objs: Dictionary = qs.get("objectives", {})
	if bool(objs.get(obj_id, false)):
		return true
	# Also accept direct world_flag if the objective declares a done_flag
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	for obj in def.get("objectives", []):
		if str((obj as Dictionary).get("id", "")) == obj_id:
			var done_flag := str((obj as Dictionary).get("done_flag", ""))
			if not done_flag.is_empty():
				return bool(get_world_flag(done_flag))
	return false


func can_complete_quest(quest_id: String) -> bool:
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.is_empty():
		return false
	for obj in def.get("objectives", []):
		if bool((obj as Dictionary).get("required", false)):
			if not is_quest_step_done(quest_id, str((obj as Dictionary).get("id", ""))):
				return false
	return true


func complete_quest(quest_id: String) -> void:
	mark_quest_completed(quest_id)
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("done_flag"):
		set_world_flag(str(def.get("done_flag")), true)
	if quest_states.has(quest_id):
		quest_states[quest_id]["completed"] = true
	else:
		quest_states[quest_id] = {"objectives": {}, "completed": true}


func abandon_quest(quest_id: String) -> bool:
	if quest_id.is_empty() or not QUEST_DEFS.has(quest_id):
		return false
	if is_quest_completed(quest_id) or not is_quest_started(quest_id):
		return false
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.has("active_flag"):
		set_world_flag(str(def.get("active_flag")), false)
	EventDeckSystem.remove_cards_by_tag(quest_id + "_active")
	quest_states.erase(quest_id)
	last_mission_result = "Abandoned quest: %s" % str(def.get("title", quest_id))
	return true


func get_quest_objective_text(quest_id: String) -> String:
	var def: Dictionary = QUEST_DEFS.get(quest_id, {})
	if def.is_empty():
		return ""
	if is_quest_completed(quest_id):
		return str(def.get("objective_text_done", str(def.get("title", quest_id)) + " complete."))
	if def.has("objective_text_active"):
		return str(def.get("objective_text_active", ""))
	# Campaign quests: build from objectives list
	var objs: Array = def.get("objectives", [])
	if objs.is_empty():
		return str(def.get("title", quest_id)) + ": in progress."
	var parts: PackedStringArray = []
	for obj in objs:
		var done := is_quest_step_done(quest_id, str((obj as Dictionary).get("id", "")))
		var label := str((obj as Dictionary).get("id", "")).replace("_", " ")
		parts.append("%s (%s)" % [label, "done" if done else "needed"])
	return "%s: %s" % [str(def.get("title", quest_id)), ", ".join(parts)]


func get_active_quests(type_filter := "") -> Array:
	var result: Array = []
	for quest_id in QUEST_DEFS.keys():
		var qid := str(quest_id)
		var def: Dictionary = QUEST_DEFS.get(qid, {})
		if not type_filter.is_empty() and str(def.get("type", "")) != type_filter:
			continue
		if not is_quest_started(qid):
			continue
		if is_quest_completed(qid):
			continue
		result.append({
			"id": qid,
			"title": str(def.get("title", qid)),
			"type": str(def.get("type", "")),
			"objective_text": get_quest_objective_text(qid),
		})
	return result


func get_active_hub_quests() -> Array:
	var result: Array = []
	for quest_id in QUEST_DEFS.keys():
		var def: Dictionary = QUEST_DEFS.get(quest_id, {})
		if str(def.get("type", "")) != "hub":
			continue
		if not is_quest_started(quest_id):
			continue
		if is_quest_completed(quest_id):
			continue
		result.append({
			"id": quest_id,
			"title": str(def.get("title", quest_id)),
			"objective_text": get_quest_objective_text(quest_id),
		})
	return result
