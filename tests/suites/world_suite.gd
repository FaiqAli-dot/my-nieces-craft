extends Node
## Milestone E — bigger biome world: bounds, determinism, unchanged meadow,
## biomes, landmarks, lazy meshing, edited-chunk saves and old-save loading.

var runner: Node


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[world] " + msg)


func run() -> void:
	var w: VoxelWorld = runner._make_world()
	await get_tree().process_frame
	_test_bounds(w)
	_test_meadow_core(w)
	_test_biomes_and_landmarks(w)
	_test_lazy_meshing(w)
	_test_saves_store_edits_only(w)
	_test_old_full_save_loads(w)
	_test_water_is_replaceable(w)
	_test_determinism()
	w.queue_free()
	await get_tree().process_frame


func _count(w: VoxelWorld, centre: Vector2i, r: int, y0: int, y1: int, id: int) -> int:
	var n := 0
	for z in range(centre.y - r, centre.y + r + 1):
		for x in range(centre.x - r, centre.x + r + 1):
			for y in range(y0, y1):
				if w.get_block(x, y, z) == id:
					n += 1
	return n


func _test_bounds(w: VoxelWorld) -> void:
	check(w.world_size_blocks() == Vector3i(160, 32, 160), "world is 160 x 32 x 160 blocks")
	check(w.chunks.size() == 200, "200 chunks generated (%d)" % w.chunks.size())
	check(w.in_bounds(-48, 0, -48) and w.in_bounds(111, 31, 111), "negative and far corners in bounds")
	check(not w.in_bounds(-49, 5, 0) and not w.in_bounds(112, 5, 0), "outside the rim is out of bounds")
	check(w.boundary_min.x < -40.0 and w.boundary_max.x > 100.0, "player boundary covers the whole world")
	check(w.get_block(-40, 0, -40) != 0, "far corner has ground")


func _test_meadow_core(w: VoxelWorld) -> void:
	var stone := BlockDB.get_id("stone")
	var dirt := BlockDB.get_id("dirt")
	var gy := VoxelWorld.GROUND_Y
	# Columns away from any hand-placed feature keep the classic layering.
	check(w.get_block(3, 0, 60) == stone and w.get_block(3, gy - 2, 60) == dirt, "meadow ground layers unchanged")
	check(w.get_block(35, gy, 35) == BlockDB.get_id("planks"), "starter build pad still at (35,35)")
	check(w.get_block(34, gy + 1, 34) == BlockDB.get_id("wool_yellow"), "pad corner wool unchanged")
	check(w.get_block(20, gy, 20) == BlockDB.get_id("glass"), "meadow pond unchanged")
	check(w.get_block(45, gy + 2, 30) == stone, "stone outcrop unchanged")
	check(w.spawn_position().distance_to(Vector3(32.5, gy + 1.1, 32.5)) < 0.01, "spawn unchanged")
	var flat := true
	for x in range(0, VoxelWorld.MEADOW_SIZE, 9):
		if w.terrain.height_at(x, 0) != gy or w.terrain.height_at(x, VoxelWorld.MEADOW_SIZE - 1) != gy:
			flat = false
	check(flat, "meadow terrain height stays at ground level")
	var step_ok := true
	for x in range(-10, 1):
		if absi(w.terrain.height_at(x, 32) - w.terrain.height_at(x + 1, 32)) > 2:
			step_ok = false
	check(step_ok, "terrain blends into the meadow edge without cliffs")


