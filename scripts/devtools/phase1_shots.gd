extends Node
## Phase 1 evidence shots: flight joystick stability + combat presence.
## COZY_P1_SHOTS=1 COZY_FORCE_TOUCH=1 COZY_P1_SHOTS_QUIT=1 xvfb-run -a godot --path .

const SIZES := [
	{"name": "phone_1792x828", "size": Vector2i(1792, 828), "inset": "48,0,48,21"},
	{"name": "tablet_2048x1536", "size": Vector2i(2048, 1536), "inset": "24,20,24,24"},
]

func _ready() -> void:
	if OS.get_environment("COZY_P1_SHOTS") != "1":
		queue_free()
		return
	await get_tree().create_timer(1.4).timeout
	await _run()
	if OS.get_environment("COZY_P1_SHOTS_QUIT") == "1":
		get_tree().quit(0)


func _run() -> void:
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "/opt/cursor/artifacts/screenshots/phase1"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.touch_controls_forced = true
	GameState.set_creative(true)
	ui.hide_mode_select()
	ui._detect_touch()
	player.global_position = Vector3(36.5, float(VoxelWorld.GROUND_Y + 1), 32.5)
	player.look_yaw = -0.6
	player.look_pitch = -0.15
	player.head.rotation.y = player.look_yaw
	player.camera.rotation.x = player.look_pitch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame

	var cluster_dir := out_dir.path_join("action_cluster")
	DirAccess.make_dir_recursive_absolute(cluster_dir)
	for spec in SIZES:
		get_window().size = spec["size"]
		OS.set_environment("COZY_SAFE_INSET", str(spec["inset"]))
		await get_tree().process_frame
		ui._detect_touch()
		if ui.touch_controls:
			ui.touch_controls._on_viewport_resized()
		ui._layout_hotbar()
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(out_dir, "%s_flight_off.png" % spec["name"])
		await _shot(cluster_dir, "%s_flight_off.png" % spec["name"])
		GameState.set_flying(true)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(out_dir, "%s_flight_on.png" % spec["name"])
		await _shot(cluster_dir, "%s_flight_on.png" % spec["name"])
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await _shot(out_dir, "%s_flight_off_again.png" % spec["name"])
		await _shot(cluster_dir, "%s_flight_off_again.png" % spec["name"])

	# Combat presence: face a gloomlet and capture.
	GameState.set_creative(true)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var spawner: MonsterSpawner = main.get_node_or_null("MonsterSpawner")
	var mob: CozyMonster = null
	if spawner:
		for c in spawner.get_children():
			if c is CozyMonster and (c as CozyMonster).is_alive():
				mob = c
				break
	if mob:
		# Clear voxels between camera and mob so the attack ray is unobstructed.
		var mp := mob.global_position
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				world_clear_column(main.get_node("VoxelWorld"), int(mp.x) + dx, int(mp.z) + dz)
		player.global_position = mp + Vector3(0, 0, 2.4)
		player.look_yaw = 0.0
		player.look_pitch = -0.05
		player.head.rotation.y = 0.0
		player.camera.rotation.x = -0.05
		player._attack_cooldown = 0.0
		for i in 8:
			await get_tree().physics_frame
			player.ray.force_raycast_update()
		await _shot(out_dir, "combat_gloomlet_before_attack.png")
		var before_hp := mob.health
		var hit := player._try_attack()
		print("[P1_SHOTS] combat hit=", hit, " hp ", before_hp, "→", mob.health)
		# Capture during hurt flash window.
		await get_tree().create_timer(0.05).timeout
		await _shot(out_dir, "combat_gloomlet_after_hit.png")
	print("[P1_SHOTS] wrote ", out_dir)


func world_clear_column(world: VoxelWorld, x: int, z: int) -> void:
	for y in range(VoxelWorld.GROUND_Y + 1, VoxelWorld.GROUND_Y + 4):
		if world.get_block(x, y, z) != 0:
			world.set_block(x, y, z, 0, true)


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [dir, name]
	img.save_png(path)
	print("[P1_SHOTS] ", path)
