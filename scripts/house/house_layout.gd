extends RefCounted
class_name HouseLayout
## Persistent house record + furniture instances.
##
## Size tiers (Small / Medium / Large) are a kid-friendly step design — one tap
## grows or shrinks the whole room on a fixed grid, with server validation so
## furniture is never orphaned. Freeform wall editing is deferred.

const SCHEMA_VERSION := 2
const SIZE_SMALL := "small"
const SIZE_MEDIUM := "medium"
const SIZE_LARGE := "large"
const SIZE_ORDER: PackedStringArray = [SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE]
const SIZE_CELLS := {
	SIZE_SMALL: 12,
	SIZE_MEDIUM: 16,
	SIZE_LARGE: 20,
}
const SIZE_LABELS := {
	SIZE_SMALL: "Small",
	SIZE_MEDIUM: "Medium",
	SIZE_LARGE: "Large",
}

const DEFAULT_SIZE_TIER := SIZE_SMALL
const DEFAULT_ROOM_MIN := Vector2i(0, 0)
const DEFAULT_ROOM_MAX := Vector2i(11, 11) # 12x12 buildable cells
const DEFAULT_CAPACITY := 8

var house_id: String = ""
var owner_id: String = ""
var invite_code: String = ""
var invite_revoked: bool = false
var invite_expires_at: int = 0 ## unix seconds; 0 = no expiry
var collaboration_enabled: bool = false
var furniture: Array = [] # Array[Dictionary]
var revision: int = 0
var created_at: int = 0
var updated_at: int = 0
var room_min: Vector2i = DEFAULT_ROOM_MIN
var room_max: Vector2i = DEFAULT_ROOM_MAX
var capacity: int = DEFAULT_CAPACITY
var display_name: String = "Cozy House"
var size_tier: String = DEFAULT_SIZE_TIER


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"house_id": house_id,
		"owner_id": owner_id,
		"invite_code": invite_code,
		"invite_revoked": invite_revoked,
		"invite_expires_at": invite_expires_at,
		"collaboration_enabled": collaboration_enabled,
		"furniture": furniture.duplicate(true),
		"revision": revision,
		"created_at": created_at,
		"updated_at": updated_at,
		"room_min": [room_min.x, room_min.y],
		"room_max": [room_max.x, room_max.y],
		"capacity": capacity,
		"display_name": display_name,
		"size_tier": size_tier,
	}


func invite_is_valid(now_unix: int = -1) -> bool:
	if invite_code == "" or invite_revoked:
		return false
	if invite_expires_at > 0:
		var now := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
		if now >= invite_expires_at:
			return false
	return true


static func cells_for_tier(tier: String) -> int:
	return int(SIZE_CELLS.get(normalize_size_tier(tier), SIZE_CELLS[DEFAULT_SIZE_TIER]))


static func label_for_tier(tier: String) -> String:
	var t := normalize_size_tier(tier)
	return str(SIZE_LABELS.get(t, SIZE_LABELS[DEFAULT_SIZE_TIER]))


static func normalize_size_tier(tier: String) -> String:
	var t := tier.strip_edges().to_lower()
	if SIZE_CELLS.has(t):
		return t
	return DEFAULT_SIZE_TIER


static func tier_for_room_max(rmax: Vector2i) -> String:
	var cells := maxi(rmax.x, rmax.y) + 1
	var best := DEFAULT_SIZE_TIER
	var best_diff := 999
	for t in SIZE_ORDER:
		var d: int = absi(int(SIZE_CELLS[t]) - cells)
		if d < best_diff:
			best_diff = d
			best = t
	return best


