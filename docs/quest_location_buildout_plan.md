# Gatebox Quest Location Buildout Plan

Agent instruction document for six new quest-driven locations in GATEBOX BREACH. These are distinct from the four Cooters job destinations. Where thematic overlap exists with existing scenes, the differentiation is explicit.

Companion documents: `docs/cooters_job_destination_agent_plan.md`, `docs/cooters_job_board_level_expansion_plan.md`.

---

## Overlap Resolution

Two locations in the original design draft overlapped with existing Cooters job destination scenes. Those have been resolved:

| Original name | Conflict | Resolution |
|---|---|---|
| Food Court Fever Ward | Thematic overlap with Dead Food Court Bloom (second-floor bio-flora) | Kept — different floor, different hazard biome. FoodCourtFeverWard is Market Row ground floor: fever heat, sick bodies, food poisoning aftermath. NOT bio-flora. |
| Cistern Relay | Concept overlap with Water Reclamation Cistern (Torai pump heart lease) | Renamed to **Contamination Sump**. Scene file: `ContaminationSump.tscn`. Different space entirely: sub-pump contamination pocket, magenta Torai biocanister runoff, investigation not retrieval. |

---

## EventDeckSystem Integration

New quest locations use world flags for condition tracking (not `active_job`, which is for Cooters jobs only).

**Pattern for quest-driven cards:**

```gdscript
"quest_X_exit": {
    "id": "quest_X_exit",
    "title": "...",
    "contexts": ["district_exit"],
    "weight": 2,
    "conditions": {"flag_true": "quest_X_active"},
    "effects": [],
    "expires_after": 1,
    "tags": ["quest_X_tag"],
    "speaker": "NPC NAME",
    "text": "...",
},
```

Flag `quest_X_active` is set via `GameState.set_world_flag("quest_X_active", true)` when the player accepts the quest from the quest-giver NPC. Cards are added via `EventDeckSystem.add_card("quest_X_exit")` at the same time.

**Quest completion cards** use `conditions: {}` (no condition) and `expires_after: 0` (fire once, expire immediately).

All new NAMED_CARDS entries are listed in the **WorldDirector Integration** section at the end of this document.

---

## Location 1 — Filter Crypt

**Scene:** `scenes/levels/FilterCrypt.tscn`
**Script:** `scripts/systems/FilterCrypt.gd`
**Quest:** Pipe Father Gideon personal quest — `quest_filter_crypt`
**Quest giver:** Pipe Father Gideon (Faded Atrium hub, Store 2 — Pipe Church)

### Identity

Old maintenance shaft converted into a pipe worship space by Gideon's congregation. The shaft is partially flooded with rusty mineral water — considered holy by the Pipe Church. The filter system the church has been maintaining for years is now failing. Gideon needs it repaired before the congregation's water supply goes sour.

### Site card

```yaml
site_id: quest_filter_crypt
name: "Filter Crypt"
site_type: "maintenance shaft / pipe worship site"
region: sub_sub_basement (between Leak Street and cistern level)
old_function: "pressure relief shaft and junction filter for upper mall water feeds"
current_function: "Pipe Church sacred site; failing filter is the quest target"
main_resource_pressure: water, faith
visual_identity:
  - narrow vertical shaft — low ceiling, tight walls, iron grating underfoot
  - pipe shrine alcoves carved into the walls — wrench icons, candle-analog lights
  - mineral water pool on lowest level — rust-orange, slow drip from above
  - filter housing at pool center — old industrial unit, cracked casing, orange mineral scale
  - iron ladder on east wall — leads to upper level where vent access panel sits
  - ambient sound: pipe groan loop at 0.5 Hz with harmonic overtones
key_spaces:
  - name: "Shaft entry (upper)"
    gameplay: "ladder down or vent panel approach; scope before descending"
  - name: "Pipe shrine corridor"
    gameplay: "two alcoves with interactable shrine objects; Gideon lore; Pipe Church history"
  - name: "Filter pool (lowest level)"
    gameplay: "filter housing objective; mineral water hazard (1 hp/s, slow); repair interactable"
  - name: "Vent override panel (upper east)"
    gameplay: "environmental bypass — venting neutralizes pool chemistry; safe repair access"
hazards:
  environmental: "mineral water pool — 1 hp/s at y < 1.2; drainable via vent override panel"
  social_or_tactical: "one Pipe Church guard NPC (non-hostile if quest_filter_crypt_active flag is set)"
player_approaches:
  combat: "wade into pool, fight guard if quest not active, repair filter under damage"
  stealth: "upper vent panel access bypasses guard; descend from above"
  technical: "vent_override_panel neutralizes pool; flag filter_crypt_vent_used"
twist: "the filter housing contains a sealed Wan Moa Torai ledger — Gideon has been paying a resource debt for 3 years and didn't tell the congregation"
```

