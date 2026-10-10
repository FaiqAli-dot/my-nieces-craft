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

## Target edition / version (needs approval)

Pick one primary rule set before implementation. Candidates:

| Target | Why | Key rule differences |
|--------|-----|----------------------|
| **Java 1.20.1** (recommend default) | Stable docs, common “classic” sandbox reference; matches many tutorials kids’ parents know | Natural regen with hunger ≥ 18; exhaustion from sprint/jump; bed skips night if all players sleep; creeper/zombie/skeleton classic kit |
| **Java 1.21.x** | Newer; trial chambers / new mobs if we ever want them | Extra mobs/blocks; combat still similar; more content surface area |
| **Bedrock 1.20/1.21** | Closer to mobile/console family play | Spawn rules & redstone differ; hunger/regen broadly similar; some drop tables differ |
| **Minecraft Education** | Classroom-friendly | Often creative-first; survival extras vary — poor fit unless curriculum demands it |

**Version-dependent choices to lock explicitly**

- Combat: Java 1.9+ attack cooldown vs legacy spam-click.
- Hunger: do we implement full exhaustion or a simplified kid-friendly drain?
- KeepInventory: off by default (Java default) vs optional soft mode for ages 5–8.
- Hostile mob set: full classic set vs gentle slime-only “cozy survival”.
- Multiplayer meadow survival: local-only first vs later authoritative server (house server is furniture-only today).

## Suggested phase split (after approval)

1. **Survival foundations** — gamemode enum, vitals, hunger, death/respawn, creative/survival rule fork, save schema.
2. **Gathering** — hardness, tools, durability, drops.
3. **World living** — time cycle, passive mobs, then limited hostiles.
4. **Polish** — difficulty, sounds, UI hearts/drumsticks, soft-kid options.

## Approval ask

Please confirm: **primary target = Java Edition 1.20.1 rules**, with an optional **Cozy soft mode** (slower hunger, fewer hostiles, keepInventory toggle) for the nieces’ age range — without changing the underlying edition math when soft mode is off.
