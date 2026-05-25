# GATEBOX BREACH — Sub-Sub Basement Survival Site & Encounter Reference

Clean-room design brief for level-building and quest-building agents. This document distills broadly applicable post-apocalyptic sandbox, settlement, resource, hazard, and encounter-site design patterns into original guidance for **GATEBOX BREACH**, a retro cyberpunk immersive-sim / dungeon-crawler set in the **Sub-Sub Basement of Gatebox Mega City One**.

Do **not** copy names, factions, rules text, tables, setting terms, NPCs, locations, stat blocks, or branded lore from any source book. Use this as a practical generation vocabulary for Codex, level agents, quest agents, map builders, encounter spawners, and narrative-content scripts.

## Design Goal

The Sub-Sub Basement should not feel like a generic dungeon. It should feel like a buried city-machine where every room is shaped by survival pressure:

- People need water, power, medicine, food, air, shelter, signal, identity, and security.
- Every useful place has already been claimed, stripped, trapped, repaired, worshipped, flooded, or forgotten.
- Every faction is tied to a resource problem.
- Every encounter site should contain a reason to enter, a reason to hesitate, and a reason to remember it.

## Core Loop For Agents

When generating a playable site, use this loop:

1. **Pick the site identity.** What was this place before the collapse of this level?
2. **Pick the current pressure.** What scarce resource, danger, or social conflict makes it matter now?
3. **Pick 3–5 key spaces.** Build a compact layout from meaningful rooms, not filler hallways.
4. **Pick occupants or traces.** Who is here, who was here, or who is watching from nearby?
5. **Pick hazards.** Include at least one environmental problem and one behavior-changing complication.
6. **Pick loot or utility.** Give the player something practical, not just abstract reward.
7. **Pick a twist.** Make the first read of the place incomplete or misleading.
8. **Expose choices.** Include at least two approaches: fight, sneak, negotiate, repair, hack, bypass, or exploit terrain.

## Site Card Format

Agents should be able to output a site in this compact structure:

```yaml
site_id: ssb_sector_##_site_##
name: "Short evocative name"
site_type: "former use / current use"
sub_sub_basement_zone: "district or local region"
old_function: "what the place was built for"
current_function: "what survivors use it for now"
main_resource_pressure: "water | power | food | air | medicine | shelter | signal | salvage | safety | status"
visual_identity:
  - "2-4 strong art notes"
key_spaces:
  - name: "entrance / threshold"
    gameplay: "first decision, ambush, checkpoint, signposting"
  - name: "main work area"
    gameplay: "central combat/exploration loop"
  - name: "restricted or hidden space"
    gameplay: "reward, lore, shortcut, optional danger"
occupants:
  faction_or_group: "who is here"
  motive: "why they are here"
  default_state: "what they are doing when found"
hazards:
  environmental: "physical hazard"
  social_or_tactical: "occupant behavior, alarm, hostage, rival claim"
loot_or_utility:
  practical: "ammo, meds, water, batteries, parts, map data, key item"
  hidden: "optional prize or secret"
player_approaches:
  combat: "how fighting plays differently here"
  stealth: "route, cover, darkness, noise use"
  technical: "hack/repair/power/drain/disable option"
  social: "trade, intimidate, rescue, bargain, lie option"
twist: "what changes once investigated"
connections:
  leads_to: ["neighboring zone", "quest hook", "faction consequence"]
```

## Sub-Sub Basement Campaign Assumptions

Use this document with these setting assumptions:

- The game begins in a **run-down mall-like lower city**, similar in spirit to the Mall of the Future but not the actual Mall of the Future.
- The Sub-Sub Basement is not wilderness. It is an artificial wasteland: collapsed retail, dead infrastructure, service tunnels, dumped biotech, abandoned theme zones, refugee markets, and machine-managed utility spaces.
- Survivors build enclaves around working systems: generators, water stills, pump rooms, grow lights, barricaded escalators, air scrubbers, server shrines, old pharmacy stores, freezer banks, and illegal signal relays.
- The player should constantly feel the value of basic needs. Clean water, a working battery, a quiet room, a reliable air vent, or a trustworthy guide can matter as much as a weapon.

## Macro Structure: Regions, Routes, and Enclaves

A region is a cluster of encounter sites connected by safe routes, dangerous shortcuts, faction patrols, and resource dependencies.

