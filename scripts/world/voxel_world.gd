extends Node3D
class_name VoxelWorld
## Finite chunked voxel world for the Phase 1 sandbox + S2 Survival resources.

signal world_reset
signal block_changed(pos: Vector3i, id: int)

## The hand-built meadow occupies blocks 0..MEADOW_SIZE-1; biomes surround it.
const MEADOW_SIZE := 64
const CHUNK_MIN := Vector3i(-3, 0, -3)
const CHUNK_MAX := Vector3i(7, 2, 7) # exclusive: 160 x 32 x 160 blocks
const GROUND_Y := 4
const SPAWN_BLOCK := Vector3i(32, GROUND_Y + 1, 32)
const MAX_DROPS := 80
## Chunks (Chebyshev, in x/z) meshed synchronously around the focus on load.
const SYNC_MESH_RADIUS := 1

var chunks: Dictionary = {} # Vector3i -> VoxelChunk
var boundary_min := Vector3(CHUNK_MIN.x * VoxelChunk.SIZE + 1, 0, CHUNK_MIN.z * VoxelChunk.SIZE + 1)
var boundary_max := Vector3(CHUNK_MAX.x * VoxelChunk.SIZE - 2, CHUNK_MAX.y * VoxelChunk.SIZE - 1, CHUNK_MAX.z * VoxelChunk.SIZE - 2)

var chunk_root: Node3D
var drop_root: Node3D
## Set by deserialize() when a v1 save's wood trunks were converted to logs.
var migrated_tree_logs := 0
var world_seed := TerrainGen.DEFAULT_SEED
var terrain: TerrainGen
## Distant chunks are meshed a few per frame, nearest to `focus` first.
var focus: Node3D
var mesh_budget_ms := 4.0
var _mesh_queue: Array[VoxelChunk] = []
var _avg_mesh_ms := 2.0
var _queue_sorted_for := Vector3i(1 << 20, 0, 0)
## While true, set_block() does not mark chunks as player-modified.
var _generating := false


func _ready() -> void:
	chunk_root = get_node_or_null("Chunks") as Node3D
	if chunk_root == null:
		chunk_root = Node3D.new()
		chunk_root.name = "Chunks"
		add_child(chunk_root)
	drop_root = get_node_or_null("Drops") as Node3D
	if drop_root == null:
		drop_root = Node3D.new()
		drop_root.name = "Drops"
		add_child(drop_root)
	generate_flat_world()


func world_min_block() -> Vector3i:
	return CHUNK_MIN * VoxelChunk.SIZE


## Exclusive upper corner.
func world_max_block() -> Vector3i:
	return CHUNK_MAX * VoxelChunk.SIZE


func world_size_blocks() -> Vector3i:
	return world_max_block() - world_min_block()


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
	var lo := CHUNK_MIN * VoxelChunk.SIZE
	var hi := CHUNK_MAX * VoxelChunk.SIZE
	return wx >= lo.x and wy >= lo.y and wz >= lo.z and wx < hi.x and wy < hi.y and wz < hi.z


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
	if not _generating:
		chunk.modified = true
	if rebuild:
		_rebuild_affected(wx, wy, wz)
	block_changed.emit(Vector3i(wx, wy, wz), id)


func _rebuild_affected(wx: int, wy: int, wz: int) -> void:
	_rebuild_keys(_affected_keys(wx, wy, wz))


## Rebuilds each chunk touched by `cells` (plus border neighbours) exactly once.
func rebuild_cells(cells: Array) -> void:
	var keys: Array[Vector3i] = []
	var seen := {}
	for c in cells:
		var p: Vector3i = c
		for k in _affected_keys(p.x, p.y, p.z):
			if not seen.has(k):
				seen[k] = true
				keys.append(k)
	_rebuild_keys(keys)


func _rebuild_keys(keys: Array[Vector3i]) -> void:
	for key in keys:
		if key.x < CHUNK_MIN.x or key.y < CHUNK_MIN.y or key.z < CHUNK_MIN.z:
			continue
		if key.x >= CHUNK_MAX.x or key.y >= CHUNK_MAX.y or key.z >= CHUNK_MAX.z:
			continue
		var chunk := ensure_chunk(key)
		chunk.dirty = true
		chunk.rebuild_mesh()


func _affected_keys(wx: int, wy: int, wz: int) -> Array[Vector3i]:
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
	return keys


func generate_flat_world() -> void:
	_generate()
	mesh_around(focus_point(), SYNC_MESH_RADIUS)
	world_reset.emit()


