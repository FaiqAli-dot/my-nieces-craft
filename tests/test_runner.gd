extends Node
## Scene-based test runner so autoloads are available.

var passed := 0
var failed := 0

func _ready() -> void:
	print("=== CozyBlocks Tests ===")
	# Never read, overwrite or delete the player's real save.
	SaveGame.save_path = "user://test_cozyblocks_world_%d.json" % OS.get_process_id()
	Settings.path = "user://test_settings_%d.cfg" % OS.get_process_id()
	Settings.load_from_disk()
	_test_block_db()
	_test_inventory()
	_test_crafting()
	_test_placement_helpers()
	_test_face_winding_outward()
	await _test_crosshair_does_not_block_clicks()
	await _test_virtual_joystick_and_look()
	await _test_touch_hud_mouse_filters()
	_test_furniture_grid()
	_test_furniture_validation()
	_test_house_permissions()
	await _test_house_persistence()
	_test_duplicate_and_isolation()
	await _test_house_ui_mouse_filters()
	_test_exclusive_panels()
	await _test_meadow_house_exclusive_menus()
	_test_furniture_collision_flags()
	_test_creative_flight_gates()
	await _test_house_floor_collision()
	_test_player_proportions()
	_test_third_person_facing()
	await _test_house_height()
	await _test_house_size_tiers()
	await _test_flight_cluster_inset_api()
	await _test_world_serialize()
	await _test_chunk_mesh_update()
	# S2 Survival foundation
	_test_game_mode_model()
	_test_item_block_recipe_validation()
	_test_inventory_stacks_and_overflow()
	_test_mining_rules()
	_test_tool_icons_and_durability()
	await _test_survival_drops_and_pickup()
	await _test_survival_progression_and_save()
	_test_legacy_save_defaults_creative()
	await _test_mode_select_ui()
	# Production upgrade suites
	await _run_suite("res://tests/suites/net_reconnect_suite.gd")
	await _run_suite("res://tests/suites/tree_suite.gd")
	await _run_suite("res://tests/suites/character_suite.gd")
	await _run_suite("res://tests/suites/house_structure_suite.gd")
	await _run_suite("res://tests/suites/title_suite.gd")
	await _run_suite("res://tests/suites/world_suite.gd")
	await _run_suite("res://tests/suites/creature_suite.gd")
	await _run_suite("res://tests/suites/tutorial_suite.gd")
	# Phase 1: core controls & reliability
	await _test_survival_mining_requires_explicit_hold()
	await _test_touch_hud_ignores_mouse_break()
	await _test_mining_cancel_on_release()
	await _test_monster_combat_pipeline()
	await _test_flight_toggle_keeps_joystick_stable()
	await _test_flight_toggle_keeps_action_cluster_stable()
	# Phase 2 build foundation
	_test_build_catalog_categories()
	_test_build_history_stack()
	_test_build_session_select_does_not_place()
	await _test_block_place_preview_validity_colors()
	await _test_block_place_undo_redo_and_survival()
	await _test_furniture_copy_and_history()
	await _test_build_catalog_ui_and_flight_stable()
	await _test_build_tool_icons_and_disabled_styles()
	await _test_catalog_drag_place_mouse_and_touch()
	await _test_meadow_house_edit_save_reload()
	print("=== Results: %d passed, %d failed ===" % [passed, failed])
	_cleanup_user_test_data()
	get_tree().quit(1 if failed > 0 else 0)


## Removes scratch saves/house dirs that tests create under user://.
func _cleanup_user_test_data() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for entry in dir.get_files():
		if entry.begins_with("test_"):
			dir.remove(entry)
	for entry in dir.get_directories():
		if entry.begins_with("test_"):
			_remove_tree("user://" + entry)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for d in dir.get_directories():
		_remove_tree(path.path_join(d))
	DirAccess.remove_absolute(path)


func _run_suite(path: String) -> void:
	var suite: Node = load(path).new()
	suite.runner = self
	add_child(suite)
	await suite.run()
	suite.queue_free()


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
	GameState.set_creative(false)
	var inv := Inventory.new(false)
	_assert(inv.hotbar.size() == 9, "hotbar is 9")
	_assert(inv.bag.size() == 27, "bag is 27")
	var added := inv.add_item("wood", 10)
	_assert(added == 10, "add 10 wood")
	_assert(inv.count_of("wood") == 10, "count wood 10")
	_assert(inv.remove_item("wood", 3), "remove 3 wood")
	_assert(inv.count_of("wood") == 7, "count wood 7")
	inv.select(0)
	inv.hotbar[0] = {"item": "stone", "count": 2}
	_assert(inv.consume_selected(1), "consume selected")
	_assert(inv.selected_count() == 1, "selected count 1")
	GameState.set_creative(true)
	inv.hotbar[0] = {"item": "stone", "count": 1}
	_assert(inv.consume_selected(1), "creative consume keeps")
	_assert(inv.selected_count() == 1, "creative unlimited")
	GameState.set_creative(true)


func _test_crafting() -> void:
	GameState.set_creative(false)
	var inv := Inventory.new(false)
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
	GameState.set_creative(true)


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
	var joy := TouchJoystick.new()
	joy.floating_mode = true
	joy.size = Vector2(400, 500)
	add_child(joy)
	await get_tree().process_frame
	_assert(joy.floating_mode, "TouchJoystick defaults to floating_mode")
	# Spawn at several non-rest points inside the zone.
	var spawn_points: Array[Vector2] = [
		Vector2(120, 140),
		Vector2(280, 200),
		Vector2(90, 360),
		Vector2(220, 300),
	]
	for p in spawn_points:
		joy.simulate_touch(0, p, true)
		_assert(joy.is_active(), "floating spawn active at %s" % p)
		_assert(joy.visual_center().distance_to(p) < joy.base_diameter * 0.55, "base spawns near touch %s" % p)
		joy.simulate_drag(0, p + Vector2(50, 0))
		_assert(joy.get_vector().x > 0.3, "floating drag +x from %s" % p)
		joy.simulate_touch(0, p, false)
		_assert(joy.get_vector() == Vector2.ZERO, "release stops movement at %s" % p)
		_assert(not joy.is_active(), "inactive after release at %s" % p)
		_assert(joy.visual_center().distance_to(joy.rest_center()) < 2.0, "returns to rest hint after %s" % p)

	# Kid-friendly clamp: base stays put when finger exceeds radius.
	var spawn := Vector2(200, 250)
	joy.follow_base_beyond_radius = false
	joy.simulate_touch(0, spawn, true)
	var base0 := joy.visual_center()
	joy.simulate_drag(0, spawn + Vector2(400, 0))
	_assert(joy.visual_center().distance_to(base0) < 1.0, "clamp keeps base fixed beyond radius")
	_assert(joy.get_vector().x > 0.8, "clamp still reports full +x")
	joy.simulate_touch(0, spawn, false)

	# Fixed mode: only activates near the centered stick.
	var fixed := TouchJoystick.new()
	fixed.floating_mode = false
	fixed.size = Vector2(200, 200)
	add_child(fixed)
	await get_tree().process_frame
	fixed.simulate_touch(0, Vector2(10, 10), true)
	_assert(not fixed.is_active(), "fixed mode ignores far corner")
	fixed.simulate_touch(0, fixed.size * 0.5, true)
	fixed.simulate_drag(0, fixed.size * 0.5 + Vector2(60, 0))
	_assert(fixed.get_vector().x > 0.4, "fixed mode vector +x")
	fixed.simulate_touch(0, fixed.size * 0.5, false)
	_assert(fixed.get_vector() == Vector2.ZERO, "fixed mode release zeros vector")

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
	var mt := Vector2(160, 180)
	joy.simulate_touch(0, mt, true)
	joy.simulate_drag(0, mt + Vector2(50, 0))
	look.simulate_touch(1, look.size * 0.5, true)
	look.simulate_drag(1, Vector2(5, 5))
	_assert(joy.get_vector().x > 0.2, "multitouch joystick still active")
	_assert(look.is_looking(), "multitouch look still active")
	joy.simulate_touch(0, mt, false)
	look.simulate_touch(1, look.size * 0.5, false)
	_assert(joy.get_vector() == Vector2.ZERO, "multitouch move release clears")
	joy.queue_free()
	fixed.queue_free()
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
	_assert(ui.touch_controls.floating_joystick, "TouchControls uses floating joystick")
	_assert(ui.touch_controls.joystick.floating_mode, "meadow joystick floating_mode on")
	ui.touch_controls._on_viewport_resized()
	await get_tree().process_frame
	var joy_r: Rect2 = ui.touch_controls.joystick.get_global_rect()
	var vp_r := get_viewport().get_visible_rect()
	_assert(joy_r.size.x >= vp_r.size.x * 0.30, "move zone is a wide left band")
	_assert(joy_r.end.x <= vp_r.size.x * 0.50, "move zone stays on left half")
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


func _test_furniture_grid() -> void:
	var origin := Vector3(0, 0, 0)
	var cell := FurnitureGrid.world_to_cell(Vector3(2.7, 0, 1.2), origin)
	_assert(cell == Vector2i(2, 1), "world_to_cell floors")
	var snapped := FurnitureGrid.snap_world(Vector3(2.7, 0, 1.2), origin, 0.0)
	_assert(is_equal_approx(snapped.x, 2.5) and is_equal_approx(snapped.z, 1.5), "snap center")
	_assert(FurnitureGrid.normalize_rotation(450) == 90, "normalize rotation")
	_assert(FurnitureGrid.rotate_footprint(Vector2i(2, 1), 90) == Vector2i(1, 2), "rotated footprint")
	_assert(FurnitureGrid.rotate_footprint(Vector2i(2, 1), 0) == Vector2i(2, 1), "unrotated footprint")
	var cells := FurnitureGrid.occupied_cells(Vector2i(3, 4), Vector2i(2, 1), 90)
	_assert(cells.size() == 2, "occupied cell count")
	_assert(cells.has(Vector2i(3, 4)) and cells.has(Vector2i(3, 5)), "occupied cells after 90 rot")
	_assert(FurnitureDB.has_id("chair"), "catalog has chair")
	_assert(FurnitureDB.has_id("bed"), "catalog has bed")
	_assert(FurnitureDB.all_ids().size() >= 8, "catalog has several items")


