extends Node3D
class_name MeadowDresser
## Places trees, rocks, flowers, and clouds into a charming meadow composition.

func dress(root: Node3D) -> void:
	_clear_old(root)
	var props := Node3D.new()
	props.name = "MeadowProps"
	root.add_child(props)
	_place_trees(props)
	_place_rocks(props)
	_place_flowers(props)
	_place_pathside(props)
	_place_clouds(root)


func _clear_old(root: Node3D) -> void:
	for n in ["MeadowProps", "AmbientProps", "Clouds"]:
		var old := root.get_node_or_null(n)
		if old:
			old.queue_free()


func _spawn(path: String, parent: Node3D, pos: Vector3, scale_f: float, yaw_deg: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var node: Node3D = load(path).instantiate()
	node.position = pos
	node.scale = Vector3.ONE * scale_f
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	_paint_prop(node, path.get_file().to_lower())


func _paint_prop(node: Node, fn: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				var sm := StandardMaterial3D.new()
				sm.metallic = 0.0
				sm.roughness = 0.92
				if fn.find("tree") >= 0:
					# Surface 0 often foliage; others trunk — keep readable even if swapped
					if si == 0:
						sm.albedo_color = Color(0.28, 0.72, 0.38)
					else:
						sm.albedo_color = Color(0.55, 0.32, 0.16)
				elif fn.find("flower_yellow") >= 0:
					sm.albedo_color = Color(0.98, 0.82, 0.22)
				elif fn.find("flower_purple") >= 0:
					sm.albedo_color = Color(0.72, 0.42, 0.88)
				elif fn.find("flower") >= 0:
					sm.albedo_color = Color(0.95, 0.32, 0.52) if si == 0 else Color(0.28, 0.68, 0.34)
				elif fn.find("mushroom") >= 0:
					sm.albedo_color = Color(0.88, 0.22, 0.28) if si == 0 else Color(0.95, 0.90, 0.78)
				elif fn.find("rock") >= 0:
					sm.albedo_color = Color(0.62, 0.56, 0.48)  # warm stone, not cold grey
				elif fn.find("grass") >= 0 or fn.find("plant") >= 0 or fn.find("bush") >= 0 or fn.find("patch") >= 0:
					sm.albedo_color = Color(0.30, 0.74, 0.36)
				else:
					var mat: Material = mi.get_active_material(si)
					if mat == null:
						mat = mi.mesh.surface_get_material(si)
					if mat is StandardMaterial3D:
						sm.albedo_color = (mat as StandardMaterial3D).albedo_color
						sm.albedo_texture = (mat as StandardMaterial3D).albedo_texture
					else:
						sm.albedo_color = Color(0.45, 0.7, 0.4)
				mi.set_surface_override_material(si, sm)
	for c in node.get_children():
		_paint_prop(c, fn)


func _place_trees(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var trees := [
		# Grove west of spawn
		["res://assets/models/nature/tree_oak.glb", Vector3(18, gy, 26), 1.7, 10.0],
		["res://assets/models/nature/tree_oak.glb", Vector3(20, gy, 22), 1.4, 40.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(16, gy, 30), 1.55, 0.0],
		["res://assets/models/nature/tree_detailed.glb", Vector3(14, gy, 34), 1.3, 20.0],
		# Near build pad
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(42, gy, 30), 1.35, 25.0],
		["res://assets/models/nature/tree_oak.glb", Vector3(30, gy, 42), 1.5, 55.0],
		["res://assets/models/props/tree.glb", Vector3(44, gy, 42), 1.9, 15.0],
		# Garden / east
		["res://assets/models/nature/tree_detailed.glb", Vector3(46, gy, 26), 1.4, 55.0],
		["res://assets/models/props/tree-high.glb", Vector3(50, gy, 34), 1.75, 70.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(52, gy, 18), 1.45, 5.0],
		# South knoll
		["res://assets/models/nature/tree_oak.glb", Vector3(18, gy, 46), 1.45, 80.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(24, gy, 48), 1.3, 30.0],
	]
	for t in trees:
		_spawn(t[0], props, t[1], t[2], t[3])


func _place_rocks(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	# Few warm stones only — avoid grey slab walls in the play view
	var rocks := [
		["res://assets/models/nature/rock_smallA.glb", Vector3(30, gy, 20), 0.9, 0.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(31, gy, 18), 0.8, 20.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(22, gy, 42), 0.85, 10.0],
	]
	for r in rocks:
		_spawn(r[0], props, r[1], r[2], r[3])


func _place_flowers(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var flowers := [
		["res://assets/models/nature/flower_redA.glb", Vector3(23, gy, 27), 1.35],
		["res://assets/models/nature/flower_yellowA.glb", Vector3(25, gy, 29), 1.35],
		["res://assets/models/nature/flower_purpleA.glb", Vector3(21, gy, 29), 1.35],
		["res://assets/models/nature/flower_redA.glb", Vector3(39, gy, 23), 1.25],
		["res://assets/models/nature/flower_yellowA.glb", Vector3(41, gy, 21), 1.25],
		["res://assets/models/nature/flower_purpleA.glb", Vector3(37, gy, 24), 1.2],
		["res://assets/models/nature/flower_redA.glb", Vector3(19, gy, 40), 1.3],
		["res://assets/models/nature/flower_yellowA.glb", Vector3(17, gy, 42), 1.25],
		["res://assets/models/nature/grass_large.glb", Vector3(27, gy, 33), 1.15],
		["res://assets/models/nature/grass.glb", Vector3(29, gy, 31), 1.25],
		["res://assets/models/nature/grass_large.glb", Vector3(33, gy, 28), 1.1],
		["res://assets/models/nature/grass.glb", Vector3(35, gy, 44), 1.2],
		["res://assets/models/nature/mushroom_red.glb", Vector3(19, gy, 34), 1.05],
		["res://assets/models/nature/mushroom_red.glb", Vector3(43, gy, 36), 1.0],
		["res://assets/models/nature/plant_bush.glb", Vector3(36, gy, 20), 1.05],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(48, gy, 30), 1.05],
		["res://assets/models/nature/plant_bush.glb", Vector3(26, gy, 44), 1.0],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(40, gy, 46), 1.0],
	]
	for i in flowers.size():
		var f = flowers[i]
		# Larger scale so flowers read as props, not speckles
		_spawn(f[0], props, f[1], float(f[2]) * 1.35, float(i * 17))


func _place_pathside(props: Node3D) -> void:
	## Clustered flower/tuft groups along the path — intentional, not noise.
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var clusters := [
		Vector3(30, gy, 30), Vector3(34, gy, 26), Vector3(38, gy, 22),
		Vector3(26, gy, 28), Vector3(42, gy, 18),
	]
	var kinds := [
		"res://assets/models/nature/flower_redA.glb",
		"res://assets/models/nature/flower_yellowA.glb",
		"res://assets/models/nature/flower_purpleA.glb",
		"res://assets/models/nature/grass_large.glb",
	]
	for ci in clusters.size():
		var c: Vector3 = clusters[ci]
		for j in 3:
			var ang := float(j) * TAU / 3.0 + float(ci)
			_spawn(kinds[(ci + j) % kinds.size()], props, c + Vector3(cos(ang) * 0.55, 0, sin(ang) * 0.55), 1.7, rad_to_deg(ang))


func _place_clouds(root: Node3D) -> void:
	var clouds := Node3D.new()
	clouds.name = "Clouds"
	root.add_child(clouds)
	for i in 8:
		var cluster := Node3D.new()
		cluster.position = Vector3(6 + i * 7.5, 22 + (i % 3) * 1.8, 4 + (i * 6) % 48)
		clouds.add_child(cluster)
		for p in 3:
			var mi := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.4 + float((i + p) % 3) * 0.35
			sphere.height = sphere.radius * 1.4
			sphere.radial_segments = 10
			sphere.rings = 6
			mi.mesh = sphere
			var mat := StandardMaterial3D.new()
			# Opaque soft white — alpha clouds punch black holes on gl_compatibility
			mat.albedo_color = Color(0.96, 0.97, 1.0, 1.0)
			mat.roughness = 1.0
			mat.metallic = 0.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat
			mi.position = Vector3(p * 1.5 - 1.5, (p % 2) * 0.4, (p - 1) * 0.8)
			cluster.add_child(mi)
