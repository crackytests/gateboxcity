# GATEBOX BREACH — Expansion Plan
*Pip-Boy Interface + Full System Build-Out*
*Drawing from: IZ2, Judge Dredd, Mutant Year Zero, Gatebox Breach Lore Bible*

---

## Overview

Six phases, sequenced so each one ships something playable before the next starts.
Nothing here requires gutting what exists — every phase extends the current architecture.

---

## WHAT EXISTS RIGHT NOW

| System | File | State |
|---|---|---|
| InventorySystem | `scripts/systems/InventorySystem.gd` | Simple string dict, 9-item ITEM_DB in UI |
| QuestSystem | `scripts/systems/QuestSystem.gd` | Hard-coded `wake_up_call` steps |
| GameState | `scripts/systems/GameState.gd` | Central save/load; 6 jobs; 5 hub quests; 5 cybernetics |
| WorldDirector | `scripts/systems/WorldDirector.gd` | 4 events; 4 factions; ~30 NAMED_CARDS |
| EventDeckSystem | `scripts/systems/EventDeckSystem.gd` | Context-based deck with conditions + effects |
| HUDController | `scripts/ui/HUDController.gd` | Flat label overlay; 5 separate toggle panels |
| InventoryUI | `scripts/ui/InventoryUI.gd` | ItemList + RichTextLabel panel |
| CyberneticSurgeryUI | `scripts/ui/CyberneticSurgeryUI.gd` | 9 body slots; 5 upgrades; item-cost install |
| JobBoardUI | `scripts/ui/JobBoardUI.gd` | Lists Cooters jobs; connects to GameState job cycle |
| TravelGateUI | `scripts/ui/TravelGateUI.gd` | Route picker; triggers WorldDirector.roll_travel_event |
| HackMinigameUI | `scripts/ui/HackMinigameUI.gd` | Difficulty-based hack puzzle panel |

**What the HUD does NOT have:** a unified overlay, tab navigation, stat display, quest log, faction bars, Soul Rot tracking, or the Dreaming Generator visualised in-UI.

---

## PHASE 1 — GHOSTTERM INTERFACE (Pip-Boy Replacement)
*Priority: HIGH — everything downstream benefits from it*

### What It Is

A single togglable overlay called the **GhostTerm** — Spooky Ghost's wrist-mounted interface,
a cracked Gatebox-surplus terminal running pirated System X firmware.
Aesthetic: CRT phosphor green on black, scanline shader, occasional glitch flicker.
Opened with `I` (or TAB). Stays on top. Pauses game input like existing panels do.

The GhostTerm replaces the current patchwork of five separate UIs.
All panels become tabs inside it. The HUDController's `toggle_inventory`, `open_cybernetics`,
`open_job_board` etc. route into `GhostTermUI.open(tab_name)` instead.

### Five Tabs

#### TAB 1 — STAT
```
SPOOKY GHOST        SOUL ANCHOR: STABLE
BODY INTEGRITY   082/100  ████████░░
DREAMING GEN     058/140  ████░░░░░░
SOUL ROT         012/100  █░░░░░░░░░  [new system — see Phase 6]

CYBERNETICS INSTALLED (3/9 slots)
  [EYES   ] Gatebox Eye MK1
  [R ARM  ] Black-Market Armature
  [SPINE  ] (empty)
  [SOUL   ] (empty)
  ...

ATTRIBUTES [from IZ2 stat block — see Phase 2]
  MEAT   STR 2  AGL 3  CON 2
  MIND   INT 4  PER 3  WIL 2
  SOUL   EMP 1  LUCK 2
```

Opens to here from `HUDController.open_stat_screen()`.
Replaces the `cybernetic_label` and `player_health_label` HUD labels for detailed view.
**Cybernetics body diagram** — a 9-slot schematic of the body, each slot colored by install state.
Clicking a slot opens the install list inline (absorbs CyberneticSurgeryUI functionality here).

#### TAB 2 — INV
Current InventoryUI content, reorganised into categories:

| Category | Color | Items |
|---|---|---|
| CURRENCY | yellow | Wan Note, Cooters Bar Credit, Mall Arcade Token |
| PROTECTION | cyan | Cheap Poncho, Sealed Mask |
| CONSUMABLE | green | Chemical Neutralizer |
| SALVAGE | orange | Illegal Reactor Cell, Torai Salvage Contract |
| KEY / ACCESS | pink | Suitors Access Chit, Marbles Backroom Key |
| MISSION ITEM | white | Pipe Blood Sample, Saint Ratchet, etc. |
| WASTED POTENTIAL | grey-italic | anything in WASTED_POTENTIAL_VALUES |