## Builds every chunk from the seed (meadow + biomes + landmarks); no meshing.
func _generate() -> void:
	if chunk_root == null:
		chunk_root = get_node_or_null("Chunks") as Node3D
		if chunk_root == null:
			chunk_root = Node3D.new()
			chunk_root.name = "Chunks"
			add_child(chunk_root)
	for c in chunk_root.get_children():
		c.queue_free()
	chunks.clear()
	_mesh_queue.clear()
	_queue_sorted_for = Vector3i(1 << 20, 0, 0)
	for cy in range(CHUNK_MIN.y, CHUNK_MAX.y):
		for cz in range(CHUNK_MIN.z, CHUNK_MAX.z):
			for cx in range(CHUNK_MIN.x, CHUNK_MAX.x):
				ensure_chunk(Vector3i(cx, cy, cz))
	_generating = true
	terrain = TerrainGen.new(world_seed, Vector2i(world_min_block().x, world_min_block().z), Vector2i(world_max_block().x, world_max_block().z))
	terrain.fill(self)
	_dress_meadow()
	_place_stone_outcrop()
	_place_boulders()
	_plant_voxel_trees()
	terrain.decorate(self)
	Landmarks.build_signs(self, terrain)
	_generating = false
	clear_drops()
	for key in chunks.keys():
		var c: VoxelChunk = chunks[key]
		c.dirty = true
		c.modified = false
		_mesh_queue.append(c)


func focus_point() -> Vector3:
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		return focus.global_position
	return spawn_position()


func _chunk_distance(c: VoxelChunk, p: Vector3) -> float:
	var centre := Vector3(c.chunk_pos * VoxelChunk.SIZE) + Vector3.ONE * (VoxelChunk.SIZE * 0.5)
	return Vector2(centre.x - p.x, centre.z - p.z).length_squared() + absf(centre.y - p.y)


## Meshes queued chunks within `radius` chunks (x/z) of `pos` right now.
func mesh_around(pos: Vector3, radius: int) -> void:
	var centre := world_to_chunk(floori(pos.x), floori(pos.y), floori(pos.z))
	var keep: Array[VoxelChunk] = []
	for c in _mesh_queue:
		if not is_instance_valid(c):
			continue
		if absi(c.chunk_pos.x - centre.x) <= radius and absi(c.chunk_pos.z - centre.z) <= radius:
			c.rebuild_mesh()
		else:
			keep.append(c)
	_mesh_queue = keep


func mesh_all_now() -> void:
	for c in _mesh_queue:
		if is_instance_valid(c):
			c.rebuild_mesh()
	_mesh_queue.clear()


func pending_mesh_count() -> int:
	return _mesh_queue.size()


## Meshes the nearest queued chunks until `budget_ms` is spent. Returns how many.
func process_mesh_queue(budget_ms: float) -> int:
	var start := Time.get_ticks_usec()
	_sort_mesh_queue()
	var done := 0
	while not _mesh_queue.is_empty():
		var spent := (Time.get_ticks_usec() - start) / 1000.0
		if done > 0 and spent + _avg_mesh_ms > budget_ms:
			break
		var chunk: VoxelChunk = _mesh_queue.pop_back()
		if is_instance_valid(chunk):
			var t0 := Time.get_ticks_usec()
			chunk.rebuild_mesh()
			if chunk.has_geometry():
				_avg_mesh_ms = lerpf(_avg_mesh_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.3)
			done += 1
	return done


## Farthest first, so the nearest chunk is popped from the back. Re-sorted only
## when the focus enters another chunk.
func _sort_mesh_queue() -> void:
	var p := focus_point()
	var key := world_to_chunk(floori(p.x), floori(p.y), floori(p.z))
	if key == _queue_sorted_for:
		return
	_queue_sorted_for = key
	var valid: Array[VoxelChunk] = []
	for c in _mesh_queue:
		if is_instance_valid(c):
			valid.append(c)
	valid.sort_custom(func(a: VoxelChunk, b: VoxelChunk) -> bool: return _chunk_distance(a, p) > _chunk_distance(b, p))
	_mesh_queue = valid


func _process(_delta: float) -> void:
	if not _mesh_queue.is_empty():
		process_mesh_queue(mesh_budget_ms)


