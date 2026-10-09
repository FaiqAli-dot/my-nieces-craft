# Architecture — CozyBlocks Phase 1

## Goals

Small, modular Godot 4 prototype: finite voxel sandbox, inventory/crafting, asset showcase, desktop + touch controls. No backend, multiplayer, or infinite worlds.

## Runtime overview

```
Main (main_world.gd)
├── WorldEnvironment + DirectionalLight3D
├── VoxelWorld (chunked blocks)
│   └── Chunks/*
├── Player (CharacterBody3D + Camera3D + RayCast3D)
├── GameUI (CanvasLayer HUD / touch / menus)
├── Showcase (AssetShowcase labeled sections)
└── AmbientProps (sparse Kenney nature models)
```

Autoloads:

- `BlockDB` — block/item definitions, texture atlas, lookups
- `GameState` — creative flag, UI signals, toasts

## Voxel system

- Finite world: **4×2×4 chunks** of **16³** → **64×32×64** blocks
- Flat ground at `GROUND_Y = 4` (stone → dirt → grass)
- `VoxelChunk` stores `PackedByteArray` block IDs
- Mesh: face-culled `SurfaceTool` mesh + `ConcavePolygonShape3D` collision
- Edits rebuild only the affected chunk (and border neighbors)
- No per-block nodes

## Gameplay modules

| Module | Path | Role |
|--------|------|------|
| Inventory | `scripts/inventory/inventory.gd` | Hotbar + bag, stack/add/remove |
| Crafting | `scripts/crafting/crafting.gd` | JSON recipes, consume/produce |
| Saving | `scripts/saving/save_game.gd` | JSON save of chunks + inventory |
| Player | `scripts/player/player_controller.gd` | Move/look/break/place/touch API |
| UI | `scripts/ui/game_ui.gd` | Hotbar, craft, menu, touch sticks |
| Showcase | `scripts/showcase/asset_showcase.gd` | Labeled 3D asset gallery |

## Data

- `data/blocks/blocks.json` — block definitions
- `data/blocks/items.json` — non-placeable items (sticks)
- `data/recipes/recipes.json` — crafting recipes

## Rendering / mobile

- `rendering_method = mobile`
- ETC2/ASTC import enabled for Android
- MSAA 3D light, simple procedural sky, consistent daylight for asset evaluation
- Large HUD buttons and optional virtual sticks

## Extension points (later phases)

- Swap finite chunk map for streaming chunk provider
- Network `set_block` / inventory ops behind a session interface
- Replace showcase props with authored biome kits
