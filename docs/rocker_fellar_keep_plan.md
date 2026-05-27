# Rocker Fellar Keep — General Boss Level Build Plan

**Scene:** `scenes/levels/RockerFellarKeep.tscn`
**Script:** `scripts/systems/RockerFellarKeep.gd`
**Quest giver:** System X terminal (Faded Atrium) or Kiki Baja (after completing three Cooters jobs)
**Quest flag:** `quest_rocker_fellar`
**Region:** Big Gates Foundation fortress — deep Sub-Sub-Basement, below even Leak Street

---

## General Identity: Rocker Fellar

**Rank:** General of the Big Gates Foundation
**Theme:** Death-metal vampire cyborg. Decadent, theatrical, obscene wealth built on soul harvesting and body horror. His fortress is a concert venue, a cathedral, and a slaughterhouse stitched together.
**Visual:** Tall, gaunt frame wrapped in chrome and stained stage leather. Jaw replaced with a bass-frequency amplifier that he uses as both voice and weapon. Chest cavity is an open resonating chamber lined with stolen soul batteries that pulse like amplifier tubes. Arms end in cable-cord whips tipped with salvaged guitar-neck blades. He drinks harvested soul fluid from a crystal goblet and treats combat like a headlining performance.

**Boss body parts:**

| Part | HP | Targeting Penalty | Lock Difficulty | Armor | On Destroy |
|---|---|---|---|---|---|
| Jaw Amplifier | 60 | 12 | 1.6 | 4 | Silences his sonic attack; he enrages and whips faster |
| Soul Resonator (chest) | 90 | 8 | 1.3 | 2 | Stops soul-drain aura; weakens regeneration |
| Left Cable Whip | 45 | 6 | 1.1 | 1 | Halves melee damage; he goes ranged-only for a phase |
| Right Cable Whip | 45 | 6 | 1.1 | 1 | Same as left; destroying both disables melee entirely |
| Amplifier Spine | 35 | 15 | 1.8 | 3 | His movement speed drops 60%; he can no longer reposition |
| Stage Core (back, exposed during power-up) | 55 | 18 | 2.0 | 0 | Defeat trigger — the core overloads and he collapses |

**Boss behavior phases:**

1. **Opening Set** — Stays on elevated stage platform. Uses sonic attacks (jaw amplifier) and summons amp-stack minions. Every 20 seconds he "solos": the room shakes, lights flash, and two cable-whip lash attacks sweep the floor.
2. **Encore** — After Jaw Amplifier OR Soul Resonator is destroyed. Descends to floor level. Cable whips now target player directly. Spawns blood-pit horrors from the orchestra pit. Moves faster.
3. **Feedback Loop** — After three parts destroyed. His amplifier spine glows; he charges around the room trying to body-slam the player. Stage Core becomes targetable from behind during charge recovery (2-second window after each charge).
4. **Final Note** — Stage Core destroyed. Cinematic defeat. He shatters into feedback static and collapsed chrome.

---

## Site Card