func _dress_meadow() -> void:
	## Paths, flower beds, pond, terraces, knolls, fence line, starter pad.
	var path_id := BlockDB.get_id("path_stone")
	var sand_id := BlockDB.get_id("sand")
	var flower_id := BlockDB.get_id("flower_block")
	var dirt_id := BlockDB.get_id("dirt")
	var planks_id := BlockDB.get_id("planks")
	var wood_id := BlockDB.get_id("wood")
	var glass_id := BlockDB.get_id("glass")
	var wool_y := BlockDB.get_id("wool_yellow")
	var wool_p := BlockDB.get_id("wool_pink")
	var grass_id := BlockDB.get_id("grass")
	# Winding warm path from spawn toward garden
	for t in 28:
		var x := 32 + int(round(t * 0.55))
		var z := 32 - t
		_stamp_disk(x, z, 1, path_id)
	for t in 8:
		_stamp_disk(24 + t, 28 - int(t * 0.3), 1, path_id)
	# Golden sand play patch near spawn
	_stamp_disk(28, 36, 3, sand_id)
	# Clustered flower beds (midground / far interest for wide views)
	_stamp_disk(22, 24, 2, flower_id)
	_stamp_disk(40, 22, 2, flower_id)
	_stamp_disk(18, 40, 1, flower_id)
	_stamp_disk(48, 42, 2, flower_id)
	_stamp_disk(14, 50, 2, flower_id)
	_stamp_disk(52, 28, 1, flower_id)
	_stamp_disk(30, 18, 2, flower_id)
	_stamp_disk(16, 28, 1, flower_id)
	_stamp_disk(44, 34, 1, flower_id)
	_stamp_disk(36, 46, 2, flower_id)
	# Dirt garden beds + warm ground patches
	_stamp_disk(24, 30, 1, dirt_id)
	_stamp_disk(38, 28, 1, dirt_id)
	_stamp_disk(20, 36, 1, dirt_id)
	_stamp_disk(46, 20, 1, sand_id)
	# Pond in midground (visible from south-looking wide shots)
	_stamp_disk(20, 20, 3, sand_id)
	_stamp_disk(20, 20, 2, glass_id)
	set_block(20, GROUND_Y, 20, glass_id, false)
	# Layered edge terraces (grass on dirt) — no grey walls
	for i in 8:
		var bx := 8 + i * 6
		var bz := 8 + i * 6
		for edge in [Vector2i(bx, 5), Vector2i(bx, 58), Vector2i(5, bz), Vector2i(58, bz)]:
			_grass_dirt_mound(edge.x, edge.y, 1 if i % 2 == 0 else 2)
	# Interior knolls / terraces for midground silhouette
	# Knolls away from playhouse pad (32-42) and garden (48,12)
	_build_knoll(16, 18, 2, 1)
	_build_knoll(50, 48, 2, 1)
	_build_knoll(22, 48, 2, 1)
	_build_knoll(12, 36, 2, 1)
	_build_knoll(54, 36, 2, 1)
	_build_knoll(28, 14, 2, 1)
	_build_knoll(10, 24, 2, 1)
	_build_knoll(56, 52, 2, 1)
	_build_knoll(8, 50, 2, 1)
	# Fence lines readable in wide meadow (midground + west edge)
	for i in 9:
		var fx := 10 + i * 2
		set_block(fx, GROUND_Y + 1, 16, wood_id, false)
		if i % 2 == 0:
			set_block(fx, GROUND_Y + 2, 16, wood_id, false)
	for i in 6:
		var fz := 18 + i * 2
		set_block(10, GROUND_Y + 1, fz, wood_id, false)
		if i % 2 == 0:
			set_block(10, GROUND_Y + 2, fz, wood_id, false)
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
	var current := get_block(wx, wy, wz)
	if current != 0 and not BlockDB.is_liquid(current):
		return false
	var block_aabb := AABB(Vector3(wx, wy, wz), Vector3.ONE)
	if player_aabb.intersects(block_aabb):
		return false
	return true


func break_block(wx: int, wy: int, wz: int) -> String:
	## Creative / legacy helper: always awards the normal drop into caller inventory.
	return str(harvest_block(wx, wy, wz, "", false).get("drop", ""))


func break_block_survival(wx: int, wy: int, wz: int, held_item: String) -> String:
	## Removes the block; returns drop item id (may be empty if wrong tool).
	return str(harvest_block(wx, wy, wz, held_item, true).get("drop", ""))