### Geometry spec

```
Shaft: x -4..4, z -4..4, y 0..8 (tight vertical space)
MineralPool Area3D: size (6, 3, 6) at (0, 0, 0) — 1 hp/s hazard
PoolFloor: StaticBody3D (6, 0.5, 6) at (0, -0.5, 0)
ShrineNorthAlcove: StaticBody3D (0.5, 2.5, 2.5) at (-4.1, 1.25, -1)
ShrineSouthAlcove: StaticBody3D (0.5, 2.5, 2.5) at (-4.1, 1.25, 1)
IronLadder: StaticBody3D (0.4, 6, 0.4) at (3.7, 3, 0) — ladder geometry
UpperPlatform: StaticBody3D (8, 0.28, 8) at (0, 7.86, 0) — surface y=8.0
VentPanel: WardInteractable at (3.5, 8.2, -3.5) on upper platform
FilterHousing: WardInteractable at (0, 0.95, 0) in pool center
```

### Routes

**Route 1 — Direct descent**
- Enter shaft from top, climb down iron ladder
- Wade into mineral pool (1 hp/s), repair filter housing

**Route 2 — Shrine corridor approach**
- Access shrine corridor from entrance passage (x=-4 side)
- Interact with shrine alcoves for lore
- Descend to pool from south alcove exit

**Route 3 — Vent override**
- Access upper platform via ladder
- Interact with vent_override_panel at (3.5, 8.2, -3.5)
- Sets flag `filter_crypt_vent_used`, neutralizes pool chemistry
- Descend safely, repair filter

### Quest flow

1. Accept quest from Gideon → flag `quest_filter_crypt_active` set → card `filter_crypt_exit` added to EventDeck
2. Enter Filter Crypt, repair filter housing → flag `filter_crypt_repaired` set → card `filter_crypt_return` fires on hub return
3. Return to Gideon → quest complete → flag `quest_filter_crypt_complete` set → Gideon unlocks Pipe Church store stock

### EventDeckSystem cards (add to WorldDirector.NAMED_CARDS)

See WorldDirector Integration section below.

---

## Location 2 — Mascot Service Elevator Stack

**Scene:** `scenes/levels/MascotElevatorStack.tscn`
**Script:** `scripts/systems/MascotElevatorStack.gd`
**Quest:** Ladderboy quest — `quest_mascot_elevator`
**Quest giver:** Ladderboy (Faded Atrium hub, lobby or service corridor area)

### Identity

A stack of three stuck service elevators in a vertical shaft — the mall's old mascot suit transport route. Mascot suits from different corporate eras are still sealed inside two of the three cars. The elevator control panel Ladderboy needs is inside the middle car, which is stuck between floors with a broken safety interlock.

### Site card

```yaml
site_id: quest_mascot_elevator
name: "Mascot Service Elevator Stack"
site_type: "vertical shaft / stuck elevator cars"
region: faded_atrium service corridor upper level
old_function: "service elevator shaft for costume transport between mall performance floors"
current_function: "abandoned; three elevator cars wedged at different heights; mascot suits inside"
main_resource_pressure: signal, salvage
visual_identity:
  - vertical shaft visible on entry — elevator cables and grease-stained guide rails
  - car A at bottom (accessible, doors open): empty; scorch marks from old short circuit
  - car B at mid-level (jammed): contains two mascot suits sealed in vacuum bags; control panel target
  - car C at top (accessible via crawl route): intact Gatebox corporate mascot — pristine, eerie
  - emergency hatch on top of each car — crawl-space access between cars via roof hatches
  - counterweight on cable visible through shaft gap — becomes physics hazard if cable is cut
key_spaces:
  - name: "Shaft base (car A)"
    gameplay: "entry; bottom car accessible; shaft vertical visible above"
  - name: "Shaft mid (car B)"
    gameplay: "control panel objective; car B doors jammed; roof hatch from A or emergency lever required"
  - name: "Shaft top (car C)"
    gameplay: "pristine mascot — loot / lore; accessible via roof hatch crawl from B"
  - name: "Counterweight gap"
    gameplay: "visible through shaft wall gap; cable cut environmental option"
hazards:
  environmental: "fall damage from shaft — car rooftop traversal at y=4 and y=8; no liquid hazard"
  social_or_tactical: "mascot suit in car C triggers Gatebox corporate ID check if signal is active (power_sag event bypasses check)"
player_approaches:
  combat: "no primary combat beat; corporate security drone spawns if car C opened without bypass"
  stealth: "power_sag event or lan_outage event disables corporate ID; open car C freely"
  technical: "shaft_relay_panel outside shaft — cuts corporate signal; flag mascot_relay_cut; no security drone"
twist: "the mascot in car C is not a suit — it is a functioning Gatebox animatronic that has been sealed for 7 years and is extremely glad to meet someone"
```

