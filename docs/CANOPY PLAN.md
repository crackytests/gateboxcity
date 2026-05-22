# False-Sky Truman Canopy Plan

## Summary

Save this plan later as `C:\Users\jeremy\Documents\New project\docs\false_sky_truman_canopy_plan.md`.

Move the Sub-Sub-Basement false sky from a low Fremont-style ceiling into a high, Truman Show-style artificial firmament: a huge luminous screen far above Leak Street that feels like it covers the whole larger region. The street should remain readable at ground level, with separate hanging lights providing local illumination.

## Key Changes

- Replace the current low canopy placement in `LevelDresser` with a high false-sky layer above the arcade.
- Target height: move main false-sky panels from about `y=3.5` to about `y=10.0-14.0`.
- Scale panels much larger so they read as regional infrastructure, not awnings:
  - Main overhead panels should span beyond the street width.
  - Side/continuation panels should extend past playable bounds.
- Keep the new false-sky textures:
  - `false_sky_canopy_grid_a.png`
  - `false_sky_canopy_grid_b.png`
- Remove or greatly reduce low false-sky panels near the player, except for broken canopy fragments or exposed toxic-rain gaps.
- Keep toxic rain logic grounded in shelter volumes, not direct collision with the visual sky panels.

## Implementation Details

- Refactor `_add_arcade_canopy()` into two layers:
  - `HighFalseSky`: large luminous panels high above Leak Street.
  - `StreetFixtures`: low ribs, hanging cables, streetlights, and small broken panel fragments.
- Use high panels as visual-only `MeshInstance3D` quads with no collision.
- Rotate and offset some panels subtly so the sky feels stitched together from giant cracked screens.
- Add underside glow lights from the sky layer:
  - stable generator: cyan/teal steady glow
  - sagging generator: dimmer, intermittent bands
  - overloaded: harsh flicker with magenta/red pulses
  - offline: sky mostly dead, only faint emergency patches
- Keep local streetlights responsible for gameplay readability at ground level.
- Add a few vertical reference elements:
  - tall support pylons
  - hanging cable bundles
  - distant screen seams
  - broken sky gaps above alley mouths

## Visual Goals

- The player should look up and feel like the “sky” is fake, enormous, and too far above to touch.
- Leak Street should feel like one lane under a much larger artificial weather machine.
- The floor and storefront textures should no longer compete with the sky texture at eye level.
- Toxic rain should feel like it comes from failed sections of the false sky, not from low ceiling panels.

## Test Plan

- Launch `SubSubBasementDistrict.tscn` through Godot MCP and verify no debug errors.
- Walk the main street and confirm no false-sky panels block sightlines near the ground.
- Look upward from several positions and confirm the high sky panels are visible and readable.
- Trigger generator states and confirm false-sky brightness changes clearly.
- Verify toxic rain and shelter mechanics still work.
- Confirm player cannot collide with or stand on the high sky panels.
- Recheck interact prompts and NPC visibility from ground level.

## Assumptions

- The Fremont Street inspiration remains, but the screen becomes much higher and more surreal.
- The low arcade canopy should become mostly street fixtures, not the main sky.
- The false sky is visual/worldbuilding first; gameplay shelter remains handled by explicit shelter volumes.
