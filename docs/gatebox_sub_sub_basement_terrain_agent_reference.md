# GATEBOX BREACH — Sub-Sub Basement Terrain Design Reference

Clean-room design brief for level-building agents. This document distills broad terrain-design patterns from a tabletop hive-wasteland source into original guidance for a post-apocalyptic immersive-sim / dungeon-crawler game set in the **Sub-Sub Basement of Gatebox Mega City One**. Do not copy names, factions, text, rules, or branded lore from the source. Use this as an interaction vocabulary and level-layout checklist.

## Core Terrain Philosophy

Terrain in the Sub-Sub Basement should not be decoration. Every major piece should do at least one of these jobs:

1. **Navigation** — creates routes, shortcuts, vertical paths, alternate entries, crawlspaces, ladders, lifts, ducts, service tunnels.
2. **Combat Shape** — provides cover, line-of-sight blockers, chokepoints, flanking paths, ambush pockets, exposed bridges, sniper perches.
3. **Hazard** — reacts to player/enemy actions, leaks, bursts, smokes, explodes, collapses, shocks, poisons, grabs, blocks vision.
4. **Resource** — can be looted, tapped, repaired, hacked, dragged, harvested, refueled from, used for healing, used as ammo, or salvaged.
5. **Objective** — gives the room a reason to exist: retrieve, escort, disarm, restart, purge, hack, secure, steal, repair, sacrifice, extract.
6. **World Signal** — reveals who used to own this space, who controls it now, what failed, and what threat is coming next.

A good Sub-Sub Basement level should feel like a broken living machine: pipes, vents, false-sky panels, water reclamation, dead malls, abandoned service corridors, corporate shrine rooms, slum repairs, and mutated ecosystems all fighting over the same floorplan.

## Visual Pillars

Use these motifs repeatedly, but vary density by room type:

- **Wet industrial decay:** leaking pipes, condensation, oily puddles, rust halos, peeling warning paint, cracked acrylic, dripping ceilings.
- **Corporate afterimage:** elegant mall finishes buried under salvage wiring, broken kiosks, false-daylight panels, dead ad displays, luxury materials repurposed as barricades.
- **Patchwork survival:** community generator rigs, stolen conduits, tarps, battery shrines, hand-painted warning marks, scavenger ladders, welded scrap walkways.
- **Predatory infrastructure:** machinery that still moves, vents that breathe, doors that misread biology, cameras that twitch, utility systems that punish trespassers.
- **Bio-tech overgrowth:** fungal mats, carnivorous plants, root cables, mycelium around data lines, flesh-colored slime on old service machines.
- **Vertical claustrophobia:** catwalks over sludge, gantries above plant-choked pits, stacked maintenance decks, collapsed floors exposing deeper levels.

## Level Composition Targets

For each playable level chunk, try to include:

- 1 central identity: e.g. flooded pump hall, generator chapel, dead food court, broken sky-atrium, trash refinery, service market, corpse-cold storage, fungal loading dock.
- 2–3 major traversal layers: ground, raised catwalk, duct/crawlway, flooded trench, collapsed subfloor, elevator shaft, maintenance mezzanine.
- 2 major interactable terrain systems.
- 1 optional high-risk/high-reward object.
- 1 obvious safe route and 1 dangerous shortcut.
- 1 object that can help the player and hurt them if mishandled.
- 1 environmental storytelling setpiece visible from multiple angles.

## Terrain Tags for Procedural / Agent Use

Use these tags in room metadata, encounter scripts, or generation prompts.

```yaml
terrain_tags:
  traversal:
    - hatch_network
    - maintenance_duct
    - gantry
    - ladder
    - cargo_hook
    - broken_lift
    - crawlspace
    - flooded_low_route
    - collapsed_floor
  cover:
    - half_cover_scrap
    - full_cover_container
    - destructible_cover
    - movable_cover
    - transparent_cover
    - unstable_cover
  hazard:
    - smoke_vent
    - toxic_air
    - flammable_gas
    - plasma_conduit
    - fuel_pipe
    - electric_grid
    - pressure_burst
    - unstable_floor
    - ordnance
    - carnivorous_plant
    - spore_cloud
    - sludge_pool
  utility:
    - control_panel
    - loot_container
    - med_station
    - comms_relay
    - force_gate
    - salvage_machine
    - water_still
    - generator_core
  objective:
    - disarm
    - hack
    - repair
    - retrieve
    - drag_extract
    - restart
    - purge
    - escort
    - holdout
    - route_unlock
```