### Geometry spec

```
Shaft: x -3..3, z -3..3, y 0..12
CarA: StaticBody3D (2.4, 2.4, 2.4) at (0, 1.2, 0) — bottom; floor surface y=0; doors open
CarB: StaticBody3D (2.4, 2.4, 2.4) at (0, 5.0, 0) — mid; jammed
CarC: StaticBody3D (2.4, 2.4, 2.4) at (0, 9.0, 0) — top
RoofHatchA: WardInteractable at (0, 2.4, 0) — top of car A
RoofHatchB: WardInteractable at (0, 6.2, 0) — top of car B
ControlPanel: WardInteractable at (-0.9, 5.95, 0) — inside car B (interactable through jammed door gap)
ShaftRelayPanel: WardInteractable at (3.1, 1.05, 0) — shaft exterior wall
```

### Routes

**Route 1 — Roof hatch traversal**
- Enter car A, interact with roof hatch, climb to car B roof
- Drop through car B's emergency hatch, access control panel

**Route 2 — Relay cut**
- Interact with shaft_relay_panel outside shaft
- Sets flag `mascot_relay_cut` — disables corporate ID check
- Open car C roof hatch freely; control panel still in car B

**Route 3 — Event-dependent bypass**
- If world event is `power_sag` or `lan_outage`: corporate ID check disabled automatically
- Proceed directly via roof hatch traversal without relay step

### Quest flow

1. Accept from Ladderboy → flag `quest_mascot_elevator_active` set → card `mascot_elevator_exit` added
2. Reach control panel in car B, retrieve elevator_control_module → flag `mascot_elevator_retrieved` set
3. Return to Ladderboy → quest complete → Ladderboy unlocks vertical travel shortcut in hub

---

## Location 3 — Food Court Fever Ward

**Scene:** `scenes/levels/FoodCourtFeverWard.tscn`
**Script:** `scripts/systems/FoodCourtFeverWard.gd`
**Quest:** Marbles personal quest — `quest_fever_ward`
**Quest giver:** Marbles (Faded Atrium hub, Cooters or clinic area)

**DIFFERENTIATION:** This is the **Market Row ground-floor food court** — the commercial strip at street level adjacent to Leak Street. It is NOT Dead Food Court Bloom, which is the **second-floor food-court-turned-bio-flora** zone accessed via Cooters job board. The Fever Ward is defined by food poisoning, heat damage, and sick civilians — not plant growth. Different floor, different biome, different hazard type.

### Site card

```yaml
site_id: quest_fever_ward
name: "Food Court Fever Ward"
site_type: "Market Row food court / mass food poisoning site"
region: market_row ground floor (not Faded Atrium second floor)
old_function: "ground-floor food court, budget vendor stalls, communal eating area"
current_function: "mass food poisoning incident — civilians collapsed; Marbles' contact trapped inside"
main_resource_pressure: medicine, food (negative — contaminated supply)
visual_identity:
  - vendor stall row east and west walls — shuttered or collapsed; greasy tile floors
  - central communal tables — civilians slumped against them, fever-sick, not dead
  - heat shimmer from broken kitchen exhaust stack at north end — visual heat distortion
  - medicine cabinet locked in north kitchen — Marbles' contact sheltering there
  - contaminated serving vat at center — the source; interactable with hazmat handling
  - lighting: one-third of overhead strips dead; remaining ones flicker with heat shimmer
key_spaces:
  - name: "South entry (Market Row access)"
    gameplay: "spawn; sick civilians immediately visible; heat shimmer north"
  - name: "Vendor stall row (east/west)"
    gameplay: "cover route around central tables; no direct hazard; patrol NPC possible"
  - name: "Central tables (hazard zone)"
    gameplay: "heat proximity damage (1.5 hp/s when within 4 units of vat); contaminated vat interactable"
  - name: "North kitchen"
    gameplay: "medicine cabinet target; Marbles' contact NPC; vent shutoff panel"
hazards:
  environmental: "proximity heat from contaminated vat — 1.5 hp/s within Area3D radius; not floor-dependent (y threshold not applicable here — use Area3D body_entered instead)"
  social_or_tactical: "one corporate hazmat response unit (Gatebox cleanup crew) patrols — hostile if quest not active"
player_approaches:
  combat: "push through central tables, fight hazmat unit, reach kitchen"
  stealth: "east or west vendor stall rows bypass central tables; approach kitchen from flank"
  technical: "vent_shutoff_panel in east stall deactivates heat source; flag fever_vat_vented; safe kitchen access"
twist: "the contaminated vat has a Gatebox supply chain seal on it — the food poisoning was a logistics error that corporate has already buried in a liability folder"
```

