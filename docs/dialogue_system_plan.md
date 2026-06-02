# Dialogue System Plan — Daggerfall-style Topic Conversations

Design + implementation plan for replacing the current one-line NPC interaction with a
Daggerfall-style, topic-driven conversation system. Companion docs:
`npc_writing_style_guide.md`, `gatebox_breach_lore_bible.md`.

## Decisions locked in (from design review)

- **Features:** categorized topic lists, tone toggle (Polite/Normal/Blunt), persistent keyword
  codex, rumors / "Any news?".
- **Content:** hand-authored per topic (keep the bespoke voice; no procedural generation).
- **Disposition:** *both* — faction reputation seeds each NPC's baseline disposition, then tone
  and actions adjust it locally per NPC.
- **Scope:** replace all *non-spine* character conversations. The campaign spine (Linda/System X
  audience scenes and their consoles) **stays as-is and is out of scope.** Environmental/object
  interactions — consoles, valves, crates — stay as direct one-shot lines; see "Boundary" below.
- **Keyword discoverability:** topics tagged with a `hint` show as a **non-clickable `?` cue** —
  the NPC clearly has something to say, but you must learn that keyword by **word of mouth** (a
  `teaches` chain from another topic/NPC) before you can ask it here. Topics without a `hint` are
  common knowledge and stay directly askable. Work/quest offers are always selectable.

---

## 1. What the current system is (being replaced)

- `HUDController.show_dialogue(speaker, text)` writes one line to a single `%DialogueLabel`.
- `NPCDialogue` (Area3D) `interact()` returns `{name, text}` — one line, optionally swapped by a
  single world flag.
- Every location script (`MallHub`, `SubSubBasementDistrict`, the campaign spine, etc.) hardcodes
  a `match npc_name:` block that calls `show_dialogue(...)` and inlines quest-start logic.

The new system moves all of that into **data** (a `DialogueDB` autoload) and a **dedicated
conversation window** (`DialogueUI`), following the existing `open()/close()/is_open()` menu-UI
pattern (JobBoard, TravelGate, Shop, Cybernetics, GhostTerm).

---

## 2. Player-facing flow

1. Walk up to an NPC, press E. The **DialogueUI** opens (mouse released, like other menus).
2. NPC shows a **greeting** whose flavor depends on disposition tier.
3. Right side: **category tabs** — `Tell me about` · `Where is` · `Work` · `Any news?` · `Services` · `Goodbye`.
4. Selecting a category lists the **known keywords** in that category that you can ask about.
   Picking one prints the NPC's response in the transcript pane (and may teach new keywords,
   start/advance a quest, give an item, set a flag).
5. A **tone selector** (Polite / Normal / Blunt) sits in the window. Changing tone nudges this
   NPC's disposition and recolors borderline answers.
6. **Services** surfaces existing menu actions the NPC offers (open shop, job board, travel gate,
   cybernetics) — these hand off to the UIs that already exist.
7. **Goodbye** closes the window (recaptures mouse).

This mirrors Daggerfall's category → keyword list → response loop, with the tone bar and a
disposition read-out shown as an in-voice mood word rather than a number.

---

## 3. Data model

### 3.1 Topic / keyword

A topic is something the player can ask about. Defined once in `DialogueDB.TOPICS`:

```gdscript
"lan_tap": {
    "category": "thing",            # thing|person|location|work  (drives which tab it appears under)
    "label": "the severed LAN tap", # shown in the keyword list
    "starts_known": false,          # is it in the codex from the start?
}
```

- `category` maps to a tab: `person`/`thing` → "Tell me about", `location` → "Where is",
  `work` → "Work".
- Topics are global. Any NPC *can* be asked any **known** topic; whether they have something to
  say is per-NPC (see 3.3). Unknown-to-NPC topics get a disposition-flavored "I don't know" line.

### 3.2 Keyword codex (persistence)

`GameState.known_topics: Dictionary` — the set of topic ids the player has learned. Topics enter
the codex via:
- `starts_known: true` (universal small talk: "the false sky", "toxic rain", "Linda", the local
  faction names),
- an NPC response that lists them in `teaches: [...]` (clues spread by word of mouth),
- quest events (`GameState.learn_topic(id)` from anywhere).