### Region Agent Schema

```yaml
region:
  name: "The Pump Arcade"
  theme: "water extraction under a dead shopping concourse"
  dominant_pressure: "water"
  secondary_pressure: "power"
  safety_level: "settled | contested | predatory | abandoned | sealed"
  navigation_style: "linear crawl | hub-and-spoke | looped maze | vertical stack | flooded network"
  anchor_enclave: "who lives here or claims it"
  hostile_force: "who threatens it"
  neutral_force: "who trades, guides, or scavenges"
  major_sites:
    - "3-7 encounter sites"
  route_rules:
    safe_route: "longer, guarded, taxed, lit, watched"
    risky_shortcut: "flooded, dark, trapped, exposed, contaminated"
    secret_route: "requires key, rumor, hacking, small body, special gear"
  global_state_changes:
    - trigger: "player restores generator"
      consequence: "lights change, doors open, faction moves in"
```

### Region Design Rules

- Put **one enclave or semi-safe hub** near every major region unless the region is intentionally hostile.
- Connect every enclave to at least **two resource dependencies**. Example: a slum survives because the pump hall still works, but it needs filters from a pharmacy depot.
- Give every route a cost: time, noise, toll, radiation, water depth, oxygen risk, faction scrutiny, or lock complexity.
- Avoid huge empty maps. Build in **site clusters**: 3–7 meaningful places connected by 2–3 recurring routes.
- Let player actions change the route graph. Restoring power may make elevators work but also wake security. Draining a room may reveal loot but kill a fungal crop.

## Enclave Design For Level Agents

An enclave is not just a town. It is a living dependency knot. It exists because it controls something, needs something, fears something, and lies about something.

### Enclave Schema

```yaml
enclave:
  name: "Sunday Market"
  population_scale: "tiny | small | medium | crowded"
  base_location: "repurposed mall, platform, tunnel village, sealed store, generator room"
  controlled_resource: "what keeps them alive"
  missing_resource: "what they desperately need"
  social_identity: "how they describe themselves"
  real_identity: "what they actually are under pressure"
  leadership:
    public_leader: "visible leader archetype"
    hidden_power: "optional manipulator, machine, family, cult, creditor"
    control_strength: "fragile | stable | harsh | total"
  defenses:
    physical: ["barricades", "locks", "watch posts", "trained animals", "turrets"]
    social: ["hostages", "debt", "religion", "trade dependence", "blackmail"]
  services:
    - "healing"
    - "water trade"
    - "gear repair"
    - "rumor market"
    - "safe bed"
  internal_conflicts:
    - "leader hoards medicine"
    - "generator crew wants independence"
    - "guards secretly sell access"
  quest_hooks:
    - "retrieve filters"
    - "escort caravan"
    - "investigate missing scavengers"
    - "decide who gets the water ration"
```

### Enclave Resource Types

Use these as practical anchors for quest and level logic:

| Resource | What It Creates | What Threatens It | Level-Building Expression |
|---|---|---|---|
| Water | trade, farming, hygiene, life | contamination, leaks, theft, ration politics | pump rooms, cisterns, filters, flooded bypasses |
| Power | light, doors, heat, security, manufacturing | fuel shortage, grid spikes, sabotage, rival taps | generators, battery shrines, transformer puzzles |
| Food | stability, migration, bargaining | mold, pests, crop failure, theft | grow rooms, fungus farms, protein vats, kitchens |
| Air | habitable zones, prestige, survival | clogged vents, toxins, bad filters, sealed sectors | airlocks, scrubbers, fans, pressure doors |
| Medicine | loyalty, black market, triage choices | expiration, addiction, theft, disease | clinics, pharmacy cages, cold storage, quarantine |
| Shelter | safety, sleep, community | overcrowding, fire, collapse, infestation | barricades, bunks, heat lamps, hidden rooms |
| Signal | coordination, propaganda, maps, AI ghosts | jamming, surveillance, corrupted relays | antennas, server closets, broadcast booths |
| Scrap | crafting, economy, repairs | monopoly, dangerous salvage, hoarding | junk markets, machine shops, disassembly pits |

## Encounter Site Categories For GATEBOX

These are original site types suitable for the Sub-Sub Basement. Agents should choose one and mutate it with descriptors, occupants, and hazards.

