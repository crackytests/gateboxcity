# GATEBOX BREACH — Project Context

## Engine
- **Redot 4** (Godot 4 fork, API-compatible with Godot 4.x)
- GDScript only (no C#)
- Forward+ renderer
- 1280x720 viewport

## Project Structure
```
project.godot              — Engine config (Redot 4, autoloads: GameState, WorldDirector)
scenes/
  player/Player.tscn       — First-person player scene
  enemies/                 — GoonMaterial, SecurityNode, RainMutant enemies
  weapons/ScrapPistol.tscn — Starting weapon
  levels/                  — MallHub (Faded Atrium hub), SubSubBasementDistrict (free-roam),
                             Test_SubSubBasement (Wake-Up Call mission), LindaSpire, SpireLobby,
                             CorporateTransit, CompanionCore, ExecutiveSuite, FinalPatch,
                              PacificationWard, CootersInterior
  ui/HUD.tscn              — Targeting reticle, hit chance, body-part label, world-state display
scripts/
  player/                  — PlayerController (FPS movement/mouselook), PlayerHealth, PlayerTargeting (raycast + reticle closure)
  combat/                  — Weapon (hitscan fire, ammo, reload, recoil, body-part damage via PlayerTargeting)
  enemies/                 — Enemy (AI chase/attack, body-part consequences), SecurityNode, BodyPart, DirectionalBillboard, EnemyTalkZone, DistrictNPC, RainMutant
  systems/                 — GameState (save/load autoload), WorldDirector (region/event/generator state autoload),
                             QuestSystem, FactionSystem, InventorySystem, NPCDialogue,
                             ToxicRainController, ShelterZone, GeneratorNode, LootPickup,
                             UpgradeStation, WardInteractable, MissionExit, LevelDresser
  data/                    — BodyPartData, WeaponData (Resource scripts)
  ui/                      — HUDController, TargetingReticle
data/
  body_parts/              — .tres files for goon head/torso/arms/legs (HP, targeting penalty, lock difficulty, armor)
  weapons/                 — scrap_pistol.tres (14 kinetic damage, 12 mag, 48 reserve, 0.5 lock retention)
  npcs/                    — npc_cast.yaml (17 canonical NPC definitions with Stable Diffusion prompts)
assets/
  sprites/weapon/          — scrap_pistol_view.png, scrap_pistol_fire.png
  sprites/greenline/       — LX-02 Greenline character: 8-direction sprites in base/alt/cutout/card variants
  sprites/kiki_baja/       — Kiki Baja smuggler sprites
  sprites/marbles/         — Bunny Unit C-11 Marbles sprites
docs/
  gatebox_game_design_doc_for_codex.md  — Master GDD (1600 lines)
  billboard_sprite_reference.md          — 2D billboard sprite technical reference
  sub_sub_basement_buildout_plan.md      — Current sprint buildout plan
```

## Autoloads
- `GameState` — Persistent save/load singleton (items, faction rep, quests, world flags, implants → user://gatebox_save.json)
- `WorldDirector` — Runtime world state (region, world event, generator state, hazard rates, signals to HUD)

## Signature Mechanic: Reticle Closure Targeting
1. Player aims at enemy → `PlayerTargeting` raycasts from camera center
2. Detects `BodyPart` Area3D nodes (Head, Torso, L/R Arm, L/R Leg)
3. `lock_ratio` increases while holding aim on same body part, decays when aim leaves
4. HUD shows hit chance % as reticle closes
5. On fire, `Weapon` rolls against current hit chance
6. Hit → `BodyPart.apply_damage()` → destruction triggers consequences:
   - Leg destroyed → enemy slows
   - RightArm destroyed → enemy ranged attack disabled
   - Head/Torso destroyed → enemy defeated

## Art Direction
- 2D billboard sprites in 3D environments (`Sprite3D`/`AnimatedSprite3D`, nearest-neighbor filtering)
- 8-direction directional sprites per character
- Dark corporate aesthetic: vertical slum bottom → pacification middle → corporate spire top

## Factions
- **System X** — Underground resistance / pro-human
- **Gatebox Corporation** — Corporate enforcers
- **Wan Moa Torai** — Debt-driven traders
- **Linda** — AI totalitarian care antagonist

## Current Sprint (Sub-Sub-Basement Buildout)
Building the Sub-Sub-Basement into a playable starting region:
- Faded Atrium (MallHub) hub
- Free-roam district with toxic rain, shelters, generators
- Establishments: Cooters, Suitors, Wan Moa Torai Office, Hoodlum LAN Den
- First jobs: Patch The Dreaming Generator, One More Try, LAN Party Brownout
- Protection items: Cheap Poncho (halves rain), Sealed Mask (blocks rain), Chemical Neutralizer

## Key Design Rules
- Reticle closure targeting is the signature mechanic — never simplify it
- Body parts are real gameplay targets, not cosmetic labels
- UI must show percentile hit chance as reticle closes
- City feels vertical: slum bottom, pacification middle, corporate top
- Mall of the Future is the safe hub (currently Faded Atrium placeholder)
- Linda's totalitarian care logic drives antagonist philosophy
- 13 Generals provide boss structure
- Scavenging and repurposing weird objects is central to progression
- Choices affect faction reputation and event deck/world state

## GDScript Conventions
- Godot 4 syntax (`@export`, `@onready`, signals with `signal` keyword)
- `class_name` used for Resource types (BodyPartData, WeaponData)
- Resources (.tres) store data; scripts reference them via `@export`
- Keep code modular and readable before art polish
- Enemy scenes use body-part Area3D children
- Use `Signal` for inter-system communication (e.g., `world_state_changed`, `inventory_changed`)

## Godot MCP
The project uses a Godot MCP server to let the agent inspect scenes, create nodes, attach scripts, and validate scenes without launching the editor manually. After mechanical changes, validate by launching scenes through MCP and checking for errors.
