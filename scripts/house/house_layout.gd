extends RefCounted
class_name HouseLayout
## Persistent house record + furniture instances.

const SCHEMA_VERSION := 1
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
	}


func invite_is_valid(now_unix: int = -1) -> bool:
	if invite_code == "" or invite_revoked:
		return false
	if invite_expires_at > 0:
		var now := now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
		if now >= invite_expires_at:
			return false
	return true


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
	h._sanitize_furniture()
	return h


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