### Utility & Survival Sites

- **Water Still Chapel:** shrine-like purifier room surrounded by buckets, pipes, and ration graffiti.
- **Pump Arcade:** flooded retail concourse where old fountain pumps keep part of the level alive.
- **Battery Dormitory:** sleeping quarters wired around a communal charge wall.
- **Air Scrubber Loft:** high catwalk nest around a working fan tower.
- **Filter Crypt:** sealed maintenance crypt full of replacement air/water filters.
- **Generator Reliquary:** community power source treated as holy, dangerous, or political.
- **Heat Exchange Sauna:** survivors camp around unstable thermal ducts.
- **Cold Locker Clinic:** freezer-bank turned medical triage and corpse storage.

### Mall Ruin Sites

- **Dead Food Court:** abandoned kitchens, grease traps, mascot signage, fire shutters.
- **False-Sky Atrium:** cracked video ceiling, artificial daylight flicker, exposed service bridges.
- **Luxury Rotunda:** corporate marble and glass buried under slum structures.
- **Escalator Village:** vertical shack town built around dead escalators and working winches.
- **Department Store Maze:** mannequins, racks, barricades, dressing-room tunnels.
- **Prize Arcade Vault:** broken amusements, ticket counters, hidden token economies.
- **Customer Service Tribunal:** complaint desk repurposed as court, cult pulpit, or toll booth.
- **Security Office Warren:** monitors, keys, holding cells, dead cameras, active alarms.

### Industrial & Salvage Sites

- **Trash Compactor Cathedral:** huge compactors, bone-crushing machinery, salvage cults.
- **Scrap Sorting Yard:** conveyor lanes, magnet cranes, piles of sharp debris.
- **Machine Shop Den:** functional tools defended by mechanics or raiders.
- **Old Delivery Hub:** cargo lockers, robot tracks, lift shafts, missing packages.
- **Pipeworks Canyon:** walkways over open pipe trenches and leaking mains.
- **Sump Gate:** flood-control door contested by water thieves and pump keepers.
- **Service Elevator Stack:** multi-floor descent point with changing hazards per stop.
- **Forklift Graveyard:** dead vehicles, battery loot, cover maze, explosive cells.

### Biohazard & Weird Sites

- **Fungal Laundromat:** humid machines overgrown with edible and toxic molds.
- **Biotech Dumping Niche:** illegally dumped experiment waste mutating the floorplan.
- **Petting Zoo Remnant:** escaped mascot animals or mutant small predators.
- **Protein Vat Nursery:** food source, monster nest, or cult womb depending on state.
- **Greenhouse Underpass:** hydroponic ruin under broken grow lights.
- **Spore Market:** traders selling questionable medicine and hallucinogenic fungus.
- **Quarantine Boutique:** sealed luxury store converted into plague ward.
- **Root-Cable Server Room:** plant growth and data lines fused into one system.

### Signal, AI, and Corporate Ghost Sites

- **Gatebox Kiosk Farm:** customer-service terminals repeating old sales scripts.
- **System X Relay Shrine:** benevolent-seeming node with missing context.
- **Yoko Translation Booths:** multilingual help stations turned oracle booths.
- **Face Memorial Cache:** hidden data/lore room protected by sentimental traps.
- **Ad Drone Aviary:** inactive drones perched above a plaza, some still watching.
- **Influencer Studio Tomb:** streamer set, ring lights, dead subscription wall, useful camera gear.
- **Mall Map Nerve Center:** directory room that can reveal routes if powered.
- **Identity Printer Office:** badge-making and face-scan systems with corrupted permissions.

## Site Descriptors

Apply 1–3 descriptors to make repeated site types feel different.