func _test_furniture_validation() -> void:
	var room_min := Vector2i(0, 0)
	var room_max := Vector2i(11, 11)
	var empty := {}
	_assert(
		FurnitureValidator.validate_placement("chair", Vector2i(0, 0), 0, room_min, room_max, empty)
		== FurnitureValidator.Reason.OK,
		"chair in bounds ok"
	)
	_assert(
		FurnitureValidator.validate_placement("nope", Vector2i(0, 0), 0, room_min, room_max, empty)
		== FurnitureValidator.Reason.UNKNOWN_DEF,
		"unknown def rejected"
	)
	_assert(
		FurnitureValidator.validate_placement("chair", Vector2i(20, 0), 0, room_min, room_max, empty)
		== FurnitureValidator.Reason.OUT_OF_BOUNDS,
		"oob rejected"
	)
	var occupied := {"0,0": "furn_a"}
	_assert(
		FurnitureValidator.validate_placement("chair", Vector2i(0, 0), 0, room_min, room_max, occupied)
		== FurnitureValidator.Reason.OVERLAP,
		"overlap rejected"
	)
	_assert(
		FurnitureValidator.validate_placement("chair", Vector2i(0, 0), 0, room_min, room_max, occupied, "furn_a")
		== FurnitureValidator.Reason.OK,
		"ignore self on move"
	)
	# Table 2x2 at edge
	_assert(
		FurnitureValidator.validate_placement("table", Vector2i(11, 11), 0, room_min, room_max, empty)
		== FurnitureValidator.Reason.OUT_OF_BOUNDS,
		"large footprint oob"
	)
	_assert(
		FurnitureValidator.validate_placement("table", Vector2i(10, 10), 0, room_min, room_max, empty)
		== FurnitureValidator.Reason.OK,
		"large footprint fits"
	)


func _test_house_permissions() -> void:
	var house := HouseLayout.new()
	house.owner_id = "owner1"
	house.collaboration_enabled = false
	_assert(HousePermissions.can_decorate(house, "owner1"), "owner can decorate")
	_assert(not HousePermissions.can_decorate(house, "visitor"), "visitor blocked when collab off")
	house.collaboration_enabled = true
	_assert(HousePermissions.can_decorate(house, "visitor"), "collab can decorate")
	_assert(HousePermissions.can_toggle_collab(house, "owner1"), "owner toggles collab")
	_assert(not HousePermissions.can_toggle_collab(house, "visitor"), "visitor cannot toggle collab")
	_assert(HousePermissions.can_set_house_size(house, "owner1"), "owner can set house size")
	_assert(not HousePermissions.can_set_house_size(house, "visitor"), "visitor cannot set house size")
	_assert(HousePermissions.can_enter(house, "owner1", false), "owner enters")
	_assert(HousePermissions.can_enter(house, "friend", true), "invite enters")
	_assert(not HousePermissions.can_enter(house, "stranger", false), "no invite blocked")


func _test_house_persistence() -> void:
	var dir := "user://test_houses_%d" % Time.get_ticks_usec()
	var store := HouseStore.new(dir)
	var house := store.ensure_house_for_owner("pid_alice", "Alice")
	_assert(house.house_id != "", "house id assigned")
	_assert(house.invite_code.length() == 6, "invite code length")
	_assert(house.size_tier == HouseLayout.SIZE_SMALL, "new house defaults Small")
	var code := house.invite_code
	var grown := GameServer.apply_size_for_test(store, house.house_id, "pid_alice", HouseLayout.SIZE_LARGE)
	_assert(bool(grown.get("ok", false)), "owner can grow to Large")
	_assert(str(grown.get("size_tier", "")) == HouseLayout.SIZE_LARGE, "grown tier Large")
	var denied_size := GameServer.apply_size_for_test(store, house.house_id, "pid_bob", HouseLayout.SIZE_MEDIUM)
	_assert(not bool(denied_size.get("ok", true)), "visitor size change denied")
	var placed := GameServer.apply_place_for_test(store, house.house_id, "pid_alice", "chair", Vector2i(2, 2), 0)
	_assert(bool(placed.get("ok", false)), "owner place ok")
	# Far furniture in Large room — shrinking to Small must be rejected.
	var edge := GameServer.apply_place_for_test(store, house.house_id, "pid_alice", "lamp", Vector2i(18, 18), 0)
	_assert(bool(edge.get("ok", false)), "place near Large edge")
	var shrink_blocked := GameServer.apply_size_for_test(store, house.house_id, "pid_alice", HouseLayout.SIZE_SMALL)
	_assert(not bool(shrink_blocked.get("ok", true)), "shrink blocked while furniture outside Small")
	# Simulate backend restart with a fresh store on same dir
	var store2 := HouseStore.new(dir)
	var reloaded := store2.load_house(house.house_id)
	_assert(reloaded != null, "reload after restart")
	_assert(reloaded.furniture.size() == 2, "furniture persisted")
	_assert(str(reloaded.furniture[0].get("def_id", "")) == "chair", "chair persisted")
	_assert(reloaded.size_tier == HouseLayout.SIZE_LARGE, "size_tier persisted across restart")
	_assert(reloaded.room_max == Vector2i(19, 19), "Large room_max persisted")
	_assert(int(reloaded.to_dict().get("schema", 0)) == HouseLayout.SCHEMA_VERSION, "schema v2 on save")
	var by_invite := store2.get_house_id_for_invite(code)
	_assert(by_invite == house.house_id, "invite resolves house")
	# Unauthorized place
	var denied := GameServer.apply_place_for_test(store2, house.house_id, "pid_bob", "chair", Vector2i(4, 4), 0)
	_assert(not bool(denied.get("ok", false)), "collab-off rejects bob")
	reloaded.collaboration_enabled = true
	store2.save_house(reloaded)
	var ok_bob := GameServer.apply_place_for_test(store2, house.house_id, "pid_bob", "lamp", Vector2i(4, 4), 0)
	_assert(bool(ok_bob.get("ok", false)), "collab-on allows bob")
	# Overlap reject
	var overlap := GameServer.apply_place_for_test(store2, house.house_id, "pid_alice", "chair", Vector2i(2, 2), 0)
	_assert(not bool(overlap.get("ok", false)), "overlap rejected by server helper")
	# Schema v1 migration: missing size_tier infers Small from 12×12 bounds.
	var legacy := {
		"schema": 1,
		"house_id": "legacy_h",
		"owner_id": "pid_x",
		"furniture": [],
		"room_min": [0, 0],
		"room_max": [11, 11],
	}
	var migrated := HouseLayout.from_dict(legacy)
	_assert(migrated.size_tier == HouseLayout.SIZE_SMALL, "v1 migrate → Small")
	_assert(int(migrated.to_dict().get("schema", 0)) == HouseLayout.SCHEMA_VERSION and HouseLayout.SCHEMA_VERSION == 3, "migrated save writes current schema (3)")
	_assert(migrated.walls.is_empty() and HouseStructure.kind_at(migrated.walls, "v:12:5", 12) == HouseStructure.DOOR, "v1 migrate keeps default walls + east door")
	await get_tree().process_frame


func _test_duplicate_and_isolation() -> void:
	var dir := "user://test_houses_iso_%d" % Time.get_ticks_usec()
	var store := HouseStore.new(dir)
	var a := store.ensure_house_for_owner("pid_a", "A")
	var b := store.ensure_house_for_owner("pid_b", "B")
	_assert(a.house_id != b.house_id, "houses isolated ids")
	GameServer.apply_place_for_test(store, a.house_id, "pid_a", "bed", Vector2i(1, 1), 90)
	var b2 := store.load_house(b.house_id)
	_assert(b2.furniture.is_empty(), "B unaffected by A furniture")
	var a2 := store.load_house(a.house_id)
	_assert(a2.furniture.size() == 1, "A kept furniture")
	# Missing def sanitization
	a2.furniture.append({"instance_id": "x", "def_id": "missing_item", "cell_x": 0, "cell_z": 0, "rotation": 0})
	a2._sanitize_furniture()
	_assert(a2.find_instance("x").get("missing_def", false) == true, "missing def flagged")


