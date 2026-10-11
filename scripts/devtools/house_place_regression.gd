extends Node
## UI-path furniture placement regression (offline + online).
## COZY_HOUSE_PLACE_TEST=1 COZY_NET_AUTOSTART=0 COZY_SMOKE_QUIT=1 \
##   xvfb-run -a godot --path . res://scenes/house/house.tscn \
##   --rendering-method gl_compatibility --rendering-driver opengl3

var _pass := 0
var _fail := 0
var _world: Node
var _server: GameServer
var _port := 19191
var _data_dir := ""


func _ready() -> void:
	if OS.get_environment("COZY_HOUSE_PLACE_TEST") != "1":
		queue_free()
		return
	print("=== House Place Regression ===")
	_world = get_parent()
	_data_dir = "user://place_test_houses_%d" % Time.get_ticks_usec()
	OS.set_environment("COZY_HOUSE_DATA", _data_dir)
	await get_tree().create_timer(0.8).timeout
	# Re-enter offline against an isolated store (harness may have booted earlier).
	_world._enter_offline_mode("Offline demo (server not started)")
	await get_tree().process_frame
	await _run_offline()
	await _run_online()
	print("=== PLACE Results: %d passed, %d failed ===" % [_pass, _fail])
	if OS.get_environment("COZY_SMOKE_QUIT") == "1" or OS.get_environment("COZY_HOUSE_PLACE_QUIT") == "1":
		get_tree().quit(1 if _fail > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("PASS: ", msg)
	else:
		_fail += 1
		print("FAIL: ", msg)


func _run_offline() -> void:
	print("-- offline UI placement --")
	if _world.has_method("is_offline_mode"):
		_assert(_world.is_offline_mode(), "offline mode active")
	_assert(_world.placement.can_decorate, "offline can_decorate")
	var ui: HouseUi = _world.ui
	_world._rebuild_furniture([])
	_world._persist_offline()

	for tier in HouseLayout.SIZE_ORDER:
		_world.apply_house_size_local(tier)
		await get_tree().process_frame
		_world._rebuild_furniture([])
		_world.placement.set_instances(_world._furniture)
		_assert(_world.space.room_cells == HouseLayout.cells_for_tier(tier), "offline size %s cells" % tier)
		# Catalog → item button → Place button (touch path).
		await _place_via_catalog_and_place_btn("bed", Vector2i(2, 2), "offline %s bed" % tier)
		await _place_via_catalog_and_place_btn("table", Vector2i(5, 5), "offline %s table 2x2" % tier)
		await _place_via_catalog_and_place_btn("coffee_table", Vector2i(8, 3), "offline %s coffee 2x1" % tier)
		# Desktop confirm: Catalog pick + E key (interact).
		await _place_via_catalog_and_key("wardrobe", Vector2i(1, 1), KEY_E, "offline %s wardrobe via E" % tier)
		# Invalid overlap should toast reason and keep count.
		var before := _world._furniture.size()
		await _pick_catalog("chair")
		_world.placement._anchor = Vector2i(2, 2) # overlaps bed
		_world.placement._last_reason = FurnitureValidator.Reason.OVERLAP
		_world.placement._valid = false
		ui.place_btn.pressed.emit()
		await get_tree().process_frame
		_assert(_world._furniture.size() == before, "offline %s overlap rejected" % tier)
		_assert(
			FurnitureValidator.reason_text(FurnitureValidator.Reason.OVERLAP) == "Something is already there",
			"offline %s overlap toast copy" % tier
		)
		_world.cancel_placement()
		_world._persist_offline()

	# Persistence across reload of store (last tier's items).
	var store := HouseStore.new(_world._offline_data_dir())
	var hid := store.get_house_id_for_owner("offline_local")
	var reloaded := store.load_house(hid)
	_assert(reloaded != null and reloaded.furniture.size() >= 3, "offline furniture persisted to disk")

	# Rotate (R) + move + remove via UI path.
	await _pick_catalog("sofa")
	_world.placement._anchor = Vector2i(1, 8)
	_world.placement._valid = true
	_world.placement._last_reason = FurnitureValidator.Reason.OK
	var r := InputEventKey.new()
	r.pressed = true
	r.physical_keycode = KEY_R
	_world._unhandled_input(r)
	_assert(_world.placement.rotation_deg == 90, "offline rotate via R key")
	ui.place_btn.pressed.emit()
	await get_tree().process_frame
	var sofa_id := ""
	for iid in _world._furniture.keys():
		if (_world._furniture[iid] as FurnitureVisual).def_id == "sofa":
			sofa_id = iid
			break
	_assert(sofa_id != "", "offline sofa placed")
	if sofa_id != "":
		_world.player.placement_locked = true
		_world.placement.begin_move(_world._furniture[sofa_id])
		_world.placement._anchor = Vector2i(3, 8)
		_world.placement._valid = true
		_world.placement._last_reason = FurnitureValidator.Reason.OK
		# Desktop mouse click confirm while moving.
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		_world._unhandled_input(click)
		await get_tree().process_frame
		_assert((_world._furniture[sofa_id] as FurnitureVisual).cell == Vector2i(3, 8), "offline move via click")
		_world._on_remove_req(sofa_id)
		await get_tree().process_frame
		_assert(not _world._furniture.has(sofa_id), "offline remove")


func _pick_catalog(def_id: String) -> void:
	var ui: HouseUi = _world.ui
	ui.panels.close_all()
	await get_tree().process_frame
	ui.open_catalog()
	await get_tree().process_frame
	_assert(ui.catalog_panel.visible, "catalog open for %s" % def_id)
	var grid: GridContainer = ui.catalog_panel.get_node("Margin/VBox/Grid")
	# Buttons are added after populate; wait one frame for queue_free of old kids.
	await get_tree().process_frame
	var want := FurnitureDB.display_name(def_id)
	var found: Button = null
	for c in grid.get_children():
		if c is Button and (c as Button).text == want:
			found = c as Button
			break
	_assert(found != null, "catalog has button %s" % want)
	if found:
		found.pressed.emit()
	await get_tree().process_frame
	_assert(_world.placement.mode == PlacementController.Mode.PLACE, "catalog pick entered place mode (%s)" % def_id)
	_assert(not ui.catalog_panel.visible, "catalog closed after pick (%s)" % def_id)


func _aim_valid(cell: Vector2i) -> void:
	_world.placement._anchor = cell
	_world.placement._valid = true
	_world.placement._last_reason = FurnitureValidator.Reason.OK
	_world.placement._update_preview_xform()
	_world.placement._tint(true)


func _place_via_catalog_and_place_btn(def_id: String, cell: Vector2i, label: String) -> void:
	var ui: HouseUi = _world.ui
	var before := _world._furniture.size()
	await _pick_catalog(def_id)
	_aim_valid(cell)
	ui.place_btn.pressed.emit()
	await get_tree().process_frame
	_assert(_world.placement.mode == PlacementController.Mode.IDLE, "%s Place button exits mode" % label)
	_assert(_world._furniture.size() == before + 1, "%s furniture spawned" % label)
	_assert(_find_at(def_id, cell), "%s instance at cell" % label)


func _place_via_catalog_and_key(def_id: String, cell: Vector2i, keycode: Key, label: String) -> void:
	var before := _world._furniture.size()
	await _pick_catalog(def_id)
	_aim_valid(cell)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = keycode
	_world._unhandled_input(ev)
	await get_tree().process_frame
	_assert(_world.placement.mode == PlacementController.Mode.IDLE, "%s key confirm exits mode" % label)
	_assert(_world._furniture.size() == before + 1, "%s furniture spawned" % label)
	_assert(_find_at(def_id, cell), "%s instance at cell" % label)


func _find_at(def_id: String, cell: Vector2i) -> bool:
	for iid in _world._furniture.keys():
		var vis: FurnitureVisual = _world._furniture[iid]
		if vis.def_id == def_id and vis.cell == cell:
			return true
	return false


func _run_online() -> void:
	print("-- online UI placement --")
	OS.set_environment("COZY_NET_PORT", str(_port))
	OS.set_environment("COZY_HOUSE_DATA", _data_dir)
	OS.set_environment("COZY_NET_HOST", "127.0.0.1")
	_server = GameServer.new()
	add_child(_server)
	await get_tree().create_timer(0.3).timeout

	NetClient.host = "127.0.0.1"
	NetClient.port = _port
	NetClient.dev_identity = "alice_place"
	NetClient.display_name = "Alice"
	NetClient.connect_to_server()
	var t0 := Time.get_ticks_msec()
	while NetClient.connection_status() != "connected" and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	_assert(NetClient.connection_status() == "connected", "online connected")
	NetClient.enter_own_house()
	t0 = Time.get_ticks_msec()
	while NetClient.current_house.is_empty() and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	_assert(not NetClient.current_house.is_empty(), "online house state")
	_assert(_world.placement.can_decorate, "online owner can_decorate")
	_assert(not _world.is_offline_mode(), "left offline mode online")

	var tier_i := 0
	for tier in HouseLayout.SIZE_ORDER:
		NetClient.set_house_size(tier)
		t0 = Time.get_ticks_msec()
		while str(NetClient.current_house.get("size_tier", "")) != tier and Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
		_assert(str(NetClient.current_house.get("size_tier", "")) == tier, "online size %s" % tier)
		var z_off := tier_i * 3
		await _place_online_via_ui("bed", Vector2i(2, 2 + z_off), "online %s bed" % tier)
		await _place_online_via_ui("table", Vector2i(6, 2 + z_off), "online %s table 2x2" % tier)
		await _place_online_via_ui("coffee_table", Vector2i(9, 2 + z_off), "online %s coffee 2x1" % tier)
		tier_i += 1

	# Persist across server store reload.
	var hid := str(NetClient.current_house.get("house_id", ""))
	var store2 := HouseStore.new(_data_dir)
	var reloaded := store2.load_house(hid)
	_assert(reloaded != null and reloaded.furniture.size() >= 2, "online furniture persisted")

	NetClient.disconnect_from_server()
	await get_tree().create_timer(0.2).timeout
	if _server:
		_server.queue_free()
		_server = null


func _place_online_via_ui(def_id: String, cell: Vector2i, label: String) -> void:
	var ui: HouseUi = _world.ui
	var before_rev := NetClient.revision
	var before_count := _world._furniture.size()
	await _pick_catalog(def_id)
	_aim_valid(cell)
	ui.place_btn.pressed.emit()
	var t0 := Time.get_ticks_msec()
	while NetClient.revision <= before_rev and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	_assert(NetClient.revision > before_rev, "%s server ack revision" % label)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(_world._furniture.size() >= before_count + 1, "%s furniture visible" % label)