| Descriptor | Meaning For Agent |
|---|---|
| Adorned | covered in slum art, faction marks, memorials, warnings, mascot graffiti |
| Atrocity-marked | evidence of a public punishment, massacre, betrayal, or ration riot |
| Active Machinery | old systems still move, crush, pump, sort, heat, scan, or broadcast |
| Bifurcated | split between two users, two elevations, two factions, or two climate zones |
| Burned | charred layout, smoke damage, collapsed shelving, brittle floors |
| Buried | partly blocked by cave-in, trash slide, foam insulation, or fungal mass |
| Contaminated | chemical, sewage, radiation, spores, sickness, or cursed data residue |
| Flooded | ankle, waist, or full-depth water/sludge changes traversal and sound |
| High Ground | overlooks nearby routes; useful for snipers, scouts, antennas, or watchmen |
| Infested | vermin, drones, fungus, cables, feral pets, or tiny machines occupy it |
| Locked | entrances are sealed; needs key, hack, brute force, vent route, or bargain |
| Mazey | racks, debris, partitions, pipes, or shacks make line-of-sight confusing |
| Overlooked | hidden behind signage, false wall, trash drift, service panel, or collapsed decor |
| Recently Used | warm fires, wet footprints, fresh wrappers, active battery, recent blood |
| Revered | locals treat it as holy, taboo, ancestral, cursed, or contractually protected |
| Stripped | obvious loot gone; value is hidden, structural, technical, or social |
| Trapped | alarms, deadfalls, pressure plates, electrified doors, noise lures |
| Watched | cameras, scouts, informants, drones, animals, or AI processes observe it |
| Wind/Pressure Damaged | fans, suction, draft, vacuum leaks, or pressure shifts affect movement |
| Wrongly Remembered | local stories about the site are incomplete or dangerously false |

## Encounter Occupants

Occupants should not spawn randomly without motive. Tie them to nearby enclaves, resource needs, rumors, or travel routes.

| Occupant Type | Why They Are Here | Default Behavior |
|---|---|---|
| Scavenger Crew | stripping parts, mapping loot, harvesting copper | avoid fights unless cornered; may trade information |
| Water Thieves | tapping pipes, poisoning rivals, stealing filters | flee with cargo; sabotage route behind them |
| Generator Keepers | repairing or defending power machinery | suspicious but practical; value tools and batteries |
| Refugee Family | sheltering, hiding, waiting for guide | scared, protective, can become moral choice |
| Toll Gang | controlling bridge, elevator, door, or safe route | demands payment; may respect strength or contracts |
| Fungal Cult | farming spores, worshipping growth, drug trade | friendly if respected, dangerous if mocked or burned |
| Linda Bioroid Remnant | self-repairing, scavenging, following old service logic | polite until threatened; may want parts or customers |
| System X Agent | monitoring infrastructure, recovering data, protecting hidden truth | helpful but selective; withholds context |
| Mascot Pack | feral people or machines using entertainment costumes/skins | ambush, mimicry, unsettling social rituals |
| Ex-Security Unit | enforcing obsolete rules or protecting old VIP spaces | warns first, escalates predictably |
| Clinic Runners | treating wounded, hiding medicine, choosing who lives | trade for supplies, fear infection and raiders |
| Data Hermit | living near terminal, radio, archive, AI shrine | knows routes; demands weird favors or privacy |
| Raider Foragers | seeking food, drugs, captives, batteries | aggressive if advantaged, transactional if not |
| Machine Vermin | drones, cleaner bots, cable rats, maintenance spiders | react to noise, light, heat, spilled fluids |
| Rival Salvage Claimants | arrived for the same prize as player | can negotiate, race, betray, or accidentally help |

## Occupant State Table

Pick one so the place feels alive before the player enters:

1. Arguing about whether to stay or leave.
2. Repairing something with inadequate tools.
3. Looting quickly before a rival arrives.
4. Hiding from a stronger threat deeper inside.
5. Performing a ritual, memorial, trial, or execution.
6. Sleeping in shifts with crude alarms set.
7. Treating an injury or infection.
8. Moving heavy cargo through a dangerous route.
9. Watching a door, hatch, or machine they fear.
10. Following orders they do not understand.
11. Trying to silence a witness, prisoner, or noisy machine.
12. Waiting for a trade, ransom, pickup, or signal.

## Hazard Design

Every important site should have **0–3 hazards** depending on size and intensity. Use hazards to change behavior, not just drain health.

### Environmental Hazards

