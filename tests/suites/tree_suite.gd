extends Node
## Milestone B — harvestable voxel trees, felling, leaf decay, persistence.

var runner: Node


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[tree] " + msg)


func run() -> void:
	await _test_generated_trees_are_natural()
	await _test_survival_fell_drops_and_collision()
	await _test_neighbour_tree_unaffected()
	await _test_creative_remove_and_build()
	await _test_player_wood_never_fells()
	await _test_harvest_persists_after_save_reload()
	await _test_v1_save_trunk_migration()


func _world() -> VoxelWorld:
	var w: VoxelWorld = runner._make_world()
	return w


func _free(w: Node) -> void:
	w.queue_free()
	await get_tree().process_frame


func _count_ids(w: VoxelWorld, lo: Vector3i, hi: Vector3i, pred: Callable) -> int:
	var n := 0
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				if pred.call(w.get_block(x, y, z)):
					n += 1
	return n


## Finds the base log of the natural tree whose trunk column is (x, z).
func _trunk_base(w: VoxelWorld, x: int, z: int) -> Vector3i:
	for y in range(0, w.world_size_blocks().y):
		if TreeGen.is_tree_log(w.get_block(x, y, z)):
			return Vector3i(x, y, z)
	return Vector3i(-1, -1, -1)


func _trunk_height(w: VoxelWorld, base: Vector3i) -> int:
	var h := 0
	while TreeGen.is_tree_log(w.get_block(base.x, base.y + h, base.z)):
		h += 1
	return h


func _test_generated_trees_are_natural() -> void:
	var w := _world()
	await get_tree().process_frame
	var size := Vector3i(VoxelWorld.MEADOW_SIZE, w.world_size_blocks().y, VoxelWorld.MEADOW_SIZE)
	var bases := 0
	for z in size.z:
		for x in size.x:
			for y in range(VoxelWorld.GROUND_Y, VoxelWorld.GROUND_Y + 4):
				if TreeGen.is_tree_log(w.get_block(x, y, z)) and not TreeGen.is_tree_log(w.get_block(x, y - 1, z)):
					bases += 1
	check(bases >= 18, "meadow has many harvestable voxel trees (%d)" % bases)
	var kinds := {}
	for id_name in ["log", "birch_log", "pine_leaves", "birch_leaves", "leaves"]:
		var id := BlockDB.get_id(id_name)
		kinds[id_name] = _count_ids(w, Vector3i(0, 0, 0), size - Vector3i.ONE, func(b): return b == id) > 0
	check(kinds["log"] and kinds["birch_log"], "oak and birch trunks generated")
	check(kinds["pine_leaves"] and kinds["birch_leaves"] and kinds["leaves"], "three canopy styles generated")
	var props := Node3D.new()
	add_child(props)
	MeadowDresser.new().dress(props)
	var deco_inside := 0
	var canopy := props.find_child("MM_TreeCanopies", true, false)
	var positions: Array = canopy.get_meta("positions", []) if canopy else []
	for o: Vector3 in positions:
		if o.x > w.boundary_min.x and o.x < w.boundary_max.x and o.z > w.boundary_min.z and o.z < w.boundary_max.z:
			deco_inside += 1
	check(positions.size() > 100, "backdrop tree ring generated (%d)" % positions.size())
	check(deco_inside == 0, "no decorative (unbreakable) trees inside the playable area (%d)" % deco_inside)
	props.queue_free()
	await _free(w)


