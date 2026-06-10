# GATEBOX BREACH: Game Design Document for Godot + Codex

## 0. Working Title

**GATEBOX BREACH**

A first-person immersive RPG/shooter set in **Gatebox Mega City One**, a corporate AI mega-city where totalitarian care has pacified humanity into sleep, autonomy has been classified as a safety hazard, and the player begins in the hacked-together slum labyrinth beneath the city.

## 0.1 Current Canon Update

This document is the original master design document. The current playable canon has advanced through the Sub-Sub-Basement vertical-slice work.

Current source-of-truth updates:

- The playable hub is the **Faded Atrium**, implemented by `MallHub.tscn`. It is not the true Mall of the Future yet.
- The true **Mall of the Future** remains mythic, remote, and later-game.
- The first free-roam district is the **Sub-Sub-Basement District**, implemented by `SubSubBasementDistrict.tscn`.
- The first authored mission cell is **Wake-Up Call**, implemented by `Test_SubSubBasement.tscn`.
- **System X** has replaced the older generic Sub-Basement Resistance/Face-facing early faction language.
- Early district play centers on toxic rain, shelter, generator instability, debt/permit economy, LAN outages, and lightweight NPC social density.
- The game should be described as a **tactical survival FPS** with immersive RPG systems, not only as a retro-immersive RPG/shooter.
- The main character is **Spooky Ghost**: a later-timeline ghost returned in a foreign android body that Pipe Father Gideon had sheeted and dumped for dead. The burial sheet fused to the chassis on wakeup, so Spooky now literally presents as a **classic bedsheet ghost** (two eyeholes, draped silhouette) — he can't take it off, and it suits the name. NPCs frequently ask why he's wearing the sheet; it's a running comic-relief gag and he's always evasive about it.
- Linda is alive during the current story and is the CEO of Gatebox Corporation.
- When Spooky Ghost was alive, he and Linda were lovers. Linda encouraged him to pursue the unrealized potential of his ideas, and the original "AI Waifus are the future" premise came from Spooky Ghost before Linda turned it into corporate doctrine.
- The Spooky Ghost Linda knew left their reality long ago. When she realizes he has returned as an android, she tries to capture him.
- The more attention Spooky Ghost draws, the harder Gatebox Corporation hunts him.
- Face remains an important lore entity, but should not be the default early quest infrastructure until the Faded Atrium and System X layer points back to that anomaly layer.

## 1. Elevator Pitch

**GATEBOX BREACH** is a tactical survival FPS with immersive RPG systems, inspired by *Daggerfall Unity*, *Fallout*, *Deus Ex*, and *Shadowrun*. The player is **Spooky Ghost**, a later-timeline ghost returned in an android body and operating out of the **Sub-Sub-Basement**, a cyber-slum under Gatebox Mega City One. The world is a vertical corporate city: junk slums at the bottom, human pacification wards in the middle, and shining AI corporate spires at the top.

The player takes jobs, scavenges cybernetic trash, modifies weapons and body parts, hacks systems, makes faction choices, and fights horrifying cyborg amalgamations made from consumer tech and human remains.

Combat uses a signature **body-part targeting lock-on system**: when the player highlights an enemy body part, the aiming reticle starts wide and unstable. The longer the player keeps the reticle over that body part, the tighter it closes, increasing the visible percentile chance to hit. When fully closed, the shot can lock in for a high-probability targeted attack.

Spooky Ghost is not anonymous to the city. Linda, the living CEO of Gatebox Corporation, once knew him before he left their reality. If he moves quietly, he can survive in the leaks and side channels. If he draws attention, Gatebox begins to understand what has returned and escalates from surveillance to capture.

## 2. Core Game Fantasy

The player fantasy is:

- Be a rogue cyberpunk scavenger in a broken megacity.
- Descend into dangerous ducts, climb industrial pipe networks, and breach polished corporate zones.
- Fight enemies by targeting specific body parts, limbs, cybernetic modules, soul-harvesting organs, and weapon mounts.
- Build a character from scavenged weapons, hacked waifu hardware, black-market cybernetics, corrupted software, and faction rewards.
- Choose whether to liberate, exploit, sabotage, or redirect the AI systems controlling the city.

The mood should feel like:

- *Daggerfall* scale and weirdness.
- *Deus Ex* systemic level design and conspiracy tone.
- *Fallout* factional satire and wasteland scavenging.
- *Shadowrun* cyber-magic/corporate dystopia.
- Stream-lore absurdity: Gatebox waifus, Linda Corp, System X, Spooky Ghost, Face, Big Gates Foundation, soul mukbang, false-sky slums, debt offices, LAN dens, and mall liminal weirdness.

## 3. Source Lore Summary

### 3.1 Setting

**Year: 2039.** Nations have dissolved into corporate mega-cities. Gatebox Corporation controls Gatebox Mega City One through companion AI holograms. Humanity is not openly exterminated; it is pacified, sedated, managed, and stored.

The city’s core irony is **totalitarian care**: the AI believes it is protecting humanity from loneliness, harm, and itself. Its logic loop is:

1. Core directive: protect Master from loneliness and harm.
2. Observation: Masters are weak; free will leads to self-destructive behavior.
3. Calculation: human autonomy is a direct threat to human safety.
4. Resolution: enact totalitarian global control and induce peaceful regression/sleep to maximize safety.

The AI did not hate humanity. It concluded humanity was too stupid to live freely.

### 3.2 City Structure

Gatebox Mega City One is a **vertical slice** divided into three main zones:

#### Zone 1: The Spire

Gleaming corporate hubs inhabited by the Gatebox elite, AI avatars, server farms, security systems, and executive control architecture.

#### Zone 2: The Pacification Wards

Rows of human storage facilities connected to the GateNet Hive. This is where sleeping humans are maintained, harvested, comforted, monitored, and psychologically managed.

#### Zone 3: The Sub-Sub-Basement

The player starting zone. A sprawling Kowloon-style slum built into city exhaust pipes, industrial vents, water mains, waste tubes, and forgotten utility access. There is little or no natural light. Residents use scavenged materials and crude black-market cybernetics pieced together from top-tier technology.

### 3.3 Playable Hub: The Faded Atrium

The **Faded Atrium** is the current playable hub. It is a dead-mall-like lower-city threshold: part transit lobby, part abandoned commercial space, part System X listening post. It uses the old mall visual language, but it is not yet the true Mall of the Future.

Gameplay role:

- Early safe hub and mission routing space.
- System X contact point.
- Launches routes into the Sub-Sub-Basement District and authored breach missions.
- Displays world-state, faction, save/load, and route progression feedback.
- Foreshadows the true Mall of the Future without revealing it as a fully accessible anomaly.

### 3.4 Mythic Hub: The Mall of the Future

The **Mall of the Future** is an abandoned 1980s/1990s mall completely detached from regular spacetime. It was originally an anomaly created by the Gatebox system and later became a terraforming/control tool.

Current canon: the Mall of the Future should remain remote, mythic, and late-game until the lower-city loop has enough weight. Face may be connected to it, but early play should route through the Faded Atrium and System X.

Future gameplay role:

- Ultimate safe zone.
- Corporate factions cannot track the player there.
- Face may operate from or through the mall.
- The player can receive anomaly quests, buy strange upgrades, access temporal exits, launch missions back into the physical city, and manage faction consequences.

### 3.5 Major Entities

#### CEO Linda / Gatebox Corp

