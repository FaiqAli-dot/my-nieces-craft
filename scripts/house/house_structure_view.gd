extends Node3D
class_name HouseStructureView
## Builds wall / window / door pieces from HouseStructure data.
## Door open/close animates in place; any other change rebuilds the pieces.

const T := 0.24
const DOOR_H := HouseSpace.DOOR_CLEARANCE
const SILL_H := 1.15
const HEAD_H := 2.55
const OPEN_ANGLE := deg_to_rad(100.0)
const DOOR_ANIM_SEC := 0.28

var wall_h: float = 4.8
var cells: int = 12
var walls: Dictionary = {}
## edge key -> {pivot, shape, kind}
var doors: Dictionary = {}
var _kinds: Dictionary = {}

var _mat_wall: StandardMaterial3D
var _mat_outer: StandardMaterial3D
var _mat_frame: StandardMaterial3D
var _mat_door: StandardMaterial3D
var _mat_knob: StandardMaterial3D
var _mat_glass: StandardMaterial3D


func _init() -> void:
	_mat_wall = _mat(Color(0.98, 0.93, 0.82), 0.96)
	_mat_outer = _mat(Color(0.78, 0.58, 0.38), 0.9)
	_mat_frame = _mat(Color(0.68, 0.46, 0.28), 0.85)
	_mat_door = _mat(Color(0.85, 0.55, 0.38), 0.8)
	_mat_knob = _mat(Color(1.0, 0.85, 0.35), 0.6)
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.albedo_color = Color(0.55, 0.82, 0.98, 0.45)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.emission_enabled = true
	_mat_glass.emission = Color(0.65, 0.88, 1.0)
	_mat_glass.emission_energy_multiplier = 0.55
	_mat_glass.cull_mode = BaseMaterial3D.CULL_DISABLED


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Full rebuild unless only door states differ (then animate those doors).
func apply(p_walls: Dictionary, p_cells: int, animate: bool = true) -> void:
	var next := HouseStructure.pieces(p_walls, p_cells)
	var only_doors := p_cells == cells and next.size() == _kinds.size() and not _kinds.is_empty()
	if only_doors:
		for key in next.keys():
			var a := str(next[key])
			var b := str(_kinds.get(key, "__missing"))
			if a == b:
				continue
			if not (HouseStructure.is_door(a) and HouseStructure.is_door(b)):
				only_doors = false
				break
	walls = p_walls.duplicate()
	cells = p_cells
	if only_doors:
		for key in next.keys():
			if str(next[key]) != str(_kinds[key]):
				_set_door_open(key, str(next[key]) == HouseStructure.DOOR_OPEN, animate)
		_kinds = next
		return
	_kinds = next
	_rebuild()


func piece_kind(key: String) -> String:
	return str(_kinds.get(key, HouseStructure.NONE))


func is_door_open(key: String) -> bool:
	return doors.has(key) and bool(doors[key]["open"])


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	doors.clear()
	for key in _kinds.keys():
		var kind := str(_kinds[key])
		match kind:
			HouseStructure.WALL:
				_build_wall(key)
			HouseStructure.WINDOW:
				_build_window(key)
			HouseStructure.DOOR, HouseStructure.DOOR_OPEN:
				_build_door(key, kind == HouseStructure.DOOR_OPEN)
	_build_posts()


## Piece frame: origin at edge centre, local X along the edge, local Z across.
func _piece_root(key: String) -> Node3D:
	var e := HouseStructure.parse(key)
	var root := Node3D.new()
	root.name = "Piece_" + key.replace(":", "_")
	var c := HouseStructure.edge_center(key)
	var out := _outward(key)
	root.position = c + out * (T * 0.5)
	if e["axis"] == "v":
		root.rotation.y = PI * 0.5
	add_child(root)
	root.set_meta("edge", key)
	return root


## Outward normal for perimeter edges (zero for interior edges).
func _outward(key: String) -> Vector3:
	if not HouseStructure.is_perimeter(key, cells):
		return Vector3.ZERO
	var e := HouseStructure.parse(key)
	if e["axis"] == "h":
		return Vector3(0, 0, -1) if e["z"] == 0 else Vector3(0, 0, 1)
	return Vector3(-1, 0, 0) if e["x"] == 0 else Vector3(1, 0, 0)


func _solid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = pos
	body.add_child(shape)
	if mat != null:
		_visual(body, pos, size, mat)
	return body


