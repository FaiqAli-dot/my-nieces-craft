extends Node
## Capture polished mobile HUD at phone / tablet landscape sizes.
## COZY_MOBILE_HUD_SHOTS=1 COZY_FORCE_TOUCH=1 COZY_SAFE_INSET=48,12,48,28 \
##   godot --path . --resolution WxH ...

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

	player.global_position = Vector3(28, 7.5, 46)
	player.look_yaw = 0.15
	player.look_pitch = -0.24
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch

	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "/opt/cursor/artifacts/screenshots/mobile_hud"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var label := OS.get_environment("COZY_SHOT_LABEL")
	if label == "":
		var vp := get_viewport().get_visible_rect().size
		label = "hud_%dx%d" % [int(vp.x), int(vp.y)]

	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("[MOBILE_HUD] ", path)
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)
