extends RefCounted
class_name BuildCatalog
## Unified placeable catalog over BlockDB + FurnitureDB.
## Categories are kid-facing groups; only real placeable content is listed.
## Optional Phase-3 metadata keys (behavior_type, attachments) are passed through
## when present on furniture defs — no runtime machines in Phase 2.

const CAT_BLOCKS := "blocks"
const CAT_FURNITURE := "furniture"
const CAT_DECORATIONS := "decorations"
const CAT_GARDEN := "garden"

const CATEGORY_ORDER: Array[String] = [CAT_BLOCKS, CAT_FURNITURE, CAT_DECORATIONS, CAT_GARDEN]

const CATEGORY_LABELS := {
	CAT_BLOCKS: "Blocks",
	CAT_FURNITURE: "Furniture",
	CAT_DECORATIONS: "Decorations",
	CAT_GARDEN: "Garden",
}

## Meadow / voxel block → kid category. Unknown placeables fall back to Blocks.
const BLOCK_CATEGORY := {
	"grass": CAT_GARDEN,
	"dirt": CAT_BLOCKS,
	"stone": CAT_BLOCKS,
	"sand": CAT_GARDEN,
	"wood": CAT_BLOCKS,
	"leaves": CAT_GARDEN,
	"glass": CAT_DECORATIONS,
	"planks": CAT_BLOCKS,
	"cobble": CAT_BLOCKS,
	"brick": CAT_BLOCKS,
	"wool_red": CAT_DECORATIONS,
	"wool_blue": CAT_DECORATIONS,
	"wool_yellow": CAT_DECORATIONS,
	"wool_pink": CAT_DECORATIONS,
	"wool_green": CAT_DECORATIONS,
	"flower_block": CAT_GARDEN,
	"path_stone": CAT_GARDEN,
	"crafting_table": CAT_BLOCKS,
}

## FurnitureDB categories → kid tabs.
const FURNITURE_CATEGORY := {
	"seating": CAT_FURNITURE,
	"tables": CAT_FURNITURE,
	"bedroom": CAT_FURNITURE,
	"storage": CAT_FURNITURE,
	"decor": CAT_DECORATIONS,
}


static func category_label(cat: String) -> String:
	return str(CATEGORY_LABELS.get(cat, cat.capitalize()))


static func entries_for_context(context: String) -> Array[Dictionary]:
	## context: "meadow" (blocks only) or "house" (furniture only) or "all".
	var out: Array[Dictionary] = []
	if context == "meadow" or context == "all":
		for name in BlockDB.all_placeable_names():
			out.append(block_entry(name))
	if context == "house" or context == "all":
		for fid in FurnitureDB.all_ids():
			out.append(furniture_entry(fid))
	return out


static func entries_in_category(context: String, category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries_for_context(context):
		if str(e.get("category", "")) == category:
			out.append(e)
	return out


static func available_categories(context: String) -> Array[String]:
	var present := {}
	for e in entries_for_context(context):
		present[str(e.get("category", ""))] = true
	var out: Array[String] = []
	for c in CATEGORY_ORDER:
		if present.has(c):
			out.append(c)
	return out


static func block_entry(item_id: String) -> Dictionary:
	var cat := str(BLOCK_CATEGORY.get(item_id, CAT_BLOCKS))
	return {
		"kind": "block",
		"id": item_id,
		"display_name": BlockDB.display_name(item_id),
		"category": cat,
		"footprint": Vector2i(1, 1),
		"rotation_increments_deg": 0,
		"supports_rotation": false,
		"supports_copy": true,
		"supports_move": true,
		"supports_remove": true,
		"supports_history": true,
		# Phase 3 readiness (unused in Phase 2)
		"behavior_type": "static_block",
		"attachments": [],
		"icon": BlockDB.icon_texture(item_id),
	}


static func furniture_entry(def_id: String) -> Dictionary:
	var def := FurnitureDB.get_def(def_id)
	var raw_cat := FurnitureDB.category(def_id)
	var cat := str(FURNITURE_CATEGORY.get(raw_cat, CAT_FURNITURE))
	return {
		"kind": "furniture",
		"id": def_id,
		"display_name": FurnitureDB.display_name(def_id),
		"category": cat,
		"footprint": FurnitureDB.footprint(def_id),
		"rotation_increments_deg": FurnitureDB.rot_step(def_id),
		"supports_rotation": true,
		"supports_copy": true,
		"supports_move": true,
		"supports_remove": true,
		"supports_history": true,
		"behavior_type": str(def.get("behavior_type", "static_furniture")),
		"attachments": def.get("attachments", []),
		"icon": FurnitureDB.make_preview_texture(def_id),
	}


static func find_entry(context: String, kind: String, id: String) -> Dictionary:
	for e in entries_for_context(context):
		if str(e.get("kind", "")) == kind and str(e.get("id", "")) == id:
			return e
	return {}


static func survival_count_text(item_id: String, inventory: Inventory) -> String:
	if inventory == null or GameState.is_creative():
		return ""
	var n := inventory.count_of(item_id)
	if n <= 0:
		return "Costs 1 — need more"
	return "Costs 1 — have x%d" % n
