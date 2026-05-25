# Sub-Sub-Basement Buildout Plan

## Current Implementation State

- The current vertical slice is functional.
- `WorldDirector` exists and is autoloaded.
- HUD has world-state display.
- System X has replaced the old Resistance/Face faction language.
- MCP testing should be used after each mechanical step.
- World events auto-cycle every ~45 seconds when generator is not stable.
- Power sag dims generator, sky, and all zone lights in the district.
- Generator mesh material changes color per state (green/cyan/magenta/amber).
- Three shelter zones cover the pipe area, generator, and market.
- Seven structural pillars break up the district sight lines.
- District expanded to 44x40 units with 5 distinct zones.
- 7 ambient district NPCs with event-aware and faction-aware dialogue.
- LevelDresser provides runtime props for market stalls, LAN furniture, signage, and sky platforms.
- Establishments now have second-pass lightweight jobs after their first gear rewards.
- Cooters, Suitors, and Wan Moa Torai chain world-event errands into small rewards and quest flags.
- Cooters now escalates from rain sample into a rain-mutant containment encounter and unlocks a tiny Marbles interior.
- Velvet Coil's surgery menu now consumes district reward items and installs cybernetics with live gameplay effects.
- Suitors now has a tiny interior and a surveillance choir hack that maps a persistent blind spot.
- The district has been visually restructured as **Leak Street**, a specific patchwork settlement lane inside the larger Sub-Sub-Basement.
- Cooters now has a reusable job board, Marbles job hints/payouts, a Leak Street travel gate, and the first compact job destination: `PipeUtilityTunnels.tscn`.

## Ninth Sprint: Cooters Job Board, Travel Gate, and Pipe Utility Tunnels

### Status: Complete

- Added save-backed Cooters job state to `GameState`: active job, available jobs, completed jobs, and job flags.
- Added `JobBoardUI` to the HUD and a Cooters job board interactable inside `CootersInterior.tscn`.
- Marbles now points the player to the board, explains the active job, and pays out completed job objectives.
- Added a `TravelGateUI` route picker and a Leak Street travel gate at the district exit.
- Added `WorldDirector.roll_travel_event(route_id)` with clear, toxic rain, power sag, LAN outage, and quiet shortcut cards.
- Added `PipeUtilityTunnels.tscn` as the first compact destination with three job objectives, a shelter nook, a toxic rain leak, an upper pipe path, and a security-node target.
- Reference plan: `docs/cooters_job_board_and_travel_plan.md`.

## Ninth Sprint Expansion: Terrain-Driven Cooters Destinations

### Status: Complete

- Added `docs/gatebox_sub_sub_basement_terrain_agent_reference.md` as the terrain interaction reference.
- Added `docs/cooters_job_board_level_expansion_plan.md` for the three new job destinations.
- Expanded the Cooters job board with three terrain-driven jobs:
  - `Food Court Filter` -> `DeadFoodCourtBloom.tscn`
  - `Pump Heart Lease` -> `WaterReclamationCistern.tscn`
  - `Atrium Relay Echo` -> `CollapsedServiceAtrium.tscn`
- Moved the Leak Street travel selector and Faded Atrium gate to the same side of the street to support the new canon: the old mall is partly submerged and Leak Street is built beside the exposed second-floor entrance.
- Removed the extra standalone Wake-Up Call street door; Wake-Up Call remains available through route selection.

## Eighth Sprint: Leak Street Restructure

### Status: Complete

- Reframed `SubSubBasementDistrict.tscn` as a named street slice rather than an open test arena.
- Expanded `LevelDresser` with street-scale visual structure:
  - patchwork north/south settlement facades
  - balcony rails and stacked shack fronts
  - alley mouths implying deeper offscreen neighborhoods
  - overhead cable bridges and leaking pipes
  - storefront/faction facades for Cooters, Suitors, Torai, Pipe Father Gideon, and System X
  - wet neon street spine and Leak Street signs
