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
	## Paths, flower beds, play patches, rim hills, and a cozy starter pad.
	var path_id := BlockDB.get_id("path_stone")
	var sand_id := BlockDB.get_id("sand")
	var flower_id := BlockDB.get_id("flower_block")
	var cobble_id := BlockDB.get_id("cobble")
	var dirt_id := BlockDB.get_id("dirt")
	var planks_id := BlockDB.get_id("planks")
	var wool_y := BlockDB.get_id("wool_yellow")
	var wool_p := BlockDB.get_id("wool_pink")
	var grass_id := BlockDB.get_id("grass")
	var leaves_id := BlockDB.get_id("leaves")
	# Winding path from spawn toward garden
	for t in 30:
		var x := 32 + int(round(t * 0.55))
		var z := 32 - t
		_stamp_disk(x, z, 1 if t % 3 != 0 else 2, path_id)
	# Side spur path to flower nook
	for t in 10:
		_stamp_disk(24 + t, 28 - int(t * 0.3), 1, path_id)
	# Soft sand play patch near spawn
	_stamp_disk(28, 36, 3, sand_id)
	_stamp_disk(27, 37, 1, sand_id)
	# Flower beds (filled, not just rings)
	_stamp_disk(22, 24, 2, flower_id)
	_stamp_ring(22, 24, 3, flower_id)
	_stamp_disk(40, 22, 2, flower_id)
	_stamp_disk(18, 40, 2, flower_id)
	# Dirt garden beds + leaf accents
	_stamp_disk(24, 30, 2, dirt_id)
	_stamp_disk(38, 28, 2, dirt_id)
	set_block(24, GROUND_Y, 30, leaves_id, false)
	set_block(38, GROUND_Y, 28, leaves_id, false)
	# Sparse meadow speckles so grass doesn't read as one tile forever
	for i in 40:
		var sx := 10 + (i * 7) % 44
		var sz := 10 + (i * 11) % 44
		if get_block(sx, GROUND_Y, sz) == grass_id and (i % 3) == 0:
			set_block(sx, GROUND_Y, sz, flower_id if i % 2 == 0 else dirt_id, false)
	# Soft natural rim mounds (not a pillar arena) — clustered low hills on the border
	for i in 10:
		var bx := 6 + i * 5
		var bz := 6 + i * 5
		for edge in [
			Vector2i(bx, 5), Vector2i(bx, 58),
			Vector2i(5, bz), Vector2i(58, bz),
		]:
			if not in_bounds(edge.x, GROUND_Y, edge.y):
				continue
			set_block(edge.x, GROUND_Y, edge.y, dirt_id, false)
			set_block(edge.x, GROUND_Y + 1, edge.y, grass_id, false)
			# occasional 2-high mound with a flower or cobble accent
			if i % 2 == 0:
				set_block(edge.x, GROUND_Y + 2, edge.y, grass_id, false)
			if i % 3 == 0 and in_bounds(edge.x + 1, GROUND_Y, edge.y):
				set_block(edge.x + 1, GROUND_Y, edge.y, cobble_id, false)
				set_block(edge.x + 1, GROUND_Y + 1, edge.y, flower_id if i % 2 == 0 else grass_id, false)
	# Low hillock near garden for silhouette
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var d2 := dx * dx + dz * dz
			if d2 <= 8:
				set_block(45 + dx, GROUND_Y + 1, 14 + dz, dirt_id, false)
				set_block(45 + dx, GROUND_Y + 2, 14 + dz, grass_id, false)
			if d2 <= 2:
				set_block(45 + dx, GROUND_Y + 3, 14 + dz, grass_id, false)
	# Second smaller knoll near spawn for depth
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if dx * dx + dz * dz <= 4:
				set_block(20 + dx, GROUND_Y + 1, 44 + dz, dirt_id, false)
				set_block(20 + dx, GROUND_Y + 2, 44 + dz, grass_id, false)
	# Cozy starter build pad (planks floor + wool corner markers)
	for x in range(34, 40):
		for z in range(34, 40):
			set_block(x, GROUND_Y, z, planks_id, false)
	# Path ring around pad
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