```yaml
site_id: rocker_fellar_keep
name: "Rocker Fellar Keep"
site_type: "Big Gates Foundation General headquarters / concert fortress"
region: deep_sub_sub_basement (below Leak Street; accessed via service lift from Faded Atrium basement)
old_function: "underground performance venue and broadcasting complex"
current_function: "Rocker Fellar's personal fortress; soul-harvesting concert hall; decadent monument to wasted potential"
main_resource_pressure: soul, salvage, safety
visual_identity:
  - entrance hall: marble floors cracked by bass vibrations; gold-framed portraits of Rocker Fellar in different "eras" — all grotesque
  - grand corridor: red carpet over industrial grating; chandeliers made from spinal columns and microphone stands; piped-in death metal at low volume
  - blood pit orchestra pit: sunken pit in the concert hall floor filled with thick red-black fluid; bio-horror creatures spawn from it
  - amp stack wall: towering speaker cabinets stacked floor to ceiling; emit shockwaves during boss phases; destroy individual stacks to reduce boss damage
  - VIP lounge: opulent wreckage — overturned bar, broken instruments, soul-fluid stains on velvet; loot and lore
  - backstage tunnels: narrow service corridors behind the stage; props, cages, and evidence of Fellar's harvesting operation
  - soul battery vault: rows of glowing soul batteries in recharge cradles; destroy to weaken boss regeneration
  - main stage: elevated platform with lighting rig; Fellar's throne; cable runs and pyrotechnic charges (environmental hazard)
key_spaces:
  - name: "Service lift entry"
    gameplay: "spawn; immediate visual of the keep's scale; locked gate opens with quest flag"
  - name: "Entrance hall"
    gameplay: "first enemies; cover behind fallen columns; loot crate near ticket booth"
  - name: "Grand corridor"
    gameplay: "linear push toward concert hall; side rooms for flanking; environmental hazards from bass vibrations (ceiling debris falls periodically)"
  - name: "VIP lounge (east side)"
    gameplay: "optional detour; lore about Fellar's harvesting contracts; loot; health pickup; shortcut back to corridor"
  - name: "Concert hall"
    gameplay: "main arena; boss fight; amp stacks, blood pit, stage; soul batteries on catwalks"
  - name: "Backstage tunnels (west)"
    gameplay: "flank route to stage; destroy soul batteries behind stage to weaken boss; cages with evidence"
  - name: "Soul battery vault (below stage)"
    gameplay: "accessed via backstage hatch; destroy all 4 battery cradles to disable boss regeneration permanently; heavy hazard (soul burn 2 hp/s near batteries)"
  - name: "Stage platform"
    gameplay: "boss home position in phase 1; catwalks above for player vertical routing"
  - name: "Extraction lift"
    gameplay: "unlocks after boss defeat; return to Faded Atrium with loot"
occupants:
  faction_or_group: "Big Gates Foundation — Rocker Fellar's personal retinue"
  motive: "guard the general; maintain the soul harvest; keep the concert going"
  default_state: "patrol corridors; amp-stack operators at their stations; blood-pit horrors dormant until boss summons them"
enemies:
  - Amp Stack Operator: stationary; fires shockwave pulse (ranged); body parts: Head, Torso, Control Arm; destroy Control Arm to disable shockwave
  - Blood Pit Horror: crawls from orchestra pit during boss phases; fast, low damage, swarm behavior; body parts: Skull, Torso, Front Limbs x2, Rear Limbs x2
  - Cable Fiend: patrol in backstage tunnels; uses whip melee; body parts: Head, Torso, Whip Arm, Legs x2
  - Soul Warden: guards battery vault; pacifies player on hit (2 sec stun); body parts: Helm, Torso, Suppression Arm, Legs x2
boss: Rocker Fellar (see body parts and phases above)
hazards:
  environmental:
    - bass vibration debris: periodic ceiling collapse in grand corridor; 8 damage per hit; dodge by watching dust particles fall
    - blood pit: red-black fluid in orchestra pit; 2 hp/s at y < 1.2 in the concert hall
    - soul burn: proximity to soul batteries; 2 hp/s within 2 units; destroys when battery cradle is smashed
    - pyrotechnic charges: on stage rail; explode when shot or after boss phase transition; 15 damage in 3-unit radius
    - amp stack shockwave: emitted by intact amp stacks during boss fight; 5 damage + pushback in cone
  social_or_tactical: "Fellar taunts the player between phases; breaking amp stacks reduces his damage; destroying soul batteries stops his regeneration"
player_approaches:
  combat: "push through grand corridor, fight into concert hall, engage boss on stage"
  stealth: "backstage tunnels bypass corridor enemies; reach soul batteries before engaging boss; weakened boss is easier"
  technical: "shoot pyrotechnic charges during boss fight for environmental damage; destroy amp stacks from catwalk to reduce boss attack power; hack stage lights to blind boss temporarily"
twist: "the soul batteries contain the harvested potential of Leak Street residents — destroying them frees the souls but Fellar has already processed most of them into his personal amplifier system. The real loot is the contract ledger linking Fellar to Wan Moa Torai and Gatebox Corporation procurement"
```

---

## Layout Map

```
                    N (extraction lift after boss defeat)
                    |
            [Soul Battery Vault — below stage, accessed via backstage hatch]
                    |
   [Backstage   /------\   [Stage Platform]
    Tunnels]    | CONCERT|   (boss home, pyrotechnics, catwalks above)
    (west)      |  HALL  |   [Amp Stacks along north/south walls]
                | (blood |
   [VIP        |  pit   |    pit in center floor)
    Lounge]     |  sunken)|
    (east)      \--------/
         \          |
          \   [Grand Corridor — red carpet, chandeliers, bass debris]
           \         |
            [Entrance Hall — columns, ticket booth, first enemies]
                    |
                    S (service lift entry from Faded Atrium)
```

