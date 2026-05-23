# Ninth Sprint: Cooters Job Board, Travel Gate, and Pipe Utility Tunnels

## Summary

Expand Cooters from a one-room NPC stop into the first reusable job hub. Add a simple quest board UI inside `CootersInterior`, let the player accept one Cooters job at a time, let Marbles explain or pay out the accepted job, and add a town exit gate that opens a simple route-selection menu.

Travel rolls one lightweight world event from the existing world-event set, then sends the player to the first new quest location: **Pipe Utility Tunnels**.

## Implemented Scope

- Add save-backed Cooters job state to `GameState`.
- Add `JobBoardUI` to the HUD.
- Add `TravelGateUI` to the HUD.
- Add a Cooters job board interactable inside `CootersInterior`.
- Make Marbles react to no job, active job, objective-complete job, and payout.
- Add a Leak Street travel gate in `SubSubBasementDistrict`.
- Add `WorldDirector.roll_travel_event(route_id)`.
- Add `PipeUtilityTunnels.tscn` as the first compact job destination.

## First Jobs

- `pipe_blood_sample`: collect `Pipe Blood Sample` in Pipe Utility Tunnels and return to Marbles. Reward: `Cooters Bar Credit`, System X +1.
- `ratchet_saint`: recover `Saint Ratchet` in Pipe Utility Tunnels and return to Marbles. Reward: `Chemical Neutralizer`, Wan Moa Torai +1.
- `listen_to_the_pipes`: use the pipe listening node in Pipe Utility Tunnels and return to Marbles. Reward: `Cooters Rumor Token`, System X +1.

## Travel Routes

- Pipe Utility Tunnels: requires an active Cooters job pointing there.
- Faded Atrium: available as a hub return.
- Wake-Up Call: requires the dreaming generator to be patched.

## Travel Event Deck

Initial travel cards:

- Clear Run
- Toxic Rain
- Power Sag
- LAN Outage
- Quiet Shortcut

The deck only applies existing world events for now. The Faded Atrium mall deck remains a later sprint.

## Test Targets

- Launch `CootersInterior.tscn`; verify board open/close and mouse capture.
- Accept each job and verify only one active job can be held.
- Talk to Marbles before job, during job, and after objective completion.
- Launch `SubSubBasementDistrict.tscn`; verify travel gate route locking.
- Travel to `PipeUtilityTunnels.tscn`; verify the event roll and job objectives.
- Return to Cooters for payout.
- Save/load while a job is active and while an objective is awaiting payout.