static func from_dict(data: Dictionary) -> HouseLayout:
	var h := HouseLayout.new()
	if data.is_empty():
		return h
	h.house_id = str(data.get("house_id", ""))
	h.owner_id = str(data.get("owner_id", ""))
	h.invite_code = str(data.get("invite_code", ""))
	h.invite_revoked = bool(data.get("invite_revoked", false))
	h.invite_expires_at = int(data.get("invite_expires_at", 0))
	h.collaboration_enabled = bool(data.get("collaboration_enabled", false))
	h.furniture = data.get("furniture", [])
	if typeof(h.furniture) != TYPE_ARRAY:
		h.furniture = []
	h.revision = int(data.get("revision", 0))
	h.created_at = int(data.get("created_at", 0))
	h.updated_at = int(data.get("updated_at", 0))
	var rmin = data.get("room_min", [0, 0])
	var rmax = data.get("room_max", [11, 11])
	if typeof(rmin) == TYPE_ARRAY and rmin.size() >= 2:
		h.room_min = Vector2i(int(rmin[0]), int(rmin[1]))
	if typeof(rmax) == TYPE_ARRAY and rmax.size() >= 2:
		h.room_max = Vector2i(int(rmax[0]), int(rmax[1]))
	h.capacity = int(data.get("capacity", DEFAULT_CAPACITY))
	h.display_name = str(data.get("display_name", "Cozy House"))
	# Schema migration: infer size_tier from room bounds when missing (v1 saves).
	if data.has("size_tier"):
		h.size_tier = normalize_size_tier(str(data.get("size_tier", DEFAULT_SIZE_TIER)))
	else:
		h.size_tier = tier_for_room_max(h.room_max)
	h.apply_size_tier(h.size_tier, false)
	h._sanitize_furniture()
	return h


func apply_size_tier(tier: String, rewrite_bounds: bool = true) -> void:
	size_tier = normalize_size_tier(tier)
	if rewrite_bounds:
		var cells := cells_for_tier(size_tier)
		room_min = Vector2i(0, 0)
		room_max = Vector2i(cells - 1, cells - 1)


func furniture_max_cell() -> Vector2i:
	## Inclusive max cell occupied by any furniture footprint corner.
	var max_c := Vector2i(-1, -1)
	for inst in furniture:
		if typeof(inst) != TYPE_DICTIONARY:
			continue
		var def_id := str(inst.get("def_id", ""))
		if not FurnitureDB.has_id(def_id):
			continue
		var cell := Vector2i(int(inst.get("cell_x", 0)), int(inst.get("cell_z", 0)))
		var rot := int(inst.get("rotation", 0))
		var fp := FurnitureGrid.rotate_footprint(FurnitureDB.footprint(def_id), rot)
		max_c.x = maxi(max_c.x, cell.x + fp.x - 1)
		max_c.y = maxi(max_c.y, cell.y + fp.y - 1)
	return max_c


func can_apply_size_tier(tier: String) -> String:
	## Empty string = ok; otherwise a kid-readable reason.
	var t := normalize_size_tier(tier)
	if not SIZE_CELLS.has(t):
		return "Unknown house size"
	var cells := cells_for_tier(t)
	var need := furniture_max_cell()
	if need.x >= cells or need.y >= cells:
		return "Move furniture closer before making the house smaller"
	return ""


func spawn_position() -> Vector3:
	var cells := cells_for_tier(size_tier)
	var size := float(cells) * FurnitureGrid.CELL_SIZE
	return Vector3(size * 0.5, 0.1, size * 0.75)


func move_bounds() -> Dictionary:
	## Soft clamp for networked player positions (with a little outdoor apron).
	var cells := cells_for_tier(size_tier)
	var size := float(cells) * FurnitureGrid.CELL_SIZE
	return {
		"min_x": -1.0,
		"max_x": size + 2.0,
		"min_z": -1.0,
		"max_z": size + 1.0,
		"min_y": 0.0,
		"max_y": HouseSpace.WALL_H + 0.5,
	}


func _sanitize_furniture() -> void:
	var cleaned: Array = []
	var seen := {}
	for inst in furniture:
		if typeof(inst) != TYPE_DICTIONARY:
			continue
		var iid := str(inst.get("instance_id", ""))
		var def_id := str(inst.get("def_id", ""))
		if iid == "" or seen.has(iid):
			continue
		if not FurnitureDB.has_id(def_id):
			# Keep stub so layout doesn't crash; renderer skips missing defs.
			inst["missing_def"] = true
		seen[iid] = true
		inst["rotation"] = FurnitureGrid.normalize_rotation(int(inst.get("rotation", 0)))
		inst["cell_x"] = int(inst.get("cell_x", 0))
		inst["cell_z"] = int(inst.get("cell_z", 0))
		cleaned.append(inst)
	furniture = cleaned


func find_instance(instance_id: String) -> Dictionary:
	for inst in furniture:
		if str(inst.get("instance_id", "")) == instance_id:
			return inst
	return {}


func remove_instance(instance_id: String) -> bool:
	for i in furniture.size():
		if str(furniture[i].get("instance_id", "")) == instance_id:
			furniture.remove_at(i)
			return true
	return false
