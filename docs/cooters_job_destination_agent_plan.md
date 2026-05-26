# Cooters Job Destination — Agent Build Plan

Clean-room agent instruction document for implementing (or rebuilding) the four Cooters job destination scenes in GATEBOX BREACH. Companion to `docs/cooters_job_board_and_travel_plan.md` and `docs/cooters_job_board_level_expansion_plan.md`.

Each scene is its own standalone level: one script, one .tscn, three distinct routes to the objective. The autoload triad is `GameState`, `WorldDirector`, `EventDeckSystem`.

---

## Scene Registry

| Scene file | Script | Jobs served | Hazard |
|---|---|---|---|
| `PipeUtilityTunnels.tscn` | `scripts/systems/PipeUtilityTunnels.gd` | pipe_blood_sample, ratchet_saint, listen_to_the_pipes | none |
| `DeadFoodCourtBloom.tscn` | `scripts/systems/DeadFoodCourtBloom.gd` | food_court_filter | growth pit 1 hp/s |
| `WaterReclamationCistern.tscn` | `scripts/systems/WaterReclamationCistern.gd` | cistern_pump_heart | water channel 3 hp/s |
| `CollapsedServiceAtrium.tscn` | `scripts/systems/CollapsedServiceAtrium.gd` | atrium_relay_echo | sludge gap 4 hp/s |

All four .tscn files share the same minimal structure:

```
[ext_resource type="Script" path="res://scripts/systems/SCRIPTNAME.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/player/Player.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="3"]

[node name="SCENENAME" type="Node3D"]
script = ExtResource("1")

[node name="Player" parent="." instance=ExtResource("2")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.05, 8)

[node name="HUD" parent="." instance=ExtResource("3")]
```

All geometry is procedurally built in `_ready()` via `_add_box()` and `_add_ramp()` helpers in each script. No mesh assets in the .tscn.

---

## Shared Technical Patterns

### Interactable group and dispatch

All interactables are `WardInteractable` nodes added to group `"location_interactable"`. The script connects each node's `interacted` signal to `_dispatch_interactable()`. Dispatch routes by `interactable_id` — specific environmental handlers first, then `_handle_job_node()` for all job nodes.

```gdscript
func _dispatch_interactable(interactable: WardInteractable) -> void:
    match interactable.interactable_id:
        "env_panel_id":
            _use_env_panel()
        _:
            _handle_job_node(interactable)
```

### Security node lifecycle

Each scene holds `_security_node` (a `WardInteractable` in the `"location_interactable"` group, with `interactable_id = "security_node"`). It is despawned by:
1. Environmental bypass (valve/panel used) — script calls `_security_node.queue_free()`
2. Player defeat — security node emits a signal the script listens for

On load, `_wire_runtime()` checks the bypass flag and despawns immediately if already set.

### Damage zone pattern

```gdscript
var _in_hazard := false
var _hazard_active := true  # only used in WaterReclamationCistern

func _process(delta: float) -> void:
    if _in_hazard and _hazard_active and player != null:
        if player.global_position.y < 1.2:
            player_health.apply_damage(DAMAGE_RATE * delta)
```

Y-threshold 1.2 is intentional: ground-level player spawns at y=1.05 (takes damage), elevated platforms at y≥1.5 are safe.

### EventDeckSystem — existing NAMED_CARDS

These cards are already defined in `WorldDirector.NAMED_CARDS`. Do not recreate them. Add them to `GameState.COOTERS_JOBS[job_id]["event_cards_on_accept"]` and `["event_cards_on_complete"]` lists.

---

## Location 1 — Pipe Utility Tunnels

**Scene:** `scenes/levels/PipeUtilityTunnels.tscn`
**Script:** `scripts/systems/PipeUtilityTunnels.gd`

### Site card