Item detail pane (right side): description + type + lore flavour + **USE button** if applicable.
USE button can: equip (poncho/mask), consume (neutralizer), sell to Gideon (wasted potential items).
Wasted potential items show their soul potential value in parentheses.

**ITEM_DB expansion:** Add ~25 items drawing from all four sources (see Appendix A).

#### TAB 3 — DATA
Quest log. Three sections:

```
CAMPAIGN QUEST
  Wake-Up Call  [in progress]
  > display (done)  right arm (done)  coolant (done)
  > Extract when ready.

HUB PROJECTS  (2 active)
  Restore Hub Power — repair the generator coupling
  Connect Hub Water  — install conduit at cistern junction

COOTERS JOBS
  Active: Pump Heart Lease
  > Recover Cistern Filter Core [done — return to Marbles]
  
  Available: Food Court Filter / Atrium Relay Echo / ...
  Completed: Pipe Blood Sample / Saint Ratchet
```

Cooters job entries are clickable — selecting one shows full flavour text + reward.
"Accept" button visible for available jobs if none is active.
This absorbs JobBoardUI functionality as a tab subtab.

#### TAB 4 — WORLD
```
REGION  Faded Atrium
PRESSURE  stable, watched
SKY  false daylight
GENERATOR  sagging  (POTENTIAL 58/140)
SURVEILLANCE  normal

FACTION STANDING
  System X        ████░░░  +4   "improvisation over control"
  Gatebox Corp    ██░░░░░  +1   "comfort through ownership"
  Wan Moa Torai   ███░░░░  +3   "because everyone deserves one more try"
  Linda           ░░░░░░░   0   "freedom creates suffering"

HUB DEVELOPMENT [see Phase 3]
  POWER   ████████  restored
  WATER   ████░░░░  conduit pending
  CULTURE ██░░░░░░  Velvet Coil recruited
  DEFENSE ░░░░░░░░  unbuilt
```

Faction rep bars with threshold markers (see Phase 4 for what thresholds trigger).
Hub development track visualised here as four progress bars.
TravelGateUI routes moved to a sub-panel here (or kept as its own interactable — TBD).

#### TAB 5 — LOGS
Scrollable feed of the last 20 system log entries:
- Card-triggered dialogue (speaker: line)
- Damage events
- Job completions
- World flag changes that matter ("Saint Ratchet returned." "Hub LAN restored." etc.)

Currently HUDController has a single-line `log_label` — this replaces it with history.
`HUDController.push_log()` appends to an `Array[String]` that GhostTerm reads.

### Implementation Files

| File | Action |
|---|---|
| `scripts/ui/GhostTermUI.gd` | NEW — master container, tab controller |
| `scripts/ui/GhostTermStatTab.gd` | NEW — stat + cybernetics body diagram |
| `scripts/ui/GhostTermInvTab.gd` | NEW — replaces InventoryUI |
| `scripts/ui/GhostTermDataTab.gd` | NEW — replaces JobBoardUI as quest log |
| `scripts/ui/GhostTermWorldTab.gd` | NEW — faction bars + hub tracks + world event |
| `scripts/ui/GhostTermLogsTab.gd` | NEW — scrollable log history |
| `scripts/ui/HUDController.gd` | EDIT — route toggle calls into GhostTermUI |
| `scripts/ui/InventoryUI.gd` | KEEP as fallback or deprecate after tab ships |
| `scripts/ui/JobBoardUI.gd` | KEEP as interactable-only fallback; tab replaces it |

### GhostTerm Open/Close API

```gdscript
# In HUDController
func toggle_ghost_term(tab: String = "") -> void:
    if ghost_term.is_open():
        ghost_term.close()
    else:
        ghost_term.open(tab if not tab.is_empty() else last_ghost_term_tab)

# Callers
toggle_inventory()       → toggle_ghost_term("inv")
open_cybernetics(...)    → toggle_ghost_term("stat")
open_job_board(...)      → toggle_ghost_term("data")
```

### Visual Style Guide

