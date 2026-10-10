extends RefCounted
class_name FurnitureGrid
## Shared grid math for client + server furniture placement.

const CELL_SIZE := 1.0
const DEFAULT_ROT_STEP := 90


static func world_to_cell(world_pos: Vector3, origin: Vector3) -> Vector2i:
	var local := world_pos - origin
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.z / CELL_SIZE))


static func cell_to_world(cell: Vector2i, origin: Vector3, y: float = 0.0) -> Vector3:
	return origin + Vector3(
		(float(cell.x) + 0.5) * CELL_SIZE,
		y,
		(float(cell.y) + 0.5) * CELL_SIZE
	)


static func snap_world(world_pos: Vector3, origin: Vector3, y: float = 0.0) -> Vector3:
	return cell_to_world(world_to_cell(world_pos, origin), origin, y)


static func normalize_rotation(deg: int, step: int = DEFAULT_ROT_STEP) -> int:
	if step <= 0:
		step = DEFAULT_ROT_STEP
	var r := ((deg % 360) + 360) % 360
	# Snap to nearest increment
	var snapped: int = int(round(float(r) / float(step))) * step
	return ((snapped % 360) + 360) % 360


static func rotate_footprint(footprint: Vector2i, rotation_deg: int) -> Vector2i:
	var r := normalize_rotation(rotation_deg)
	if r == 90 or r == 270:
		return Vector2i(footprint.y, footprint.x)
	return footprint


static func occupied_cells(anchor: Vector2i, footprint: Vector2i, rotation_deg: int) -> Array[Vector2i]:
	var fp := rotate_footprint(footprint, rotation_deg)
	var cells: Array[Vector2i] = []
	for x in fp.x:
		for z in fp.y:
			cells.append(Vector2i(anchor.x + x, anchor.y + z))
	return cells


static func multi_cell_world_center(anchor: Vector2i, footprint: Vector2i, rotation_deg: int, origin: Vector3, y: float) -> Vector3:
	var fp := rotate_footprint(footprint, rotation_deg)
	var min_c := anchor
	var max_c := Vector2i(anchor.x + fp.x - 1, anchor.y + fp.y - 1)
	var a := cell_to_world(min_c, origin, y)
	var b := cell_to_world(max_c, origin, y)
	return (a + b) * 0.5