### Geometry spec

```
Room: x -10..10, z -12..6
VatHeatArea3D: size (4, 4, 4) at (0, 2, -2) — proximity damage radius; 1.5 hp/s body_entered
ContaminatedVat: StaticBody3D (1.5, 1.2, 1.5) at (0, 0.6, -2) — cylinder approximation; WardInteractable
EastStallRow: StaticBody3D (3, 2.5, 14) at (7, 1.25, -2) — stall wall
WestStallRow: StaticBody3D (3, 2.5, 14) at (-7, 1.25, -2)
KitchenNorthWall: StaticBody3D (20, 3.5, 0.35) at (0, 1.75, -10)
KitchenDoor: gap at x=2..4 in KitchenNorthWall
MedicineCabinet: WardInteractable at (0, 1.2, -11)
VentShutoffPanel: WardInteractable at (8.5, 1.05, 0) — east stall exterior wall
```

**Note on damage type:** VatHeatArea3D uses `body_entered` / `body_exited` (not y-threshold) since heat is a 3D proximity effect, not a floor-level hazard. `_in_heat` boolean; `_process()` applies damage when `_in_heat` is true regardless of y.

### Routes

**Route 1 — Central push combat**
- Walk through central tables, enter heat area
- Fight hazmat unit, reach kitchen door, collect medicine

**Route 2 — Stall row stealth**
- Hug east or west stall row wall (outside heat Area3D radius)
- Approach kitchen door from flank without entering heat zone

**Route 3 — Vent shutoff**
- Interact with vent_shutoff_panel at (8.5, 1.05, 0)
- Sets flag `fever_vat_vented`, deactivates VatHeatArea3D damage
- Walk through center freely

### Quest flow

1. Accept from Marbles → `quest_fever_ward_active` set → card `fever_ward_exit` added
2. Collect medicine from cabinet, speak to contact NPC → `fever_ward_medicine_retrieved` set
3. Return to Marbles → quest complete → Marbles unlocks advanced diagnostic dialogue

---

## Location 4 — Contamination Sump

**Scene:** `scenes/levels/ContaminationSump.tscn`
**Script:** `scripts/systems/ContaminationSump.gd`
**Quest:** System X investigation quest — `quest_contamination_sump`
**Quest giver:** System X terminal (Faded Atrium hub, server shrine)

**DIFFERENTIATION:** This is a **sub-pump contamination pocket** — a hidden secondary chamber fed by a cracked Torai biocanister. It is NOT Water Reclamation Cistern, which is the Cooters job destination for pump heart retrieval. Different location, different visual identity, different purpose. Cistern = Torai lease/retrieval (blue water). Sump = Torai contamination investigation (magenta biotech runoff). The player investigates what is poisoning the Leak Street water table — they don't retrieve anything.

### Site card

```yaml
site_id: quest_contamination_sump
name: "Contamination Sump"
site_type: "sub-pump contamination pocket / investigation site"
region: sub_sub_basement below cistern level
old_function: "overflow drain chamber for cistern pressure relief"
current_function: "cracked Torai biocanister is leaking magenta biotech runoff into the drain; source of Leak Street water contamination"
main_resource_pressure: water (negative — contamination source)
visual_identity:
  - magenta runoff pool at base — NOT blue water; glowing, thick, slow churn
  - cracked Torai biocanister on north platform — corporate yellow stripe, cracked casing, magenta seep
  - drain grate network on floor — runoff flowing toward Leak Street water table below
  - data logger terminal on east wall — System X has one node here already
  - containment valve on west wall — old cistern overflow control, not working; Torai lock on it
  - lighting: magenta bloom from pool below; yellow Torai safety lights (ironic) above canister
key_spaces:
  - name: "Entry hatch (top)"
    gameplay: "hatch from service crawlspace above; sump visible below; ladder or drop"
  - name: "Drain floor (magenta hazard)"
    gameplay: "2 hp/s when player.y < 1.2; canister platform and walkway are safe"
  - name: "Canister platform (north)"
    gameplay: "cracked canister investigation target; Torai corporate ID stamped — evidence"
  - name: "Data logger terminal (east wall)"
    gameplay: "System X uplink; upload contamination data; quest objective"
  - name: "Containment valve (west)"
    gameplay: "environmental option; Torai-locked but hackable; flag sump_valve_sealed"
hazards:
  environmental: "magenta runoff pool — 2 hp/s at y < 1.2; canister platform (surface y=0.8, player y≈1.85) is SAFE"
  social_or_tactical: "one Torai maintenance drone patrols — hostile; it is here to prevent exactly this investigation"
player_approaches:
  combat: "fight Torai drone, walk walkway to canister, investigate, upload to terminal"
  stealth: "entry hatch drops onto east walkway above drone patrol range; reach terminal first"
  technical: "containment_valve on west wall — hackable; seals canister leak, disables drone (Torai ID kill signal); flag sump_valve_sealed"
twist: "the Torai corporate ID on the canister matches the same ledger code as the cistern_filter_core_node from the pump heart job — same Torai supply chain failure, covered up at both ends"
```