func _visual(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _outer_band(root: Node3D, key: String) -> void:
	if HouseStructure.is_perimeter(key, cells):
		# Warm wood skirting on the garden side.
		var side := signf(_local_z(key).dot(_outward(key)))
		_visual(root, Vector3(0, 0.35, side * (T * 0.5 + 0.03)), Vector3(1.0, 0.7, 0.06), _mat_outer)


## World direction of a piece's local +Z (pieces on "v" edges are turned 90°).
func _local_z(key: String) -> Vector3:
	return Vector3(1, 0, 0) if HouseStructure.parse(key)["axis"] == "v" else Vector3(0, 0, 1)


func _build_wall(key: String) -> void:
	var root := _piece_root(key)
	_solid(root, Vector3(0, wall_h * 0.5, 0), Vector3(1.0, wall_h, T), _mat_wall)
	_outer_band(root, key)


func _build_window(key: String) -> void:
	var root := _piece_root(key)
	_solid(root, Vector3(0, SILL_H * 0.5, 0), Vector3(1.0, SILL_H, T), _mat_wall)
	_solid(root, Vector3(0, (HEAD_H + wall_h) * 0.5, 0), Vector3(1.0, wall_h - HEAD_H, T), _mat_wall)
	# Glass collides so the window can't be walked through.
	_solid(root, Vector3(0, (SILL_H + HEAD_H) * 0.5, 0), Vector3(1.0, HEAD_H - SILL_H, 0.05), _mat_glass)
	var fw := 0.07
	_visual(root, Vector3(0, SILL_H + fw * 0.5, 0), Vector3(1.0, fw, T + 0.06), _mat_frame)
	_visual(root, Vector3(0, HEAD_H - fw * 0.5, 0), Vector3(1.0, fw, T + 0.06), _mat_frame)
	_visual(root, Vector3(0, (SILL_H + HEAD_H) * 0.5, 0), Vector3(0.05, HEAD_H - SILL_H, T + 0.04), _mat_frame)
	_outer_band(root, key)


func _build_door(key: String, open: bool) -> void:
	var root := _piece_root(key)
	_solid(root, Vector3(0, (DOOR_H + wall_h) * 0.5, 0), Vector3(1.0, wall_h - DOOR_H, T), _mat_wall)
	_visual(root, Vector3(-0.48, DOOR_H * 0.5, 0), Vector3(0.05, DOOR_H, T + 0.05), _mat_frame)
	_visual(root, Vector3(0.48, DOOR_H * 0.5, 0), Vector3(0.05, DOOR_H, T + 0.05), _mat_frame)
	_visual(root, Vector3(0, DOOR_H + 0.03, 0), Vector3(1.0, 0.07, T + 0.05), _mat_frame)
	# Leaf hinges on the -X end and swings toward the house interior.
	var pivot := Node3D.new()
	pivot.name = "Hinge"
	pivot.position = Vector3(-0.46, 0, 0)
	root.add_child(pivot)
	var leaf := _solid(pivot, Vector3(0.46, DOOR_H * 0.48, 0), Vector3(0.9, DOOR_H * 0.96, 0.07), _mat_door)
	leaf.name = "Leaf"
	leaf.set_meta("door_edge", key)
	_visual(leaf, Vector3(0.8, 1.05, 0.06), Vector3(0.08, 0.08, 0.08), _mat_knob)
	_visual(leaf, Vector3(0.8, 1.05, -0.06), Vector3(0.08, 0.08, 0.08), _mat_knob)
	var shape: CollisionShape3D = leaf.get_child(0)
	doors[key] = {"pivot": pivot, "shape": shape, "open": false, "swing": _swing_sign(key)}
	_set_door_open(key, open, false)


## +1/-1 so the leaf rotates into the room for perimeter doors.
func _swing_sign(key: String) -> float:
	# A +Y rotation moves the leaf's free end toward local -Z.
	var out := _outward(key)
	if out == Vector3.ZERO:
		return 1.0
	return 1.0 if _local_z(key).dot(out) > 0.0 else -1.0


func _set_door_open(key: String, open: bool, animate: bool) -> void:
	if not doors.has(key):
		return
	var d: Dictionary = doors[key]
	d["open"] = open
	var pivot: Node3D = d["pivot"]
	var shape: CollisionShape3D = d["shape"]
	var target := OPEN_ANGLE * float(d["swing"]) if open else 0.0
	# Open doors never trap anyone: the leaf stops colliding while open.
	shape.set_deferred("disabled", open)
	if animate and pivot.is_inside_tree():
		var tw := pivot.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "rotation:y", target, DOOR_ANIM_SEC)
	else:
		pivot.rotation.y = target


## Corner posts where wall pieces meet at an angle, plus the 4 outer corners.
func _build_posts() -> void:
	var axes := {}
	for key in _kinds.keys():
		if HouseStructure.is_door(str(_kinds[key])):
			continue
		var e := HouseStructure.parse(key)
		var ends: Array[Vector2i] = []
		if e["axis"] == "h":
			ends = [Vector2i(e["x"], e["z"]), Vector2i(e["x"] + 1, e["z"])]
		else:
			ends = [Vector2i(e["x"], e["z"]), Vector2i(e["x"], e["z"] + 1)]
		for v in ends:
			if not axes.has(v):
				axes[v] = {}
			axes[v][e["axis"]] = true
	for v: Vector2i in axes.keys():
		var a: Dictionary = axes[v]
		if not (a.has("h") and a.has("v")):
			continue
		var pos := Vector3(float(v.x), wall_h * 0.5, float(v.y))
		var corner := (v.x == 0 or v.x == cells) and (v.y == 0 or v.y == cells)
		if corner:
			pos.x += -T * 0.5 if v.x == 0 else T * 0.5
			pos.z += -T * 0.5 if v.y == 0 else T * 0.5
		_solid(self, pos, Vector3(T, wall_h, T), _mat_wall)


## Door nearest to `p` within `max_dist`, or "".
func nearest_door(p: Vector3, max_dist: float = 2.2) -> String:
	var best := ""
	var best_d := max_dist
	for key in doors.keys():
		var c := HouseStructure.edge_center(key)
		var d := Vector2(c.x - p.x, c.z - p.z).length()
		if d < best_d:
			best_d = d
			best = key
	return best