## Interactive Terrain Archetypes

### 1. Service Hatches / Crawlway Network

**Purpose:** shortcuts, ambush routes, stealth repositioning, risky navigation.

**Gatebox version:** rusted service hatches, mall maintenance crawlspaces, old mascot tunnels, drainage ducts, utility coffin-tubes, broken delivery chute network.

**Use cases:**

- Connect distant room edges without making an obvious hallway.
- Let small enemies flank the player.
- Let stealth builds bypass open firefights.
- Hide loot, bodies, old recordings, or faction graffiti.
- Create uncertainty: the network may lead somewhere useful, somewhere dangerous, or into an enemy nest.

**Agent placement rules:**

- Put at least two exits in the same encounter zone; three is better.
- Never make a hatch network the only critical path unless the player has already learned it is safe.
- Pair with sound cues: scraping, fans, dripping, distant voices.
- Use narrow collision and low ceilings to make the route feel risky.
- Add a failure state that is not instant death: wrong exit, noise event, spore exposure, enemy notice, minor fall, temporary darkness.

### 2. Smoke Vents / Exhaust Stacks

**Purpose:** dynamic line-of-sight blocking, temporary denial zones, stealth opportunities, breathing hazards.

**Gatebox version:** food court grease vents, generator exhaust stacks, coolant purge chimneys, broken climate-control towers, Linda Corp aromatherapy vents gone toxic.

**Behavior design:**

- Periodically emit smoke, steam, ash, poison, or hot vapor.
- During active emission, block vision and reduce ranged accuracy.
- Some emissions slow movement, drain stamina, or require respirator gear.
- Flammable vent clouds can turn fire weapons, sparks, or explosions into area hazards.

**Agent placement rules:**

- Place vents near chokepoints, not randomly in empty corners.
- Give the player visual buildup before venting: blinking light, rising hiss, shaking cap, pressure gauge.
- Pair with alternate routes so the vent changes the best route instead of simply stopping progress.
- Let hacking, valve wheels, or damaged control panels toggle vent timing.

### 3. Cargo Hooks / Industrial Claws

**Purpose:** vertical traversal, object movement, environmental attacks, rescue tools.

**Gatebox version:** ceiling cargo claws, mall freight hooks, meat locker rails, store-display rigging, trash compactor grabbers, broken delivery drones tethered to rails.

**Behavior design:**

- Functions as a climb point, zip point, lift, pulley, or moving platform.
- Can move crates, bodies, loot, batteries, keys, or wounded NPCs.
- Can be dropped as a trap if the player activates it at the right moment.
- Can create loud noise that changes patrol behavior.

**Agent placement rules:**

- Put hooks above visible lower-level targets or desirable loot.
- Make the vertical line readable from the floor.
- Give at least one non-combat use before expecting the player to use it offensively.
- Do not rely on perfect timing unless the attack is optional.

### 4. High-Energy Conduits

**Purpose:** dangerous cover, light source, power puzzle, explosive chain reaction.

**Gatebox version:** plasma conduits, neon transformer banks, false-sky power trunks, server-cooling tubes, unstable GateBox display-core cables, System X generator arteries.

**Behavior design:**

- Emits harsh light in dark areas.
- Disrupts night vision, thermal optics, sensors, or targeting assistance.
- If damaged enough, erupts in a cone, sphere, or line burst.
- Can power doors, lifts, force gates, pumps, signs, cameras, or traps.

**Agent placement rules:**

- Treat as tempting cover: useful, but dangerous when shot.
- Put near enemy firing lanes so stray fire can trigger it.
- Provide visual warning: glow, hum, heat shimmer, corona arcs, melted floor.
- Use sparingly; high-energy bursts should feel dramatic.

### 5. Fuel Lines / Reservoirs

