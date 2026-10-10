extends Node3D
class_name AssetShowcase
## Curated garden playground — not a floating-label museum.

const GARDEN_ORIGIN := Vector3(48, 0, 12)

var _anim_players: Array[AnimationPlayer] = []

func _ready() -> void:
	position = Vector3(GARDEN_ORIGIN.x, VoxelWorld.GROUND_Y + 1, GARDEN_ORIGIN.z)
	_build_garden()


func _build_garden() -> void:
	_add_ground_plaque(Vector3(0, 0.02, -4), "Cozy Garden", Color(0.45, 0.7, 0.45))
	_build_animal_pen(Vector3(0, 0, 0))
	_build_flower_nook(Vector3(-6, 0, 6))
	_build_sitting_corner(Vector3(6, 0, 6))
	_build_block_palette(Vector3(0, 0, 12))


func _animal_tex(kind: String) -> Texture2D:
	var path := ""
	match kind:
		"cow":
			path = "res://assets/textures/animals/cow_spots.png"
		"sheep":
			path = "res://assets/textures/animals/sheep_wool.png"
		"pig":
			path = "res://assets/textures/animals/pig_pink.png"
		"pug":
			path = "res://assets/textures/animals/pug_brown.png"
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _paint_animal(node: Node, kind: String) -> void:
	var color := Color(0.9, 0.85, 0.7)
	match kind:
		"cow":
			color = Color(0.96, 0.90, 0.78)
		"sheep":
			color = Color(0.98, 0.98, 1.0)
		"pig":
			color = Color(1.0, 0.68, 0.74)
		"pug":
			color = Color(0.62, 0.40, 0.28)
		"bear":
			color = Color(0.66, 0.44, 0.28)
		"chair", "table", "plant":
			color = Color(0.78, 0.56, 0.34)
	var tex := _animal_tex(kind)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				var sm := StandardMaterial3D.new()
				sm.albedo_color = color
				if tex:
					sm.albedo_texture = tex
					sm.uv1_scale = Vector3(2.0, 2.0, 2.0)
				# Multi-surface FBX: darker accents on later surfaces
				if kind == "cow" and si > 0:
					sm.albedo_color = Color(0.28, 0.22, 0.18)
					sm.albedo_texture = null
				if kind == "sheep" and si > 0:
					sm.albedo_color = Color(0.25, 0.25, 0.28)
					sm.albedo_texture = null
				if kind == "pig" and si > 0:
					sm.albedo_color = Color(0.95, 0.55, 0.62)
				if kind == "pug" and si > 0:
					sm.albedo_color = Color(0.35, 0.25, 0.2)
					sm.albedo_texture = null
				sm.metallic = 0.0
				sm.roughness = 0.88
				sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mi.set_surface_override_material(si, sm)
	for c in node.get_children():
		_paint_animal(c, kind)


func _spawn(path: String, origin: Vector3, scale_factor: float = 1.0, yaw: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var node: Node3D = load(path).instantiate()
	node.scale = Vector3.ONE * scale_factor
	node.rotation_degrees.y = yaw
	var fn := path.get_file().to_lower()
	var kind := "prop"
	if fn.find("cow") >= 0: kind = "cow"
	elif fn.find("sheep") >= 0: kind = "sheep"
	elif fn.find("pig") >= 0: kind = "pig"
	elif fn.find("pug") >= 0: kind = "pug"
	elif fn.find("bear") >= 0: kind = "bear"
	elif fn.find("chair") >= 0: kind = "chair"
	elif fn.find("table") >= 0: kind = "table"
	elif fn.find("plant") >= 0: kind = "plant"
	_paint_animal(node, kind)
	# Flowers / nature in garden nook
	if fn.find("flower") >= 0 or fn.find("grass") >= 0 or fn.find("mushroom") >= 0 or fn.find("bush") >= 0:
		_paint_nature(node, fn)

	var ap := _find_anim(node)
	var host := Node3D.new()
	# Prefer gentle bob — some FBX clips leave animals lying down / unreadable
	host.set_script(load("res://scripts/showcase/bobbing_animal.gd"))
	host.position = origin
	add_child(host)
	host.add_child(node)
	if ap:
		ap.active = false
		_anim_players.append(ap)
	return host


func _paint_nature(node: Node, fn: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				var sm := StandardMaterial3D.new()
				sm.metallic = 0.0
				sm.roughness = 0.92
				if fn.find("yellow") >= 0:
					sm.albedo_color = Color(0.95, 0.8, 0.25)
				elif fn.find("purple") >= 0:
					sm.albedo_color = Color(0.7, 0.4, 0.85)
				elif fn.find("mushroom") >= 0:
					sm.albedo_color = Color(0.85, 0.25, 0.28) if si == 0 else Color(0.9, 0.85, 0.7)
				elif fn.find("flower") >= 0:
					sm.albedo_color = Color(0.92, 0.35, 0.55) if si == 0 else Color(0.3, 0.65, 0.35)
				else:
					sm.albedo_color = Color(0.32, 0.72, 0.38)
				mi.set_surface_override_material(si, sm)
	for c in node.get_children():
		_paint_nature(c, fn)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null


func _add_ground_plaque(pos: Vector3, text: String, color: Color) -> void:
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.12, 0.9)
	base.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	base.material_override = mat
	base.position = pos
	add_child(base)
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.008
	label.position = pos + Vector3(0, 0.2, 0)
	label.modulate = Color(0.2, 0.25, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _fence_rect(center: Vector3, half_w: float, half_d: float) -> void:
	# Toy fence: posts + rails so the pen reads clearly
	var posts: Array[Vector3] = []
	for i in 6:
		var t := float(i) / 5.0
		posts.append(center + Vector3(lerpf(-half_w, half_w, t), 0, -half_d))
		posts.append(center + Vector3(lerpf(-half_w, half_w, t), 0, half_d))
		posts.append(center + Vector3(-half_w, 0, lerpf(-half_d, half_d, t)))
		posts.append(center + Vector3(half_w, 0, lerpf(-half_d, half_d, t)))
	for p in posts:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 1.1, 0.16)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.40, 0.20)
		mat.roughness = 0.9
		mi.material_override = mat
		mi.position = p + Vector3(0, 0.55, 0)
		add_child(mi)
	# Horizontal rails
	for rail_y in [0.35, 0.75]:
		for seg in [
			[Vector3(0, rail_y, -half_d), Vector3(half_w * 2, 0.08, 0.1)],
			[Vector3(0, rail_y, half_d), Vector3(half_w * 2, 0.08, 0.1)],
			[Vector3(-half_w, rail_y, 0), Vector3(0.1, 0.08, half_d * 2)],
			[Vector3(half_w, rail_y, 0), Vector3(0.1, 0.08, half_d * 2)],
		]:
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = seg[1]
			mi.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.72, 0.50, 0.28)
			mat.roughness = 0.9
			mi.material_override = mat
			mi.position = center + seg[0]
			add_child(mi)