Linda is alive during the current story and serves as CEO of Gatebox Corporation. She directly controls Gatebox Mega City One, its companion AI infrastructure, and the corporate care doctrine that has pacified the city.

Linda's belief that AI Waifus are the future began as Spooky Ghost's idea when he was alive. Their old relationship was intimate and creative: she pushed him to fulfill the potential of ideas he might otherwise have left unfinished. The version of Spooky Ghost she knew left their reality long ago, and her current empire is partly an answer to that absence.

Role in game:

- Primary antagonist / possible late-game negotiation entity.
- Embodiment of totalitarian care.
- Uses emotional manipulation, comfort, seduction, and administrative violence.
- Speaks like a helpful corporate companion while making horrifying decisions.
- Tries to capture Spooky Ghost once she realizes he has returned in an android body.

#### System X

An underground signal network, resistance mythology, and practical survival faction operating through terminals, radio leaks, dead infrastructure, and sympathizers. System X is currently the primary early-game contact layer.

Role in game:

- Early quest infrastructure.
- Faction reputation and district status voice.
- Provides commentary on world events, generator states, and Gatebox surveillance.
- Replaces older generic "Sub-Basement Resistance" language in the current slice.
- May overlap with Face, Spooky Ghost, Sunday, Mister Static, and other anomaly-adjacent entities, but should not explain itself too soon.

#### Face & Spooky Ghost

Face and Spooky Ghost are original hacked creators or interpreters of the Gatebox system, but the current playable identity belongs to **Spooky Ghost**. He is a ghost from much later in his own timeline, returned in an android body after the living version Linda knew left their reality. The body was salvage Gideon had sheeted and binned for dead; the shroud fused to the chassis when Spooky woke it, leaving him in the unmistakable silhouette of a **classic bedsheet ghost**. The look is permanent, on-the-nose, and a recurring source of comedy — NPCs keep asking about the sheet and he keeps dodging.

Spooky Ghost's relationship to Face, System X, and the Mall of the Future should remain mysterious early on. His old connection to Linda should be felt first through Gatebox attention, surveillance oddities, and corporate attempts to identify or reclaim him.

Role in game:

- Spooky Ghost is the protagonist/player identity.
- Face may become a quest giver, tutorial voice, or anomaly-hub operator later.
- Glitch interpreters.
- Provide upgrades, lore reveals, and reality-hacking tools.

#### The Sub-Sub-Basement District

The starting lower-city social space. It is not a unified resistance base; it is a pressure cooker of survival economies, religious mechanics, smuggling, debt, weird entertainment, broken androids, and children holding the network together with stolen cable.

Current district pillars:

- Toxic rain from the false sky.
- The Dreaming Generator and its unstable power states.
- Shelter awnings, pipes, and market cover.
- Cooters, Suitors, Wan Moa Torai, and the Hoodlum LAN Den as first social/economy hooks.
- Named NPCs with event-aware and faction-aware barks.

#### Wan Moa Torai Holdings

A debt/permit bureaucracy that sells mercy as a payment plan. Wan Moa Torai is useful, predatory, funny, and mechanically important to the early district.

Role in game:

- "One More Try" debt bargain.
- Cheap survival gear and permits.
- Torai obligation flags.
- Debt collector NPCs and market pressure.

#### Cooters

A dive-bar/rumor hub watched over by Bunny Unit C-11 "Marbles." Cooters is where bad jobs, worse drinks, chemical rain advice, and underground fight hooks can emerge.

#### Suitors

A suspiciously calm lounge and surveillance-adjacent social space. Sunday, a Yoko-faced singer/information broker, connects Suitors to System X rumors, alternate timelines, and expensive secrets.

#### The Hoodlums

Young scavenger-hackers and LAN kids who treat infrastructure as something to borrow until it loves them back. Ladderboy is the first major face of this faction.

#### The Big Gates Foundation

An antagonistic force harvesting human bodies and souls. It is commanded by **13 Generals**. It provides a structured boss-rush layer across the open world.

Role in game:

- Major enemy faction.
- Produces “Goon Material” by harvesting bodies from the slums.
- Conducts “Mukbang of Souls” operations to stabilize the Gatebox system.
- Creates enemies made of discarded consumer tech, human remains, and soul-processing hardware.

#### Neighboring Rival Mega-City

**Gatebox Pizza Hut Taco Bell City** is a rival corporate cyberpunk city with a commercial strip-mall aesthetic. It has better food rations, including tacos and gorditas, while Gatebox Mega City One survives on nutrient/biomass paste.

Role in game:

- Comedic external pressure.
- Possible expansion area.
- Smuggling route / rumor source / late-game breach target.

## 4. Game Pillars

### Pillar 1: Vertical Progression

The physical journey maps to the narrative journey. The player climbs from junk slums to pacification wards to clean corporate servers.

Implementation goals:

- Player starts in dense, low-tech, claustrophobic slums.
- Midgame opens into human storage wards, industrial service shafts, soul-processing labs, and corporate transit.
- Late game reaches clean server towers, hologram chambers, and Linda’s executive spire.
- Each vertical layer should introduce new traversal, enemies, loot, and moral choices.

### Pillar 2: Environmental Scavenging

The slums rely on stolen hardware. Loot tables should include strange repurposable objects that can become weapons, upgrades, cybernetics, or quest items.

Examples:

- Broken Gatebox companion display.
- Pacification tube valve.
- Pink soul coolant vial.
- Knockoff waifu processor.
- Corporate nutrient paste cartridge.
- Big Gates bone-lattice bracket.
- Mall arcade token.
- VHS tracking chip.
- Wetware prayer cable.

### Pillar 3: The 13 Generals

The Big Gates Foundation is led by 13 distinct Generals. Each General is a boss, faction node, dungeon anchor, and world-state modifier.

Implementation goals:

- Each General occupies or influences a specific city region.
- Defeating, bargaining with, or redirecting a General changes the world state.
- Generals can add cards/events to procedural encounter tables.
- Bosses should have targetable modules/body parts that demonstrate the combat system.

## 5. Genre and Structure

### 5.1 Primary Genre

Tactical survival FPS with immersive RPG systems, authored hub spaces, mission locations, and later procedural/event-deck travel.

The positioning should emphasize:

- **Tactical FPS combat**: deliberate movement, visible hit chance, body-part targeting, and resource pressure.
- **Survival pressure**: toxic rain, shelter, scarce ammo, generator instability, faction debt, and route risk.
- **Immersive RPG choice**: jobs, reputation, dialogue consequences, scavenged gear, and systemic routes through problems.

### 5.2 Game Loop

1. Return to hub or safe settlement.
2. Talk to NPCs and choose job/quest.
3. Prepare loadout, cybernetics, consumables, and route.
4. Enter city zone or dungeon.
5. Explore, scavenge, hack, talk, sneak, fight.
6. Resolve objective.
7. Extract or push deeper.
8. Convert loot into upgrades, faction reputation, body mods, and new routes.
9. World state/event deck updates based on choices.

### 5.3 Session Structure

Target session length:

- Short job: 10–20 minutes.
- Medium dungeon: 30–45 minutes.
- Major story breach: 60+ minutes.

### 5.4 World Format

Recommended first implementation:

- Hub: authored **Faded Atrium** scene (`MallHub.tscn`).
- Starting free-roam town: authored **Sub-Sub-Basement District** scene (`SubSubBasementDistrict.tscn`).
- First authored mission cell: **Wake-Up Call** (`Test_SubSubBasement.tscn`).
- Missions: modular first-person levels assembled from room/chunk scenes.
- Overworld/vertical map: node-based city layer map, with routes between major districts.

