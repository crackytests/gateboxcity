# Gatebox — Faded Atrium Hub Buildout Plan

Implementation plan for `MallHub.tscn` — the Faded Atrium, the player's base of operations inside the Sub-Sub Basement. This document covers layout, NPC placement, hub quests, phase progression, and EventDeckSystem integration.

Companion documents: `docs/cooters_job_destination_agent_plan.md`, `docs/quest_location_buildout_plan.md`, `docs/gatebox_game_design_doc_for_codex.md`.

---

## Hub Philosophy

The Faded Atrium is not a safe house — it is a contested ruin that the player and a small group of survivors slowly make functional. Every improvement costs effort. The hub should reflect its phase: phase 1 is barely occupied; phase 3 feels like a real place that people chose to build. Each phase expansion is driven by hub quests, not passive timers.

The hub is always accessible. The travel gate is inside it. Cooters job board is inside it. NPCs accumulate here as the game progresses. Ambient event cards reflect hub state.

---

## Scene File

**Scene:** `scenes/levels/MallHub.tscn`
**Script:** `scripts/systems/MallHub.gd`

The script builds geometry in `_ready()`. NPC nodes are either always-present or spawned based on flags. Phase state is read from `GameState` flags on load.

---

## IMPLEMENTATION NOTE — Current Build (2026 update)

The shipped hub diverged from the flat 8-store sketch below into a **two-floor mezzanine**. The
sections after this note are preserved as original design intent; where they conflict, the build
described here wins.

### Actual layout

```
            UPPER FLOOR (mezzanine, floor surface y=6.4, reached by central escalators)
   [Vera][Kiki Baja][Ladderboy][Velvet Coil]      <- upper north store row, z(-9..-16)
            |  railings ring the atrium void  |
   ========================================== central escalators (x=±1.5, z+4 → z-4) ==========
            GROUND FLOOR
   [Mister Static][Gideon][Bar(Store3)][Unclaimed(Store4)]   <- south store row, z(+9..+16)
            CENTRAL ATRIUM x(-16..+16) z(-9..+9) h=10
            (route gates + System X terminal + mission board + cybernetics kiosk live here)
   North service stub + basement hatch (z -9..-16)   |   South entry corridor (z +16..+25, player spawn)
```

- **Ground-floor tenants (phase 1):** Mister Static (x=-12), Pipe Father Gideon (x=-4). Store 3 (x=+4)
  is the sealed Bar; Store 4 (x=+12) is an unclaimed sealed slot (dressing only — see Velvet Coil below).
