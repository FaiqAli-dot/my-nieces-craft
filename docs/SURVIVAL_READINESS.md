# Survival Mode — Readiness Assessment

Phase 1.6 intentionally does **not** implement Survival. This note maps what CozyBlocks already has, what is missing, and which Minecraft edition/version choices matter before coding starts.

## Reusable today

| System | Location | Survival reuse |
|--------|----------|----------------|
| Inventory + hotbar stacks | `Inventory`, `GameUi` / touch hotbar | Keep; add survival stack limits / non-creative give rules |
| Crafting recipes | `CraftingSystem`, `data/recipes` | Keep structure; gate by unlocked recipes / station later |
| Block break/place + drops | `PlayerController`, `VoxelWorld`, `BlockDB` | Keep; add tool tiers, hardness, timed break |
| Creative flag | `GameState.creative_mode` | Already disables flight when Limited; extend into full rule packs |
| Creative flight | `GameState.flying` + player controller | Auto-off when Survival starts (already wired via `set_creative(false)`) |
| Save/load world + inventory | `SaveGame` | Extend schema with health/hunger/gamemode/time |
| Meadow world gen | `VoxelWorld` / dresser | Day/night + spawners need time + entity layer |
| House MP (Phase 2) | NetClient / GameServer | Separate from meadow survival; do not overload house server with combat |

## Missing for real Survival

1. **Player vitals** — health, damage, invulnerability frames, hunger, saturation, exhaustion.
2. **Death / respawn** — drop rules, keepInventory option, bed/spawn point, clear flight.
3. **Mining rules** — block hardness, tool speed, correct drops, silk-touch equivalents if desired.
4. **Tool durability** — item metadata, break sounds, empty-hand fallback.
5. **Combat entities** — passive/hostile mob AI, pathfinding, spawn caps, despawn.
6. **Day/night + sleep** — world time, light levels, hostile spawn windows.
7. **Food use** — consumable items, eat animation/timer, poison/effects subset.
8. **Progression gates** — no infinite creative give; recipe unlock or gather-only.
9. **Difficulty** — Peaceful/Easy/Normal/Hard damage & hunger drain tables.
10. **Persistence** — gamemode per player, world time, mobs, player NBT-like blob.

Do **not** ship a fake Survival that only draws a heart bar while keeping creative flight, infinite blocks, and one-hit break.

## Target edition / version — **LOCKED**

**Primary target = Minecraft Java Edition 26.3** (product decision for S2).

S2 implements the wood→stone gathering/crafting loop only (see `docs/S2_SURVIVAL.md`). Hunger, combat, day/night, ores, and mobs remain later phases.

## Suggested phase split

1. **S2 Survival foundations (done)** — gamemode enum, timed mining, tools, drops, 9+27 inventory, JE recipes, save schema, New World UI.
2. **Gathering+** — fuller durability UX, more tools, furnaces.
3. **World living** — time cycle, passive mobs, then limited hostiles; vitals/hunger.
4. **Polish** — difficulty behavior, hearts/drumsticks, soft-kid options.
