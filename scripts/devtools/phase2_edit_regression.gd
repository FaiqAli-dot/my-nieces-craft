extends Node
## Scripted Phase 2 edit ops: move/copy/remove/undo/redo in meadow + house,
## Creative and Survival, plus save/reload without duplicates.
## COZY_PHASE2_EDIT_TEST=1 COZY_SMOKE_QUIT=1

var passed := 0
var failed := 0


func _ready() -> void:
	if OS.get_environment("COZY_PHASE2_EDIT_TEST") != "1":
		queue_free()
		return
	await get_tree().create_timer(0.3).timeout
	print("=== Phase 2 Edit Regression ===")
	await _run_meadow()
	await _run_house()
	print("=== Phase2 Edit Results: %d passed, %d failed ===" % [passed, failed])
	if OS.get_environment("COZY_SMOKE_QUIT") == "1" or OS.get_environment("COZY_PHASE2_EDIT_QUIT") == "1":
		get_tree().quit(1 if failed > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)


func _run_meadow() -> void:
	var world: VoxelWorld = get_parent().get_node_or_null("VoxelWorld")
	var player: PlayerController = get_parent().get_node_or_null("Player")
	if world == null or player == null:
		_assert(false, "meadow world/player present")
		return
	for creative in [true, false]:
		var label := "Creative" if creative else "Survival"
		GameState.set_creative(creative)
		player.prepare_for_mode(GameState.Mode.CREATIVE if creative else GameState.Mode.SURVIVAL)
		player.build_history.clear()
		if creative:
			player.inventory = Inventory.new(true)
		else:
			player.inventory = Inventory.new(false)
			player.inventory.clear()
			player.inventory.add_item("planks", 20)
			player.inventory.hotbar[0] = {"item": "planks", "count": 20}
			player.inventory.select(0)
		var gy := VoxelWorld.GROUND_Y + 1
		var a := Vector3i(40, gy, 40)
		var b := Vector3i(41, gy, 40)
		var c := Vector3i(42, gy, 40)
		for p in [a, b, c]:
			world.set_block(p.x, p.y, p.z, 0, true)
		var bid := BlockDB.place_block_id("planks")
		player.select_build_item("planks")
		_aim(player, a)
		await get_tree().physics_frame
		player.try_place()
		_assert(world.get_block(a.x, a.y, a.z) == bid, "%s meadow place" % label)
		player.begin_copy_targeted_block()
		_aim(player, b)
		await get_tree().physics_frame
		player.try_place()
		_assert(world.get_block(b.x, b.y, b.z) == bid, "%s meadow copy" % label)
		# Move: remove source via history move helper path
		world.set_block(a.x, a.y, a.z, 0, true)
		world.set_block(c.x, c.y, c.z, bid, true)
		player.build_history.push(BuildHistory.block_move(a, c, "planks", bid, 0))
		_assert(world.get_block(c.x, c.y, c.z) == bid, "%s meadow move" % label)
		world.set_block(b.x, b.y, b.z, 0, true)
		if not creative:
			player.inventory.add_item("planks", 1)
		player.build_history.push(BuildHistory.block_remove(b, "planks", bid))
		player.undo_build()
		_assert(world.get_block(b.x, b.y, b.z) == bid, "%s meadow undo remove" % label)
		player.redo_build()
		_assert(world.get_block(b.x, b.y, b.z) == 0, "%s meadow redo remove" % label)
		SaveGame.delete_save()
		var count_before := _count_bid(world, bid, 38, 45, gy)
		_assert(SaveGame.save_world(world, player.inventory), "%s meadow save" % label)
		for z in range(38, 45):
			for x in range(38, 45):
				world.set_block(x, gy, z, 0, true)
		_assert(SaveGame.load_world(world, player.inventory), "%s meadow load" % label)
		var count_after := _count_bid(world, bid, 38, 45, gy)
		_assert(count_after == count_before, "%s meadow reload no dupes (%d)" % [label, count_after])
		SaveGame.delete_save()


func _run_house() -> void:
	## Offline furniture history + disk persist (no live HouseWorld required).
	for creative in [true, false]:
		var label := "Creative" if creative else "Survival"
		GameState.set_creative(creative)
		var hist := BuildHistory.new()
		hist.push(BuildHistory.furniture_place("edit_a", "chair", Vector2i(2, 2), 0))
		hist.push(BuildHistory.furniture_copy("edit_b", "chair", Vector2i(3, 3), 90))
		hist.push(BuildHistory.furniture_move("edit_a", "chair", Vector2i(2, 2), 0, Vector2i(5, 5), 0))
		hist.push(BuildHistory.furniture_remove({
			"instance_id": "edit_b", "def_id": "chair", "cell_x": 3, "cell_z": 3, "rotation": 90,
		}))
		_assert(hist.undo_count() == 4, "%s house hist depth" % label)
		var u := hist.pop_undo()
		_assert(int(u.get("op", -1)) == BuildHistory.Op.REMOVE_FURNITURE, "%s house undo remove entry" % label)
		_assert(str(u.get("instance_id", "")) == "edit_b", "%s house undo keeps identity" % label)
		var r := hist.pop_redo()
		_assert(str(r.get("instance_id", "")) == "edit_b", "%s house redo keeps identity" % label)
		var layout := HouseLayout.new()
		layout.house_id = "phase2_edit_%s" % ("c" if creative else "s")
		layout.owner_id = "local_edit"
		layout.furniture = [
			{"instance_id": "edit_a", "def_id": "chair", "cell_x": 5, "cell_z": 5, "rotation": 0},
			{"instance_id": "edit_b", "def_id": "chair", "cell_x": 3, "cell_z": 3, "rotation": 90},
		]
		var store := HouseStore.new("user://phase2_edit_houses")
		_assert(store.save_house(layout), "%s house save" % label)
		var loaded := store.load_house(layout.house_id)
		_assert(loaded != null and loaded.furniture.size() == 2, "%s house reload count" % label)
		var seen := {}
		for inst in loaded.furniture:
			var iid := str(inst.get("instance_id", ""))
			_assert(iid != "" and not seen.has(iid), "%s house no duplicate id %s" % [label, iid])
			seen[iid] = true


func _count_bid(world: VoxelWorld, bid: int, x0: int, x1: int, gy: int) -> int:
	var n := 0
	for z in range(x0, x1):
		for x in range(x0, x1):
			if world.get_block(x, gy, z) == bid:
				n += 1
	return n


func _aim(player: PlayerController, cell: Vector3i) -> void:
	player.global_position = Vector3(float(cell.x) + 0.5, float(cell.y) + 0.5 - PlayerController.EYE_HEIGHT, float(cell.z) + 2.6)
	player.look_yaw = 0.0
	player.look_pitch = -0.15
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch
	if player.ray:
		player.ray.force_raycast_update()
	player._update_targeting()
