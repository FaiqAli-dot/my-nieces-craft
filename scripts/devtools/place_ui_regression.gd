extends Node
## Regression: place wood through real GUI/input paths (not world.set_block).
## Run: COZY_PLACE_UI_TEST=1 godot --path . --resolution 1280x720 \
##   --rendering-method gl_compatibility --rendering-driver opengl3

var _pass := 0
var _fail := 0

func _ready() -> void:
	if OS.get_environment("COZY_PLACE_UI_TEST") != "1":
		queue_free()
		return
	await get_tree().create_timer(2.0).timeout
	await _run()
	print("=== PLACE UI Results: %d passed, %d failed ===" % [_pass, _fail])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(1 if _fail > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("PASS: ", msg)
	else:
		_fail += 1
		print("FAIL: ", msg)


func _run() -> void:
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5

	# Crosshair must ignore mouse (root cause of desktop place/break failing).
	var cross: Control = ui.get_node_or_null("Root/Crosshair")
	_assert(cross != null, "crosshair node exists")
	_assert(cross != null and cross.mouse_filter == Control.MOUSE_FILTER_IGNORE, "crosshair mouse_filter ignore")

	# No STOP control may cover the captured-mouse center.
	var blocking := false
	for n in _all(ui):
		if n is Control:
			var c := n as Control
			if not c.is_visible_in_tree():
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			if c.get_global_rect().has_point(center):
				print("FAIL detail: blocking control ", c.get_path())
				blocking = true
	_assert(not blocking, "no HUD control blocks screen center")

	# Select wood via hotbar UI button (slot 4).
	GameState.touch_controls_forced = false
	ui.touch_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var wood_btn: Button = ui.hotbar.get_child(4) as Button
	wood_btn.pressed.emit()
	await get_tree().process_frame
	_assert(player.inventory.selected == 4, "hotbar UI selected slot 4")
	_assert(player.inventory.selected_item() == "wood", "hotbar UI selected wood")

	# Aim at ground ahead of spawn.
	player.global_position = Vector3(32.5, float(VoxelWorld.GROUND_Y + 1), 28.5)
	player.look_yaw = 0.0
	player.look_pitch = -0.45
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch
	for i in 8:
		await get_tree().physics_frame
	var p := player.get_place_pos()
	_assert(p.x != -9999, "raycast has place position")
	_assert(player.world.can_place_at(p.x, p.y, p.z, player.player_aabb()), "place cell is free")
	if p.x != -9999 and player.world.get_block(p.x, p.y, p.z) != 0:
		player.world.set_block(p.x, p.y, p.z, 0, true)
		for i in 3:
			await get_tree().physics_frame
		p = player.get_place_pos()

	# Desktop path: real push_input right-click at screen center (captured mouse).
	var before := player.world.get_block(p.x, p.y, p.z)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ev.position = center
	ev.global_position = center
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
	vp.push_input(ev, false)
	await get_tree().process_frame
	await get_tree().physics_frame
	var after_rc := player.world.get_block(p.x, p.y, p.z)
	_assert(after_rc == BlockDB.get_id("wood"), "right-click push_input placed wood")
	print("[PLACE_UI] rclick cell=", p, " before=", before, " after=", after_rc)

	# Clear and test touch Place button path.
	if after_rc != 0:
		player.world.set_block(p.x, p.y, p.z, 0, true)
	GameState.touch_controls_forced = true
	ui.touch_layer.visible = true
	for i in 5:
		await get_tree().physics_frame
	p = player.get_place_pos()
	_assert(p.x != -9999 and player.world.get_block(p.x, p.y, p.z) == 0, "cell clear for touch place")
	var place_btn: BaseButton = null
	if ui.touch_controls and ui.touch_controls.has_method("get_action_button"):
		place_btn = ui.touch_controls.get_action_button("place")
	if place_btn == null:
		place_btn = ui.touch_layer.find_child("PlaceButton", true, false) as BaseButton
	_assert(place_btn != null, "Place touch button exists")
	if place_btn:
		# Prefer ActionButton signal path (pressed visual + gameplay).
		if place_btn.has_signal("action_pressed"):
			place_btn.emit_signal("action_pressed")
		else:
			place_btn.pressed.emit()
		await get_tree().process_frame
		await get_tree().physics_frame
	var after_touch := player.world.get_block(p.x, p.y, p.z) if p.x != -9999 else 0
	_assert(after_touch == BlockDB.get_id("wood"), "Place button placed wood")

	# Screenshot proof of UI-placed wood.
	var shot_dir := OS.get_environment("COZY_SHOT_DIR")
	if shot_dir == "":
		shot_dir = "/opt/cursor/artifacts/screenshots/phase1_5_final"
	DirAccess.make_dir_recursive_absolute(shot_dir)
	# Frame the placed block
	if p.x != -9999:
		player.global_position = Vector3(float(p.x) + 2.8, float(VoxelWorld.GROUND_Y) + 2.2, float(p.z) + 3.2)
		var look_at := Vector3(float(p.x) + 0.5, float(p.y) + 0.5, float(p.z) + 0.5)
		var to := look_at - player.global_position
		player.look_yaw = atan2(-to.x, -to.z)
		player.look_pitch = -0.25
		player.head.rotation.y = player.look_yaw
		player.camera.rotation.x = player.look_pitch
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := shot_dir.path_join("12_place_wood_via_ui.png")
	img.save_png(path)
	print("[PLACE_UI] screenshot ", path)


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