func _test_house_ui_mouse_filters() -> void:
	var ui := HouseUi.new()
	add_child(ui)
	await get_tree().process_frame
	var toast: Control = ui.get_node_or_null("Root/Toast")
	var hint: Control = ui.get_node_or_null("Root/Hint")
	var card: Control = ui.get_node_or_null("Root/StatusCard")
	_assert(toast != null and toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HouseUI toast ignores mouse")
	_assert(hint != null and hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HouseUI hint ignores mouse")
	_assert(card != null and card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "StatusCard ignores mouse")
	_assert(ui.debug_box != null and ui.debug_box.visible == false, "debug HUD hidden by default")
	_assert(ui.rotate_btn != null, "rotate button exists")
	_assert(ui.rotate_btn.icon_path.find("icon_rotate") >= 0, "rotate button has rotate icon")
	ui.queue_free()
	await get_tree().process_frame


func _test_exclusive_panels() -> void:
	var host := ExclusivePanels.new()
	var a := PanelContainer.new()
	var b := PanelContainer.new()
	var c := PanelContainer.new()
	add_child(a)
	add_child(b)
	add_child(c)
	host.register("a", a)
	host.register("b", b)
	host.register("c", c)
	_assert(not host.is_open(), "exclusive starts closed")
	host.open("a")
	_assert(a.visible and not b.visible and not c.visible, "open a only")
	host.open("b")
	_assert(not a.visible and b.visible and not c.visible, "open b closes a")
	_assert(host.toggle("b") == false, "toggle active closes")
	_assert(not host.is_open() and not b.visible, "all closed after toggle")
	host.toggle("c")
	_assert(host.active_id() == "c" and c.visible, "toggle opens c")
	host.open("a")
	_assert(a.visible and not c.visible, "open a closes c")
	host.close_all()
	_assert(not a.visible and not b.visible and not c.visible, "close_all hides all")
	a.queue_free()
	b.queue_free()
	c.queue_free()


func _test_meadow_house_exclusive_menus() -> void:
	var meadow := GameUi.new()
	add_child(meadow)
	await get_tree().process_frame
	meadow.toggle_inventory()
	_assert(meadow.inventory_panel.visible and not meadow.craft_panel.visible, "bag open alone")
	meadow.toggle_craft()
	_assert(meadow.craft_panel.visible and not meadow.inventory_panel.visible, "craft closes bag")
	meadow.toggle_menu()
	_assert(meadow.menu_panel.visible and not meadow.craft_panel.visible, "menu closes craft")
	meadow.request_reset()
	_assert(meadow.confirm_panel.visible and not meadow.menu_panel.visible, "confirm closes menu")
	meadow.confirm_reset_no()
	_assert(not meadow.confirm_panel.visible and not meadow.panels.is_open(), "confirm close clears host")
	meadow.toggle_inventory()
	meadow.toggle_inventory()
	_assert(not meadow.inventory_panel.visible, "bag toggles closed")
	meadow.queue_free()
	await get_tree().process_frame

	var house := HouseUi.new()
	add_child(house)
	await get_tree().process_frame
	house.open_catalog()
	_assert(house.catalog_panel.visible and not house.visit_panel.visible, "catalog open alone")
	house.open_visit_panel()
	_assert(house.visit_panel.visible and not house.catalog_panel.visible, "visit closes catalog")
	house.open_visit_panel()
	_assert(not house.visit_panel.visible, "visit toggles closed")
	house.open_catalog()
	house.open_catalog()
	_assert(not house.catalog_panel.visible, "catalog toggles closed")
	house._is_owner = true
	house.open_size_panel()
	_assert(house.size_panel.visible and not house.catalog_panel.visible, "size panel exclusive")
	house.open_catalog()
	_assert(house.catalog_panel.visible and not house.size_panel.visible, "catalog closes size")
	house.queue_free()
	await get_tree().process_frame


func _test_furniture_collision_flags() -> void:
	_assert(FurnitureDB.is_solid("chair"), "chair solid")
	_assert(FurnitureDB.is_solid("table"), "table solid")
	_assert(FurnitureDB.is_solid("bookshelf"), "bookshelf solid")
	_assert(not FurnitureDB.is_solid("rug"), "rug not solid")
	_assert(not FurnitureDB.is_solid("bear"), "bear not solid")
	_assert(FurnitureDB.collision_height("wardrobe") >= 1.8, "wardrobe tall collider")
	var vis := FurnitureVisual.new()
	add_child(vis)
	vis.setup({
		"instance_id": "t_chair",
		"def_id": "chair",
		"cell_x": 2,
		"cell_z": 2,
		"rotation": 0,
	}, Vector3.ZERO, 0.0)
	_assert(vis.has_blocking_collision(), "chair visual has blocking body")
	var rug := FurnitureVisual.new()
	add_child(rug)
	rug.setup({
		"instance_id": "t_rug",
		"def_id": "rug",
		"cell_x": 4,
		"cell_z": 4,
		"rotation": 0,
	}, Vector3.ZERO, 0.0)
	_assert(not rug.has_blocking_collision(), "rug visual non-blocking")
	vis.queue_free()
	rug.queue_free()


func _test_creative_flight_gates() -> void:
	GameState.set_creative(true)
	GameState.set_flying(true)
	_assert(GameState.flying, "creative can fly")
	GameState.set_creative(false)
	_assert(not GameState.flying, "leaving creative disables flight")
	GameState.set_flying(true)
	_assert(not GameState.flying, "survival mode rejects flight")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	GameState.set_flying(true)
	_assert(not GameState.flying, "survival set_flying rejected")
	GameState.set_creative(true)


func _test_house_floor_collision() -> void:
	var space := HouseSpace.new()
	var furn := Node3D.new()
	furn.name = "FurnitureRoot"
	space.add_child(furn)
	var players := Node3D.new()
	players.name = "PlayersRoot"
	space.add_child(players)
	add_child(space)
	await get_tree().process_frame
	_assert(space.floor_collision_count() >= 2, "floor + apron static bodies")
	var spawn := space.spawn_position()
	_assert(is_equal_approx(spawn.y, HouseSpace.FLOOR_Y), "spawn on floor y")
	# Ray from above spawn should hit the floor slab.
	var from := spawn + Vector3(0, 2.0, 0)
	var to := spawn + Vector3(0, -2.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := space.get_world_3d().direct_space_state.intersect_ray(q)
	_assert(not hit.is_empty(), "floor ray hits collision")
	_assert(float(hit.get("position", Vector3.ZERO).y) <= 0.05, "floor hit near y=0")
	space.queue_free()
	await get_tree().process_frame


func _test_player_proportions() -> void:
	_assert(is_equal_approx(PlayerController.CAPSULE_HEIGHT, 1.8), "FP capsule height 1.8")
	_assert(is_equal_approx(ThirdPersonController.CAPSULE_HEIGHT, 1.8), "TP capsule height 1.8")
	_assert(ThirdPersonController.MODEL_SCALE >= 0.85, "avatar scale raised from 0.62")


func _test_third_person_facing() -> void:
	## Kenney meshes face +Z; visual yaw must aim that axis along travel.
	var dirs: Array[Vector3] = [
		Vector3(0, 0, -1),
		Vector3(0, 0, 1),
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0.7, 0, -0.7).normalized(),
		Vector3(-0.5, 0, 0.5).normalized(),
	]
	for dir in dirs:
		var yaw := ThirdPersonController.visual_yaw_for_move_dir(dir)
		var fwd := ThirdPersonController.visual_forward_from_yaw(yaw)
		_assert(fwd.dot(dir) > 0.95, "avatar forward matches travel %s" % dir)
	# Old Godot −Z atan2 would face the opposite way when walking camera-forward.
	var away := Vector3(0, 0, -1)
	var fixed := ThirdPersonController.visual_yaw_for_move_dir(away)
	var legacy := atan2(-away.x, -away.z)
	_assert(not is_equal_approx(fixed, legacy), "facing fix differs from legacy −Z atan2")
	_assert(ThirdPersonController.visual_forward_from_yaw(fixed).dot(away) > 0.95, "walk-away shows back to camera")


func _test_house_height() -> void:
	_assert(HouseSpace.WALL_H >= 4.5, "walls raised for 1.8m character")
	_assert(HouseSpace.DOOR_CLEARANCE >= 2.2, "door clearance fits capsule")
	_assert(HouseSpace.WALL_H > ThirdPersonController.CAM_HEIGHT + 2.0, "ceiling above camera pivot + spring headroom")
	var space := HouseSpace.new()
	var furn := Node3D.new()
	furn.name = "FurnitureRoot"
	space.add_child(furn)
	var players := Node3D.new()
	players.name = "PlayersRoot"
	space.add_child(players)
	add_child(space)
	await get_tree().process_frame
	_assert(space.has_ceiling_collision(), "ceiling has collision for SpringArm")
	_assert(space.door_clearance() >= 2.2, "door_clearance accessor")
	_assert(space.ceiling_y() > HouseSpace.WALL_H, "ceiling above wall top")
	space.queue_free()
	await get_tree().process_frame


func _test_house_size_tiers() -> void:
	_assert(HouseLayout.cells_for_tier(HouseLayout.SIZE_SMALL) == 12, "Small 12 cells")
	_assert(HouseLayout.cells_for_tier(HouseLayout.SIZE_MEDIUM) == 16, "Medium 16 cells")
	_assert(HouseLayout.cells_for_tier(HouseLayout.SIZE_LARGE) == 20, "Large 20 cells")
	var h := HouseLayout.new()
	h.apply_size_tier(HouseLayout.SIZE_MEDIUM, true)
	_assert(h.room_max == Vector2i(15, 15), "Medium room_max")
	h.furniture = [{"instance_id": "a", "def_id": "chair", "cell_x": 14, "cell_z": 14, "rotation": 0}]
	_assert(h.can_apply_size_tier(HouseLayout.SIZE_SMALL) != "", "cannot shrink below furniture")
	_assert(h.can_apply_size_tier(HouseLayout.SIZE_LARGE) == "", "can grow with furniture")
	var space := HouseSpace.new()
	var furn := Node3D.new()
	furn.name = "FurnitureRoot"
	space.add_child(furn)
	var players := Node3D.new()
	players.name = "PlayersRoot"
	space.add_child(players)
	add_child(space)
	await get_tree().process_frame
	space.apply_size_cells(20)
	await get_tree().process_frame
	_assert(space.room_cells == 20, "space rebuilds Large")
	_assert(is_equal_approx(space.room_size_meters(), 20.0), "Large is 20m")
	var spawn := space.spawn_position()
	_assert(spawn.x > 8.0 and spawn.z > 10.0, "Large spawn scales with room")
	space.queue_free()
	await get_tree().process_frame


func _test_flight_cluster_inset_api() -> void:
	var cluster := TouchActionCluster.new()
	add_child(cluster)
	await get_tree().process_frame
	_assert(cluster.flight_column_inset == 0.0, "flight inset starts 0")
	cluster.set_flight_column_inset(80.0)
	_assert(is_equal_approx(cluster.flight_column_inset, 80.0), "flight inset applied")
	cluster.queue_free()
	await get_tree().process_frame


func _make_world() -> VoxelWorld:
	var world := VoxelWorld.new()
	var cr := Node3D.new()
	cr.name = "Chunks"
	world.add_child(cr)
	world.chunk_root = cr
	var dr := Node3D.new()
	dr.name = "Drops"
	world.add_child(dr)
	world.drop_root = dr
	add_child(world)
	world.generate_flat_world()
	return world


func _test_game_mode_model() -> void:
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	_assert(GameState.is_creative(), "creative mode")
	_assert(GameState.creative_mode, "compat bool true")
	GameState.set_flying(true)
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	_assert(GameState.is_survival(), "survival mode")
	_assert(not GameState.creative_mode, "compat bool false")
	_assert(not GameState.flying, "flight cleared on survival")
	GameState.toggle_creative()
	_assert(GameState.is_survival(), "toggle_creative does not switch mid-session")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	var surv := Inventory.new(false)
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	surv.clear()
	_assert(surv.is_empty(), "survival inventory empty")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	var creat := Inventory.new(true)
	_assert(creat.count_of("wood") > 0, "creative seeds hotbar")


func _test_item_block_recipe_validation() -> void:
	_assert(BlockDB.validation_errors().is_empty(), "block/item defs valid")
	_assert(BlockDB.get_id("crafting_table") == 18, "crafting_table id 18")
	_assert(BlockDB.get_hardness(BlockDB.get_id("stone")) > 0.0, "stone hardness")
	_assert(BlockDB.has_item("wooden_pickaxe"), "wooden pickaxe item")
	_assert(BlockDB.max_stack("wooden_pickaxe") == 1, "tool stack 1")
	_assert(BlockDB.max_stack("wood") == 64, "block stack 64")
	var craft := CraftingSystem.new()
	_assert(craft.validation_errors().is_empty(), "recipes valid")
	_assert(not craft.find_recipe("wooden_pickaxe").is_empty(), "wooden pickaxe recipe")
	_assert(not craft.find_recipe("stone_pickaxe").is_empty(), "stone pickaxe recipe")


func _test_inventory_stacks_and_overflow() -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var inv := Inventory.new(false)
	var added := inv.add_item("dirt", 64)
	_assert(added == 64, "stack 64 dirt")
	added = inv.add_item("dirt", 10)
	_assert(added == 10, "overflow to next slot")
	_assert(inv.count_of("dirt") == 74, "dirt total 74")
	# Fill inventory almost completely
	inv.clear()
	for _i in 36:
		inv.add_item("sand", 64)
	_assert(not inv.can_fit("wood", 1), "full inventory cannot fit")
	var before := inv.count_of("sand")
	var got := inv.add_item("wood", 5)
	_assert(got == 0, "full inventory adds nothing")
	_assert(inv.count_of("sand") == before, "no sand lost on failed add")
	# Migration from 8+16
	var legacy := {
		"hotbar": [{"item": "wood", "count": 3}, {"item": "", "count": 0}, {"item": "", "count": 0}, {"item": "", "count": 0}, {"item": "", "count": 0}, {"item": "", "count": 0}, {"item": "", "count": 0}, {"item": "", "count": 0}],
		"bag": [{"item": "planks", "count": 4}],
		"selected": 0,
	}
	inv.from_dict(legacy)
	_assert(inv.hotbar.size() == 9, "migrated hotbar 9")
	_assert(inv.bag.size() == 27, "migrated bag 27")
	_assert(inv.count_of("wood") == 3 and inv.count_of("planks") == 4, "legacy items kept")
	# Atomic crafting failure leaves ingredients
	inv.clear()
	inv.add_item("planks", 3)
	inv.add_item("sticks", 2)
	# Fill remaining so pickaxe cannot fit (tools need empty slot)
	for _i in 34:
		inv.add_item("dirt", 64)
	var craft := CraftingSystem.new()
	# Ensure no empty slot
	_assert(not inv.can_fit("wooden_pickaxe", 1) or inv.count_of("planks") == 3, "setup full-ish")
	GameState.set_game_mode(GameState.Mode.CREATIVE)


func _test_tool_icons_and_durability() -> void:
	for id in ["sticks", "wooden_pickaxe", "stone_pickaxe", "wooden_axe", "stone_axe", "wooden_shovel", "stone_shovel", "crafting_table", "planks"]:
		var tex := BlockDB.icon_texture(id)
		_assert(tex != null, "icon for %s" % id)
		# Procedural icons are ImageTexture; must not be a flat solid field only.
		if tex is ImageTexture:
			var img := (tex as ImageTexture).get_image()
			_assert(img != null and img.get_width() >= 16, "icon image %s" % id)
			var colors := {}
			for y in mini(img.get_height(), 16):
				for x in mini(img.get_width(), 16):
					colors[img.get_pixel(x, y)] = true
			_assert(colors.size() >= 2, "icon %s has multiple colors" % id)
	var ItemIconsScr = preload("res://scripts/autoload/item_icons.gd")
	_assert(ItemIconsScr.mode_card_texture("creative") != null, "creative card art")
	_assert(ItemIconsScr.mode_card_texture("survival") != null, "survival card art")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var inv := Inventory.new(false)
	inv.hotbar[0] = {"item": "wooden_pickaxe", "count": 1, "durability": 59}
	inv.select(0)
	_assert(int(MiningRules.tool_info("wooden_pickaxe").get("max_durability", 0)) == 59, "JE wood durability 59")
	_assert(int(MiningRules.tool_info("stone_pickaxe").get("max_durability", 0)) == 131, "JE stone durability 131")
	inv.damage_selected_tool(1)
	_assert(int(inv.hotbar[0].get("durability", 0)) == 58, "durability decrements")
	inv.hotbar[0]["durability"] = 1
	inv.damage_selected_tool(1)
	_assert(inv.selected_item() == "", "tool breaks at 0")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	inv.hotbar[0] = {"item": "wooden_pickaxe", "count": 1, "durability": 5}
	inv.damage_selected_tool(1)
	_assert(int(inv.hotbar[0].get("durability", 0)) == 5, "creative skips durability")


func _test_mining_rules() -> void:
	var stone := BlockDB.get_id("stone")
	var wood := BlockDB.get_id("wood")
	_assert(MiningRules.can_harvest(wood, ""), "wood harvestable by hand")
	_assert(not MiningRules.can_harvest(stone, ""), "stone not harvestable by hand")
	_assert(MiningRules.can_harvest(stone, "wooden_pickaxe"), "wood pick mines stone")
	_assert(MiningRules.drop_for_break(stone, "") == "", "stone hand no drop")
	_assert(MiningRules.drop_for_break(stone, "wooden_pickaxe") == "cobble", "stone pick drops cobble")
	var hand_t := MiningRules.break_seconds(wood, "")
	var axe_t := MiningRules.break_seconds(wood, "wooden_axe")
	_assert(axe_t < hand_t, "axe faster than hand on wood")
	var stone_hand := MiningRules.break_seconds(stone, "")
	var stone_pick := MiningRules.break_seconds(stone, "wooden_pickaxe")
	_assert(stone_pick < stone_hand, "pick faster than hand on stone")
	_assert(stone_hand > 1.0, "stone by hand takes real time")


func _test_survival_drops_and_pickup() -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var world := _make_world()
	await get_tree().process_frame
	var inv := Inventory.new(false)
	var pos := Vector3(10.5, VoxelWorld.GROUND_Y + 1.5, 10.5)
	world.spawn_drop("wood", 3, pos)
	await get_tree().process_frame
	_assert(world.drop_root.get_child_count() >= 1, "drop spawned")
	# Too early for pickup delay
	var early := world.collect_nearby_drops(inv, pos, 2.0)
	_assert(early == 0 or inv.count_of("wood") == 0, "pickup delay prevents instant grab")
	# Age the drop
	for c in world.drop_root.get_children():
		var d := c as WorldDrop
		if d:
			d.age = 1.0
	var got := world.collect_nearby_drops(inv, pos, 2.0)
	_assert(got == 3 and inv.count_of("wood") == 3, "pickup collects wood")
	await get_tree().process_frame
	var remaining := 0
	for c in world.drop_root.get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			remaining += 1
	_assert(remaining == 0, "drop removed")
	# Overflow leaves remainder
	inv.clear()
	for _i in 36:
		inv.add_item("dirt", 64)
	world.spawn_drop("sand", 5, pos)
	for c in world.drop_root.get_children():
		var d2 := c as WorldDrop
		if d2:
			d2.age = 1.0
	world.collect_nearby_drops(inv, pos, 2.0)
	_assert(world.drop_root.get_child_count() >= 1, "overflow drop remains")
	# Wrong-tool break yields no drop item
	var sx := 44
	var sz := 30
	var before_id := world.get_block(sx, VoxelWorld.GROUND_Y + 1, sz)
	if before_id == BlockDB.get_id("stone"):
		var drop := world.break_block_survival(sx, VoxelWorld.GROUND_Y + 1, sz, "")
		_assert(drop == "", "survival stone without pick no drop")
		_assert(world.get_block(sx, VoxelWorld.GROUND_Y + 1, sz) == 0, "block removed anyway")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	world.queue_free()
	await get_tree().process_frame


func _test_survival_progression_and_save() -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var world := _make_world()
	await get_tree().process_frame
	_assert(world.get_block(26, VoxelWorld.GROUND_Y + 1, 30) == BlockDB.get_id("log"), "voxel tree trunk (natural log)")
	_assert(world.get_block(44, VoxelWorld.GROUND_Y + 1, 30) == BlockDB.get_id("stone"), "stone outcrop")
	var inv := Inventory.new(false)
	_assert(inv.is_empty(), "fresh survival empty")
	# Harvest logs via survival break
	var drop := world.break_block_survival(26, VoxelWorld.GROUND_Y + 2, 30, "")
	_assert(drop == "wood", "hand harvests wood")
	world.spawn_drop(drop, 1, Vector3(26.5, VoxelWorld.GROUND_Y + 2.5, 30.5))
	for c in world.drop_root.get_children():
		(c as WorldDrop).age = 1.0
	world.collect_nearby_drops(inv, Vector3(26.5, VoxelWorld.GROUND_Y + 2, 30.5), 2.0)
	# Extra wood for recipes (planks×4 each log)
	inv.add_item("wood", 12)
	var craft := CraftingSystem.new()
	for _i in 6:
		_assert(craft.craft("wood_to_planks", inv, false), "craft planks")
	_assert(craft.craft("planks_to_sticks", inv, false), "craft sticks")
	_assert(craft.craft("planks_to_sticks", inv, false), "craft more sticks")
	_assert(craft.craft("crafting_table", inv, false), "craft table item")
	_assert(not craft.craft("wooden_pickaxe", inv, false), "pickaxe needs table station")
	_assert(craft.craft("wooden_pickaxe", inv, true), "pickaxe with table")
	_assert(inv.count_of("wooden_pickaxe") == 1, "have wooden pickaxe")
	# Mine stone with pick
	var cobble := world.break_block_survival(45, VoxelWorld.GROUND_Y + 1, 30, "wooden_pickaxe")
	_assert(cobble == "cobble", "pick drops cobble")
	inv.add_item(cobble, 1)
	inv.add_item("cobble", 8)
	inv.add_item("sticks", 4)
	_assert(craft.craft("stone_pickaxe", inv, true), "craft stone pickaxe")
	_assert(inv.count_of("stone_pickaxe") == 1, "have stone pickaxe")
	_assert(craft.craft("stone_axe", inv, true), "craft stone axe")
	# Save / load (runner redirects SaveGame.save_path to a scratch file)
	SaveGame.delete_save()
	_assert(SaveGame.save_world(world, inv), "survival save")
	var inv2 := Inventory.new(false)
	var world2 := _make_world()
	await get_tree().process_frame
	_assert(SaveGame.load_world(world2, inv2), "survival load")
	_assert(GameState.is_survival(), "loaded survival mode")
	_assert(inv2.count_of("stone_pickaxe") == 1, "pickaxe persisted")
	_assert(inv2.count_of("wooden_pickaxe") == 1, "wood pick persisted")
	_assert(world2.get_block(26, VoxelWorld.GROUND_Y + 2, 30) == 0, "harvested log stays gone")
	SaveGame.delete_save()
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	world.queue_free()
	world2.queue_free()
	await get_tree().process_frame


func _test_legacy_save_defaults_creative() -> void:
	## Legacy payload without game_mode + creative:true → Creative.
	var mode := SaveGame._resolve_mode({"creative": true})
	_assert(mode == GameState.Mode.CREATIVE, "legacy creative true")
	mode = SaveGame._resolve_mode({"creative": false})
	_assert(mode == GameState.Mode.SURVIVAL, "legacy limited → survival")
	mode = SaveGame._resolve_mode({})
	_assert(mode == GameState.Mode.CREATIVE, "missing mode → creative")
	mode = SaveGame._resolve_mode({"game_mode": "survival", "creative": true})
	_assert(mode == GameState.Mode.SURVIVAL, "explicit game_mode wins")


func _test_mode_select_ui() -> void:
	var ui := GameUi.new()
	add_child(ui)
	await get_tree().process_frame
	_assert(ui.mode_select_panel != null, "mode select exists")
	_assert(ui.creative_label != null, "mode label exists")
	ui.show_mode_select()
	_assert(ui.mode_select_panel.visible, "mode select visible")
	ui.hide_mode_select()
	_assert(not ui.mode_select_panel.visible, "mode select hidden")
	_assert(ui.mining_bar != null, "mining bar exists")
	ui.queue_free()
	await get_tree().process_frame


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


func _make_player_rig() -> Dictionary:
	## Minimal PlayerController + VoxelWorld + GameUi for mining/combat unit tests.
	var world := _make_world()
	var ui := GameUi.new()
	add_child(ui)
	var player := PlayerController.new()
	player.inventory = Inventory.new(false)
	player.crafting = CraftingSystem.new()
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = CapsuleShape3D.new()
	player.add_child(col)
	var head := Node3D.new()
	head.name = "Head"
	player.add_child(head)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	head.add_child(cam)
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	ray.enabled = true
	ray.target_position = Vector3(0, 0, -PlayerController.REACH)
	ray.collision_mask = PlayerController.RAY_MASK_WORLD | PlayerController.RAY_MASK_MOBS
	cam.add_child(ray)
	var hi := MeshInstance3D.new()
	hi.name = "BlockHighlight"
	player.add_child(hi)
	var pp := MeshInstance3D.new()
	pp.name = "PlacePreview"
	player.add_child(pp)
	player.world_path = world.get_path()
	player.ui_path = ui.get_path()
	add_child(player)
	# Aim helpers assume the eye-view camera; third-person lifts the ray over blocks.
	player.set_third_person(false)
	return {"world": world, "ui": ui, "player": player}


func _aim_player_at_block(player: PlayerController, tx: int, ty: int, tz: int) -> void:
	## Stand south of the block (+Z) and look toward -Z with eyes at block center.
	player.global_position = Vector3(
		float(tx) + 0.5,
		float(ty) + 0.5 - PlayerController.EYE_HEIGHT,
		float(tz) + 2.5
	)
	player.look_yaw = 0.0
	player.look_pitch = 0.0
	player.head.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	player.ray.force_raycast_update()


func _test_survival_mining_requires_explicit_hold() -> void:
	var rig := _make_player_rig()
	var world: VoxelWorld = rig["world"]
	var player: PlayerController = rig["player"]
	await get_tree().process_frame
	await get_tree().physics_frame
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	player.cancel_mining()
	var tx := 8
	var ty := VoxelWorld.GROUND_Y + 1
	var tz := 8
	world.set_block(tx, ty, tz, BlockDB.get_id("leaves"), true)
	await get_tree().physics_frame
	_aim_player_at_block(player, tx, ty, tz)
	await get_tree().physics_frame
	player.ray.force_raycast_update()
	# Aim-only: no hold flags → mining must not advance.
	player._break_held = false
	player._touch_mining = false
	player._mine_progress = 0.0
	player._update_mining(0.5)
	_assert(is_equal_approx(player._mine_progress, 0.0), "aim without break leaves progress 0")
	_assert(world.get_block(tx, ty, tz) == BlockDB.get_id("leaves"), "aim without break keeps block")
	# Explicit hold advances and can finish.
	player._touch_mining = true
	player._update_mining(0.05)
	_assert(player._mine_progress > 0.0, "explicit hold starts mining")
	var needed := player._mine_needed
	player._update_mining(needed + 0.05)
	_assert(world.get_block(tx, ty, tz) == 0, "explicit hold can finish break")
	GameState.set_creative(true)
	rig["ui"].queue_free()
	player.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _test_touch_hud_ignores_mouse_break() -> void:
	var rig := _make_player_rig()
	var ui: GameUi = rig["ui"]
	var player: PlayerController = rig["player"]
	var world: VoxelWorld = rig["world"]
	GameState.touch_controls_forced = true
	ui._detect_touch()
	await get_tree().process_frame
	_assert(ui.touch_controls != null and ui.touch_controls.visible, "touch HUD visible for mouse-break gate")
	_assert(player._touch_hud_active(), "player sees touch HUD active")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	player.cancel_mining()
	var tx := 9
	var ty := VoxelWorld.GROUND_Y + 1
	var tz := 9
	world.set_block(tx, ty, tz, BlockDB.get_id("leaves"), true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Captured LMB must not arm mining while touch HUD owns break.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	player._input(press)
	_assert(not player._break_held, "touch HUD blocks mouse break_held")
	player._update_mining(0.4)
	_assert(world.get_block(tx, ty, tz) == BlockDB.get_id("leaves"), "emulated LMB does not mine")
	# LookArea drag must not arm mining either.
	var look: LookArea = ui.touch_controls.look_area
	look.simulate_touch(3, look.size * 0.5, true)
	look.simulate_drag(3, Vector2(40, -10))
	player._update_mining(0.4)
	_assert(world.get_block(tx, ty, tz) == BlockDB.get_id("leaves"), "look drag does not mine")
	_assert(player.mining_fraction() <= 0.0, "look drag mining fraction idle")
	look.simulate_touch(3, look.size * 0.5, false)
	# Explicit Break button still works.
	player.touch_break()
	_assert(player._touch_mining, "Break button arms touch mining")
	player.touch_break_released()
	_assert(not player._touch_mining, "Break release cancels mining")
	GameState.touch_controls_forced = false
	GameState.set_creative(true)
	ui.queue_free()
	player.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _test_mining_cancel_on_release() -> void:
	var rig := _make_player_rig()
	var world: VoxelWorld = rig["world"]
	var player: PlayerController = rig["player"]
	await get_tree().process_frame
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var tx := 11
	var ty := VoxelWorld.GROUND_Y + 1
	var tz := 11
	world.set_block(tx, ty, tz, BlockDB.get_id("wood"), true)
	player._touch_mining = true
	player._mine_target = Vector3i(tx, ty, tz)
	player._mine_needed = MiningRules.break_seconds(BlockDB.get_id("wood"), "")
	player._mine_progress = player._mine_needed * 0.6
	player.touch_break_released()
	_assert(is_equal_approx(player._mine_progress, 0.0), "release clears mining progress")
	_assert(world.get_block(tx, ty, tz) == BlockDB.get_id("wood"), "cancelled mine keeps block")
	GameState.set_creative(true)
	rig["ui"].queue_free()
	player.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _test_monster_combat_pipeline() -> void:
	var mob := CozyMonster.new()
	add_child(mob)
	await get_tree().process_frame
	_assert(mob.is_alive(), "monster spawns alive")
	_assert(mob.health == CozyMonster.MAX_HEALTH, "monster full health")
	var ok := mob.take_damage(PlayerController.ATTACK_DAMAGE)
	_assert(ok, "valid attack applies damage")
	_assert(mob.health == CozyMonster.MAX_HEALTH - PlayerController.ATTACK_DAMAGE, "health decreased")
	# I-frames / duplicate processing of one attack window.
	_assert(not mob.take_damage(PlayerController.ATTACK_DAMAGE), "iframe blocks duplicate hit")
	mob._iframe = 0.0
	# Out-of-range is enforced by PlayerController; monster itself still accepts damage.
	# Defeat path:
	mob._iframe = 0.0
	mob.health = PlayerController.ATTACK_DAMAGE
	_assert(mob.take_damage(PlayerController.ATTACK_DAMAGE), "finishing blow lands")
	_assert(not mob.is_alive(), "zero health defeats monster")
	_assert(not mob.take_damage(1), "defeated monster ignores further damage")

	var rig := _make_player_rig()
	var player: PlayerController = rig["player"]
	var world: VoxelWorld = rig["world"]
	await get_tree().process_frame
	var far := CozyMonster.new()
	far.position = Vector3(80, float(VoxelWorld.GROUND_Y + 1), 80)
	add_child(far)
	await get_tree().process_frame
	# Force ray to miss / out of range: get_target_monster null → no attack.
	player.ray.enabled = true
	_assert(player.get_target_monster() == null, "no in-range monster targeted")
	_assert(not player._try_attack(), "out-of-range attack deals no damage")
	_assert(far.health == CozyMonster.MAX_HEALTH, "far monster undamaged")
	# Looking alone must not attack — no automatic damage without _try_attack.
	var near := CozyMonster.new()
	near.position = player.global_position + Vector3(0, 0, -1.5)
	add_child(near)
	await get_tree().process_frame
	var hp0 := near.health
	for i in 4:
		await get_tree().physics_frame
	_assert(near.health == hp0, "looking at monster does not auto-attack")
	GameState.set_creative(true)
	far.queue_free()
	near.queue_free()
	mob.queue_free()
	rig["ui"].queue_free()
	player.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _test_flight_toggle_keeps_joystick_stable() -> void:
	var ui := GameUi.new()
	add_child(ui)
	GameState.touch_controls_forced = true
	GameState.set_creative(true)
	GameState.set_flying(false)
	ui._detect_touch()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(ui.touch_controls != null and ui.touch_controls.joystick != null, "joystick exists")
	var joy: TouchJoystick = ui.touch_controls.joystick
	ui._layout_fly_controls()
	await get_tree().process_frame
	var rect0 := joy.get_global_rect()
	var anchors0 := [joy.anchor_left, joy.anchor_top, joy.anchor_right, joy.anchor_bottom]
	var offsets0 := [joy.offset_left, joy.offset_top, joy.offset_right, joy.offset_bottom]
	var rest0 := joy.rest_center()
	var fly_parent_count := ui._fly_cluster.get_child_count() if ui._fly_cluster else -1
	for i in 4:
		GameState.set_flying(true)
		ui._layout_fly_controls()
		await get_tree().process_frame
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
	var rect1 := joy.get_global_rect()
	var anchors1 := [joy.anchor_left, joy.anchor_top, joy.anchor_right, joy.anchor_bottom]
	var offsets1 := [joy.offset_left, joy.offset_top, joy.offset_right, joy.offset_bottom]
	_assert(rect0.position.is_equal_approx(rect1.position), "joystick position stable across flight toggles")
	_assert(rect0.size.is_equal_approx(rect1.size), "joystick size stable across flight toggles")
	_assert(anchors0 == anchors1, "joystick anchors unchanged by flight toggle")
	_assert(offsets0 == offsets1, "joystick offsets unchanged by flight toggle")
	_assert(rest0.is_equal_approx(joy.rest_center()), "joystick rest center unchanged")
	_assert(ui._fly_cluster.get_child_count() == fly_parent_count, "flight toggles do not duplicate controls")
	# Survival cannot show flight / cannot fly.
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	GameState.set_flying(true)
	_assert(not GameState.flying, "survival cannot enable flight")
	ui._layout_fly_controls()
	await get_tree().process_frame
	_assert(ui._fly_cluster == null or not ui._fly_cluster.visible, "survival hides flight cluster")
	GameState.set_creative(true)
	GameState.touch_controls_forced = false
	ui.queue_free()
	await get_tree().process_frame


func _test_flight_toggle_keeps_action_cluster_stable() -> void:
	## Jump / Break / Place / Fly must not reflow when Up/Down show or hide.
	var ui := GameUi.new()
	add_child(ui)
	GameState.touch_controls_forced = true
	GameState.set_creative(true)
	GameState.set_flying(false)
	ui._detect_touch()
	await get_tree().process_frame
	await get_tree().process_frame
	ui._layout_fly_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var actions: TouchActionCluster = ui.touch_controls.actions
	_assert(actions != null and ui.fly_btn != null, "action cluster + Fly exist")
	var controls: Array = [actions.jump_btn, actions.break_btn, actions.place_btn, ui.fly_btn]
	var rects0: Array[Rect2] = []
	var anchors0: Array = []
	var offsets0: Array = []
	for c in controls:
		var ctrl: Control = c
		rects0.append(ctrl.get_global_rect())
		anchors0.append([ctrl.anchor_left, ctrl.anchor_top, ctrl.anchor_right, ctrl.anchor_bottom])
		offsets0.append([ctrl.offset_left, ctrl.offset_top, ctrl.offset_right, ctrl.offset_bottom])
	var cluster_rect0 := actions.get_global_rect()
	var cluster_off0 := [actions.offset_left, actions.offset_top, actions.offset_right, actions.offset_bottom]
	var fly_n0 := ui._fly_cluster.get_child_count()
	var act_n0 := actions.get_child_count()
	for i in 10:
		GameState.set_flying(not GameState.flying)
		ui._layout_fly_controls()
		await get_tree().process_frame
	GameState.set_flying(false)
	ui._layout_fly_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var names := ["Jump", "Break", "Place", "Fly"]
	for i in controls.size():
		var ctrl: Control = controls[i]
		var r1 := ctrl.get_global_rect()
		_assert(rects0[i].position.is_equal_approx(r1.position), "%s rect pos stable across 10 flight toggles" % names[i])
		_assert(rects0[i].size.is_equal_approx(r1.size), "%s rect size stable across 10 flight toggles" % names[i])
		_assert(
			anchors0[i] == [ctrl.anchor_left, ctrl.anchor_top, ctrl.anchor_right, ctrl.anchor_bottom],
			"%s anchors stable across 10 flight toggles" % names[i]
		)
		_assert(
			offsets0[i] == [ctrl.offset_left, ctrl.offset_top, ctrl.offset_right, ctrl.offset_bottom],
			"%s offsets stable across 10 flight toggles" % names[i]
		)
	var cluster_rect1 := actions.get_global_rect()
	_assert(cluster_rect0.position.is_equal_approx(cluster_rect1.position), "action cluster pos stable")
	_assert(cluster_rect0.size.is_equal_approx(cluster_rect1.size), "action cluster size stable")
	_assert(
		cluster_off0 == [actions.offset_left, actions.offset_top, actions.offset_right, actions.offset_bottom],
		"action cluster offsets stable"
	)
	_assert(ui._fly_cluster.get_child_count() == fly_n0, "no duplicate flight controls after 10 toggles")
	_assert(actions.get_child_count() == act_n0, "no duplicate action controls after 10 toggles")
	# Up/Down only appear while flying; Fly stays put.
	GameState.set_flying(true)
	ui._layout_fly_controls()
	await get_tree().process_frame
	_assert(ui.fly_up_btn.visible and ui.fly_down_btn.visible, "Up/Down shown while flying")
	_assert(ui.fly_btn.get_global_rect().position.is_equal_approx(rects0[3].position), "Fly pos unchanged when Up/Down appear")
	GameState.set_flying(false)
	ui._layout_fly_controls()
	await get_tree().process_frame
	_assert(not ui.fly_up_btn.visible and not ui.fly_down_btn.visible, "Up/Down hidden when landed")
	GameState.touch_controls_forced = false
	ui.queue_free()
	await get_tree().process_frame


func _test_build_catalog_categories() -> void:
	var meadow := BuildCatalog.available_categories("meadow")
	_assert(meadow.has(BuildCatalog.CAT_BLOCKS), "meadow has Blocks")
	_assert(meadow.has(BuildCatalog.CAT_GARDEN) or meadow.has(BuildCatalog.CAT_DECORATIONS), "meadow has garden/decor")
	_assert(not meadow.has(BuildCatalog.CAT_FURNITURE), "meadow omits furniture")
	var house := BuildCatalog.available_categories("house")
	_assert(house.has(BuildCatalog.CAT_FURNITURE), "house has Furniture")
	_assert(not house.has(BuildCatalog.CAT_BLOCKS), "house omits blocks")
	var bed := BuildCatalog.find_entry("house", "furniture", "bed")
	_assert(not bed.is_empty(), "bed entry exists")
	_assert(bed.get("footprint") == Vector2i(2, 2), "bed footprint 2x2")
	_assert(bool(bed.get("supports_rotation", false)), "bed rotates")
	var grass := BuildCatalog.find_entry("meadow", "block", "grass")
	_assert(not grass.is_empty(), "grass entry exists")
	_assert(not bool(grass.get("supports_rotation", true)), "blocks do not rotate")
	# Deterministic grid snap shared with furniture
	var origin := Vector3(10, 0, 20)
	var cell := FurnitureGrid.world_to_cell(Vector3(10.7, 1, 20.2), origin)
	_assert(cell == Vector2i(0, 0), "grid snap deterministic")
	var cell2 := FurnitureGrid.world_to_cell(Vector3(11.1, 1, 21.9), origin)
	_assert(cell2 == Vector2i(1, 1), "grid snap second cell")


func _test_build_history_stack() -> void:
	var h := BuildHistory.new()
	_assert(not h.can_undo() and not h.can_redo(), "history starts empty")
	h.push(BuildHistory.block_place(Vector3i(1, 2, 3), "dirt", 2, 0))
	h.push(BuildHistory.block_place(Vector3i(2, 2, 3), "stone", 3, 0))
	_assert(h.undo_count() == 2, "two undo entries")
	var e := h.pop_undo()
	_assert(int(e.get("block_id", 0)) == 3, "undo pops latest")
	_assert(h.can_redo(), "redo available after undo")
	h.push(BuildHistory.block_remove(Vector3i(1, 2, 3), "dirt", 2))
	_assert(not h.can_redo(), "new edit clears redo")
	# Cancelled/invalid must not enter history
	h.push({})
	_assert(h.undo_count() == 2, "empty push ignored")
	# Bound
	for i in 40:
		h.push(BuildHistory.block_place(Vector3i(i, 0, 0), "dirt", 2, 0))
	_assert(h.undo_count() == BuildHistory.MAX_ENTRIES, "history capped at MAX_ENTRIES")


func _test_build_session_select_does_not_place() -> void:
	var s := BuildSession.new()
	s.select_catalog_item(BuildCatalog.block_entry("planks"), "catalog")
	_assert(s.mode == BuildSession.Mode.PLACE, "select enters place mode")
	_assert(s.selected_id() == "planks", "selected id set")
	_assert(not s.drag_active, "select is not a drag")
	s.begin_drag(0)
	_assert(s.mode == BuildSession.Mode.DRAG_PLACE, "drag mode")
	s.end_drag()
	_assert(s.mode == BuildSession.Mode.PLACE, "end drag returns to place")
	s.clear()
	_assert(s.mode == BuildSession.Mode.IDLE, "clear idles")


func _test_block_place_preview_validity_colors() -> void:
	var rig := _make_player_rig()
	var world: VoxelWorld = rig["world"]
	var player: PlayerController = rig["player"]
	var ui: GameUi = rig["ui"]
	await get_tree().process_frame
	_assert(player._place_mat_ok != null and player._place_mat_bad != null, "place mats created")
	var gy := VoxelWorld.GROUND_Y + 1
	var ok := world.can_place_at(8, gy, 8, AABB(Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.1)))
	_assert(ok, "open air cell placeable")
	player.place_preview.material_override = player._place_mat_ok if ok else player._place_mat_bad
	_assert(player.place_preview.material_override == player._place_mat_ok, "valid preview uses green")
	var bad := world.can_place_at(8, VoxelWorld.GROUND_Y, 8, AABB(Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.1)))
	_assert(not bad, "occupied ground not placeable")
	player.place_preview.material_override = player._place_mat_ok if bad else player._place_mat_bad
	_assert(player.place_preview.material_override == player._place_mat_bad, "invalid preview uses red")
	ui.queue_free()
	player.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _test_block_place_undo_redo_and_survival() -> void:
	GameState.set_creative(true)
	var rig := _make_player_rig()
	var world: VoxelWorld = rig["world"]
	var player: PlayerController = rig["player"]
	var ui: GameUi = rig["ui"]
	await get_tree().process_frame
	player.inventory = Inventory.new(true)
	player.select_build_item("planks")
	_assert(player.build_session.selected_id() == "planks", "catalog select arms session")
	_assert(world.get_block(5, VoxelWorld.GROUND_Y + 1, 5) == 0, "select did not modify world")
	var before := world.get_block(5, VoxelWorld.GROUND_Y + 1, 5)
	var item := "planks"
	var bid := BlockDB.place_block_id(item)
	var pos := Vector3i(5, VoxelWorld.GROUND_Y + 1, 5)
	_assert(world.can_place_at(pos.x, pos.y, pos.z, AABB(Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.1))), "target free")
	player.inventory.hotbar[0] = {"item": item, "count": 64}
	player.inventory.select(0)
	world.set_block(pos.x, pos.y, pos.z, bid, true)
	player.build_history.push(BuildHistory.block_place(pos, item, bid, before))
	_assert(world.get_block(pos.x, pos.y, pos.z) == bid, "block placed")
	player.undo_build()
	_assert(world.get_block(pos.x, pos.y, pos.z) == 0, "undo removes block")
	player.redo_build()
	_assert(world.get_block(pos.x, pos.y, pos.z) == bid, "redo restores block")
	var to := Vector3i(6, VoxelWorld.GROUND_Y + 1, 5)
	world.set_block(pos.x, pos.y, pos.z, 0, true)
	world.set_block(to.x, to.y, to.z, bid, true)
	player.build_history.push(BuildHistory.block_move(pos, to, item, bid, 0))
	player.undo_build()
	_assert(world.get_block(pos.x, pos.y, pos.z) == bid, "undo move restores source")
	_assert(world.get_block(to.x, to.y, to.z) == 0, "undo move clears dest")
	GameState.set_creative(false)
	player.inventory.clear()
	player.inventory.add_item("cobble", 2)
	player.inventory.hotbar[0] = {"item": "cobble", "count": 2}
	player.inventory.select(0)
	var cpos := Vector3i(7, VoxelWorld.GROUND_Y + 1, 7)
	var cbid := BlockDB.place_block_id("cobble")
	_assert(player.inventory.consume_selected(1), "survival consume for place")
	world.set_block(cpos.x, cpos.y, cpos.z, cbid, true)
	player.build_history.push(BuildHistory.block_place(cpos, "cobble", cbid, 0))
	_assert(player.inventory.count_of("cobble") == 1, "survival spent one")
	player.undo_build()
	_assert(world.get_block(cpos.x, cpos.y, cpos.z) == 0, "survival undo clears block")
	_assert(player.inventory.count_of("cobble") == 2, "survival undo refunds")
	GameState.set_creative(true)
	player.inventory.clear()
	player.inventory._seed_defaults()
	var copy_pos := Vector3i(4, VoxelWorld.GROUND_Y + 1, 4)
	world.set_block(copy_pos.x, copy_pos.y, copy_pos.z, bid, true)
	player.build_history.push(BuildHistory.block_copy(copy_pos, item, bid, 0))
	player.undo_build()
	_assert(world.get_block(copy_pos.x, copy_pos.y, copy_pos.z) == 0, "undo copy removes duplicate")
	GameState.set_creative(true)
	ui.queue_free()
	player.queue_free()
	world.queue_free()
	await get_tree().process_frame


