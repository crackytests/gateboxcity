# Sub-Sub-Basement Visual Progress Log

## Current Visual Pass

- Imported the first Leak Street texture set into `assets/textures/leak_street`.
- Added wet concrete, rusted metal, corrugated shack metal, false-sky glass, facade images, props, signage, and hazard-sign atlases.
- Reworked `LevelDresser` so the Sub-Sub-Basement District can be dressed at runtime with textured floor panels, wall panels, storefront facades, cropped atlas signs, and generator-linked lights.
- Replaced the flat neon placeholder storefronts with larger facade art for Cooters, Suitors, Wan Moa Torai, Hoodlum LAN, and Pipe Chapel.
- Moved the major establishment interaction volumes closer to their facade art so prompts line up better with the visible locations.
- Added hanging streetlights controlled by generator state:
  - stable: bright and steady
  - sagging/power sag: weak partial flicker
  - overloaded/LAN outage: hot unstable flicker
  - offline: dark
- Added a temporary F9 tuning overlay for texture brightness, facade brightness, emission, fog, wash lights, streetlights, and atlas crop tuning.

## Debug Tuning Controls

- `F9`: open or close the tuning overlay.
- `Up/Down`: select a value.
- `Left/Right`: adjust the selected value.
- `Shift + Left/Right`: adjust faster.
- `PageUp/PageDown`: select a different atlas panel.
- `Enter`: print the current values to the Redot/Godot output.

The tuning overlay is temporary. Once the texture and lighting values feel right in play, the chosen values should be baked into code and the debug UI removed.

## Known Issues

- Atlas sign crops still need final tuning against the latest alpha-layer atlas files.
- The previous district layout was still a decorated box rather than a strong street space.
- Some runtime clutter and old placeholder shapes could intersect facades, lights, or player sight lines.
- The first texture pass made surfaces readable, but the lighting still needs to serve navigability and mood rather than evenly exposing every panel.

