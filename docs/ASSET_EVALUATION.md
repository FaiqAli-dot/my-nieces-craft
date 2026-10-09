# Asset Evaluation — CozyBlocks Phase 1

## Art direction fit (ages 5–8)

| Category | Assets | Cohesion | Notes |
|----------|--------|----------|-------|
| Environment | Kenney Nature Kit + Mini Forest | Strong | Bright low-poly; scales well vs 1m blocks with ~0.7–1.0 scale |
| Furniture | Kenney Furniture Kit | Strong | Same Kenney style family as nature kit |
| Characters | Blocky / Mini Characters | Good | Friendly; slightly different proportions between packs |
| Animals | Fox/Duck (Khronos) + Kenney bear | Mixed | Quaternius farm animals unavailable; Fox is animated and readable; Duck/Bear are static; styles differ (realistic fox vs toy bear) |
| Materials | Poly Haven PBR + prototype tiles | Mixed | Poly Haven is photoreal — good for material board, busier than Kenney props; block textures are custom bright tiles for gameplay clarity |
| Audio | Kenney packs | Strong | Soft UI/impact cues, non-threatening |
| Sky | Procedural sky + Kenney skybox PNGs + Poly Haven HDRI on disk | Good | Runtime uses procedural sky for consistent lighting; HDRI kept for later |

## In-game integration checks

- **Vegetation/props:** Placed in AmbientProps near spawn and in Showcase Environment section.
- **Animals:** Showcase Animals section; Fox AnimationPlayer autoplays Survey/idle-like clip when present.
- **Scale vs player/blocks:** Kenney nature trees ~player height at 0.7–0.8 scale; Fox requires ~0.02 scale (model units).
- **Materials:** Showcase Materials section displays Poly Haven + prototype + block wool on cubes.
- **Animations:** Fox animation previewed when AnimationPlayer found; Duck/Bear have none.
- **Tablet performance intent:** Mobile renderer, batched voxel meshes, limited world, 1k textures — not profiled on a physical tablet in this environment.
- **Visual clashes:** Photoreal Poly Haven next to Kenney low-poly is intentionally isolated to the Materials board. Prefer Kenney for world dressing going forward.

## Recommendations

1. Re-attempt Quaternius Drive downloads later for cohesive stylized animals.
2. Author a single atlas of kid-friendly block textures (replace procedural tiles).
3. Keep Poly Haven for ground/detail materials sparingly, or stylize them.
4. Prefer one character kit (Mini or Blocky) for the player avatar in Phase 2.
