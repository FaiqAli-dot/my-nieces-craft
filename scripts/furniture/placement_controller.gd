extends Node
class_name PlacementController
## Client-side translucent furniture preview + grid + confirm/cancel.

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
var _ghost_host: Node3D
var _footprint_box: MeshInstance3D
var _grid_root: Node3D
var _ghost_mat_ok: StandardMaterial3D
var _ghost_mat_bad: StandardMaterial3D
var _fp_mat_ok: StandardMaterial3D
var _fp_mat_bad: StandardMaterial3D
var _valid := false
var _anchor := Vector2i.ZERO
var _instances: Dictionary = {} # id -> FurnitureVisual


func _ready() -> void:
	_ghost_mat_ok = _make_ghost(Color(0.18, 0.95, 0.38, 0.78), Color(0.2, 1.0, 0.35))
	_ghost_mat_bad = _make_ghost(Color(0.98, 0.18, 0.18, 0.78), Color(1.0, 0.25, 0.2))
	_fp_mat_ok = _make_ghost(Color(0.15, 0.92, 0.32, 0.55), Color(0.2, 0.95, 0.35))
	_fp_mat_bad = _make_ghost(Color(0.95, 0.15, 0.15, 0.55), Color(1.0, 0.2, 0.2))


func _make_ghost(col: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 0.85
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
	_show_grid(true)
	_build_preview()
	GameState.toast("Place " + FurnitureDB.display_name(id))


func begin_move(visual: FurnitureVisual) -> void:
	if not can_decorate or visual == null:
		return
	cancel()
	mode = Mode.MOVE
	def_id = visual.def_id
	instance_id = visual.instance_id
	rotation_deg = visual.rotation_deg
	visual.visible = false
	_show_grid(true)
	_build_preview()
	selection_changed.emit(instance_id)


func cancel() -> void:
	if mode == Mode.MOVE and instance_id != "" and _instances.has(instance_id):
		(_instances[instance_id] as FurnitureVisual).visible = true
	_clear_preview()
	_show_grid(false)
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
	_show_grid(false)
	mode = Mode.IDLE


func remove_selected() -> void:
	if instance_id == "" and mode != Mode.MOVE:
		return
	var iid := instance_id
	cancel()
	edit_remove_requested.emit(iid)


func _show_grid(on: bool) -> void:
	if not on:
		if _grid_root and is_instance_valid(_grid_root):
			_grid_root.queue_free()
		_grid_root = null
		return
	if _grid_root and is_instance_valid(_grid_root):
		return
	_grid_root = Node3D.new()
	_grid_root.name = "PlacementGrid"
	furniture_root.add_child(_grid_root)
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 0.82, 0.28, 0.75)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mat.emission_enabled = true
	line_mat.emission = Color(1.0, 0.85, 0.3)
	line_mat.emission_energy_multiplier = 0.4
	# Thin boxes read more clearly than 1px lines under gl_compatibility / llvmpipe.
	for x in range(room_min.x, room_max.x + 2):
		_add_grid_bar(
			Vector3(float(x), floor_y + 0.035, float(room_min.y + room_max.y + 1) * 0.5),
			Vector3(0.04, 0.02, float(room_max.y - room_min.y + 1)),
			line_mat
		)
	for z in range(room_min.y, room_max.y + 2):
		_add_grid_bar(
			Vector3(float(room_min.x + room_max.x + 1) * 0.5, floor_y + 0.035, float(z)),
			Vector3(float(room_max.x - room_min.x + 1), 0.02, 0.04),
			line_mat
		)


func _add_grid_bar(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = grid_origin + pos
	mi.material_override = mat
	_grid_root.add_child(mi)


func _build_preview() -> void:
	_clear_preview()
	_preview = Node3D.new()
	_preview.name = "PlacementPreview"
	furniture_root.add_child(_preview)
	_ghost_host = Node3D.new()
	_preview.add_child(_ghost_host)
	var path := FurnitureDB.scene_path(def_id)
	if ResourceLoader.exists(path):
		var node: Node3D = load(path).instantiate()
		var sc := float(FurnitureDB.get_def(def_id).get("scale", 1.0))
		node.scale = Vector3.ONE * sc
		_apply_ghost(node, true)
		_ghost_host.add_child(node)
	_footprint_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.95, 0.1, 0.95)
	_footprint_box.mesh = bm
	_footprint_box.position.y = 0.06
	_footprint_box.material_override = _fp_mat_ok
	_preview.add_child(_footprint_box)
	# Tall translucent volume so thin Kenney meshes still read as green/red ghosts.
	var volume := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.7, 0.85, 0.7)
	volume.mesh = vb
	volume.position.y = 0.45
	volume.material_override = _ghost_mat_ok
	volume.name = "GhostVolume"
	_preview.add_child(volume)


func _clear_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_ghost_host = null
	_footprint_box = null


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
		_tint(false)
		return
	_anchor = FurnitureGrid.world_to_cell(hit, grid_origin)
	var fp := FurnitureDB.footprint(def_id)
	var rfp := FurnitureGrid.rotate_footprint(fp, rotation_deg)
	_anchor.x = clampi(_anchor.x, room_min.x, maxi(room_min.x, room_max.x - rfp.x + 1))
	_anchor.y = clampi(_anchor.y, room_min.y, maxi(room_min.y, room_max.y - rfp.y + 1))

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
	_tint(_valid)


func _tint(ok: bool) -> void:
	if _ghost_host:
		_apply_ghost(_ghost_host, ok)
	if _footprint_box:
		_footprint_box.material_override = _fp_mat_ok if ok else _fp_mat_bad
	if _preview:
		var vol := _preview.get_node_or_null("GhostVolume") as MeshInstance3D
		if vol:
			vol.material_override = _ghost_mat_ok if ok else _ghost_mat_bad


func _update_preview_xform() -> void:
	if _preview == null:
		return
	var fp := FurnitureDB.footprint(def_id)
	var rfp := FurnitureGrid.rotate_footprint(fp, rotation_deg)
	var y := floor_y + float(FurnitureDB.get_def(def_id).get("y_offset", 0.0))
	_preview.global_position = FurnitureGrid.multi_cell_world_center(_anchor, fp, rotation_deg, grid_origin, y)
	_preview.rotation_degrees.y = float(rotation_deg)
	if _footprint_box and _footprint_box.mesh is BoxMesh:
		(_footprint_box.mesh as BoxMesh).size = Vector3(
			float(rfp.x) * FurnitureGrid.CELL_SIZE * 0.92,
			0.1,
			float(rfp.y) * FurnitureGrid.CELL_SIZE * 0.92
		)
	if _preview:
		var vol := _preview.get_node_or_null("GhostVolume") as MeshInstance3D
		if vol and vol.mesh is BoxMesh:
			(vol.mesh as BoxMesh).size = Vector3(
				float(rfp.x) * FurnitureGrid.CELL_SIZE * 0.72,
				0.9,
				float(rfp.y) * FurnitureGrid.CELL_SIZE * 0.72
			)


func _floor_hit() -> Vector3:
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
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
		if absf(dir.y) < 0.001:
			return Vector3.INF
		var t := (floor_y - from.y) / dir.y
		if t < 0:
			return Vector3.INF
		return from + dir * t
	return hit.position
