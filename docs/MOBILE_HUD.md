# Mobile Touch Controls & HUD

Polished, child-friendly on-screen controls for CozyBlocks (first-person meadow). Components are modular so Phase 2 can reuse them.

## Components

| Scene / script | Role |
| --- | --- |
| `scenes/ui/touch/touch_controls.tscn` | Safe-area shell: joystick + look + actions |
| `scenes/ui/touch/virtual_joystick.tscn` | Floating left-zone stick (spawn at thumb; clamp beyond radius; configurable fixed mode) |
| `scenes/ui/touch/look_area.tscn` | Right-side look drag (configurable sensitivity) |
| `scenes/ui/touch/action_button.tscn` | Circular Jump / Break / Place / Craft buttons |
| `scenes/ui/touch/touch_action_cluster.tscn` | Bottom-right button layout |
| `scenes/ui/touch/touch_hotbar.tscn` | Large tappable hotbar slots |
| `assets/ui/cozy_touch_theme.tres` + `CozyTouchTheme` | Shared Sunny Toy Meadow palette |

Non-interactive HUD chrome (crosshair, toast, labels) uses `MOUSE_FILTER_IGNORE` so it cannot swallow place/break clicks.

## Desktop vs touch

- Touch overlays show on mobile/iOS/Android, or when `COZY_FORCE_TOUCH=1` / `GameState.touch_controls_forced`.
- Keyboard/mouse bindings are unchanged.
- Intended orientation: **landscape** (project `window/handheld/orientation=4`). Portrait remains usable but is not the primary layout.

## Debug / tests

```bash
# Unit tests
godot --headless --path . res://tests/test_runner.tscn

# Multitouch + action regression (Xvfb)
COZY_TOUCH_TEST=1 COZY_FORCE_TOUCH=1 xvfb-run -a godot --path . \
  --resolution 1280x720 --rendering-method gl_compatibility --rendering-driver opengl3

# Phone / tablet HUD screenshots
COZY_MOBILE_HUD_SHOTS=1 COZY_FORCE_TOUCH=1 COZY_SMOKE_QUIT=1 \
  COZY_SAFE_INSET=48,12,48,28 COZY_SHOT_LABEL=phone_landscape \
  COZY_SHOT_DIR=/tmp/hud xvfb-run -a godot --path . \
  --resolution 1792x828 --rendering-method gl_compatibility --rendering-driver opengl3
```

Simulated multitouch uses `InputEventScreenTouch` / `ScreenDrag` with distinct `index` values. Real capacitive multitouch still needs a physical iPhone/iPad.

## Export to iPhone / iPad

1. Open the project in Godot 4.3 on macOS.
2. **Project → Export → Add… → iOS**.
3. Set a valid App Store team / bundle id, enable **Landscape Left/Right**, and keep portrait optional.
4. Ensure **Display** safe-area / notch is respected (TouchControls reads `DisplayServer.get_display_safe_area()`; override with `COZY_SAFE_INSET` for CI).
5. Export an Xcode project or `.ipa`, then run on a device or Simulator.
6. On device, verify: move + look together, jump while moving, break/place, hotbar taps, and that controls clear the home indicator.