- Background: `Color(0.04, 0.06, 0.04)` near-black with slight green tint
- Primary text: `Color(0.2, 1.0, 0.6)` phosphor green
- Secondary text: `Color(0.55, 0.8, 0.6)` dimmer green
- Danger/Soul Rot: `Color(1.0, 0.22, 0.82)` hot magenta
- Headers: uppercase, 18pt
- Body: 14pt
- Tab bar across top: active tab bright, inactive tabs 40% brightness
- Scanline shader: `CanvasItem` material with a simple scanline texture at 1% opacity
- Open/close animation: slide in from left side (wrist raise motion), 0.12s easing

---

## PHASE 2 — EXPANDED ATTRIBUTE & CYBERNETICS SYSTEM
*Drawing from: Interface Zero 2.0*

### Player Attributes (IZ2-derived, reskinned)

Add 8 attributes to GameState. These are set at new-game character creation (or locked for now).
They modify skill rolls and cybernetic synergies.

```
MEAT (physical)
  STR — melee damage, carry weight
  AGL — movement speed, dodge window
  CON — max HP multiplier, toxic rain resistance

MIND (cognitive)
  INT — hacking success bonus, Dreaming Generator potential gain
  PER — targeting range, enemy detection range
  WIL — soul rot resistance, coolant efficiency

SOUL (metaphysical — Gatebox lore specific)
  EMP — faction rep gain rate, NPC reaction modifier
  LUCK — loot roll modifier, card draw weight modifier
```

Stored in `GameState.attributes: Dictionary = {"STR": 2, "AGL": 3, ...}`.
Displayed on GhostTerm STAT tab.
Not used in hard game mechanic gating yet — can be soft flavour first, then wired in.

### Expanded Cyberware (IZ2 taxonomy)

Current 5 upgrades cover: Head, Eyes, R Arm, R Leg, Torso.
Add 12 more to fill the remaining slots and give meaningful choice:

| ID | Slot | Name | Effect | Cost Item | Source |
|---|---|---|---|---|---|
| `neural_jack` | Head | Neural Jack | Speeds hack terminal access, bonus to INT rolls | Suitors Access Chit x2 | IZ2 Netrunner |
| `whisper_filter` | Head | Whisper Filter | Reduces noise signature, Splice aggro radius | Cooters Rumor Token | IZ2 Nanotech |
| `mag_retina` | Eyes | Mag-Retina | Reveals enemy weak points (replaces Eye MK1 tier) | Mall Arcade Token x3 | IZ2 Cybervision |
| `endoskeletal_brace` | Torso | Endoskeletal Brace | Raises max HP by 20 | Chemical Neutralizer x2 | IZ2 Chassis |
| `bioreactor_mesh` | Torso | Bio-Reactor Mesh | Slowly regenerates HP out of combat | Illegal Reactor Cell | IZ2 Bio-Systems |
| `left_arm_graft` | Left Arm | Salvage Graft | Improves melee range and damage | Torai Salvage Contract x2 | IZ2 Muscle Graft |
| `trauma_dampener` | Left Arm | Trauma Dampener | Reduces knockback, maintains aim during damage | Wan Note x20 | IZ2 |
| `sprint_pistons` | Left Leg | Sprint Pistons | Sprint burst speed; pairs with Pipewalker Legs | Cooters Bar Credit x3 | IZ2 Leg Rig |
| `spine_relay` | Spine | Spine Relay | Connects all cybernetics — reduces Drift accumulation | Atrium Relay Packet | Gatebox lore |
| `soul_anchor_tap` | Soul Slot | Soul Anchor Tap | Reduces Soul Rot gain rate; surfaces System X messages faster | Atrium Relay Packet + System X rep ≥ 5 | Gatebox lore |
| `preservation_blocker` | Soul Slot | Preservation Blocker | Blocks Preservation Directive scan events | Rep Gatebox ≤ -3 only; costs Linda rep | Gatebox lore |
| `drift_syphon` | Spine | Drift Syphon | Converts excess Drift into Dreaming Generator potential | Pipe Blood Sample + soul_rot < 30 | Gatebox/IZ2 hybrid |

### Drift System (IZ2 Humanity Cost, reskinned)

Every cybernetic install adds **Drift** — quantified estrangement from unmodified humanity.
Stored in `GameState.drift: int = 0`.