## Player break entry point. Natural tree logs fell every connected log above
## and decay orphaned leaves (no floating canopies).
## Returns {"drop": item, "count": n, "felled": bool, "block": block_name}.
func harvest_block(wx: int, wy: int, wz: int, held_item: String, survival: bool) -> Dictionary:
	var id := get_block(wx, wy, wz)
	if id == 0 or not BlockDB.is_breakable(id):
		return {"drop": "", "count": 0, "felled": false, "block": ""}
	var block_name := BlockDB.get_block_name(id)
	var drop := MiningRules.drop_for_break(id, held_item) if survival else BlockDB.get_drop(id)
	if TreeGen.is_tree_log(id):
		var felled := TreeGen.fell(self, Vector3i(wx, wy, wz))
		var logs := int(felled.get("logs", 1))
		return {"drop": drop, "count": logs if drop != "" else 0, "felled": logs > 1, "block": block_name}
	set_block(wx, wy, wz, 0, true)
	return {"drop": drop, "count": 1 if drop != "" else 0, "felled": false, "block": block_name}


func spawn_drop(item: String, count: int, at: Vector3) -> void:
	if item == "" or count <= 0:
		return
	if drop_root == null:
		drop_root = Node3D.new()
		drop_root.name = "Drops"
		add_child(drop_root)
	_enforce_drop_cap()
	var d := WorldDrop.new()
	d.setup(item, count, at + Vector3(0.0, 0.2, 0.0))
	drop_root.add_child(d)
	d.global_position = at + Vector3(0.0, 0.2, 0.0)


func clear_drops() -> void:
	if drop_root == null:
		return
	for c in drop_root.get_children():
		c.queue_free()


func _enforce_drop_cap() -> void:
	if drop_root == null:
		return
	var kids := drop_root.get_children()
	var overflow := kids.size() - MAX_DROPS + 1
	if overflow <= 0:
		return
	for i in overflow:
		if i < kids.size():
			kids[i].queue_free()


func collect_nearby_drops(inventory: Inventory, collector_pos: Vector3, radius: float = 1.6) -> int:
	if drop_root == null or inventory == null:
		return 0
	var collected := 0
	for c in drop_root.get_children():
		var drop := c as WorldDrop
		if drop == null:
			continue
		if collector_pos.distance_to(drop.global_position) <= radius:
			var before := drop.count
			if drop.try_collect(inventory):
				collected += before - maxi(drop.count, 0)
	return collected


func has_crafting_table_near(pos: Vector3, radius: float = 3.5) -> bool:
	var table_id := BlockDB.get_id("crafting_table")
	if table_id == 0:
		return false
	var cx := floori(pos.x)
	var cy := floori(pos.y)
	var cz := floori(pos.z)
	var r := ceili(radius)
	for dy in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if get_block(cx + dx, cy + dy, cz + dz) == table_id:
					return true
	return false


func serialize_drops() -> Array:
	var out: Array = []
	if drop_root == null:
		return out
	for c in drop_root.get_children():
		var drop := c as WorldDrop
		if drop:
			out.append(drop.to_dict())
	return out


func deserialize_drops(data) -> void:
	clear_drops()
	if typeof(data) != TYPE_ARRAY:
		return
	if drop_root == null:
		drop_root = Node3D.new()
		drop_root.name = "Drops"
		add_child(drop_root)
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d := WorldDrop.from_dict(entry)
		drop_root.add_child(d)


func _plant_voxel_trees() -> void:
	## Every tree inside the playable area is a harvestable voxel tree.
	var spots := [
		[26, 30, TreeGen.Kind.OAK], [38, 26, TreeGen.Kind.OAK], [30, 40, TreeGen.Kind.BIRCH],
		[42, 38, TreeGen.Kind.OAK], [20, 34, TreeGen.Kind.BIRCH], [48, 32, TreeGen.Kind.PINE],
		[24, 44, TreeGen.Kind.OAK], [36, 20, TreeGen.Kind.BIRCH],
		[18, 26, TreeGen.Kind.OAK], [16, 30, TreeGen.Kind.PINE], [14, 34, TreeGen.Kind.BIRCH],
		[46, 26, TreeGen.Kind.BIRCH], [50, 38, TreeGen.Kind.PINE], [58, 26, TreeGen.Kind.PINE],
		[18, 46, TreeGen.Kind.OAK], [24, 50, TreeGen.Kind.PINE], [10, 28, TreeGen.Kind.OAK],
		[56, 44, TreeGen.Kind.PINE], [8, 48, TreeGen.Kind.OAK], [12, 12, TreeGen.Kind.PINE],
		[54, 54, TreeGen.Kind.OAK], [30, 56, TreeGen.Kind.BIRCH], [44, 52, TreeGen.Kind.OAK],
	]
	for s in spots:
		var x: int = s[0]
		var z: int = s[1]
		var base := surface_y(x, z) + 1
		if TreeGen.grow(self, int(s[2]), x, base, z):
			set_block(x, base - 1, z, BlockDB.get_id("dirt"), false)


