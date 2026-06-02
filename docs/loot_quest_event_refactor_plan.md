# Refactor Plan — Loot, Cyberware, Dynamic Quests, Event Chains & Economy

A pillar refactor moving the game toward the original vision: enemies drop cyberware, jobs are
dynamic and faction-sourced with multiple resolutions, an event-chain system follows the player
with stat-checked resolutions, and the whole economy runs on Wan Notes.

Companion docs: `gatebox_breach_lore_bible.md`, `npc_writing_style_guide.md`,
`cooters_job_board_and_travel_plan.md`, `dialogue_system_plan.md`.

---

## 0. Locked decisions (from design review)

1. **Quests:** hand-authored templates, shuffled. A pool of faction-flavored templates; Cooters
   shows a random subset each visit. Location, reward-spawn spot, and enemy-layout profile are
   rolled per instance.
2. **Cyberware loop:** enemies drop the implant as an item → **Velvet Coil installs it for Wan
   Notes (+drift)** → **Gideon buys unwanted implants/ruined parts for Wan Notes (scrap)**. The old
   bespoke item-costs and GhostTerm self-install are **retired**; GhostTerm WARE becomes a viewer.
3. **Stat checks:** **2d6 + attribute modifier + relevant cyberware/drug bonus ≥ difficulty.**
4. **Objective types this phase:** Find item, Kill-for-loot, Deliver item. **Escort deferred.**

### Proposals to confirm (secondary decisions, defaulted below — flag any to change)

- **Economy:** Wan Notes becomes the *sole* currency. Cooters Bar Credit, Mall Arcade Token, the
  old cyberware-cost items (Suitors Chit, Salvage Contract, etc.) become **sellable junk** that
  converts to Wan Notes at Gideon. Ronnie's pharmacy reprices to Wan Notes.
- **"Unbroken parts → better drops":** on defeat, roll one drop; if it hits, the implant pool is
  weighted toward implants whose body part was **not** broken (a broken part removes/heavily reduces
  its implant). Encourages clean takedowns.
- **Enemy-layout profiles:** 2–3 per quest location, themed by hostile faction, scaling with the
  quest's threat band.
- **Cooters board size:** 4 jobs shown at once; reshuffle on every Cooters entry (daily later).
- **Crit/fumble:** double 6s = crit (bonus outcome / extra card); double 1s = fumble (worse branch).

---

## 1. Stat-check system (new foundation)

A new `StatCheck` helper (in `GameState` or a small autoload `Dice`). Everything else builds on it.

```
total = 2d6 + attr_mod(attribute) + gear_bonus(check_tag)
success = total >= difficulty
```

- **Attribute modifier** = the raw attribute value (STR 2 → +2). Range ~1–4 now; grows later.
- **Gear bonus** = sum of bonuses from installed cyberware and active drugs that carry the check's
  `check_tag` (e.g. a STR/force check gets +X from Salvage Graft; a hack check gets +X from Neural
  Jack; a PER check gets +X from Mag-Retina). Defined as a small `CHECK_BONUSES` map.
- **Difficulty bands:** Routine 6 · Tricky 8 · Hard 10 · Severe 12. (2d6 avg 7; +mod ~2–3 → DC 8
  likely, DC 10 coin-flip, DC 12 needs gear/luck.)
- **Crit/fumble:** natural double-6 = critical success; natural double-1 = fumble. Each event choice
  may define `crit` / `fumble` branches; otherwise they fold into success/failure.

```gdscript
# Dice.roll_check(attribute: String, difficulty: int, check_tag := "") -> Dictionary
# returns {success, total, dice:[a,b], mod, gear, crit, fumble, difficulty}
```

Attribute → typical use (drives which checks event choices offer):
STR force/break · AGL dodge/flee/sneak · CON endure/resist · INT hack/analyze · PER spot/read ·
WIL resist coercion · EMP persuade/charm · LUCK wildcard.

---

## 2. Loot & cyberware overhaul

### 2.1 Drop on defeat

`Enemy` gains a data-driven loot table instead of the single `drop_item`. On `_defeat()`:

1. Track which parts were broken (already have `body_part_destroyed`; record a `set` of broken part
   names during the fight).
2. Roll the **base drop chance** (`loot_chance`, per enemy/faction).
3. If it drops, pick from the enemy's **implant pool**, weighting toward implants whose mapped body
   part is **intact**. A broken part's implant is excluded (or heavily reduced).
4. Always-possible extras independent of the implant roll: **ruined implant parts** (scrap) and the
   quest-relevant **`neural_splice`** (kept for the Vessel/bunny quest) on Splice-type enemies.

Delivery: drops spawn as a **world `LootPickup`** at the corpse (walk over to grab), so loot is
visible and skippable — matches the "go get the loot" quest type. (Auto-to-inventory is the
fallback if a spawn point is unavailable.)

### 2.2 Enemy → implant → faction mapping

Each enemy/faction has an implant pool drawn from `UPGRADE_DB`, spread logically with some overlap.
Draft mapping (to be filled out in data):

| Enemy / faction | Body-part flavor | Implant pool (examples) |
|---|---|---|
| Splice (street/mod) | arms, legs, head grafts | Salvage Graft, Black-Market Armature, Sprint Pistons, Whisper Filter; drops `neural_splice` |
| Gatebox guard / Security Node | optics, head, torso | Gatebox Eye MK1, Targeting Co-Processor, Soul Baffle, Endoskeletal Brace |
| Pacification Warden / Ward Graft | spine, soul, sedation | Spine Relay, Trauma Dampener, Preservation Blocker (rare) |
| Big Gates (Overseer, Bone Dividend) | reactor, soul batteries | Bio-Reactor Mesh, Mag-Retina, soul-tech (rare) |
| Rocker Fellar / elites | high-tier | rare picks from any pool |

`UPGRADE_DB` entries gain: `part` (which body slot/part it associates with for the unbroken-part
weighting), `tier` (common/uncommon/rare → drop weight + Coil install price + Gideon scrap value),
and `check_tags` (which stat checks it boosts). The old `cost_item`/`cost_count` fields are removed.

### 2.3 Ruined parts & scrap

New junk items (sell-only for now, "used in things later"): e.g. `Cracked Optic`, `Bent Actuator`,
`Fried Cortex Chip`, `Leaking Cell`. Added to a `SCRAP_VALUES` map (Wan Note value). They drop
commonly from the relevant enemy types and can also come from breaking specific parts.

### 2.4 Install & sell

- **Velvet Coil — install:** her cybernetics service lists implants **you own** (dropped items)
  whose slot is free and requirements met. Installing spends **Wan Notes** (price by tier) + applies
  **drift**, consumes the implant item, calls `add_cybernetic`.
- **Gideon — scrap buy:** his sell shop buys implants you don't want and all ruined parts for Wan
  Notes (folds into the existing wasted-potential sell flow, repriced).
- **GhostTerm WARE tab:** becomes a **read-only viewer** of installed ware + drift (no install).

### 2.5 Files touched

`Enemy.gd` (loot roll + broken-part tracking + world-drop), `GameState.gd` (loot tables, scrap
values, install-for-wan-notes API), `CyberneticSurgeryUI.UPGRADE_DB` (add part/tier/check_tags,
remove cost_item), `GhostTermUI.gd` (WARE → viewer), Coil + Gideon service handlers, `LootPickup`.

---

## 3. Economy unification (Wan Notes)

- **Wan Notes** is the only spendable currency. `GameState` gets `wan_notes` accessors (or keep as
  an item `"Wan Note"` — confirm; item-based is simplest given current code).
- **Gideon** = the universal buyer (junk, ruined parts, unwanted implants → Wan Notes; still feeds
  the Dreaming Generator from wasted potential).
- **Ronnie's pharmacy** reprices drugs to Wan Notes.
- **Velvet Coil** charges Wan Notes to install.
- Old currencies (Cooters Bar Credit, Mall Arcade Token, chits, contracts) become **sellable junk**
  with Wan Note values — no longer spent directly. Their lore/flavor stays; they just liquidate.

---

## 4. Dynamic quest system

