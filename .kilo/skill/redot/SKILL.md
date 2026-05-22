---
name: redot
description: Redot 4 (Godot 4 fork) GDScript patterns, scene structure conventions, and MCP-based scene validation for GATEBOX BREACH.
---

# Redot/Godot 4 Development Skill

## GDScript Patterns

### Resource Data
Use `class_name` for custom resources. Store data in .tres files, reference via `@export`:

```gdscript
class_name WeaponData
extends Resource

@export var display_name: String = ""
@export var damage: float = 10.0
@export var magazine_size: int = 12
@export var reserve_ammo: int = 48
@export var lock_retention: float = 0.5
```

### BodyPart System
Each enemy has Area3D children for each body part. BodyPartData defines stats:

```gdscript
@export var display_name: String = ""
@export var max_hp: float = 25.0
@export var current_hp: float = 25.0
@export var targeting_penalty: float = 0.0
@export var lock_difficulty_multiplier: float = 1.0
@export var armor_value: float = 0.0
```

### Autoload Singletons
- `GameState` — Persistent data (items, rep, quests, flags, implants). Save/load to user://gatebox_save.json.
- `WorldDirector` — Runtime world state (region, events, generator). Emits `world_state_changed`.

### Signal Communication
Systems communicate via signals:
```gdscript
signal world_state_changed(event_name: String, details: Dictionary)
signal inventory_changed(summary: String)
signal objective_changed(objective: String, completed: bool)
```

## Scene Structure
- `.tscn` files use Godot 4 scene format
- Enemy scenes: CharacterBody3D root → MeshInstance3D + CollisionShape3D + body part Area3D children
- Level scenes: Node3D root → CSGBox3D/StaticBody3D geometry + Light3D + interactive nodes
- HUD: CanvasLayer → Control nodes (TargetingReticle, labels)

## Billboard Sprite System
- `Sprite3D` or `AnimatedSprite3D` with `texture_filter = Nearest`
- 8-direction sprites: front, back, left, right, front-left, front-right, back-left, back-right
- Character variants: base, alt, cutout, card

## Validation Workflow
After making changes:
1. Use Godot MCP to inspect affected scenes
2. Launch scenes to check for runtime errors
3. Re-run route scenes when shared systems change
4. Verify save/load persists state correctly
