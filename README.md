# GATEBOX BREACH

**GATEBOX BREACH** is a tactical survival FPS with immersive RPG systems, built in Redot 4. The player is Spooky Ghost, a later-timeline ghost returned in an android body and hunted through Gatebox Mega City One after drawing the attention of Linda, the living CEO of Gatebox Corporation.

The current playable focus is the Sub-Sub-Basement: a lower-city survival district around Leak Street, the Faded Atrium, Cooters, Suitors, Wan Moa Torai, Hoodlum LAN, Pipe Chapel, toxic rain, route events, and body-part combat.

## Current Slice

- First-person movement, mouselook, shooting, reloading, and interaction.
- Reticle closure targeting with visible hit chance and targetable body parts.
- Sub-Sub-Basement district with toxic rain, shelters, generator-linked state, streetlights, signs, and social NPCs.
- Cooters job board and route travel loop.
- Pipe Utility Tunnels and additional job locations.
- Faded Atrium hub and Wake-Up Call mission route.
- Save/load for inventory, quests, jobs, factions, and world flags.

## Engine

- Redot 26.1 / Godot 4-compatible APIs
- GDScript only
- Forward+ renderer
- 1280x720 target viewport

## Running Locally

Open `project.godot` in Redot 26.1 and run the project. The configured main scene is:

```text
res://scenes/levels/MallHub.tscn
```

Useful scenes while testing:

- `scenes/levels/MallHub.tscn`
- `scenes/levels/SubSubBasementDistrict.tscn`
- `scenes/levels/CootersInterior.tscn`
- `scenes/levels/PipeUtilityTunnels.tscn`
- `scenes/levels/Test_SubSubBasement.tscn`

## Controls

- `WASD`: move
- Mouse: look
- Left mouse: fire
- `R`: reload
- `E`: interact
- `Space`: jump
- `F5`: save
- `F9`: load or debug/tuning menu in some test scenes

## Building

See [BUILDING.md](BUILDING.md) for local export and GitHub Actions release instructions.

Version tags such as `v0.0.4` trigger the Redot build workflow and publish release artifacts from CI.

## Design Docs

The main project design source is:

- `docs/gatebox_game_design_doc_for_codex.md`

Supporting sprint and reference docs live in `docs/`, including billboard sprite guidance, Sub-Sub-Basement planning, terrain and survival-site references, the Cooters job board/travel plan, and NPC writing style guidance.
