# CozyBlocks S2 — Survival Mode Foundation

Playable Survival progression (wood → crafting table → wooden pickaxe → stone → stone tools) on the finite meadow world. Reference ruleset: **Minecraft Java Edition 26.3**.

## Documented product decisions

| Decision | Choice |
|----------|--------|
| Edition pin | **Java Edition 26.3** (user-confirmed; supersedes SURVIVAL_READINESS 1.20.1 ask) |
| Legacy Limited | Saves with `creative: false` and no `game_mode` migrate to **Survival** |
| Mid-session mode toggle | Disabled (G / Mode chip toast only). Mode chosen on **New World** |
| Difficulty | Stored as `"normal"`; no gameplay effect in S2 |
| Crafting station | Place **Crafting Table** block; tool recipes require one within ~3.5 m |
| Creative-only recipes | `glass_from_sand`, `flower_mix` remain for Creative; hidden in Survival |
| Durability | Tools store durability and lose 1 per break; break at 0 (minimal UX) |
| Decorative GLB trees | Unchanged; **voxel oaks** added near spawn for harvestable wood |
| Stone access | Stone layer under dirt + surface **stone outcrop** near spawn |
| World drops | Lightweight `WorldDrop` entities on physics layer 3; capped at 80 |

## How to play (wood → stone)

1. Launch with no save → **New World** screen → tap **Survival**.
2. HUD shows **Survival**; bag starts empty; flight controls hidden.
3. Walk to a voxel tree (wood trunk + leaves near spawn).
4. Hold Break (mouse or touch) until the mining bar fills; collect the wood drop.
5. Open **Craft** → Make **Planks** → **Sticks** → **Crafting Table**.
6. Select the table on the hotbar, place it, stand nearby, open Craft again.
7. Make a **Wooden Pickaxe**; equip it; mine the stone outcrop (east of spawn).
8. Collect cobble; craft **Stone Pickaxe** (and Stone Axe/Shovel if you want).
9. Menu → **Save**. Reload confirms inventory + broken blocks persist.

## Mode UI

- First launch / Menu → **New World…** → two large picture buttons (Creative / Survival).
- Top bar Mode chip + label show the current mode (not a toggle).
- Creative keeps flight, unlimited consume, instant break, seeded hotbar.

## Save schema (v2)

```json
{
  "schema_version": 2,
  "game_mode": "creative" | "survival",
  "difficulty": "normal",
  "creative": true,
  "world": { "version": 1, "chunks": {} },
  "inventory": { "hotbar": [], "bag": [], "selected": 0, "layout": "9+27" },
  "drops": []
}
```

Legacy: missing `game_mode` → Creative; `creative: false` → Survival; hotbar 8 / bag 16 padded to 9+27.

## Tests

```bash
godot --headless --path . res://tests/test_runner.tscn
```

S2 coverage: game mode, validation, stacks/overflow, mining rules, drops/pickup, full progression + save/load, legacy migration, mode-select UI.
