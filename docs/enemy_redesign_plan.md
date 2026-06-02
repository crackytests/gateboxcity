# GATEBOX BREACH — Enemy Redesign Plan
*From "disable checklist" to readable, reactive locational combat*

---

## Intent

The locational dismemberment system (hold-to-lock targeting → destroy parts → consequences)
is the game's combat identity. It is currently underexploited: enemies share one shallow FSM,
part destruction is purely subtractive and always safe, and none of the game's newer systems
(drift, drugs, hacking, cybereye, soul-rot) touch combat.

This plan keeps the identity and rebuilds around four pillars:

1. **Telegraph → interrupt** — readable wind-ups tied to parts you can shoot to cancel.
2. **Volatile / moral parts** — parts that are dangerous or costly to destroy.
3. **System-reactive enemies** — combat that reads drift, hacking, cybereye, soul-rot.
4. **Pack / coordinated AI** — shared state, alerts, anchor units.

Enabling all of it: a **data-driven `BodyPartData`** so consequences live in `.tres` files,
not hardcoded `match part.display_name` blocks in every subclass.

---

## CURRENT STATE AUDIT

| Enemy | File | Behaviour today | Parts → consequence |
|---|---|---|---|
| Goon Material | `Enemy.gd` | PATROL→(LOS)→COMBAT→walk to range→tick melee/ranged on cooldown | Leg→slow · Right Arm→no ranged · Head→stun+defeat · Torso→defeat |
| Splice | `Splice.gd` | Inherits Enemy; melee only | Wire Skull→stun · Graft Shell→defeat · Splice Arm→**berserk** (temp dmg) · Drag Frame→slow |
| Rain Mutant | `RainMutant.gd` | Inherits Enemy; **regenerates** parts in toxic rain unless in containment zone; capture-not-kill | Rain Sac→less dmg/no ranged · Mobility Frame→slow · Claws→less dmg · Anchor Spine→stun |
| Rocker Fellar | `RockerFellar.gd` | Boss; 3 phases, 6 parts; stage→descend→charge; can regen | Jaw Amp→no sonic · Soul Resonator→(none) · Cable Whips→less melee · Spine→slow · Stage Core→defeat |
| Security Node | `SecurityNode.gd` | **Standalone** (not Enemy); stationary turret; rotating pulse attack | Lens→less dmg · Antenna→less range/slower · Core→defeat |

**Shared FSM (Enemy.gd):** `_process_patrol` (LOS check → COMBAT, else walk patrol points) and
`_process_combat` (close to `attack_range`, else `move_toward 0`, then `_try_attack`).
`_try_attack` applies damage instantly on `attack_cooldown`. `_has_line_of_sight` already
respects `whisper_filter` (range × 0.55). Pacify/talk exists (`pacify()`, `EnemyTalkZone`,
`is_talkable()`) but is only triggered by scripted Linda mandates.

**`BodyPartData` fields today:** `display_name`, `max_hp`, `targeting_penalty`,
`lock_difficulty_multiplier`, `armor_value`.

---

## DIAGNOSIS

1. **One FSM for everyone.** No telegraphs, cover, retreat, or coordination.
2. **Part destruction is subtractive and risk-free.** Enemies only get weaker; no reason to
   ever *not* shoot a part; no target prioritization.
3. **The targeting system barely interacts with enemies.** Player skill = "hold reticle to raise
   hit chance." Enemies never juke to break lock, shield parts, or open timed windows.
   `RockerFellar.expose_stage_core()` is the ONE place a part's `lock_difficulty_multiplier` is
   used dynamically — and it's excellent. It should be everywhere.
4. **New systems are combat-blind.** drift, drugs, soul-rot, hacking, cybereye overlay: none react.
5. **Duplication.** `SecurityNode` reimplements the part system; every subclass hardcodes
   consequences in `match` blocks.

---

## PILLAR A — TELEGRAPH → INTERRUPT

Attacks stop being instant. Each significant attack has a **wind-up** owned by a specific part:

```
IDLE → WINDUP (telegraph, ~0.5–0.9s) → STRIKE (apply damage) → RECOVER (cooldown)
```