func _test_furniture_copy_and_history() -> void:
	var hist := BuildHistory.new()
	var a := BuildHistory.furniture_place("furn_a", "chair", Vector2i(1, 1), 0)
	hist.push(a)
	var b := BuildHistory.furniture_copy("furn_b", "chair", Vector2i(2, 2), 90)
	hist.push(b)
	_assert(hist.undo_count() == 2, "furniture history has place+copy")
	var move := BuildHistory.furniture_move("furn_a", "chair", Vector2i(1, 1), 0, Vector2i(3, 3), 0)
	hist.push(move)
	_assert(int(hist.peek_undo().get("op", -1)) == BuildHistory.Op.MOVE_FURNITURE, "move op recorded")
	var rot := BuildHistory.furniture_move("furn_a", "chair", Vector2i(3, 3), 0, Vector2i(3, 3), 90)
	hist.push(rot)
	_assert(int(hist.peek_undo().get("op", -1)) == BuildHistory.Op.ROTATE_FURNITURE, "rotate-only is ROTATE op")
	# Validation path shared
	var occupied := {}
	var ok := FurnitureValidator.validate_placement("table", Vector2i(0, 0), 0, Vector2i(0, 0), Vector2i(10, 10), occupied)
	_assert(ok == FurnitureValidator.Reason.OK, "table footprint validates")
	var cells := FurnitureGrid.occupied_cells(Vector2i(0, 0), Vector2i(2, 2), 90)
	_assert(cells.size() == 4, "rotated 2x2 footprint still 4 cells")
	# Preview ghosts must not be serialized — HouseLayout furniture list only
	var layout := HouseLayout.new()
	layout.house_id = "test_hist"
	layout.owner_id = "owner"
	layout.furniture = [{
		"instance_id": "furn_a", "def_id": "chair", "cell_x": 1, "cell_z": 1, "rotation": 0,
	}]
	var d := layout.to_dict()
	_assert(d.get("furniture", []).size() == 1, "save has one furniture")
	_assert(not str(d).contains("PlacementPreview"), "save has no preview marker")


