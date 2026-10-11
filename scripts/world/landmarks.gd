extends RefCounted
class_name Landmarks
## Hand-shaped voxel landmarks (one per biome) plus floating name signs.
## Built on the flattened pads TerrainGen leaves at TerrainGen.LANDMARKS.

const SIGN_ROOT := "Signs"


static func build_all(world: VoxelWorld, gen: TerrainGen) -> void:
	for lm in TerrainGen.LANDMARKS:
		var p: Vector2i = lm["pos"]
		var b := gen.landmark_base_y(lm["id"])
		match str(lm["id"]):
			"ruins": _ruins(world, p.x, b, p.y)
			"tower": _tower(world, p.x, b, p.y)
			"lighthouse": _lighthouse(world, gen, p.x, b, p.y)
			"windmill": _windmill(world, p.x, b, p.y)


static func _put(world: VoxelWorld, x: int, y: int, z: int, block: String) -> void:
	world.set_block(x, y, z, BlockDB.get_id(block), false)


static func _ruins(world: VoxelWorld, cx: int, b: int, cz: int) -> void:
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			_put(world, cx + dx, b - 1, cz + dz, "path_stone" if (dx + dz) % 3 != 0 else "mossy_cobble")
			if absi(dx) != 4 and absi(dz) != 4:
				continue
			# Broken walls: deterministic gaps and uneven heights.
			var h := 1 + (absi(dx * 7 + dz * 3) % 3)
			if (dx == 0 and absi(dz) == 4) or (dz == 0 and absi(dx) == 4) or absi(dx * dz) % 5 == 1:
				continue
			for y in h:
				_put(world, cx + dx, b + y, cz + dz, "mossy_cobble" if (dx + y) % 2 == 0 else "cobble")
	for c in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		for y in 4:
			_put(world, cx + c.x, b + y, cz + c.y, "mossy_cobble")
	_put(world, cx, b, cz, "crafting_table")


static func _tower(world: VoxelWorld, cx: int, b: int, cz: int) -> void:
	var top := b + 7
	for c in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
		for y in range(b, top):
			_put(world, cx + c.x, y, cz + c.y, "cobble")
		_put(world, cx + c.x, top + 1, cz + c.y, "wood")
		_put(world, cx + c.x, top + 2, cz + c.y, "wood")
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			_put(world, cx + dx, top, cz + dz, "planks")
	_put(world, cx + 2, top + 3, cz + 2, "wool_red")
	# Outside staircase up the west side; each step one block higher.
	for i in 7:
		var x := cx - 3
		var z := cz - 4 + i
		for y in range(b - 1, b + i):
			if world.get_block(x, y, z) == 0:
				_put(world, x, y, z, "cobble")
		_put(world, x, b + i, z, "planks")


static func _lighthouse(world: VoxelWorld, gen: TerrainGen, cx: int, b: int, cz: int) -> void:
	for y in range(b, b + 10):
		var stripe := "wool_red" if (y - b) / 2 % 2 == 0 else "plaster"
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				_put(world, cx + dx, y, cz + dz, stripe)
	var lamp := b + 10
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_put(world, cx + dx, lamp, cz + dz, "glass")
			_put(world, cx + dx, lamp + 1, cz + dz, "roof_tile")
	_put(world, cx, lamp, cz, "wool_yellow")
	# Pier from the north shore to the island, on posts.
	var z := cz - 5
	var deck := VoxelWorld.GROUND_Y
	while z > cz - 30 and gen.height_at(cx, z) < deck:
		for x in [cx - 1, cx]:
			_put(world, x, deck, z, "planks")
			if z % 3 == 0:
				for y in range(gen.height_at(x, z) + 1, deck):
					_put(world, x, y, z, "wood")
		z -= 1


static func _windmill(world: VoxelWorld, cx: int, b: int, cz: int) -> void:
	for y in range(b, b + 9):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				_put(world, cx + dx, y, cz + dz, "cobble" if y < b + 4 else "planks")
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_put(world, cx + dx, b + 9, cz + dz, "roof_tile")
	_put(world, cx, b + 10, cz, "roof_tile")
	# Sails face the meadow (east).
	var hub := Vector3i(cx + 2, b + 6, cz)
	_put(world, hub.x, hub.y, hub.z, "wood")
	for i in range(1, 5):
		_put(world, hub.x, hub.y + i, hub.z, "plaster")
		_put(world, hub.x, hub.y - i, hub.z, "plaster")
		_put(world, hub.x, hub.y, hub.z + i, "plaster")
		_put(world, hub.x, hub.y, hub.z - i, "plaster")


## Floating name signs over each landmark and at the meadow exits.
static func build_signs(world: VoxelWorld, gen: TerrainGen) -> Node3D:
	var root := world.get_node_or_null(SIGN_ROOT) as Node3D
	if root:
		world.remove_child(root)
		root.queue_free()
	root = Node3D.new()
	root.name = SIGN_ROOT
	world.add_child(root)
	for lm in TerrainGen.LANDMARKS:
		var p: Vector2i = lm["pos"]
		var top := world.surface_y(p.x, p.y)
		root.add_child(_label(str(lm["name"]), Vector3(p.x + 0.5, top + 3.0, p.y + 0.5), 1.0))
	var m := VoxelWorld.MEADOW_SIZE
	var exits := [
		[Vector2i(32, -3), TerrainGen.Biome.FOREST],
		[Vector2i(m + 2, 30), TerrainGen.Biome.SNOW],
		[Vector2i(30, m + 2), TerrainGen.Biome.BEACH],
		[Vector2i(-3, 30), TerrainGen.Biome.FLOWERS],
	]
	for e in exits:
		var p: Vector2i = e[0]
		var base := gen.height_at(p.x, p.y) + 1
		_put(world, p.x, base, p.y, "wood")
		_put(world, p.x, base + 1, p.y, "wood")
		root.add_child(_label(TerrainGen.biome_name(int(e[1])), Vector3(p.x + 0.5, base + 2.8, p.y + 0.5), 0.75))
	return root


static func _label(text: String, at: Vector3, scale_f: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.outline_size = 14
	l.pixel_size = 0.009 * scale_f
	l.modulate = Color(1.0, 0.97, 0.88)
	l.outline_modulate = Color(0.32, 0.22, 0.14)
	l.name = "Sign_" + text.replace(" ", "")
	return l