The keyword list shown for a category, **per NPC** = (known topics in that category) ∪ (this NPC's
own authored topics in that category). For the NPC's own topics:
- **Work offers** are always selectable (picking one takes the job).
- **Known** lore topics, and any topic *without* a `hint` field (common knowledge), are selectable.
- Lore topics that authored a `hint` and are **not yet learned** render as a **non-clickable `?`
  cue**: the NPC clearly has something on it, but you must learn the keyword by word of mouth (a
  `teaches` chain) before it becomes askable here.

Known topics the NPC has no entry for are still askable and return the disposition-flavored shrug
line. This gives Daggerfall's word-of-mouth flow: `?` marks what's worth chasing, but the keyword
must be earned, not clicked.

### 3.3 NPC dialogue profile

One entry per NPC in `DialogueDB.NPC_PROFILES`, keyed by `npc_id` (the existing hub group id /
NPC identity):

```gdscript
"mister_static": {
    "name": "Mister Static",
    "faction": "System X",          # seeds baseline disposition; "" = neutral
    "tone_pref": "blunt",           # which tone this NPC warms to (see 5.2)
    "greetings": {                  # disposition-tiered greeting
        "warm":    "...", "neutral": "...", "cold": "...",
    },
    "topics": {
        "lan_tap": {
            "text": { "warm": "...", "neutral": "...", "cold": "..." },  # or a single String
            "hint": "something about the LAN",  # teaser shown on the `?` entry before it's learned
            "requires_flag": "",        # optional gate
            "min_disposition": "cold",  # optional gate
            "teaches": ["water_cistern"],
            "effects": [ {"type": "learn", "topic": "..."} ],
        },
        ...
    },
    "work": { ... },                # the "Work" category: quest offers/advancement
    "rumors": [ ... ],              # "Any news?" lines (see 6)
    "services": ["shop"],           # which Services buttons to show
    "unknown_line": { "warm": "...", "cold": "..." },  # fallback when asked an unknown topic
}
```

- `text` can be a plain `String` (same line regardless of mood) or a `{warm/neutral/cold}` dict.
- `effects` reuses the verb pattern already used by `WorldDirector.NAMED_CARDS`
  (`set_flag`, `add_rep`, `learn`, `give_item`, `start_quest`, `complete_quest`, `open_service`).
  This keeps quest logic in data instead of `match` blocks.

This format is a const Dictionary in an autoload — consistent with `GameState.QUEST_DEFS`,
`GameState.COOTERS_JOBS`, and `WorldDirector.NAMED_CARDS`.

---

## 4. GameState additions

```gdscript
var known_topics: Dictionary = {}      # topic_id -> true
var npc_disposition: Dictionary = {}   # npc_id -> int (0..100)
var conversation_tone := "normal"      # last-used tone, remembered between talks

func learn_topic(id: String) -> void
func has_topic(id: String) -> bool
func get_disposition(npc_id: String) -> int      # seeds from faction baseline on first read
func adjust_disposition(npc_id: String, delta: int) -> void
```

All three new vars get added to `save_game()` / `load_game()` (alongside `world_flags`,
`quest_states`, etc.). `starts_known` topics are seeded into `known_topics` lazily on first use.

---

## 5. Disposition + tone

### 5.1 Faction-seeded baseline (the "Both" model)

On first conversation with an NPC, `get_disposition()` seeds from the NPC's faction standing:

```
baseline = 50 + clamp(faction_rep * 5, -30, +30)   # neutral 50, shifted by your standing
```

Neutral/unaffiliated NPCs start at 50. Stored per-NPC thereafter so local changes stick.

### 5.2 Tone

Tone is a global toggle (remembered in `conversation_tone`). Each *new* topic ask applies a small
disposition delta based on whether the tone matches the NPC's `tone_pref`:

- Lower-city factions (System X, Wan Moa Torai, Pipe Church, Hoodlums) `tone_pref: "blunt"` —
  they respect directness; Blunt nudges up, fawning Polite nudges down.
- Corporate factions (Gatebox, Linda, Suitors) `tone_pref: "polite"` — Polite nudges up, Blunt
  nudges down.
- `Normal` is always a safe small nudge toward neutral.

This makes tone setting-meaningful: you read the room. (Daggerfall used etiquette/streetwise
skills; we substitute faction character, which fits the lore with no new skill stats.)

### 5.3 Disposition tiers

Three tiers keep authoring light (matches the `warm/neutral/cold` text keys):

- `cold`   (0–34): curt answers, many topics refused, services may be withheld.
- `neutral`(35–69): standard answers.
- `warm`   (70–100): fullest answers, extra rumor, services open, occasional bonus keyword.