### 4.1 Quest template schema (`COOTERS_JOB_TEMPLATES`)

Replaces the 6 static `COOTERS_JOBS`. Each template is authored; instances are rolled.

```gdscript
"torai_recover_core": {
    "giver": "Wan Moa Torai",          # faction/NPC the job comes from (flavor + event linkage)
    "title": "Pump Heart Lease",
    "objective_type": "find",          # find | kill_loot | deliver
    "locations": ["water_reclamation_cistern", "collapsed_service_atrium"],  # rolled per instance
    "objective_item": "Cistern Filter Core",   # for find/deliver
    "target_loot": "",                 # for kill_loot: the enemy-drop item required
    "deliver_to": "",                  # for deliver: destination NPC/location
    "threat_band": 2,                  # picks enemy-layout profile tier
    "reward_wan_notes": [14, 22],      # primary reward (rolled in range)
    "reward_item_chance": 0.35,        # sometimes-benefit
    "reward_item_pool": ["Chemical Neutralizer", "Cracked Optic"],
    "faction_rep": {"Wan Moa Torai": 1},
    "event_cards": ["torai_recover_exit", "torai_recover_return"],  # chain seeds
    "flavor": { "accept": "...", "active": "...", "payout": "..." },  # Marbles/giver voice
}
```

### 4.2 Objective types (this phase)

- **find** — recover an item that spawns at one of several reward-spawn points in the location.
- **kill_loot** — defeat enemies until the required `target_loot` drops (ties into §2 drops).
- **deliver** — carry an item to a destination NPC/location.

### 4.3 Instancing & shuffle

- On **entering Cooters**, build the board: shuffle the template pool, pick 4 eligible (respect
  faction standing / prerequisites), and for each roll: location (from `locations`), reward-spawn
  point, enemy-layout profile (by `threat_band`), reward Wan Notes (range), and whether the
  sometimes-item triggers.
- Active job persists across the shuffle; completing/abandoning frees the slot.
- Later: refresh on day-tick instead of every entry (hook ready).

### 4.4 Reward philosophy

Primary reward = **Wan Notes**; items are an occasional bonus (`reward_item_chance`). Faction rep
shifts per giver. This reorients the economy around Wan Notes.

### 4.5 Files touched

`GameState.gd` (templates, instancing, accept/complete rework), `CootersInterior.gd` +
`JobBoardUI.gd` (shuffle on entry, show giver/threat/reward), job-destination scripts (reward-spawn
points + enemy-profile spawn), new `EnemyLayoutProfiles` data.

---

## 5. Enemy-layout profiles

Each quest location defines 2–3 layout profiles, themed by which hostile faction currently contests
it, scaling with the job's `threat_band`:

```
"water_reclamation_cistern": {
    "profiles": [
        {"faction": "Torai",   "band": [1,2], "spawns": [ ... enemy id + point ... ]},
        {"faction": "Splice",  "band": [2,3], "spawns": [ ... ]},
        {"faction": "Gatebox", "band": [3,4], "spawns": [ ... ]},
    ]
}
```

On entering a destination for a job, pick a profile matching the job's band (and ideally the giver's
rival faction), then spawn that enemy set at the defined points. This makes the same location feel
contested and keeps threat scaled to the mission. Data-first; the destination scripts already build
geometry, so they gain a "spawn this profile" call.

---

## 6. Event-chain system

### 6.1 Triggers

Event cards fire on three contexts (extend existing `roll_context_event`):
- **travel** (already exists) — heading to a job destination.
- **leave Cooters** (`district_exit` / a new `cooters_exit`).
- **enter Faded Atrium** (`hub_return`, already exists).

Cards are **faction-linked** to active/recent jobs (a Torai job seeds Torai-flavored events).

### 6.2 Event types

- **Ambush** — hostiles intercept (combat or a check to evade/turn it).
- **Unexpected visitor** to the atrium — an NPC shows up with a request/news.
- **Hostile demand** — a faction demands a related item (comply / refuse / check to bluff).
- **Gift** — a grateful NPC/faction leaves Wan Notes or an item.

