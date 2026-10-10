# CozyBlocks — Phase 2

Kid-friendly 3D voxel sandbox (Godot 4.3 / GDScript) plus a third-person house decorating mode with invite-based multiplayer. Phase 1 meadow building/crafting is preserved; Phase 2 adds private houses, furniture, and a small authoritative WebSocket server.

## Requirements

- Godot **4.3+** (standard build)
- Desktop keyboard/mouse for development; touch UI included for tablets
- Optional: Android export templates for APK builds

## Launch — meadow (Phase 1)

```bash
godot --path .
```

On headless/CI displays (Xvfb), prefer OpenGL compatibility:

```bash
xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

## Launch — house multiplayer (Phase 2)

Terminal A — authoritative house server:

```bash
export COZY_NET_PORT=9080
export COZY_HOUSE_DATA=/tmp/cozyblocks_houses
godot --headless --path . res://scenes/server/server.tscn
```

Terminal B — player Alice (own house):

```bash
export COZY_NET_HOST=127.0.0.1 COZY_NET_PORT=9080
export COZY_DEV_IDENTITY=alice COZY_DISPLAY_NAME=Alice
godot --path . res://scenes/house/house.tscn
```

Terminal C — player Bob (join Alice’s invite code from her HUD):

```bash
export COZY_NET_HOST=127.0.0.1 COZY_NET_PORT=9080
export COZY_DEV_IDENTITY=bob COZY_DISPLAY_NAME=Bob
export COZY_JOIN_INVITE=XXXXXX   # Alice's Invite code
godot --path . res://scenes/house/house.tscn
```

Or from the meadow: **Menu → My House**.

See `.env.example` for all variables. `COZY_DEV_IDENTITY` is a **local demo identity only** (not production auth).

No database setup — houses persist as JSON under `COZY_HOUSE_DATA` (default `user://houses`).

## Tests

```bash
# Unit + Phase 2 house/furniture/permission/persistence tests
godot --headless --path . res://tests/test_runner.tscn

# Place/break UI regression (crosshair must not swallow clicks)
COZY_PLACE_UI_TEST=1 COZY_SMOKE_QUIT=1 xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3

# Two-client multiplayer integration (in-process server)
COZY_MP_TEST=1 COZY_MP_TEST_QUIT=1 godot --headless --path . res://scenes/server/mp_test.tscn

# Meadow smoke
COZY_SMOKE=1 COZY_SMOKE_QUIT=1 xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

## Controls

### Meadow

| Action | Desktop | Touch UI |
|--------|---------|----------|
| Move | WASD / arrows | MOVE stick |
| Look | Mouse | LOOK pad |
| Jump | Space | Jump |
| Break | Left click | Break |
| Place | Right click | Place |
| Hotbar | 1–8 or tap slots | Tap hotbar |
| Inventory | I / Tab | Bag |
| Craft | C | Craft |
| My House | Menu → My House | Menu → My House |
| Creative flight | F toggle; Space up; Ctrl/Shift down | Fly / Land; Up / Down while flying |
| Creative mode | G or top-bar button | Top-bar Creative chip |

Only one of Bag / Craft / Menu is open at a time (opening one closes the others).

### House

| Action | Desktop | Touch UI |
|--------|---------|----------|
| Move | WASD | MOVE stick |
| Camera | Mouse | LOOK pad |
| Catalog | Catalog button | Catalog |
| Confirm place | Click / E | Place |
| Rotate preview | R / right-click | Rotate |
| Cancel | Esc | Cancel |
| Select furniture | Click | — |
| Move / remove | E / X | — |
| Invite / Visit / Collab | HUD buttons | HUD buttons |
| Return to meadow | Meadow (or Leave from own house) | Meadow |

Catalog and Visit are exclusive panels (same single-open rule as the meadow menus).

## Docs

- `docs/PHASE16.md` — Phase 1.6 collision / transitions / flight
- `docs/SURVIVAL_READINESS.md` — Survival prep (not implemented yet)
- `docs/PHASE2.md` — Phase 2 architecture & base-branch rationale
- `docs/ARCHITECTURE.md` — Phase 1 voxel architecture
- `docs/ART_DIRECTION.md` — Sunny Toy Meadow
- `docs/ASSET_MANIFEST.md` — vendored assets / licenses

## License note

Game code in this repository is provided for the CozyBlocks prototype. Third-party assets retain their own licenses (mostly CC0 from Kenney and Poly Haven). See `assets/licenses/` and `docs/ASSET_MANIFEST.md`.