- **Upper-floor tenants (phase 2+):** Vera (x=-12), Kiki Baja (x=-4), Ladderboy (x=+4) arrive at phase 2;
  Velvet Coil (x=+12) arrives at phase 3. All stand at z=-12.5, y=7.45, behind a shop counter (NPC focus
  radius widened to 2.6 so they're reachable across the counter). Each upper store is dressed by
  `_build_upper_shop()` (counter, back shelving, crate, one character prop).
- **Upper-floor access** requires the escalators, which are a small fetch task (Motor Crate → Escalator
  Console). Phase 2's log line points the player at the escalator if it isn't running yet.

### Light services (per `AskUserQuestion` decision)

- **Vera** — heals the player to full HP on every interaction; her cistern quest still runs in dialogue.
- **Kiki Baja** — reads out current Wan Moa Torai standing.
- **Ladderboy** — gives the Clear-the-Court quest hook (existing).
- **Velvet Coil** — opens the cybernetics menu (surgical suite) — phase 3 only.
- **Vessel (hub bar)** — the repaired bunny android tends the hub's Cooters branch once the bar opens.
  Marbles keeps the *original* Cooters elsewhere; the mall bar is Vessel's. Vessel relocates from the
  atrium (LAN-quest spot) to behind the bar counter when `bar_open` is set.

### Bar (Store 3) — now a real phase-3 quest

`bar_open` is **no longer auto-set by phase 2**. Store 3 stays sealed; a "Bar Door" interactable in
front of it opens the bar **only when `hub_cistern_connected` is true** (`_open_bar()` → removes seal,
builds bar interior, spawns Marbles, re-checks phase). This restores the doc's original intent.

### Velvet Coil reconciliation

The old ground-floor "Store 4 claim" quest (`hub_store_4`) is **deprecated** — Velvet Coil now lives in
the **upper** fourth store as the surgical suite, arriving at phase 3 after `coil_invitation_accepted`
(set via the invitation flow in `SubSubBasementDistrict.gd`). Ground Store 4 stays a sealed dressing slot.

### Phase gating (as built)

- **Phase 2** = `hub_power_restored` AND `hub_lan_restored` → spawns upper tenants, unlocks basement hatch.
- **Phase 3** = `hub_phase_2` AND `hub_cistern_connected` AND `nursery_culture_saved` AND `bar_open`
  → Velvet Coil arrives, hub radio + planters/warm-light dressing pass.

### Upper-floor access notes

- The atrium **north wall** (`AtriumWallNL/NR/NTop` at z=-9.2) is **ground-floor height only (y 0..6)**.
  It must NOT extend to full height (y=10) or it seals the mezzanine off from the upper store row —
  the upper walkway connects to the stores through the entry pillars at z=-9.
- The **active escalator** material (`_mat_esc_on`) uses low emission (~0.35) with a bright cyan albedo,
  so the step texture stays readable instead of blowing out to a solid cyan slab.

(Dev shortcuts F7 / 0-key used during buildout have been removed.)

---

## Layout

```
     N (service corridor → basement access)
     |
[Store 8][Store 7][Store 6][Store 5]
     |                           |
[Service Corridor ——— Central Atrium ——— East Corridor]
     |                           |
[Store 1][Store 2][Store 3][Store 4]
     |
     S (Leak Street access / main entry)
     |
  [Travel Gate + Cooters Job Board]
```

### Spaces

| Space | Dimensions (approx) | Notes |
|---|---|---|
| Central Atrium | (20, 6, 20) | Hub heart; cleared in Clear_The_Court quest |
| South Corridor | (6, 4, 8) | Entry from Leak Street; travel gate + Cooters board here |
| Service Corridor N | (6, 4, 12) | Access to basement hatch |
| Store 1 (SW) | (8, 4, 8) | Mister Static — protein vat nutrition unit |
| Store 2 (S) | (8, 4, 8) | Pipe Church — Gideon + congregation |
| Store 3 (SE) | (8, 4, 8) | Bar — sealed until Bar_Open quest |
| Store 4 (NW) | (8, 4, 8) | Unclaimed until Store_4_Claim quest |
| Store 5 (N) | (8, 4, 8) | Vera's medical station |
| Store 6 (NE) | (8, 4, 8) | Vessel (Bunny Unit) — data shrine |
| Store 7 (N) | (8, 4, 8) | Kiki Baja — Torai liaison desk |
| Store 8 (NW) | (8, 4, 8) | Ladderboy — vertical access workshop |
| Basement Hatch | — | Hatch at north end of service corridor |

---

## Phase Progression

Hub phases are tracked via world flags in `GameState`. Each phase unlocks NPC availability, store functionality, and ambient EventDeck card pools.

### Phase 1 — Occupied Ruin

**Flag:** `hub_phase_1` (default; always true)

**State:**
- Central atrium blocked by debris; only south corridor and stores 1-3 accessible
- Stores 4-8 locked or inaccessible
- Only Mister Static, Gideon, and Marbles (at Cooters board) present
- Generator is sagging (`WorldDirector.GENERATOR_SAGGING`)
- No LAN connection; System X terminal offline

**Visual:** Emergency lighting only — warm orange single strip lights, long shadows. Debris piles in atrium center.

### Phase 2 — Working Base

**Flags required:** `hub_power_restored` AND `hub_lan_restored`
**Set flag:** `hub_phase_2` — set when both conditions are met (check in `MallHub._check_phase()`)

**Unlocks:**
- Atrium debris cleared (if Clear_The_Court also complete)
- Generator stable (`GENERATOR_STABLE`) — full lighting
- System X terminal online
- Stores 5-7 accessible (Vera, Vessel, Kiki Baja arrive)
- Velvet Coil invitation card active (if `coil_met_in_tunnels` flag set)
- Basement hatch accessible

**Visual:** Full overhead lighting restored, warmer tone. Atrium cleared. Vendor stalls with activity.

### Phase 3 — Restored Hub

**Flags required:** `hub_phase_2` AND `hub_cistern_connected` AND `nursery_culture_saved` AND `bar_open`
**Set flag:** `hub_phase_3`

**Unlocks:**
- All stores active
- Velvet Coil present in hub (if `coil_invitation_accepted`)
- Store 4 claimed (if `store_4_claimed`)
- Water supply active (clean water nodes in hub)
- Bar open; social hub beat active

**Visual:** Hub feels inhabited — improvised furniture, ambient NPC chatter, hub radio playing, plants from Static's nursery at south entry.

---

## NPC Roster

| NPC | Location in hub | Available from | Notes |
|---|---|---|---|
| Mister Static | Store 1 | Phase 1 | Quest giver: quest_vat_nursery |
| Pipe Father Gideon | Store 2 | Phase 1 | Quest giver: quest_filter_crypt |
| Marbles | Cooters board (south corridor) | Phase 1 | Cooters job dialogue |
| Vera | Store 5 | Phase 2 | Medical; passive healing service |
| Vessel (Bunny Unit) | Store 6 | Phase 2 | Data archive; System X faction |
| Kiki Baja | Store 7 | Phase 2 | Torai liaison; tracks Torai rep |
| Ladderboy | Store 8 | Phase 2 (after mascot_elevator_retrieved) | Quest giver: quest_mascot_elevator |
| Velvet Coil | **NOT in hub by default** — see below | Phase 3 only | Coil_Invitation quest required |

### Velvet Coil — Corrected Placement

Velvet Coil's **initial encounter is in PipeUtilityTunnels.tscn**, not the hub. She is found in the west passage of the tunnels during a Cooters job run. The player meets her there, triggering the `coil_met_in_tunnels` flag and the `coil_invitation_card` EventDeck event.

She only appears **in the hub** (Store 4 or central atrium) after:
1. `coil_met_in_tunnels` is true (met in tunnels)
2. `coil_invitation_accepted` is true (player accepted her invitation)
3. `hub_phase_3` is true (hub is ready)

If `coil_invitation_available` is false (hub not yet at phase 2), she does not spawn in PipeUtilityTunnels. Set `coil_invitation_available` true when `hub_phase_2` is set.

---

## Hub Quests

### Hub_Power — Restore Generator

**Quest giver:** Mister Static or ambient note in Store 1
**Flag set on accept:** `quest_hub_power_active`
**Objective:** Locate the generator room in the basement, repair the power coupling
**Destination:** Generator room (accessible via basement hatch; small sub-scene or area in MallHub basement extension)
**On complete:** `hub_power_restored` = true; WorldDirector.generator_state → GENERATOR_STABLE; check phase upgrade

**EventDeckSystem cards (add to NAMED_CARDS):**
```gdscript
"hub_power_exit": {
    "id": "hub_power_exit", "title": "Generator Run",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_hub_power_active"},
    "effects": [], "expires_after": 1, "tags": ["hub_power_active"],
    "speaker": "Mister Static",
    "text": "The coupling is in the basement. I have been fixing it with tape for six weeks. It deserves better. So does the tape.",
},
"hub_power_return": {
    "id": "hub_power_return", "title": "Generator Online",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {},
    "effects": [{"type": "set_flag", "flag": "hub_power_restored", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "Mister Static",
    "text": "Generator is stable. The lights are full and everyone is acting like they cannot believe they live here. Some of them still cannot. That is progress.",
},
```

---

### Hub_LAN — Restore LAN Connection

**Quest giver:** Vessel (Bunny Unit) in Store 6 OR System X terminal (unlocked at phase 2 approach)
**Flag set on accept:** `quest_hub_lan_active`
**Objective:** Find the LAN relay splice point in the service corridor ceiling; connect a new tap cable
**On complete:** `hub_lan_restored` = true; System X terminal goes online; check phase upgrade

**EventDeckSystem cards:**
```gdscript
"hub_lan_exit": {
    "id": "hub_lan_exit", "title": "LAN Tap Run",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_hub_lan_active"},
    "effects": [{"type": "set_event", "event_id": "lan_outage"}],
    "expires_after": 1, "tags": ["hub_lan_active"],
    "speaker": "System X",
    "text": "The tap cable is in the service corridor ceiling panel above the north corridor junction. Hoodlums clipped it during the last LAN party. Bring a splice kit.",
},
"hub_lan_return": {
    "id": "hub_lan_return", "title": "LAN Restored",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {},
    "effects": [{"type": "set_flag", "flag": "hub_lan_restored", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "System X",
    "text": "LAN is live. I am now watching fourteen feeds I was not watching before. Three of them are concerning. I will tell you when it is actionable.",
},
```

---

### Coil_Invitation — Invite Velvet Coil to Hub

**Quest giver:** Velvet Coil herself, encountered in PipeUtilityTunnels (west passage)
**Trigger:** Interacting with Velvet Coil NPC when `coil_invitation_available` is true
**Flag set:** `coil_met_in_tunnels` = true; `coil_invitation_card` added to EventDeck
**Objective:** Return to hub and tell Gideon or Mister Static about the invitation (social step)
**On complete:** `coil_invitation_accepted` = true; Velvet Coil spawns in hub at phase 3

**EventDeckSystem card:**
```gdscript
"coil_invitation_card": {
    "id": "coil_invitation_card", "title": "Velvet Coil Message",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {"flag_true": "coil_met_in_tunnels"},
    "effects": [],
    "expires_after": 1, "tags": ["coil_invitation"],
    "speaker": "Velvet Coil",
    "text": "Tell them I am still thinking about the invitation. I have conditions. Most of them are about the acoustics of the space. The rest are about Torai.",
},
```

---

### Bar_Open — Open the Bar in Store 3

**Quest giver:** Any NPC at phase 2 OR player discovers sealed Store 3 door
**Flag set on accept:** `quest_bar_open_active`
**Objective:** Source a working tap connection (sub-quest for Bar_Open — connects to Hub_Cistern water)
**Prerequisite:** `hub_cistern_connected` must be true (clean water supply)
**On complete:** `bar_open` = true; Store 3 opens; social hub beat activates; check phase 3

---

### Clear_The_Court — Clear Atrium Debris

**Quest giver:** Ladderboy (store 8)
**Flag set on accept:** `quest_clear_court_active`
**Objective:** Remove three debris piles from central atrium (three interactable StaticBody3D nodes)
**On complete:** `atrium_cleared` = true; atrium traversal fully open; ambient NPC movement range expands

---

### Store_4_Claim — Claim Unclaimed Store

**Quest giver:** Velvet Coil (after hub arrival) OR ambient note
**Flag set on accept:** `quest_store_4_active`
**Objective:** Clear Store 4 of old corporate squatter data (terminal wipe + physical cleanup)
**On complete:** `store_4_claimed` = true; Velvet Coil (or player-chosen NPC) moves to Store 4

---

### Hub_Cistern — Connect Cistern Water to Hub

**Quest giver:** Vera (medical station, Store 5) — she needs clean water for clinic
**Flag set on accept:** `quest_hub_cistern_active`
**Connection:** Links to existing world_flag `cistern_valve_used` — if the Cooters cistern job already shut off the hazard water, the pipe run is partially done
**Objective:** Install water conduit from WaterReclamationCistern west walkway to hub pipe junction in service corridor
**Compatibility check in script:**
```gdscript
if GameState.get_world_flag("cistern_valve_used", false):
    # Conduit installation is easier — valve already sealed; skip one step
    hud.push_log("Pipe valve already bled — conduit run simplified")
```
**On complete:** `hub_cistern_connected` = true; enables Bar_Open prerequisite; check phase 3

**EventDeckSystem cards:**
```gdscript
"hub_cistern_exit": {
    "id": "hub_cistern_exit", "title": "Conduit Run",
    "contexts": ["district_exit"], "weight": 2,
    "conditions": {"flag_true": "quest_hub_cistern_active"},
    "effects": [], "expires_after": 1, "tags": ["hub_cistern_active"],
    "speaker": "Vera",
    "text": "The junction point is on the west walkway of the cistern. Torai has a monitoring node there. Do not let it log you. Clean water is worth the careful approach.",
},
"hub_cistern_return": {
    "id": "hub_cistern_return", "title": "Hub Water Connected",
    "contexts": ["hub_return"], "weight": 3,
    "conditions": {},
    "effects": [{"type": "set_flag", "flag": "hub_cistern_connected", "value": true}],
    "expires_after": 0, "tags": [],
    "speaker": "Vera",
    "text": "Water is running. I ran three purity tests. It passed all three, which is two more than I expected. I am not going to question this.",
},
```

---

## EventDeckSystem — Phase-Driven Ambient Cards

These cards fire automatically on `hub_return` based on hub phase state. They do not require an active quest — they reflect the hub's current condition and give it narrative texture. Add to `WorldDirector.NAMED_CARDS`.

```gdscript
# Phase 1 ambient — hub is barely functioning
"hub_ambient_phase1_a": {
    "id": "hub_ambient_phase1_a", "title": "Generator Cough",
    "contexts": ["hub_return"], "weight": 1,
    "conditions": {"flag_false": "hub_power_restored"},
    "effects": [], "expires_after": -1, "tags": ["hub_ambient"],
    "speaker": "Mister Static",
    "text": "The generator coughed twice while you were out. I told it things would improve. It did not seem convinced. I am not either but I kept that part private.",
},
"hub_ambient_phase1_b": {
    "id": "hub_ambient_phase1_b", "title": "Offline",
    "contexts": ["hub_return"], "weight": 1,
    "conditions": {"flag_false": "hub_lan_restored"},
    "effects": [], "expires_after": -1, "tags": ["hub_ambient"],
    "speaker": "System X",
    "text": "I cannot see anything from here. This is not a complaint, it is a capability summary. Please fix the LAN before I have to say this again.",
},

# Phase 2 ambient — hub is working
"hub_ambient_phase2_a": {
    "id": "hub_ambient_phase2_a", "title": "Lights Are On",
    "contexts": ["hub_return"], "weight": 1,
    "conditions": {"flag_true": "hub_phase_2"},
    "effects": [], "expires_after": -1, "tags": ["hub_ambient"],
    "speaker": "Mister Static",
    "text": "Three people asked me if we were staying. I said yes. Two of them started carrying things in from the corridor. I think we are staying.",
},
"hub_ambient_phase2_b": {
    "id": "hub_ambient_phase2_b", "title": "Torai Desk Note",
    "contexts": ["hub_return"], "weight": 1,
    "conditions": {"flag_true": "hub_phase_2"},
    "effects": [], "expires_after": -1, "tags": ["hub_ambient"],
    "speaker": "Kiki Baja",
    "text": "Wan Moa Torai sent a message. It says they are aware of our location and are interested in providing services. It is formatted as a sales letter. I am choosing to read it as a threat.",
},

# Phase 3 ambient — hub is restored
"hub_ambient_phase3_a": {
    "id": "hub_ambient_phase3_a", "title": "Bar is Open",
    "contexts": ["hub_return"], "weight": 1,
    "conditions": {"flag_true": "hub_phase_3"},
    "effects": [], "expires_after": -1, "tags": ["hub_ambient"],
    "speaker": "Marbles",
    "text": "The bar opened. I do not think any of us thought we would get here. I am going to celebrate this professionally and also with a drink.",
},
"hub_ambient_phase3_b": {
    "id": "hub_ambient_phase3_b", "title": "Velvet Coil Radio",
    "contexts": ["hub_return"], "weight": 1,
    "conditions": {"flag_true": "coil_invitation_accepted"},
    "effects": [], "expires_after": -1, "tags": ["hub_ambient"],
    "speaker": "Velvet Coil",
    "text": "I set up the radio. The acoustics here are acceptable. I was not going to say that unless they were. They are. That is the extent of my enthusiasm. For now.",
},

# Existing world_flag callbacks — these fire once when job-destination flags are set
"hub_pipe_valve_note": {
    "id": "hub_pipe_valve_note", "title": "Pipe Pressure Note",
    "contexts": ["hub_return"], "weight": 2,
    "conditions": {"flag_true": "pipe_valve_used"},
    "effects": [], "expires_after": 1, "tags": [],
    "speaker": "Pipe Father Gideon",
    "text": "You bled the pressure valve. The pipes are quieter. The congregation thinks it is a sign. I told them it was maintenance. They think that too is a sign.",
},
"hub_spore_vent_note": {
    "id": "hub_spore_vent_note", "title": "Bloom Court Vented",
    "contexts": ["hub_return"], "weight": 2,
    "conditions": {"flag_true": "spore_vent_used"},
    "effects": [], "expires_after": 1, "tags": [],
    "speaker": "Marbles",
    "text": "Spore count in the food court is down forty percent since the vent panel. I know because I am tracking it. I started tracking it because I was concerned. I am less concerned now.",
},
"hub_atrium_gate_note": {
    "id": "hub_atrium_gate_note", "title": "Hardlight Gate Opened",
    "contexts": ["hub_return"], "weight": 2,
    "conditions": {"flag_true": "atrium_gate_opened"},
    "effects": [], "expires_after": 1, "tags": [],
    "speaker": "System X",
    "text": "Hardlight bridge is active in the service atrium. The gate panel is Gatebox tech. If they are logging access, they know. I am logging that they might be logging.",
},
```

---

## MallHub.gd — Phase Check Pattern

```gdscript
func _check_phase() -> void:
    var power := GameState.get_world_flag("hub_power_restored", false)
    var lan := GameState.get_world_flag("hub_lan_restored", false)
    var cistern := GameState.get_world_flag("hub_cistern_connected", false)
    var culture := GameState.get_world_flag("nursery_culture_saved", false)
    var bar := GameState.get_world_flag("bar_open", false)

    if power and lan and not GameState.get_world_flag("hub_phase_2", false):
        GameState.set_world_flag("hub_phase_2", true)
        GameState.set_world_flag("coil_invitation_available", true)
        _apply_phase_2()
        hud.push_log("Hub: Working Base established")

    if GameState.get_world_flag("hub_phase_2", false) and cistern and culture and bar:
        if not GameState.get_world_flag("hub_phase_3", false):
            GameState.set_world_flag("hub_phase_3", true)
            _apply_phase_3()
            hud.push_log("Hub: Restored Hub achieved")

func _apply_phase_2() -> void:
    # Upgrade WorldDirector generator state
    WorldDirector.generator_state = WorldDirector.GENERATOR_STABLE
    # Spawn phase 2 NPCs
    _spawn_npc("vera", Vector3(-8, 1.05, -6))
    _spawn_npc("vessel", Vector3(8, 1.05, -6))
    _spawn_npc("kiki_baja", Vector3(8, 1.05, 6))
    # Unlock basement hatch
    _unlock_basement_hatch()

func _apply_phase_3() -> void:
    # Spawn Velvet Coil if invited
    if GameState.get_world_flag("coil_invitation_accepted", false):
        _spawn_npc("velvet_coil", Vector3(-8, 1.05, 0))
    # Open Store 4
    if GameState.get_world_flag("store_4_claimed", false):
        _open_store(4)
    # Activate hub radio
    _activate_hub_radio()
```

---

## Compatibility with Existing World Flags

These flags are set in Cooters job destination scripts and are read by hub scripts. No changes needed to the job scripts — the hub reads them:

| Flag | Set in | Read in hub for |
|---|---|---|
| `pipe_valve_used` | PipeUtilityTunnels.gd | `hub_pipe_valve_note` ambient card |
| `saint_ratchet_returned` | WorldDirector (ratchet_saint_return card effect) | Gideon NPC dialogue variant |
| `pipes_catalogue_updated` | WorldDirector (listen_pipes_return card effect) | System X terminal lore entry |
| `spore_vent_used` | DeadFoodCourtBloom.gd | `hub_spore_vent_note` ambient card |
| `cistern_valve_used` | WaterReclamationCistern.gd | Hub_Cistern quest — simplifies conduit install |
| `atrium_relay_data_logged` | WorldDirector (atrium_relay_return card effect) | `hub_atrium_gate_note` ambient card |

---

## Implementation Checklist

- [ ] MallHub.gd builds all hub geometry in `_ready()` via `_add_box()` helpers
- [ ] Player spawns in south corridor at z=8 (Leak Street entry side)
- [ ] HUD node present in MallHub.tscn
- [ ] Travel gate and Cooters job board in south corridor
- [ ] `_wire_runtime()` reads all flags and applies current state on load
- [ ] `_check_phase()` called in `_wire_runtime()` and after each quest flag is set
- [ ] Store doors: closed StaticBody3D panels removed when store is unlocked
- [ ] NPC spawn system: `_spawn_npc(npc_id, position)` checks phase and flag conditions
- [ ] Velvet Coil: only spawns in PipeUtilityTunnels when `coil_invitation_available` is true
- [ ] Velvet Coil: only spawns in hub when `coil_invitation_accepted` AND `hub_phase_3` are true
- [ ] Hub_Cistern quest: checks `cistern_valve_used` to simplify the conduit objective
- [ ] All new NAMED_CARDS entries added to WorldDirector.NAMED_CARDS dict
- [ ] `hub_phase_2` and `hub_phase_3` flags not manually set — only set via `_check_phase()`
- [ ] WorldDirector.generator_state updated to GENERATOR_STABLE when `hub_power_restored` is set
- [ ] Basement hatch StaticBody3D removed when `hub_phase_2` flag is set on load