```yaml
site_id: cooters_dest_pipe_utility_tunnels
name: "Pipe Utility Tunnels"
site_type: "maintenance tunnels / semi-active utility run"
region: sub_sub_basement
old_function: "pressure equalization and pipe monitoring corridor"
current_function: "ambient job destination; Pipe Church gathering point for Gideon's flock"
main_resource_pressure: water, signal
visual_identity:
  - corroded pipe runs floor to ceiling on both side walls — amber and rust color
  - divider wall mid-corridor in cracked concrete with two passages cut through (gap south, gap north)
  - upper east walkway elevated on welded iron grating — visible from main corridor below
  - SE ramp in scuffed yellow safety paint leading up to east walk
  - saint_ratchet_node: a large chrome ratchet wrench mounted on a bolt-pillar shrine at the east walk high point
  - pipe_pressure_valve: heavy manual valve wheel on west wall, bleeding rust-water when triggered
  - lighting: amber incandescent filaments behind mesh guards; water drip sounds throughout
key_spaces:
  - name: "South entry — Cooters gate at z=12.1"
    gameplay: "spawn point; main corridor visible ahead; divider wall splits options immediately"
  - name: "Main corridor (z=0 to z=-12)"
    gameplay: "straight approach; security node at (0,0,-7) blocks north passage"
  - name: "West passage (divider wall west side)"
    gameplay: "bypass lane; narrower; gaps in divider let player rejoin main corridor"
  - name: "Upper east walkway (y=2.55)"
    gameplay: "elevated route; saint_ratchet_node objective; SE ramp is the only access"
  - name: "North end — pipe_listening_node at z=-11.5"
    gameplay: "all three routes converge here; objective zone"
occupants:
  faction_or_group: "Pipe Church (Gideon's flock, 1-2 worshippers as ambient NPCs)"
  motive: "ritual maintenance of the saint_ratchet_node shrine"
  default_state: "kneeling near east walk base; non-hostile"
hazards:
  environmental: "none — pressure only; valve use affects noise level and node state"
  social_or_tactical: "security node at (0,0,-7) blocks the straightforward corridor run"
player_approaches:
  combat: "fight security node in main corridor, then straight north to listening node"
  stealth: "west passage bypasses node; two divider gaps allow rejoining without aggro"
  technical: "pipe_pressure_valve at (-7,0.95,0.5) bleeds system pressure, despawns security node; flag pipe_valve_used"
twist: "saint_ratchet_node is also an objective for the ratchet_saint job — the shrine is actively maintained by the church"
connections:
  leads_to: ["Cooters (z=12.1 exit)", "Leak Street (z=-12.1 exit)", "Coil_Invitation quest (Velvet Coil NPC)"]
```

### Geometry spec

```
Room: x -9..9, z -12..12, y 0..5
Floor: StaticBody3D (18, 0.5, 24) at (0, -0.25, 0)
CeilingPanel: StaticBody3D (18, 0.5, 24) at (0, 5.25, 0)
NorthWall: StaticBody3D (18, 5.5, 0.35) at (0, 2.5, -12)
SouthWall: StaticBody3D (18, 5.5, 0.35) at (0, 2.5, 12)
EastWall: StaticBody3D (0.35, 5.5, 24) at (9, 2.5, 0)
WestWall: StaticBody3D (0.35, 5.5, 24) at (-9, 2.5, 0)

DividerWall: StaticBody3D (0.35, 4.5, 9.5) at (-2.5, 2.0, -5.25)
  — leaves gap south (z > 0) and gap north (z < -10)

UpperEastWalk: StaticBody3D (4, 0.28, 11) at (7, 2.41, -5.5)
  — surface y=2.55; player y≈3.6 (safe, no hazard in this scene)
SERamp: StaticBody3D (2, 0.3, 5) at (7, 1.1, 2.0) rot(-0.503, 0, 0)
```

### Routes

**Route 1 — Main corridor combat**
- Enter south, walk north along x=0 corridor
- Encounter security node at (0, 0, -7)
- Fight or take damage, reach pipe_listening_node at (0.5, 0.95, -11.5)

**Route 2 — West passage bypass**
- Enter south, slip through divider gap south (x < -2.5 zone)
- Travel north on west side of divider wall
- Rejoin main corridor through gap north near z=-10
- Reach pipe_listening_node without triggering node

**Route 3 — Valve environmental**
- Locate pipe_pressure_valve at (-7, 0.95, 0.5) — west wall, south chamber
- Interact: sets flag `pipe_valve_used`, despawns security node
- Walk corridor freely, both nodes and all jobs accessible

### Job nodes

| interactable_id | Position | Serves |
|---|---|---|
| pipe_blood_sample_node | (-5.5, 0.95, 6.5) | pipe_blood_sample |
| saint_ratchet_node | (7.2, 2.55, -5.5) | ratchet_saint |
| pipe_listening_node | (0.5, 0.95, -11.5) | listen_to_the_pipes |
| pipe_pressure_valve | (-7, 0.95, 0.5) | environmental |
| security_node | (0.0, 0.0, -7.0) | combat beat |