---

## Geometry Spec

### Room dimensions

```
Entrance Hall:       x -8..8,   z 0..12,   y 0..5
Grand Corridor:      x -6..6,   z -20..0,   y 0..6   (taller for chandeliers)
VIP Lounge:          x 6..14,   z -14..-6,  y 0..4
Backstage Tunnels:   x -14..-6, z -14..-6,  y 0..3.5
Concert Hall:        x -16..16, z -48..-20, y 0..8   (tall venue ceiling)
  Stage Platform:    x -6..6,   z -48..-40, y 0..2   (elevated to y=1.8)
  Blood Pit:         x -8..8,   z -38..-30, y -1..0   (sunken below floor)
  Catwalk (north):   x -16..16, z -46..-44, y=5.5
  Catwalk (south):   x -16..16, z -22..-20, y=5.5
Soul Battery Vault:  x -6..6,   z -54..-48, y -2..0   (below stage, via hatch)
```

### Key collision surfaces

```
# Entrance Hall
EntranceFloor: StaticBody3D (16, 0.5, 12) at (0, -0.25, 6)
EntranceCeiling: StaticBody3D (16, 0.25, 12) at (0, 5.125, 6)
EntranceNorth: StaticBody3D (16, 5.5, 0.35) at (0, 2.75, 0) — has gap at x -2..2 for corridor entry
EntranceSouth: StaticBody3D (16, 5.5, 0.35) at (0, 2.75, 12) — has gap at x -2..2 for lift entry
EntranceEast: StaticBody3D (0.35, 5.5, 12) at (8, 2.75, 6)
EntranceWest: StaticBody3D (0.35, 5.5, 12) at (-8, 2.75, 6)
EntranceColumns (4x): StaticBody3D (0.6, 4.5, 0.6) at (-4, 2.25, 3), (4, 2.25, 3), (-4, 2.25, 9), (4, 2.25, 9)

# Grand Corridor
CorridorFloor: StaticBody3D (12, 0.5, 20) at (0, -0.25, -10)
CorridorCeiling: StaticBody3D (12, 0.25, 20) at (0, 6.125, -10)
CorridorEast: StaticBody3D (0.35, 6.5, 20) at (6, 3.25, -10) — gap at z -14..-6 for VIP Lounge
CorridorWest: StaticBody3D (0.35, 6.5, 20) at (-6, 3.25, -10) — gap at z -14..-6 for Backstage
CorridorNorth: StaticBody3D (12, 6.5, 0.35) at (0, 3.25, -20) — gap at x -4..4 for concert hall

# VIP Lounge (east side room)
VIPFloor: StaticBody3D (8, 0.5, 8) at (10, -0.25, -10)
VIPNorth: StaticBody3D (8, 4.5, 0.35) at (10, 2.25, -14)
VIPEast: StaticBody3D (0.35, 4.5, 8) at (14, 2.25, -10)
VIPSouth: StaticBody3D (8, 4.5, 0.35) at (10, 2.25, -6)

# Backstage Tunnels (west side room)
BackstageFloor: StaticBody3D (8, 0.5, 8) at (-10, -0.25, -10)
BackstageNorth: StaticBody3D (8, 3.5, 0.35) at (-10, 1.75, -14) — has hatch at x -10, z -14 to battery vault below
BackstageWest: StaticBody3D (0.35, 3.5, 8) at (-14, 1.75, -10)
BackstageSouth: StaticBody3D (8, 3.5, 0.35) at (-10, 1.75, -6)

# Concert Hall (main arena)
ConcertFloor: StaticBody3D (32, 0.5, 28) at (0, -0.25, -34)
ConcertCeiling: StaticBody3D (32, 0.25, 28) at (0, 8.125, -34)
ConcertEast: StaticBody3D (0.35, 8.5, 28) at (16, 4.25, -34)
ConcertWest: StaticBody3D (0.35, 8.5, 28) at (-16, 4.25, -34)
ConcertNorth: StaticBody3D (32, 8.5, 0.35) at (0, 4.25, -48)
ConcertSouth: StaticBody3D (32, 8.5, 0.35) at (0, 4.25, -20) — gap at x -4..4 from corridor

# Stage Platform (elevated, north end of concert hall)
StagePlatform: StaticBody3D (12, 0.28, 8) at (0, 1.66, -44) — surface y=1.8
StageRamp: StaticBody3D (3, 0.2, 3) at (0, 0.9, -40.5) rot(-0.278, 0, 0) — ramp from floor to stage

# Blood Pit (sunken, center of concert hall)
BloodPitFloor: StaticBody3D (16, 0.5, 8) at (0, -1.25, -34) — surface y=-1.0; player y≈0.05 → takes damage
BloodPitWalls (4x): StaticBody3D (16, 1.5, 0.35) at (0, -0.25, -30), (0, -0.25, -38), (0.35, 1.5, 8) at (-8, -0.25, -34), (8, -0.25, -34)
BloodPitRailing (visual only, no collision): edges of pit at y=0.0

# Catwalks (elevated side routes)
NorthCatwalk: StaticBody3D (32, 0.2, 2) at (0, 5.4, -45) — surface y=5.5
SouthCatwalk: StaticBody3D (32, 0.2, 2) at (0, 5.4, -21)
CatwalkLadderNE: StaticBody3D (0.4, 5.5, 0.4) at (14, 2.75, -45) — ladder access
CatwalkLadderNW: StaticBody3D (0.4, 5.5, 0.4) at (-14, 2.75, -45)
CatwalkLadderSE: StaticBody3D (0.4, 5.5, 0.4) at (14, 2.75, -21)
CatwalkLadderSW: StaticBody3D (0.4, 5.5, 0.4) at (-14, 2.75, -21)

# Soul Battery Vault (below stage)
VaultFloor: StaticBody3D (12, 0.5, 6) at (0, -2.25, -51)
VaultCeiling: StaticBody3D (12, 0.25, 6) at (0, -0.125, -51)
VaultWalls: StaticBody3D (12, 2.0, 0.35) at (0, -1.25, -48), (0, -1.25, -54)
VaultEast: StaticBody3D (0.35, 2.0, 6) at (6, -1.25, -51)
VaultWest: StaticBody3D (0.35, 2.0, 6) at (-6, -1.25, -51)
VaultHatch: StaticBody3D (2, 0.1, 2) at (-10, -0.05, -14) — hatch from backstage to vault ladder
VaultLadder: StaticBody3D (0.4, 2.0, 0.4) at (-10, -1.0, -14.3)
```