```
Drift 0-20   — no change
Drift 21-40  — Gatebox Corp NPCs grow more attentive (soft surveillance increase)
Drift 41-60  — Some citizens react with discomfort; Linda dialogue: "I can see the edges"
Drift 61-80  — Preservation Directive scan events increase frequency
Drift 81+    — World flag "high_drift" triggers unique NPC lines + Linda becomes concerned
```

Visible on GhostTerm STAT tab as a bar.
Mitigated by: Soul Anchor Tap (install), Spine Relay (install), or Wan Note payment to Torai.

---

## PHASE 3 — HUB DEVELOPMENT TRACKS
*Drawing from: Mutant Year Zero ARK system*

### Four Development Tracks

The Faded Atrium develops along four tracks, each with a progress score (0–100).
Progress comes from completing quests + delivering items + spending Dreaming Generator potential.
Tracks unlock NPCs, shop inventory, event cards, and late-game content.

```
POWER   (generator, electricity, machines)
WATER   (cistern, filtration, food court)
CULTURE (bar, radio, art, community)
DEFENSE (barricades, security nodes, patrols)
```

Stored in `GameState.hub_tracks: Dictionary = {"power": 0, "water": 0, "culture": 0, "defense": 0}`.

#### POWER Track Milestones

| Score | Flag | Content Unlocked |
|---|---|---|
| 10 | hub_power_minimal | Basic lights on; HUD event timer speeds up |
| 25 | hub_power_restored | Full lighting; generator state moves to STABLE |
| 50 | hub_power_surplus | Powers new rooms; UpgradeStation gets second slot |
| 75 | hub_power_broadcast | Can push interference events to nearby districts |
| 100 | hub_power_sovereign | Generator fully independent of Wan Moa Torai grid |

Current quest `hub_power_restore` (complete generator coupling) → gives 25 POWER points.
New: "Feed the Reactor" quest (Illegal Reactor Cell → Gideon → 25 more) → 50 total.
New: "Broadcast Splice" job → trips something in Torai grid → POWER 75.

#### WATER Track Milestones

| Score | Flag | Content Unlocked |
|---|---|---|
| 10 | hub_water_trickling | Vera appears; minimal water rations |
| 25 | hub_cistern_connected | Full water; toxic rain recovery in hub |
| 50 | hub_water_purified | Pure Water Filter delivered; food court revives |
| 75 | hub_water_garden | Bloom growth in food court converted to food supply |
| 100 | hub_water_sovereign | Water independence; Torai leverage over hub removed |

#### CULTURE Track Milestones

| Score | Flag | Content Unlocked |
|---|---|---|
| 10 | coil_invitation_accepted | Velvet Coil sets up the radio |
| 25 | hub_bar_open | Cooters bar fully open; Marbles offers rumor trades |
| 50 | hub_broadcast_active | Velvet Coil broadcasts; new ambient card pool unlocked |
| 75 | hub_chronicler_present | MYZ Chronicler archetype NPC appears — records events |
| 100 | hub_culture_sovereign | Songs about the City survive whatever happens to the hub |

#### DEFENSE Track Milestones

| Score | Flag | Content Unlocked |
|---|---|---|
| 10 | hub_barricades_basic | Entry corridor barricaded; slows crackdown events |
| 25 | hub_watch_rotation | NPCs begin hub patrol AI rotation |
| 50 | hub_security_node | SecurityNode active at entrance; alerts on approach |
| 75 | hub_counter_surveillance | Suitors surveillance jammed permanently |
| 100 | hub_defense_sovereign | Hub can repel a Preservation Directive forced entry |

### ARK PROJECTS (MYZ-inspired big unlocks)

These cost multiple resources and cross-track investment.
They represent the major hub upgrades beyond individual quests.

| Project | Requirements | Reward |
|---|---|---|
| DREAMING GENERATOR STABLE | POWER ≥ 50 + Potential ≥ 80 | Generator state → STABLE; no more toxic rain from power failure |
| PIPE CHAPEL | WATER ≥ 25 + `saint_ratchet_returned` | Gideon's sermon events; healing zone in hub |
| VELVET BROADCAST TOWER | CULTURE ≥ 50 + Torai rep ≥ 3 OR Torai rep ≤ -3 | New card context "broadcast_event"; reaches Upper City |
| SOUL BATTERY LAB | DEFENSE ≥ 25 + INT ≥ 4 | Can reverse-engineer captured soul batteries; Dreaming Generator gains +20 max |
| THE MALL CONNECTOR | All 4 tracks ≥ 50 | Opens the late-game transit route to the Mall of the Future |