**Purpose:** volatile environmental weapon, slipping hazard, refueling station, fire-risk puzzle.

**Gatebox version:** generator diesel lines, old cooking-oil tanks, chemical fuel bladders, prom-night fountain pumps repurposed as fuel stores, stolen slum heat lines.

**Behavior design:**

- When ruptured, sprays fluid, blinds cameras/characters, coats floors, or creates slicks.
- If ignited, becomes flame jet, burning puddle, or temporary wall of fire.
- Fire-based weapons can refill or gain extra use near certain reservoirs.
- Leaks can spread downhill or through floor grates.

**Agent placement rules:**

- Put fuel near routes enemies use, not only beside loot.
- Combine with environmental ignition sources: sparks, cooking fires, broken neon, laser traps.
- Make fuel visually distinct from water and sludge.
- Add shutoff valves or control panels for careful players.

### 6. Control Panels / Terminals

**Purpose:** make the environment hackable and readable.

**Gatebox version:** cracked mall directories, service tablets, biometric door plates, System X maintenance nodes, Linda Corp customer-service kiosks, analog fuse boards.

**Behavior design:**

A terminal should do one or more of these:

- Trigger nearby machinery.
- Shut down a hazard temporarily.
- Change vent timing.
- Open a hatch or gate.
- Rotate a crane.
- Drain or flood a room.
- Reveal a map layer.
- Wake dormant security.
- Print corrupted lore.

**Agent placement rules:**

- Put panels close enough to see their connected machine, or draw a visible cable between them.
- Reward technical builds with safer routes, extra salvage, or hazard control.
- Failed hacks should create interesting trouble: alarm, shock, reboot delay, wrong machine starts, temporary lights-out.
- Avoid generic terminals that only dump text. Every terminal should affect the level or give actionable information.

### 7. Ruined Relics / Corporate Shrines

**Purpose:** mood, faction identity, buffs/debuffs, loot landmarks, social storytelling.

**Gatebox version:** broken GateBox demo shrine, Yoko customer-care altar, CEO Linda standee, System X memorial terminal, dead luxury fountain, mall mascot statue, old streamer merch kiosk, security trophy wall.

**Behavior design:**

- May calm friendly NPCs, intimidate enemies, or alter AI morale.
- May be valuable salvage if extracted.
- May mark territory or function as a hidden faction checkpoint.
- May contain old messages, power cells, keys, or traps.

**Agent placement rules:**

- Place at sightline anchors: end of hallway, center of plaza, above stairs, behind boss arena.
- Make relics readable from silhouette alone.
- Use them to establish the room’s past life before decay.

### 8. Ancient / Corrupted Terminals

**Purpose:** high-risk lore and resource extraction.

**Gatebox version:** pre-collapse mall servers, cached AI backups, broken tenant database, dead security archive, System X orphan node, Linda pre-CEO legal console.

**Behavior design:**

- One-time interaction.
- Can grant map info, currency, reputation, XP, crafting recipe, faction intel, or secret route.
- Can also trigger enemies, false memories, corrupted UI, or a lockdown.

**Agent placement rules:**

- Put in side rooms, exposed central offices, or behind partial hazards.
- Make success feel like stealing from a dead god-machine.
- Use as optional reward, not mandatory exposition.

### 9. Abandoned Haulers / Cranes / Utility Vehicles

**Purpose:** movable terrain, crushing hazards, route creation, cover repositioning.

**Gatebox version:** cargo mule, store-delivery robot, broken escalator maintenance rig, forklift drone, trash hauler, corpse-cart, vending-machine pallet jack.

**Behavior design:**

- Can be hacked or repaired to move.
- Can carry player, NPC, loot, battery, or obstruction.
- Can be driven into enemies, through weak walls, or off ledges.
- Can become mobile cover.

**Agent placement rules:**

- Put one obvious obstacle it can solve.
- Give enough turning space.
- Let enemies react to it as a threat.
- Avoid making it required unless controls are simple and robust.

### 10. Med Stations / Repair Stations

**Purpose:** recovery point with risk, pacing valve, faction flavor.

**Gatebox version:** emergency clinic kiosk, android repair chair, vending-machine pharmacy, mall first-aid pod, backroom auto-surgeon, slum cyberdoc rig.