| Hazard | Gameplay Use | Readable Signs | Counterplay |
|---|---|---|---|
| Collapsing Floor | breaks routes, drops player/enemies, reveals subfloor | sagging tiles, dust, creaks, exposed rebar | go around, crawl, reinforce, jump, lure enemies |
| Live Wiring | area denial, shock trap, power puzzle | sparks, flicker, hum, dead rats | shutoff, insulation, water avoidance, throw object |
| Bad Air | timed pressure, mask value, route tension | coughing NPCs, yellow haze, dead insects | filters, fans, vents, oxygen pocket |
| Flooded Sludge | slows, hides holes, conducts electricity, muffles footsteps | ripples, bubbles, floating trash | drain, swim, bridge, freeze, electrify as trap |
| Fire/Heat Jet | timing hazard, area denial | scorch marks, pressure hiss, warning lights | valve, timing, remote trigger |
| Spore Bloom | stealth reveal, hallucination, poison, infection risk | fungal caps, dust clouds, colored growth | mask, burn, mist sprayer, avoid vibration |
| Structural Pressure | fans/vacuum/wind push player or projectiles | roaring ducts, moving debris | close vents, crouch, use cover, time movement |
| Toxic Spill | route denial and loot risk | warning color, melted material, smell cue | boots, neutralizer, jump path, pump out |
| Security Alarm | calls reinforcements or locks doors | cameras, trip beams, old signs | hack, disable camera, avoid light cone |
| Unstable Machinery | crushers, belts, grinders, moving pistons | rhythm, clanking, warning paint | ride, jam, reverse, lure enemy |
| Radiation/Signal Burn | invisible damage or sensor distortion | dosimeter clicks, glitching UI, static | shielding, timed exposure, power down source |
| Disease Object | infection or quest complication | quarantine tape, medical signs, corpse clusters | gloves, burn, seal, sample, avoid loot greed |

### Occupant Hazards

| Hazard | Gameplay Use |
|---|---|
| Hidden Lookout | occupants are warned unless player scouts or disables observer |
| Desperate Need | group takes irrational risks to acquire a specific supply |
| Hostage or Patient | direct combat risks killing someone valuable or innocent |
| Prepared Killzone | barricades, crossfire, tripwire, or funnel creates tactical puzzle |
| Split Faction | negotiation can turn one side against another |
| False Surrender | social encounter can become ambush if mishandled |
| Outsider Patron | a stronger faction retaliates if occupants are harmed |
| Mobile Loot | occupants may flee with the best prize if alarmed |
| Sacred Object | damaging terrain creates social consequences |
| Infection Fear | occupants overreact to blood, coughing, mutation, or contamination |
| Machine Ally | turrets, drones, cleaner bots, or doors favor occupants |
| Misidentified Player | old scanner, rumor, or disguise marks player as enemy or VIP |

## Loot and Utility Philosophy

Loot should answer: **Why risk this room?**

Avoid only giving generic coins. In GATEBOX, useful loot should be tied to survival, routes, crafting, faction leverage, or story access.

### Loot Types

| Loot Type | Examples | Gameplay Value |
|---|---|---|
| Immediate Survival | clean water, ration bricks, antibiotics, air filters | keeps player/NPCs alive; supports enclave quests |
| Tactical Consumables | ammo, batteries, grenades, smoke cans, med sprays | changes next fight |
| Repair Components | fuses, pump seals, servo motors, copper, lenses | unlocks repairs, crafting, doors, enclave upgrades |
| Route Keys | badges, elevator tokens, map chips, maintenance keys | opens alternate paths |
| Social Leverage | ledgers, blackmail, ration records, ownership tags | changes faction outcomes |
| Weird Tech | broken AI module, prototype battery, corrupted camera core | unlocks special systems or risky powers |
| Comfort Objects | toys, music, photos, decorations, coffee, clean blankets | morale, NPC quests, settlement identity |
| Trade Goods | medicine, spices, liquor, cosmetics, charge packs | barter without being pure currency |
| Evidence | recordings, logs, body placement, transaction data | reveals truth behind a site or faction |
| Heavy Prize | generator, water tank, compressor, server rack | requires extraction, escort, cart, winch, or faction deal |

### Loot Placement Rules

- Put the best loot behind a choice, not just a lock. Example: taking filters may save your hub but doom the people using them now.
- Use visible but unreachable loot to teach routes: behind grating, across flooded pit, above catwalk, inside locked display.
- Make heavy loot create gameplay: slow movement, noise, needing a cart, powering a lift, attracting thieves.
- Make some loot locally owned. Stealing from desperate survivors should have consequences.
- Hide story loot in places that make sense: manager office, server closet, freezer log, shrine wall, maintenance tablet, corpse pocket.