### 6.3 Interactive resolution UI (new `EventCardUI`)

Cards become interactive instead of one-line prints. An `EventCardUI` (built like the other menu
UIs) shows: the event narrative + 1–3 **choices**. A choice may be:
- **plain** (just text + effects), or
- a **stat check** showing attribute, difficulty band, and your live bonus; on select it rolls
  2d6+mod+gear and branches to `success` / `failure` (and optional `crit` / `fumble`).

Each branch carries `effects` (reuse the card vocabulary: `add_item`, `add_rep`, `set_flag`,
`add_card`, plus new `wan_notes`, `damage`, `start_event`) and result text.

### 6.4 Chaining

Branch effects can `add_card` to seed the next link, so player choices author an ongoing thread
(e.g., refuse a Torai demand → later Torai ambush card; help a visitor → later gift card). Cards
carry `tags`/`expires_after` (already supported) and persist in the saved deck.

### 6.5 Card schema additions

```gdscript
"torai_demand_core": {
    "id": "torai_demand_core", "contexts": ["cooters_exit","travel"], "weight": 3,
    "faction": "Wan Moa Torai",
    "conditions": {"has_item": "Cistern Filter Core"},
    "title": "A Torai Collector",
    "body": "A Torai collector blocks the gate, palm out. 'That core. Company property, technically.'",
    "choices": [
        {"label": "Hand it over", "effects": [{"type":"remove_item","item":"Cistern Filter Core"},{"type":"add_rep","faction":"Wan Moa Torai","amount":1}], "text": "..."},
        {"label": "Refuse", "check": {"attribute":"WIL","difficulty":9,"tag":"intimidate"},
            "success": {"text":"...","effects":[{"type":"add_rep","faction":"Wan Moa Torai","amount":-1}]},
            "failure": {"text":"...","effects":[{"type":"add_card","card_id":"torai_ambush"},{"type":"damage","amount":8}]}},
        {"label": "Bluff", "check": {"attribute":"EMP","difficulty":8,"tag":"persuade"},
            "success": {"effects":[{"type":"add_card","card_id":"torai_gift"}], "text":"..."},
            "failure": {"effects":[{"type":"add_card","card_id":"torai_demand_core"}], "text":"..."}},
    ],
    "expires_after": 1, "tags": ["torai_thread"],
}
```

### 6.6 Files touched

`EventDeckSystem.gd` (extend effects: `remove_item`, `wan_notes`, `damage`, `start_event`; expose
choice resolution), `WorldDirector.NAMED_CARDS` (author event chains), new `EventCardUI` +
`HUDController.open_event_card`, trigger hooks in Cooters/travel/MallHub, `Dice` for checks.

---

## 7. Architecture summary (new/changed)

- **New:** `Dice` (autoload or GameState helper) — 2d6 stat checks; `EventCardUI` scene+script;
  `EnemyLayoutProfiles` data; `COOTERS_JOB_TEMPLATES`, `SCRAP_VALUES`, loot tables, `CHECK_BONUSES`.
- **Changed:** `Enemy.gd`, `GameState.gd`, `EventDeckSystem.gd`, `UPGRADE_DB`, `GhostTermUI.gd`,
  `CootersInterior.gd`, `JobBoardUI.gd`, job-destination scripts, Coil/Gideon/Ronnie service flows.
- **Reused:** EventDeck contexts/conditions/effects + chaining, DialogueDB profiles/services,
  body-part destroy signals, LootPickup.

---

## 8. Implementation phases (ordered, each testable)

1. **Dice + stat-check core.** `Dice.roll_check`, `CHECK_BONUSES`, attribute mods, difficulty
   bands, crit/fumble. Unit-testable in isolation; no UX yet.
2. **Loot & cyberware drops.** Broken-part tracking, per-enemy loot tables, world-drop pickups,
   ruined parts, `UPGRADE_DB` part/tier/check_tags. Implants land in inventory.
3. **Coil install + Gideon scrap + economy.** Coil installs owned implants for Wan Notes (+drift);
   Gideon buys implants/parts; reprice Ronnie; GhostTerm WARE → viewer; retire bespoke costs.
