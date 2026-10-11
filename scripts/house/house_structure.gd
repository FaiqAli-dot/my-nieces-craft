extends RefCounted
class_name HouseStructure
## Walls, windows and doors sit on the 1 m edges between house cells.
##
## Edge keys:
##   "h:x:z" — runs along X on grid line z (north side of cell x,z)
##   "v:x:z" — runs along Z on grid line x (west side of cell x,z)
## A house stores only differences from the default (solid perimeter with a
## double door in the middle of the east wall), so old saves need no data.
## Shared by the server, offline play and the client preview.

const NONE := ""
const WALL := "wall"
const WINDOW := "window"
const DOOR := "door"
const DOOR_OPEN := "door_open"
## Stored override for a perimeter edge the player knocked out.
const OPEN := "open"
## Tools the player can build with ("" = remove).
const TOOLS: PackedStringArray = [WALL, WINDOW, DOOR, NONE]

enum Reason {
	OK,
	OUT_OF_BOUNDS,
	BAD_KIND,
	NO_CHANGE,
	FURNITURE_IN_WAY,
	DOORWAY_BLOCKED,
	LAST_EXIT,
	NOT_A_DOOR,
}


static func reason_text(r: int) -> String:
	match r:
		Reason.OK:
			return "ok"
		Reason.OUT_OF_BOUNDS:
			return "Build inside your house"
		Reason.BAD_KIND:
			return "That piece is missing"
		Reason.NO_CHANGE:
			return "Already like that"
		Reason.FURNITURE_IN_WAY:
			return "Furniture is in the way"
		Reason.DOORWAY_BLOCKED:
			return "Clear the doorway first"
		Reason.LAST_EXIT:
			return "Keep at least one way out!"
		Reason.NOT_A_DOOR:
			return "That's not a door"
		_:
			return "Can't build there"


static func key_h(x: int, z: int) -> String:
	return "h:%d:%d" % [x, z]


static func key_v(x: int, z: int) -> String:
	return "v:%d:%d" % [x, z]