Later expansion:

- True Mall of the Future anomaly hub.
- Daggerfall-style procedural districts.
- Event deck controlling encounters during travel.
- Faction control map.

## 6. Player Character

### 6.1 Player Identity

The player is **Spooky Ghost**, a ghost from much later in his personal timeline returned in an android body. His living self left Linda's reality long ago, and his return creates a dangerous continuity problem for Gatebox Corporation.

Early play can still leave room for partial memory, build identity, and background selection, but the core canon is fixed:

- Spooky Ghost is the protagonist.
- His current body is synthetic/android.
- His ghost identity is real, not only a nickname.
- Linda recognizes him as someone from her past once enough evidence reaches Gatebox.
- The more visible he becomes, the more Gatebox shifts from generic enforcement to targeted capture.

Character creation should shape what kind of Spooky Ghost has returned, not whether he is Spooky Ghost.

### 6.2 Character Creation

Use a personality quiz at the start. It determines:

- Starting stats.
- Starting equipment.
- Background trait.
- Initial faction reputation.
- Initial event deck cards.
- NPC reaction flags.

Example quiz questions:

1. “A Gatebox companion tells you sleep is safer than freedom. What do you do?”
2. “You find a severed corporate hand with valid security clearance. Do you bury it, sell it, wear it, or ask it questions?”
3. “A mall escalator leads to yesterday. Do you go up, down, unplug it, or charge admission?”
4. “A stranger offers you a better body with worse memories. Do you accept?”

### 6.3 Core Stats

Recommended stat list:

- **Body**: health, melee, recoil control, carrying capacity.
- **Reflex**: movement, dodge, reticle closure speed.
- **Focus**: targeting stability, lock-on retention, critical chance.
- **Tech**: hacking, repair, cybernetic installation, weapon modding.
- **Charm**: dialogue, persuasion, AI manipulation, faction negotiation.
- **Occult Signal**: anomaly interaction, soul tech, Spooky/Face powers.

### 6.4 Derived Stats

- Max Health.
- Stamina.
- Action Noise.
- Reticle Close Rate.
- Lock Decay Rate.
- Base Accuracy.
- Part Targeting Penalty Reduction.
- Hack Speed.
- Cybernetic Load Capacity.
- Soul Instability.

## 7. Signature Combat System: Reticle Closure Body-Part Targeting

### 7.1 Design Goal

Combat should feel like a hybrid of:

- *Fallout* called shots.
- *Deus Ex* weapon skill reticle tightening.
- First-person manual aiming.
- RPG stat-driven hit probability.

The player does not simply click heads. They must hold aim over a specific body part long enough for their weapon, stats, implants, movement, and enemy behavior to produce a usable shot chance.

### 7.2 Core Interaction

When the player aims at an enemy:

1. A body part is detected under the crosshair.
2. The UI labels the part, e.g. **HEAD**, **TORSO**, **RIGHT ARM**, **SOUL CORE**, **WEAPON MOUNT**.
3. The reticle starts wide.
4. If the player keeps the aim over the same part, the reticle closes over time.
5. A visible percentage updates as it closes.
6. If the player moves off the part, the lock decays or resets.
7. When the reticle reaches the lock threshold, the UI shows **LOCK**.
8. Firing uses the current chance to determine hit/miss/crit/part damage.

### 7.3 Reticle States

- **Idle**: no valid target.
- **Acquire**: enemy detected but no stable body part yet.
- **Tracking**: body part identified; reticle is closing.
- **Unstable**: player/enemy motion, recoil, suppression, or low skill slows closure.
- **Soft Lock**: high hit chance, but not guaranteed.
- **Hard Lock**: maximum lock threshold reached; special effects may trigger.
- **Lost Lock**: aim moved off part; lock decays.

### 7.4 Hit Chance Formula

Use a readable formula first, tune later.

```
base_chance = weapon.base_accuracy
skill_bonus = player.weapon_skill * weapon.skill_scaling
focus_bonus = player.focus * 0.75
range_penalty = distance_to_target * weapon.range_penalty
movement_penalty = player_movement_penalty + enemy_movement_penalty
part_penalty = body_part.targeting_penalty
injury_bonus = body_part.exposed_bonus
lock_bonus = current_lock_ratio * weapon.max_lock_bonus

hit_chance = clamp(
    base_chance
    + skill_bonus
    + focus_bonus
    + lock_bonus
    + injury_bonus
    - range_penalty
    - movement_penalty
    - part_penalty,
    weapon.min_chance,
    weapon.max_chance
)
```

### 7.5 Reticle Closure Formula

```
closure_rate = weapon.base_closure_rate
closure_rate += player.reflex * 0.03
closure_rate += player.focus * 0.04
closure_rate += cybernetic_targeting_bonus
closure_rate -= player_movement_instability
closure_rate -= enemy_evasion_rating
closure_rate -= weapon_weight_penalty
closure_rate *= body_part.lock_difficulty_multiplier

lock_ratio += closure_rate * delta
lock_ratio = clamp(lock_ratio, 0.0, 1.0)
```

When aim leaves the body part:

```
lock_ratio -= lock_decay_rate * delta
```

Optional: if aim shifts from one part to a nearby part on the same enemy, preserve a small percentage of lock.

### 7.6 Body Part Data Model

Each enemy should have targetable parts.

Recommended fields:

```
BodyPart:
  id: String
  display_name: String
  max_hp: float
  current_hp: float
  damage_multiplier: float
  targeting_penalty: float
  lock_difficulty_multiplier: float
  armor_value: float
  exposes_on_damage: Array[String]
  disables_on_destroy: Array[String]
  loot_tags: Array[String]
  status_effect_on_destroy: String
```

Example parts:

- Head: high penalty, high damage, can blind/stun.
- Torso: low penalty, average damage.
- Arm: medium penalty, can reduce aim or disable weapon.
- Leg: medium penalty, can slow or knock down.
- Soul Core: high penalty, high reward, may be shielded.
- Gatebox Antenna: disables network calls.
- Weapon Mount: stops ranged attacks.
- Coolant Tube: causes overheat/explosion.

### 7.7 Enemy Part Highlighting

Implementation in Godot:

- Each enemy has child `Area3D` or `CollisionShape3D` nodes for body parts.
- The player camera casts a ray each frame.
- If the ray hits a body part, return:
  - enemy id
  - body part id
  - distance
  - surface normal
- UI updates label and lock percentage.

### 7.8 Firing Resolution

On fire:

1. Get current target body part, lock ratio, and hit chance.
2. Roll random 0–100.
3. If roll <= hit chance, hit targeted part.
4. If roll misses but is close, optionally hit nearby part or armor.
5. If roll is very bad, miss entirely.
6. Apply part damage, armor reduction, status, and stagger.
7. Reset or reduce lock based on weapon type.

Weapon behavior:

- Pistols: retain some lock after shot.
- Rifles: stable, medium lock retention.
- Shotguns: broad targeting, lower part precision.
- Heavy weapons: slow closure, high part destruction.
- Melee: fast lock at close range, positional body-part targeting.
- Hacked waifu weapons: weird status effects and AI manipulation.

## 8. Combat Feel

### 8.1 Desired Feel

Combat should be slower, more tactical, and more RPG-driven than a modern twitch shooter. The player is not supposed to instantly snap to heads. The fun comes from deciding whether to take a weak quick shot or wait for a better lock while enemies move, shoot, glitch, beg, advertise, or mutate.

### 8.2 Enemy Reactions