4. **Enemy-layout profiles.** Profile data + destination "spawn profile" hook; threat scaling.
5. **Dynamic quests.** Templates + instancing + shuffle-on-Cooters-entry + reward-spawn points +
   the three objective types + Wan-Note-primary rewards + job board UI.
6. **Event-card UI + stat-checked resolution.** `EventCardUI`, choice/check branching, effect
   verbs, wire triggers (travel / leave Cooters / enter Atrium).
7. **Event chains + faction linkage.** Author the faction event threads (ambush/visitor/demand/
   gift) that seed and chain off active jobs.
8. **Polish & balance.** Drop rates, Wan Note prices, DCs, board size; save/load coverage; remove
   any temporary scaffolding.

Phases 1–3 stand alone (loot/cyberware/economy) and can ship before the quest/event work. Each
phase keeps the game runnable; un-migrated content falls back to current behavior where possible.

### Status — all phases complete

Phases 1–8 are implemented. Phase 8 outcomes and decisions:

- **Hostile events spawn real enemies.** Added a `spawn_enemies` effect verb (EventDeckSystem) +
  `EnemyLayouts.spawn_ambush()`. The four travel-context ambush cards (`splice_ambush`,
  `gatebox_enforcers`, `biggates_harvesters`, `torai_ambush`) now drop a faction-appropriate pair
  of enemies on a **failed** flee/sneak/fight branch (plus a reduced opening-hit `damage`); clean
  successes stay abstract. Ambush spawns self-wire `player_path` + `alert()` since they arrive after
  the destination's `_ready` wiring pass. `district_exit`/hub cards stay abstract (no avatar to
  ambush in safe hubs; `spawn_enemies` no-ops there by design).
- **Garrison spawn distances.** Pulled the nearest combatant slot in `pipe_utility_tunnels`,
  `water_reclamation_cistern`, and `collapsed_service_atrium` past the 14u enemy detection radius
  (was 6.5–14u from the entry point → now 18–20u), so the garrison no longer aggros on arrival.
- **Deliver double-add fixed.** The job drop-off node no longer mints a duplicate parcel; for
  `deliver` jobs it verifies you're carrying the item and marks the objective done (payout consumes
  it). `find` jobs still grant the recovered item. (All four destinations.)
- **Legacy hub kiosk retired.** The `CyberneticsKiosk` `upgrade_station` now routes to the Velvet
  Coil install flow (`hud.open_cybernetics()`, Wan Notes) instead of the old item-cost self-install;
  `MallHub._try_install_upgrade` deleted.
- **Legacy `cost`/`cost_item`/`cost_count`** in `UPGRADE_DB` confirmed dead (nothing reads them; the
  surgery UI is never opened) and documented as legacy in place rather than churned out.
- **`big_gates` loot mapping:** confirmed correct as-is. The only non-goon Big Gates enemy is the
  `soul_drone` (a `SecurityNode` turret) which doesn't roll loot at all; the goon part-names target
  the goon-framed `foundation_enforcer`/`tithe_servitor`.
- **Economy review:** job rewards (10–26 WN) vs install tiers (8/16/28) vs scrap (4/8/14) and drop
  rates (0.22–0.28 implant, intact-part-gated) are coherent; left as-is for play-feel tuning.

Open tuning knobs (feel, not correctness): ambush group size (currently 2) stacks on top of the
garrison; opening-hit damage values; whether to gate the public kiosk behind the Coil invitation.

---

## 9. Open questions still worth confirming

- **Wan Notes representation:** keep as the `"Wan Note"` inventory item (simplest, current), or
  promote to a dedicated `GameState.wan_notes` int with a HUD counter? (Recommend dedicated int.)
- **Escort (deferred):** confirm it's a later phase, not this build.
- **Drop generosity:** target feel — implants meaningfully rare (a few per location run) vs frequent?
- **Old job items mid-save:** players with existing saves hold Bar Credit etc.; auto-convert to Wan
  Notes on load, or just let Gideon buy them? (Recommend: let Gideon buy them; no migration code.)
