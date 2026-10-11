extends RefCounted
class_name FurnitureValidator
## Authoritative placement rules shared by client preview and server.

enum Reason {
	OK,
	UNKNOWN_DEF,
	OUT_OF_BOUNDS,
	OVERLAP,
	BAD_SURFACE,
	NO_PERMISSION,
	HOUSE_MISMATCH,
	STALE_OP,
	DUPLICATE_OP,
	RATE_LIMIT,
	INVALID_PAYLOAD,
}


static func reason_text(r: int) -> String:
	## Short, kid-friendly copy for toasts / HUD.
	match r:
		Reason.OK:
			return "ok"
		Reason.UNKNOWN_DEF:
			return "Hmm, that furniture is missing"
		Reason.OUT_OF_BOUNDS:
			return "That doesn't fit in the room"
		Reason.OVERLAP:
			return "Something is already there"
		Reason.BAD_SURFACE:
			return "Need a clear floor spot"
		Reason.NO_PERMISSION:
			return "Only the owner can decorate right now"
		Reason.HOUSE_MISMATCH:
			return "Wrong house"
		Reason.STALE_OP:
			return "Oops — try that again"
		Reason.DUPLICATE_OP:
			return "Already done"
		Reason.RATE_LIMIT:
			return "Slow down a little"
		Reason.INVALID_PAYLOAD:
			return "That didn't work — try again"
		_:
			return "Can't place there"


static func validate_placement(
	def_id: String,
	anchor: Vector2i,
	rotation_deg: int,
	room_min: Vector2i,
	room_max: Vector2i,
	occupied: Dictionary,
	ignore_instance_id: String = ""
) -> int:
	if not FurnitureDB.has_id(def_id):
		return Reason.UNKNOWN_DEF
	var fp: Vector2i = FurnitureDB.footprint(def_id)
	var rot := FurnitureGrid.normalize_rotation(rotation_deg, FurnitureDB.rot_step(def_id))
	var cells := FurnitureGrid.occupied_cells(anchor, fp, rot)
	for c in cells:
		if c.x < room_min.x or c.y < room_min.y or c.x > room_max.x or c.y > room_max.y:
			return Reason.OUT_OF_BOUNDS
		var key := _cell_key(c)
		if occupied.has(key):
			var owner_id := str(occupied[key])
			if owner_id != "" and owner_id != ignore_instance_id:
				return Reason.OVERLAP
	return Reason.OK


static func build_occupied_map(instances: Array) -> Dictionary:
	## instances: Array of Dictionaries with instance_id, def_id, cell_x, cell_z, rotation
	var occupied := {}
	for inst in instances:
		if typeof(inst) != TYPE_DICTIONARY:
			continue
		var def_id := str(inst.get("def_id", ""))
		if not FurnitureDB.has_id(def_id):
			continue
		var anchor := Vector2i(int(inst.get("cell_x", 0)), int(inst.get("cell_z", 0)))
		var rot := int(inst.get("rotation", 0))
		var iid := str(inst.get("instance_id", ""))
		var fp := FurnitureDB.footprint(def_id)
		for c in FurnitureGrid.occupied_cells(anchor, fp, rot):
			occupied[_cell_key(c)] = iid
	return occupied


static func _cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]