**Behavior design:**

- Can heal, stabilize, restore limb function, repair modules, or remove toxins.
- May require power, coolant, sterile fluid, or a hacking check.
- Failure can worsen injury, add infection, attract enemies, or consume rare supplies.

**Agent placement rules:**

- Place after a hard route or before a boss-like encounter.
- Signal whether it is safe, dirty, or corrupted.
- Do not overuse; a med station should feel valuable.

### 11. Comms Relays / Signal Boosters

**Purpose:** command, scouting, remote activation, faction systems.

**Gatebox version:** emergency broadcast antenna, mall PA relay, streamer booth uplink, Yoko customer-service node, System X mesh repeater.

**Behavior design:**

- Extends remote control range.
- Allows squad/NPC coordination.
- Reveals enemy positions or patrol paths.
- Lets the player call elevator, open shutters, trigger decoys, or contact factions.

**Agent placement rules:**

- Put near high ground or exposed service balconies.
- Make it useful before combat starts.
- Let enemies disable or guard it.

### 12. Force Gates / Energy Barriers

**Purpose:** conditional cover, route gating, combat geometry, stealth puzzle.

**Gatebox version:** hardlight storefront shutters, security pylons, laser curtain, anti-riot field, broken VIP gate, Linda Corp display-wall shield.

**Behavior design:**

- Blocks or weakens shots through it.
- May protect both player and enemies.
- Can overload, flicker, reverse, or shut down from linked panels.
- Can create a temporary safe lane across exposed ground.

**Agent placement rules:**

- Always show the two endpoints or source emitters.
- Avoid invisible logic; players should understand why the barrier exists.
- Allow at least two solutions: hack, destroy power, go around, bait enemy fire, find maintenance hatch.

### 13. Forgotten Ordnance / Unstable Bombs

**Purpose:** time pressure, disarm objective, area denial, dramatic escalation.

**Gatebox version:** buried security charge, abandoned demolition pack, swollen battery bank, unstable fusion vending machine, old riot drone warhead.

**Behavior design:**

- Starts inert or slowly escalating.
- Each turn/minute/noisy event increases risk.
- Player can disarm, drag, shield behind cover, or weaponize it.
- Explosion should affect a meaningful area and change the room afterward.

**Agent placement rules:**

- Use 0–2 per level chunk.
- Put near the center of conflict, not hidden in a random corner.
- Give readable ticking, heat, flashing, audio, or UI warning.
- Let clever players turn it into a solution.

### 14. Loot Containers / Salvage Lockers

**Purpose:** reward, trap, repeatable scavenging point, sound bait.

**Gatebox version:** sealed mall stockroom crates, emergency lockers, machine-part bins, vending machines, courier pods, display cases, shipping containers.

**Behavior design:**

- Can contain supplies, keys, components, weapons, faction items, lore scraps.
- May be trapped, noisy, jammed, irradiated, or guarded by pests.
- Large containers can be looted repeatedly but may take time.
- Some containers cannot move; some can be dragged.

**Agent placement rules:**

- Put loot where it changes player route choice.
- Make high-value loot visible but costly.
- Use traps sparingly; do not make every crate suspicious.

### 15. High-Value Targets

**Purpose:** optional objective that generates emergent conflict.

**Gatebox version:** lost android body, rare generator core, celebrity GateBox prototype, still-living server seed, pure-water tank, slum mayor’s battery, Linda Corp black box.

**Behavior design:**

- Heavy object or vulnerable NPC/object that must be dragged, escorted, powered, repaired, or extracted.
- Located centrally or equidistant from competing routes.
- Taking it changes enemy behavior or triggers pursuit.
- Reward should be large enough to justify risk.

**Agent placement rules:**

- Make the target visible early.
- Provide multiple extraction paths.
- Make carrying/dragging it alter movement, weapon use, or stealth.
- Add at least one environmental shortcut that specifically helps extraction.

## Biohazard / Mutant Plant Terrain

Use plant-like terrain as active enemies that occupy space rather than as ordinary monsters. These hazards should make the player think about distance, timing, fire, and route choice.

### A. Snare Growth

