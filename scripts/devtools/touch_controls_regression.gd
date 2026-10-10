extends Node
## Automated touch HUD regression: multitouch indices, joystick, look, actions, layout.
## Run: COZY_TOUCH_TEST=1 COZY_FORCE_TOUCH=1 godot --path . --resolution 1280x720 \
##   --rendering-method gl_compatibility --rendering-driver opengl3

var _pass := 0
var _fail := 0

func _ready() -> void:
	if OS.get_environment("COZY_TOUCH_TEST") != "1":
		queue_free()
		return
	await get_tree().create_timer(2.0).timeout
	await _run()
	print("=== TOUCH Results: %d passed, %d failed ===" % [_pass, _fail])
	await get_tree().create_timer(0.2).timeout
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
	GameState.touch_controls_forced = true
	ui._detect_touch()
	await get_tree().process_frame

	_assert(ui.touch_controls != null and ui.touch_controls.visible, "touch controls visible")
	var joy: TouchJoystick = ui.touch_controls.joystick
	var look: LookArea = ui.touch_controls.look_area
	var actions: TouchActionCluster = ui.touch_controls.actions
	_assert(joy != null and look != null and actions != null, "joystick/look/actions exist")

	# Crosshair / non-interactive decorations must not STOP center clicks.
	var cross: Control = ui.get_node_or_null("Root/Crosshair")
	_assert(cross != null and cross.mouse_filter == Control.MOUSE_FILTER_IGNORE, "crosshair ignores mouse")
	var center := get_viewport().get_visible_rect().size * 0.5
	var blocking := false
	for n in _all(ui):
		if n is Control:
			var c := n as Control
			if not c.is_visible_in_tree():
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			# Interactive touch widgets may exist, but must not cover dead-center play area.
			if c is TouchJoystick or c is LookArea or c is ActionButton or c is TouchHotbar or c is TouchActionCluster:
				continue
			if c.get_global_rect().has_point(center):
				print("FAIL detail: blocking ", c.get_path(), " filter=", c.mouse_filter)
				blocking = true
	_assert(not blocking, "no unexpected HUD control blocks screen center")

	# Floating joystick: spawn at several zone positions; release → zero + rest hint.
	_assert(joy.floating_mode, "joystick floating_mode enabled")
	player.set_touch_move(Vector2.ZERO)
	var spawn_locals: Array[Vector2] = [
		Vector2(joy.size.x * 0.25, joy.size.y * 0.35),
		Vector2(joy.size.x * 0.55, joy.size.y * 0.45),
		Vector2(joy.size.x * 0.35, joy.size.y * 0.65),
	]
	for sp in spawn_locals:
		joy.simulate_touch(0, sp, true)
		await get_tree().process_frame
		_assert(joy.is_active(), "zone touch spawns stick at %s" % sp)
		_assert(joy.visual_center().distance_to(sp) < joy.base_diameter * 0.55, "base centered near %s" % sp)
		joy.simulate_drag(0, sp + Vector2(40, 0))
		await get_tree().process_frame
		_assert(player.touch_move.x > 0.2, "floating drag +x from %s" % sp)
		joy.simulate_touch(0, sp, false)
		await get_tree().process_frame
		_assert(player.touch_move == Vector2.ZERO, "release clears move from %s" % sp)
		_assert(joy.visual_center().distance_to(joy.rest_center()) < 2.0, "rest hint after %s" % sp)

	var joy_spawn := Vector2(joy.size.x * 0.4, joy.size.y * 0.5)
	joy.simulate_touch(0, joy_spawn, true)
	joy.simulate_drag(0, joy_spawn + Vector2(0, 40))
	await get_tree().process_frame
	_assert(player.touch_move.y > 0.2, "joystick down moves +y")
	joy.simulate_drag(0, joy_spawn + Vector2(-40, -40))
	await get_tree().process_frame
	_assert(player.touch_move.x < -0.15 and player.touch_move.y < -0.15, "joystick diagonal NW")
	joy.simulate_touch(0, joy_spawn, false)
	await get_tree().process_frame
	_assert(player.touch_move == Vector2.ZERO, "joystick release clears move")

	# Look: separate finger index 1 while joystick uses index 0.
	var yaw0 := player.look_yaw
	var pitch0 := player.look_pitch
	joy.simulate_touch(0, joy_spawn + Vector2(30, 0), true)
	joy.simulate_drag(0, joy_spawn + Vector2(50, 0))
	look.simulate_touch(1, look.size * 0.5, true)
	look.simulate_drag(1, Vector2(40, -20))
	# Apply look in physics.
	for i in 3:
		await get_tree().physics_frame
	_assert(player.touch_move.x > 0.1, "multitouch: move continues with look finger")
	_assert(absf(player.look_yaw - yaw0) > 0.0001 or absf(player.look_pitch - pitch0) > 0.0001, "multitouch: look rotates independently")
	# Look release stops further deltas; move still held.
	look.simulate_touch(1, look.size * 0.5, false)
	var yaw1 := player.look_yaw
	look.simulate_drag(1, Vector2(80, 0)) # should be ignored — wrong/no index
	for i in 2:
		await get_tree().physics_frame
	_assert(is_equal_approx(player.look_yaw, yaw1), "look release ignores further drag")
	joy.simulate_touch(0, joy_spawn, false)
	await get_tree().process_frame
	_assert(player.touch_move == Vector2.ZERO, "move finger release clears after multitouch")

	# Action buttons invoke real gameplay APIs.
	player.global_position = Vector3(32.5, float(VoxelWorld.GROUND_Y + 1), 28.5)
	player.look_yaw = 0.0
	player.look_pitch = -0.45
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch
	player.velocity = Vector3.ZERO
	for i in 6:
		await get_tree().physics_frame

	var on_floor := player.is_on_floor()
	_assert(on_floor, "player on floor for jump test")
	var y0 := player.global_position.y
	actions.jump_btn.action_pressed.emit()
	await get_tree().physics_frame
	_assert(player.velocity.y > 0.5 or player.global_position.y > y0, "Jump button applies jump velocity")

	player.inventory.select(4) # wood
	ui.refresh_hotbar()
	var p := player.get_place_pos()
	if p.x != -9999 and player.world.get_block(p.x, p.y, p.z) != 0:
		player.world.set_block(p.x, p.y, p.z, 0, true)
		for i in 3:
			await get_tree().physics_frame
		p = player.get_place_pos()
	_assert(p.x != -9999, "place raycast valid")
	actions.place_btn.action_pressed.emit()
	await get_tree().process_frame
	await get_tree().physics_frame
	_assert(player.world.get_block(p.x, p.y, p.z) == BlockDB.get_id("wood"), "Place button places wood")

	actions.break_btn.action_pressed.emit()
	await get_tree().process_frame
	await get_tree().physics_frame
	_assert(player.world.get_block(p.x, p.y, p.z) == 0, "Break button breaks block")

	var craft_was := ui.craft_panel.visible
	actions.craft_btn.action_pressed.emit()
	await get_tree().process_frame
	_assert(ui.craft_panel.visible != craft_was or ui.craft_panel.visible, "Craft button toggles craft UI")
	if ui.craft_panel.visible:
		ui.toggle_craft()

	# Hotbar select
	var slot := ui.hotbar_tray.get_slot_button(2)
	_assert(slot != null, "hotbar slot 2 exists")
	slot.pressed.emit()
	await get_tree().process_frame
	_assert(player.inventory.selected == 2, "hotbar selects slot 2")

	# Layout: left move zone, look/actions/hotbar/top chips outside it.
	ui.touch_controls._on_viewport_resized()
	ui._layout_hotbar()
	await get_tree().process_frame
	await get_tree().process_frame
	var vp_rect := get_viewport().get_visible_rect()
	var joy_r := joy.get_global_rect()
	var act_r := actions.get_global_rect()
	var hot_r := ui.hotbar_tray.get_global_rect()
	var look_r := look.get_global_rect()
	print("[TOUCH] layout vp=", vp_rect, " joy=", joy_r, " actions=", act_r, " hotbar=", hot_r)
	_assert(joy_r.size.x > 8.0 and joy_r.size.y > 8.0, "joystick has nonzero size")
	_assert(act_r.size.x > 8.0 and act_r.size.y > 8.0, "actions have nonzero size")
	_assert(vp_rect.encloses(joy_r.grow(-4)), "joystick inside viewport")
	_assert(vp_rect.encloses(act_r.grow(-4)), "actions inside viewport")
	_assert(vp_rect.encloses(hot_r.grow(-4)), "hotbar inside viewport")
	_assert(joy_r.position.x < vp_rect.size.x * 0.45, "joystick on left half")
	_assert(joy_r.end.x <= vp_rect.size.x * 0.50 + 2.0, "move zone ≤ left half")
	_assert(act_r.position.x > vp_rect.size.x * 0.45, "actions on right half")
	_assert(not joy_r.grow(-2).intersects(act_r.grow(-2)), "joystick and actions do not overlap")
	_assert(not joy_r.grow(-2).intersects(look_r.grow(-2)), "move zone does not overlap look area")
	_assert(not joy_r.grow(-2).intersects(hot_r.grow(-2)), "move zone does not overlap hotbar")
	for chip in [ui.mode_btn, ui.bag_btn, ui.craft_top_btn, ui.menu_btn]:
		if chip == null:
			continue
		var cr: Rect2 = chip.get_global_rect()
		_assert(not joy_r.grow(-2).intersects(cr.grow(-2)), "move zone misses top chip %s" % chip.name)
	for btn in [actions.jump_btn, actions.break_btn, actions.place_btn, actions.craft_btn]:
		if btn == null or not btn.visible:
			continue
		_assert(not joy_r.grow(-2).intersects(btn.get_global_rect().grow(-2)), "move zone misses action %s" % btn.name)

	# Joystick must not start look; look finger must not move joystick.
	joy.simulate_touch(0, joy_spawn, false)
	look.simulate_touch(1, look.size * 0.5, false)
	player.set_touch_move(Vector2.ZERO)
	look.simulate_touch(2, look.size * 0.5, true)
	look.simulate_drag(2, Vector2(30, 0))
	await get_tree().process_frame
	_assert(player.touch_move == Vector2.ZERO, "look finger does not set move vector")
	_assert(not joy.is_active(), "look finger does not spawn joystick")
	look.simulate_touch(2, look.size * 0.5, false)

	# Action / hotbar presses must not leave the stick active.
	actions.jump_btn.action_pressed.emit()
	await get_tree().process_frame
	_assert(not joy.is_active(), "jump press does not spawn joystick")
	var slot1 := ui.hotbar_tray.get_slot_button(1)
	if slot1:
		slot1.pressed.emit()
		await get_tree().process_frame
	_assert(not joy.is_active(), "hotbar tap does not spawn joystick")

	print("[TOUCH] multitouch simulated with distinct ScreenTouch/ScreenDrag indices 0/1/2")


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