## Twists For Encounter Sites

Use one twist per important site.

1. The apparent raiders are refugees pretending to be dangerous.
2. The machine is not broken; it is refusing unsafe operation.
3. The useful resource is contaminated but can be purified with extra work.
4. The local story blames the wrong faction.
5. The occupant leader is a puppet for a hidden terminal, creditor, or hostage-taker.
6. The site is safe only because something worse avoids it.
7. The loot is real, but removing it destabilizes a system.
8. The obvious entrance is watched; the ridiculous entrance is safe.
9. The monster is protecting eggs, children, patients, or a food source.
10. The old corporate system still recognizes VIP credentials.
11. A friendly guide is steering the player away from evidence.
12. The place has been stripped, but the walls/floor/ceiling are valuable.
13. The hazard can be weaponized against a nearby faction.
14. The dead here were not killed by the current occupants.
15. The site’s best reward is a map to a different site.
16. The enclave needs the place restored, but a rival needs it destroyed.
17. The AI voice is imitating someone the player/NPCs trust.
18. The resource is abundant, but moving it is the real challenge.
19. The safest route requires violating a taboo or faction boundary.
20. The site is a trap, but not for the player.

## Adventure Structures For Agents

Use these to generate quests that fit a post-apocalyptic immersive sim.

### 1. Resource Recovery

```yaml
adventure_type: resource_recovery
setup: "an enclave needs a practical resource from a dangerous site"
complication: "someone else already depends on it"
choices:
  - "take it by force"
  - "repair the source so both groups benefit"
  - "trade for it"
  - "find a worse but acceptable substitute"
consequence: "resource access changes hub services, prices, NPC survival, or route safety"
```

### 2. Route Opening

```yaml
adventure_type: route_opening
setup: "a shortcut or critical path is blocked by collapse, flood, gang toll, lock, or machine logic"
complication: "opening it helps enemies as well as allies"
choices:
  - "restore official route"
  - "create hidden bypass"
  - "make a deal with route holders"
  - "weaponize the blockage"
consequence: "patrols, trade, refugees, and monsters begin using new route graph"
```

### 3. Enclave Crisis

```yaml
adventure_type: enclave_crisis
setup: "a settlement is about to fail due to internal conflict or resource loss"
complication: "no solution satisfies all factions"
choices:
  - "support current leader"
  - "empower workers/guards/technicians"
  - "expose hidden truth"
  - "evacuate instead of saving the place"
consequence: "leadership, services, prices, and regional hostility change"
```

### 4. Salvage Race

```yaml
adventure_type: salvage_race
setup: "multiple groups learn about a valuable site at the same time"
complication: "the site becomes more dangerous the longer the race continues"
choices:
  - "arrive first through a hazardous shortcut"
  - "ambush rivals"
  - "negotiate shares"
  - "sabotage the prize so nobody gets it"
consequence: "rivals remember player behavior"
```

### 5. Truth Retrieval

```yaml
adventure_type: truth_retrieval
setup: "a terminal, witness, corpse, or archive can prove what really happened"
complication: "the truth destabilizes an enclave or empowers a bad actor"
choices:
  - "publish truth"
  - "sell truth"
  - "hide truth"
  - "use truth to blackmail or reform"
consequence: "faction trust and future quest availability change"
```

## Survival Pressures As Level Mechanics

These are not necessarily meters. They can be quest logic, local hazards, NPC needs, or optional difficulty systems.

### Hunger / Food

- Food sites attract desperate people faster than weapon sites.
- Kitchens, fungus farms, protein vats, and storage rooms should have strong social stakes.
- Food contamination is a good non-combat reason to explore medical, filtration, or diagnostic sites.

### Thirst / Water

- Water makes settlements possible.
- Pipes, cisterns, pumps, condensation traps, and purifier cartridges should be recurring objective items.
- A flooded area is not automatically good; it may be undrinkable, electrified, diseased, guarded, or needed for cooling.

### Air

- Use breathable air as a boundary for dangerous sectors.
- Fans and scrubbers are excellent environmental puzzle objects.
- Bad air can justify masks, timers, alternate routes, and NPC triage.

### Disease

