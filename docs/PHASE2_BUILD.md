# Phase 2 — Beginner-Friendly Build Foundation

This document covers the **unified build system** layered on top of existing meadow voxel placement and house furniture decorating (not a rewrite of Phase 2 multiplayer houses).

## Architecture

Responsibilities (adapter style — blocks and furniture keep their runtime types):

| Module | Role |
|--------|------|
| `scripts/build/build_catalog.gd` | Placeable definitions + kid categories (Blocks / Furniture / Decorations / Garden) |
| `scripts/build/build_session.gd` | Selection + tap/drag input state (does not mutate the world) |
| `scripts/build/build_history.gd` | Bounded undo/redo (`MAX_ENTRIES = 32`) |
| `scripts/build/build_catalog_panel.gd` | Shared catalog UI |
| `PlayerController` | Voxel place/move/copy/remove + green/red preview + history |
| `PlacementController` + `HouseWorld` | Furniture place/move/copy/remove + history (offline + online) |

Phase 3 readiness: catalog entries may carry optional `behavior_type` / `attachments` metadata. No machines, carts, or automation are implemented.

## Interactions

- **Tap-to-place:** open Build/Catalog → tap card (no world change) → aim → tap Place / world confirm.
- **Drag-and-place:** drag a catalog card into the world; drop on UI cancels.
- **Edit tools:** Move, Copy, Remove, Undo, Redo, Cancel (house touch cluster + catalog toolbar).
- **Creative:** unrestricted resources. **Survival:** consume on successful place; undo refunds; copy cannot invent free blocks.

## History

One user action → one history entry. New edits clear redo. Multiplayer undo uses reverse net ops and refuses when the target instance disappeared or permissions fail (never silently overwrites newer peer work).

## Screenshots

```bash
COZY_PHASE2_BUILD_SHOTS=1 COZY_PHASE2_BUILD_QUIT=1 COZY_FORCE_TOUCH=1 \
  COZY_SHOT_DIR=/opt/cursor/artifacts/phase2_build COZY_SHOT_SIZE=1792x828 \
  xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3

COZY_PHASE2_HOUSE_SHOTS=1 COZY_PHASE2_BUILD_QUIT=1 COZY_NET_AUTOSTART=0 \
  COZY_SHOT_DIR=/opt/cursor/artifacts/phase2_build \
  xvfb-run -a godot --path . res://scenes/house/house.tscn \
  --rendering-method gl_compatibility --rendering-driver opengl3
```
