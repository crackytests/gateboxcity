extends Resource
class_name BodyPartData

@export var display_name := "Body Part"
@export var max_hp := 25.0
@export var targeting_penalty := 0.0
@export var lock_difficulty_multiplier := 1.0
@export var armor_value := 0.0

# ── Data-driven destruction behaviour ───────────────────────────────
# part_role: "core" | "head" | "limb" | "module"
@export var part_role := "limb"
# on_destroy_effect: "" | "stun" | "slow" | "disable_ranged" |
#   "reduce_melee_mult" | "reduce_melee_flat" | "enrage" |
#   "detonate" | "rupture_cloud" | "free_soul" | "defeat"
@export var on_destroy_effect := ""
@export var effect_strength := 0.0          # stun secs / slow mult / dmg mult / etc.
@export var effect_radius := 0.0
@export var effect_payload: Dictionary = {} # {duration, floor, disable_ranged, trigger_message, soul_rot, ...}

# ── Forward-looking flags (telegraph/interrupt + cybereye, later steps) ─
@export var telegraph_ability := ""         # "" | "ranged_shot" | "charge" | "sonic_beam" | "lunge"
@export var windup_lock_bonus := 0.0        # subtracted from lock_difficulty during wind-up
@export var volatile := false               # cybereye flags it; pairs with detonate/rupture/free_soul
@export var hackable := false               # eligible for the hack minigame as an alternative
@export var weak_point := false             # cybereye "best target" flag
