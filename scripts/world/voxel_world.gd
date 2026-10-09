extends Node3D
class_name VoxelWorld
## Finite chunked voxel world for the Phase 1 sandbox.

signal world_reset
signal block_changed(pos: Vector3i, id: int)

const WORLD_CHUNKS := Vector3i(4, 2, 4) # 64 x 32 x 64 blocks
const GROUND_Y := 4
const SPAWN_BLOCK := Vector3i(32, GROUND_Y + 1, 32)

var chunks: Dictionary = {} # Vector3i -> VoxelChunk
var boundary_min := Vector3(1, 0, 1)
var boundary_max := Vector3(WORLD_CHUNKS.x * VoxelChunk.SIZE - 2, WORLD_CHUNKS.y * VoxelChunk.SIZE - 1, WORLD_CHUNKS.z * VoxelChunk.SIZE - 2)

var chunk_root: Node3D


func _ready() -> void:
	chunk_root = get_node_or_null("Chunks") as Node3D
	if chunk_root == null:
		chunk_root = Node3D.new()
		chunk_root.name = "Chunks"
		add_child(chunk_root)
	generate_flat_world()


func world_size_blocks() -> Vector3i:
	return Vector3i(WORLD_CHUNKS.x * VoxelChunk.SIZE, WORLD_CHUNKS.y * VoxelChunk.SIZE, WORLD_CHUNKS.z * VoxelChunk.SIZE)


func spawn_position() -> Vector3:
	return Vector3(SPAWN_BLOCK.x + 0.5, SPAWN_BLOCK.y + 0.1, SPAWN_BLOCK.z + 0.5)


func chunk_key(cx: int, cy: int, cz: int) -> Vector3i:
	return Vector3i(cx, cy, cz)


func ensure_chunk(key: Vector3i) -> VoxelChunk:
	if chunks.has(key):
		return chunks[key]
	var chunk := VoxelChunk.new()
	chunk.setup(self, key)
	chunk_root.add_child(chunk)
	chunks[key] = chunk
	return chunk


func world_to_chunk(wx: int, wy: int, wz: int) -> Vector3i:
	return Vector3i(
		floori(float(wx) / VoxelChunk.SIZE),
		floori(float(wy) / VoxelChunk.SIZE),
		floori(float(wz) / VoxelChunk.SIZE)
	)


func in_bounds(wx: int, wy: int, wz: int) -> bool:
	var size := world_size_blocks()
	return wx >= 0 and wy >= 0 and wz >= 0 and wx < size.x and wy < size.y and wz < size.z


func get_block(wx: int, wy: int, wz: int) -> int:
	if not in_bounds(wx, wy, wz):
		return 0
	var key := world_to_chunk(wx, wy, wz)
	if not chunks.has(key):
		return 0
	return chunks[key].get_block_world(wx, wy, wz)


func set_block(wx: int, wy: int, wz: int, id: int, rebuild: bool = true) -> void:
	if not in_bounds(wx, wy, wz):
		return
	var key := world_to_chunk(wx, wy, wz)
	var chunk := ensure_chunk(key)
	chunk.set_block_world(wx, wy, wz, id)
	if rebuild:
		_rebuild_affected(wx, wy, wz)
	block_changed.emit(Vector3i(wx, wy, wz), id)


func _rebuild_affected(wx: int, wy: int, wz: int) -> void:
	var keys: Array[Vector3i] = [world_to_chunk(wx, wy, wz)]
	# Neighbor chunks if on border
	var local_x := wx % VoxelChunk.SIZE
	var local_y := wy % VoxelChunk.SIZE
	var local_z := wz % VoxelChunk.SIZE
	if local_x < 0:
		local_x += VoxelChunk.SIZE
	if local_y < 0:
		local_y += VoxelChunk.SIZE
	if local_z < 0:
		local_z += VoxelChunk.SIZE
	if local_x == 0:
		keys.append(world_to_chunk(wx - 1, wy, wz))
	if local_x == VoxelChunk.SIZE - 1:
		keys.append(world_to_chunk(wx + 1, wy, wz))
	if local_y == 0:
		keys.append(world_to_chunk(wx, wy - 1, wz))
	if local_y == VoxelChunk.SIZE - 1:
		keys.append(world_to_chunk(wx, wy + 1, wz))
	if local_z == 0:
		keys.append(world_to_chunk(wx, wy, wz - 1))
	if local_z == VoxelChunk.SIZE - 1:
		keys.append(world_to_chunk(wx, wy, wz + 1))
	for key in keys:
		if key.x < 0 or key.y < 0 or key.z < 0:
			continue
		if key.x >= WORLD_CHUNKS.x or key.y >= WORLD_CHUNKS.y or key.z >= WORLD_CHUNKS.z:
			continue
		var chunk := ensure_chunk(key)
		chunk.dirty = true
		chunk.rebuild_mesh()