- During WINDUP the owning part **lowers its `lock_difficulty_multiplier`** (easier to lock) and
  the cybereye overlay pulses it. Destroying or hard-staggering that part during WINDUP **cancels
  the strike** and staggers the enemy.
- Telegraph is communicated by: billboard flash/scale (already have `flash_damage`,
  `show_part_broken`), a wind-up light/colour, and an optional HUD callout.
- This is the core *feel* fix: it makes the lock-on matter under pressure and turns part targeting
  into active interrupts instead of a to-do list.

**Data:** `BodyPartData.telegraph_ability: String` (`""`, `"ranged_shot"`, `"charge"`,
`"sonic_beam"`, `"lunge"`). The base AI runs a wind-up timer when the owning part is alive and the
attack is chosen; if the part dies mid-wind-up, cancel + stagger.

---

## PILLAR B — VOLATILE / MORAL PARTS

Not every part is safe to destroy. Add consequences that fire **on destruction**:

| Effect | Behaviour | Example part |
|---|---|---|
| `detonate` | AoE damage at the part's position on death — lethal up close, safe at range | Splice **Drag Frame** (overclocked reactor) |
| `rupture_cloud` | Spawns a lingering toxic/spore volume | Rain Mutant **Rain Sac** |
| `free_soul` | Releases a trapped soul: soul-rot +, faction rep shift, easy-kill shortcut | Big Gates **Soul Resonator/Battery** |
| `enrage` | Surviving parts gain damage/speed (already Splice berserk) | Splice **Splice Arm** |

This creates the missing **prioritization decision**: legs-first (safe, slow) vs. core (fast,
dangerous), and a **moral** axis (destroy the soul battery for a cheap win at a soul-rot cost, or
spare/hack it). The cybereye overlay should tag volatile parts (e.g. magenta "⚠ RUPTURE").

**Data:** `BodyPartData.volatile: bool`, `on_destroy_effect: String`, `effect_radius: float`,
`effect_payload: Dictionary` (damage, soul_rot, rep, item, etc.).

---

## PILLAR C — SYSTEM-REACTIVE ENEMIES

| System | Enemy reaction |
|---|---|
| **Drift** | High-drift player "reads as one of them." Gatebox/Preservation units **mis-ID and hesitate** (delayed aggro = stealth window); Splice and citizen-type enemies turn **more** aggressive. Drift becomes a two-edged combat stat. Hook: `Enemy.detection_delay` scaled by `GameState.get_drift()` and a `faction` tag. |
| **Hacking** | Designate parts `hackable`. Instead of/along with destroying, run the existing hack minigame to **stun / blind / turn** the unit. `neural_jack` lowers difficulty. Primary identity for `SecurityNode`, Splice **Wire Skull**, Preservation drones. |
| **Cybereye** | The overlay already brackets regions. Extend it to flag `weak_point`, `volatile`, and `hackable` parts only when the eye is installed — making the implant feel essential. |
| **Soul-rot** | High soul-rot warps perception: corrupted/jittering enemy callouts, occasional false body-part reads (a lore-justified accuracy debuff). `free_soul` parts add soul-rot. |
| **Drugs** | Already affect the player side (Redline dmg, Glass aim). Enemies need no change; volatile/telegraph play makes drug windows meaningful. |

---

## PILLAR D — PACK / COORDINATED AI

`DeadFoodCourtBloom` spawns 7 Splices that act as 7 loners. Give group enemies shared state:

- **Alert propagation:** one unit spotting the player flips nearby same-faction units to COMBAT
  (radius check on alert), so stealth/whisper_filter actually matters.
- **Anchor unit:** one Splice is the pack **Anchor**; while alive it grants the pack a buff
  (berserk-on-death contagion, +damage, coordinated approach). Kill the Anchor → pack loses
  coordination and reverts to solo behaviour. New group-level target priority.
- **Spacing:** simple separation steering so packs flank/surround instead of stacking on one tile
  (cheap: push away from nearest ally each frame).

**Data/impl:** a lightweight `EnemyPack` resource or a runtime group tag set by the spawning level;
`Enemy.pack_id` + a static registry, or signals through the level script (which already wires
`set_patrol_points`).

---

## ENABLING REFACTOR — DATA-DRIVEN `BodyPartData`