**Role:** proximity trap, immobilizer, poison source.

**Appearance:** thorn curtains, cable-vines, pink meat-flowers, wire roots, mall planter boxes turned predatory.

**Behavior:**

- Triggers when the player or NPC moves too close.
- Applies grab, slow, poison, stamina drain, or temporary stat reduction.
- Can punish sprinting through overgrowth.
- Fire, acid, cutting tools, or careful hacking of root-cables can clear it.

**Placement:**

- Around loot, alternate routes, and quiet flank paths.
- Near low visibility, but with enough silhouette/readability to feel fair.
- Combine with enemies that try to shove or lure the player into it.

### B. Spine Growth

**Role:** ranged hazard and area denial.

**Appearance:** glassy needle bushes, bone-like shards, shattered display acrylic that regrows, crystalline fungus.

**Behavior:**

- Shoots or bursts spines at nearby movement/noise.
- Cuts armor or bypasses normal cover if too close.
- Can create risk when firing guns nearby.
- Can be used against enemies by baiting them through its range.

**Placement:**

- On edges of arenas, not in every path.
- Beside long sightlines to break sniper dominance.
- Near noisy machines or alarm zones.

### C. Crawling Weed / Mobile Plant Cluster

**Role:** slow environmental pursuer.

**Appearance:** uprooted planter colony, carpet of cable-vines, shopping-mall decorative ivy fused with cleaning robots.

**Behavior:**

- Moves toward the nearest warm/noisy/bleeding target at intervals.
- Attacks anything within short reach.
- Ignores many normal terrain penalties but respects hard walls.
- Can reshape the fight by making camping unsafe.

**Placement:**

- In large rooms, arenas, flooded halls, or long holdout sequences.
- Avoid tight corridors unless the goal is panic.
- Pair with fire sprinklers, fuel slicks, or doors so the player has counterplay.

### Plant Destruction Rule of Thumb

Plants should not die to casual bullets unless the game’s weapon model requires it. Prefer specific counters:

- fire
- acid
- industrial cutting tools
- herbicide canisters
- coolant shock
- generator overload
- environmental crushing

This makes plant terrain a level puzzle rather than just another health bar.

## Terrain Interaction Patterns

### Risky Cover

Cover should sometimes be a liability. Examples:

- Fuel drum: great cover until shot.
- Power conduit: blocks bullets but arcs electricity.
- Glass storefront: hides silhouette but shatters loudly.
- Old vending machine: cover plus loot, but may explode or alarm.
- Plant wall: blocks sight, but grabs anything too close.

### Environmental Soft Locks

A hazard can temporarily close a route without hard-locking the player:

- smoke cloud blocks aim
- vent heat blocks safe passage
- slick floor makes charging risky
- energy barrier flickers on cycle
- plant growth slowly crosses the route
- flooded trench becomes electrified until power is cut

### Player-Triggered Chaos

Let the player deliberately destabilize the room:

- shoot pipe to blind enemies
- ignite fuel to block pursuit
- trigger claw to drop cargo
- hack vent to smoke a camera
- drive hauler through a barricade
- overload false-sky panel to stun creatures
- open sluice gate to wash enemies into lower pit

### Linked Systems

Every complex room should have at least one visible relationship:

```yaml
linked_system_examples:
  - panel_controls_vent
  - valve_controls_fuel_leak
  - generator_powers_barrier
  - relay_controls_security_door
  - crane_moves_container
  - pump_changes_water_level
  - false_sky_panel_powers_plant_growth
  - comms_relay_summons_or_delays_faction_patrol
```

## Level Recipes

### Recipe 1: Generator Chapel

```yaml
identity: slum power shrine built around a stolen generator
primary_spaces:
  - nave_like_generator_room
  - side_maintenance_balcony
  - flooded_cable_crypt
  - backroom_control_cell
terrain_systems:
  - high_energy_conduits
  - control_panels
  - cargo_hooks
  - risky_cover_fuel_drums
hazards:
  - electrical_arcs
  - fuel_slicks
  - smoke_vent
objectives:
  - restart_generator
  - steal_power_core
  - defend_technician
encounter_shape:
  - enemies hold balcony
  - player can crawl through cable crypt to flank
  - shooting conduits creates temporary light burst and danger zone
visual_notes:
  - candles made from battery cells
  - warning icons painted by hand
  - corporate marble under rust and soot
```

