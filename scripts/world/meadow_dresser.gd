extends Node3D
class_name MeadowDresser
## Charms the meadow: key Kenney props + MultiMesh fillers for wide-view depth.

func dress(root: Node3D) -> void:
	_clear_old(root)
	var props := Node3D.new()
	props.name = "MeadowProps"
	root.add_child(props)
	_place_hero_trees(props)
	_place_rocks(props)
	_place_flower_clusters(props)
	_place_bushes(props)
	_place_pathside(props)
	_place_multimesh_fill(props)
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
					if si == 0:
						sm.albedo_color = Color(0.32, 0.76, 0.40)
					else:
						sm.albedo_color = Color(0.62, 0.38, 0.18)
				elif fn.find("flower_yellow") >= 0:
					sm.albedo_color = Color(0.98, 0.82, 0.22)
				elif fn.find("flower_purple") >= 0:
					sm.albedo_color = Color(0.72, 0.42, 0.88)
				elif fn.find("flower") >= 0:
					sm.albedo_color = Color(0.95, 0.32, 0.52) if si == 0 else Color(0.28, 0.68, 0.34)
				elif fn.find("mushroom") >= 0:
					sm.albedo_color = Color(0.88, 0.22, 0.28) if si == 0 else Color(0.95, 0.90, 0.78)
				elif fn.find("rock") >= 0:
					sm.albedo_color = Color(0.66, 0.58, 0.48)
				elif fn.find("grass") >= 0 or fn.find("plant") >= 0 or fn.find("bush") >= 0 or fn.find("patch") >= 0:
					sm.albedo_color = Color(0.34, 0.76, 0.38)
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


func _place_hero_trees(props: Node3D) -> void:
	## Fewer unique Kenney trees as readable anchors (midground).
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var trees := [
		["res://assets/models/nature/tree_oak.glb", Vector3(18, gy, 26), 1.7, 10.0],
		["res://assets/models/nature/tree_oak.glb", Vector3(20, gy, 22), 1.4, 40.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(16, gy, 30), 1.55, 0.0],
		["res://assets/models/nature/tree_detailed.glb", Vector3(14, gy, 34), 1.3, 20.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(42, gy, 30), 1.35, 25.0],
		["res://assets/models/nature/tree_oak.glb", Vector3(30, gy, 42), 1.5, 55.0],
		["res://assets/models/props/tree.glb", Vector3(44, gy, 42), 1.9, 15.0],
		["res://assets/models/nature/tree_detailed.glb", Vector3(46, gy, 26), 1.4, 55.0],
		["res://assets/models/props/tree-high.glb", Vector3(50, gy, 34), 1.75, 70.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(52, gy, 18), 1.45, 5.0],
		["res://assets/models/nature/tree_oak.glb", Vector3(18, gy, 46), 1.45, 80.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(24, gy, 48), 1.3, 30.0],
		["res://assets/models/nature/tree_oak.glb", Vector3(10, gy, 28), 1.5, 60.0],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(56, gy, 44), 1.4, 15.0],
		["res://assets/models/props/tree.glb", Vector3(8, gy, 48), 1.8, 90.0],
	]
	for t in trees:
		var p: Vector3 = t[1]
		if _in_keepout(p.x, p.z):
			continue
		_spawn(t[0], props, p, t[2], t[3])