### Geometry spec

```
Sump: x -6..6, z -8..4, y 0..5
MagentaPool Area3D: size (8, 3, 8) at (0, 0, -2) — 2 hp/s at y < 1.2
PoolFloor: StaticBody3D (8, 0.5, 8) at (0, -0.5, -2)
CanisterPlatform: StaticBody3D (4, 0.8, 4) at (0, 0.4, -6) — surface y=0.8; player y≈1.85 → SAFE
BrokenCanister: StaticBody3D (0.8, 1.6, 0.8) at (0, 1.2, -6) — WardInteractable "cracked_canister"
EastWalkway: StaticBody3D (2, 0.5, 12) at (5, -0.25, -2)     — surface y=0; player y≈1.05
DataLoggerTerminal: WardInteractable at (5.5, 1.05, 0)
ContainmentValve: WardInteractable at (-5.5, 1.05, -2)
EntryHatch: at (0, 5.0, 3.5) — drop to EastWalkway
```

### Routes

**Route 1 — Drone fight walkway**
- Enter hatch, land on east walkway
- Fight Torai drone, walk walkway to canister platform
- Investigate canister, upload to terminal

**Route 2 — Terminal first (stealth)**
- Drop from hatch onto east walkway above drone path
- Upload to data logger terminal immediately
- Drone deactivated by System X upload (flag: `sump_data_uploaded`)

**Route 3 — Containment valve hack**
- Reach containment_valve via east walkway (drone patrol gap)
- Hack valve: sets flag `sump_valve_sealed`, seals leak, sends Torai drone kill signal
- Investigate canister freely, upload data

### Quest flow

1. Accept from System X terminal → `quest_contamination_sump_active` set → card `sump_exit` added
2. Investigate canister AND upload data terminal → both flags set → `quest_contamination_sump_complete`
3. Return to System X terminal → quest complete → reveals Torai supply chain corruption lore entry; adds Wan Moa Torai rep -1 (enemy of the investigation)

---

## Location 5 — Corporate Sub-Level Cache

**Scene:** `scenes/levels/CorporateSubLevelCache.tscn`
**Script:** `scripts/systems/CorporateSubLevelCache.gd`
**Quest:** Exploration only — no active quest trigger required to enter
**Unlock:** Accessible after flag `sub_level_cache_discovered` (set by interacting with a hint object in Faded Atrium basement)

### Identity

A sealed Gatebox corporate archive level below the service corridor. Intact — no structural damage. The archive still has working lights, climate control, and one functioning terminal. No active quest sends the player here; the space rewards exploration and sets up future quest hooks.

### Site card

```yaml
site_id: quest_corporate_sub_level_cache
name: "Corporate Sub-Level Cache"
site_type: "intact corporate archive / undiscovered sub-level"
region: faded_atrium sub-basement (below service corridor)
old_function: "Gatebox corporate document archive, server backup unit, executive emergency shelter"
current_function: "sealed and forgotten; still functional; contains evidence of early mall design decisions"
main_resource_pressure: signal, shelter, salvage
visual_identity:
  - clean corporate aesthetic — white walls, grey floors, recessed lighting (still on)
  - filing terminal row east wall — six terminals; five dead, one active
  - server rack NW corner — still humming; Gatebox logo still lit
  - sealed vault door NW — "EXECUTIVE SHELTER — AUTHORIZED PERSONNEL ONLY"
  - document scattered on floor at entrance — evidence of someone leaving in a hurry
  - contrast to rest of game: nothing is broken or scavenged yet; uncanny cleanliness
key_spaces:
  - name: "Entry corridor (via hatch)"
    gameplay: "transition; uncanny clean contrast signals this is special"
  - name: "Terminal row"
    gameplay: "five dead terminals, one active — lore dumps; world history; Gatebox design documentation"
  - name: "Server rack"
    gameplay: "System X interest target; optional upload for System X rep gain"
  - name: "Vault door"
    gameplay: "locked; hackable in future quest; visual teaser for later content"
hazards:
  environmental: "none — the space itself is the tension"
  social_or_tactical: "corporate security ghost protocol activates on vault approach — one automated defense turret wakes"
player_approaches:
  combat: "fight turret, approach vault"
  stealth: "terminal row access avoids vault proximity; turret stays inactive"
  technical: "active_terminal offers turret override (System X uplink skill required)"
twist: "the server rack is still synced to an active Gatebox node — the corporation knows someone is in this room the moment the terminal is touched"
```