Move consequences out of code and into the part resource. Proposed fields (additive; existing
fields stay):

```gdscript
# BodyPartData.gd (proposed additions)
@export var part_role := "limb"          # "core" | "head" | "limb" | "module"
@export var on_destroy_effect := ""       # "" | "stun" | "slow" | "disable_ranged" |
                                          # "enrage" | "detonate" | "rupture_cloud" |
                                          # "free_soul" | "defeat"
@export var effect_strength := 1.0        # stun secs / slow mult / detonate dmg, etc.
@export var effect_radius := 0.0
@export var effect_payload: Dictionary = {}   # {soul_rot, rep_faction, rep_amount, item, ...}

@export var telegraph_ability := ""       # "" | "ranged_shot" | "charge" | "sonic_beam" | "lunge"
@export var windup_lock_bonus := 0.0      # subtract from lock_difficulty_multiplier during wind-up
@export var volatile := false             # cybereye flags it; usually pairs with detonate/rupture
@export var hackable := false             # eligible for the hack minigame as an alternative
@export var weak_point := false           # cybereye "best target" flag; small damage bonus
```

Then a single base `Enemy._on_part_destroyed(part)` reads `part.body_part_data.on_destroy_effect`
and dispatches via `match` **once**. ~90% of `Splice`/`RainMutant`/`RockerFellar`/`SecurityNode`
override code disappears, and authoring a new enemy becomes writing `.tres` files. Bosses keep a
thin subclass only for phase logic.

`SecurityNode` folds back onto the unified base (it's a stationary `module`-role enemy with one
telegraphed pulse and a `hackable` Antenna).

---

## BASE `Enemy` AI REDESIGN

Extend the FSM with wind-up and a couple of branches:

```
PATROL → (LOS, after detection_delay) → COMBAT
COMBAT:
  choose attack (melee in range / telegraphed ranged at distance)
  → WINDUP (telegraph; owning part lock-eased; interruptible)
  → STRIKE (damage) → RECOVER (cooldown)
  low-integrity branch:
    aggressive type → enrage/charge
    fragile/citizen type → FLEE → SURRENDER (→ pacify/talkable)
COVER (optional, cheap): when ranged disabled, step toward nearest blocker
```

- **Surrender** generalises the existing `pacify()`/`is_talkable()` path into a real non-lethal
  axis, gated by soul-rot / faction standing rather than scripted Linda mandates only.
- Keep it cheap: no navmesh required; separation + move_toward + LOS is enough for the mall spaces.

---

## PER-ENEMY REDESIGN SPECS

### Goon Material (baseline template)
- Telegraphed **trash-cannon** shot owned by Right Arm (`telegraph_ability="ranged_shot"`);
  shoot the arm mid-wind-up to cancel. Head wind-down still stuns/defeats.
- Low-integrity **flee → surrender** branch → talkable (soul-rot/faction gated).
- Light cover-seeking once ranged is gone.

### Splice (pack predator)
- **Pack/Anchor**: berserk becomes *contagious*; Anchor Splice buffs the group.
- Splice Arm telegraphs a **lunge** — cancelable; on destruction → enrage (existing).
- **Drag Frame = volatile reactor** (`detonate`): rewards ranged kills, punishes knifing.
- **Wire Skull = hackable** → hard stun / brief turn.

### Rain Mutant (positioning puzzle, cleaned up)
- Keep capture-not-kill + rain regen.
- **Rain Sac = volatile `rupture_cloud`**: rupture-vs-contain becomes a spatial choice.
- Replace the wall of hint-strings with **cybereye flags** on Rain Sac (⚠) and Mobility Frame.

### Rocker Fellar (boss; signature interrupts)
- Each phase gets one **interruptible signature** keyed to a part:
  - P1 **sonic** = Jaw charge (cancel by staggering Jaw Amp).
  - P3 **charge** = Spine (blow the Amplifier Spine to topple him → big opening).
- **Soul Resonator = moral/volatile** (`free_soul`): destroy for a fast win at soul-rot + Big Gates
  rep cost, or hack/spare for a cleaner resolution. Gives the fight a decision, not just a part list.

