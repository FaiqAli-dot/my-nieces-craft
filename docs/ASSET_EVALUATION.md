# Asset Evaluation — CozyBlocks Phase 1.5

## Art direction fit (ages 5–8) — Sunny Toy Meadow

| Category | Assets | Cohesion | Notes |
|----------|--------|----------|-------|
| Blocks | Original toy atlas | Strong | Clear grass/dirt/stone/wood/leaves/sand/glass/wool/path |
| Environment | Kenney Nature + Mini Forest (painted) | Strong | Trees/rocks/flowers read as toys after material override |
| Garden furniture | Kenney Furniture Kit (painted) | Good | Cozy corner only — not a museum row |
| Animals | Quaternius Cow/Sheep/Pig/Pug | Good | Same pack family; scaled ~0.09–0.12; idle bob |
| Sky / light | Procedural sky + soft fog + warm sun | Good | Tuned for tablet; llvmpipe still flattens shadows |
| Photoreal PBR | Poly Haven on disk | Unused in world | Intentionally not mixed into meadow |

## Integration checks

- **Vegetation:** Dense meadow dresser near spawn, path, knolls, and garden
- **Animals:** Garden “Friends” pen with checkered pad + post fence; Quaternius FBX
- **Scale:** Farm critters near block/player scale after FBX unit correction
- **Animations:** Prefer AnimationPlayer idle/eat/walk if present; else `bobbing_animal.gd`
- **UI:** Rounded cream tray, color-coded touch targets, LOOK separated from hotbar
- **Tablet intent:** Mobile renderer, fog instead of heavy post FX, limited world size

## Quaternius retry outcome

1. Phase 1 Google Drive downloads: **blocked** (rate limit)
2. Phase 1.5 itch.io official listing: **success** via claim `download_url` (see `assets/licenses/quaternius_itch_retry.txt`)
3. Only four farm animals imported into the playable garden

## Recommendations (later phases)

1. Author a dedicated player avatar from one Kenney character kit
2. Optional: convert Quaternius FBX → GLB with baked vertex colors to drop runtime paint
3. Profile shadows/fog on a real tablet before raising shadow map size