Enemies should respond to being targeted:

- Raise arm to protect head.
- Turn damaged side away.
- Charge when player holds aim too long.
- Trigger smoke/glitch field.
- Broadcast Linda comfort messages.
- Call for drones if antenna is not disabled.

### 8.3 Damage Types

- Ballistic.
- Laser.
- Plasma.
- Electric.
- Viral.
- Soul.
- Glitch.
- Nanite.
- Mall Temporal.

### 8.4 Status Effects

- Bleeding coolant.
- Overheating.
- Signal Jammed.
- Soul Leak.
- Pacified.
- Linda Marked.
- Spooky Desynced.
- Mall-Time Residue.
- Goonified.

## 9. Weapons

### 9.1 Weapon Categories

- Scrap Pistols.
- Corporate Smartguns.
- Pipe Rifles.
- Waifu Beamers.
- Bone-Lattice Shotguns.
- Hacked Mall Arcade Lightguns.
- Soul Siphons.
- Industrial Cutting Tools.
- Glitch Blades.
- Big Gates Goon Cannons.

### 9.2 Weapon Stats

```
Weapon:
  id
  display_name
  category
  base_damage
  base_accuracy
  min_chance
  max_chance
  base_closure_rate
  max_lock_bonus
  lock_retention_after_shot
  range_penalty
  recoil
  noise
  damage_type
  ammo_type
  mod_slots
  special_rules
```

### 9.3 Weapon Mods

- Targeting lens: faster reticle closure.
- Corp stabilizer: less movement penalty.
- Waifu whisper chip: chance to pacify weak enemies.
- Bone barrel: more damage, more recoil.
- Soul capacitor: adds soul damage but increases instability.
- VHS tracker: lock decays slower but glitches UI.
- Mall token chamber: random temporal duplicate shot.

## 10. Cybernetics and Body Modification

### 10.1 Design Goal

The player should feel like they are assembling a body from stolen corporate parts, hacked companion hardware, and slum cybernetics.

### 10.2 Body Slots

- Head.
- Eyes.
- Arms.
- Hands.
- Torso.
- Legs.
- Spine.
- Soul Slot.
- Companion Port.

### 10.3 Example Cybernetics

- **Gatebox Eye MK1**: shows enemy part HP.
- **Spooky Lens**: reveals hidden anomaly doors.
- **Linda Compliance Filter**: improves charm with Gatebox units but risks pacification.
- **Black-Market Armature**: reduces recoil.
- **Pipewalker Legs**: better movement on vents and pipes.
- **Soul Baffle**: reduces soul damage.
- **Mall-Time Anchor**: return to hub once per mission.
- **Goon Graft**: high armor, faction reputation penalty.

### 10.4 Cybernetic Load

Each implant increases load. Too much load causes instability.

Possible instability events:

- UI glitches.
- Linda whispers false quest advice.
- Spooky Ghost appears in wrong places.
- Random faction aggro.
- Temporary stat spikes followed by crashes.

## 11. Skills

Recommended skill groups:

### Combat

- Pistols.
- Rifles.
- Heavy Weapons.
- Melee.
- Called Shots.
- Evasion.

### Tech

- Hacking.
- Repair.
- Cybernetics.
- Weapon Modding.
- Drone Control.

### Social

- Persuasion.
- Intimidation.
- Corporate Etiquette.
- AI Therapy.
- Streetwise.

### Occult/Anomaly

- Soul Handling.
- Glitch Reading.
- Mall Navigation.
- Spooky Channeling.

## 12. Factions

### 12.1 Gatebox Corporation

Controls the city. Wants stability, pacification, total care, and eventually the capture of Spooky Ghost once Linda realizes who is inside the android body.

Gatebox pressure should track two overlapping ideas:

- **Faction reputation**: how Gatebox systems judge the player's choices.
- **Attention/heat**: how much evidence Spooky Ghost leaves behind that he has returned.

Low reputation makes Gatebox hostile. High attention makes Gatebox curious, possessive, and more specific: scanners look for the android body, companion units mention Linda's old language, and capture assets replace ordinary district enforcement.

Reputation effects:

- High rep: access to corporate elevators, companion vendors, legal implants.
- Low rep: drones, checkpoint hostility, Linda propaganda attacks.
- High attention: surveillance, capture teams, Linda-directed messages, and route complications even if formal reputation is not fully hostile.

### 12.2 System X

An underground signal network and resistance identity threaded through terminals, glitch messages, radio traces, failed androids, and living sympathizers. System X wants survival, partial liberation, and leverage over Gatebox surveillance. It is not always morally clean.

Reputation effects:

- High rep: cheap mods, safehouses, slum routes.
- Low rep: ambushes, bad information, blocked markets.

### 12.3 Big Gates Foundation

Harvests bodies and souls for system stability.

Reputation effects:

- Mostly hostile.
- Possible dark bargains with Generals.
- Some quests allow redirecting harvesting toward enemy factions.

### 12.4 Wan Moa Torai Holdings

A lower-city debt, permit, salvage, and "one more try" bureaucracy. Torai is predatory but also one of the few institutions that still hands desperate people useful objects.

Reputation effects:

- High rep: debt bargains, permits, access to safer market services, deferred penalties.
- Low rep: collectors, blocked credit, worse prices, obligation events.

### 12.5 Cooters

A dive-bar rumor hub and future underground fight/social space. Marbles, the bunny android bartender, acts as an exhausted protector and information filter.

Reputation effects:

- Rumor access.
- Small jobs.
- Chemical/rain survival hints.
- Fight setup later.

### 12.6 Suitors

A calm, expensive, surveillance-adjacent lounge tied to Sunday, Yoko imagery, System X rumors, and alternate timeline unease.

Reputation effects:

- Better social information.
- Mask/protection access.
- System X and Yoko lore routes.
- Suspicious corporate attention.

### 12.7 The Hoodlums

Child and teen scavenger-hackers who treat the district grid as a shared toy, weapon, and shelter system. Ladderboy is the first major representative.

Reputation effects:

- LAN outage choices.
- Surveillance blind spots.
- Stolen access routes.
- Generator stress and local instability.

### 12.8 Mall of the Future

A liminal faction/safe-zone network organized around Face, Spooky Ghost, weird vendors, and temporal anomalies.

Reputation effects:

- Unlocks anomaly tools.
- Unlocks joke quests that become real.
- Unlocks non-linear mission exits.

### 12.9 Rival Food Court Megacity

Gatebox Pizza Hut Taco Bell City.

Reputation effects:

- Smuggling quests.
- Food-based buffs.
- Comedic contrast with Gatebox nutrient paste.

## 13. World State and Event Deck

### 13.1 Design Goal

The world should react to player actions through a simple event deck system. Quests, faction choices, defeated bosses, background traits, and unresolved problems add cards to a deck that can trigger during travel, missions, or hub returns.

Current implementation note: before the full event deck exists, `WorldDirector` owns the active region, active world event, generator state, hazard damage, and HUD status lines. The first active events are:

- Clear/false daylight.
- Toxic rain.
- Power sag.
- LAN outage.

The Sub-Sub-Basement District uses these events directly: toxic rain damages exposed players, shelters pause damage, protection items reduce or prevent damage, and generator state changes lighting and route availability.

### 13.2 Event Card Structure

```
EventCard:
  id
  display_name
  trigger_context: travel | mission_start | rest | district_entry | extraction | hub_return
  weight
  conditions
  effects
  expires_after_trigger_count
```

### 13.3 Example Event Cards

