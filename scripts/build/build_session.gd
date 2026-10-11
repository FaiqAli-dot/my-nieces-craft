extends RefCounted
class_name BuildSession
## Shared selection + input state for tap-to-place and drag-and-place.
## Does not create world objects; adapters execute placement.

signal selection_changed(entry: Dictionary)
signal mode_changed(mode: int)
signal cancelled

enum Mode {
	IDLE,
	PLACE,
	MOVE,
	COPY,
	DRAG_PLACE,
}

var mode: int = Mode.IDLE
var entry: Dictionary = {}
var source: String = "" ## "catalog" | "hotbar" | "world" | "copy"
var instance_id: String = "" ## furniture move/copy source
var block_pos: Vector3i = Vector3i(-9999, 0, 0) ## block move source
var rotation_deg: int = 0
var drag_active := false
var drag_pointer_id := -1
var suppress_world_place := false ## true while catalog UI is handling the gesture


func is_busy() -> bool:
	return mode != Mode.IDLE


func selected_kind() -> String:
	return str(entry.get("kind", ""))


func selected_id() -> String:
	return str(entry.get("id", ""))


func clear() -> void:
	var was_busy := is_busy()
	mode = Mode.IDLE
	entry = {}
	source = ""
	instance_id = ""
	block_pos = Vector3i(-9999, 0, 0)
	rotation_deg = 0
	drag_active = false
	drag_pointer_id = -1
	suppress_world_place = false
	if was_busy:
		cancelled.emit()
	mode_changed.emit(mode)
	selection_changed.emit(entry)


func select_catalog_item(e: Dictionary, from_source: String = "catalog") -> void:
	## Selecting a catalog item must not place anything.
	if e.is_empty():
		return
	entry = e.duplicate(true)
	source = from_source
	instance_id = ""
	block_pos = Vector3i(-9999, 0, 0)
	rotation_deg = 0
	mode = Mode.PLACE
	drag_active = false
	drag_pointer_id = -1
	mode_changed.emit(mode)
	selection_changed.emit(entry)


func begin_drag(pointer_id: int) -> void:
	if entry.is_empty():
		return
	drag_active = true
	drag_pointer_id = pointer_id
	mode = Mode.DRAG_PLACE
	suppress_world_place = true
	mode_changed.emit(mode)


func end_drag() -> void:
	drag_active = false
	drag_pointer_id = -1
	suppress_world_place = false
	if mode == Mode.DRAG_PLACE:
		mode = Mode.PLACE if not entry.is_empty() else Mode.IDLE
		mode_changed.emit(mode)


func begin_move_furniture(iid: String, e: Dictionary, rot: int) -> void:
	entry = e.duplicate(true)
	source = "world"
	instance_id = iid
	rotation_deg = rot
	mode = Mode.MOVE
	mode_changed.emit(mode)
	selection_changed.emit(entry)


func begin_copy_furniture(iid: String, e: Dictionary, rot: int) -> void:
	entry = e.duplicate(true)
	source = "copy"
	instance_id = iid
	rotation_deg = rot
	mode = Mode.COPY
	mode_changed.emit(mode)
	selection_changed.emit(entry)


func begin_move_block(pos: Vector3i, e: Dictionary) -> void:
	entry = e.duplicate(true)
	source = "world"
	block_pos = pos
	mode = Mode.MOVE
	mode_changed.emit(mode)
	selection_changed.emit(entry)


func begin_copy_block(pos: Vector3i, e: Dictionary) -> void:
	entry = e.duplicate(true)
	source = "copy"
	block_pos = pos
	mode = Mode.COPY
	mode_changed.emit(mode)
	selection_changed.emit(entry)


func rotate_steps(steps: int = 1) -> void:
	if entry.is_empty() or not bool(entry.get("supports_rotation", false)):
		return
	var step := int(entry.get("rotation_increments_deg", 90))
	if step <= 0:
		return
	rotation_deg = FurnitureGrid.normalize_rotation(rotation_deg + step * steps, step)