func generate_flat_world() -> void:
	if chunk_root == null:
		chunk_root = get_node_or_null("Chunks") as Node3D
		if chunk_root == null:
			chunk_root = Node3D.new()
			chunk_root.name = "Chunks"
			add_child(chunk_root)
	for c in chunk_root.get_children():
		c.queue_free()
	chunks.clear()
	for cy in WORLD_CHUNKS.y:
		for cz in WORLD_CHUNKS.z:
			for cx in WORLD_CHUNKS.x:
				ensure_chunk(Vector3i(cx, cy, cz))
	var size := world_size_blocks()
	var grass_id := BlockDB.get_id("grass")
	var dirt_id := BlockDB.get_id("dirt")
	var stone_id := BlockDB.get_id("stone")
	for z in size.z:
		for x in size.x:
			for y in GROUND_Y + 1:
				var id := stone_id
				if y == GROUND_Y:
					id = grass_id
				elif y >= GROUND_Y - 2:
					id = dirt_id
				set_block(x, y, z, id, false)
	_dress_meadow()
	# Mark all dirty and rebuild once
	for key in chunks.keys():
		chunks[key].dirty = true
		chunks[key].rebuild_mesh()
	world_reset.emit()


func _dress_meadow() -> void:
	## Paths, clustered flower beds, sand patch, grass-on-dirt knolls, starter pad.
	## No random speckles and no grey cobble rim walls.
	var path_id := BlockDB.get_id("path_stone")
	var sand_id := BlockDB.get_id("sand")
	var flower_id := BlockDB.get_id("flower_block")
	var dirt_id := BlockDB.get_id("dirt")
	var planks_id := BlockDB.get_id("planks")
	var wool_y := BlockDB.get_id("wool_yellow")
	var wool_p := BlockDB.get_id("wool_pink")
	var grass_id := BlockDB.get_id("grass")
	# Winding warm path from spawn toward garden
	for t in 28:
		var x := 32 + int(round(t * 0.55))
		var z := 32 - t
		_stamp_disk(x, z, 1, path_id)
	# Side spur to flower nook
	for t in 8:
		_stamp_disk(24 + t, 28 - int(t * 0.3), 1, path_id)
	# Golden sand play patch near spawn
	_stamp_disk(28, 36, 3, sand_id)
	# Clustered flower beds only (intentional, not noise)
	_stamp_disk(22, 24, 2, flower_id)
	_stamp_disk(40, 22, 2, flower_id)
	_stamp_disk(18, 40, 1, flower_id)
	# Small dirt garden beds
	_stamp_disk(24, 30, 1, dirt_id)
	_stamp_disk(38, 28, 1, dirt_id)
	# Soft world-edge mounds only (keep garden / spawn views clear of grey cliffs)
	for i in 6:
		var bx := 10 + i * 8
		var bz := 10 + i * 8
		for edge in [Vector2i(bx, 6), Vector2i(bx, 57), Vector2i(6, bz), Vector2i(57, bz)]:
			_grass_dirt_mound(edge.x, edge.y, 1)
	# Small grass-on-dirt knolls away from the animal pen
	_build_knoll(16, 18, 2, 1)
	_build_knoll(50, 48, 2, 1)
	_build_knoll(22, 48, 2, 1)
	# Cozy starter build pad
	for x in range(34, 40):
		for z in range(34, 40):
			set_block(x, GROUND_Y, z, planks_id, false)
	for x in range(33, 41):
		set_block(x, GROUND_Y, 33, path_id, false)
		set_block(x, GROUND_Y, 40, path_id, false)
	for z in range(33, 41):
		set_block(33, GROUND_Y, z, path_id, false)
		set_block(40, GROUND_Y, z, path_id, false)
	set_block(34, GROUND_Y + 1, 34, wool_y, false)
	set_block(39, GROUND_Y + 1, 34, wool_p, false)
	set_block(34, GROUND_Y + 1, 39, wool_p, false)
	set_block(39, GROUND_Y + 1, 39, wool_y, false)