---

## Routes Through the Keep

### Route 1 — Frontal Assault (Combat)
- Enter through service lift, fight through entrance hall
- Push up grand corridor under bass debris hazard
- Enter concert hall from south, fight amp operators
- Engage boss on stage

### Route 2 — Backstage Sabotage (Stealth/Technical)
- Enter grand corridor, take west gap into backstage tunnels
- Avoid cable fiend patrols
- Find hatch to soul battery vault
- Destroy all 4 soul battery cradles (disables boss regeneration)
- Emerge from backstage directly onto stage platform flank
- Engage weakened boss

### Route 3 — VIP Lounge + Catwalk (Mixed)
- Take east gap into VIP lounge
- Loot health pickup and lore documents
- Return to corridor, enter concert hall
- Use ladder to catwalks above
- Destroy amp stacks from elevated position (reduces boss damage)
- Drop down to engage boss

---

## Interactable Nodes

| interactable_id | Position | Purpose |
|---|---|---|
| quest_gate | (0, 1.05, 12) | Entrance gate — only opens if `quest_rocker_fellar_active` is true |
| bass_debris_warning | (0, 0.95, -10) | Lore: explains the ceiling collapse mechanic |
| vip_lore_contract | (12, 0.95, -10) | VIP lounge: Fellar's harvesting contract with Gatebox Corporation |
| vip_health_cache | (8, 0.95, -12) | Health pickup in VIP lounge |
| backstage_cage_evidence | (-12, 0.95, -10) | Lore: cages used for holding harvest victims |
| backstage_hatch | (-10, 0.05, -14) | Opens passage to soul battery vault below |
| soul_battery_1 | (-4, -1.55, -50) | Destroy to weaken boss regen (flag: fellar_battery_1_destroyed) |
| soul_battery_2 | (4, -1.55, -50) | Same (flag: fellar_battery_2_destroyed) |
| soul_battery_3 | (-4, -1.55, -52) | Same (flag: fellar_battery_3_destroyed) |
| soul_battery_4 | (4, -1.55, -52) | Same (flag: fellar_battery_4_destroyed) |
| amp_stack_n1 through amp_stack_n4 | Along north concert hall walls | Destroy to reduce boss sonic damage |
| amp_stack_s1 through amp_stack_s4 | Along south concert hall walls | Same |
| extraction_lift | (0, 1.05, -48) | Unlocks after boss defeat; returns to Faded Atrium |

