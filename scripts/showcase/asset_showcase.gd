extends Node3D
class_name AssetShowcase
## Dedicated labeled asset showcase adjacent to the build area.

const SECTION_SPACING := 8.0

var _anim_players: Array[AnimationPlayer] = []

func _ready() -> void:
	_build_showcase()


func _build_showcase() -> void:
	# Place showcase east of spawn / build area
	position = Vector3(48, VoxelWorld.GROUND_Y + 1, 8)
	_add_sign(Vector3(0, 2.5, -2), "ASSET SHOWCASE")

	var sections := [
		{"title": "Environment & Vegetation", "source": "Kenney Nature Kit / Mini Forest", "builder": "_section_environment"},
		{"title": "Animals", "source": "Khronos Fox/Duck + Kenney Bear", "builder": "_section_animals"},
		{"title": "Furniture & Props", "source": "Kenney Furniture Kit", "builder": "_section_furniture"},
		{"title": "Materials & Textures", "source": "Poly Haven + Kenney Prototype", "builder": "_section_materials"},
		{"title": "Other Useful Assets", "source": "Kenney Characters / Audio / UI", "builder": "_section_other"},
	]
	for i in sections.size():
		var origin := Vector3(0, 0, i * SECTION_SPACING)
		_add_platform(origin)
		_add_sign(origin + Vector3(0, 2.2, -2.2), sections[i]["title"])
		_add_label(origin + Vector3(0, 1.8, -2.2), str(sections[i]["source"]))
		call(sections[i]["builder"], origin + Vector3(0, 0.05, 0))