### No event deck cards required

This location has no quest-giver and no active job. Exploration lore is delivered via terminal interactables. No NAMED_CARDS entries. Discovery flag `sub_level_cache_discovered` is the only flag interaction.

---

## Location 6 — Protein Vat Nursery

**Scene:** `scenes/levels/ProteinVatNursery.tscn`
**Script:** `scripts/systems/ProteinVatNursery.gd`
**Quest:** Mister Static personal quest — `quest_vat_nursery`
**Quest giver:** Mister Static (Faded Atrium hub, Store 1 or central atrium)

### Identity

An old mall food science lab converted into a protein vat bioreactor. Mister Static has been maintaining it as a supplemental food source for the hub. A vat rupture has contaminated the nutrient bath and the whole system is at risk. Static needs someone to replace the culture vessel without killing the remaining viable culture strands.

### Site card

```yaml
site_id: quest_vat_nursery
name: "Protein Vat Nursery"
site_type: "food science lab / bioreactor nursery"
region: faded_atrium sub-basement (separate wing from Sub-Level Cache)
old_function: "mall food science demonstration lab for Gatebox nutrition products"
current_function: "Mister Static's protein cultivation operation; ruptured vat is the crisis"
main_resource_pressure: food, medicine
visual_identity:
  - row of four cylindrical vats along north wall — three intact (opaque beige culture), one cracked (leaking orange-brown)
  - bioreactor walkway raised above floor — safe surface at y=0.7
  - ruptured vat leak pool on floor — nutrient bath, 1 hp/s (organic acid burn), y < 1.2
  - culture sample node on upper vat platform — delicate interaction; wrong order corrupts sample
  - ventilation override panel east wall — neutralizes acid; flag nursery_vent_used
  - Static's supply crates stacked near south entry — contrast between maintenance and crisis
key_spaces:
  - name: "South entry"
    gameplay: "spawn; leak pool visible; bioreactor walkway raised path accessible"
  - name: "Bioreactor walkway"
    gameplay: "raised path y=0.7; player y≈1.75 → SAFE; connects entry to vat platform"
  - name: "Ruptured vat platform"
    gameplay: "culture_sample_node — sequential interactable (three steps: drain, collect, seal)"
  - name: "Ventilation panel (east)"
    gameplay: "neutralizes acid pool; flag nursery_vent_used"
hazards:
  environmental: "nutrient acid pool — 1 hp/s at y < 1.2; bioreactor walkway (y surface 0.7, player y≈1.75) SAFE"
  social_or_tactical: "no combat — this is a care and precision quest; rushing culture collection corrupts the sample"
player_approaches:
  combat: "n/a (no combat beat)"
  stealth: "n/a"
  technical: "ventilation_override neutralizes pool for safe floor access; sequential culture_sample_node interaction is the core puzzle"
twist: "one of the intact vats contains a small preserved animal — Static has been keeping it alive for 18 months and has named it"
```

### Geometry spec

```
Lab: x -8..8, z -10..6, y 0..5
AcidPool Area3D: size (14, 3, 10) at (0, 0, -2) — 1 hp/s at y < 1.2
PoolFloor: StaticBody3D (14, 0.5, 10) at (0, -0.5, -2)
BioreactorWalkway: StaticBody3D (14, 0.7, 2) at (0, 0.35, 1) — surface y=0.7; player y≈1.75 → SAFE
VatPlatform: StaticBody3D (4, 0.7, 4) at (0, 0.35, -8) — surface y=0.7; SAFE
CultureSampleNode: WardInteractable at (0, 1.05, -8) — sequential three-step interaction
VentilationOverride: WardInteractable at (7.5, 1.05, 0)
VatA: StaticBody3D (1.2, 3, 1.2) at (-4, 1.5, -8) — intact
VatB: StaticBody3D (1.2, 3, 1.2) at (-1.5, 1.5, -8) — intact
VatC: StaticBody3D (1.2, 3, 1.2) at (1.5, 1.5, -8) — intact
VatD_Cracked: StaticBody3D (1.2, 3, 1.2) at (4, 1.5, -8) — cracked; orange-brown emission
```