- Angled existing divider blockers to create a more guided street rhythm while preserving access to the current jobs.
- Updated System X and world-region text to establish Leak Street as one lane in a much larger settlement.

## Seventh Sprint: Suitors Surveillance Interior

### Status: Complete

- Added `SuitorsInterior.tscn` as the second tiny establishment interior.
  - Sunday is present as the first Suitors NPC.
  - The room includes a small lounge/stage, camera orbs, and a surveillance terminal.
  - The district Suitors doorway now grants the first mask outside, then routes into the interior on later interactions.
- Added the Surveillance Choir hack as the next crunchy district mechanic.
  - The hack can only be routed during a Hoodlum LAN outage.
  - On success it completes `suitors_blind_spot`, grants `Suitors Access Chit`, sets `suitors_surveillance_jammed`, and rewards System X reputation.
  - The blind spot gives the player a small persistent targeting assist by raising base hit chance and pickup radius.
- Updated objective text so the player chain reads: protect LAN outage -> enter Suitors -> hack surveillance choir.

## Sixth Sprint: Velvet Coil Cybernetics Pass

### Status: Complete

- Converted Velvet Coil's cybernetic surgery UI from a menu-only prototype into a usable district progression system.
- Replaced unreachable Mall Arcade Token costs with current district reward items:
  - `Suitors Access Chit` for Targeting Co-Processor.
  - `Cooters Bar Credit` for Gatebox Eye MK1.
  - `Torai Salvage Contract` for Black-Market Armature.
  - `Cheap Poncho` for Pipewalker Legs.
  - `Chemical Neutralizer` for Soul Baffle.
- Added live cybernetic effects:
  - Targeting Co-Processor improves base hit chance, lock speed, and pickup radius.
  - Gatebox Eye MK1 reveals enemy body part HP.
  - Black-Market Armature reduces weapon kick and preserves more lock after firing.
  - Pipewalker Legs increase movement speed.
  - Soul Baffle reduces incoming integrity damage.
- HUD inventory and cybernetic summary update immediately after installation.

## Fifth Sprint: Cooters Rain Mutant Encounter

### Status: Complete

- Added `RainMutant` as a body-part-targeted enemy variant.
  - Regenerates damaged parts while toxic rain is active and it is outside the Cooters containment radius.
  - Uses containment instead of death as the win condition.
  - Breaking `Rain Sac` and `Mobility Frame` near Cooters triggers containment.
- Added a Cooters escalation after the rain sample errand.
  - Sets `cooters_rain_mutant_active`.
  - Forces toxic rain so the regeneration rule is readable.
  - Persists completion with `cooters_rain_mutant_contained` and `cooters_unlocked`.
- Added `CootersInterior.tscn` as the first tiny establishment interior.
  - Contains Marbles as a proper interactable NPC.
  - Returns to the Sub-Sub-Basement District.
  - No vendor, fight pit, or full dialogue UI yet.
- Updated district objective text to guide the player through rain sample, Cooters emergency, containment, and interior access.

## Fourth Sprint: Establishment Errands

### Status: Complete

- Expanded Cooters from one-time Chemical Neutralizer pickup into a follow-up rain sample job.
  - Requires toxic rain to be active.
  - Rewards `Cooters Bar Credit`, System X rep, and `cooters_rain_sample`.
- Expanded Suitors from one-time Sealed Mask pickup into a LAN blind-spot job.
  - Requires LAN outage to be active.
  - Rewards `Suitors Access Chit`, System X rep, and `suitors_blind_spot`.
- Expanded Wan Moa Torai from one-time Cheap Poncho pickup into a salvage paperwork follow-up.
  - Requires Cooters rain sample completion.
  - Rewards `Torai Salvage Contract`, Wan Moa Torai rep, and `torai_salvage_contract`.
- Updated district objective text to guide the player through the new post-generator establishment loop.
- Kept the implementation hardcoded and lightweight until the district loop proves fun.

## Second Sprint: Social Density

### Status: Complete