### Security Node (hack-first surveillance)
- Fold onto unified base. Primary play = **hack the Antenna** to blind the network / open a stealth
  lane; destroying the Lens reduces damage; Core defeats. Less bullet-sponge, more theme.

---

## NEW ARCHETYPE SEEDS (exploit the unique systems)

| Archetype | Faction | Hook |
|---|---|---|
| **Preservation Drone** | Gatebox / Preservation Directive | Scans you; **mis-IDs high-drift players** (hesitates). Hackable optics. Calls reinforcements if it completes a scan — interrupt the scan (telegraph). |
| **Comfort Unit** | Gatebox | Non-hostile until provoked; tries to *pacify you* (applies a slow/"sedation"); destroying it has a faction/soul-rot cost — a moral encounter. |
| **Soul Harvester** | Big Gates Foundation | Carries multiple **soul batteries** (`free_soul` volatile parts); a walking moral minefield. |
| **Hoodlum Netrunner** | street | Buffs/repairs other enemies remotely; **hack or kill the runner** to collapse the group's support — pack priority target. |

---

## SYSTEM INTEGRATION MATRIX

| System | Combat role after redesign |
|---|---|
| Targeting/lock | Interrupt windows via dynamic `lock_difficulty_multiplier` during telegraphs |
| Cybereye | Flags weak/volatile/hackable parts; the "read the fight" tool |
| Drift | Mis-ID/hesitation vs. extra aggression by faction — two-edged |
| Hacking | Alternative to destruction: stun/blind/turn; `neural_jack` eases it |
| Soul-rot | Rises from `free_soul` kills; high rot warps enemy reads (lore debuff) |
| Drugs | Redline/Glass windows matter against telegraph/volatile play |
| Pacify/talk | Generalised surrender axis (non-lethal), soul-rot/faction gated |

---

## IMPLEMENTATION ORDER

```
STEP 1 — Data-driven parts        [enabling refactor]
  ├── Extend BodyPartData with the proposed fields
  ├── Base Enemy._on_part_destroyed reads data, single dispatch
  ├── Port Splice / RainMutant / SecurityNode consequences into .tres
  └── Keep RockerFellar's phase logic thin on top

STEP 2 — Telegraph → interrupt    [the feel fix]
  ├── Add WINDUP/STRIKE/RECOVER to base AI
  ├── lock_difficulty eased + cybereye pulse during wind-up
  ├── Destroy/stagger owning part = cancel + stagger
  └── Convert Goon ranged shot + Boss signatures

STEP 3 — Volatile / moral parts
  ├── detonate / rupture_cloud / free_soul effects
  ├── Cybereye volatile/weak/hackable flags
  └── Wire soul-rot + faction payloads (free_soul)

STEP 4 — System-reactive
  ├── Drift mis-ID / aggro by faction tag
  ├── Hackable parts → existing hack minigame (stun/blind/turn)
  └── neural_jack difficulty easing

STEP 5 — Pack / coordination
  ├── Alert propagation + separation steering
  ├── Anchor unit buff + collapse-on-death
  └── Apply to DeadFoodCourtBloom Splice packs

STEP 6 — New archetypes
  └── Preservation Drone, Comfort Unit, Soul Harvester, Hoodlum Netrunner
```

Steps 1–2 deliver the biggest gameplay change and unblock everything else. Each step is shippable
on its own and respects the current spawn/wire architecture (levels keep calling
`set_patrol_points`, `pacify`, `contain`, `alert`).

---

## OPEN QUESTIONS / RISKS

- **Non-uniform hitbox tuning** (the new debug menu) pairs with this — bake region sizes before
  authoring weak/volatile parts so the cybereye boxes read true.
- **Telegraph readability** depends on billboard VFX; may need a dedicated wind-up light/decal per
  enemy rather than reusing the damage flash.
- **`free_soul` economy**: soul-rot is a global pressure clock (Phase 6 of expansion_plan.md) — tune
  so moral kills are tempting but not free.
- **Pack AI cost**: keep separation/alert O(n²) small (packs are <10); no navmesh.
- **Boss regen** (`regen_all_parts`) should not undo volatile/interrupt progress — exclude
  destroyed/volatile parts from regen.