## {axis:"h"/"v", x, z} or {} if malformed.
static func parse(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 3 or (parts[0] != "h" and parts[0] != "v"):
		return {}
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	return {"axis": parts[0], "x": int(parts[1]), "z": int(parts[2])}


static func in_bounds(key: String, cells: int) -> bool:
	var e := parse(key)
	if e.is_empty():
		return false
	if e["axis"] == "h":
		return e["x"] >= 0 and e["x"] < cells and e["z"] >= 0 and e["z"] <= cells
	return e["z"] >= 0 and e["z"] < cells and e["x"] >= 0 and e["x"] <= cells


static func is_perimeter(key: String, cells: int) -> bool:
	if not in_bounds(key, cells):
		return false
	var e := parse(key)
	if e["axis"] == "h":
		return e["z"] == 0 or e["z"] == cells
	return e["x"] == 0 or e["x"] == cells


static func default_door_edges(cells: int) -> PackedStringArray:
	return PackedStringArray([key_v(cells, cells / 2 - 1), key_v(cells, cells / 2)])


static func default_window_edges(cells: int) -> PackedStringArray:
	return PackedStringArray([key_h(int(cells * 0.32), 0), key_h(int(cells * 0.68), 0)])


static func default_kind(key: String, cells: int) -> String:
	if not is_perimeter(key, cells):
		return NONE
	if key in default_door_edges(cells):
		return DOOR
	if key in default_window_edges(cells):
		return WINDOW
	return WALL


static func kind_at(walls: Dictionary, key: String, cells: int) -> String:
	if not in_bounds(key, cells):
		return NONE
	if walls.has(key):
		var k := str(walls[key])
		return NONE if k == OPEN else k
	return default_kind(key, cells)


static func is_door(kind: String) -> bool:
	return kind == DOOR or kind == DOOR_OPEN


static func perimeter_edges(cells: int) -> PackedStringArray:
	var out := PackedStringArray()
	for i in cells:
		out.append(key_h(i, 0))
		out.append(key_h(i, cells))
		out.append(key_v(0, i))
		out.append(key_v(cells, i))
	return out


## Every visible piece: key -> kind.
static func pieces(walls: Dictionary, cells: int) -> Dictionary:
	var out := {}
	for key in perimeter_edges(cells):
		var k := kind_at(walls, key, cells)
		if k != NONE:
			out[key] = k
	for key in walls.keys():
		if out.has(key) or not in_bounds(str(key), cells):
			continue
		var k := kind_at(walls, str(key), cells)
		if k != NONE:
			out[str(key)] = k
	return out


## The two cells an edge separates (one may be outside the house).
static func adjacent_cells(key: String) -> Array[Vector2i]:
	var e := parse(key)
	if e.is_empty():
		return []
	if e["axis"] == "h":
		return [Vector2i(e["x"], e["z"] - 1), Vector2i(e["x"], e["z"])]
	return [Vector2i(e["x"] - 1, e["z"]), Vector2i(e["x"], e["z"])]


static func exit_count(walls: Dictionary, cells: int) -> int:
	var n := 0
	for key in perimeter_edges(cells):
		var k := kind_at(walls, key, cells)
		if k == NONE or is_door(k):
			n += 1
	return n


static func _footprint_cells(furniture: Array) -> Dictionary:
	## "x,z" -> instance_id for every furniture cell.
	return FurnitureValidator.build_occupied_map(furniture)


## Can `kind` be built on `key`? kind "" removes the piece.
static func validate_edit(walls: Dictionary, cells: int, furniture: Array, key: String, kind: String) -> int:
	if not in_bounds(key, cells):
		return Reason.OUT_OF_BOUNDS
	if not kind in TOOLS:
		return Reason.BAD_KIND
	var current := kind_at(walls, key, cells)
	var cur_norm := DOOR if is_door(current) else current
	if cur_norm == kind:
		return Reason.NO_CHANGE
	var occ := _footprint_cells(furniture)
	var adj := adjacent_cells(key)
	if kind != NONE:
		var a := "%d,%d" % [adj[0].x, adj[0].y]
		var b := "%d,%d" % [adj[1].x, adj[1].y]
		if occ.has(a) and occ.has(b) and occ[a] == occ[b]:
			return Reason.FURNITURE_IN_WAY
	if kind == DOOR:
		for c in adj:
			if occ.has("%d,%d" % [c.x, c.y]):
				return Reason.DOORWAY_BLOCKED
	if is_perimeter(key, cells) and (kind == WALL or kind == WINDOW):
		var next := walls.duplicate()
		apply_edit(next, cells, key, kind)
		if exit_count(next, cells) == 0:
			return Reason.LAST_EXIT
	return Reason.OK


## Writes the override for `kind` (assumes validate_edit passed).
static func apply_edit(walls: Dictionary, cells: int, key: String, kind: String) -> void:
	var stored := kind
	if kind == NONE:
		stored = OPEN if is_perimeter(key, cells) else NONE
	if stored == default_kind(key, cells):
		walls.erase(key)
	else:
		walls[key] = stored


## Flips a door open/closed. Returns the new kind, or "" if `key` is no door.
static func toggle_door(walls: Dictionary, cells: int, key: String) -> String:
	var k := kind_at(walls, key, cells)
	if not is_door(k):
		return ""
	var next := DOOR if k == DOOR_OPEN else DOOR_OPEN
	if next == default_kind(key, cells):
		walls.erase(key)
	else:
		walls[key] = next
	return next


## Furniture may not straddle a wall or stand in a doorway.
static func furniture_conflict(walls: Dictionary, cells: int, fp_cells: Array) -> int:
	if cells <= 0:
		return Reason.OK
	var mine := {}
	for c in fp_cells:
		mine["%d,%d" % [c.x, c.y]] = true
	var all := pieces(walls, cells)
	for key in all.keys():
		var adj := adjacent_cells(key)
		var ia := mine.has("%d,%d" % [adj[0].x, adj[0].y])
		var ib := mine.has("%d,%d" % [adj[1].x, adj[1].y])
		if ia and ib:
			return Reason.FURNITURE_IN_WAY
		if is_door(str(all[key])) and (ia or ib):
			return Reason.DOORWAY_BLOCKED
	return Reason.OK


## Pieces that would be cut off by shrinking to `new_cells`.
static func blocks_resize(walls: Dictionary, new_cells: int) -> bool:
	for key in walls.keys():
		var k := str(walls[key])
		if k == OPEN:
			continue
		if not in_bounds(str(key), new_cells):
			return true
	return false


## Overrides that survive a resize. Old perimeter tweaks on lines that stop
## being the outside wall are dropped so no stray door floats mid-room.
static func on_resize(walls: Dictionary, old_cells: int, new_cells: int) -> Dictionary:
	var out := {}
	for key in walls.keys():
		var k := str(walls[key])
		if not in_bounds(str(key), new_cells):
			continue
		var was_perim := is_perimeter(str(key), old_cells)
		var now_perim := is_perimeter(str(key), new_cells)
		if was_perim and not now_perim:
			continue
		if k == OPEN and not now_perim:
			continue
		out[key] = k
	return out


## Drops malformed entries (bad keys/kinds) from untrusted data.
static func sanitize(raw: Variant, cells: int) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in (raw as Dictionary).keys():
		var k := str(raw[key])
		if not in_bounds(str(key), cells):
			continue
		if k in [WALL, WINDOW, DOOR, DOOR_OPEN, OPEN]:
			out[str(key)] = k
	return out


## Nearest edge to a floor point (world == grid coords; origin at 0,0).
static func edge_near(p: Vector3) -> String:
	var fx := p.x - floorf(p.x)
	var fz := p.z - floorf(p.z)
	var dx := minf(fx, 1.0 - fx)
	var dz := minf(fz, 1.0 - fz)
	if dx < dz:
		return key_v(roundi(p.x), floori(p.z))
	return key_h(floori(p.x), roundi(p.z))


## World-space centre of an edge at floor height.
static func edge_center(key: String) -> Vector3:
	var e := parse(key)
	if e.is_empty():
		return Vector3.ZERO
	if e["axis"] == "h":
		return Vector3(float(e["x"]) + 0.5, 0.0, float(e["z"]))
	return Vector3(float(e["x"]), 0.0, float(e["z"]) + 0.5)