- Added `DistrictNPC` script: wandering ambient NPCs with event-aware and faction-aware bark dialogue.
- Added 7 district NPCs (renamed to canonical GDD names):
  - **Pipe Father Gideon** (near pipe shelter): System X rep-gated dialogue, rain/sag/lan barks.
  - **Kiki Baja** (center-south): Wan Moa Torai rep-gated dialogue, smuggler/economy barks.
  - **VCR Prophet Ezekiel** (north area): System X rep-gated, prophetic world-event barks.
  - **Velvet Coil** (east): Gatebox Corporation rep-gated, cybernetic surgeon barks.
  - **Mister Static** (center-north): System X rep-gated, broken android barks.
  - **Ladderboy** (NW near den): Gatebox Corporation rep-gated, network/grid barks.
  - **Brickmouth Ronnie** (SE market): Wan Moa Torai rep-gated, ledger/obligation barks.
- NPCs wander within radius, idle, and respond to interact with context-sensitive lines.
- District script connects NPC focus signals and handles interaction.

## Third Sprint: District Expansion

### Status: Complete

- Expanded `SubSubBasementDistrict.tscn` from ~24x22 to 44x40 units with distinct zones:
  - Pipe Slums (SW): rust materials, Pipe Father Gideon, Reactor Cell crate
  - Hoodlum LAN (NW): green neon, Ladderboy, LAN Den, server rack dressing
  - Pipe Chapel / generator reliquary (SW): Gideon, wasted-potential economy, chapel-side power fiction
  - Market Row (SE): amber neon, Kiki Baja, Brickmouth Ronnie, Wan Moa Torai kiosk
  - Sky Platforms (NE): cyan/glass, elevated false sky panels
- Added 4 zone-specific OmniLight3D nodes (SlumOmni, MarketOmni, LANOmni, SkyOmni) with full event-aware dimming.
- Added third shelter zone (MarketShelter) with amber neon awning.
- Added 7 structural pillars (PillarA-G) for sight-line breakup across the expanded footprint.
- Added 3 internal dividing walls (DividerNW, DividerSE, DividerCenterNS) for corridor/zone separation.
- Expanded `_apply_world_lighting()` with `_set_zone_light()` and `_dim_zone_lights()` helpers for all 5 zone lights.
- Expanded `LevelDresser._dress_sub_basement_district()` with market stalls, LAN furniture, zone signage, generator pedestal, sky platform edge.
- Fixed `load_steps` count (55 resources + 1 scene = 56).
- MCP validated: zero errors, zero warnings on both SubSubBasementDistrict and MallHub.

## Summary

Build the Sub-Sub-Basement into a playable starting region before expanding the campaign spine further. The next phase turns the current slice into a small systemic lower-city loop: Faded Atrium hub, free-roam district, toxic rain hazard, generator instability, simple jobs, faction reactions, and survivable traversal.

## Key Changes

- Keep `MallHub.tscn` as the Faded Atrium hub, not the true Mall of the Future.
- Keep `Test_SubSubBasement.tscn` as the authored Wake-Up Call mission cell.
- Add `SubSubBasementDistrict.tscn` as the first free-roam lower-city scene.
- Expand `WorldDirector` into the central holder for region, world event, generator state, and faction-flavored status text.
- Add toxic rain, shelter volumes, protection items, generator state, and lightweight social/economy hooks.

## First Sprint

### Implemented Baseline

- Added `SubSubBasementDistrict.tscn` as the compact free-roam lower-city district.
- Added toxic rain, shelter, generator, and establishment interaction scripts.
- Routed the Faded Atrium Sub-Sub-Basement gate into the district.
- Added item hooks for `Cheap Poncho`, `Sealed Mask`, `Chemical Neutralizer`, mission loot, and `Wan Note`.
- Locked the Wake-Up Call route behind the first generator repair job.
- Added MCP validation for the new district and affected route scenes.

### Region Structure

The district should include:

