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
	# Mark all dirty and rebuild once
	for key in chunks.keys():
		chunks[key].dirty = true
		chunks[key].rebuild_mesh()
	world_reset.emit()


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
