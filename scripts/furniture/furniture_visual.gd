extends Node3D
class_name FurnitureVisual
## World instance of a placed furniture item.

var instance_id: String = ""
var def_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var rotation_deg: int = 0
var selected: bool = false

var _body: StaticBody3D
var _mesh_host: Node3D
var _select_box: MeshInstance3D


func setup(inst: Dictionary, origin: Vector3, floor_y: float) -> void:
	instance_id = str(inst.get("instance_id", ""))
	def_id = str(inst.get("def_id", ""))
	cell = Vector2i(int(inst.get("cell_x", 0)), int(inst.get("cell_z", 0)))
	rotation_deg = int(inst.get("rotation", 0))
	name = instance_id
	_rebuild(origin, floor_y)


func update_transform(inst: Dictionary, origin: Vector3, floor_y: float) -> void:
	cell = Vector2i(int(inst.get("cell_x", 0)), int(inst.get("cell_z", 0)))
	rotation_deg = int(inst.get("rotation", 0))
	def_id = str(inst.get("def_id", def_id))
	_rebuild(origin, floor_y)


func _rebuild(origin: Vector3, floor_y: float) -> void:
	for c in get_children():
		c.queue_free()
	if not FurnitureDB.has_id(def_id):
		return
	var def := FurnitureDB.get_def(def_id)
	var fp: Vector2i = def["footprint"]
	var y := floor_y + float(def.get("y_offset", 0.0))
	global_position = FurnitureGrid.multi_cell_world_center(cell, fp, rotation_deg, origin, y)
	rotation_degrees.y = float(rotation_deg)

	_mesh_host = Node3D.new()
	add_child(_mesh_host)
	var path := FurnitureDB.scene_path(def_id)
	if ResourceLoader.exists(path):
		var node: Node3D = load(path).instantiate()
		var sc := float(def.get("scale", 1.0))
		node.scale = Vector3.ONE * sc
		_paint(node, str(def.get("paint", "wood")))
		_mesh_host.add_child(node)

	# Collision footprint box
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var rfp := FurnitureGrid.rotate_footprint(fp, rotation_deg)
	box.size = Vector3(float(rfp.x) * FurnitureGrid.CELL_SIZE * 0.92, 0.9, float(rfp.y) * FurnitureGrid.CELL_SIZE * 0.92)
	shape.shape = box
	shape.position.y = 0.45
	_body.add_child(shape)
	_body.set_meta("furniture_instance_id", instance_id)

	_select_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(rfp.x) * FurnitureGrid.CELL_SIZE, 0.05, float(rfp.y) * FurnitureGrid.CELL_SIZE)
	_select_box.mesh = bm
	_select_box.position.y = 0.03
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_select_box.material_override = mat
	_select_box.visible = selected
	add_child(_select_box)


func set_selected(on: bool) -> void:
	selected = on
	if _select_box:
		_select_box.visible = on


func _paint(node: Node, paint: String) -> void:
	var col := Color(0.78, 0.56, 0.34)
	match paint:
		"soft":
			col = Color(0.95, 0.72, 0.78)
		"cool":
			col = Color(0.62, 0.72, 0.82)
		"lamp":
			col = Color(0.98, 0.92, 0.7)
		"plant":
			col = Color(0.4, 0.75, 0.42)
		"bear":
			col = Color(0.66, 0.44, 0.28)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var sm := StandardMaterial3D.new()
				sm.albedo_color = col if si == 0 else col.darkened(0.08)
				sm.metallic = 0.0
				sm.roughness = 0.9
				# Keep default back-face culling; do not mirror voxel mesher winding bugs.
				sm.cull_mode = BaseMaterial3D.CULL_BACK
				mi.set_surface_override_material(si, sm)
	for c in node.get_children():
		_paint(c, paint)