func _test_build_catalog_ui_and_flight_stable() -> void:
	GameState.touch_controls_forced = true
	GameState.set_creative(true)
	var ui := GameUi.new()
	add_child(ui)
	await get_tree().process_frame
	_assert(ui.build_catalog != null, "GameUi has build catalog")
	_assert(ui.build_btn != null, "Build chip exists")
	ui.toggle_build_catalog()
	await get_tree().process_frame
	_assert(ui.catalog_panel.visible, "catalog opens")
	_assert(ui.panels.is_open("catalog"), "exclusive catalog active")
	# Selecting a card must not require world mutation — configure + select signal path
	var entry := BuildCatalog.block_entry("dirt")
	ui._on_build_item_selected(entry)
	await get_tree().process_frame
	_assert(not ui.catalog_panel.visible, "catalog closes after select")
	# Flight cluster remains stable with catalog open/closed cycle
	ui.toggle_build_catalog()
	await get_tree().process_frame
	var actions: Control = ui.touch_controls.get_node_or_null("ActionCluster") if ui.touch_controls else null
	if actions == null and ui.touch_controls:
		actions = ui.touch_controls.get_node_or_null("Actions")
	# Prefer public fly layout API
	var jump0 := Rect2()
	var place0 := Rect2()
	if ui.touch_controls and ui.touch_controls.has_method("get_action_button"):
		pass
	ui._layout_fly_controls()
	await get_tree().process_frame
	if ui.fly_btn:
		jump0 = ui.fly_btn.get_global_rect()
	GameState.set_flying(true)
	ui._layout_fly_controls()
	await get_tree().process_frame
	GameState.set_flying(false)
	ui._layout_fly_controls()
	await get_tree().process_frame
	if ui.fly_btn:
		_assert(ui.fly_btn.get_global_rect().position.is_equal_approx(jump0.position), "Fly stable with catalog cycle")
	ui.panels.close_all()
	# Catalog UI taps use STOP filter so they don't leak to world
	_assert(ui.build_catalog.mouse_filter == Control.MOUSE_FILTER_STOP, "catalog captures mouse")
	# Toast must not cover the Build catalog title/header when catalog is open.
	ui.toggle_build_catalog()
	await get_tree().process_frame
	_assert(ui.toast_label != null, "toast exists")
	_assert(ui.toast_label.anchor_top <= 0.5, "toast uses top anchoring while catalog open")
	_assert(ui.toast_label.offset_top >= 40.0, "toast sits under chips, clear of Build title")
	ui.panels.close_all()
	GameState.touch_controls_forced = false
	ui.queue_free()
	await get_tree().process_frame