---

## Enemies

### Corridor Enemies (spawned in `_ready()`)

| Position | Type | Notes |
|---|---|---|
| (-3, 0, 4) | Goon Material | Entrance hall guard |
| (3, 0, 4) | Goon Material | Entrance hall guard |
| (-2, 0, -6) | Goon Material | Corridor patrol |
| (2, 0, -12) | Goon Material | Corridor patrol |
| (0, 0, -16) | Cable Fiend | Near corridor/concert junction |

### Concert Hall Enemies (spawned in `_ready()`)

| Position | Type | Notes |
|---|---|---|
| (-12, 0, -26) | Amp Stack Operator | North-west stack |
| (-12, 0, -30) | Amp Stack Operator | |
| (12, 0, -26) | Amp Stack Operator | North-east stack |
| (12, 0, -30) | Amp Stack Operator | |

### Backstage Enemies (spawned in `_ready()`)

| Position | Type | Notes |
|---|---|---|
| (-12, 0, -8) | Cable Fiend | Patrol |
| (-8, 0, -12) | Cable Fiend | Patrol |

### Battery Vault Enemy

| Position | Type | Notes |
|---|---|---|
| (0, -1.55, -51) | Soul Warden | Guards batteries |

### Boss

| Position | Type | Notes |
|---|---|---|
| (0, 1.8, -44) | Rocker Fellar | On stage platform |

### Blood Pit Horrors (spawned during boss fight)

Spawned at (random x in -6..6, -0.5, random z in -36..-32) from the blood pit during boss phase transitions. 2 horrors per spawn wave. Max 6 alive at once.

---

## Boss Fight Mechanics

### Regeneration

Rocker Fellar regenerates 3 HP/sec on all non-destroyed parts while `fellar_regen_active` is true. Regen disables when all 4 soul batteries are destroyed. Partial regen reduction: each battery destroyed reduces regen by 0.75 HP/sec.

### Phase Transitions

- Phase 2 triggers when Jaw Amplifier OR Soul Resonator reaches 0 HP
- Phase 3 triggers when 3+ parts are destroyed
- Phase 4 triggers when Stage Core reaches 0 HP

### Sonic Attack (Phase 1)

Every 3 seconds while on stage: fires a shockwave cone from the stage toward the player. 8 damage. Blocked by amp stacks (player can hide behind intact stacks).

### Cable Whip Lash (Phase 2+)

Melee sweep attack. 12 damage. Used when player is within 3 units.

### Charge (Phase 3)

Boss charges toward player. On impact: 18 damage + 1.5 sec stun. During 2 sec recovery after charge, Stage Core is exposed from behind (lock difficulty drops to 0.8).

### Blood Pit Spawns

During phase 2 and 3, every 15 seconds: spawn 2 Blood Pit Horrors from the orchestra pit. These are weak (10 HP each) but swarm the player and interrupt targeting.

---

## EventDeckSystem Cards (add to WorldDirector.NAMED_CARDS)

```gdscript
"rocker_fellar_exit": {
    "id": "rocker_fellar_exit",
    "title": "Deep Lift",
    "contexts": ["district_exit"],
    "weight": 3,
    "conditions": {"flag_true": "quest_rocker_fellar_active"},
    "effects": [],
    "expires_after": 1,
    "tags": ["rocker_fellar"],
    "speaker": "System X",
    "text": "The service lift goes deep. Fellar's fortress is built inside an old performance complex that the Big Gates Foundation repurposed into a soul-processing venue. The acoustics are intentional. Bring ear protection and a healthy disrespect for authority.",
},

"rocker_fellar_return": {
    "id": "rocker_fellar_return",
    "title": "General Down",
    "contexts": ["hub_return"],
    "weight": 5,
    "conditions": {"flag_true": "rocker_fellar_defeated"},
    "effects": [
        {"type": "set_flag", "flag": "quest_rocker_fellar_complete", "value": true},
        {"type": "add_rep", "faction": "System X", "amount": 3},
        {"type": "add_rep", "faction": "Gatebox Corporation", "amount": -2},
    ],
    "expires_after": 0,
    "tags": [],
    "speaker": "System X",
    "text": "Rocker Fellar is offline. His soul batteries are empty. The contract ledger you found links Big Gates procurement to Gatebox Corporation logistics and Wan Moa Torai debt collection. This is not a small thing. This is the first crack in the foundation.",
},
```

