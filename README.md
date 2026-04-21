# Homigrad-Spawn-Tools

This is a fork of [Zgrad-Tools](https://github.com/npc-servers/zgrad-tools)
The point of this fork is too make this awesome tool work with [jonny's homigrad](https://github.com/JonnyBro/homigrad) (it will presumably work with other verions too).

Map Point Editor for Homigrad maps (spawns, CPs, vehicles, etc.). Saves per map on the server.

**Access:** SuperAdmin, Admin, or `operator` only.

**Tool:** Tool Gun → Q → Tools → Homigrad Mapping → Map Point Editor (Homigrad).

**Panel:** Mode (Place vs Select), Placement (Surface vs Self), Point type, Point number (1–32 — CP index / preview size).

**Place:** Left click to add.

**Select:** Left click near screen center to select; left click again to move; right click to delete; R to deselect. Gray `[H]` points are from the map (Hammer), not editable here.

**Data:** `garrysmod/data/Homigrad/maps/` on the server — subfolder per category, one `.txt` per map name.

**Issues:** No tool → need staff rank. Can’t select → Hammer point. No files on disk → check the server machine, not clients.