### Recipe 2: Dead Food Court Overgrown by Bio-Mall Flora

```yaml
identity: ruined mall food court turned fungal ecosystem
primary_spaces:
  - open_seating_pit
  - upper_fast_food_ring
  - kitchen_service_tunnels
  - broken_false_sky_ceiling
terrain_systems:
  - snare_growth
  - spine_growth
  - smoke_vents
  - loot_containers
hazards:
  - spore_clouds
  - slippery_grease_puddles
  - crawling_weed_cluster
objectives:
  - retrieve_pure_water_filter
  - burn_out_growth_node
  - rescue_scavenger
encounter_shape:
  - safe path is slow around upper ring
  - fast path crosses plant-choked seating pit
  - kitchen tunnel bypass hides enemies and loot
visual_notes:
  - menu boards still glowing through fungus
  - plastic plants replaced by real predators
  - tables welded into barricades
```

### Recipe 3: Collapsed Service Atrium

```yaml
identity: vertical mall atrium collapsed into maintenance decks
primary_spaces:
  - exposed_ground_floor
  - hanging_catwalks
  - elevator_shaft
  - security_kiosk
  - subfloor_sludge_gap
terrain_systems:
  - gantries
  - hatch_network
  - force_gates
  - comms_relay
hazards:
  - unstable_floor
  - long_fall
  - toxic_sludge
  - flickering_energy_barriers
objectives:
  - cross_to_exit
  - activate_relay
  - extract_high_value_target
encounter_shape:
  - enemies watch from upper catwalk
  - player can hack barrier to create temporary safe lane
  - hatch route bypasses central atrium but exits near plant hazard
visual_notes:
  - hanging escalators
  - dead luxury banners
  - rain from broken pipes into black lower gap
```

### Recipe 4: Water Reclamation Cistern

```yaml
identity: flooded under-mall utility reservoir controlled by scavengers
primary_spaces:
  - cistern_walkway_ring
  - pump_control_room
  - underwater_pipe_maze_implied
  - filter_bed_platforms
terrain_systems:
  - valves
  - pumps
  - control_panels
  - med_or_repair_station
hazards:
  - electrified_water
  - pressure_bursts
  - toxic_air_pockets
  - leech_or_small_predator_nests
objectives:
  - drain_room
  - steal_filter_core
  - purify_settlement_supply
encounter_shape:
  - water level changes which routes exist
  - shooting pipes can create steam cover
  - enemies try to cut off pump access
visual_notes:
  - bottled-water shrine
  - old luxury fountain parts used as filters
  - condensation and algae over chrome
```

### Recipe 5: Unexploded Security Warhead Market

```yaml
identity: scavenger bazaar built around a buried bomb nobody can move
primary_spaces:
  - central_warhead_square
  - vendor_stalls
  - overhead_tarps_and_catwalks
  - barricaded_escape_routes
terrain_systems:
  - ordnance
  - loot_containers
  - force_gates
  - hatch_network
hazards:
  - countdown_escalation
  - panic_crowd_or_fleeing_npcs
  - flammable_stalls
objectives:
  - disarm_warhead
  - steal_target_item
  - escort_vendor
encounter_shape:
  - fighting increases risk
  - quiet route allows disarm approach
  - warhead can be weaponized but destroys loot
visual_notes:
  - prayer ribbons tied to bomb casing
  - marketplace painted around blast radius
  - old corporate safety hologram still repeating warnings
```

## Encounter Balance Guidelines

### Terrain Density

```yaml
density_by_space:
  small_room:
    major_interactables: 1
    hazards: 0-1
    cover_nodes: 2-4
    vertical_layers: 1
  medium_room:
    major_interactables: 2
    hazards: 1-2
    cover_nodes: 4-8
    vertical_layers: 1-2
  large_arena:
    major_interactables: 3-5
    hazards: 2-4
    cover_nodes: 8-14
    vertical_layers: 2-4
```

### Readability Rules

