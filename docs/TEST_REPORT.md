# Test Report — CozyBlocks Phase 1.5

**Date:** 2026-10-09  
**Godot:** 4.3.stable  
**Branch:** `cursor/cozyblocks-phase1_5-visual-e5ec`  
**Base:** `cursor/cozyblocks-phase1-e5ec`

## Automated tests

```bash
godot --headless --path . res://tests/test_runner.tscn
```

| Area | Result |
|------|--------|
| Block definitions / lookup | PASS |
| Inventory + creative unlimited | PASS |
| Crafting recipes | PASS |
| Placement AABB helpers | PASS |
| World serialize / deserialize | PASS |
| Chunk mesh + collision after edit | PASS |
| Meadow ground surface (solid terrain) | PASS |

**Totals: 34 passed, 0 failed.**

Note: ground-surface assertion accepts meadow accents (path/flower/dirt) so dressing does not flake the suite.

## Graphical smoke (Xvfb + OpenGL compatibility)

```bash
godot --path . --resolution 1280x720 \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

`COZY_SMOKE=1`:

| Check | Result |
|-------|--------|
| Launch | PASS (dummy audio) |
| Break → drop | PASS (`path_stone` at dressed spawn cell — valid) |
| Place wood | PASS |
| Craft `wood_to_planks` | PASS |
| Save world | PASS |

## Screenshots

After shots: `/opt/cursor/artifacts/screenshots/phase1_5_after/`  
Finals: `/opt/cursor/artifacts/screenshots/phase1_5_final/`  
Before (Phase 1): `/opt/cursor/artifacts/screenshots/phase1_before/`  
Comparisons: `/opt/cursor/artifacts/screenshots/comparisons/`

| Shot | Viewpoint |
|------|-----------|
| 01 | Main building / meadow area |
| 02 | Built playhouse |
| 03 | Flower garden nook |
| 04 | Animal friends pen |
| 05 | Cozy furniture corner |
| 06 | Block palette |
| 07 | Crafting UI |
| 08 | Touch controls |
| 09 | Meadow path overview (new) |
| 10 | Garden wide (new) |
| 11 | Wide meadow (FG/MG/BG fill) |

Phase 1 vs final side-by-sides:

- `/opt/cursor/artifacts/screenshots/comparisons/compare_01_main_building_area.png`
- `/opt/cursor/artifacts/screenshots/comparisons/compare_02_built_structure.png`
- `/opt/cursor/artifacts/screenshots/comparisons/compare_03_showcase_environment.png`
- `/opt/cursor/artifacts/screenshots/comparisons/compare_04_showcase_animals.png`
- `/opt/cursor/artifacts/screenshots/comparisons/compare_11_wide_meadow.png`

## Honest visual judgment (rendered result)

**Improved vs Phase 1:** sunny mid-green grass with soft patches; MultiMesh tree/flower/bush fill + knolls/pond/fence for wide depth; light warm playhouse planks; colorful UI; Quaternius pen animals; garden composition.

**Still limited:** llvmpipe flattens shadows; some meadow angles still simpler than a shipped title; animal FBX idle clips may fall back to bob; finite sandbox by design. Garden keepouts intentionally thin props inside the pen framing.

Verdict: closer to a **small children’s voxel playground slice** than Phase 1’s empty plane; not final art-complete.

## Manual checklist

| # | Item | Status |
|---|------|--------|
| 1 | Launches | PASS |
| 2 | Move / jump | PARTIAL (bindings present) |
| 3–6 | Break / collect / place / build | PASS (smoke + harness house) |
| 7 | Hotbar | PARTIAL |
| 8 | Creative | PASS |
| 9 | Crafting | PASS |
| 10 | Models/textures | PASS (animals/garden clear in shots) |
| 11 | Showcase garden | PASS |
| 12 | Save/load | PARTIAL (save smoke + deserialize unit) |
| 13 | Reset confirm | PARTIAL (UI only) |
| 14 | Tablet tablet | NOT RUN |
