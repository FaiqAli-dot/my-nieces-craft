extends Node
## World generation / meshing benchmark.
## godot --headless --path . res://scenes/devtools/world_perf_bench.tscn

func _ready() -> void:
	await get_tree().process_frame
	var w := VoxelWorld.new()
	var t0 := Time.get_ticks_usec()
	add_child(w)
	var t1 := Time.get_ticks_usec()
	w.set_process(false)
	print("[BENCH] world ready ms=%.1f chunks=%d meshed=%d queued=%d" % [(t1 - t0) / 1000.0, w.chunks.size(), _meshed(w), w.pending_mesh_count()])
	var frames := 0
	var worst := 0.0
	var tq := Time.get_ticks_usec()
	while w.pending_mesh_count() > 0:
		await get_tree().process_frame
		frames += 1
		var f0 := Time.get_ticks_usec()
		var did := w.process_mesh_queue(w.mesh_budget_ms)
		var ms := (Time.get_ticks_usec() - f0) / 1000.0
		if ms > 6.0:
			print("[BENCH] slow frame %d ms=%.2f chunks=%d" % [frames, ms, did])
		worst = maxf(worst, ms)
	print("[BENCH] background mesh frames=%d wall_ms=%.1f worst_frame_ms=%.2f budget_ms=%.1f" % [frames, (Time.get_ticks_usec() - tq) / 1000.0, worst, w.mesh_budget_ms])
	var t2 := Time.get_ticks_usec()
	var n := 0
	for k in w.chunks.keys():
		var c: VoxelChunk = w.chunks[k]
		c.dirty = true
		c.rebuild_mesh()
		n += 1
	var t3 := Time.get_ticks_usec()
	print("[BENCH] full remesh ms=%.1f per_chunk_ms=%.2f" % [(t3 - t2) / 1000.0, (t3 - t2) / 1000.0 / maxf(n, 1)])
	w.set_block(40, VoxelWorld.GROUND_Y + 1, 40, BlockDB.get_id("planks"), true)
	var t4 := Time.get_ticks_usec()
	var data := w.serialize()
	var json := JSON.stringify(data)
	var t5 := Time.get_ticks_usec()
	print("[BENCH] serialize ms=%.1f bytes=%d saved_chunks=%d" % [(t5 - t4) / 1000.0, json.length(), (data["chunks"] as Dictionary).size()])
	var t6 := Time.get_ticks_usec()
	w.deserialize(data)
	print("[BENCH] deserialize ms=%.1f" % ((Time.get_ticks_usec() - t6) / 1000.0))
	var g0 := Time.get_ticks_usec()
	var gen := TerrainGen.new(w.world_seed)
	var g1 := Time.get_ticks_usec()
	gen.fill(w)
	var g2 := Time.get_ticks_usec()
	print("[BENCH] terrain init ms=%.1f fill ms=%.1f" % [(g1 - g0) / 1000.0, (g2 - g1) / 1000.0])
	var slowest := 0.0
	for k in w.chunks.keys():
		var c: VoxelChunk = w.chunks[k]
		c.dirty = true
		var c0 := Time.get_ticks_usec()
		c.rebuild_mesh()
		slowest = maxf(slowest, (Time.get_ticks_usec() - c0) / 1000.0)
	print("[BENCH] slowest chunk mesh ms=%.2f" % slowest)
	get_tree().quit()


func _meshed(w: VoxelWorld) -> int:
	var n := 0
	for k in w.chunks.keys():
		if not (w.chunks[k] as VoxelChunk).dirty:
			n += 1
	return n