func _test_biomes_and_landmarks(w: VoxelWorld) -> void:
	var t := w.terrain
	check(t.biome_at(32, 32) == TerrainGen.Biome.MEADOW, "centre is the meadow")
	check(t.biome_at(32, -30) == TerrainGen.Biome.FOREST, "north is the forest")
	check(t.biome_at(100, 32) == TerrainGen.Biome.SNOW, "east is the snowy hills")
	check(t.biome_at(32, 100) == TerrainGen.Biome.BEACH, "south is the beach")
	check(t.biome_at(-30, 32) == TerrainGen.Biome.FLOWERS, "west is the flower fields")
	check(_count(w, Vector2i(96, 32), 14, 0, 32, BlockDB.get_id("snow")) > 40, "snow covers the hills")
	check(_count(w, Vector2i(32, 90), 14, 0, 8, BlockDB.get_id("water")) > 60, "the lake holds water")
	check(_count(w, Vector2i(32, 90), 20, 0, 8, BlockDB.get_id("sand")) > 60, "the lake has a sandy shore")
	check(_count(w, Vector2i(-28, 32), 18, 0, 10, BlockDB.get_id("flower_block")) > 20, "flower fields bloom")
	var forest_logs := 0
	for id_name in ["log", "birch_log"]:
		forest_logs += _count(w, Vector2i(32, -30), 16, 4, 20, BlockDB.get_id(id_name))
	check(forest_logs > 40, "the forest is full of harvestable trees (%d logs)" % forest_logs)
	check(_count(w, Vector2i(32, -28), 5, 0, 12, BlockDB.get_id("mossy_cobble")) > 12, "mossy ruins stand in the forest")
	var tb := t.landmark_base_y("tower")
	check(w.get_block(90, tb + 7, 30) == BlockDB.get_id("planks") and w.get_block(87, tb, 26) == BlockDB.get_id("planks"), "lookout tower has a deck and stairs")
	check(_count(w, Vector2i(32, 90), 1, 0, 20, BlockDB.get_id("wool_red")) > 10, "lighthouse stands on the lake island")
	check(_count(w, Vector2i(32, 80), 1, VoxelWorld.GROUND_Y, VoxelWorld.GROUND_Y + 1, BlockDB.get_id("planks")) >= 3, "a pier leads to the lighthouse")
	check(_count(w, Vector2i(-26, 32), 5, 0, 20, BlockDB.get_id("plaster")) >= 16, "windmill has four sails")
	var signs := w.get_node_or_null(Landmarks.SIGN_ROOT)
	check(signs != null and signs.get_child_count() == TerrainGen.LANDMARKS.size() + 4, "landmark and biome signs placed")
	var meadow_trees := 0
	var log_id := BlockDB.get_id("log")
	for z in VoxelWorld.MEADOW_SIZE:
		for x in VoxelWorld.MEADOW_SIZE:
			if w.get_block(x, VoxelWorld.GROUND_Y + 1, z) == log_id:
				meadow_trees += 1
	check(meadow_trees > 0 and meadow_trees < 30, "biome decoration does not spill trees into the meadow (%d)" % meadow_trees)


func _test_lazy_meshing(w: VoxelWorld) -> void:
	w.generate_flat_world()
	var spawn_key := w.world_to_chunk(32, 4, 32)
	check(not (w.chunks[spawn_key] as VoxelChunk).dirty, "chunks around spawn are meshed immediately")
	var pending := w.pending_mesh_count()
	check(pending > 100, "distant chunks wait in the mesh queue (%d)" % pending)
	var far: VoxelChunk = w.chunks[Vector3i(-3, 0, -3)]
	check(far.dirty, "a far corner chunk is not meshed at load")
	var queued_before: Array = w._mesh_queue.duplicate()
	var done := w.process_mesh_queue(4.0)
	check(done >= 1 and w.pending_mesh_count() == pending - done, "the budget meshes some chunks per frame (%d)" % done)
	var p := w.focus_point()
	var farthest_done := 0.0
	for c in queued_before:
		if not w._mesh_queue.has(c):
			farthest_done = maxf(farthest_done, w._chunk_distance(c, p))
	var nearest_left := INF
	for c in w._mesh_queue:
		nearest_left = minf(nearest_left, w._chunk_distance(c, p))
	check(farthest_done <= nearest_left and far.dirty, "nearest chunks are meshed first")
	w.mesh_all_now()
	check(w.pending_mesh_count() == 0 and not far.dirty, "queue drains completely")
	var before := VoxelChunk.rebuild_count
	w.set_block(-40, 10, -40, BlockDB.get_id("stone"), true)
	check(VoxelChunk.rebuild_count - before <= 3, "edits in the far world rebuild only nearby chunks")
	w.set_block(-40, 10, -40, 0, true)


