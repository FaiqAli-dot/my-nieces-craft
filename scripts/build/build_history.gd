extends RefCounted
class_name BuildHistory
## Bounded undo/redo for supported building ops.
## Entries are Dictionaries; adapters apply/reverse them.
## Limit is documented: MAX_ENTRIES (default 32). Does not snapshot the world.

signal changed

const MAX_ENTRIES := 32

enum Op {
	PLACE_BLOCK,
	REMOVE_BLOCK,
	MOVE_BLOCK,
	COPY_BLOCK,
	PLACE_FURNITURE,
	REMOVE_FURNITURE,
	MOVE_FURNITURE,
	ROTATE_FURNITURE,
	COPY_FURNITURE,
}

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var enabled := true


func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()


func can_undo() -> bool:
	return enabled and not _undo.is_empty()


func can_redo() -> bool:
	return enabled and not _redo.is_empty()


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


func peek_undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	return _undo[_undo.size() - 1]


func peek_redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	return _redo[_redo.size() - 1]


func push(entry: Dictionary) -> void:
	## Invalid/cancelled actions must not call this.
	if not enabled or entry.is_empty():
		return
	var e := entry.duplicate(true)
	e["ts"] = Time.get_ticks_msec()
	_undo.append(e)
	while _undo.size() > MAX_ENTRIES:
		_undo.remove_at(0)
	_redo.clear()
	changed.emit()


func pop_undo() -> Dictionary:
	if not can_undo():
		return {}
	var e: Dictionary = _undo.pop_back()
	_redo.append(e)
	changed.emit()
	return e


func pop_redo() -> Dictionary:
	if not can_redo():
		return {}
	var e: Dictionary = _redo.pop_back()
	_undo.append(e)
	changed.emit()
	return e


func restore_failed_undo(entry: Dictionary) -> void:
	## Soft-fail: put the entry back on the undo stack and drop the redo copy.
	if entry.is_empty():
		return
	if not _redo.is_empty() and _redo[_redo.size() - 1] == entry:
		_redo.pop_back()
	_undo.append(entry)
	changed.emit()


func restore_failed_redo(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	if not _undo.is_empty() and _undo[_undo.size() - 1] == entry:
		_undo.pop_back()
	_redo.append(entry)
	changed.emit()


## --- Factory helpers (one logical user action → one entry) ---

static func block_place(pos: Vector3i, item_id: String, block_id: int, prev_id: int = 0) -> Dictionary:
	return {
		"op": Op.PLACE_BLOCK,
		"pos": {"x": pos.x, "y": pos.y, "z": pos.z},
		"item_id": item_id,
		"block_id": block_id,
		"prev_id": prev_id,
	}


static func block_remove(pos: Vector3i, item_id: String, block_id: int, drop_item: String = "") -> Dictionary:
	return {
		"op": Op.REMOVE_BLOCK,
		"pos": {"x": pos.x, "y": pos.y, "z": pos.z},
		"item_id": item_id,
		"block_id": block_id,
		"drop_item": drop_item if drop_item != "" else item_id,
	}


static func block_move(from_pos: Vector3i, to_pos: Vector3i, item_id: String, block_id: int, dest_prev: int = 0) -> Dictionary:
	return {
		"op": Op.MOVE_BLOCK,
		"from": {"x": from_pos.x, "y": from_pos.y, "z": from_pos.z},
		"to": {"x": to_pos.x, "y": to_pos.y, "z": to_pos.z},
		"item_id": item_id,
		"block_id": block_id,
		"dest_prev": dest_prev,
	}


static func block_copy(pos: Vector3i, item_id: String, block_id: int, prev_id: int = 0) -> Dictionary:
	var e := block_place(pos, item_id, block_id, prev_id)
	e["op"] = Op.COPY_BLOCK
	return e


static func furniture_place(instance_id: String, def_id: String, cell: Vector2i, rotation: int, revision: int = -1) -> Dictionary:
	return {
		"op": Op.PLACE_FURNITURE,
		"instance_id": instance_id,
		"def_id": def_id,
		"cell_x": cell.x,
		"cell_z": cell.y,
		"rotation": rotation,
		"revision": revision,
	}


static func furniture_remove(inst: Dictionary, revision: int = -1) -> Dictionary:
	return {
		"op": Op.REMOVE_FURNITURE,
		"instance_id": str(inst.get("instance_id", "")),
		"def_id": str(inst.get("def_id", "")),
		"cell_x": int(inst.get("cell_x", 0)),
		"cell_z": int(inst.get("cell_z", 0)),
		"rotation": int(inst.get("rotation", 0)),
		"revision": revision,
	}


static func furniture_move(instance_id: String, def_id: String, from_cell: Vector2i, from_rot: int, to_cell: Vector2i, to_rot: int, revision: int = -1) -> Dictionary:
	var op := Op.MOVE_FURNITURE
	if from_cell == to_cell and from_rot != to_rot:
		op = Op.ROTATE_FURNITURE
	return {
		"op": op,
		"instance_id": instance_id,
		"def_id": def_id,
		"from_cell_x": from_cell.x,
		"from_cell_z": from_cell.y,
		"from_rotation": from_rot,
		"cell_x": to_cell.x,
		"cell_z": to_cell.y,
		"rotation": to_rot,
		"revision": revision,
	}


static func furniture_copy(instance_id: String, def_id: String, cell: Vector2i, rotation: int, revision: int = -1) -> Dictionary:
	var e := furniture_place(instance_id, def_id, cell, rotation, revision)
	e["op"] = Op.COPY_FURNITURE
	return e


static func vec3i_of(d: Dictionary, key: String = "") -> Vector3i:
	var src: Dictionary = d if key == "" else d.get(key, {})
	if typeof(src) != TYPE_DICTIONARY:
		return Vector3i.ZERO
	return Vector3i(int(src.get("x", 0)), int(src.get("y", 0)), int(src.get("z", 0)))