### NPC: Velvet Coil (Coil_Invitation quest hook)

Add a `DistrictNPC` node at position (-6.5, 1.05, -3.0) (west passage, near divider wall). NPC interactable_id: `"velvet_coil"`. Dispatch handler:

```gdscript
"velvet_coil":
    _handle_velvet_coil_encounter()
```

`_handle_velvet_coil_encounter()` checks flag `"coil_met_in_tunnels"`. If false: sets flag, plays Coil's invitation dialogue, triggers `EventDeckSystem.add_card("coil_invitation_card")`. If true: plays follow-up line.

Velvet Coil should only appear if `GameState.get_world_flag("coil_invitation_available", false)` is true — set this flag when the Faded Atrium hub reaches phase 2 (Working Base).

### EventDeckSystem cards (existing — do not recreate)

```
event_cards_on_accept for pipe_blood_sample:
  - "pipe_blood_sample_exit"     (district_exit, active_job condition)
  - "pipe_blood_sample_travel"   (travel, sets toxic_rain event)

event_cards_on_complete for pipe_blood_sample:
  - "pipe_blood_sample_return"   (hub_return)

event_cards_on_accept for ratchet_saint:
  - "ratchet_saint_exit"
  - "ratchet_saint_travel"       (speaker: Pipe Father Gideon)

event_cards_on_complete for ratchet_saint:
  - "ratchet_saint_return"       (sets flag saint_ratchet_returned)

event_cards_on_accept for listen_to_the_pipes:
  - "listen_pipes_exit"
  - "listen_pipes_travel"        (sets lan_outage event)

event_cards_on_complete for listen_to_the_pipes:
  - "listen_pipes_return"        (sets flag pipes_catalogue_updated)
```

### Visual targets

- Pipe material: StandardMaterial3D with rust orange-brown albedo, metallic 0.6, roughness 0.9
- Shrine (east walk): chrome metallic 0.95, roughness 0.1, emission white at energy 0.5
- Valve interactable: StandardMaterial3D red-handled geometry or label "PRESSURE VALVE"
- Ambient lighting: warm amber point lights at y=3.5 every 6 units along z axis
- Water drip particle: not required for first pass — placeholder AudioStreamPlayer3D at (−7, 1.5, 0)

---

## Location 2 — Dead Food Court Bloom

**Scene:** `scenes/levels/DeadFoodCourtBloom.tscn`
**Script:** `scripts/systems/DeadFoodCourtBloom.gd`

### Site card

```yaml
site_id: cooters_dest_dead_food_court_bloom
name: "Dead Food Court Bloom"
site_type: "second-floor food court / active bio-flora hazard zone"
region: faded_atrium_upper
old_function: "mall food court with fast-food ring and central seating pit"
current_function: "abandoned; controlled by invasive bio-mall flora; filter objective inside"
main_resource_pressure: water, food (negatively — contamination)
visual_identity:
  - central seating pit choked with sick green bio-flora — pulsing bioluminescence at 1 Hz
  - west upper ring and north upper ring at y=1.65 — warped plastic food court tables as cover
  - condiment bar remnants at pit center — toppled, moss-covered
  - kitchen corridor east side — grease-stained tile, closed grates on floor
  - spore_vent_panel on east wall — large circular vent cover with bio-matter ring stain
  - pure_water_filter_node on north ring — sealed filter housing with Torai label
  - lighting: green growth emission from pit; flickering fluorescent tubes on rings
key_spaces:
  - name: "South entry"
    gameplay: "spawn; growth pit immediately visible below; west ring and east kitchen both accessible"
  - name: "Growth pit (central, y<1.2)"
    gameplay: "hazard crossing shortcut; security node at (0,0,-3) in pit; 1 hp/s damage"
  - name: "West upper ring"
    gameplay: "safe elevated route; connects south to northwest; cover opportunities"
  - name: "North upper ring"
    gameplay: "objective zone; pure_water_filter_node here; all routes converge"
  - name: "Kitchen east passage"
    gameplay: "bypass lane; spore_vent_panel access; NE ramp to north ring"
hazards:
  environmental: "growth pit Area3D — 1 hp/s when player.y < 1.2; security node in pit center"
  social_or_tactical: "security node at (0,0,-3) patrols pit; central north ramp exits onto its flank"
player_approaches:
  combat: "cross pit (take damage), fight security node, climb central north ramp to north ring"
  stealth: "SW ramp to west ring, NW corner arc to north ring — never enters pit"
  technical: "spore_vent_panel at (10.5,0.95,4) purges growth chemistry, despawns node; flag spore_vent_used"
twist: "pure_water_filter_node is marked with a Torai environmental credit ledger — collecting it opens a Torai rep line"
connections:
  leads_to: ["Cooters (south exit)", "Faded Atrium (north exit to mall proper)", "food_court_return card → Kiki Baja dialogue"]
```

