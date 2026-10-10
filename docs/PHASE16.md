# Phase 1.6 — Collision, Transitions, Creative Flight

Branch: `feature/cozyblocks-phase16-gameplay-fixes`

## Bugs fixed

### 1. Character scale
- First-person and third-person capsules are **1.8m × radius 0.38**, eye/camera height aligned.
- Kenney house avatar scale **0.62 → 0.9** so body matches capsule and furniture cells.

### 2. House floor fall-through
- Structural floor slab thickened (`FLOOR_THICKNESS = 0.5`) with top at `y=0`.
- Exterior apron outside the doorway so walking out does not void-fall.
- Immediate `free()` of regenerated geometry; player `floor_snap_length` / `safe_margin` set.

### 3. House ↔ meadow “disconnecting” stuck state
**Root cause (evidence in code):**
- `HouseWorld._connect_net_signals()` used lambdas on the `NetClient` autoload and never disconnected them → re-entry stacked handlers that touched freed `HouseUi`.
- `go_voxel_world()` called `disconnect_from_server()` which emitted `disconnected` → UI set **“Disconnected”**, while `_wanted` reconnect paths could toast **“Reconnecting…”** during teardown.
- Offline / failed connects left status on **“Connecting…”**.

**Fix:** named handlers + `_exit_tree` disconnect, `NetClient.disconnect_from_server()` no longer reconnects, `SceneFlow` owns scene changes, status ignores teardown, Meadow/Leave use the safe path.

### 4. Furniture walk-through
- Catalog gains `solid`, `collision_height`, `collision_scale`.
- Solid pieces use box colliders sized to footprint × height; rugs/bears are non-blocking (pick layer 4).

### 5. Stacking menus
**Root cause:** each Bag/Craft/Menu/Catalog/Visit toggle flipped only its own `visible` flag.

**Fix:** shared `ExclusivePanels` host — opening one id closes all others; same id toggles closed; mouse recapture / touch unchanged when all closed.

### 6. Rotate button icon
- House Rotate action uses `assets/ui/icons/icon_rotate.png`.

## Creative flight

- Creative-only (`GameState.flying`); auto-off when Creative → Limited.
- Desktop: **F** toggle, **Space** ascend, **Ctrl/Shift** descend, WASD horizontal.
- Touch: Fly / Land button above joystick; Up/Down while flying.
- Implemented inside `PlayerController` (no second movement system).

## Tests

```bash
godot --headless --path . res://tests/test_runner.tscn
COZY_NET_AUTOSTART=0 COZY_TRANSITION_TEST=1 COZY_SMOKE_QUIT=1 \
  xvfb-run -a godot --path . res://scenes/house/house.tscn \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

## Survival

See `docs/SURVIVAL_READINESS.md` — not implemented in this branch.
