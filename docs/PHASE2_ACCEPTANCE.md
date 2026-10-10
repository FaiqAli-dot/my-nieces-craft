# Phase 2 acceptance checklist

Tip commit on `cursor/cozyblocks-phase2`: `5bb61e45eb2954e5c9824b35a2db6cc3910e7cf1`  
Merged face-winding: `c79be849` · Merged main (#4/#6/#7): via `5bb61e4`

## Checklist

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Third-person character controller | **Done / verified** | `01_character_controller.png`, unit/touch |
| Furniture catalog + place/move/rotate/cancel | **Done / verified** | catalog shot, touch 15/15, placement ghosts |
| Visible grid + green/red ghosts | **Done / verified** | `03_placement_valid.png`, `04_placement_invalid.png` |
| Cozy house visuals (walls/floor/windows/door/lighting) | **Done / verified** | live shots (not bare box) |
| Furniture scale vs avatar | **Done / verified** | retuned JSON + avatar 0.62 |
| Furnished example layout | **Done / verified** | `07_furnished_layout.png` |
| Styled status card + roster; debug text behind flag | **Done / verified** | shots; `COZY_DEBUG_HUD=1` |
| Reuse #7 touch components in house | **Done / verified** | VirtualJoystick/LookArea/ActionButton/CozyTouchTheme |
| Private houses + invites | **Done / verified** | MP + dual E2E |
| Collaboration toggle | **Done / verified** | MP + dual E2E steps 5/9/10 |
| Place sync across clients | **Done / verified** | MP + E2E step 7 |
| Move/rotate/remove sync | **Done / verified** | MP `_scenario_move_rotate_remove` |
| Concurrent ops same cell | **Done / verified** | MP |
| Duplicate op ids rejected | **Done / verified** | MP |
| Stale-version rejection | **Done / verified** | MP |
| Disconnect mid-edit | **Done / verified** | MP |
| Backend restart → layout restored | **Done / verified** | MP + E2E step 14 |
| Reconnect handling | **Done / verified** | MP + E2E |
| House isolation | **Done / verified** | MP + E2E step 15 |
| Unauthorized ownership/permission | **Done / verified** | MP |
| Invalid/expired/revoked invites | **Done / verified** | MP |
| Capacity limit | **Done / verified** | MP |
| Real dual-client 15-step E2E | **Done / verified** | `run_dual_e2e.sh` 17 PASS |
| Dual-client screenshot/video | **Done / verified** | `08_dual_client_side_by_side.png`, `phase2_dual_client_e2e.mp4` |
| Live-server screenshots (not Offline demo) | **Done / verified** | invite codes in shots |
| Mobile touch furniture path | **Done / verified** | house touch regression 15/15 |
| Face-winding fix on branch | **Done / verified** | merged `c79be849`; unit winding tests |
| Place/break mouse-filter regression | **Done / verified** | kept from #4; unit crosshair test |

## Test counts (latest run)

- Unit: **128** passed, 0 failed
- MP integration: **69** passed, 0 failed
- House touch: **15** passed, 0 failed
- Dual E2E: **17** PASS lines (11 alice + 6 bob), 0 FAIL

## Artifact paths

- Screenshots: `/opt/cursor/artifacts/screenshots/phase2/`
- Dual video: `/opt/cursor/artifacts/videos/phase2_dual_client_e2e.mp4`
