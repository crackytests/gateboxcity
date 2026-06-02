extends Control
class_name CyberneticSurgeryUI

## Data shell — UPGRADE_DB and body-slot constants used by GhostTermUI's WARE tab
## and the STAT tab schematic. All install logic lives in GhostTermUI.

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

# NOTE: the `cost`, `cost_item`, and `cost_count` fields below are LEGACY from the old
# item-cost self-install kiosk and are no longer read by anything. Installation now happens
# at Velvet Coil, priced in Wan Notes by rarity tier (see GameState.implant_install_price /
# IMPLANT_TIERS). Don't wire new logic to these fields; they're kept only to avoid churn.
const UPGRADE_DB := {
	# ── Original five ────────────────────────────────────────────────
	"targeting_coprocessor": {"name": "Targeting Co-Processor", "slot": "Head", "desc": "Improves reticle pickup, base hit chance, and lock speed. Bootstrapped from hacked corporate targeting hardware.", "cost": "Suitors Access Chit", "cost_item": "Suitors Access Chit", "cost_count": 1, "drift": 6},
	"gatebox_eye_mk1": {"name": "Gatebox Eye MK1", "slot": "Eyes", "desc": "Reveals enemy body part HP when targeting. Corporate surplus with warranty voided by bullet holes.", "cost": "Cooters Bar Credit", "cost_item": "Cooters Bar Credit", "cost_count": 1, "drift": 5},
	"black_market_armature": {"name": "Black-Market Armature", "slot": "Right Arm", "desc": "Reduces weapon kick and preserves more target lock after shots. Installed in a pipe alley by someone who learned surgery from a VHS tape.", "cost": "Torai Salvage Contract", "cost_item": "Torai Salvage Contract", "cost_count": 1, "drift": 7},
	"pipewalker_legs": {"name": "Pipewalker Legs", "slot": "Right Leg", "desc": "Improves movement speed. Smells like industrial lubricant and ambition.", "cost": "Cheap Poncho", "cost_item": "Cheap Poncho", "cost_count": 1, "drift": 6},
	"soul_baffle": {"name": "Soul Baffle", "slot": "Torso", "desc": "Reduces incoming integrity damage. Nobody is sure what it does to your dreams.", "cost": "Chemical Neutralizer", "cost_item": "Chemical Neutralizer", "cost_count": 1, "drift": 5},

	# ── Phase 2: head / eyes ─────────────────────────────────────────
	"neural_jack": {"name": "Neural Jack", "slot": "Head", "desc": "A direct cortex port. Speeds terminal access and sharpens cognition. The hole never fully closes; you stop noticing the draft.", "cost": "Suitors Access Chit x2", "cost_item": "Suitors Access Chit", "cost_count": 2, "drift": 8},
	"whisper_filter": {"name": "Whisper Filter", "slot": "Head", "desc": "Nanotech dampens your noise signature, so the Splice take longer to notice you. Side effect: you take longer to notice yourself.", "cost": "Cooters Rumor Token", "cost_item": "Cooters Rumor Token", "cost_count": 1, "drift": 5},
	"mag_retina": {"name": "Mag-Retina", "slot": "Eyes", "desc": "Magnifying optic array. Surfaces enemy weak points and part HP. Replaces the Gatebox Eye with something that does not phone home.", "cost": "Mall Arcade Token x3", "cost_item": "Mall Arcade Token", "cost_count": 3, "drift": 7},

	# ── Phase 2: torso ───────────────────────────────────────────────
	"endoskeletal_brace": {"name": "Endoskeletal Brace", "slot": "Torso", "desc": "A subdermal cage that raises maximum body integrity by 20. You creak in the cold and set off every scanner ever built.", "cost": "Chemical Neutralizer x2", "cost_item": "Chemical Neutralizer", "cost_count": 2, "drift": 9, "max_hp": 20},
	"bioreactor_mesh": {"name": "Bio-Reactor Mesh", "slot": "Torso", "desc": "A woven reactor lattice that slowly regenerates integrity out of combat. Powered by something the brochure calls 'ambient potential.'", "cost": "Illegal Reactor Cell", "cost_item": "Illegal Reactor Cell", "cost_count": 1, "drift": 10},

	# ── Phase 2: arms ────────────────────────────────────────────────
	"left_arm_graft": {"name": "Salvage Graft", "slot": "Left Arm", "desc": "A mismatched arm of salvaged actuators. Improves melee reach and damage. Three previous owners, all uncredited.", "cost": "Torai Salvage Contract x2", "cost_item": "Torai Salvage Contract", "cost_count": 2, "drift": 7},
	"trauma_dampener": {"name": "Trauma Dampener", "slot": "Left Arm", "desc": "Hydraulic shock baffles. Reduces knockback and keeps your aim steady while taking fire. Numbs more than recoil.", "cost": "Wan Note x20", "cost_item": "Wan Note", "cost_count": 20, "drift": 6},

	# ── Phase 2: legs ────────────────────────────────────────────────
	"sprint_pistons": {"name": "Sprint Pistons", "slot": "Left Leg", "desc": "Pneumatic calf rig. Stacks with Pipewalker Legs for real speed. The whine gives you away in quiet rooms.", "cost": "Cooters Bar Credit x3", "cost_item": "Cooters Bar Credit", "cost_count": 3, "drift": 6},

	# ── Phase 2: spine ───────────────────────────────────────────────
	"spine_relay": {"name": "Spine Relay", "slot": "Spine", "desc": "A single bus that routes every implant through one clean channel. Halves drift gained from future installs. Standardises the strangeness.", "cost": "Atrium Relay Packet", "cost_item": "Atrium Relay Packet", "cost_count": 1, "drift": 3},
	"drift_syphon": {"name": "Drift Syphon", "slot": "Spine", "desc": "Bleeds excess strangeness back into the Dreaming Generator as civic potential. Only installs while the soul still reads mostly clean.", "cost": "Pipe Blood Sample", "cost_item": "Pipe Blood Sample", "cost_count": 1, "drift": 2, "req_soul_rot_max": 30},

	# ── Phase 2: soul slot ───────────────────────────────────────────
	"soul_anchor_tap": {"name": "Soul Anchor Tap", "slot": "Soul Slot", "desc": "Pirated System X hardware that steadies your soul anchor and surfaces their transmissions faster. They only sell it to people they trust.", "cost": "Atrium Relay Packet (System X rep 5+)", "cost_item": "Atrium Relay Packet", "cost_count": 1, "drift": 4, "req_rep_min": {"faction": "System X", "amount": 5}},
	"preservation_blocker": {"name": "Preservation Blocker", "slot": "Soul Slot", "desc": "A jammer that blinds Preservation Directive scans. Gatebox only lets this fall off a truck for people they have already given up on.", "cost": "Wan Note x30 (Gatebox rep -3 or lower)", "cost_item": "Wan Note", "cost_count": 30, "drift": 8, "req_rep_max": {"faction": "Gatebox Corporation", "amount": -3}},
}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
