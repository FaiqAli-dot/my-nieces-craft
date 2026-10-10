# Art Direction — CozyBlocks Phase 1.5

## Five biggest visual weaknesses (from Phase 1 screenshots)

1. **Empty neon meadow.** The world reads as a single flat green plane to the horizon. No paths, edges, flower beds, tree clusters, or a “place to play,” so it feels like a tech demo, not a children’s game.

2. **Weak, noisy block identity.** Procedural 64×64 noise tiles make grass/dirt/stone blend together at distance. Surfaces lack readable silhouettes and a shared “toy block” language.

3. **Mismatched / washed-out prop materials.** Kenney models often import metallic and render pale under daylight; Khronos Fox is a different style family from Kenney furniture bear/duck. The scene never settles into one look.

4. **Showcase as a cluttered museum.** Floating Label3D walls, rows of unrelated objects, and dense text turn the gallery into noise instead of a charming garden kids would want to walk through.

5. **Generic grey UI.** Large grey panels and text-heavy buttons work functionally but do not feel colorful, iconic, or “game-like” for ages 5–8. Hotbar icons are plain texture crops without framing.

## Chosen art direction: “Sunny Toy Meadow”

A **polished, colorful voxel playground** — soft saturation, readable silhouettes, warm daylight — inspired by toy blocks and gentle picture-book meadows (not photoreal, not dark fantasy).

### Pillars

| Pillar | Intent |
|--------|--------|
| **Toy voxels** | Blocks look like painted wooden/plastic cubes: clear face colors, soft pixel detail, shared palette |
| **Warm daylight** | Creamy sun, soft sky blues, gentle shadows; no harsh metal sheen |
| **Garden composition** | Paths, flower rings, tree clumps, rock clusters, a cozy starter build patch |
| **Compatible props** | Prefer Kenney low-poly when materials read correctly; otherwise original voxel decorations |
| **Icon-first UI** | Rounded colorful frames, big touch targets, minimal words |

### Palette (CSS-style tokens)

```
--sky-top:        #6EB6F0
--sky-horizon:    #C8E8FF
--sun-warm:       #FFE6A8
--grass:          #7BC96F
--grass-deep:     #4FA35A
--dirt:           #C4895A
--stone:          #9AA3B2
--sand:           #F0D48A
--wood:           #B8733A
--leaves:         #5FBF6A
--accent-pink:    #F48FB1
--accent-yellow:  #FFD54F
--ui-panel:       #FFF6E8
--ui-ink:         #3E4A3C
```

### What we will change in 1.5

- Hand-authored block atlas + clearer grass top/side
- Layered terrain dressing (path, flowers, border stones, prop clusters)
- Softer sky/lighting; optional simple cloud billboards
- Garden-style showcase with low signage (ground plaques, not floating text walls)
- Small set of cohesive animals (Quaternius if obtainable; else original voxel critters with idle motion)
- Redesigned hotbar/touch chrome with color and icons

### Out of scope

Multiplayer, large/infinite worlds, combat, survival systems.