### Quest flow

1. Accept from Mister Static → `quest_vat_nursery_active` set → card `vat_nursery_exit` added
2. Complete three-step culture_sample_node interaction → `nursery_culture_saved` set
3. Return to Static → quest complete → Static unlocks food supply to hub (flag `hub_food_supply_active`)

---

## WorldDirector Integration

Add these entries to `WorldDirector.NAMED_CARDS` in `scripts/systems/WorldDirector.gd`:

```gdscript
# --- Filter Crypt (Pipe Father Gideon quest) ---
"filter_crypt_exit": {
    "id": "filter_crypt_exit", "title": "Gideon's Filter Warning",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_filter_crypt_active"},
    "effects": [], "expires_after": 1, "tags": ["filter_crypt_active"],
    "speaker": "Pipe Father Gideon",
    "text": "The mineral scale is three centimeters thick on the housing. Bring a wrench and patience. The pipes will know if you rush it.",
},
"filter_crypt_travel": {
    "id": "filter_crypt_travel", "title": "Pipe Hymn Interference",
    "contexts": ["travel"], "weight": 2,
    "conditions": {"flag_true": "quest_filter_crypt_active"},
    "effects": [], "expires_after": -1, "tags": ["filter_crypt_active"],
    "speaker": "Pipe Father Gideon",
    "text": "The congregation is singing to the pressure relief shaft. This happens every third cycle. It is devotion, not a leak.",
},
"filter_crypt_return": {
    "id": "filter_crypt_return", "title": "Filter Repaired",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {}, "effects": [{"type": "set_flag", "flag": "filter_crypt_repaired", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "Pipe Father Gideon",
    "text": "The filter sings again. The congregation believes this is divine. I believe it is also solvent and a torque wrench. Both things can be true.",
},

# --- Mascot Elevator Stack (Ladderboy quest) ---
"mascot_elevator_exit": {
    "id": "mascot_elevator_exit", "title": "Elevator Shaft Warning",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_mascot_elevator_active"},
    "effects": [], "expires_after": 1, "tags": ["mascot_elevator_active"],
    "speaker": "Ladderboy",
    "text": "Middle car has an interlock fault. The safety relay thinks the car is still moving. It is not moving. It has not moved in four years. Be gentle with it.",
},
"mascot_elevator_travel": {
    "id": "mascot_elevator_travel", "title": "Shaft Signal Bleed",
    "contexts": ["travel"], "weight": 2,
    "conditions": {"flag_true": "quest_mascot_elevator_active"},
    "effects": [{"type": "set_event", "event_id": "lan_outage"}],
    "expires_after": -1, "tags": ["mascot_elevator_active"],
    "speaker": "System X",
    "text": "Gatebox corporate ID ping from the elevator shaft. The mascot in car C is broadcasting. Corporate does not know it is awake. Yet.",
},
"mascot_elevator_return": {
    "id": "mascot_elevator_return", "title": "Elevator Module Retrieved",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {}, "effects": [{"type": "set_flag", "flag": "mascot_elevator_retrieved", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "Ladderboy",
    "text": "Control module is in. Shaft B is live. If you talked to car C, we should discuss what you found. Carefully.",
},

# --- Food Court Fever Ward (Marbles quest) ---
"fever_ward_exit": {
    "id": "fever_ward_exit", "title": "Market Row Hazmat",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_fever_ward_active"},
    "effects": [], "expires_after": 1, "tags": ["fever_ward_active"],
    "speaker": "Marbles",
    "text": "The vat is still hot. Gatebox hazmat crew is already there, which means they are trying to contain the story, not the problem. My contact is in the kitchen.",
},
"fever_ward_travel": {
    "id": "fever_ward_travel", "title": "Market Row Lockdown",
    "contexts": ["travel"], "weight": 2,
    "conditions": {"flag_true": "quest_fever_ward_active"},
    "effects": [{"type": "set_event", "event_id": "power_sag"}],
    "expires_after": -1, "tags": ["fever_ward_active"],
    "speaker": "Marbles",
    "text": "Gatebox logistics pulled power to Market Row to delay the food safety audit. The heat vat has no automatic shutoff now. Perfect.",
},
"fever_ward_return": {
    "id": "fever_ward_return", "title": "Fever Ward Clear",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {}, "effects": [{"type": "set_flag", "flag": "fever_ward_medicine_retrieved", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "Marbles",
    "text": "Medicine is in. My contact is fine, which is medically interesting because they should not be. I am choosing to be grateful and professionally confused.",
},

# --- Contamination Sump (System X quest) ---
"sump_exit": {
    "id": "sump_exit", "title": "Torai Leak Source",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_contamination_sump_active"},
    "effects": [], "expires_after": 1, "tags": ["sump_active"],
    "speaker": "System X",
    "text": "The contamination source is a cracked Torai biocanister in the overflow drain. The product ID matches a Wan Moa Torai supply manifest that was redacted three weeks ago. Go get the physical evidence.",
},
"sump_travel": {
    "id": "sump_travel", "title": "Torai Network Ping",
    "contexts": ["travel"], "weight": 2,
    "conditions": {"flag_true": "quest_contamination_sump_active"},
    "effects": [{"type": "set_event", "event_id": "lan_outage"}],
    "expires_after": -1, "tags": ["sump_active"],
    "speaker": "System X",
    "text": "Torai maintenance drone went active in the sump. They know someone accessed the drain map. The drone is there to prevent exactly what you are about to do. Proceed.",
},
"sump_return": {
    "id": "sump_return", "title": "Contamination Evidence Logged",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {},
    "effects": [
        {"type": "set_flag", "flag": "sump_data_uploaded", "value": true},
        {"type": "add_rep", "faction": "Wan Moa Torai", "amount": -1},
    ],
    "expires_after": 0, "tags": [],
    "speaker": "System X",
    "text": "Evidence is in the catalogue. The product ID links the sump canister to the cistern supply chain and to a Torai liability entry that was closed without investigation. Torai is aware we have this. Proceed accordingly.",
},

# --- Protein Vat Nursery (Mister Static quest) ---
"vat_nursery_exit": {
    "id": "vat_nursery_exit", "title": "Vat Rupture Report",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_vat_nursery_active"},
    "effects": [], "expires_after": 1, "tags": ["vat_nursery_active"],
    "speaker": "Mister Static",
    "text": "Vat D cracked along the lower seam. The culture is viable if you get the sample before the acid bath reaches the collection port. I timed it. You have room.",
},
"vat_nursery_travel": {
    "id": "vat_nursery_travel", "title": "Nutrient Bath Fumes",
    "contexts": ["travel"], "weight": 2,
    "conditions": {"flag_true": "quest_vat_nursery_active"},
    "effects": [{"type": "set_event", "event_id": "toxic_rain"}],
    "expires_after": -1, "tags": ["vat_nursery_active"],
    "speaker": "Mister Static",
    "text": "The vat fumes are venting through the building system. The fake sky is raining acid right now. Seal your intake. Do not ask how I know what the sky smells like.",
},
"vat_nursery_return": {
    "id": "vat_nursery_return", "title": "Culture Saved",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {}, "effects": [{"type": "set_flag", "flag": "nursery_culture_saved", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "Mister Static",
    "text": "Culture is viable. Vat D is sealed. The one in vat B says thank you, in whatever way something that has not yet developed language says anything. I believe it.",
},
```