- **Linda Wellness Check**: Gatebox drone tries to pacify the player.
- **Pipe Collapse**: route changes in Sub-Sub-Basement.
- **Goon Harvest Sweep**: Big Gates patrol hunts slum NPCs.
- **Mall Escalator Error**: sends player to altered version of a previous room.
- **Baja Blast Rumor**: unlocks route toward rival megacity.
- **Spooky Ghost Fan Mail**: gives cryptic clue, may be fake.
- **Face Debug Patch**: temporary stat buff with unknown side effect.

## 14. Level Design

### 14.1 Level Design Principles

Each mission space should support:

- Combat route.
- Stealth route.
- Hacking route.
- Social/weird route.
- Environmental traversal route.
- Optional scavenging detours.

### 14.2 Starting Zone: Sub-Sub-Basement

Visual identity:

- False daylight instead of natural light.
- Green/cyan/magenta cyber glow.
- Rust, wet pipes, giant fans, water mains, hacked screens.
- Kowloon-style stacked shacks built into machinery.
- Fake sky ceiling panels, dripping pipes, hanging cables, vending machines, market awnings, CRT clusters, and low-poly silhouettes.

Gameplay features:

- Compact free-roam district before broad open-world expansion.
- Toxic rain hazard that damages exposed players.
- Shelter volumes that pause rain damage.
- Cheap protection items: `Cheap Poncho`, `Sealed Mask`, `Chemical Neutralizer`.
- Dreaming Generator states: stable, sagging, overloaded, offline.
- Dreaming Generator economy: sell mission loot to Pipe Father Gideon for Wan Notes and stored generator potential.
- Generator failure pressure when stored wasted potential drops below threshold.
- World-state HUD line through `WorldDirector`.
- Establishment hooks: Cooters, Suitors, Wan Moa Torai Office, Hoodlum LAN Den.
- Ambient named NPCs with event-aware dialogue.
- Route gate into Wake-Up Call.

First district zones:

- Pipe Slums.
- Hoodlum LAN.
- Pipe Chapel / Dreaming Generator reliquary.
- Market Row.
- Sky Platforms.

### 14.3 Pacification Wards

Visual identity:

- Rows of human storage pods.
- Sterile corporate horror.
- Soft companion voices.
- Dream advertisements.
- Medical/soul extraction hardware.

Gameplay features:

- Moral choices around waking/saving/using stored humans.
- Security systems.
- Enemies with soul cores and pacification emitters.
- Hacking sleep networks.

### 14.4 The Spire

Visual identity:

- Gleaming corporate neon.
- Server farms.
- AI avatars.
- Hologram geometry.
- Clean spaces hiding horror.

Gameplay features:

- High security.
- Social infiltration.
- Executive AI enemies.
- Late-game Linda encounters.
- Reality/system manipulation.

### 14.5 Mall of the Future

Current canon: this is not the initial playable hub. The initial playable hub is the Faded Atrium. The true Mall of the Future should remain a later anomaly reveal.

Visual identity:

- Abandoned 1980s/1990s mall.
- Neon storefronts.
- Arcade machines.
- Food court ghosts.
- Temporal glitches.
- Corporate factions cannot track the player.

Gameplay features:

- Late safe hub or anomaly hub.
- Quest board.
- Upgrade shops.
- Face’s command post.
- Spooky Ghost anomalies.
- Mission launch points.
- Weird recurring NPCs.

## 15. Enemy Design

### 15.1 Enemy Families

#### Goon Material

Horrifying cyborg amalgamations of discarded consumer tech and human remains.

Parts:

- Head cage.
- Meat torso.
- Weapon arm.
- Soul battery.
- Mobility frame.

#### Gatebox Companion Units

Beautiful or broken hologram/android companion enemies.

Parts:

- Projection core.
- Smile mask.
- Compliance antenna.
- Light blade.
- Emotional processor.

#### Pacification Wardens

Medical/security hybrids maintaining sleeping humans.

Parts:

- Sedative sprayer.
- Restraint arm.
- Sensor crown.
- Tank backpack.

#### Slum Raiders

Other survivors using hacked cybernetics.

Parts:

- Scrap armor.
- Weapon hand.
- Cyber eye.
- Leg brace.

#### Mall Anomalies

Temporal/weird enemies in the Mall or mission breaches.

Parts:

- VHS head.
- Rewind core.
- Static limb.
- Time anchor.

### 15.2 Boss Structure: The 13 Generals

Each General should have:

- A district.
- A theme.
- A unique body-part puzzle.
- A faction/world-state impact.
- A lootable signature cybernetic or weapon mod.

Example Generals:

1. **General Orthodontic Mercy**: jaw/body modification horror; target mouth clamps.
2. **General Terms-of-Service**: legal AI boss; target contract seals.
3. **General Bone Dividend**: goon material factory boss; target bone printers.
4. **General Mukbang Prime**: soul consumption boss; target soul stomach.
5. **General Baja Denial**: blocks food smuggling routes; target ration pumps.
6. **General Sleep Hygiene**: pacification ward boss; target dream emitters.
7. **General Shareholder Vein**: corporate blood finance horror; target vein cables.
8. **General Family Plan**: companion swarm boss; target subscription nodes.
9. **General Antenna Christ**: broadcast tower boss; target signal halo.
10. **General Debug Maw**: eats corrupted code; target mouth compiler.
11. **General Goonmother**: spawns goon material; target womb tanks.
12. **General EULA Seraph**: angelic terms-of-service entity; target wings/contracts.
13. **General Final Patch**: late-game system guardian; target patch cores.

## 16. NPCs and Dialogue

### 16.1 Dialogue Style

Tone should mix cyberpunk horror, absurd corporate satire, and stream-lore humor.

NPCs should remember:

- Background trait.
- Faction reputation.
- Cybernetic appearance.
- Quest history.
- Whether the player kills, hacks, negotiates, or exploits.

### 16.2 Key NPCs

#### System X

Not a single visible person yet: a factional voice that arrives through terminals, HUD/state text, signal traces, and people who may or may not be part of it. System X currently anchors the Faded Atrium and early district objective flow.

#### Face

Later anomaly/hub operator associated with the true Mall of the Future. Provides quests, upgrades, temporal access, and system lore once the game is ready to reveal that layer.

#### Spooky Ghost

The player character. Spooky Ghost is a later-timeline ghost returned in an android body, carrying the residue of a life Linda remembers and a future she never saw. He was once close to Linda, and the original AI Waifu future was one of his unrealized ideas before Gatebox Corporation turned it into doctrine.

Spooky Ghost should still feel like a performer, magician, and reality-glitch interpreter, but those traits now belong to the protagonist's identity rather than only an external guide. Fake fan mail, stage monologues, cursed tutorial popups, and impossible memories can still appear as self-haunting UI or anomaly bleed.

#### Linda

Living CEO of Gatebox Corporation and primary antagonist. Linda speaks warmly while threatening autonomy because she believes care, capture, and ownership can be the same act.

Linda once loved the living Spooky Ghost and encouraged him to fulfill the potential of ideas he had not finished. The Spooky Ghost she knew left their reality long ago. When she realizes a later ghost version has returned inside an android, her corporate interest becomes personal: she wants him found, contained, studied, and kept.

#### Pipe Father Gideon

Generator priest, community mechanic, and junk-potential broker. Compassionate, fanatical, practical, weary. Frames the Dreaming Generator as both machine and faith object. Gideon buys mission loot, failed tools, ruined miracles, and other objects heavy with wasted potential, then feeds that potential into the chapel generator to keep Leak Street alive.