func _place_rocks(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var rocks := [
		["res://assets/models/nature/rock_smallA.glb", Vector3(30, gy, 20), 0.9, 0.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(31, gy, 18), 0.8, 20.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(22, gy, 42), 0.85, 10.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(48, gy, 46), 0.9, 40.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(14, gy, 52), 0.85, 70.0],
		["res://assets/models/nature/rock_tallA.glb", Vector3(54, gy, 22), 0.7, 25.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(24, gy, 16), 0.9, 35.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(18, gy, 22), 0.85, 55.0],
		["res://assets/models/nature/rock_smallA.glb", Vector3(42, gy, 28), 0.8, 15.0],
		["res://assets/models/nature/rock_tallA.glb", Vector3(34, gy, 12), 0.65, 40.0],
	]
	for r in rocks:
		var rp: Vector3 = r[1]
		if _in_keepout(rp.x, rp.z):
			continue
		_spawn(r[0], props, rp, r[2], r[3])


func _place_flower_clusters(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var centers := [
		Vector3(23, gy, 27), Vector3(40, gy, 22), Vector3(18, gy, 40),
		Vector3(48, gy, 42), Vector3(14, gy, 50), Vector3(36, gy, 48),
		Vector3(10, gy, 22), Vector3(54, gy, 40),
		Vector3(28, gy, 16), Vector3(34, gy, 24), Vector3(16, gy, 32),
		Vector3(46, gy, 36), Vector3(22, gy, 44), Vector3(38, gy, 40),
	]
	var kinds := [
		"res://assets/models/nature/flower_redA.glb",
		"res://assets/models/nature/flower_yellowA.glb",
		"res://assets/models/nature/flower_purpleA.glb",
	]
	for ci in centers.size():
		var c: Vector3 = centers[ci]
		if _in_keepout(c.x, c.z):
			continue
		for j in 4:
			var ang: float = float(j) * TAU / 4.0 + float(ci) * 0.4
			_spawn(kinds[(ci + j) % kinds.size()], props, c + Vector3(cos(ang) * 0.8, 0, sin(ang) * 0.8), 1.8, rad_to_deg(ang))


func _place_bushes(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var bushes := [
		["res://assets/models/nature/plant_bush.glb", Vector3(36, gy, 20), 1.1],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(48, gy, 30), 1.1],
		["res://assets/models/nature/plant_bush.glb", Vector3(26, gy, 44), 1.05],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(40, gy, 46), 1.05],
		["res://assets/models/nature/plant_bush.glb", Vector3(12, gy, 40), 1.1],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(50, gy, 50), 1.1],
		["res://assets/models/nature/plant_bush.glb", Vector3(22, gy, 18), 1.15],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(32, gy, 22), 1.1],
		["res://assets/models/nature/plant_bush.glb", Vector3(44, gy, 24), 1.05],
		["res://assets/models/nature/plant_bushDetailed.glb", Vector3(18, gy, 34), 1.1],
		["res://assets/models/nature/mushroom_red.glb", Vector3(19, gy, 34), 1.15],
		["res://assets/models/nature/mushroom_red.glb", Vector3(43, gy, 36), 1.1],
	]
	for i in bushes.size():
		var b = bushes[i]
		var bp: Vector3 = b[1]
		if _in_keepout(bp.x, bp.z):
			continue
		_spawn(b[0], props, bp, b[2], float(i * 23))


func _place_pathside(props: Node3D) -> void:
	var gy := float(VoxelWorld.GROUND_Y + 1)
	var clusters := [
		Vector3(30, gy, 30), Vector3(34, gy, 26), Vector3(38, gy, 22),
		Vector3(26, gy, 28), Vector3(42, gy, 18),
	]
	var kinds := [
		"res://assets/models/nature/flower_yellowA.glb",
		"res://assets/models/nature/grass_large.glb",
		"res://assets/models/nature/flower_redA.glb",
	]
	for ci in clusters.size():
		var c: Vector3 = clusters[ci]
		for j in 3:
			var ang: float = float(j) * TAU / 3.0 + float(ci)
			_spawn(kinds[(ci + j) % kinds.size()], props, c + Vector3(cos(ang) * 0.55, 0, sin(ang) * 0.55), 1.7, rad_to_deg(ang))


func _place_multimesh_fill(props: Node3D) -> void:
	## Batched silhouette trees + flower dots for far/mid fill (tablet-friendly).
	var gy := float(VoxelWorld.GROUND_Y + 1)
	_add_mm_trees(props, gy)
	_add_mm_flowers(props, gy)
	_add_mm_bushes(props, gy)