### Geometry spec

```
Room: x -12..12, z -12..6, y 0..6
GrowthPit Area3D: size (10, 3, 12) at (0, 0, -1) — damage zone
PitFloor: StaticBody3D (10, 0.5, 12) at (0, -0.5, -1) — y surface -0.25 (below threshold)

WestRing: StaticBody3D (6, 0.28, 17) at (-8, 1.51, -2.5)    — surface y=1.65
NorthRing: StaticBody3D (22, 0.28, 5) at (0, 1.51, -8.5)     — surface y=1.65
SWRamp: StaticBody3D (2, 0.3, 5) at (-8, 0.82, 2.5) rot(-0.503, 0, 0)
CentralNorthRamp: StaticBody3D (3, 0.3, 4.5) at (0, 0.82, -5.5) rot(-0.503, 0, 0)
NERamp: StaticBody3D (2, 0.3, 4.5) at (8, 0.82, -5.5) rot(-0.503, 0, 0)
KitchenEastWall: StaticBody3D (0.35, 4.5, 14) at (5, 2.0, 0.5)
```

### Routes

**Route 1 — Pit crossing combat**
- Drop into pit, fight security node at (0, 0, -3)
- Climb central north ramp to north ring, interact with filter node

**Route 2 — West ring arc**
- SW ramp up to west ring at (-8, 1.65, zone)
- Walk north along west ring, NW corner connects to north ring
- Reach filter node without entering pit

**Route 3 — Kitchen bypass + vent**
- East side of room along kitchen passage (east of KitchenEastWall)
- Interact with spore_vent_panel at (10.5, 0.95, 4.0)
- Sets flag `spore_vent_used`, despawns security node, stops pit damage
- NE ramp up to north ring

### Job nodes

| interactable_id | Position | Serves |
|---|---|---|
| pure_water_filter_node | (-4, 1.85, -10.0) | food_court_filter |
| spore_vent_panel | (10.5, 0.95, 4.0) | environmental |
| security_node | (0.0, 0.0, -3.0) | combat beat (in pit) |

### EventDeckSystem cards (existing — do not recreate)

```
event_cards_on_accept for food_court_filter:
  - "food_court_exit"      (district_exit, Marbles speaker)
  - "food_court_travel"    (travel, sets power_sag event)

event_cards_on_complete for food_court_filter:
  - "food_court_return"    (hub_return, Kiki Baja speaker)
```

### Visual targets

- Growth material: emission Color(0.12, 0.65, 0.05) at energy 1.2; albedo Color(0.06, 0.16, 0.04)
- Ring surface: warped pale grey StandardMaterial3D, roughness 0.95 (old food court plastic)
- Spore vent panel: dark green mesh disc geometry, bio-ring stain decal or emission ring
- Filter node: sealed grey box with Torai yellow stripe label
- Ambient light: green OmniLight3D at (0, 0.5, -1) in pit; white flickering on rings (AnimationPlayer on light energy)

---

## Location 3 — Water Reclamation Cistern

**Scene:** `scenes/levels/WaterReclamationCistern.tscn`
**Script:** `scripts/systems/WaterReclamationCistern.gd`

**DIFFERENTIATION NOTE:** This is the Cooters job destination — the pump heart lease retrieval site. It is NOT the same as `ContaminationSump.tscn` (which is the System X quest investigation site). This cistern is clean-ish Torai infrastructure; the sump is contaminated Torai biotech runoff. Different biomes, different scripts, different scene files.

### Site card