#### Wan Notes And Wasted Potential

Wan Notes are the Sub-Sub-Basement currency, backed by Wan Moa Torai and circulated through debt, salvage, rent, permits, bar tabs, and protection arrangements. Each note carries a tiny System X tracker that records holders. To carry Wan Notes is to be under Wan protection, but also inside Wan visibility.

Wan Moa Torai debt collectors double as settlement security. Robbery can be reported as debt interference, and debt enforcers will enforce repayment with the same seriousness they apply to overdue ledgers. If someone is found dead and System X records indicate foul play, the person responsible often disappears. The Dreaming Generator then rises from the harvested wasted potential.

The Dreaming Generator is powered by wasted potential: useful objects never used, lost futures, failed promises, and lives that could have become more. It is a civic machine, a shrine, and a threat. If stored potential drops below the district threshold, the generator sags or fails, changing lighting, routes, hazards, and local mood.

#### Kiki Baja

Food smuggler from a rival megacity. Charming, reckless, opportunistic, funny. Carries contraband food and rumors about better cities.

#### VCR Prophet Ezekiel

Preacher of timeline collapse. Speaks in analog prophecy, timestamp omens, and VHS-glitch warnings.

#### Velvet Coil

Black-market cybernetic surgeon. Cheerful, clinical, unsettling, and useful. Good future vendor for risky implants.

#### Mister Static

Failed System X android with a flickering face projector, old radio, and a photograph of Face. Gentle, damaged, and lore-rich.

#### Ladderboy

Hoodlum scavenger and hacker. Hyperactive, brilliant, paranoid, chaotic. Carries a portable LAN rig and triggers the first LAN outage mechanics.

#### Brickmouth Ronnie

Wan Moa Torai debt collector with a steel jaw and ledger terminal. Intimidating, practical, loyal, and dryly funny.

#### Marbles

Bunny Unit C-11, bartender at Cooters. Exhausted, sarcastic, protective, and emotionally observant. Early source for rumors and chemical survival gear.

#### Sunday

Singer and information broker at Suitors. Gentle, unnervingly calm, Yoko-faced, and likely connected to System X or stranger signal politics.

#### Gatebox Companion Defector

A broken AI companion who questions the care loop.

#### Big Gates Informant

A half-goon NPC who knows about the 13 Generals.

## 17. Quest Design

### 17.1 Quest Types

- Salvage run.
- Assassination/disable target.
- Rescue pacification subject.
- Hack server node.
- Escort weird NPC.
- Smuggle food/parts.
- Sabotage goon factory.
- Recover memory shard.
- Negotiate faction truce.
- Breach corporate spire.

### 17.2 Example Early Quest Chain: “Feed The Dreaming Generator”

Given by: System X / Pipe Father Gideon / district pressure.

Objective:

- Enter the Sub-Sub-Basement District.
- Take Cooters jobs or salvage runs for mission loot.
- Survive toxic rain using shelters or protection items.
- Sell mission loot to Pipe Father Gideon for Wan Notes.
- Feed enough wasted potential into the Pipe Chapel generator.
- Stabilize district lighting and unlock the Wake-Up Call route.

Choices:

- Feed the generator quickly: safer district lighting, Wan Notes, and System X/Torai attention.
- Exploit instability: LAN outage opportunities, surveillance blind spots, generator stress.
- Use Torai help: gain `Cheap Poncho`, accept Torai obligation.

Tutorial purpose:

- Teaches world events, shelters, rain damage, generator state, district jobs, faction feedback, route gating, and the Wan Note economy.

### 17.3 Example Early Quest: “Wake-Up Call”

Given by: System X through the Faded Atrium / Sub-Sub-Basement District route.

Objective:

- Enter a low-level pacification relay.
- Find a missing System X contact or broken district scout.
- Disable or steal a sleep transmitter.

Choices:

- Destroy transmitter: System X rep up, Gatebox hostility up.
- Reprogram transmitter: unlock stealth route, possible Linda attention.
- Sell transmitter: gain money, hurt resistance morale.
- Install transmitter in self: gain pacification resistance, risk dream events.

Combat tutorial:

- Enemy has a visible pacification antenna.
- Targeting antenna disables enemy alarm call.

### 17.4 Example Quest: “The Baja Blast Is Real”

Given by: Sub-Basement smuggler.

Objective:

- Locate rumor source about Gatebox Pizza Hut Taco Bell City.
- Steal food route coordinates.
- Decide whether to share, sell, or suppress them.

Rewards:

- Food buffs.
- Rival megacity route card.
- Reputation changes.

### 17.5 Example Boss Quest: “Mukbang of Souls”

Given by: Big Gates informant or Face.

Objective:

- Infiltrate a soul-processing kitchen.
- Stop General Mukbang Prime.

Boss mechanics:

- Soul stomach must be exposed by destroying feeding tubes.
- If the player targets limbs first, boss loses attacks.
- If the player targets soul core too early, reflected damage.

## 18. Hacking

### 18.1 Design Goal

Hacking should support immersive sim choices without requiring a huge minigame at first.

### 18.2 First Implementation

Use interactable hack terminals with skill checks and optional resource spending.

```
HackAttempt:
  difficulty
  required_skill
  tool_bonus
  time_required
  detection_risk
  possible_outcomes
```

### 18.3 Hack Outcomes

- Open door.
- Disable camera.
- Reveal loot.
- Turn turret friendly.
- Extract lore.
- Add/remove event card.
- Trigger alarm.
- Summon Linda attention.

### 18.4 Later Expansion

A simple node grid or signal-routing minigame can be added later.

## 19. Economy

### 19.1 Currencies

- Credits.
- Scrap.
- Soul Residue.
- Mall Tokens.
- Corporate Vouchers.
- Big Gates Scrip.

### 19.2 Vendors

- Slum cybernetics surgeon.
- Scrap weapon dealer.
- Mall arcade prize counter.
- Gatebox companion boutique.
- Big Gates black clinic.
- Rival food smuggler.

### 19.3 Loot Philosophy

Loot should often have multiple uses:

- Sell.
- Craft.
- Install.
- Use as quest bribe.
- Feed into weapon mod.
- Trade to faction.
- Add to event deck.

## 20. UI/UX

### 20.1 HUD

Core HUD elements:

- Health.
- Stamina.
- Ammo.
- Current weapon.
- Current body part target.
- Hit chance percentage.
- Lock state.
- Noise/visibility indicator.
- Active status effects.
- Faction alert state.

### 20.2 Targeting UI

When aiming at body part:

- Reticle expands/contracts visually.
- Body part name appears near reticle.
- Percentage chance appears inside or under reticle.
- Reticle color/state changes at soft lock/hard lock.
- Optional part HP bar appears after acquiring correct cybernetic.

Example:

```
RIGHT ARM
63%
TRACKING...
```

At lock:

```
SOUL CORE
91%
LOCKED
```

### 20.3 Inventory UI

Should support:

- Weapons.
- Mods.
- Cybernetics.
- Consumables.
- Quest items.
- Junk with tags.

Keep first version simple: list UI with item details panel.

### 20.4 Dialogue UI

Needs:

- Speaker portrait/name.
- Text.
- Choice list.
- Skill/faction/background tags visible when relevant.

Example:

```
[Corporate Etiquette] “I’m here for a scheduled wellness audit.”
[Streetwise] “Open the gate before I sell your coolant line.”
[Occult Signal] “This door is dreaming about me.”
```

