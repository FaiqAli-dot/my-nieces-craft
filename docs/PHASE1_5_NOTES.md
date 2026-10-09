# Phase 1.5 — Visual Quality Overhaul Notes

**Branch:** `cursor/cozyblocks-phase1_5-visual-e5ec`  
**Targets PR base:** `cursor/cozyblocks-phase1-e5ec` (keeps Phase 1 history intact; cleaner than merging straight to `main` while Phase 1 is still the gameplay baseline)

## Five biggest visual weaknesses (pre-overhaul)

Documented in `docs/ART_DIRECTION.md`:

1. Empty neon meadow / flat green plane  
2. Weak noisy block identity  
3. Mismatched / washed prop materials  
4. Showcase as cluttered floating-label museum  
5. Generic grey UI  

## Art direction chosen

**Sunny Toy Meadow** — polished colorful voxel playground: toy blocks, warm daylight, garden composition, compatible low-poly props, icon-first UI. Palette tokens in `ART_DIRECTION.md`.

## What changed

- Hand-authored block textures + path stone; UV inset to kill seam grid  
- Meadow dressing: path, flower beds, sand patch, knolls, rim mounds, starter pad  
- Prop densification + material paint (Kenney)  
- Sky/fog/sun/fill lighting retune  
- Garden showcase (animals / flowers / cozy corner / blocks) replacing museum labels  
- Quaternius farm animals via itch.io + paint textures + idle bob  
- Colorful hotbar / touch UI; LOOK separated from hotbar  

## Gameplay preserved

Block place/break, inventory, crafting, save — exercised by unit tests + smoke.