- Faded Atrium entrance/exit.
- Fake sky ceiling panels.
- Generator block.
- Pipe shelter area.
- Cooters entrance placeholder.
- Suitors entrance placeholder.
- Wan Moa Torai office kiosk.
- Hoodlum LAN den placeholder.
- Wake-Up Call mission gate.

The first district should stay compact and readable.

### World Events

`WorldDirector` owns:

- active world event: clear, toxic rain, power sag, LAN outage
- generator state: stable, sagging, overloaded, offline
- current region
- event damage and status text

Initial event behavior:

- clear: no hazard
- toxic rain: damages exposed player over time
- power sag: dimmer lights, warning HUD, some terminals unavailable
- LAN outage: surveillance blind spots, System X commentary, generator stress

### Toxic Rain

- `ToxicRainController.gd` damages the player when toxic rain is active and the player is not in shelter.
- `ShelterZone.gd` marks safe cover.
- Rain damage is around 2 hp/sec and ticks once per second.
- `Cheap Poncho` halves rain damage.
- `Sealed Mask` prevents rain damage.
- `Chemical Neutralizer` is inventory-only for now.

### Dreaming Generator

The Dreaming Generator is no longer a freestanding district repair box. It now lives inside Pipe Chapel and is tended by Pipe Father Gideon.

Current implementation:

- The old street generator mesh and reactor-cell crate are removed from Leak Street.
- Gideon/ Pipe Chapel now provide the generator interaction.
- The player can sell mission loot and other failed-use objects to Gideon.
- Sold items generate `Wan Note` currency and add stored Dreaming Generator potential.
- Stored potential is tracked in `GameState.world_flags`.
- If stored potential is below threshold, `WorldDirector` sets the generator state to sagging/offline and district routes can lock.
- Feeding enough potential marks `dreaming_generator_fed`, `dreaming_generator_sustained`, and the legacy `patch_dreaming_generator` flag for compatibility with older route gates.

Canon:

- The Dreaming Generator is powered by wasted potential: useful things, lost futures, ruined miracles, and lives that failed to become what they were supposed to become.
- Wan Notes are the Sub-Sub-Basement currency backed by Wan Moa Torai.
- Every Wan Note contains a System X tracker that records holders.
- Carrying Wan Notes means being under Wan protection, but also under Wan visibility.
- Wan debt enforcers double as street security and enforce repayment when robbery is reported.
- If someone is found dead and System X records indicate foul play, the responsible party often disappears; the generator then rises from that harvested wasted potential.

Generator states remain:

- stable
- sagging
- overloaded
- offline

### Establishments

Use lightweight interactables first:

- Cooters: rumors, small jobs, underground fight setup later
- Suitors: System X/Yoko lore and surveillance atmosphere
- Wan Moa Torai Office: debt permits and “one more try” gear
- Hoodlum LAN Den: LAN outage hook and future child-engineer questline

### First Jobs

- Feed The Dreaming Generator: sell mission loot to Gideon for Wan Notes and stored generator potential.
- One More Try: accept Torai obligation, gain `Cheap Poncho`.
- LAN Party Brownout: stop or protect the LAN event through repeated Hoodlum den interactions.

## Test Plan

- Launch `MallHub.tscn` through MCP and verify no debug errors.
- Launch `SubSubBasementDistrict.tscn` through MCP and verify no debug errors.
- Trigger toxic rain and verify exposed player takes damage.
- Enter shelter and verify rain damage stops.
- Add `Cheap Poncho` and verify rain damage is reduced.
- Add `Sealed Mask` and verify rain damage stops.
- Trigger generator power sag and verify HUD/lighting changes.
- Sell mission loot to Gideon and verify Wan Notes, generator potential, event/state updates, and route unlocks.
- Save during a non-clear event, reload, and verify state persists.
- Re-run existing route scenes through MCP when shared systems change.

## Assumptions

- First priority is playable systems, then social density, then traversal expansion.
- The first district is compact and systemic, not huge.
- Dialogue remains lightweight until the district mechanics are fun.
- The true Mall of the Future stays mythic/remote for now; the playable hub is the Faded Atrium.
