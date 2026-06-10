# Billboard Sprite Reference

These notes capture the target style from the provided sprite sheet references for later enemy/NPC art implementation.

## Format

- 3D world, 2D billboard characters.
- `Sprite3D` or `AnimatedSprite3D` nodes face the player camera.
- Directional frame is selected from yaw angle to player.
- Billboard remains upright; pitch should not tilt the sprite.
- Use nearest-neighbor filtering for a crunchy retro look.
- Pivot should be bottom-center so feet stay planted.

## Direction Order

Use an 8-direction set:

1. Back, 180 degrees
2. Back-left, 135 degrees
3. Left, 90 degrees
4. Front-left, 45 degrees
5. Front, 0 degrees
6. Front-right, 315 degrees
7. Right, 270 degrees
8. Back-right, 225 degrees

The common sheet target is `2048x384`, with eight `256x384` frames in a row.

## Animation Rows

Target sheet rows:

- Base directional pose: 8 frames.
- Idle animation: 4 frames per direction when available.
- Damage reaction: at least 1 frame per direction.

Prototype can start with a single 8-frame row, then expand to idle/damage rows later.

## Characters Referenced

- `LX-04 Spooky Ghost`: the **protagonist's** look — a classic bedsheet-ghost silhouette (draped sheet, two worn eyeholes) over a salvaged android chassis; pale cloth with a red-black glitch palette. The sheet is fused to the body and never comes off; it's his permanent, deliberately on-the-nose appearance (and a running comic gag).
- `LX-05 Lethal`: neon magenta operative/enforcer, glossy cyberpunk palette.
- `LX-02 Field Operative / Greenline`: compact helmeted operative, green/brown industrial palette.

## Godot Implementation Target

Create a reusable `DirectionalBillboard.gd` component:

- Export an array of 8 textures or an atlas texture plus frame size.
- Export `target_camera_path`.
- Each frame maps to one of the 8 yaw buckets.
- Optional idle bob and glitch flicker parameters.
- Optional damage flash frame or shader tint.

For enemies with body-part targeting, use the billboard for visuals while keeping invisible `Area3D` body part colliders in 3D space.
