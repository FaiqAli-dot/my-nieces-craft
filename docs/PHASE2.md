# CozyBlocks Phase 2 — Architecture & Runbook

## Base branch choice

Phase 2 is branched from **`cursor/cozyblocks-phase1_5-visual-e5ec`** (includes Sunny Toy Meadow + the place/break crosshair fix `f7a98c3`), not from `main`.

Reasons:

- Phase 1 / 1.5 were not both on `main` when Phase 2 started; 1.5 is the latest playable visual base.
- Preserves meadow art, Quaternius animals, touch UI language, and the HUD mouse-filter placement fix.
- Avoids merging unfinished work into `main`.

PR target: `cursor/cozyblocks-phase1_5-visual-e5ec`.

## What Phase 2 adds

1. **Third-person house scene** (`scenes/house/house.tscn`) with Kenney animated character, SpringArm camera, desktop + touch controls.
2. **Furniture catalog** (`data/furniture/furniture.json`, Kenney Furniture Kit) with grid snap, rotate, valid/invalid preview, move/remove.
3. **Authoritative WebSocket house server** (Godot headless, shared GDScript validation) with JSON file persistence.
4. **Private houses**, invite codes, visit/leave, collaboration toggle, remote player interpolation, furniture op sync.

Phase 1 meadow voxel gameplay remains the default main scene (`scenes/world/main.tscn`). Menu → **My House** opens Phase 2.

## Why Godot WebSocket server

- Same language and `FurnitureValidator` / `HousePermissions` / `HouseStore` code on client and server.
- No extra runtime (Node/DB) required for the vertical slice.
- File-backed JSON under `COZY_HOUSE_DATA` (default `user://houses`) survives restarts.
- `COZY_DEV_IDENTITY` is an explicit **local demo identity**, hashed server-side into `player_id` — not production auth.

## Key modules

| Path | Role |
|------|------|
| `scripts/furniture/furniture_grid.gd` | Grid snap / rotated footprints |
| `scripts/furniture/furniture_validator.gd` | Shared placement rules |
| `scripts/furniture/furniture_db.gd` | Catalog autoload |
| `scripts/house/house_layout.gd` / `house_store.gd` | Data model + persistence |
| `scripts/house/house_permissions.gd` | Owner / collab / visitor |
| `scripts/net/game_server.gd` | Authoritative server |
| `scripts/net/net_client.gd` | Client autoload |
| `scripts/player/third_person_controller.gd` | Local avatar + camera |
| `scripts/player/remote_player.gd` | Interpolated remotes |
| `scripts/ui/house_ui.gd` | Catalog / invite / collab HUD |

## Mouse-filter rule (do not regress)

Any non-interactive full-screen or center `Control` (toast, hint, crosshair) **must** use `MOUSE_FILTER_IGNORE`. The Phase 1.5 crosshair bug (`MOUSE_FILTER_STOP` swallowing captured clicks) is covered by unit + `COZY_PLACE_UI_TEST=1`.

## Voxel face-culling (merged from PR #6)

Side-face quads in `VoxelChunk` were wound CCW-from-outside while Godot culls with clockwise front faces. Merged `cursor/fix-face-winding-e5ec` (`c79be849`): side triangles flipped via `face_tri_order(flip=true)`, plus winding unit tests and `face_winding_shots.gd`.

Phase 2 furniture/house meshes use engine `BoxMesh` / Kenney GLBs with explicit `CULL_BACK` on opaque materials. Placement ghosts intentionally use `CULL_DISABLED` so translucent previews stay visible from all angles — that is not the voxel winding issue.

## Local run

See root `README.md` and `.env.example`.