func _test_saves_store_edits_only(w: VoxelWorld) -> void:
	w.generate_flat_world()
	var fresh := w.serialize()
	check(int(fresh["version"]) == VoxelWorld.WORLD_DATA_VERSION and fresh.has("seed"), "save carries version and seed")
	check((fresh["chunks"] as Dictionary).is_empty(), "an untouched world saves no chunks")
	w.set_block(-30, 9, 70, BlockDB.get_id("brick"), true)
	w.set_block(100, 12, 100, BlockDB.get_id("brick"), true)
	var data := w.serialize()
	check((data["chunks"] as Dictionary).size() == 2, "only edited chunks are saved")
	check(JSON.stringify(data).length() < 20000, "an edited save stays small (%d bytes)" % JSON.stringify(data).length())
	w.generate_flat_world()
	check(w.get_block(-30, 9, 70) != BlockDB.get_id("brick"), "regeneration clears the edit")
	w.deserialize(data)
	check(w.get_block(-30, 9, 70) == BlockDB.get_id("brick") and w.get_block(100, 12, 100) == BlockDB.get_id("brick"), "edits restored from the save")
	check(w.get_block(32, VoxelWorld.GROUND_Y, -28 + 3) != 0, "unsaved chunks regenerate from the seed")
	check((w.serialize()["chunks"] as Dictionary).size() == 2, "loaded edits stay marked for the next save")


func _test_old_full_save_loads(w: VoxelWorld) -> void:
	w.generate_flat_world()
	var chunk: VoxelChunk = w.chunks[Vector3i(1, 0, 1)]
	var bytes := chunk.to_bytes()
	bytes[0] = BlockDB.get_id("brick")
	var v2 := {"version": 2, "chunks": {"1,0,1": Marshalls.raw_to_base64(bytes)}}
	w.deserialize(v2)
	check(w.world_seed == TerrainGen.DEFAULT_SEED, "old saves use the default seed")
	check(w.get_block(16, 0, 16) == BlockDB.get_id("brick"), "old full-chunk save data is applied")
	check(w.get_block(96, 0, 32) != 0, "old saves gain the new biomes around the meadow")
	check((w.serialize()["chunks"] as Dictionary).has("1,0,1"), "old chunks are kept on the next save")
	w.deserialize({"version": 3, "seed": 1234, "chunks": {"99,0,0": "AAAA", "bad": "x"}})
	check(w.world_seed == 1234 and w.get_block(32, VoxelWorld.GROUND_Y, 32) != 0, "unknown chunk keys are ignored safely")
	w.world_seed = TerrainGen.DEFAULT_SEED


func _test_water_is_replaceable(w: VoxelWorld) -> void:
	w.generate_flat_world()
	var water := BlockDB.get_id("water")
	var spot := Vector3i(-9999, 0, 0)
	for z in range(84, 97):
		for x in range(26, 39):
			if w.get_block(x, TerrainGen.SEA_Y, z) == water and spot.x == -9999:
				spot = Vector3i(x, TerrainGen.SEA_Y, z)
	check(spot.x != -9999, "found lake water")
	check(not BlockDB.is_solid(water) and BlockDB.is_liquid(water), "water is a non-solid liquid")
	var far_aabb := AABB(Vector3(0, 50, 0), Vector3.ONE)
	check(w.can_place_at(spot.x, spot.y, spot.z, far_aabb), "blocks can be placed into water")


func _test_determinism() -> void:
	var a := TerrainGen.new(TerrainGen.DEFAULT_SEED)
	var b := TerrainGen.new(TerrainGen.DEFAULT_SEED)
	var c := TerrainGen.new(777)
	var same := true
	var differs := false
	var meadow_same := true
	for i in 200:
		var x := -48 + (i * 37) % 160
		var z := -48 + (i * 53) % 160
		if a.height_at(x, z) != b.height_at(x, z):
			same = false
		if a.height_at(x, z) != c.height_at(x, z):
			differs = true
		if TerrainGen.in_meadow(x, z) and a.height_at(x, z) != c.height_at(x, z):
			meadow_same = false
	check(same, "same seed, same terrain")
	check(differs, "a different seed changes the wilds")
	check(meadow_same, "the meadow is the same for every seed")
