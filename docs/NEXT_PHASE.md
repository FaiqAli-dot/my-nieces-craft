# Next Phase Recommendations

Phase 1 validated chunked voxels, hotbar/crafting, touch HUD scaffolding, and a local asset pipeline. Suggested next work for a larger kid-friendly multiplayer game:

## World

- Streaming chunk provider around the player (keep the same `VoxelChunk` mesh API)
- Biome kits using Kenney/Quaternius vegetation with density budgets for tablets
- Soft world border / map islands instead of hard clamp

## Multiplayer (later)

- Authoritative block edit channel (place/break ops with validation)
- Per-player inventories; no accounts required for local couch/LAN first
- Interest management by chunk

## Gameplay

- Optional gentle goals (build a house checklist) without combat/hunger
- Drop entities with bobbing pickup
- Tool items crafted from sticks + planks
- Player avatar from Kenney Mini Characters

## Assets

- Retry Quaternius Ultimate Animated Animals when Drive allows
- Convert any desired Blender-only packs to GLB offline
- Unified stylized material set for blocks (leave Poly Haven for optional detail)

## Platforms

- Android export presets + on-device touch tuning
- iPad export when Apple toolchain available
- Input profiles: larger HUD on phones, more world UI on tablets

## Quality

- Expand headless tests for chunk borders and save migrations
- Automated screenshot harness for showcase lighting regression
- Performance budgets: draw calls, triangle counts, texture memory