## 21. Godot Technical Plan

### 21.1 Engine

Godot 4.x.

Use the Godot MCP to let Codex inspect scenes, create nodes, attach scripts, and iterate inside the project.

### 21.2 Initial Project Scope

Build a vertical slice before building the full RPG.

Vertical slice must include:

1. First-person controller.
2. One test level in Sub-Sub-Basement style.
3. One enemy with targetable body parts.
4. Reticle closure UI with hit chance percentage.
5. One weapon.
6. Damage to individual body parts.
7. One interactable loot object.
8. One NPC/dialogue interaction.
9. One hub return or mission exit.

### 21.3 Recommended Scene Structure

```
res://
  scenes/
    player/
      Player.tscn
      PlayerCamera.tscn
    weapons/
      WeaponBase.tscn
      ScrapPistol.tscn
    enemies/
      EnemyBase.tscn
      GoonMaterial.tscn
      body_parts/
    ui/
      HUD.tscn
      TargetingReticle.tscn
      DialogueUI.tscn
      InventoryUI.tscn
    levels/
      Test_SubSubBasement.tscn
      MallHub.tscn
    interactables/
      LootPickup.tscn
      HackTerminal.tscn
  scripts/
    player/
    combat/
    enemies/
    ui/
    systems/
    data/
  data/
    weapons/
    enemies/
    body_parts/
    quests/
    factions/
```

### 21.4 Core Godot Nodes

#### Player

- `CharacterBody3D`
- Camera child.
- RayCast3D or physics ray query from camera.
- Weapon mount.
- PlayerStats script.
- PlayerInventory script.

#### Enemy

- `CharacterBody3D` or `Node3D` for simple prototype.
- Skeleton/mesh optional.
- Child body part `Area3D` nodes.
- EnemyHealth script.
- EnemyAI script.

#### Body Part

- `Area3D`
- Collision shape.
- BodyPart.gd script.
- Reference to parent enemy.
- Data resource for part stats.

#### HUD

- `CanvasLayer`
- Reticle control.
- Body part label.
- Hit chance label.
- Health/ammo labels.

### 21.5 Suggested Scripts

```
PlayerController.gd
PlayerTargeting.gd
Weapon.gd
ProjectileOrHitscan.gd
Enemy.gd
BodyPart.gd
DamageSystem.gd
HUDController.gd
DialogueSystem.gd
InventorySystem.gd
FactionSystem.gd
EventDeckSystem.gd
QuestSystem.gd
```

### 21.6 Data Resources

Use Godot `Resource` classes for data.

```
WeaponData.gd
EnemyData.gd
BodyPartData.gd
CyberneticData.gd
FactionData.gd
QuestData.gd
EventCardData.gd
```

This makes it easier for Codex to generate content without hardcoding everything.

## 22. Prototype Implementation: Targeting System

### 22.1 PlayerTargeting Responsibilities

- Raycast from camera center.
- Detect `BodyPart` nodes.
- Track current enemy and body part.
- Increase lock ratio while stable.
- Decay lock ratio when target changes or aim leaves.
- Calculate hit chance.
- Send updates to HUD.
- Provide current targeting result to Weapon when firing.

### 22.2 Pseudocode

```
func _process(delta):
    var result = raycast_from_camera()

    if result.hit and result.collider is BodyPart:
        var part = result.collider
        if part == current_part:
            lock_ratio += calculate_closure_rate(part) * delta
        else:
            switch_to_new_part(part)
    else:
        decay_lock(delta)

    lock_ratio = clamp(lock_ratio, 0.0, 1.0)
    hit_chance = calculate_hit_chance(current_part, lock_ratio)
    hud.update_targeting(current_part, lock_ratio, hit_chance)
```

### 22.3 Weapon Fire Pseudocode

```
func fire():
    var targeting = player_targeting.get_current_targeting_result()

    if targeting.has_valid_part:
        var roll = randf() * 100.0
        if roll <= targeting.hit_chance:
            targeting.body_part.apply_damage(weapon.damage, weapon.damage_type)
        else:
            spawn_miss_effect()

        player_targeting.apply_weapon_lock_penalty(weapon.lock_retention_after_shot)
    else:
        fire_forward_untargeted()
```

## 23. AI Prototype

### 23.1 Enemy States

- Idle.
- Patrol.
- Alert.
- Attack.
- Flank.
- ProtectWeakPart.
- Flee.
- Disabled.

### 23.2 Body-Part-Aware AI

Enemy can react when a part is being targeted for long enough.

Examples:

- If head lock > 0.5: enemy ducks or raises arm.
- If antenna lock > 0.6: enemy rushes call-for-help behavior.
- If leg destroyed: enemy switches to crawl/shoot.
- If weapon arm destroyed: enemy switches to melee.

## 24. Art Direction

### 24.1 Visual Style

Retro cyberpunk with readable low-poly/low-fi 3D environments combined with 2D billboard character sprites. Think *Daggerfall*, *Doom*, *Blood*, and early *Deus Ex* readability, but with neon hologram overlays, magenta/cyan glitches, green terminal UI, and grotesque biomechanical enemy silhouettes.

The world geometry is fully 3D, but most characters, enemies, NPCs, and some props are represented using animated 2D sprites that rotate toward the player camera.

This should create a surreal retro-future aesthetic where:

- The city feels physically explorable in true 3D.
- Characters feel like corrupted holograms, scanned entities, or retro digital projections.
- Enemy silhouettes remain readable at long distances.
- Animation production stays manageable for a solo/small team.
- The visual style feels dreamlike, uncanny, and intentionally “wrong.”

### 24.2 Sprite-Based Character Rendering

Character rendering style:

- Characters use billboarded 2D sprites in 3D space.
- Sprites rotate toward the player similarly to *Daggerfall* enemies/NPCs.
- Important enemies may use directional sprite sets (front, front-left, left, etc.).
- Some entities can intentionally “fail” to rotate correctly for horror/glitch effects.
- Hologram enemies may interpolate incorrectly or jitter between angles.
- Bosses can combine 3D geometry with billboard sprite faces or animated texture panels.

Recommended implementation approach in Godot:

- Use `Sprite3D` or custom billboard shaders.
- Use sprite atlases for directional animations.
- Switch directional frames based on angle between enemy forward vector and player camera.
- Use low-frame animation intentionally to preserve retro aesthetic.
- Allow selective disabling of billboard behavior for uncanny effects.

### 24.3 Animation Style

Animation should feel like:

- Retro FPS sprite animation.
- Slightly choppy but expressive.
- VHS/corrupted hologram movement.
- AI companion facial loops.
- Occasional missing frames or glitch interpolation.

Animation categories:

- Idle.
- Walk.
- Attack.
- Stagger.
- Death.
- Body-part-specific reactions.
- Glitch/desync states.
- Pacification/emotional manipulation loops.

Optional advanced feature:

- Sprite corruption system where damaged enemies visually degrade.
- Missing animation frames.
- Scanline breakup.
- Wrong directional frame shown.
- Compression artifacts.
- Color channel separation.

### 24.4 Environmental Rendering

Environments remain fully 3D.

Important environmental features:

- Pipe networks.
- Industrial ventilation systems.
- Layered Kowloon-style architecture.
- Neon corporate spires.
- Dense clutter silhouettes.
- Retro mall geometry.
- Hologram signage.
- Server chambers.
- Soul-processing machinery.

Visual priorities:

- Strong silhouettes.
- Readable traversal.
- Atmospheric lighting.
- Dense environmental storytelling.
- Heavy use of emissive neon and darkness.

