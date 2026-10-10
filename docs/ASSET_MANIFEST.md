# Asset Manifest — CozyBlocks (Phase 1.5)

All third-party packages are vendored in the repository (no runtime URL dependencies). Licenses live under `assets/licenses/`.

## Successfully integrated

### Quaternius — LowPoly Animated Animals (Phase 1.5)
- **Source:** https://quaternius.itch.io/lowpoly-animated-animals (official itch.io claim download)
- **License:** CC0 — `assets/licenses/quaternius_lowpoly_animated_animals.txt`
- **Retry note:** `assets/licenses/quaternius_itch_retry.txt` (Google Drive was **not** used; prior Drive rate-limit is documented)
- **Path:** `assets/models/animals/quaternius/{Cow,Sheep,Pig,Pug}.fbx`
- **Used:** Animal pen in the curated garden showcase, with painted toy materials + idle bob when FBX clips are unavailable
- **Rejected from pack:** Horse, Llama, Zebra, and format duplicates — kept a small cohesive farm set only

### Kenney — Nature Kit / Mini Forest / Furniture Kit
- **License:** CC0
- **Paths:** `assets/models/nature/`, `assets/models/props/`, `assets/models/furniture/`
- **Phase 1.5 use:** Meadow trees/rocks/flowers; garden flower nook + cozy corner (chair/table/plant/bear)
- **Materials:** Forced non-metallic paint overrides so washed Kenney imports stay saturated under daylight

### Kenney — Characters, Prototype Textures, Audio, UI / Skybox packs
- **Paths:** `assets/models/characters/`, `assets/textures/prototype/`, `assets/audio/`, `assets/ui/`, `assets/sky/`
- **Notes:** Available for later; Phase 1.5 world dressing prefers Nature Kit + original voxels

### Poly Haven
- **License:** CC0 — `assets/licenses/polyhaven.txt`
- **Path:** `assets/sky/kloppenheim_06_puresky_1k.hdr`, `assets/textures/polyhaven/`
- **Status:** Kept on disk; **not** used as primary meadow materials (photoreal vs toy voxels)

### Khronos glTF Sample Models
- **Path:** `assets/models/animals/Fox.glb`, `Duck.glb`
- **Phase 1.5 status:** **Removed from showcase** (style clash with Quaternius farm set). Files retained for reference/attribution only — see licenses

### CozyBlocks original block textures (Phase 1.5 rewrite)
- **Path:** `assets/textures/blocks/*.png` (+ `path_stone.png`)
- **License:** project original
- **Notes:** Softer toy tiles without hard per-face borders (borders caused a bright seam grid). UV half-texel inset in `voxel_chunk.gd`

### CozyBlocks animal paint textures
- **Path:** `assets/textures/animals/{cow_spots,sheep_wool,pig_pink,pug_brown}.png`
- **License:** project original — applied over Quaternius meshes for readable kid-friendly colors

### Font
- **Nunito Bold** — `assets/fonts/Nunito-Bold.ttf` (SIL OFL)

## Failed / blocked / rejected

| Source | Outcome | Why |
|--------|---------|-----|
| Quaternius via Google Drive (Phase 1) | Failed | Drive “too many users” rate limit — do not loop |
| Quaternius via itch.io (Phase 1.5) | **Success** | Official `download_url` claim → ZIP mirror |
| OpenGameArt Posable Poultry | Not integrated | `.blend` only; no Blender in env |
| Kenney Toon Characters | Skipped for 3D | 2D PNG parts |
| Extra Quaternius species | Rejected | Avoid asset-count bloat; farm quartet is enough |
| Poly Haven as world albedo | Rejected for meadow | Style mismatch with toy voxels |
| Khronos Fox/Duck in garden | Removed from active showcase | Different style family than Quaternius |

## Inventory

Run `find assets -type f | sort` for the full tree. Curated garden layout is documented in `docs/ASSET_EVALUATION.md`.
