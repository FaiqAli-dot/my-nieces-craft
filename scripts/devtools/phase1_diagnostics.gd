extends Node
## Phase 1 root-cause diagnostics (not part of the acceptance suite).
## Run: COZY_P1_DIAG=1 COZY_FORCE_TOUCH=1 COZY_NET_AUTOSTART=0 \
##   xvfb-run -a godot --path . --resolution 1280x720 \
##   --rendering-method gl_compatibility --rendering-driver opengl3

func _ready() -> void:
	if OS.get_environment("COZY_P1_DIAG") != "1":
		queue_free()
		return
	await get_tree().create_timer(1.5).timeout
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	GameState.touch_controls_forced = true
	ui._detect_touch()
	await get_tree().process_frame

	print("=== P1 DIAG: monster / combat inventory ===")
	print("monster scripts: none (grep confirmed empty)")
	print("player has touch_break=", player.has_method("touch_break"))
	print("player has attack method=", player.has_method("attack") or player.has_method("try_attack"))

	print("=== P1 DIAG: look/LMB → survival mining ===")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	player.inventory.clear()
	player.cancel_mining()
	# Stand and aim at a soft leaves block so a short hold would finish.
	var tx := 34
	var ty := VoxelWorld.GROUND_Y + 2
	var tz := 30
	world.set_block(tx, ty, tz, BlockDB.get_id("leaves"), true)
	player.global_position = Vector3(34.5, float(VoxelWorld.GROUND_Y + 1), 28.5)
	player.look_yaw = 0.0
	player.look_pitch = -0.35
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 8:
		await get_tree().physics_frame
	var target := player.get_target_block()
	print("target=", target, " expected≈", Vector3i(tx, ty, tz), " block=", world.get_block(tx, ty, tz))
	print("before: break_held=", player._break_held, " touch_mining=", player._touch_mining, " frac=", player.mining_fraction())

	# Path A: only look around via LookArea mouse (emulated touch path).
	var look: LookArea = ui.touch_controls.look_area
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = look.get_global_rect().get_center()
	# Deliver through viewport so PlayerController._input sees break_block.
	Input.parse_input_event(mb)
	await get_tree().process_frame
	print("after LMB parse: break_held=", player._break_held, " action_pressed=", Input.is_action_pressed("break_block"), " frac=", player.mining_fraction())

	# Hold ~0.4s (leaves hand mine ≈ 0.3s).
	for i in 30:
		await get_tree().physics_frame
	print("after hold frames: frac=", player.mining_fraction(), " block=", world.get_block(tx, ty, tz), " break_held=", player._break_held)

	var mb_up := InputEventMouseButton.new()
	mb_up.button_index = MOUSE_BUTTON_LEFT
	mb_up.pressed = false
	mb_up.position = mb.position
	Input.parse_input_event(mb_up)
	await get_tree().process_frame
	player.cancel_mining()

	# Path B: targeting alone must not mine.
	world.set_block(tx, ty, tz, BlockDB.get_id("leaves"), true)
	player._break_held = false
	player._touch_mining = false
	for i in 20:
		await get_tree().physics_frame
	print("aim-only (no hold): frac=", player.mining_fraction(), " block=", world.get_block(tx, ty, tz), " break_held=", player._break_held)

	# Path C: LookArea.accept_event does not stop captured _input
	print("=== P1 DIAG: captured _input vs LookArea ===")
	print("mouse_mode=", Input.mouse_mode, " emulate_mouse_from_touch default typically true")

	print("=== P1 DIAG: joystick rect across flight toggles ===")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	GameState.set_flying(false)
	ui._detect_touch()
	ui._layout_fly_controls()
	await get_tree().process_frame
	await get_tree().process_frame
	var joy: TouchJoystick = ui.touch_controls.joystick
	var sizes := [Vector2i(1280, 720), Vector2i(1792, 828), Vector2i(2048, 1536)]
	for sz in sizes:
		get_window().size = sz
		OS.set_environment("COZY_SAFE_INSET", "48,0,48,21")
		await get_tree().process_frame
		ui._detect_touch()
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		var r0 := joy.get_global_rect()
		var rest0 := joy.rest_center()
		var vis0 := joy.visual_center()
		var anchors0 := [joy.anchor_left, joy.anchor_top, joy.anchor_right, joy.anchor_bottom]
		var offsets0 := [joy.offset_left, joy.offset_top, joy.offset_right, joy.offset_bottom]
		print("SIZE ", sz, " landed joy_rect=", r0, " rest=", rest0, " vis=", vis0, " anchors=", anchors0, " offsets=", offsets0)
		GameState.set_flying(true)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		var r1 := joy.get_global_rect()
		var rest1 := joy.rest_center()
		var vis1 := joy.visual_center()
		var anchors1 := [joy.anchor_left, joy.anchor_top, joy.anchor_right, joy.anchor_bottom]
		var offsets1 := [joy.offset_left, joy.offset_top, joy.offset_right, joy.offset_bottom]
		print("SIZE ", sz, " flying  joy_rect=", r1, " rest=", rest1, " vis=", vis1, " anchors=", anchors1, " offsets=", offsets1)
		print("SIZE ", sz, " delta_pos=", r1.position - r0.position, " delta_size=", r1.size - r0.size, " rest_delta=", rest1 - rest0, " vis_delta=", vis1 - vis0)
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		var r2 := joy.get_global_rect()
		print("SIZE ", sz, " re-land joy_rect=", r2, " delta_from_first=", r2.position - r0.position, " size_delta=", r2.size - r0.size)

	print("=== P1 DIAG DONE ===")
