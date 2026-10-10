# Next Phase Recommendations

Phase 1 delivered gameplay; Phase 1.5 established **Sunny Toy Meadow** visuals and a Quaternius itch.io animal path. Suggested next work:

## World

- Streaming chunk provider around the player (keep the same `VoxelChunk` mesh API)
- Biome kits with density budgets for tablets
- Soft world border / map islands instead of hard clamp

## Multiplayer (later — not Phase 1.5)

- Authoritative block edit channel (place/break ops with validation)
- Per-player inventories; no accounts required for local couch/LAN first
- Interest management by chunk

## Gameplay

- Optional gentle goals (build a house checklist) without combat/hunger
- Drop entities with bobbing pickup
- Tool items crafted from sticks + planks
- Player avatar from Kenney Mini Characters

## Assets / art

- Bake Quaternius materials to GLB to reduce runtime paint
- Optional more farm friends only if style matches the garden set
- On-device lighting pass (real tablet shadows vs llvmpipe)

## Platforms

- Android export presets + on-device touch tuning
- iPad export when Apple toolchain available

## Quality

- Expand headless tests for chunk borders and save migrations
- Keep screenshot harness for visual regression
- Performance budgets: draw calls, triangle counts, texture memory
