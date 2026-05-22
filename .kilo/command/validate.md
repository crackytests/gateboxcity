---
description: Validate scenes through the Godot MCP server
agent: redot
---
Validate the current state of the project by inspecting scenes through the Godot MCP server.

Steps:
1. Use the Godot MCP to launch and inspect the scene(s) specified in $ARGUMENTS (or all key scenes if none specified).
2. Key scenes to validate: MallHub.tscn, SubSubBasementDistrict.tscn, Test_SubSubBasement.tscn
3. Check for any debug errors, missing resources, or broken node references.
4. Report findings and suggest fixes for any issues found.

If no MCP server is available, read the .tscn files and check for obvious issues (missing scripts, broken resource paths).
