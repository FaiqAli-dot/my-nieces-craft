# Phase 2 — Beginner-Friendly Build Foundation

This document covers the **unified build system** layered on top of existing meadow voxel placement and house furniture decorating (not a rewrite of Phase 2 multiplayer houses).

## Architecture

Responsibilities (adapter style — blocks and furniture keep their runtime types):

| Module | Role |
|--------|------|
| `scripts/build/build_catalog.gd` | Placeable definitions + kid categories (Blocks / Furniture / Decorations / Garden) |
| `scripts/build/build_session.gd` | Selection + tap/drag input state (does not mutate the world) |
| `scripts/build/build_history.gd` | Bounded undo/redo (`MAX_ENTRIES = 32`) |
| `scripts/build/build_catalog_panel.gd` | Shared catalog UI (large icon+label tools) |
| `scripts/build/build_tool_icons.gd` | Shared Move/Copy/Rotate/Remove/Undo/Redo/Cancel icons for meadow + house |
| `PlayerController` | Voxel place/move/copy/remove + green/red preview + history |
| `PlacementController` + `HouseWorld` | Furniture place/move/copy/remove + history (offline + online) |

Phase 3 readiness: catalog entries may carry optional `behavior_type` / `attachments` metadata. No machines, carts, or automation are implemented.

## Interactions

- **Tap-to-place:** open Build/Catalog → tap card (no world change) → aim → tap Place / world confirm.
- **Drag-and-place:** drag a catalog card into the world; drop on UI cancels; valid drop commits once.
- **Edit tools:** Move, Copy, Remove, Undo, Redo, Cancel (house touch cluster + catalog toolbar). All use the same `BuildToolIcons` set.
- **Creative:** unrestricted resources. **Survival:** consume on successful place; undo refunds; copy cannot invent free blocks.

## History & online identity

One user action → one history entry. New edits clear redo. Multiplayer undo uses reverse net ops and refuses when the target instance disappeared or permissions fail (never silently overwrites newer peer work).

**Undo of an online remove preserves `instance_id`:** the client sends `furn_place` with the prior `instance_id`. The server accepts it only if that id is in an in-memory tombstone for the house (populated on remove), the `def_id` matches, the id is not currently live, and the client revision is current. Invented or never-removed ids are rejected. Tombstones are process-local (lost on server restart) — after a restart, undo-of-remove falls back to a new id if the client somehow still holds a stale history entry; normal play after restart clears client history on house leave/rejoin.

## UI notes / root causes fixed

- **Blank disabled tools:** Godot `Button.disabled` uses the `disabled` stylebox and `font_disabled_color`. Without theme overrides those render as empty grey boxes. Catalog tools now set `disabled` style + font/icon disabled colors and always show icon + short label.
- **House cluster icons:** Move/Copy/Remove/Undo/Redo previously reused menu/craft assets; they now load distinct shared icons from `BuildToolIcons`.
- **Toast vs catalog header:** when the Build catalog is open, toast anchors to the bottom so messages like “Back to start!” do not cover the title.

## Screenshots

```bash
COZY_PHASE2_BUILD_SHOTS=1 COZY_PHASE2_BUILD_QUIT=1 COZY_FORCE_TOUCH=1 \
  COZY_SHOT_DIR=/opt/cursor/artifacts/phase2_build COZY_SHOT_SIZE=1792x828 COZY_SHOT_TAG=phone \
  xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3

COZY_PHASE2_HOUSE_SHOTS=1 COZY_PHASE2_BUILD_QUIT=1 COZY_NET_AUTOSTART=0 \
  COZY_SHOT_DIR=/opt/cursor/artifacts/phase2_build COZY_SHOT_SIZE=1792x828 COZY_SHOT_TAG=house_phone \
  xvfb-run -a godot --path . res://scenes/house/house.tscn \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

Artifacts land under `/opt/cursor/artifacts/phase2_build/` (phone `1792x828` and tablet `2048x1536`).