## Highest solid block in the column (or GROUND_Y if empty).
func surface_y(x: int, z: int) -> int:
	for y in range(world_size_blocks().y - 1, -1, -1):
		var id := get_block(x, y, z)
		if id != 0 and not TreeGen.is_tree_leaves(id):
			return y
	return GROUND_Y


func _place_stone_outcrop() -> void:
	## Surface stone near spawn so Survival players need not dig deep.
	var stone_id := BlockDB.get_id("stone")
	var spots: Array[Vector2i] = [
		Vector2i(44, 30), Vector2i(45, 30), Vector2i(44, 31),
		Vector2i(45, 31), Vector2i(46, 30), Vector2i(44, 29),
	]
	for s in spots:
		set_block(s.x, GROUND_Y, s.y, stone_id, false)
		set_block(s.x, GROUND_Y + 1, s.y, stone_id, false)
	set_block(45, GROUND_Y + 2, 30, stone_id, false)


func _place_boulders() -> void:
	## Small mineable rock piles (replace the old walk-through rock props).
	var stone_id := BlockDB.get_id("stone")
	var cobble_id := BlockDB.get_id("cobble")
	var spots: Array[Vector2i] = [
		Vector2i(30, 20), Vector2i(22, 42), Vector2i(48, 46), Vector2i(14, 52),
		Vector2i(54, 22), Vector2i(24, 16), Vector2i(18, 22), Vector2i(34, 12),
	]
	for i in spots.size():
		var s := spots[i]
		var y := surface_y(s.x, s.y) + 1
		var cells: Array[Vector3i] = [
			Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 0),
		]
		if i % 2 == 0:
			cells.append(Vector3i(-1, 0, 0))
			cells.append(Vector3i(1, 1, 1))
		for c in cells:
			var p := Vector3i(s.x, y, s.y) + c
			if get_block(p.x, p.y, p.z) == 0:
				set_block(p.x, p.y, p.z, cobble_id if (p.x + p.z) % 3 == 0 else stone_id, false)


## v2: natural trees use tree_log blocks (log/birch_log) instead of wood.
## v3: seeded biome world; only player-modified chunks are stored (+ seed).
## v1/v2 saves hold every meadow chunk; those load as modified chunks.
const WORLD_DATA_VERSION := 3


func serialize() -> Dictionary:
	var out := {"version": WORLD_DATA_VERSION, "seed": world_seed, "chunks": {}}
	for key in chunks.keys():
		var c: VoxelChunk = chunks[key]
		if not c.modified:
			continue
		var k: Vector3i = key
		out["chunks"]["%d,%d,%d" % [k.x, k.y, k.z]] = Marshalls.raw_to_base64(c.to_bytes())
	return out


func deserialize(data: Dictionary) -> void:
	world_seed = int(data.get("seed", TerrainGen.DEFAULT_SEED))
	_generate()
	var chunk_data: Dictionary = data.get("chunks", {})
	for key_str in chunk_data.keys():
		var parts := str(key_str).split(",")
		if parts.size() != 3:
			continue
		var key := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		if not chunks.has(key):
			continue
		var bytes := Marshalls.base64_to_raw(str(chunk_data[key_str]))
		var chunk: VoxelChunk = chunks[key]
		chunk.from_bytes(bytes)
		chunk.modified = true
	if int(data.get("version", 1)) < 2:
		migrated_tree_logs = _migrate_v1_tree_trunks()
	mesh_around(focus_point(), SYNC_MESH_RADIUS)
	world_reset.emit()


func _migrate_v1_tree_trunks() -> int:
	## v1 trees were plain `wood` columns capped by leaves. Convert those runs to
	## natural logs so they fell like new trees; other wood (fences, builds) stays.
	var wood_id := BlockDB.get_id("wood")
	var log_id := BlockDB.get_id("log")
	var height := world_size_blocks().y
	var converted := 0
	for z in MEADOW_SIZE:
		for x in MEADOW_SIZE:
			var y := 0
			while y < height:
				if get_block(x, y, z) != wood_id or get_block(x, y - 1, z) == wood_id:
					y += 1
					continue
				var top := y
				while get_block(x, top + 1, z) == wood_id:
					top += 1
				if TreeGen.is_tree_leaves(get_block(x, top + 1, z)) and top - y < 8:
					for ty in range(y, top + 1):
						set_block(x, ty, z, log_id, false)
						converted += 1
				y = top + 1
	return converted