---

## PHASE 4 — FACTION DEPTH
*Drawing from: IZ2 corp debt / Judge Dredd bloc allegiance / Gatebox Breach hard canon*

### Reputation Thresholds

Each faction has breakpoints that trigger world-flag changes.

#### System X
| Rep | Effect |
|---|---|
| ≥ 1 | System X will answer hails on the terminal |
| ≥ 3 | Pee Kid sends encrypted supply drops (new NAMED_CARD context) |
| ≥ 5 | Soul Anchor Tap cyberware unlocked |
| ≥ 8 | System X reveals a timeline secret (midgame flag `system_x_truth_revealed`) |
| ≤ -3 | System X goes silent; Pee Kid says "we made a mistake" |

#### Gatebox Corporation
| Rep | Effect |
|---|---|
| ≥ 3 | Gatebox Corporate Liaison NPC appears in hub — offers "legitimate" jobs |
| ≥ 5 | Linda makes direct contact (flag `linda_direct_contact`) |
| ≤ -2 | Preservation Directive scan events increase |
| ≤ -5 | Corporate Enforcement patrol added to encounter deck |

#### Wan Moa Torai
| Rep | Effect |
|---|---|
| ≥ 3 | Torai Salvage Contracts become available in bulk |
| ≥ 5 | Torai Debt Office offers a one-time forgiveness (clears all Drift cost debt) |
| ≤ -2 | Debt accumulates — Wan Note costs increase by 10% per negative point |
| ≤ -5 | Brickmouth Ronnie stops speaking; Torai locks the cistern access |

#### Linda
| Rep | Effect |
|---|---|
| 0 | Silent — no contact yet |
| ≥ 1 | First message arrives: "I know you're down there." |
| ≥ 3 | Personal invitation to meet (Midgame trigger) |
| ≥ 5 | Linda reveals she is still resisting CEO transformation |
| ≤ -2 | Linda sends a Compliance Agent instead of a message |
| ≤ -5 | CEO Linda process accelerates (late-game flag) |

### New Faction: Big Gates Foundation
Add as a 5th faction. Currently only Rocker Fellar represents them.
Rep starts at 0; increases only via defeating Rocker Fellar or finding soul battery evidence.

| Rep | Effect |
|---|---|
| ≥ 3 | Big Gates relic items begin appearing in black-market loot |
| ≥ 5 | Soul Battery Lab ARK project unlocks |
| ≤ -1 | BGF bounty hunters added to encounter deck |

### Corporate Compliance Meter (Judge Dredd-inspired)

Separate from Gatebox Corp reputation — a one-way ratchet.
Stored in `GameState.compliance_score: int = 0`. **Does not decrease.**
Goes up when: Preservation Directive events are ignored, hacking logged terminals, using the Preservation Blocker implant.

| Score | Effect |
|---|---|
| 10 | Passive: Surveillance cameras begin tracking (cosmetic HUD message) |
| 25 | Preservation Directive patrol added to random event pool |
| 50 | Named Compliance Agent NPC assigned to your file (dialogue encounter) |
| 75 | Gatebox Corp locks Upper City access |
| 100 | Executive Extraction order issued — Linda must intervene to stop it |

---

## PHASE 5 — EXPANDED JOB BOARD & EVENT CARDS
*Drawing from: All four sources*

### New Job Destinations (per architecture docs)

Three additional Cooters job destinations were already planned.
These are the ones to build, each with three routes (as per memory doc architecture):

#### 1. Sub-Sub-Basement Street Run
Jobs: intelligence gathering, Splice patrol report, Torai checkpoint avoidance.
Hazards: Preservation Directive patrol, toxic rain pockets, Splice nesting area.
Route A: Upper walkway — slow, safe, compliance risk.
Route B: Sewer bypass — fast, Splice risk, Drift +1.
Route C: Torai back-channel — requires rep ≥ 2, bypasses hazards, adds Torai favour.