The window shows the tier as a mood word in-voice (e.g., "wary", "civil", "warming"), never a
number.

---

## 6. Rumors / "Any news?"

Per-NPC `rumors` is a list of `{text, conditions}` entries. Selecting "Any news?" picks the
highest-priority rumor whose `conditions` match current world state (hub phase, completed quests,
faction flags) — reusing the same condition checks as `WorldDirector` event cards. Rumors can
`teach` topics, so word-of-mouth clues flow into the codex. A shared `DialogueDB.CITY_RUMORS`
pool supplies generic ambient lines so even minor NPCs have something to say.

---

## 7. UI — `DialogueUI`

New scene `scenes/ui/DialogueUI.tscn` + `scripts/ui/DialogueUI.gd`, added under the HUD like the
other menu UIs, with `open(npc_id)` / `close()` / `is_open()` and mouse release/recapture.

Layout:
- **Transcript pane** (left/center): NPC name, mood word, scrolling greeting + responses.
- **Category tabs** (right): Tell me about / Where is / Work / Any news? / Services / Goodbye.
- **Keyword list** (right, under tabs): scrollable buttons for the selected category. Known topics
  show their label; the NPC's own not-yet-learned topics show as a `?` hint with a teaser; known
  topics the NPC can't speak to are greyed but still askable (shrug line).
- **Tone bar** (bottom): Polite / Normal / Blunt.

Mouse-driven to match the list-based menus; keyboard nav can come later.

`HUDController` gains `open_dialogue(npc_id)` following the exact pattern of `open_job_board` etc.
(close the other panels, then `dialogue_ui.open(npc_id)`).

---

## 8. Integration — replacing the old path

1. `NPCDialogue` gets an `npc_id` export. `interact()` becomes: `hud.open_dialogue(npc_id)`
   (no more returned line). `face_player_now()` still runs.
2. Every location script's `match npc_name:` handler and its inline quest-start code is **deleted**
   and re-expressed as profile `topics`/`work`/`effects` in `DialogueDB`.
3. Services (`open_shop`, `open_job_board`, `open_travel_gate`, `open_cybernetics`) are invoked
   from the "Services" category via an `open_service` effect, so existing UIs are reused unchanged.
4. The spine's Linda/System X *conversations* (greetings, audience scenes) become profiles too.

### Boundary: object/console interactions

The mandate dais, rupture console, valves, crates, terminals, etc. are **not conversations** —
they stay as direct `show_dialogue` one-shots (a topic window on a wall panel would feel wrong).
To keep presentation consistent, `DialogueUI` supports a **statement mode** (`open_statement(speaker, text)`):
same window frame, greeting text only, just a "Goodbye" — used for these object lines and for any
quick barks. This honors "replace everything" for the *look* without forcing topic trees onto
inanimate objects.

---

## 9. Content authoring

All authored content lives in `scripts/systems/DialogueDB.gd` (new autoload):
`TOPICS`, `NPC_PROFILES`, `CITY_RUMORS`. Writing follows `npc_writing_style_guide.md` (sincere
baseline under sarcasm, faction voice, brush cosmic truth without naming it). Disposition tiers
let one NPC sound generous when warm and clipped when cold without new systems.

### Worked example (abbreviated)

```gdscript
"mister_static": {
    "name": "Mister Static", "faction": "System X", "tone_pref": "blunt",
    "greetings": {
        "warm":    "You again. Good. The generator stopped sounding like a dying organ, partly your fault.",
        "neutral": "Make it quick, the coupling does not babysit itself.",
        "cold":    "I am busy keeping the lights honest. Talk fast or talk to the dark.",
    },
    "topics": {
        "generator": { "text": {
            "warm": "She is stable. I stopped apologising to her. We reached an understanding.",
            "neutral": "Held together with tape and intention. Tape is not a plan, just optimistic adhesive.",
            "cold": "It runs. That is all you are getting." }, "teaches": ["faded_atrium"] },
        "lan_tap": { "text": "Vessel's department, not mine. Ask the bunny when it stops sulking.",
                     "requires_flag": "vessel_repaired" },
    },
    "work": {
        "hub_power_restore": {
            "offer": "Coupling is in the basement. Fix it properly before the tape develops opinions.",
            "effects": [ {"type": "start_quest", "quest": "hub_power_restore"},
                         {"type": "learn", "topic": "generator_coupling"} ],
        },
    },
    "rumors": [
        {"text": "Heard the bar's tap finally runs. Vessel pouring. Miracles come cheap when the water's clean.",
         "conditions": {"flag_true": "bar_open"}},
    ],
    "services": [],
    "unknown_line": { "warm": "Not my wheelhouse, friend.", "cold": "No idea. Try someone paid to care." },
}
```

