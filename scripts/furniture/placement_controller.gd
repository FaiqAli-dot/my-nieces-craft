extends Node
class_name PlacementController
## Client-side translucent furniture preview + confirm/cancel.

signal placement_cancelled
signal placement_requested(def_id: String, cell: Vector2i, rotation: int)
signal edit_move_requested(instance_id: String, cell: Vector2i, rotation: int)
signal edit_remove_requested(instance_id: String)
signal selection_changed(instance_id: String)

enum Mode { IDLE, PLACE, MOVE }

var mode: int = Mode.IDLE
var def_id: String = ""
var instance_id: String = ""
var rotation_deg: int = 0
var can_decorate: bool = false

var grid_origin: Vector3 = Vector3.ZERO
var floor_y: float = 0.0
var room_min: Vector2i = HouseLayout.DEFAULT_ROOM_MIN
var room_max: Vector2i = HouseLayout.DEFAULT_ROOM_MAX
var furniture_root: Node3D
var camera: Camera3D

var _preview: Node3D
var _ghost_mat_ok: StandardMaterial3D
var _ghost_mat_bad: StandardMaterial3D
var _valid := false
var _anchor := Vector2i.ZERO
var _instances: Dictionary = {} # id -> FurnitureVisual


func _ready() -> void:
	_ghost_mat_ok = _make_ghost(Color(0.35, 0.9, 0.45, 0.45))
	_ghost_mat_bad = _make_ghost(Color(0.95, 0.3, 0.3, 0.45))


func _make_ghost(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func set_instances(map: Dictionary) -> void:
	_instances = map


func begin_place(id: String) -> void:
	if not can_decorate or not FurnitureDB.has_id(id):
		GameState.toast("Can't decorate right now")
		return
	cancel()
	mode = Mode.PLACE
	def_id = id
	instance_id = ""
	rotation_deg = 0
	_build_preview()
	GameState.toast("Place " + FurnitureDB.display_name(id) + " — click to confirm, Esc cancel")


func begin_move(visual: FurnitureVisual) -> void:
	if not can_decorate or visual == null:
		return
	cancel()
	mode = Mode.MOVE
	def_id = visual.def_id
	instance_id = visual.instance_id
	rotation_deg = visual.rotation_deg
	visual.visible = false
	_build_preview()
	selection_changed.emit(instance_id)


func cancel() -> void:
	if mode == Mode.MOVE and instance_id != "" and _instances.has(instance_id):
		(_instances[instance_id] as FurnitureVisual).visible = true
	_clear_preview()
	mode = Mode.IDLE
	def_id = ""
	instance_id = ""
	placement_cancelled.emit()


func rotate_preview(steps: int = 1) -> void:
	if mode == Mode.IDLE or def_id == "":
		return
	var step := FurnitureDB.rot_step(def_id)
	rotation_deg = FurnitureGrid.normalize_rotation(rotation_deg + step * steps, step)
	_update_preview_xform()


func confirm() -> void:
	if mode == Mode.IDLE or not _valid:
		GameState.toast("Can't place there")
		return
	if mode == Mode.PLACE:
		placement_requested.emit(def_id, _anchor, rotation_deg)
	elif mode == Mode.MOVE:
		edit_move_requested.emit(instance_id, _anchor, rotation_deg)
	_clear_preview()
	mode = Mode.IDLE


func remove_selected() -> void:
	if instance_id == "" and mode != Mode.MOVE:
		return
	var iid := instance_id
	cancel()
	edit_remove_requested.emit(iid)


func _build_preview() -> void:
	_clear_preview()
	_preview = Node3D.new()
	_preview.name = "PlacementPreview"
	furniture_root.add_child(_preview)
	var path := FurnitureDB.scene_path(def_id)
	if ResourceLoader.exists(path):
		var node: Node3D = load(path).instantiate()
		var sc := float(FurnitureDB.get_def(def_id).get("scale", 1.0))
		node.scale = Vector3.ONE * sc
		_apply_ghost(node, true)
		_preview.add_child(node)
	else:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		mi.mesh = box
		mi.material_override = _ghost_mat_ok
		_preview.add_child(mi)


func _clear_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


func _apply_ghost(node: Node, ok: bool) -> void:
	var mat := _ghost_mat_ok if ok else _ghost_mat_bad
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_apply_ghost(c, ok)


func _physics_process(_delta: float) -> void:
	if mode == Mode.IDLE or camera == null or _preview == null:
		return
	var hit := _floor_hit()
	if hit == Vector3.INF:
		_valid = false
		_apply_ghost(_preview, false)
		return
	_anchor = FurnitureGrid.world_to_cell(hit, grid_origin)
	# Keep multi-cell items inside room by clamping anchor
	var fp := FurnitureDB.footprint(def_id)
	var rfp := FurnitureGrid.rotate_footprint(fp, rotation_deg)
	_anchor.x = clampi(_anchor.x, room_min.x, room_max.x - rfp.x + 1)
	_anchor.y = clampi(_anchor.y, room_min.y, room_max.y - rfp.y + 1)

	var occupied := {}
	for iid in _instances.keys():
		var vis: FurnitureVisual = _instances[iid]
		if mode == Mode.MOVE and iid == instance_id:
			continue
		var cells := FurnitureGrid.occupied_cells(vis.cell, FurnitureDB.footprint(vis.def_id), vis.rotation_deg)
		for c in cells:
			occupied["%d,%d" % [c.x, c.y]] = iid
	var reason := FurnitureValidator.validate_placement(
		def_id, _anchor, rotation_deg, room_min, room_max, occupied, instance_id
	)
	_valid = reason == FurnitureValidator.Reason.OK
	_update_preview_xform()
	_apply_ghost(_preview, _valid)


func _update_preview_xform() -> void:
	if _preview == null:
		return
	var fp := FurnitureDB.footprint(def_id)
	var y := floor_y + float(FurnitureDB.get_def(def_id).get("y_offset", 0.0))
	_preview.global_position = FurnitureGrid.multi_cell_world_center(_anchor, fp, rotation_deg, grid_origin, y)
	_preview.rotation_degrees.y = float(rotation_deg)


func _floor_hit() -> Vector3:
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	# When mouse captured, aim from screen center
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rect := vp.get_visible_rect()
		mouse = rect.size * 0.5
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var to := from + dir * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		# Intersect virtual floor plane
		if absf(dir.y) < 0.001:
			return Vector3.INF
		var t := (floor_y - from.y) / dir.y
		if t < 0:
			return Vector3.INF
		return from + dir * t
	return hit.position