```yaml
site_id: cooters_dest_water_reclamation_cistern
name: "Water Reclamation Cistern"
site_type: "active water reclamation facility / contested Torai lease"
region: sub_sub_basement
old_function: "water reclamation and filtration node for mall lower levels"
current_function: "active but decayed; Torai holds the lease; cistern_filter_core_node is the retrieval target"
main_resource_pressure: water
visual_identity:
  - central water channel — blue-cyan translucent (70% opacity), ripple shader or animated UV
  - filter bed stepping stones crossing the channel — grey concrete pads at water surface
  - east walkway — dry concrete catwalk along right wall
  - west walkway — dry concrete catwalk along left wall leading to pump room
  - pump room NW corner — enclosed with PumpRoomSouthWall and PumpRoomEastWall; cistern_filter_core_node inside
  - pump_valve_panel west wall center — industrial red emergency shutoff with Torai warning label
  - live conduit marker east side (visual only — orange warning stripe StaticBody3D)
  - lighting: cold blue-white from water glow; yellow overhead work lights on walkways
key_spaces:
  - name: "South entry"
    gameplay: "spawn; water channel immediately visible; east and west walkways accessible"
  - name: "Water channel (central)"
    gameplay: "3 hp/s damage at y<1.2; filter bed stepping stones allow safe crossing at y≈1.55"
  - name: "East walkway"
    gameplay: "safe path; security node at (7,0,-5) blocks north approach from east"
  - name: "West walkway"
    gameplay: "safe path; leads directly to pump room entrance; no node obstruction"
  - name: "Pump room (NW corner)"
    gameplay: "objective zone; cistern_filter_core_node inside; pump_valve_panel on west wall"
hazards:
  environmental: "water channel — 3 hp/s; stepping stones are safe (y≈1.55); pump_valve_panel disables water + despawns node"
  social_or_tactical: "security node at (7,0,-5) patrols east walkway approach; Torai surveillance flavor text"
player_approaches:
  combat: "east walkway, fight security node at (7,0,-5), north walkway to pump room"
  stealth: "stepping stones across center channel, west side, pump room — avoids node entirely"
  technical: "pump_valve_panel at (-7,0.95,0) — disables water hazard + despawns node; flag cistern_valve_used"
twist: "cistern_filter_core_node has a Torai tracking chip — collecting it triggers Torai rep gain (already in cistern_return card effect)"
connections:
  leads_to: ["Cooters (south exit)", "Leak Street (north exit)", "Wan Moa Torai rep consequence"]
```

### Geometry spec

```
Room: x -10..10, z -12..8, y 0..5
WaterArea3D: size (7, 3, 22) at (0, 0, 0) — damage zone; _water_hazard_active flag gates damage
WaterSurface: StandardMaterial3D blue-cyan mesh (7, 0.05, 22) at (0, 0.025, 0)
WaterFloor: StaticBody3D (7, 0.5, 22) at (0, -0.5, 0)

EastWalkway: StaticBody3D (3, 0.5, 22) at (8.5, -0.25, 0)    — surface y=0 (ground level, y≈1.05)
WestWalkway: StaticBody3D (3, 0.5, 22) at (-8.5, -0.25, 0)   — same
FilterStone1: StaticBody3D (2.2, 0.5, 2.2) at (0, -0.25, 4)  — surface y=0.5; player y≈1.55 → SAFE
FilterStone2: StaticBody3D (2.2, 0.5, 2.2) at (0, -0.25, 0)
FilterStone3: StaticBody3D (2.2, 0.5, 2.2) at (0, -0.25, -4)

PumpRoomSouthWall: StaticBody3D (6, 2.8, 0.35) at (-7.25, 1.4, -8.0)
PumpRoomEastWall: StaticBody3D (0.35, 3.2, 4.5) at (-4.5, 1.6, -10.25)
```

### Routes

**Route 1 — East walkway combat**
- Follow east walkway north
- Fight security node at (7, 0, -5)
- Continue north, cross to west side, pump room at NW

**Route 2 — Stepping stones**
- Step from EastWalkway onto FilterStone1 at z=4, across to z=0, z=-4
- Reach WestWalkway directly, follow north to pump room
- Security node at (7, 0, -5) is east — never triggered

**Route 3 — Valve environmental**
- Locate pump_valve_panel at (-7, 0.95, 0.0) — west walkway, mid-point
- Interact: sets flag `cistern_valve_used`, disables `_water_hazard_active`, despawns security node
- Walk through water channel freely (still visual hazard, no damage)

### Job nodes

| interactable_id | Position | Serves |
|---|---|---|
| cistern_filter_core_node | (-7, 0.95, -9.5) | cistern_pump_heart |
| pump_valve_panel | (-7, 0.95, 0.0) | environmental |
| security_node | (7.0, 0.0, -5.0) | combat beat |

