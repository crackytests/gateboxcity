---
description: Implement a feature from the GDD or buildout plan
agent: redot
subtask: true
---
Implement the feature described in: $ARGUMENTS

Steps:
1. Read the relevant sections of docs/gatebox_game_design_doc_for_codex.md and docs/sub_sub_basement_buildout_plan.md.
2. Check existing code in scripts/ for patterns to follow.
3. Implement the feature incrementally in small steps.
4. Follow the project's GDScript conventions (Godot 4 syntax, @export, @onready, class_name for Resources).
5. After implementation, validate affected scenes through the Godot MCP if available.
6. Report what was implemented and any issues encountered.

Reference files: @AGENTS.md