- Disease should create quarantine layouts, moral choices, and supply runs.
- Avoid making disease feel random and unfair; foreshadow with corpses, coughing, warning tags, medical clutter, insect swarms, or discoloration.
- Let careful play reduce risk: gloves, burning, sealing, ventilation, medicine, remote handling.

### Radiation / Signal Burn / Corruption

For Gatebox, treat radiation broadly: chemical radiation, data corruption, AI signal exposure, sensor burn, or mutagenic waste.

- Use it to make short exposure routes viable but lingering dangerous.
- Provide readable meters or environmental signs.
- Pair with valuable loot so the player chooses risk.

### Stress / Fear / Social Breakdown

- Show psychological pressure through NPC behavior: paranoia, hoarding, cult logic, faction splitting, irrational rules.
- Use safe rooms, music, lights, and comfort objects to contrast hostile spaces.
- Let player choices calm or radicalize enclaves.

## Technical Agent Rules For Building Levels

### Key Space Count

For a small encounter site:

- 1 threshold space
- 1 central interaction/combat space
- 1 reward or control space
- 0–1 hidden bypass or vantage point

For a medium encounter site:

- 1 threshold space
- 2 central spaces with different traversal/combat shapes
- 1 hazard-control space
- 1 occupant social space
- 1 hidden reward/lore space

For a large complex:

- Treat it as 3–6 linked encounter sites.
- Each sub-site gets its own identity, occupants/traces, hazard, and reward.
- Use a shared global system: power state, flood level, alarm state, faction war, oxygen, moving elevator, or pressure doors.

### Room Metadata Tags

```yaml
room_tags:
  function:
    - threshold
    - combat_arena
    - stealth_route
    - social_node
    - puzzle_control
    - resource_cache
    - lore_site
    - extraction_point
  pressure:
    - water_need
    - power_need
    - food_need
    - air_need
    - medicine_need
    - security_need
    - signal_need
  traversal:
    - vertical
    - flooded
    - crawlspace
    - catwalk
    - elevator
    - vent
    - destructible_blockage
    - locked_gate
  hazard:
    - electricity
    - toxic_air
    - disease
    - spores
    - collapse
    - fire
    - security
    - machinery
    - signal_burn
  social:
    - claimed
    - taboo
    - occupied
    - watched
    - disputed
    - hostage
    - trade_possible
    - betrayal_possible
```

### Encounter Pacing

Avoid stacking every danger in one room. Build rhythm:

1. **Read:** player sees signs of trouble before contact.
2. **Choice:** player picks route or approach.
3. **Contact:** occupant, hazard, or puzzle activates.
4. **Complication:** alarm, rival, leak, collapse, truth, or moral problem changes the plan.
5. **Reward:** player gains resource, route, knowledge, ally, or leverage.
6. **Consequence:** local state changes.

## Example Generated Sites

### Example 1: The Filter Crypt

```yaml
name: "The Filter Crypt"
site_type: "sealed maintenance storage / contested air-filter cache"
main_resource_pressure: "air"
visual_identity:
  - "rows of coffin-like filter drawers under cracked teal emergency light"
  - "paper prayer strips tied to intake grates"
  - "white dust drifts in ankle-deep dunes"
key_spaces:
  - name: "sealed service vestibule"
    gameplay: "locked door, vent crawl bypass, warning marks"
  - name: "filter drawer hall"
    gameplay: "long sightlines, movable drawers as cover, dust clouds"
  - name: "fan control pulpit"
    gameplay: "turn fans on/off, clear dust, awaken sensors"
occupants:
  faction_or_group: "clinic runners and a hidden lookout"
  motive: "they need filters for a quarantine ward"
  default_state: "two are loading filters while one watches the entrance"
hazards:
  environmental: "bad air and choking dust when drawers are opened"
  social_or_tactical: "taking all filters dooms another enclave's sickroom"
loot_or_utility:
  practical: "air filters, fan fuse, respirator patch kit"
  hidden: "maintenance map to a cleaner upper duct"
player_approaches:
  combat: "long narrow aisles favor suppression and drawer cover"
  stealth: "crawl through intake duct to reach control pulpit"
  technical: "power fans to clear dust but trigger old camera scan"
  social: "trade medicine or promise alternate filters"
twist: "some filters are fake shells hiding data drives from System X"
```

