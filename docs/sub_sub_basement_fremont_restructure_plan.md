# Sub-Sub-Basement Fremont Restructure Plan

## Summary

Restructure `SubSubBasementDistrict.tscn` into **Leak Street Arcade**, a Fremont Street-inspired lower-city avenue. The district should read as one playable street inside a much larger Sub-Sub-Basement settlement: storefronts on both sides, a continuous false-sky screen canopy overhead, side alleys that imply depth beyond the level, generator-linked hanging lights, and one modest playable upper catwalk route.

This plan extends `docs/sub_sub_basement_buildout_plan.md`; it does not replace it.

## Key Changes

- Keep the existing district quests, NPCs, toxic rain, generator state, Cooters/Suitors/Torai/Hoodlum hooks, and Wake-Up Call routing.
- Reframe the playable area as a north-south covered arcade rather than a flat test-room district.
- Arrange Cooters, Suitors, Wan Moa Torai, Hoodlum LAN, Pipe Chapel, and System X as readable destinations along the street.
- Add a continuous overhead false-sky canopy that extends visually past the playable space.
- Leave controlled canopy gaps, side alleys, and route gates for rain exposure and future expansion.
- Add a first playable catwalk layer with a small loop, access ramp, scaffold steps, and a blocked future shortcut.
- Keep generator-linked streetlights as a core readability cue.

## Implementation Notes

- `LevelDresser` should own most of the visual arcade structure so the layout can still be tuned quickly.
- Authored scene nodes should remain responsible for gameplay interactions, collision gates, NPCs, toxic rain, and mission exits.
- Runtime dressing should be split into helpers for avenue floor, storefront walls, canopy, facades, signs, streetlights, alley silhouettes, and catwalks.
- Atlas signs should use `Sprite3D.region_enabled`, never full atlas planes.
- Catwalk pieces should use runtime collision so traversal can be tested immediately.

## Acceptance Tests

- Launch `SubSubBasementDistrict.tscn` with no debug errors.
- Walk the main arcade from end to end without hitting invisible clutter.
- Verify all major establishments are readable from the street.
- Verify no full sign or prop atlas sheets are visible.
- Verify generator state visibly changes the hanging streetlights.
- Walk the catwalk/ramp/stair route without falling through or bypassing locked gates.
- Confirm the existing generator, Cooters, Suitors, Wan Moa Torai, Hoodlum LAN, System X, Wake-Up Call, and Faded Atrium interactions still work.
- Re-run `MallHub.tscn` and `Test_SubSubBasement.tscn` after the district pass.