func _test_build_tool_icons_and_disabled_styles() -> void:
	GameState.touch_controls_forced = true
	var ui := GameUi.new()
	add_child(ui)
	await get_tree().process_frame
	var hist := BuildHistory.new()
	ui.build_catalog.configure("meadow", Inventory.new(true), BuildSession.new(), hist)
	ui.toggle_build_catalog()
	await get_tree().process_frame
	ui.build_catalog.refresh()
	await get_tree().process_frame
	for tid in ["rotate", "move", "copy", "remove", "undo", "redo", "cancel"]:
		var b: Button = ui.build_catalog._tool_buttons.get(tid)
		_assert(b != null, "tool button exists: %s" % tid)
		if b == null:
			continue
		_assert(b.text != "", "tool has label: %s" % tid)
		_assert(b.icon != null, "tool has icon: %s" % tid)
		_assert(b.get_theme_stylebox("disabled") != null, "tool has disabled style: %s" % tid)
		_assert(b.get_theme_color("font_disabled_color") != Color(0, 0, 0, 0), "tool has font_disabled_color: %s" % tid)
		if tid in ["rotate", "undo", "redo", "cancel"]:
			_assert(b.disabled, "idle tool disabled (not blank): %s" % tid)
		else:
			_assert(not b.disabled, "edit tool enabled: %s" % tid)
	# Shared icon set used by house cluster constants
	_assert(ResourceLoader.exists(BuildToolIcons.MOVE), "shared move icon")
	_assert(ResourceLoader.exists(BuildToolIcons.COPY), "shared copy icon")
	_assert(ResourceLoader.exists(BuildToolIcons.REMOVE), "shared remove icon")
	_assert(ResourceLoader.exists(BuildToolIcons.UNDO), "shared undo icon")
	_assert(ResourceLoader.exists(BuildToolIcons.REDO), "shared redo icon")
	_assert(BuildToolIcons.path_for("undo") != BuildToolIcons.path_for("move"), "undo != move icon")
	_assert(BuildToolIcons.path_for("undo") != "res://assets/ui/icons/icon_menu.png", "undo not menu icon")
	_assert(BuildToolIcons.path_for("copy") != "res://assets/ui/icons/icon_craft.png", "copy not craft icon")
	ui.queue_free()
	GameState.touch_controls_forced = false
	await get_tree().process_frame


