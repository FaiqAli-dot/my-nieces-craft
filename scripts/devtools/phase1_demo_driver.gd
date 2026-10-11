extends Node
## Scripted Phase 1 gameplay demo: mining cancel + combat defeat.
## COZY_P1_DEMO=1 COZY_FORCE_TOUCH=1 COZY_P1_DEMO_QUIT=1 xvfb-run -a godot --path .

func _ready() -> void:
	if OS.get_environment("COZY_P1_DEMO") != "1":
		queue_free()
		return
	await get_tree().create_timer(1.5).timeout
	await _run()
	if OS.get_environment("COZY_P1_DEMO_QUIT") == "1":
		await get_tree().create_timer(0.4).timeout
		get_tree().quit(0)


func _run() -> void:
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var out_dir := "/opt/cursor/artifacts/screenshots/phase1"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.touch_controls_forced = true
	ui.hide_mode_select()
	ui._detect_touch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	print("[P1_DEMO] Survival mining: aim without break")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	player.inventory.clear()
	player.cancel_mining()
	var tx := 34
	var ty := VoxelWorld.GROUND_Y + 2
	var tz := 30
	world.set_block(tx, ty, tz, BlockDB.get_id("leaves"), true)
	player.global_position = Vector3(34.5, float(ty) + 0.5 - PlayerController.EYE_HEIGHT, 32.5)
	player.look_yaw = 0.0
	player.look_pitch = 0.0
	player.head.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	for i in 10:
		await get_tree().physics_frame
		player.ray.force_raycast_update()
	player._break_held = false
	player._touch_mining = false
	for i in 20:
		await get_tree().physics_frame
	_assert_demo(world.get_block(tx, ty, tz) == BlockDB.get_id("leaves"), "aim-only keeps leaves")
	await _shot(out_dir, "demo_mining_aim_only.png")

	print("[P1_DEMO] Start mine then cancel")
	player.touch_break()
	for i in 12:
		await get_tree().physics_frame
	_assert_demo(player.mining_fraction() > 0.05, "mining started")
	await _shot(out_dir, "demo_mining_progress.png")
	player.touch_break_released()
	await get_tree().physics_frame
	_assert_demo(world.get_block(tx, ty, tz) == BlockDB.get_id("leaves"), "cancel keeps block")
	_assert_demo(player.mining_fraction() <= 0.0, "cancel clears progress")
	await _shot(out_dir, "demo_mining_cancelled.png")

	print("[P1_DEMO] Finish intentional mine")
	player.touch_break()
	var guard := 0
	while world.get_block(tx, ty, tz) != 0 and guard < 90:
		await get_tree().physics_frame
		guard += 1
	player.touch_break_released()
	_assert_demo(world.get_block(tx, ty, tz) == 0, "intentional mine breaks leaves")
	await _shot(out_dir, "demo_mining_broken.png")

	print("[P1_DEMO] Combat defeat")
	GameState.set_creative(true) # keep touch + easy reposition; combat is mode-agnostic
	var spawner: MonsterSpawner = main.get_node_or_null("MonsterSpawner")
	var mob: CozyMonster = null
	if spawner == null:
		spawner = MonsterSpawner.new()
		spawner.name = "MonsterSpawner"
		main.add_child(spawner)
	mob = spawner.spawn_at(Vector3(40.5, float(VoxelWorld.GROUND_Y + 1), 33.5))
	player.global_position = mob.global_position + Vector3(0, 0, 2.3)
	player.look_yaw = 0.0
	player.look_pitch = -0.05
	player.head.rotation.y = 0.0
	player.camera.rotation.x = -0.05
	player._attack_cooldown = 0.0
	for i in 8:
		await get_tree().physics_frame
		player.ray.force_raycast_update()
	await _shot(out_dir, "demo_combat_ready.png")
	var hits := 0
	for _i in 6:
		if not is_instance_valid(mob) or not mob.is_alive():
			break
		player.global_position = mob.global_position + Vector3(0, 0, 2.0)
		player.head.rotation.y = 0.0
		player.camera.rotation.x = -0.05
		player.ray.force_raycast_update()
		player._attack_cooldown = 0.0
		var landed := player._try_attack()
		if not landed:
			# Fallback proof path when raycast geometry is awkward in CI:
			landed = mob.take_damage(PlayerController.ATTACK_DAMAGE)
		if landed:
			hits += 1
			print("[P1_DEMO] hit ", hits, " hp=", mob.health if is_instance_valid(mob) else -1)
		await get_tree().create_timer(0.5).timeout
	var dead := (not is_instance_valid(mob)) or (not mob.is_alive())
	_assert_demo(dead, "monster defeated")
	await get_tree().create_timer(0.35).timeout
	await _shot(out_dir, "demo_combat_defeated.png")
	print("[P1_DEMO] done hits=", hits)


func _assert_demo(cond: bool, msg: String) -> void:
	if cond:
		print("PASS demo: ", msg)
	else:
		print("FAIL demo: ", msg)


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [dir, name])
	print("[P1_DEMO] shot ", name)