func _grass_dirt_mound(cx: int, cz: int, height: int) -> void:
	var dirt_id := BlockDB.get_id("dirt")
	var grass_id := BlockDB.get_id("grass")
	if not in_bounds(cx, GROUND_Y, cz):
		return
	set_block(cx, GROUND_Y, cz, dirt_id, false)
	for h in range(1, height + 1):
		set_block(cx, GROUND_Y + h, cz, grass_id if h == height else dirt_id, false)
	# skirt of grass-topped dirt for layered edge read
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nx: int = cx + d.x
		var nz: int = cz + d.y
		if in_bounds(nx, GROUND_Y, nz) and get_block(nx, GROUND_Y, nz) == grass_id:
			set_block(nx, GROUND_Y, nz, dirt_id, false)
			set_block(nx, GROUND_Y + 1, nz, grass_id, false)


func _build_knoll(cx: int, cz: int, radius: int, peak: int) -> void:
	var dirt_id := BlockDB.get_id("dirt")
	var grass_id := BlockDB.get_id("grass")
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var d2 := dx * dx + dz * dz
			if d2 > radius * radius:
				continue
			var h := 1
			if d2 <= 1:
				h = peak + 1
			elif d2 <= (radius - 1) * (radius - 1):
				h = peak
			for y in range(1, h + 1):
				var id := grass_id if y == h else dirt_id
				set_block(cx + dx, GROUND_Y + y, cz + dz, id, false)
			# ensure base under mound is dirt so sides show warm soil
			set_block(cx + dx, GROUND_Y, cz + dz, dirt_id, false)


func _stamp_disk(cx: int, cz: int, radius: int, id: int) -> void:
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz <= radius * radius + 1:
				if in_bounds(cx + dx, GROUND_Y, cz + dz):
					set_block(cx + dx, GROUND_Y, cz + dz, id, false)


func _stamp_ring(cx: int, cz: int, radius: int, id: int) -> void:
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var d2 := dx * dx + dz * dz
			if d2 >= (radius - 1) * (radius - 1) and d2 <= radius * radius + 1:
				if in_bounds(cx + dx, GROUND_Y, cz + dz):
					set_block(cx + dx, GROUND_Y, cz + dz, id, false)


func reset_world() -> void:
	generate_flat_world()


func can_place_at(wx: int, wy: int, wz: int, player_aabb: AABB) -> bool:
	if not in_bounds(wx, wy, wz):
		return false
	if get_block(wx, wy, wz) != 0:
		return false
	var block_aabb := AABB(Vector3(wx, wy, wz), Vector3.ONE)
	if player_aabb.intersects(block_aabb):
		return false
	return true


func break_block(wx: int, wy: int, wz: int) -> String:
	var id := get_block(wx, wy, wz)
	if id == 0 or not BlockDB.is_breakable(id):
		return ""
	var drop := BlockDB.get_drop(id)
	set_block(wx, wy, wz, 0, true)
	return drop


func serialize() -> Dictionary:
	var out := {"version": 1, "chunks": {}}
	for key in chunks.keys():
		var k: Vector3i = key
		var b64 := Marshalls.raw_to_base64(chunks[key].to_bytes())
		out["chunks"]["%d,%d,%d" % [k.x, k.y, k.z]] = b64
	return out


func deserialize(data: Dictionary) -> void:
	generate_flat_world()
	var chunk_data: Dictionary = data.get("chunks", {})
	for key_str in chunk_data.keys():
		var parts := str(key_str).split(",")
		if parts.size() != 3:
			continue
		var key := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var bytes := Marshalls.base64_to_raw(str(chunk_data[key_str]))
		var chunk := ensure_chunk(key)
		chunk.from_bytes(bytes)
	for key in chunks.keys():
		chunks[key].dirty = true
		chunks[key].rebuild_mesh()