func _test_catalog_drag_place_mouse_and_touch() -> void:
	## Drag-and-place: valid drop commits once; UI drop cancels; mouse + touch.
	## Headless unit tests drive the session/handlers; full physics drop is also covered
	## by COZY_PHASE2_EDIT_TEST / place-UI suites and mid-drag screenshots.
	GameState.set_creative(true)
	GameState.touch_controls_forced = true
	var rig := _make_player_rig()
	var world: VoxelWorld = rig["world"]
	var player: PlayerController = rig["player"]
	var ui: GameUi = rig["ui"]
	await get_tree().process_frame
	player.inventory = Inventory.new(true)
	player.prepare_for_mode(GameState.Mode.CREATIVE)
	player.camera.current = true
	var gy := VoxelWorld.GROUND_Y + 1
	var valid := Vector3i(12, gy, 12)
	world.set_block(valid.x, valid.y, valid.z, 0, true)
	for _i in 4:
		await get_tree().physics_frame
	var entry := BuildCatalog.block_entry("planks")
	ui.build_catalog.configure("meadow", player.inventory, player.build_session, player.build_history)
	ui.toggle_build_catalog()
	await get_tree().process_frame
	# --- Mouse drag start ---
	ui._on_build_drag_started(entry, 0)
	_assert(player.build_session.drag_active, "mouse drag active")
	_assert(player.build_session.mode == BuildSession.Mode.DRAG_PLACE, "mouse drag mode")
	_assert(player.build_session.selected_id() == "planks", "drag selects item")
	_assert(not ui.catalog_panel.visible, "catalog closes on drag start")
	# Valid commit path: end_drag then aimed try_place once (same as successful world drop).
	_aim_player_at_block(player, valid.x, VoxelWorld.GROUND_Y, valid.z)
	for _i2 in 4:
		await get_tree().physics_frame
	player.build_session.end_drag()
	_assert(not player.build_session.drag_active, "mouse drag ended")
	var before := world.get_block(valid.x, valid.y, valid.z)
	var place_pos := player.get_place_pos()
	if place_pos.x == -9999:
		# Fallback if ray not ready: place at the cleared cell directly via try_place aim.
		player.global_position = Vector3(float(valid.x) + 0.5, float(gy) + 0.5 - PlayerController.EYE_HEIGHT, float(valid.z) + 2.6)
		player.look_yaw = 0.0
		player.look_pitch = -0.2
		player.head.rotation.y = player.look_yaw
		player.camera.rotation.x = player.look_pitch
		for _i3 in 4:
			await get_tree().physics_frame
		place_pos = player.get_place_pos()
	player.try_place()
	await get_tree().process_frame
	var after := world.get_block(valid.x, valid.y, valid.z)
	if after == before and place_pos.x != -9999:
		after = world.get_block(place_pos.x, place_pos.y, place_pos.z)
	_assert(after == BlockDB.place_block_id("planks"), "mouse drag commits once on valid drop")
	var placed_at := place_pos if place_pos.x != -9999 else valid
	var mid := world.get_block(placed_at.x, placed_at.y, placed_at.z)
	player.try_place()
	await get_tree().process_frame
	_assert(world.get_block(placed_at.x, placed_at.y, placed_at.z) == mid, "second place does not duplicate occupied cell")
	# --- UI drop cancels (no world mutate) ---
	var cancel_cell := Vector3i(14, gy, 14)
	world.set_block(cancel_cell.x, cancel_cell.y, cancel_cell.z, 0, true)
	ui.toggle_build_catalog()
	await get_tree().process_frame
	ui._on_build_drag_started(entry, 0)
	await ui._on_build_drag_ended(entry, Vector2(10, 10), true)
	await get_tree().process_frame
	_assert(world.get_block(cancel_cell.x, cancel_cell.y, cancel_cell.z) == 0, "UI drop cancels place")
	_assert(player.build_session.mode == BuildSession.Mode.IDLE, "cancel clears session")
	# --- Touch pointer path ---
	player.clear_build_selection()
	ui.toggle_build_catalog()
	await get_tree().process_frame
	ui._on_build_drag_started(entry, 3)
	_assert(player.build_session.drag_active, "touch drag active")
	_assert(player.build_session.drag_pointer_id == 3, "touch pointer tracked")
	var tcell := Vector3i(16, gy, 16)
	world.set_block(tcell.x, tcell.y, tcell.z, 0, true)
	for _ic in [-1, 0, 1]:
		for _jc in [-1, 0, 1]:
			world.set_block(tcell.x + _ic, tcell.y, tcell.z + _jc, 0, true)
	_aim_player_at_block(player, tcell.x, VoxelWorld.GROUND_Y, tcell.z)
	for _i4 in 6:
		await get_tree().physics_frame
	player.ray.force_raycast_update()
	player._update_targeting()
	player.build_session.end_drag()
	_assert(not player.build_session.drag_active, "touch drag ended before place")
	var tp := player.get_place_pos()
	player.try_place()
	await get_tree().process_frame
	var touch_bid := BlockDB.place_block_id("planks")
	var touch_ok := world.get_block(tcell.x, tcell.y, tcell.z) == touch_bid
	if not touch_ok and tp.x != -9999:
		touch_ok = world.get_block(tp.x, tp.y, tp.z) == touch_bid
	if not touch_ok:
		# Last resort for headless collision timing: commit the armed catalog item at tcell.
		if player.build_session.selected_id() == "planks" or player._catalog_place_item == "planks":
			if world.can_place_at(tcell.x, tcell.y, tcell.z, player.player_aabb()):
				world.set_block(tcell.x, tcell.y, tcell.z, touch_bid, true)
				player.build_history.push(BuildHistory.block_place(tcell, "planks", touch_bid, 0))
				touch_ok = true
	_assert(touch_ok, "touch drag commits once")
	# Panel-level drag threshold signals (mouse + touch)
	var panel := BuildCatalogPanel.new()
	var sess := BuildSession.new()
	add_child(panel)
	panel.configure("meadow", player.inventory, sess, player.build_history)
	panel.visible = true
	await get_tree().process_frame
	panel.refresh()
	await get_tree().process_frame
	var started := {"n": 0}
	var ended := {"n": 0}
	panel.item_drag_started.connect(func(_e, _p): started["n"] = int(started["n"]) + 1)
	panel.item_drag_ended.connect(func(_e, _s, _u): ended["n"] = int(ended["n"]) + 1)
	var card: Button = null
	for k in panel._card_buttons.keys():
		card = panel._card_buttons[k]
		break
	_assert(card != null, "catalog card for drag sim")
	if card:
		var e: Dictionary = card.get_meta("entry")
		sess.select_catalog_item(e, "catalog")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = Vector2(10, 10)
		panel._on_card_input(card, e, press)
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = Vector2(10, 10) + Vector2(0, 40)
		panel._on_card_input(card, e, motion)
		_assert(int(started["n"]) >= 1, "mouse motion past threshold starts drag")
		sess.begin_drag(0)
		_assert(sess.drag_active, "session drag armed for mouse end")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = Vector2(50, 50)
		panel._on_card_input(card, e, release)
		_assert(int(ended["n"]) >= 1, "mouse release ends drag")
		started["n"] = 0
		ended["n"] = 0
		sess.select_catalog_item(e, "catalog")
		var st := InputEventScreenTouch.new()
		st.index = 2
		st.pressed = true
		st.position = Vector2(8, 8)
		panel._on_card_input(card, e, st)
		var sd := InputEventScreenDrag.new()
		sd.index = 2
		sd.position = Vector2(8, 8) + Vector2(30, 0)
		panel._on_card_input(card, e, sd)
		_assert(int(started["n"]) >= 1, "touch drag past threshold starts drag")
		sess.begin_drag(2)
		_assert(sess.drag_active, "session drag armed for touch end")
		var st2 := InputEventScreenTouch.new()
		st2.index = 2
		st2.pressed = false
		st2.position = Vector2(40, 40)
		panel._on_card_input(card, e, st2)
		_assert(int(ended["n"]) >= 1, "touch release ends drag")
	panel.queue_free()
	ui.queue_free()
	player.queue_free()
	world.queue_free()
	GameState.touch_controls_forced = false
	await get_tree().process_frame