func _in_keepout(px: float, pz: float) -> bool:
	## Leave playhouse pad + animal/garden props clear; allow far tree line behind garden.
	if px > 30.0 and px < 44.0 and pz > 30.0 and pz < 46.0:
		return true
	# Showcase garden around (48,12) — clear pen/nooks, keep distant z<=3 backdrop
	if px > 42.0 and px < 56.0 and pz > 6.0 and pz < 24.0:
		return true
	return false


func _mm_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _add_mm_trees(parent: Node3D, gy: float) -> void:
	# Canopies
	var canopy := SphereMesh.new()
	canopy.radius = 1.1
	canopy.height = 1.6
	canopy.radial_segments = 8
	canopy.rings = 4
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.22
	trunk.height = 1.6
	trunk.radial_segments = 6
	var positions: Array[Vector3] = []
	# Edge hubs + interior midground groves (skip build pad)
	var hubs: Array[Vector2] = [
		Vector2(8, 16), Vector2(56, 16), Vector2(8, 56), Vector2(56, 56),
		Vector2(32, 8), Vector2(32, 58), Vector2(6, 36), Vector2(58, 36),
		Vector2(20, 56), Vector2(44, 56), Vector2(12, 12), Vector2(52, 52),
		Vector2(16, 32), Vector2(48, 38), Vector2(24, 20), Vector2(40, 48),
		Vector2(12, 48), Vector2(28, 54), Vector2(50, 24), Vector2(20, 40),
		Vector2(26, 36), Vector2(44, 32), Vector2(18, 44), Vector2(36, 22),
		Vector2(30, 16), Vector2(46, 46), Vector2(14, 26), Vector2(38, 54),
		# Extra mid/far groves for wide meadow depth
		Vector2(22, 14), Vector2(36, 12), Vector2(48, 18), Vector2(14, 20),
		Vector2(26, 28), Vector2(34, 34), Vector2(42, 40), Vector2(18, 36),
		Vector2(10, 30), Vector2(54, 42), Vector2(28, 44), Vector2(38, 28),
		# Far tree line behind garden (visible from animal pen)
		Vector2(44, 2), Vector2(50, 2), Vector2(56, 3), Vector2(40, 3),
	]
	for h in hubs:
		if _in_keepout(h.x, h.y):
			continue
		for k in 5:
			var ang: float = float(k) * TAU / 5.0 + h.x * 0.1
			var r: float = 1.2 + float(k) * 0.5
			var px: float = h.x + cos(ang) * r
			var pz: float = h.y + sin(ang) * r
			if _in_keepout(px, pz):
				continue
			positions.append(Vector3(px, gy, pz))
	var mm_c := MultiMeshInstance3D.new()
	mm_c.name = "MM_TreeCanopies"
	var mm1 := MultiMesh.new()
	mm1.transform_format = MultiMesh.TRANSFORM_3D
	mm1.mesh = canopy
	mm1.instance_count = positions.size()
	for i in positions.size():
		var s := 0.75 + float(i % 4) * 0.10
		var basis := Basis.from_euler(Vector3(0.0, float(i) * 0.7, 0.0)).scaled(Vector3(s, s, s))
		var xf := Transform3D(basis, positions[i] + Vector3(0.0, 2.0, 0.0))
		mm1.set_instance_transform(i, xf)
	mm_c.multimesh = mm1
	mm_c.material_override = _mm_material(Color(0.34, 0.78, 0.38))
	parent.add_child(mm_c)
	var mm_t := MultiMeshInstance3D.new()
	mm_t.name = "MM_TreeTrunks"
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = trunk
	mm2.instance_count = positions.size()
	for i in positions.size():
		var xf := Transform3D(Basis.IDENTITY, positions[i] + Vector3(0.0, 0.8, 0.0))
		mm2.set_instance_transform(i, xf)
	mm_t.multimesh = mm2
	mm_t.material_override = _mm_material(Color(0.58, 0.36, 0.18))
	parent.add_child(mm_t)