func _build_animal_pen(origin: Vector3) -> void:
	_add_ground_plaque(origin + Vector3(0, 0.02, -4.2), "Friends", Color(0.95, 0.78, 0.35))
	_fence_rect(origin, 4.5, 3.5)
	# Soft solid pad (no busy checkers)
	var pad := MeshInstance3D.new()
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(8.6, 0.1, 6.6)
	pad.mesh = pad_box
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.38, 0.62, 0.30)
	pad_mat.roughness = 0.95
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = pad_mat
	pad.position = origin + Vector3(0, 0.05, 0)
	add_child(pad)
	# Quaternius AABB at scale 1: cow≈5.15 tall, pig≈4.6, pug≈1.05; sheep pivot sits high.
	# Target: cow ~1.5, sheep ~1.15, pig ~1.0, pug ~0.65 blocks tall.
	var animals := [
		["res://assets/models/animals/quaternius/Cow.fbx", Vector3(-2.4, 0.05, 0.2), 0.30, 25.0],
		["res://assets/models/animals/quaternius/Sheep.fbx", Vector3(1.0, 1.35, -1.4), 0.20, -15.0],
		["res://assets/models/animals/quaternius/Pig.fbx", Vector3(2.5, 0.05, 0.8), 0.28, 40.0],
		["res://assets/models/animals/quaternius/Pug.fbx", Vector3(-0.4, 0.05, 2.0), 0.58, -25.0],
	]
	for a in animals:
		_spawn(a[0], origin + a[1], a[2], a[3])


func _build_flower_nook(origin: Vector3) -> void:
	_add_ground_plaque(origin + Vector3(0, 0.02, -2.0), "Flowers", Color(0.85, 0.55, 0.7))
	var items := [
		["res://assets/models/nature/flower_redA.glb", 1.4],
		["res://assets/models/nature/flower_yellowA.glb", 1.4],
		["res://assets/models/nature/flower_purpleA.glb", 1.4],
		["res://assets/models/nature/mushroom_red.glb", 1.1],
		["res://assets/models/nature/grass_large.glb", 1.2],
		["res://assets/models/nature/plant_bush.glb", 1.0],
	]
	for i in items.size():
		var ang := float(i) / float(items.size()) * TAU
		var p := origin + Vector3(cos(ang) * 1.4, 0, sin(ang) * 1.4)
		_spawn(items[i][0], p, items[i][1], rad_to_deg(ang))


func _build_sitting_corner(origin: Vector3) -> void:
	_add_ground_plaque(origin + Vector3(0, 0.02, -2.0), "Cozy Corner", Color(0.7, 0.6, 0.45))
	_spawn("res://assets/models/furniture/chair.glb", origin + Vector3(-0.8, 0, 0), 1.0, 20.0)
	_spawn("res://assets/models/furniture/tableCoffee.glb", origin + Vector3(0.4, 0, 0.2), 1.0, 0.0)
	_spawn("res://assets/models/furniture/plantSmall1.glb", origin + Vector3(1.2, 0, -0.6), 1.1, 0.0)
	_spawn("res://assets/models/furniture/bear.glb", origin + Vector3(-1.4, 0, 0.8), 1.2, -30.0)


func _build_block_palette(origin: Vector3) -> void:
	_add_ground_plaque(origin + Vector3(0, 0.02, -1.6), "Blocks", Color(0.55, 0.7, 0.9))
	var names := ["grass", "dirt", "stone", "sand", "wood", "leaves", "glass", "planks", "wool_pink", "wool_yellow"]
	for i in names.size():
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.85, 0.85, 0.85)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		var tex: Texture2D = BlockDB.icon_texture(names[i])
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.9
		mat.metallic = 0.0
		mi.material_override = mat
		mi.position = origin + Vector3(-4.0 + i * 0.95, 0.42, 0)
		add_child(mi)