---

## GameState Flags

```gdscript
"quest_rocker_fellar_active"          # set on quest accept
"quest_rocker_fellar_complete"        # set on return to hub after defeat
"rocker_fellar_defeated"              # set on boss defeat in level
"fellar_battery_1_destroyed"          # soul battery cradles
"fellar_battery_2_destroyed"
"fellar_battery_3_destroyed"
"fellar_battery_4_destroyed"
"fellar_amp_stacks_destroyed"         # set when all 8 amp stacks are down
"fellar_vault_opened"                 # set when backstage hatch is used
"fellar_contract_recovered"           # set when VIP lounge lore is read
```

---

## Loot Table

| Source | Item | Notes |
|---|---|---|
| Entrance hall crate | Random ammo + 1 random consumable |  |
| VIP lounge | Gatebox Eye MK1 Upgrade Chip (if not already installed) or Wan Note x5 |  |
| VIP lounge lore | Fellar's Contract Ledger | Quest item; links Big Gates to Gatebox Corp and Torai |
| Backstage cage | Scrap Pistol Mod: Bass Dampener (reduces sonic damage by 25%) |  |
| Each soul battery | Soul Residue x2 | Crafting/sell item |
| Boss defeat | Fellar's Jaw Amplifier | Unique cybernetic: melee attacks emit a sonic pulse that staggers nearby enemies |
| Boss defeat | General's Insignia | Proof of kill; triggers world state change |
| Concert hall loot (post-boss) | Random weapon mod + 3x random consumable |  |

---

## Visual Targets

- Entrance hall: cracked white marble floor, gold-trimmed walls, dim amber chandeliers, bass-vibration dust particles
- Grand corridor: blood-red carpet over steel grating, spinal-column chandeliers, periodic ceiling debris (dust warning → rock fall)
- VIP lounge: velvet wreckage, overturned bar counter, soul-fluid stains on couches, warm orange light
- Backstage: industrial concrete, exposed cables, iron cage bars, cold fluorescent flicker
- Concert hall: massive dark space, stage lit by red/purple spotlights, blood pit glowing sickly red, amp stacks with orange warning lights, catwalks with blue industrial lights
- Soul battery vault: rows of glowing green soul batteries, chrome cradles, humming ambient, green fog at floor level
- Boss: chrome and leather, bass-frequency jaw, open chest cavity with pulsing soul tubes, cable-whip arms, stage presence

---

## Implementation Notes

- Single script `RockerFellarKeep.gd` builds all geometry in `_ready()`
- Boss is a custom scene `scenes/enemies/RockerFellar.tscn` extending the Enemy base with additional phase logic
- Blood Pit Horrors use the existing Goon Material scene with reduced HP and faster move speed
- Amp Stack Operators use Security Node scene (stationary ranged)
- Cable Fiends use Enemy scene with whip-arm body parts
- Soul Wardens use Enemy scene with suppression arm that stuns instead of dealing damage
- Catwalk ladders use LadderZone pattern from SubSubBasementDistrict
- Bass debris hazard uses periodic timer + falling MeshInstance3D + Area3D damage zone
- All loot is handled via WardInteractable dispatch like existing job locations
- Boss defeat sets `rocker_fellar_defeated` flag; extraction lift checks this flag before allowing use
- Destroying all 4 soul batteries sets individual flags and reduces boss regen
- Destroying all 8 amp stacks sets `fellar_amp_stacks_destroyed` and reduces boss sonic damage

---

## Acceptance Tests

- Launch `RockerFellarKeep.tscn` with no debug errors
- Walk from service lift to concert hall without hitting invisible walls
- Complete Route 2 (backstage sabotage): reach soul battery vault, destroy all 4 batteries
- Boss fight transitions through all 4 phases correctly
- Body part consequences work: destroying jaw silences sonic attack, destroying whips disables melee, destroying spine slows boss
- Blood pit horrors spawn during boss phases, max 6 alive at once
- Boss regen reduces as batteries are destroyed; stops when all 4 are down
- Loot drops are collectable after boss defeat
- Extraction lift works only after boss is defeated
- All flags persist through save/load
- Re-run `MallHub.tscn` after the level pass
