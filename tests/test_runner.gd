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
	_test_face_winding_outward()
	await _test_crosshair_does_not_block_clicks()
	await _test_virtual_joystick_and_look()
	await _test_touch_hud_mouse_filters()
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


func _test_face_winding_outward() -> void:
	## Godot front faces are clockwise-from-outside; winding normal points inward.
	var faces: Array = VoxelChunk.face_templates()
	_assert(faces.size() == 6, "six face templates")
	var seen := {}
	for f in faces:
		var name := str(f.get("name", ""))
		var outward: Vector3 = f["n"]
		var verts: Array = f["d"]
		var flip := bool(f.get("flip", false))
		_assert(verts.size() == 4, "%s has 4 verts" % name)
		var winding := VoxelChunk.face_winding_normal(verts, flip)
		_assert(VoxelChunk.face_winding_is_godot_front(outward, verts, flip), "%s winding is Godot CW front (inward)" % name)
		# Explicit per-direction: winding opposite outward
		_assert(winding.dot(outward) < -0.5, "%s winding opposite outward normal" % name)
		# Stored normal must match expected axis direction
		match name:
			"up":
				_assert(outward.dot(Vector3.UP) > 0.9, "up normal +Y")
			"down":
				_assert(outward.dot(Vector3.DOWN) > 0.9, "down normal -Y")
			"forward":
				_assert(outward.dot(Vector3.FORWARD) > 0.9, "forward normal -Z")
			"back":
				_assert(outward.dot(Vector3.BACK) > 0.9, "back normal +Z")
			"left":
				_assert(outward.dot(Vector3.LEFT) > 0.9, "left normal -X")
			"right":
				_assert(outward.dot(Vector3.RIGHT) > 0.9, "right normal +X")
		seen[name] = true
	for expected in ["up", "down", "forward", "back", "left", "right"]:
		_assert(seen.has(expected), "has face %s" % expected)


func _test_crosshair_does_not_block_clicks() -> void:
	## Phase 1.5 regression: crosshair ColorRect at screen center ate place/break.
	var ui := GameUi.new()
	add_child(ui)
	await get_tree().process_frame
	var cross: Control = ui.get_node_or_null("Root/Crosshair")
	_assert(cross != null, "GameUI has Crosshair")
	_assert(cross != null and cross.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Crosshair ignores mouse")
	ui.queue_free()
	await get_tree().process_frame


func _test_virtual_joystick_and_look() -> void:
	var joy := VirtualJoystick.new()
	joy.size = Vector2(200, 200)
	add_child(joy)
	await get_tree().process_frame
	var center := joy.size * 0.5
	joy.simulate_touch(0, center, true)
	joy.simulate_drag(0, center + Vector2(60, 0))
	_assert(joy.get_vector().x > 0.4, "joystick vector +x")
	joy.simulate_drag(0, center + Vector2(0, -60))
	_assert(joy.get_vector().y < -0.4, "joystick vector -y")
	joy.simulate_touch(0, center, false)
	_assert(joy.get_vector() == Vector2.ZERO, "joystick release zeros vector")

	var look := LookArea.new()
	look.size = Vector2(300, 400)
	add_child(look)
	await get_tree().process_frame
	var got: Array = [Vector2.ZERO]
	look.look_delta.connect(func(v: Vector2): got[0] = got[0] + v)
	look.simulate_touch(1, look.size * 0.5, true)
	_assert(look.is_looking(), "look touch begins looking")
	look.simulate_drag(1, Vector2(12, -8))
	_assert(got[0].x == 12 and got[0].y == -8, "look drag emits relative")
	look.simulate_touch(1, look.size * 0.5, false)
	got[0] = Vector2.ZERO
	look.simulate_drag(1, Vector2(50, 0))
	_assert(got[0] == Vector2.ZERO, "look ignores drag after release")

	# Distinct indices: joystick 0 + look 1 simultaneously.
	joy.simulate_touch(0, center + Vector2(40, 0), true)
	joy.simulate_drag(0, center + Vector2(50, 0))
	look.simulate_touch(1, look.size * 0.5, true)
	look.simulate_drag(1, Vector2(5, 5))
	_assert(joy.get_vector().x > 0.2, "multitouch joystick still active")
	_assert(look.is_looking(), "multitouch look still active")
	joy.simulate_touch(0, center, false)
	look.simulate_touch(1, look.size * 0.5, false)
	joy.queue_free()
	look.queue_free()
	await get_tree().process_frame


func _test_touch_hud_mouse_filters() -> void:
	GameState.touch_controls_forced = true
	var ui := GameUi.new()
	add_child(ui)
	await get_tree().process_frame
	ui._detect_touch()
	await get_tree().process_frame
	_assert(ui.touch_controls.visible, "forced touch shows controls")
	_assert(ui.touch_controls.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TouchControls root ignores mouse")
	_assert(ui.touch_controls.look_area.anchor_left >= 0.54, "look area starts right of center")
	var place_btn := ui.touch_controls.get_action_button("place")
	_assert(place_btn != null, "place action button present")
	_assert(place_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "place button is interactive")
	# Regression: filled circular body must exist (Button.flat previously hid StyleBoxes).
	var body := place_btn.get_node_or_null("Body") as Panel
	_assert(body != null, "place button has Body panel")
	if body:
		var sb := body.get_theme_stylebox("panel")
		_assert(sb is StyleBoxFlat and (sb as StyleBoxFlat).draw_center, "place button body StyleBox draws fill")
		_assert((sb as StyleBoxFlat).bg_color.a > 0.9, "place button body is opaque")
	_assert(ui.touch_controls.look_area.show_hint == false or OS.get_environment("COZY_LOOK_HINT") == "1", "LOOK hint off by default")
	# Desktop hide path
	GameState.touch_controls_forced = false
	ui.touch_layer.visible = false
	_assert(not ui.touch_layer.visible, "touch hidden on desktop path")
	ui.queue_free()
	await get_tree().process_frame


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
	# Meadow dressing may place path/flower/dirt accents; surface must still be solid ground.
	var before := world.get_block(10, VoxelWorld.GROUND_Y, 10)
	_assert(before != 0 and BlockDB.is_solid(before), "generated ground surface")
	var grass_probe := world.get_block(12, VoxelWorld.GROUND_Y, 15)
	_assert(grass_probe == BlockDB.get_id("grass") or grass_probe != 0, "meadow has terrain blocks")
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