---

## 10. Implementation phases

1. **Core data + state.** `DialogueDB` autoload skeleton (`TOPICS`, `NPC_PROFILES`, `CITY_RUMORS`);
   `GameState` additions (`known_topics`, `npc_disposition`, `conversation_tone`) + save/load.
2. **Disposition/tone engine.** `get_disposition` seeding, `adjust_disposition`, tier mapping,
   tone deltas, effect-verb resolver (shared with the card condition/effect helpers).
3. **DialogueUI scene + controller.** Tabs, keyword list, transcript, tone bar; `open(npc_id)`,
   `open_statement(...)`, `close`, `is_open`; `HUDController.open_dialogue`.
4. **Wire NPCDialogue.** Add `npc_id`; route `interact()` → `open_dialogue`. One pilot NPC end to end.
5. **Migrate content, location by location.** Port hub NPCs first (Static, Gideon, Vera, Kiki,
   Ladderboy, Vessel, Velvet Coil), then the district, then the spine. Delete `match` handlers as
   each NPC moves over. Move quest-starts into `work`/`effects`.
6. **Rumors + codex polish.** World-state rumor selection; seed `starts_known` topics; verify
   keyword propagation across NPCs.
7. **Statement mode for objects.** Route console/valve/crate lines through `open_statement` for a
   consistent frame; remove the last raw `show_dialogue` callers (or keep `show_dialogue` as the
   thin backend `open_statement` uses).

Phases 1–4 are the engine and can land before any content migration; the game keeps working
because un-migrated NPCs still fall back to their old line until ported.

### Status — phases complete

All NPC content is migrated. Hub NPCs (Static, Gideon, Vera, Kiki, Ladderboy, Vessel, Velvet
Coil, Ronnie, the informant, the survivor, Sunday, Torai, System X) plus the two remaining
side-location NPCs are now data-driven:

- **Marbles (Cooters).** Full profile: disposition-tiered greetings that react to job state
  (`job_active`/`job_ready` conditions), a `job_board` service, and a `collect_pay` work topic
  gated by `requires_job_ready` that pays out via a new `complete_job` effect verb. The old
  `_handle_marbles` special-case is deleted; Cooters routes profiled NPCs to the topic window and
  handles the `job_board` service + a dialogue-closed HUD refresh. Job accept (board UI signal) and
  the standalone job-board interactable are unchanged.
- **Sunday (Suitors).** Wired to her existing profile; the surveillance-choir hack terminal stays a
  scripted object/minigame.

Engine additions for the above: `job_active` / `job_ready` conditions, `requires_job_ready` topic
visibility gate, and the `complete_job` effect (all in `DialogueDB`).

**Statement mode (hybrid).** Object/prop lines use the framed statement window only for dismissable
narrative reveals — the Velvet Coil tunnel cameo, and Rocker Fellar Keep's Warning Graffiti,
Contract Ledger, and Cage Evidence. Quick functional barks (valves, crates, junctions, "already
done" states), timed outros (the extraction lift, which auto-advances to a scene change), and
boss-combat barks (a mouse-releasing modal mid-fight would be disruptive) stay on the lightweight
HUD banner. The destinations are all functional barks, so they keep the snappy banner throughout.

---

## 11. Risks / open questions

- **Content volume.** Hand-authoring topics for every NPC across 3 disposition tiers is the bulk
  of the work. Mitigation: tiers are optional (plain String is allowed), `CITY_RUMORS` + shared
  topic defaults cover minor NPCs, and migration is incremental.
- **Tone economy.** Need to make sure tone can't be spammed to farm disposition — cap per-NPC
  tone gains per conversation, or only apply the delta on first ask of each topic.
- **Resolved — Spine scope.** The campaign spine stays scripted and out of scope; the system
  covers non-spine characters only. Objects everywhere still use statement mode.
- **Resolved — Keyword discoverability.** A topic with a `hint` shows as a non-clickable `?` cue
  until its keyword is learned by word of mouth (`teaches`); then it becomes askable. Topics
  without a `hint` stay directly askable; work offers are always selectable (see 3.2 / 3.3).