func _test_survival_fell_drops_and_collision() -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var w := _world()
	await get_tree().process_frame
	var base := _trunk_base(w, 26, 30)
	check(base.y > 0, "oak trunk found at (26,30)")
	var h := _trunk_height(w, base)
	check(h >= 4, "oak trunk is tall (%d)" % h)
	var area_lo := base + Vector3i(-3, 0, -3)
	var area_hi := base + Vector3i(3, h + 3, 3)
	var leaves_before := _count_ids(w, area_lo, area_hi, func(b): return TreeGen.is_tree_leaves(b))
	check(leaves_before > 10, "canopy present before felling")
	var rebuilds_before := VoxelChunk.rebuild_count
	var r := w.harvest_block(base.x, base.y, base.z, "", true)
	check(str(r["drop"]) == "wood", "trunk drops wood by hand")
	check(int(r["count"]) == h, "one wood per log (%d/%d)" % [int(r["count"]), h])
	check(bool(r["felled"]), "breaking the base fells the tree")
	check(_count_ids(w, area_lo, area_hi, func(b): return TreeGen.is_tree_log(b)) == 0, "no trunk left floating")
	check(_count_ids(w, area_lo, area_hi, func(b): return TreeGen.is_tree_leaves(b)) == 0, "no floating leaves left")
	check(VoxelChunk.rebuild_count - rebuilds_before <= 8, "felling rebuilds only nearby chunks (%d)" % (VoxelChunk.rebuild_count - rebuilds_before))
	# Drops: one stack, collected once.
	w.spawn_drop(str(r["drop"]), int(r["count"]), Vector3(base) + Vector3(0.5, 0.5, 0.5))
	check(w.drop_root.get_child_count() == 1, "one drop stack, no duplicates")
	var inv := Inventory.new(false)
	for c in w.drop_root.get_children():
		(c as WorldDrop).age = 1.0
	w.collect_nearby_drops(inv, Vector3(base) + Vector3(0.5, 0.5, 0.5), 2.0)
	w.collect_nearby_drops(inv, Vector3(base) + Vector3(0.5, 0.5, 0.5), 2.0)
	check(inv.count_of("wood") == h, "collected exactly the felled wood (%d)" % inv.count_of("wood"))
	# Collision updated: a ray down through the old canopy hits the ground.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := w.get_world_3d().direct_space_state
	var from := Vector3(base.x + 0.5, base.y + h + 4, base.z + 0.5)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0))
	check(not hit.is_empty() and absf(float(hit["position"].y) - float(base.y)) < 0.05, "collision cleared down to the ground")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	await _free(w)


func _test_neighbour_tree_unaffected() -> void:
	var w := _world()
	await get_tree().process_frame
	# Two oaks 4 blocks apart on open ground; canopies touch.
	var y := VoxelWorld.GROUND_Y + 1
	for x in range(2, 14):
		for z in range(54, 62):
			for yy in range(y, y + 10):
				w.set_block(x, yy, z, 0, false)
	TreeGen.grow(w, TreeGen.Kind.OAK, 5, y, 58)
	TreeGen.grow(w, TreeGen.Kind.OAK, 9, y, 58)
	var b_leaves := _count_ids(w, Vector3i(9, y, 56), Vector3i(11, y + 8, 60), func(b): return TreeGen.is_tree_leaves(b))
	w.harvest_block(5, y, 58, "", true)
	check(_trunk_height(w, Vector3i(9, y, 58)) == 5, "neighbour trunk intact")
	check(_count_ids(w, Vector3i(9, y, 56), Vector3i(11, y + 8, 60), func(b): return TreeGen.is_tree_leaves(b)) == b_leaves, "neighbour canopy intact")
	# Leaves within LEAF_SUPPORT of the neighbour's trunk legitimately stay;
	# the far side of the felled canopy (x 2..4) must be gone.
	check(_count_ids(w, Vector3i(2, y, 56), Vector3i(4, y + 8, 60), func(b): return TreeGen.is_tree_leaves(b)) == 0, "felled tree's far canopy decayed")
	await _free(w)