### EventDeckSystem cards (existing — do not recreate)

```
event_cards_on_accept for cistern_pump_heart:
  - "cistern_exit"      (district_exit, Marbles speaker)
  - "cistern_travel"    (travel, sets lan_outage; Brickmouth Ronnie speaker)

event_cards_on_complete for cistern_pump_heart:
  - "cistern_return"    (hub_return, adds Wan Moa Torai rep +1; Brickmouth Ronnie speaker)
```

### Visual targets

- Water material: Color(0.02, 0.28, 0.55, 0.72), roughness 0.05, metallic 0.1
- Pump room: darker concrete albedo; cistern_filter_core_node is a sealed grey cylinder with cyan indicator light emission
- Valve panel: red disc handle on dark wall-mounted box; Torai yellow warning stripe
- Stepping stones: dark grey StandardMaterial3D, roughness 0.9, visible height above water surface
- Live conduit marker (visual only): orange stripe StaticBody3D (0.2, 1.5, 0.2) at (9.5, 0.75, -2) — warning color, no damage

---

## Location 4 — Collapsed Service Atrium

**Scene:** `scenes/levels/CollapsedServiceAtrium.tscn`
**Script:** `scripts/systems/CollapsedServiceAtrium.gd`

### Site card

```yaml
site_id: cooters_dest_collapsed_service_atrium
name: "Collapsed Service Atrium"
site_type: "vertical mall atrium / collapsed maintenance deck"
region: faded_atrium_service_underside
old_function: "central mall atrium vertical shaft — escalators, retail frontage, open retail floors"
current_function: "lower mall flooded and unreachable; service catwalks above sludge gap are the only traversable surfaces"
main_resource_pressure: signal, shelter
visual_identity:
  - sludge gap floor — purple-black semi-opaque fluid, slow bubble animation at ground level
  - main catwalk at y=2.0 — rusted steel grating spanning full width east-west at z=-5 to z=-12
  - south ramp rising from entry to catwalk level — yellow safety paint worn to suggestion
  - hardlight gate panel left (west) of entry — Gatebox tech panel, blue-cyan indicator lights
  - hardlight bridge when activated — translucent blue StaticBody3D spanning sludge gap at y=1.35
  - atrium_relay_node north end of catwalk — old mall broadcasting unit, slowly rotating antenna arm
  - east hatch wall dividing main atrium from service corridor right-side approach
  - lighting: purple emission from sludge below; blue-white maintenance floods on catwalk level
key_spaces:
  - name: "South entry (z=8)"
    gameplay: "spawn; sludge gap immediately visible; south ramp to catwalk visible ahead; east hatch wall splits right-side option"
  - name: "Sludge gap (y<1.2)"
    gameplay: "4 hp/s; impassable at ground level without hardlight bridge; forces vertical routing"
  - name: "Main catwalk (y=2.0)"
    gameplay: "primary combat and navigation surface; security node at (0,2,-5.5); atrium_relay_node at NW end"
  - name: "East hatch service corridor"
    gameplay: "stealth bypass; east of EastHatchWall; NE ramp connects to catwalk north approach"
  - name: "Hardlight bridge (spawned)"
    gameplay: "surface at y=1.35; player y≈2.525 → safe; allows western ground-level approach if gate activated"
hazards:
  environmental: "sludge gap Area3D — 4 hp/s at y<1.2; hardlight bridge provides western safe crossing"
  social_or_tactical: "security node at (0,2,-5.5) ON catwalk — unavoidable via south ramp route"
player_approaches:
  combat: "south ramp to catwalk, fight security node at (0,2,-5.5), north to relay"
  stealth: "east hatch corridor (x>4.5), NE ramp at (7,1,-3.5), catwalk north approach — bypasses node"
  technical: "hardlight_gate_panel at (-8.5,0.95,-2) → spawns hardlight bridge + despawns node; flag atrium_gate_opened"
twist: "the relay is still broadcasting on a pre-reformat frequency — collecting the packet triggers a WorldDirector lore flag"
connections:
  leads_to: ["Cooters (south exit)", "Faded Atrium upper levels (north exit)", "atrium_relay_data_logged flag"]
```

### Geometry spec

