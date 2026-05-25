# Cooters Job Board Level Expansion

This document applies `docs/gatebox_sub_sub_basement_terrain_agent_reference.md` to the next Cooters job-board destinations. It extends, but does not replace, `docs/cooters_job_board_and_travel_plan.md`.

## Street Context

Leak Street now sits beside the partly submerged old mall. The Faded Atrium is the exposed second-floor mall entrance on the same side of the street as the travel selector. The lower mall levels are underwater, sealed, or reachable only through future service routes. The extra standalone Wake-Up Call door is removed from the street; Wake-Up Call remains a selectable route from the gate.

## New Job Destinations

### Dead Food Court Bloom

**Identity:** A ruined second-floor food court overgrown by bio-mall flora.

**Job:** `Food Court Filter`

**Objective:** Recover `Pure Water Filter`.

**Terrain recipe:** Dead food court overgrown by bio-mall flora.

**Terrain systems:**

- Upper fast-food ring as the safer slow route.
- Plant-choked seating pit as the dangerous shortcut.
- Kitchen bypass ramp as a flank.
- Grease-spore vent panel as a first-pass interactable terrain object.

**Mission shape:** The player can reach the filter from the upper ring with safer angles, or cross the growth pit quickly while exposed to snare-growth language. A security-node target gives the room a small combat beat without making it a full dungeon.

### Water Reclamation Cistern

**Identity:** A flooded reclamation room controlled by improvised scavenger repairs.

**Job:** `Pump Heart Lease`

**Objective:** Recover `Cistern Filter Core`.

**Terrain recipe:** Water reclamation cistern.

**Terrain systems:**

- Walkway ring around shallow toxic water.
- Pump control room as an objective pocket.
- Live conduit as risky cover and route pressure.
- Pump valve panel as a first-pass utility object.

**Mission shape:** The safe route follows walkways; the fast route cuts across wet space beside the conduit. Torai flavor frames the objective as debt-coded salvage.

### Collapsed Service Atrium

**Identity:** A vertical mall atrium collapsed into maintenance decks, with only upper service paths still usable above the submerged lower mall.

**Job:** `Atrium Relay Echo`

**Objective:** Record `Atrium Relay Packet`.

**Terrain recipe:** Collapsed service atrium.

**Terrain systems:**

- Ground floor split by sludge gap.
- Raised catwalk and ramp path.
- Hardlight gate as readable conditional cover.
- Mall relay choir as the objective anchor.

**Mission shape:** The player climbs to the relay, crosses a catwalk, and deals with a light security-node beat. The room reinforces the new canon that the old mall is partly submerged and Leak Street is built beside its exposed second floor.

## Job Board Integration

The Cooters board now includes six hardcoded first-pass jobs:

- `Pipe Blood Sample` -> Pipe Utility Tunnels
- `Saint Ratchet` -> Pipe Utility Tunnels
- `Listen To The Pipes` -> Pipe Utility Tunnels
- `Food Court Filter` -> Dead Food Court Bloom
- `Pump Heart Lease` -> Water Reclamation Cistern
- `Atrium Relay Echo` -> Collapsed Service Atrium

Only one job can be active at a time. The travel gate unlocks only the route matching the active job destination, plus always-available hub routes.
