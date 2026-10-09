extends Node
## Scene-based test runner so autoloads are available.

var passed := 0
var failed := 0

func _ready() -> void:
	print("=== CozyBlocks Tests ===")
	_test_block_db()
	_test_inventory()
	_test_crafting()
	_test_placement_helpers()
	await _test_world_serialize()
	await _test_chunk_mesh_update()
	print("=== Results: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)


func _test_block_db() -> void:
	_assert(BlockDB.get_id("grass") == 1, "grass id is 1")
	_assert(BlockDB.get_id("dirt") == 2, "dirt id is 2")
	_assert(BlockDB.is_solid(1), "grass is solid")
	_assert(not BlockDB.is_solid(0), "air not solid")
	_assert(BlockDB.get_drop(1) == "dirt", "grass drops dirt")
	_assert(BlockDB.is_placeable("stone"), "stone placeable")
	_assert(not BlockDB.is_placeable("sticks"), "sticks not placeable")
	_assert(BlockDB.display_name("wool_pink") == "Pink Wool", "display name")
	_assert(BlockDB.get_atlas_texture() != null, "atlas built")


func _test_inventory() -> void:
	GameState.creative_mode = false
	var inv := Inventory.new()
	for i in inv.hotbar.size():
		inv.hotbar[i] = {"item": "", "count": 0}
	var added := inv.add_item("wood", 10)
	_assert(added == 10, "add 10 wood")
	_assert(inv.count_of("wood") == 10, "count wood 10")
	_assert(inv.remove_item("wood", 3), "remove 3 wood")
	_assert(inv.count_of("wood") == 7, "count wood 7")
	inv.select(0)
	inv.hotbar[0] = {"item": "stone", "count": 2}
	_assert(inv.consume_selected(1), "consume selected")
	_assert(inv.selected_count() == 1, "selected count 1")
	GameState.creative_mode = true
	inv.hotbar[0] = {"item": "stone", "count": 1}
	_assert(inv.consume_selected(1), "creative consume keeps")
	_assert(inv.selected_count() == 1, "creative unlimited")


func _test_crafting() -> void:
	GameState.creative_mode = false
	var inv := Inventory.new()
	for i in inv.hotbar.size():
		inv.hotbar[i] = {"item": "", "count": 0}
	inv.add_item("wood", 2)
	var craft := CraftingSystem.new()
	_assert(craft.can_craft(craft.find_recipe("wood_to_planks"), inv), "can craft planks")
	_assert(craft.craft("wood_to_planks", inv), "craft planks")
	_assert(inv.count_of("wood") == 1, "wood consumed")
	_assert(inv.count_of("planks") == 4, "planks produced")
	_assert(not craft.craft("glass_from_sand", inv), "cannot craft glass without sand")
	inv.add_item("planks", 2)
	_assert(craft.craft("planks_to_sticks", inv), "craft sticks")
	_assert(inv.count_of("sticks") == 4, "sticks produced")


func _test_placement_helpers() -> void:
	var player_aabb := AABB(Vector3(10, 5, 10), Vector3(0.6, 1.7, 0.6))
	var block_inside := AABB(Vector3(10, 5, 10), Vector3.ONE)
	var block_outside := AABB(Vector3(12, 5, 12), Vector3.ONE)
	_assert(player_aabb.intersects(block_inside), "overlap detected")
	_assert(not player_aabb.intersects(block_outside), "no overlap outside")


func _make_world() -> VoxelWorld:
	var world := VoxelWorld.new()
	var cr := Node3D.new()
	cr.name = "Chunks"
	world.add_child(cr)
	world.chunk_root = cr
	add_child(world)
	world.generate_flat_world()
	return world


func _test_world_serialize() -> void:
	var world := _make_world()
	await get_tree().process_frame
	var before := world.get_block(10, VoxelWorld.GROUND_Y, 10)
	_assert(before == BlockDB.get_id("grass"), "generated grass surface")
	world.set_block(10, VoxelWorld.GROUND_Y + 1, 10, BlockDB.get_id("wood"), true)
	_assert(world.get_block(10, VoxelWorld.GROUND_Y + 1, 10) == BlockDB.get_id("wood"), "placed wood")
	var data := world.serialize()
	_assert(data.has("chunks"), "serialize has chunks")
	world.set_block(10, VoxelWorld.GROUND_Y + 1, 10, 0, true)
	world.deserialize(data)
	_assert(world.get_block(10, VoxelWorld.GROUND_Y + 1, 10) == BlockDB.get_id("wood"), "deserialize restores wood")
	world.queue_free()
	await get_tree().process_frame


func _test_chunk_mesh_update() -> void:
	var world := _make_world()
	await get_tree().process_frame
	var key := world.world_to_chunk(5, VoxelWorld.GROUND_Y, 5)
	var chunk: VoxelChunk = world.chunks[key]
	world.set_block(5, VoxelWorld.GROUND_Y + 1, 5, BlockDB.get_id("stone"), true)
	_assert(chunk._mesh_instance.mesh != null, "mesh exists after edit")
	_assert(not chunk.dirty, "chunk rebuilt clears dirty")
	var faces: int = 0
	if chunk._collision.shape is ConcavePolygonShape3D:
		faces = (chunk._collision.shape as ConcavePolygonShape3D).get_faces().size()
	_assert(faces > 0, "collision faces present")
	world.queue_free()
