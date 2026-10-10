extends Node
## Capture polished mobile HUD at phone / tablet landscape sizes.
## COZY_MOBILE_HUD_SHOTS=1 COZY_FORCE_TOUCH=1 COZY_SAFE_INSET=48,12,48,28 \
##   COZY_SHOT_LABEL=phone_hud godot --path . --resolution WxH ...
## Optional: COZY_SHOT_MODE=pressed|joystick

func _ready() -> void:
	if OS.get_environment("COZY_MOBILE_HUD_SHOTS") != "1":
		queue_free()
		return
	GameState.touch_controls_forced = true
	await get_tree().create_timer(2.0).timeout
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	ui._detect_touch()
	ui._layout_hotbar()
	if ui.touch_controls:
		ui.touch_controls._on_viewport_resized()

	# Clear meadow view: spawn-ish, facing the warm playhouse / build pad (not into trees).
	player.global_position = Vector3(32.5, float(VoxelWorld.GROUND_Y) + 1.7, 44.0)
	var look_at := Vector3(36.5, float(VoxelWorld.GROUND_Y) + 2.2, 36.5)
	var to := look_at - player.global_position
	player.look_yaw = atan2(-to.x, -to.z)
	player.look_pitch = -0.18
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch

	var mode := OS.get_environment("COZY_SHOT_MODE")
	if mode == "pressed" and ui.touch_controls and ui.touch_controls.actions:
		ui.touch_controls.actions.jump_btn.set_pressed_visual(true)
		ui.touch_controls.actions.place_btn.set_pressed_visual(true)
		ui.touch_controls.actions.break_btn.set_pressed_visual(true)
		if ui.touch_controls.actions.craft_btn.visible:
			ui.touch_controls.actions.craft_btn.set_pressed_visual(true)
	elif mode == "joystick" and ui.touch_controls and ui.touch_controls.joystick:
		var joy: VirtualJoystick = ui.touch_controls.joystick
		# Non-default spawn: upper-middle of the left zone (not the rest hint).
		var spawn := Vector2(joy.size.x * 0.55, joy.size.y * 0.38)
		joy.simulate_touch(0, spawn, true)
		joy.simulate_drag(0, spawn + Vector2(48, -36))
		if player:
			player.set_touch_move(joy.get_vector())

	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "/opt/cursor/artifacts/screenshots/mobile_hud"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var label := OS.get_environment("COZY_SHOT_LABEL")
	if label == "":
		var vp := get_viewport().get_visible_rect().size
		label = "hud_%dx%d" % [int(vp.x), int(vp.y)]

	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("[MOBILE_HUD] ", path)
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)