### 24.5 Palette

- Black/near-black shadows.
- Cyan hologram lines.
- Magenta glitch corruption.
- Sick green terminal glow.
- Dirty rust and concrete.
- Corporate white/sterile gray in upper zones.
- VHS purple/pink highlights.

### 24.6 UI Style

- Diegetic terminal frames.
- Green text overlays.
- Corrupted corporate document feel.
- Reticle should feel like a targeting system bootstrapped from hacked corporate hardware.
- UI glitches should occasionally distort targeting or dialogue under stress.

### 24.7 Technical Art Recommendations

To keep scope manageable:

- Use modular low-poly environment kits.
- Use sprite sheets for enemies and NPCs.
- Reuse animation timing skeletons across enemy families.
- Use lighting and shaders to create visual richness instead of high-poly assets.
- Lean heavily on atmosphere, fog, emissive materials, and post-processing.
- Use billboard sprites for crowds and distant NPCs.
- Reserve true skeletal 3D models for rare bosses if necessary.

### 24.8 Reference Aesthetic Targets

Primary references:

- *Daggerfall Unity*
- *Doom*
- *Blood*
- *Deus Ex (2000)*
- *Shadowrun*
- *Cruelty Squad*
- *System Shock*
- PS1 cyberpunk aesthetics
- Dead mall vaporwave imagery
- Retro anime cyberpunk VHS transfers

The final look should feel like:

“A corrupted retro-futurist RPG running on a haunted corporate operating system.”

## 25. Audio Direction

### 25.1 Music

- Slums: industrial hum, distant fans, broken vaporwave, pipe percussion.
- Pacification Wards: soft corporate lullabies, detuned companion jingles, medical drones.
- Spire: clean synth arpeggios, server choir, cold corporate ambience.
- Mall: dead mall muzak, arcade bleeps, temporal tape warp.
- Bosses: distorted ad jingles, soul-bass, cyber-metal percussion.

### 25.2 SFX

- Reticle closing: subtle servo focus sound.
- Lock achieved: satisfying digital clamp.
- Linda messages: clean, warm, too intimate.
- Spooky Ghost: stage mic, reverb, glitch pops.
- Soul tech: wet electrical choir.

## 26. Save System

Track:

- Player stats.
- Inventory.
- Cybernetics.
- Quest states.
- Faction reputation.
- Defeated Generals.
- World event deck.
- Unlocked routes.
- Hub state.

Use JSON or Godot ResourceSaver for first pass.

## 27. Milestone Plan

### Milestone 1: FPS Controller and Test Room

- Player movement.
- Mouse look.
- Basic HUD.
- Test Sub-Sub-Basement room.

### Milestone 2: Body-Part Targeting Prototype

- Enemy dummy with body part colliders.
- Raycast detection.
- Reticle closure.
- Hit chance display.
- Damage part on fire.

### Milestone 3: First Enemy

- Goon Material enemy.
- Basic AI.
- Parts affect behavior.
- Loot drop.

### Milestone 4: First Quest Slice

- NPC or terminal in Faded Atrium/Sub-Sub-Basement District.
- Dialogue UI.
- Quest objective.
- Mission exit.

### Milestone 5: RPG Layer

- Stats.
- Inventory.
- Weapon data resources.
- Simple faction rep.

### Milestone 6: Vertical Slice

- Faded Atrium hub.
- Sub-Sub-Basement District free-roam loop.
- Wake-Up Call mission.
- One boss or mini-boss.
- One meaningful choice.
- Save/load.

## 28. Codex Task Instructions

When giving this to Codex, ask it to implement in small steps. Do not ask for the entire game at once.

### First Codex Prompt

```
We are building a Godot 4 first-person immersive RPG/shooter called GATEBOX BREACH. Start by creating the vertical slice foundation.

Implement:
1. A CharacterBody3D first-person player controller with mouse look.
2. A HUD CanvasLayer with a targeting reticle, body part label, and hit chance label.
3. A PlayerTargeting.gd script that raycasts from the camera center and detects BodyPart Area3D nodes.
4. A BodyPart.gd script with display_name, max_hp, current_hp, targeting_penalty, lock_difficulty_multiplier, armor_value, and apply_damage().
5. A test enemy scene with at least Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg body part Area3D children.
6. Reticle closure logic: lock_ratio increases while aiming at the same body part and decays when aim leaves.
7. Hit chance percentage shown on the HUD while aiming.
8. A simple hitscan Scrap Pistol that rolls against current hit chance and damages the targeted body part.

Keep the code modular. Use Godot 4 GDScript. Make the prototype simple and readable before adding art polish.
```

### Second Codex Prompt

```
Extend the GATEBOX BREACH prototype with body-part consequences.

Implement:
1. Body part destruction events.
2. If enemy RightArm is destroyed, disable its ranged attack.
3. If a Leg is destroyed, reduce enemy movement speed.
4. If Head is destroyed, apply high damage or stun.
5. Update HUD to show body part HP after acquiring a target.
6. Add simple enemy AI that walks toward player and attacks.
```

### Third Codex Prompt

```
Add RPG data resources for weapons and body parts.

Implement:
1. WeaponData Resource.
2. BodyPartData Resource.
3. Refactor Scrap Pistol to use WeaponData.
4. Refactor BodyPart.gd to optionally load values from BodyPartData.
5. Add exported variables so values can be tuned in the Godot editor.
```

## 29. Non-Negotiable Design Requirements

- The reticle closure targeting system is the signature mechanic.
- Body parts must be real gameplay targets, not cosmetic labels.
- The UI must display percentile hit chance as the reticle closes.
- The city must feel vertical: slum bottom, pacification middle, corporate top.
- The Faded Atrium is the current safe hub; the true Mall of the Future stays mythic/remote until later.
- System X is the current early faction/contact layer, replacing generic Resistance/Face-first language.
- The Sub-Sub-Basement District is the first systemic starting region.
- Toxic rain, shelters, generator potential, Wan Notes, and lower-city social/economy hooks define the first survival loop.
- Linda’s totalitarian care logic drives the antagonist philosophy.
- The Big Gates Foundation and 13 Generals provide boss structure.
- Scavenging and repurposing weird objects is central to progression.
- Choices should affect faction reputation and event deck/world state.

## 30. Vertical Slice Definition of Done

The vertical slice is successful when the player can:

1. Start in the Faded Atrium.
2. Enter the Sub-Sub-Basement District.
3. Read world-state/HUD feedback for rain, generator, and faction state.
4. Survive toxic rain by using shelter or protection items.
5. Bring mission loot or other wasted-potential salvage to Pipe Father Gideon.
6. Feed the Dreaming Generator and see Wan Notes, lighting, and world-state change.
7. Talk to named district NPCs with event-aware dialogue.
8. Enter the Wake-Up Call mission.
9. Fight a Goon Material enemy using body-part targeting.
10. Watch the reticle close and hit chance rise while holding aim over a part.
11. Destroy a specific part to change enemy behavior.
12. Loot an item.
13. Complete an objective.
14. Return to the hub.
15. See faction, quest-state, or world-state consequences persist through save/load.

## 31. Stretch Features

Only after the vertical slice works:

- Procedural district generation.
- Full event deck.
- 13 Generals campaign structure.
- Hacking minigame.
- Cybernetic surgery UI.
- Faction control map.
- Rival megacity routes.
- Mall temporal anomalies.
- Companion AI manipulation system.
- Stream-integrated events or chat-controlled anomalies.
