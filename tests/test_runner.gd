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
	_assert(int(migrated.to_dict().get("schema", 0)) == 2, "migrated save writes schema 2")
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
	_assert(not GameState.flying, "limited mode rejects flight")
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