func _add_mm_flowers(parent: Node3D, gy: float) -> void:
	var bloom := SphereMesh.new()
	bloom.radius = 0.22
	bloom.height = 0.35
	bloom.radial_segments = 6
	bloom.rings = 3
	var colors := [
		Color(0.95, 0.35, 0.55),
		Color(0.98, 0.82, 0.25),
		Color(0.70, 0.42, 0.90),
	]
	var patches_all: Array[Vector2] = [
		Vector2(22, 26), Vector2(40, 24), Vector2(16, 42), Vector2(48, 44),
		Vector2(28, 52), Vector2(50, 32), Vector2(12, 30), Vector2(36, 16),
		Vector2(24, 12), Vector2(44, 50), Vector2(18, 18), Vector2(32, 20),
		Vector2(28, 30), Vector2(42, 28), Vector2(20, 34), Vector2(38, 38),
		Vector2(14, 38), Vector2(46, 22), Vector2(26, 40), Vector2(34, 46),
	]
	var patches: Array[Vector2] = []
	for p in patches_all:
		if not _in_keepout(p.x, p.y):
			patches.append(p)
	for ci in colors.size():
		var mm_i := MultiMeshInstance3D.new()
		mm_i.name = "MM_Flowers_%d" % ci
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bloom
		mm.instance_count = patches.size() * 6
		var idx := 0
		for p in patches:
			for k in 6:
				var ang: float = float(k) * TAU / 6.0 + float(ci)
				var r: float = 0.45 + float(k) * 0.22
				var xf := Transform3D.IDENTITY
				xf.origin = Vector3(p.x + cos(ang) * r, gy + 0.25, p.y + sin(ang) * r)
				mm.set_instance_transform(idx, xf)
				idx += 1
		mm_i.multimesh = mm
		mm_i.material_override = _mm_material(colors[ci])
		parent.add_child(mm_i)


func _add_mm_bushes(parent: Node3D, gy: float) -> void:
	var bush := SphereMesh.new()
	bush.radius = 0.7
	bush.height = 1.0
	bush.radial_segments = 8
	bush.rings = 4
	var spots_all: Array[Vector2] = [
		Vector2(15, 20), Vector2(25, 16), Vector2(45, 18), Vector2(55, 30),
		Vector2(50, 50), Vector2(30, 55), Vector2(18, 54), Vector2(10, 44),
		Vector2(42, 38), Vector2(8, 24), Vector2(58, 48), Vector2(34, 10),
		Vector2(20, 14), Vector2(28, 22), Vector2(36, 18), Vector2(48, 26),
		Vector2(16, 28), Vector2(24, 34), Vector2(40, 36), Vector2(32, 42),
		Vector2(12, 34), Vector2(52, 34), Vector2(22, 46), Vector2(44, 44),
	]
	var spots: Array[Vector2] = []
	for spt in spots_all:
		if not _in_keepout(spt.x, spt.y):
			spots.append(spt)
	var mm_i := MultiMeshInstance3D.new()
	mm_i.name = "MM_Bushes"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bush
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := 0.9 + float(i % 3) * 0.15
		var basis := Basis.IDENTITY.scaled(Vector3(s, s * 0.85, s))
		var xf := Transform3D(basis, Vector3(spots[i].x, gy + 0.35, spots[i].y))
		mm.set_instance_transform(i, xf)
	mm_i.multimesh = mm
	mm_i.material_override = _mm_material(Color(0.32, 0.76, 0.36))
	parent.add_child(mm_i)


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
			mat.albedo_color = Color(0.96, 0.97, 1.0, 1.0)
			mat.roughness = 1.0
			mat.metallic = 0.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat
			mi.position = Vector3(p * 1.5 - 1.5, (p % 2) * 0.4, (p - 1) * 0.8)
			cluster.add_child(mi)