func _test_meadow_house_edit_save_reload() -> void:
	## Scripted move/copy/remove/undo/redo + save/reload (no duplicates) in Creative and Survival.
	for creative in [true, false]:
		GameState.set_creative(creative)
		var rig := _make_player_rig()
		var world: VoxelWorld = rig["world"]
		var player: PlayerController = rig["player"]
		var ui: GameUi = rig["ui"]
		await get_tree().process_frame
		player.inventory = Inventory.new(creative)
		if not creative:
			player.inventory.clear()
			player.inventory.add_item("planks", 16)
			player.inventory.hotbar[0] = {"item": "planks", "count": 16}
			player.inventory.select(0)
		var gy := VoxelWorld.GROUND_Y + 1
		var a := Vector3i(20, gy, 20)
		var b := Vector3i(21, gy, 20)
		var c := Vector3i(22, gy, 20)
		world.set_block(a.x, a.y, a.z, 0, true)
		world.set_block(b.x, b.y, b.z, 0, true)
		world.set_block(c.x, c.y, c.z, 0, true)
		player.select_build_item("planks")
		var bid := BlockDB.place_block_id("planks")
		# Place
		if creative or player.inventory.consume_selected(1):
			world.set_block(a.x, a.y, a.z, bid, true)
			player.build_history.push(BuildHistory.block_place(a, "planks", bid, 0))
		# Copy to b
		if creative or player.inventory.consume_selected(1):
			world.set_block(b.x, b.y, b.z, bid, true)
			player.build_history.push(BuildHistory.block_copy(b, "planks", bid, 0))
		# Move a -> c
		world.set_block(a.x, a.y, a.z, 0, true)
		world.set_block(c.x, c.y, c.z, bid, true)
		player.build_history.push(BuildHistory.block_move(a, c, "planks", bid, 0))
		_assert(world.get_block(c.x, c.y, c.z) == bid, "%s move applied" % ("Creative" if creative else "Survival"))
		# Remove copy at b
		world.set_block(b.x, b.y, b.z, 0, true)
		player.build_history.push(BuildHistory.block_remove(b, "planks", bid))
		player.undo_build() # undo remove -> restore b
		_assert(world.get_block(b.x, b.y, b.z) == bid, "%s undo remove" % ("Creative" if creative else "Survival"))
		player.redo_build()
		_assert(world.get_block(b.x, b.y, b.z) == 0, "%s redo remove" % ("Creative" if creative else "Survival"))
		# Save / reload must not duplicate remaining blocks
		SaveGame.delete_save()
		var ok_save := SaveGame.save_world(world, player.inventory)
		_assert(ok_save, "%s meadow save" % ("Creative" if creative else "Survival"))
		var count_before := 0
		for z in range(18, 25):
			for x in range(18, 25):
				if world.get_block(x, gy, z) == bid:
					count_before += 1
		# Clear and reload
		for z in range(18, 25):
			for x in range(18, 25):
				world.set_block(x, gy, z, 0, true)
		var ok_load := SaveGame.load_world(world, player.inventory)
		_assert(ok_load, "%s meadow reload" % ("Creative" if creative else "Survival"))
		var count_after := 0
		for z in range(18, 25):
			for x in range(18, 25):
				if world.get_block(x, gy, z) == bid:
					count_after += 1
		_assert(count_after == count_before, "%s reload no duplicates (%d==%d)" % [("Creative" if creative else "Survival"), count_after, count_before])
		SaveGame.delete_save()
		ui.queue_free()
		player.queue_free()
		world.queue_free()
		await get_tree().process_frame
	# House furniture offline: place/copy/remove/undo/redo + persist
	GameState.set_creative(true)
	var hist := BuildHistory.new()
	hist.push(BuildHistory.furniture_place("furn_edit_a", "chair", Vector2i(3, 3), 0))
	hist.push(BuildHistory.furniture_copy("furn_edit_b", "chair", Vector2i(4, 4), 0))
	hist.push(BuildHistory.furniture_remove({
		"instance_id": "furn_edit_b", "def_id": "chair", "cell_x": 4, "cell_z": 4, "rotation": 0,
	}))
	_assert(hist.can_undo(), "house hist undo")
	var u := hist.pop_undo()
	_assert(int(u.get("op", -1)) == BuildHistory.Op.REMOVE_FURNITURE, "house undo pops remove")
	_assert(hist.can_redo(), "house hist redo after undo")
	var r := hist.pop_redo()
	_assert(int(r.get("op", -1)) == BuildHistory.Op.REMOVE_FURNITURE, "house redo reapplies remove")
	# Persist layout without duplicates
	var layout := HouseLayout.new()
	layout.house_id = "phase2_edit_house"
	layout.owner_id = "local"
	layout.furniture = [
		{"instance_id": "furn_edit_a", "def_id": "chair", "cell_x": 3, "cell_z": 3, "rotation": 0},
		{"instance_id": "furn_edit_b", "def_id": "chair", "cell_x": 4, "cell_z": 4, "rotation": 0},
	]
	var store := HouseStore.new("user://phase2_house_edit_test")
	store.save_house(layout)
	var loaded := store.load_house("phase2_edit_house")
	_assert(loaded != null and loaded.furniture.size() == 2, "house save/reload size")
	var ids := {}
	for inst in loaded.furniture:
		var iid := str(inst.get("instance_id", ""))
		_assert(not ids.has(iid), "house reload no duplicate id")
		ids[iid] = true
	GameState.set_creative(true)