```
Room: x -10..10, z -12..8, y 0..6
SludgeArea3D: size (8, 3, 10) at (0, 0, -4) — damage zone; ground level

MainCatwalk: StaticBody3D (20, 0.28, 7) at (0, 1.86, -8.5)    — surface y=2.0; player y≈3.05
SouthRamp: StaticBody3D (4, 0.3, 7.3) at (0, 1.0, 0.5) rot(-0.278, 0, 0)
NERamp: StaticBody3D (4, 0.3, 3.6) at (7, 1.0, -3.5) rot(-0.588, 0, 0)
NWRamp: StaticBody3D (4, 0.3, 3.6) at (-7, 1.0, -3.5) rot(-0.588, 0, 0)
EastHatchWall: StaticBody3D (0.35, 5.3, 14) at (4.5, 2.3, 0.5)

HardlightBridge (spawned on flag): StaticBody3D (9, 0.25, 2.2) at (-0.5, 1.35, -5.0)
  — surface y=1.475; player y≈2.525 → ABOVE 1.2 threshold → safe from sludge
```

### Routes

**Route 1 — South ramp combat**
- South ramp up to catwalk at y=2.0
- Fight security node at (0, 2, -5.5) on catwalk
- Walk north along catwalk to atrium_relay_node at (-2, 2.15, -10.5)

**Route 2 — East hatch stealth**
- Stay east of EastHatchWall (x > 4.5)
- NE ramp at (7, 1, -3.5) up to catwalk north approach
- Approach relay from north side — security node is at -5.5, relay at -10.5, never crossed

**Route 3 — Hardlight gate environmental**
- Locate hardlight_gate_panel at (-8.5, 0.95, -2.0) — left wall, south end
- Interact: sets flag `atrium_gate_opened`, spawns HardlightBridge StaticBody3D, despawns security node
- Walk west approach across bridge (y=1.475 surface → player above threshold), north to relay

### Job nodes

| interactable_id | Position | Serves |
|---|---|---|
| atrium_relay_node | (-2, 2.15, -10.5) | atrium_relay_echo |
| hardlight_gate_panel | (-8.5, 0.95, -2.0) | environmental |
| security_node | (0.0, 2.0, -5.5) | combat beat (ON catwalk) |

### EventDeckSystem cards (existing — do not recreate)

```
event_cards_on_accept for atrium_relay_echo:
  - "atrium_relay_exit"      (district_exit, Marbles speaker)
  - "atrium_relay_travel"    (travel, sets power_sag event; System X speaker)

event_cards_on_complete for atrium_relay_echo:
  - "atrium_relay_return"    (hub_return, sets flag atrium_relay_data_logged; System X speaker)
```

### Visual targets

- Sludge material: Color(0.06, 0.10, 0.06, 0.85), emission Color(0.04, 0.14, 0.04) at energy 0.6
- Hardlight bridge: Color(0.05, 0.3, 0.9, 0.82), emission Color(0.1, 0.5, 1.0) at energy 2.0; transparent albedo
- Catwalk: dark metallic grating StandardMaterial3D, metallic 0.7, roughness 0.6
- Relay node: old broadcast unit — grey housing, slow rotation AnimationPlayer on an antenna child node, red indicator light
- Gate panel: Gatebox corporate tech — clean white housing, blue-cyan LED strip, "HARDLIGHT GATE — AUTHORIZED ACCESS ONLY" label

---

## Implementation Checklist

For each location, verify:

- [ ] Script builds all geometry in `_ready()` — no mesh nodes in .tscn
- [ ] Player node present in .tscn at (0, 1.05, 8)
- [ ] HUD node present in .tscn
- [ ] All interactables in group `"location_interactable"`
- [ ] `_dispatch_interactable()` routes by interactable_id
- [ ] Security node stored in `_security_node`; despawned by env bypass AND defeat signal
- [ ] `_wire_runtime()` checks bypass flag on load and despawns immediately if set
- [ ] Damage zone Area3D sets `_in_hazard` bool via `body_entered` / `body_exited`
- [ ] `_process()` checks `player.global_position.y < 1.2` before applying damage
- [ ] WaterReclamationCistern: `_water_hazard_active` flag gates damage; valve sets it false
- [ ] CollapsedServiceAtrium: hardlight bridge spawned as StaticBody3D with surface at y=1.35
- [ ] All flags use `GameState.set_world_flag` / `get_world_flag`
- [ ] EventDeckSystem card keys match WorldDirector.NAMED_CARDS exactly
- [ ] PipeUtilityTunnels: Velvet Coil DistrictNPC only spawns if `coil_invitation_available` flag is true