func _test_creative_remove_and_build() -> void:
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	var w := _world()
	await get_tree().process_frame
	var base := _trunk_base(w, 38, 26)
	var h := _trunk_height(w, base)
	var r := w.harvest_block(base.x, base.y + 1, base.z, "", false)
	check(str(r["drop"]) == "wood" and bool(r["felled"]), "creative removes the tree from a mid-trunk hit")
	check(_trunk_height(w, base) == 1, "stump below the hit remains (1)")
	check(_count_ids(w, base + Vector3i(-3, 1, -3), base + Vector3i(3, h + 3, 3), func(b): return TreeGen.is_tree_leaves(b)) == 0, "creative fell leaves nothing floating")
	var p := base + Vector3i(0, 2, 0)
	var far_aabb := AABB(Vector3(0, -50, 0), Vector3.ONE)
	check(w.can_place_at(p.x, p.y, p.z, far_aabb), "cleared space accepts blocks")
	w.set_block(p.x, p.y, p.z, BlockDB.get_id("planks"), true)
	check(w.get_block(p.x, p.y, p.z) == BlockDB.get_id("planks"), "built in cleared space")
	await _free(w)


func _test_player_wood_never_fells() -> void:
	var w := _world()
	await get_tree().process_frame
	var y := VoxelWorld.GROUND_Y + 1
	var wood := BlockDB.get_id("wood")
	for i in 3:
		w.set_block(3, y + i, 3, wood, true)
	w.set_block(3, y + 3, 3, BlockDB.get_id("leaves"), true)
	var r := w.harvest_block(3, y, 3, "", true)
	check(not bool(r["felled"]) and int(r["count"]) == 1, "player-built wood breaks one block at a time")
	check(w.get_block(3, y + 1, 3) == wood, "pillar above player wood stays")
	await _free(w)


func _test_harvest_persists_after_save_reload() -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var w := _world()
	await get_tree().process_frame
	var base := _trunk_base(w, 30, 40)
	var h := _trunk_height(w, base)
	var r := w.harvest_block(base.x, base.y, base.z, "", true)
	var inv := Inventory.new(false)
	inv.add_item(str(r["drop"]), int(r["count"]))
	SaveGame.delete_save()
	check(SaveGame.save_world(w, inv), "save after harvesting")
	var w2 := _world()
	await get_tree().process_frame
	check(TreeGen.is_tree_log(w2.get_block(base.x, base.y, base.z)), "fresh world has the tree")
	var inv2 := Inventory.new(false)
	check(SaveGame.load_world(w2, inv2), "reload")
	check(w2.get_block(base.x, base.y, base.z) == 0, "harvested tree stays gone after reload")
	check(_count_ids(w2, base + Vector3i(-3, 0, -3), base + Vector3i(3, h + 3, 3), func(b): return TreeGen.is_tree_leaves(b) or TreeGen.is_tree_log(b)) == 0, "canopy stays gone after reload")
	check(inv2.count_of("wood") == h, "harvested wood persisted")
	check(GameState.is_survival(), "mode persisted")
	SaveGame.delete_save()
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	await _free(w)
	await _free(w2)


func _test_v1_save_trunk_migration() -> void:
	var w := _world()
	await get_tree().process_frame
	var y := VoxelWorld.GROUND_Y + 1
	var wood := BlockDB.get_id("wood")
	var leaves := BlockDB.get_id("leaves")
	# Old-style tree: wood column capped by leaves. Old fence: bare wood post.
	for x in range(4, 9):
		for yy in range(y, y + 8):
			w.set_block(x, yy, 6, 0, false)
	for i in 4:
		w.set_block(4, y + i, 6, wood, false)
	w.set_block(4, y + 4, 6, leaves, false)
	w.set_block(8, y, 6, wood, false)
	w.set_block(8, y + 1, 6, wood, false)
	var data := w.serialize()
	data["version"] = 1
	var w2 := _world()
	await get_tree().process_frame
	w2.deserialize(data)
	check(TreeGen.is_tree_log(w2.get_block(4, y, 6)) and TreeGen.is_tree_log(w2.get_block(4, y + 3, 6)), "v1 tree trunk migrated to natural log")
	check(w2.get_block(8, y, 6) == wood and w2.get_block(8, y + 1, 6) == wood, "v1 fence post stays player wood")
	check(w2.migrated_tree_logs >= 4, "migration reports converted logs")
	await _free(w)
	await _free(w2)