---

## GameState Flags Reference

Flags to register in `GameState` for quest tracking:

```gdscript
# Filter Crypt
"quest_filter_crypt_active"       # set on quest accept
"filter_crypt_vent_used"          # set on vent override use
"filter_crypt_repaired"           # set on filter housing repair
"quest_filter_crypt_complete"     # set on return to Gideon

# Mascot Elevator
"quest_mascot_elevator_active"
"mascot_relay_cut"                # set on shaft relay panel use
"mascot_elevator_retrieved"       # set on control panel retrieve
"quest_mascot_elevator_complete"

# Food Court Fever Ward
"quest_fever_ward_active"
"fever_vat_vented"                # set on vent shutoff panel use
"fever_ward_medicine_retrieved"   # set on medicine cabinet collect
"quest_fever_ward_complete"

# Contamination Sump
"quest_contamination_sump_active"
"sump_valve_sealed"               # set on containment valve hack
"sump_data_uploaded"              # set on data terminal upload
"quest_contamination_sump_complete"

# Protein Vat Nursery
"quest_vat_nursery_active"
"nursery_vent_used"               # set on ventilation override
"nursery_culture_saved"           # set on culture sample complete
"hub_food_supply_active"          # set on quest complete (hub consequence)
"quest_vat_nursery_complete"
```
