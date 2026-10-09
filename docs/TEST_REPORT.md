# Test Report — CozyBlocks Phase 1

**Date:** 2026-10-09  
**Godot:** 4.3.stable  
**Branch:** `cursor/cozyblocks-phase1-e5ec`

## Automated tests

Command:

```bash
godot --headless --path . res://tests/test_runner.tscn
```

| Area | Result |
|------|--------|
| Block definitions / lookup | PASS |
| Inventory add/remove/consume + creative unlimited | PASS |
| Crafting recipes (consume inputs / produce outputs) | PASS |
| Placement AABB overlap helper | PASS |
| World serialize / deserialize | PASS |
| Chunk mesh + collision after edit | PASS |

**Totals: 33 passed, 0 failed.**

Headless renderer prints occasional `mesh_get_surface_count` null noise on empty air chunks; does not fail tests.

## Graphical smoke (Xvfb + OpenGL compatibility)

Vulkan is unavailable under Xvfb (`VK_KHR_surface` missing). Graphical runs used:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" \
  godot --path . --resolution 1280x720 \
    --rendering-method gl_compatibility --rendering-driver opengl3
```

`COZY_SMOKE=1` results:

| Check | Result |
|-------|--------|
| Launch without fatal errors | PASS (audio falls back to dummy driver — no sound device) |
| Break block → drop | PASS (`dirt` from grass) |
| Place block | PASS (wood) |
| Crafting recipe | PASS (`wood_to_planks`) |
| Save world | PASS |

Screenshot harness (`COZY_SCREENSHOTS=1`) wrote artifacts to `/opt/cursor/artifacts/screenshots/`:

- `01_main_building_area.png` — flat grass, sky, ambient props, hotbar, touch UI
- `02_built_structure.png` — small multi-block house + showcase in distance
- `03_showcase_environment.png` — Environment & Vegetation section
- `04_showcase_animals.png` — Fox (animated), Duck, Kenney bear + Quaternius note
- `05_showcase_furniture.png` — Furniture Kit samples
- `06_showcase_materials.png` — Poly Haven / prototype / block material cubes
- `07_crafting_ui.png` — crafting panel with recipes + Make buttons
- `08_touch_controls.png` — MOVE/LOOK + Jump/Break/Place/Craft overlays

## Manual checklist (environment limits)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Launches without fatal errors | PASS | Graphical + headless |
| 2 | Move and jump | PARTIAL | Code + touch/desktop bindings present; not hand-piloted in VM |
| 3 | Target and break a block | PASS | Smoke harness |
| 4 | Correct resource collected | PASS | Smoke: grass → dirt |
| 5 | Place a block | PASS | Smoke |
| 6 | Build a small structure | PASS | Screenshot harness built house |
| 7 | Hotbar selection | PARTIAL | UI slots + keys implemented; not interactive click-tested |
| 8 | Creative unlimited | PASS | Unit tests + UI toggle shown ON in shots |
| 9 | Crafting recipe works | PASS | Unit + smoke |
| 10 | Imported models/textures render | PARTIAL | Animals/materials clear; some Kenney nature/furniture still wash toward pale under llvmpipe despite metallic fix |
| 11 | Showcase accessible | PASS | Screenshots of sections |
| 12 | Save/load | PARTIAL | Save verified in smoke; load exercised in unit deserialize + menu wiring (not separate smoke load step) |
| 13 | Reset with confirmation | PARTIAL | Confirmation UI implemented; not click-tested in harness |
| 14 | Tablet for tablet platform | NOT RUN | No Android SDK / signing credentials in environment |

## Not verified

- Physical touchscreen / iPad / Android device performance
- Real tablet export (APK/IPA)
- Audio playback (no ALSA device; dummy driver)
- Vulkan rendering path
- Quaternius pack integration (Drive rate-limited)
- Human mouse-look / WASD play session beyond automated harness

## Known issues

1. Kenney Nature/Furniture materials import with `metallicFactor=1`; runtime override sets metallic=0 but some models still look pale on llvmpipe.
2. Showcase Label3Ds can clutter the view when standing between sections.
3. First graphical launch without `--rendering-method gl_compatibility` fails under Xvfb Vulkan.
4. Grass top texture reads very flat/bright from distance (nearest atlas tile).