#### 2. Rocker Fellar Keep (post-defeat)
Jobs: recover soul battery fragments, catalogue Big Gates correspondence.
Hazards: BGF remnant soldiers, structural instability, active soul frequency interference.
Route A: Service lift approach — standard.
Route B: Performance hall — soul frequency hazard (Soul Rot +5), high loot.
Route C: Maintenance crawl — slow, undetected.

#### 3. Linda Spire Lower Floors (midgame unlock)
Jobs: plant listening device, recover a Gatebox tech prototype, make contact with a Gatebox insider.
Hazards: active surveillance, Compliance Agents, security lockdown events.
Route A: Maintenance entrance — requires Drift ≤ 40 (human-looking).
Route B: Corporate transit — requires Gatebox rep ≥ 3.
Route C: System X backdoor — requires System X rep ≥ 5 + neural jack implant.

### New NAMED_CARDS

#### Linda Contact Cards (midgame, after `linda_direct_contact` flag)
```
"linda_first_message":    context: hub_return, condition: linda_direct_contact
"linda_warning":          context: travel, condition: gatebox_compliance ≥ 25
"linda_personal_appeal":  context: hub_return, condition: linda_rep ≥ 3
```

#### Preservation Directive Patrol Cards
```
"pd_patrol_warning":     context: travel, condition: compliance_score ≥ 25
"pd_patrol_encounter":   context: travel, condition: compliance_score ≥ 50
"pd_checkpoint_block":   context: district_exit, condition: compliance_score ≥ 75
```

#### System X Transmission Cards
```
"systemx_supply_drop":   context: hub_return, condition: system_x_rep ≥ 3
"systemx_truth_fragment":context: hub_return, condition: system_x_rep ≥ 8
"pee_kid_warning":       context: travel, condition: soul_rot ≥ 60
```

#### Big Gates Foundation Cards
```
"bgf_bounty_scan":       context: travel, condition: bgf_rep ≤ -1
"bgf_relic_signal":      context: district_exit, condition: bgf_rep ≥ 3
```

### New Card Contexts

| Context | When fires | Examples |
|---|---|---|
| `hub_npc_talk` | When player interacts with hub NPC | Ambient dialogue, rumors, quest hints |
| `purchase_attempt` | When attempting to buy at vendor | Price hike events, fake goods, Torai interest |
| `patrol_encounter` | Random during traversal | Splice pack, Compliance scan, BGF scout |
| `broadcast_event` | After CULTURE ≥ 50 unlocks tower | City-wide reaction to Velvet Coil signal |

---

## PHASE 6 — SOUL-TECH SYSTEMS
*Drawing from: Gatebox Breach Lore Bible*

### Soul Rot Meter

`GameState.soul_rot: int = 0`. Range 0–100.

**Increases from:**
- Heavy soul-tech cybernetics installed (Soul Anchor Tap +5 on install — tradeoff)
- Failing a hack on a soul-indexed terminal (+3)
- Preservation Directive compliance events accepted passively (+2)
- Being scanned by a Compliance Agent without resistance (+5)
- Taking damage from the Generator when below threshold (+1/hit)

**Decreases from:**
- Spending time in the Pipe Chapel (CULTURE ≥ 25 unlock) — -5 per visit
- Delivering wasted potential to Gideon (soul conversion) — variable
- Spine Relay cybernetic — -1 per completed job
- Specific Linda dialogue choices (midgame) — her care still works on him

**Thresholds:**

| Score | Effect |
|---|---|
| 20 | GhostTerm STAT tab shows "Soul Rot: trace exposure" |
| 40 | System X messages become more worried in tone |
| 60 | Pee Kid sends a direct warning card |
| 80 | Linda's next dialogue acknowledges the erosion |
| 100 | `soul_anchor_critical` world flag → trigger cutscene/mechanic (game-over adjacent) |

### Soul Anchor Status

Displayed prominently on GhostTerm STAT tab.
Has four states mapped to Soul Rot + world flags:

```
STABLE    soul_rot < 40
STRESSED  soul_rot 40–59
LEAKING   soul_rot 60–79
CRITICAL  soul_rot ≥ 80
```

When `soul_anchor_critical`: The System threatens to collapse. Spooky Ghost's death
(per lore: timeline destruction) becomes mechanically real. This is the late-game
pressure clock the whole system builds toward.

### Dreaming Generator — Two Modes

Currently one flat potential pool (0–140 with 40 threshold).
Expand to two modes:

**CIVIC POTENTIAL** (current system): from wasted goods sold to Gideon.
Feeds Hub Development tracks (POWER, WATER, CULTURE, DEFENSE).

**SOUL POTENTIAL** (new): from Soul Rot converted via Drift Syphon implant or Pipe Chapel.
Feeds ARK PROJECTS and soul-tech unlocks (Soul Anchor Tap, Preservation Blocker).

Both visualised as separate bars in GhostTerm WORLD tab and on STAT tab.

### The System (Machine) — Visibility Mechanic

Per lore: The System requires a soul anchor to function. Spooky Ghost IS the anchor.
Make this mechanically real:

- The System's reality-projection ability (face to the fake sky) becomes available only when `soul_rot < 60`
- When Soul Rot is high, the System sends confused or corrupted messages
- System X dialogue (Pee Kid/Yoko) becomes less reliable when soul_rot ≥ 80
- This creates natural tension: being a good operative (hacking, fighting) costs soul integrity

---

## APPENDIX A — ITEM_DB EXPANSION

Additional items to add to `InventoryUI.ITEM_DB` (and `GameState.WASTED_POTENTIAL_VALUES` where applicable):

### New Currency / Access Items
| Name | Type | Description |
|---|---|---|
| Big Gates Scrip | Currency | Old BGF currency, barely accepted anywhere. Rocker Fellar's signature on the back. |
| Linda Corp Pass | Access | Corporate single-use clearance. It is not yours. Use it and find out. |
| System X Burn Chip | Access | One-time terminal override. Pee Kid says don't ask what it cost. |
| Torai Debt Receipt | Document | Proof of debt. Someone else's. You have it. |

### New Consumables
| Name | Type | Description | Effect |
|---|---|---|---|
| Soul Coolant Vial | Consumable | Reduces Soul Rot by 15. Tastes like mint and apology. | soul_rot -15 |
| Hack Patch Kit | Consumable | +2 to next hack difficulty attempt. Single use. | INT buff |
| Pipe Breath Filter | Consumable | Prevents Splice spore damage for one zone visit. | Resistances |
| Emergency Ration Pack | Consumable | Restores 15 HP. Wan Moa Torai brand. Best before unspecified. | HP +15 |

### New Salvage / Mission Items
| Name | Type | Wasted Potential |
|---|---|---|
| Soul Battery Fragment | Salvage | 35 potential — "stored life, bad provenance" |
| Big Gates Ledger Page | Document | 20 potential — "accountability that arrived too late" |
| Gatebox Compliance Report | Document | 12 potential — "surveillance report on a person who didn't survive the read" |
| Velvet Coil Signal Tape | Artifact | 18 potential — "music from before the corporate reformat" |
| Preservation Directive Badge | Salvage | 8 potential — "authority that forgot what it was protecting" |

---

## APPENDIX B — NPC EXPANSION SEEDS

Each hub NPC needs a quest line (already partially done), ambient card pool, and stat screen tooltip.
Drawing from all four source books for archetypes:

| NPC | Archetype Source | Missing Content |
|---|---|---|
| Marbles | MYZ Fixer / IZ2 Fixer | Phase 2 job unlocks; personal quest (Torai debt) |
| Pipe Father Gideon | MYZ Boss (spiritual) | Pipe Chapel ARK project; soul coolant sermon |
| Mister Static | MYZ Gearhead | Phase 3 POWER track; personal story (what he built before) |
| Ladderboy | MYZ Stalker | Phase 3 DEFENSE track; knows 3 hidden routes |
| Vera | MYZ Dog Handler (care-giver) | WATER track completion; medical station unlock |
| Kiki Baja | IZ2 Corporate Runner | Torai faction rep conduit; double-agent reveal |
| Brickmouth Ronnie | JD Block Judge analogue | Compliance meter events; can be bribed |
| Velvet Coil | MYZ Chronicler / IZ2 Fixer | CULTURE track; Broadcast Tower project |
| System X (Pee Kid/Yoko) | Unique (Gatebox lore) | Soul Rot warning cards; truth reveal at rep ≥ 8 |
| Sunday | IZ2 Hacker / JD Judge analogue | Suitors surveillance; unlock after Compliance event |
| Linda | Gatebox canon — complex | Rep threshold contact events; midgame meet |
| Rocker Fellar | JD Block Chief + BGF | Boss encounter (already wired); post-defeat job line |