### Example 2: Mascot Service Elevator

```yaml
name: "Mascot Service Elevator"
site_type: "vertical cargo lift / moving encounter stack"
main_resource_pressure: "route access"
visual_identity:
  - "huge freight platform painted with rotted cartoon faces"
  - "floor numbers scratched out and replaced with faction symbols"
  - "cables vanish into a black shaft full of warm wind"
key_spaces:
  - name: "loading dock barricade"
    gameplay: "toll negotiation or firefight"
  - name: "moving lift platform"
    gameplay: "cover shifts, enemies board from side doors"
  - name: "mid-shaft service niche"
    gameplay: "optional exit to hidden cache"
occupants:
  faction_or_group: "toll gang with ex-security radio"
  motive: "they control descent traffic"
  default_state: "arguing over whether to let a refugee group pass"
hazards:
  environmental: "platform stalls between floors and lights cut out"
  social_or_tactical: "if alarmed, gang sends word to lower checkpoint"
loot_or_utility:
  practical: "route unlock, elevator crank, battery pack"
  hidden: "old VIP badge under mascot floor panel"
player_approaches:
  combat: "limited cover and ring-out danger"
  stealth: "climb cable ladder during noise surge"
  technical: "repair control box to choose destination"
  social: "pay toll, expose gang's fake authority, escort refugees"
twist: "the elevator remembers old corporate priority floors if shown a VIP badge"
```

### Example 3: The Food Court Fever Ward

```yaml
name: "The Food Court Fever Ward"
site_type: "dead food court / improvised clinic and quarantine"
main_resource_pressure: "medicine"
visual_identity:
  - "plastic menu boards glowing above rows of sick cots"
  - "grease traps converted into sterilization tubs"
  - "mascot napkins used as bandages"
key_spaces:
  - name: "triage counter"
    gameplay: "social gate, moral choices"
  - name: "kitchen pharmacy"
    gameplay: "loot, crafting, disease risk"
  - name: "freezer morgue"
    gameplay: "evidence, hidden survivor, cold-storage medicine"
occupants:
  faction_or_group: "clinic runners, patients, one disguised medicine thief"
  motive: "keep disease contained and patients alive"
  default_state: "clinic is mid-argument over who gets the last antibiotics"
hazards:
  environmental: "infectious surfaces and bad ventilation"
  social_or_tactical: "open combat may spread panic and release quarantined patients"
loot_or_utility:
  practical: "antibiotics, clean syringes, cold packs"
  hidden: "ration ledger proving a nearby leader stole supplies"
player_approaches:
  combat: "dangerous due to civilians and infection zones"
  stealth: "enter through freezer delivery hatch"
  technical: "restore ventilation to reduce infection risk"
  social: "mediate ration choice or expose thief"
twist: "the 'outbreak' is partly caused by contaminated water from another site"
```

## Agent Checklist Before Finalizing A Site

Before outputting or implementing a site, verify:

- [ ] The site has a clear former purpose and current purpose.
- [ ] The site connects to at least one local resource pressure.
- [ ] There are 3–5 key spaces with different gameplay roles.
- [ ] The player can approach the problem in at least two ways.
- [ ] Hazards are foreshadowed visually or audibly.
- [ ] Occupants have a reason to be there.
- [ ] Loot is practical, social, technical, or route-changing.
- [ ] At least one element can change after player action.
- [ ] The site can be described in one sentence for debugging.
- [ ] The result feels like Gatebox: dead mall + buried infrastructure + survival horror + weird AI/corporate afterimage.

## Quick Prompt Template For Codex / Level Agents

Use this when asking an agent to generate a site:

```text
Generate a GATEBOX BREACH Sub-Sub Basement encounter site using the survival-site reference.
Return Markdown plus YAML metadata.
Site scale: small/medium/large.
Dominant pressure: [water/power/food/air/medicine/shelter/signal/salvage/security].
Tone: retro cyberpunk, wet industrial decay, dead mall infrastructure, post-apocalyptic survival.
Include:
- former purpose and current purpose
- 3-5 key spaces
- occupants or traces with motive
- environmental hazard and tactical/social hazard
- loot or utility with consequences
- at least 3 player approaches: combat, stealth, technical, social
- one twist
- room_tags for implementation
Do not use copyrighted names or copied source text.
```
