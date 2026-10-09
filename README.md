# CozyBlocks — Phase 1

Kid-friendly 3D voxel sandbox prototype (Godot 4.3 / GDScript). Validates art direction, asset pipeline, tablet controls, and basic building/crafting before a larger multiplayer world.

## Requirements

- Godot **4.3+** (standard build)
- Desktop keyboard/mouse for development; touch UI included for tablets
- Optional: Android export templates for APK builds

## Launch

Requires **Godot 4.3+**.

```bash
godot --path .
# or open the project folder in the Godot editor and press Play
```

On headless/CI displays (Xvfb), prefer OpenGL compatibility (Vulkan often lacks `VK_KHR_surface`):

```bash
xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

Headless tests:

```bash
godot --headless --path . res://tests/test_runner.tscn
```

Smoke run (auto quit):

```bash
COZY_SMOKE=1 COZY_SMOKE_QUIT=1 xvfb-run -a godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3
```

Force on-screen touch controls (desktop):

```bash
COZY_FORCE_TOUCH=1 godot --path .
```

Screenshots:

```bash
COZY_SCREENSHOTS=1 COZY_FORCE_TOUCH=1 COZY_SMOKE_QUIT=1 \
COZY_SHOT_DIR=/tmp/cozy-shots \
  xvfb-run -a godot --path . --resolution 1280x720 \
    --rendering-method gl_compatibility --rendering-driver opengl3
```

## Controls

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
| Creative toggle | G | Creative button |
| Return to start | R | Menu → Return to Start |
| Menu / mouse free | Esc | Menu |

## Project layout

See `docs/ARCHITECTURE.md`. Asset licenses and evaluation live in `docs/ASSET_MANIFEST.md` and `docs/ASSET_EVALUATION.md`.

## License note

Game code in this repository is provided for the CozyBlocks prototype. Third-party assets retain their own licenses (mostly CC0 from Kenney and Poly Haven). See `assets/licenses/` and `docs/ASSET_MANIFEST.md`.