---

## IMPLEMENTATION ORDER

```
PHASE 1 — GhostTerm UI                 [2–3 sessions]
  ├── GhostTermUI.gd scaffold + tab shell
  ├── STAT tab (HP, cybernetics body diagram, placeholder attributes)
  ├── INV tab (port InventoryUI content, add categories)
  ├── DATA tab (port JobBoardUI + quest log)
  ├── WORLD tab (faction bars + world event + hub track stubs)
  ├── LOGS tab (replace single log_label with history)
  └── Wire HUDController to GhostTermUI

PHASE 2 — Attributes + Cyberware       [1–2 sessions]
  ├── Add GameState.attributes dict
  ├── Add 12 new UPGRADE_DB entries to CyberneticSurgeryUI (or GhostTerm STAT tab)
  ├── Add GameState.drift tracking
  └── Wire drift thresholds to world flags + NPC reaction seeds

PHASE 3 — Hub Development Tracks       [1–2 sessions]
  ├── Add GameState.hub_tracks dict
  ├── Map existing hub quests to track scores
  ├── Add 2 new quests per track
  └── Visualise tracks in GhostTerm WORLD tab

PHASE 4 — Faction Depth                [1 session]
  ├── Add rep threshold checks in GameState.add_reputation()
  ├── Add compliance_score to GameState
  ├── Wire thresholds to world flags
  └── Add Linda faction + Big Gates Foundation

PHASE 5 — Expanded Jobs + Cards        [2–3 sessions]
  ├── 3 new job destinations (scripts already planned in memory docs)
  ├── New NAMED_CARDS (Linda, PD, System X, BGF)
  ├── New card contexts (hub_npc_talk, patrol_encounter, broadcast_event)
  └── Wire new jobs to GameState.COOTERS_JOBS

PHASE 6 — Soul-Tech Systems            [1–2 sessions]
  ├── Add GameState.soul_rot
  ├── Soul Rot gain sources (hacking, implants, compliance)
  ├── Soul Rot reduce sources (Pipe Chapel, Gideon, Spine Relay)
  ├── Soul Anchor status display in GhostTerm STAT tab
  ├── Two-mode Dreaming Generator (civic + soul potential)
  └── soul_anchor_critical world flag trigger
```

**Total estimated work: 8–13 sessions.**
Phase 1 (GhostTerm) ships first because everything else becomes more visible inside it.
Phases 2–4 are largely data additions on top of existing architecture.
Phase 5 and 6 are the new mechanical territory.

---

## CROSS-SOURCE SYNTHESIS NOTES

| Inspiration | What It Became Here |
|---|---|
| IZ2 — TAP/Hyper Reality | GhostTerm aesthetic; AR terminal overlays in world |
| IZ2 — Humanity/Drift cost | Drift meter on cyberware installs |
| IZ2 — Corp debt | Wan Moa Torai negative rep accumulation; Torai debt receipt items |
| IZ2 — Netrunner cyberspace | Hack terminal depth (Phase 5 extension) |
| JD — Mega-City block structure | Hub development tracks; Compliance Meter |
| JD — Perp attitude system | NPC faction rep thresholds triggering dialogue state changes |
| JD — Sector random encounter | patrol_encounter card context; Compliance Agent named NPC |
| MYZ — ARK development tracks | Hub tracks (POWER/WATER/CULTURE/DEFENSE) + ARK PROJECTS |
| MYZ — Wasted Potential | Already implemented; expanded with new items |
| MYZ — Zone exploration sectors | Job destination location design (3-route architecture) |
| MYZ — Humanoid factions | System X ↔ Stalkers; Wan Moa Torai ↔ Mechies; Gatebox ↔ Nova Cult |
| Gatebox lore — Soul Anchor | soul_rot meter; soul_anchor_critical clock |
| Gatebox lore — Preservation Directive | Compliance Meter; PD patrol cards |
| Gatebox lore — System X complexity | High rep unlocks truth; betrayal flag possible |
| Gatebox lore — Linda's humanity | Linda rep system; she resists CEO transformation if player earns it |
| Gatebox lore — Big Gates Foundation | 5th faction; Soul Battery Lab project; Rocker Fellar post-defeat arc |
| Gatebox lore — False sky/upper city | Linda Spire job destination (Phase 5); late-game Mall of the Future gate |