- The player should identify a hazard category before it triggers.
- Use color and motion language consistently: cyan = power, magenta = corrupted signal, sickly green = toxin/biohazard, orange = heat/fuel, white flicker = unstable old tech.
- Put warning props near hazards: dead rats, scorched walls, melted railing, warning paint, broken respirators, burnt silhouettes, cut cables.
- Make interactable machines visually distinct from background clutter.
- Every dangerous object should have at least one safe observation angle.

### Fairness Rules

- Avoid unavoidable instant-kill terrain.
- Give counterplay: dodge, hack, shoot, valve, alternate route, protective gear, lure enemies, wait for cycle.
- If a hazard is random, keep the consequence moderate.
- If a consequence is severe, make the warning strong and the trigger understandable.
- Do not stack more than two unfamiliar hazard types in a beginner room.

## Agent Room-Build Checklist

Before finalizing a generated room, verify:

```yaml
checklist:
  identity:
    - room_has_clear_past_function
    - room_has_clear_current_owner_or_ecology
    - room_has_one_memorable_silhouette
  navigation:
    - at_least_two_routes_through
    - at_least_one_flank_or_shortcut
    - verticality_used_if_room_is_large
    - player_can_retreat_or_reposition
  interactivity:
    - at_least_one_machine_or_object_can_be_used
    - at_least_one_hazard_can_be_turned_against_enemies
    - optional_reward_has_visible_risk
  combat:
    - cover_is_not_evenly_spaced_like_a_shooting_gallery
    - sightlines_have_interruptions
    - enemies_have_positions_that_make_sense
    - melee_and_ranged_builds_each_have_options
  atmosphere:
    - decay_tells_a_story
    - lighting_reinforces_hazard_readability
    - props_support_sub_sub_basement_lore
    - no_unexplained_clean_empty_spaces
```

## Prompt Template for Level-Building Agents

Use this when asking an agent to generate a room, blockout, or Godot/Redot scene.

```text
Create a playable level chunk for GATEBOX BREACH set in the Sub-Sub Basement of Gatebox Mega City One.

Room identity: [specific decayed mall/industrial function]
Current condition: [flooded / overgrown / burned / occupied / unstable / hacked]
Primary objective: [what the player is trying to do]
Secondary reward: [optional salvage, route, lore, NPC, high-value object]
Traversal layers: [ground / catwalk / duct / flooded trench / collapsed subfloor]
Interactive terrain systems: [choose 2-4 from this reference]
Hazards: [choose 1-3; include counterplay]
Enemy use of terrain: [how enemies exploit the space]
Player counterplay: [hack, valve, stealth, climb, lure, destroy, repair, reroute]
Visual anchor: [one unforgettable landmark]
Lore signal: [what this room reveals about Linda, Yoko, System X, scavengers, or the old mall]

Output:
- compact room summary
- top-down layout notes
- key props and interactables
- hazard behavior
- traversal routes
- encounter beats
- implementation notes for collision, triggers, and scripting
```

## Original Terrain System Names for This Project

Use these project-native names instead of source terms:

```yaml
project_terms:
  dangerous_industrial_terrain: reactive_hazard_prop
  service_hatches: sublevel_crawlway_nodes
  smokestacks: purge_vents
  industrial_claws: cargo_claw_systems
  plasma_pipes: high_energy_conduits
  promethium_pipes: fuel_lines
  control_panels: maintenance_terminals
  hive_ruins: dead_infrastructure_zones
  ancient_relics: corporate_afterimage_props
  medicae_station: auto_doc_or_repair_pod
  vox_relay: signal_relay
  force_barrier: hardlight_gate
  unexploded_ordnance: unstable_security_charge
  carnivorous_plants: predatory_growth
  barbed_plant: snare_growth
  spine_plant: spine_growth
  mobile_weed: crawling_growth
```

## Final Direction

The Sub-Sub Basement should feel like a battlefield between failed systems: corporate comfort, survival engineering, abandoned infrastructure, rogue AI maintenance, scavenger culture, and mutant ecology. Build levels where the player is not just moving through terrain, but negotiating with it, exploiting it, surviving it, and occasionally being betrayed by it.