func _add_platform(origin: Vector3) -> void:
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 0.2, 5)
	mesh_i.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.88, 0.78)
	mesh_i.material_override = mat
	mesh_i.position = origin + Vector3(0, -0.1, 0)
	add_child(mesh_i)
	var body := StaticBody3D.new()
	body.position = mesh_i.position
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _add_sign(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.01
	label.modulate = Color(0.15, 0.25, 0.45)
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	add_child(label)


func _add_label(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 20
	label.pixel_size = 0.01
	label.modulate = Color(0.25, 0.35, 0.5)
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	add_child(label)


func _spawn_model(path: String, origin: Vector3, scale_factor: float = 1.0, y_offset: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		var missing := Label3D.new()
		missing.text = "Missing:\n" + path.get_file()
		missing.font_size = 18
		missing.position = origin + Vector3(0, 0.5, 0)
		add_child(missing)
		return missing
	var scene: PackedScene = load(path)
	var node := scene.instantiate() as Node3D
	node.position = origin + Vector3(0, y_offset, 0)
	node.scale = Vector3.ONE * scale_factor
	add_child(node)
	_fix_kenney_materials(node)
	# Try to play idle / first animation if present
	var ap := _find_anim(node)
	if ap:
		_anim_players.append(ap)
		var anims := ap.get_animation_list()
		if anims.size() > 0:
			var preferred := ""
			for a in anims:
				if String(a).to_lower().find("idle") >= 0 or String(a).to_lower().find("survey") >= 0:
					preferred = a
					break
			ap.play(preferred if preferred != "" else anims[0])
	return node


func _fix_kenney_materials(node: Node) -> void:
	# Kenney GLBs often import with metallicFactor=1, which washes out under daylight.
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh != null:
				for si in mi.mesh.get_surface_count():
					var mat: Material = mi.get_active_material(si)
					if mat == null:
						mat = mi.mesh.surface_get_material(si)
					var sm := StandardMaterial3D.new()
					if mat is StandardMaterial3D:
						var src := mat as StandardMaterial3D
						sm.albedo_color = src.albedo_color
						sm.albedo_texture = src.albedo_texture
						sm.cull_mode = src.cull_mode
					else:
						sm.albedo_color = Color(0.45, 0.75, 0.4)
					sm.metallic = 0.0
					sm.roughness = 0.85
					mi.set_surface_override_material(si, sm)
	for c in node.get_children():
		_fix_kenney_materials(c)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null


func _section_environment(origin: Vector3) -> void:
	var items := [
		["res://assets/models/nature/tree_oak.glb", 0.7],
		["res://assets/models/nature/tree_pineDefaultA.glb", 0.7],
		["res://assets/models/nature/rock_largeA.glb", 0.8],
		["res://assets/models/nature/flower_redA.glb", 1.2],
		["res://assets/models/nature/grass_large.glb", 1.0],
		["res://assets/models/props/tree.glb", 1.0],
		["res://assets/models/props/plant.glb", 1.0],
	]
	for i in items.size():
		var x := -3.5 + i * 1.2
		_spawn_model(items[i][0], origin + Vector3(x, 0, 0), items[i][1])
		_add_label(origin + Vector3(x, 1.4, 1.5), items[i][0].get_file() + "\nKenney")


func _section_animals(origin: Vector3) -> void:
	# Fox has animation; Duck is static; Bear is stuffed toy from furniture kit
	_spawn_model("res://assets/models/animals/Fox.glb", origin + Vector3(-2.5, 0, 0), 0.025)
	_add_label(origin + Vector3(-2.5, 1.5, 1.4), "Fox.glb\nKhronos Sample (animated)")
	_spawn_model("res://assets/models/animals/Duck.glb", origin + Vector3(0, 0, 0), 0.8)
	_add_label(origin + Vector3(0, 1.5, 1.4), "Duck.glb\nKhronos Sample")
	_spawn_model("res://assets/models/furniture/bear.glb", origin + Vector3(2.5, 0, 0), 1.5)
	_add_label(origin + Vector3(2.5, 1.5, 1.4), "bear.glb\nKenney Furniture Kit")
	# Note label about Quaternius
	_add_label(origin + Vector3(0, 2.4, 0), "Quaternius animals: Drive rate-limited (see ASSET_MANIFEST)")


func _section_furniture(origin: Vector3) -> void:
	var items := [
		"res://assets/models/furniture/chair.glb",
		"res://assets/models/furniture/table.glb",
		"res://assets/models/furniture/bedSingle.glb",
		"res://assets/models/furniture/desk.glb",
		"res://assets/models/furniture/lampRoundTable.glb",
		"res://assets/models/furniture/bookcaseOpen.glb",
	]
	for i in items.size():
		var x := -3.0 + i * 1.2
		_spawn_model(items[i], origin + Vector3(x, 0, 0), 1.0)
		_add_label(origin + Vector3(x, 1.3, 1.4), items[i].get_file() + "\nKenney Furniture")


func _section_materials(origin: Vector3) -> void:
	var mats := [
		["res://assets/textures/polyhaven/grass_path_2/grass_path_2_diff_1k.jpg", "Poly Haven grass_path_2"],
		["res://assets/textures/polyhaven/brown_mud_03/brown_mud_03_diff_1k.jpg", "Poly Haven brown_mud_03"],
		["res://assets/textures/polyhaven/rock_face_03/rock_face_03_diff_1k.jpg", "Poly Haven rock_face_03"],
		["res://assets/textures/polyhaven/wood_table_001/wood_table_001_diff_1k.jpg", "Poly Haven wood_table_001"],
		["res://assets/textures/polyhaven/sandy_gravel_02/sandy_gravel_02_diff_1k.jpg", "Poly Haven sandy_gravel_02"],
		["res://assets/textures/prototype/Green/texture_01.png", "Kenney Prototype Green"],
		["res://assets/textures/blocks/wool_pink.png", "CozyBlocks wool_pink"],
	]
	for i in mats.size():
		var x := -3.6 + i * 1.2
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.9, 0.9)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		if ResourceLoader.exists(mats[i][0]):
			mat.albedo_texture = load(mats[i][0])
		mat.roughness = 0.85
		mi.material_override = mat
		mi.position = origin + Vector3(x, 0.45, 0)
		add_child(mi)
		_add_label(origin + Vector3(x, 1.3, 1.4), mats[i][1])


func _section_other(origin: Vector3) -> void:
	_spawn_model("res://assets/models/characters/character-a.glb", origin + Vector3(-2.5, 0, 0), 1.0)
	_add_label(origin + Vector3(-2.5, 1.6, 1.4), "character-a\nKenney Blocky Characters")
	_spawn_model("res://assets/models/characters/character-female-a.glb", origin + Vector3(-0.5, 0, 0), 1.0)
	_add_label(origin + Vector3(-0.5, 1.6, 1.4), "character-female-a\nKenney Mini Characters")
	# Audio / UI note cards
	_add_label(origin + Vector3(2.0, 1.0, 0), "Audio: Kenney Impact / Interface / RPG\nUI: Kenney Input Prompts + RPG UI\nSky: Poly Haven HDRI + Kenney skyboxes")
