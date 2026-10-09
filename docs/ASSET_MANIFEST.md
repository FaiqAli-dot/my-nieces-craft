# Asset Manifest — CozyBlocks Phase 1

All third-party packages were downloaded into the repository (no runtime URL dependencies). Licenses copied under `assets/licenses/` where provided by the pack.

## Successfully integrated

### Kenney — Nature Kit
- **Source:** https://kenney.nl/assets/nature-kit
- **License:** CC0 1.0 (see `assets/licenses/kenney_nature-kit.txt`)
- **Path:** `assets/models/nature/*.glb`
- **Included sample:** tree_oak, tree_pineDefaultA, tree_detailed, tree_cone, rock_*, grass*, flower_*, plant_bush*, cactus_*, mushroom_*, fence_simple, path_stone

### Kenney — Mini Forest
- **Source:** https://kenney.nl/assets/mini-forest
- **License:** CC0 (`assets/licenses/kenney_mini-forest.txt`)
- **Path:** `assets/models/props/` (tree, tree-high, rocks-*, plant, patch-grass + colormap)

### Kenney — Furniture Kit
- **Source:** https://kenney.nl/assets/furniture-kit
- **License:** CC0 (`assets/licenses/kenney_furniture-kit.txt`)
- **Path:** `assets/models/furniture/` (chair, table, bedSingle, desk, lamp, bookcase, bear, fridge, plants, rug, toilet, …)

### Kenney — Blocky Characters / Mini Characters
- **Sources:** https://kenney.nl/assets/blocky-characters , https://kenney.nl/assets/mini-characters
- **License:** CC0
- **Path:** `assets/models/characters/`

### Kenney — Prototype Textures
- **Source:** https://kenney.nl/assets/prototype-textures
- **License:** CC0
- **Path:** `assets/textures/prototype/`

### Kenney — Audio (Impact, Interface, RPG)
- **Sources:** kenney.nl impact-sounds / interface-sounds / rpg-audio
- **License:** CC0
- **Path:** `assets/audio/{impact,interface,rpg}/`

### Kenney — Skyboxes / UI Pack RPG / Input Prompts / Tiny Farm
- **Paths:** `assets/sky/skybox-*.png`, `assets/ui/`, `assets/ui/prompts/` (if extracted), `assets/textures/farm_tiles/`
- **License:** CC0
- **Notes:** Tiny Farm is **2D tiles** (not 3D animals). Used as farm art reference / tile sheet only.

### Poly Haven
- **Source:** https://polyhaven.com/
- **License:** CC0 1.0 (`assets/licenses/polyhaven.txt`)
- **HDRI:** `assets/sky/kloppenheim_06_puresky_1k.hdr`
- **Textures (1k diff/nor/rough):** grass_path_2, brown_mud_03, rock_face_03, wood_table_001, sandy_gravel_02 under `assets/textures/polyhaven/`

### Khronos glTF Sample Models (animal fallback)
- **Source:** https://github.com/KhronosGroup/glTF-Sample-Models
- **Path:** `assets/models/animals/Fox.glb`, `Duck.glb`
- **License notes:** See `assets/licenses/khronos_gltf_sample_models.txt`
  - Fox: CC0 (Cesium)
  - Duck: historically CC-BY from SCEA — retained only as temporary animal preview; attributed in licenses file

### CozyBlocks generated block textures
- **Path:** `assets/textures/blocks/*.png`
- **License:** project original (simple procedural tiles for voxel faces)

### Font
- **Nunito Bold** at `assets/fonts/Nunito-Bold.ttf` (SIL OFL via Google Fonts distribution)

## Failed / blocked sources

### Quaternius — Ultimate Animated Animals / Ultimate Stylized Nature
- **Source:** https://quaternius.com/ (packs distribute via Google Drive)
- **Attempt:** `gdown` folder download of Drive IDs linked from Quaternius pack pages (2026-10-09)
- **Result:** **FAILED** — Google Drive error: *“Too many users have viewed or downloaded this file recently”*
- **Retry:** Individual file downloads also rate-limited; itch.io page for lowpoly animals had no anonymous upload IDs exposed
- **Local note:** `assets/licenses/quaternius_FAILED.txt`
- **Fallback used:** Kenney furniture bear + Khronos Fox/Duck for Animals showcase section; Kenney nature/mini-forest for vegetation

### OpenGameArt — Posable Poultry
- **Source:** https://opengameart.org/content/posable-poultry
- **Downloaded:** `chickens.zip` (`.blend` only)
- **Result:** Not integrated — Blender not available in the environment to convert to GLB
- **Note:** `assets/licenses/opengameart_posable_poultry.txt`

### Kenney — Toon Characters
- **Downloaded then skipped for 3D showcase:** pack is 2D PNG character parts, not GLB models

## Full imported file inventory

Run `find assets -type f | sort` in the repo for the complete list. Representative showcase models are documented in `docs/ASSET_EVALUATION.md`.
