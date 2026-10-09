extends Node
## Phase 1.5 screenshot harness — same viewpoints as Phase 1 plus garden extras.

@onready var main := get_parent()

func _ready() -> void:
	if OS.get_environment("COZY_SCREENSHOTS") != "1":
		queue_free()
		return
	GameState.touch_controls_forced = true
	await get_tree().create_timer(2.2).timeout
	await _capture_all()
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)


func _aim(player: PlayerController, pos: Vector3, yaw: float, pitch: float) -> void:
	player.global_position = pos
	player.look_yaw = yaw
	player.look_pitch = pitch
	player.head.rotation.y = yaw
	player.camera.rotation.x = pitch


func _capture_all() -> void:
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	ui._detect_touch()
	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "user://screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var world: VoxelWorld = main.get_node("VoxelWorld")
	var showcase: Node3D = main.get_node("Showcase")

	# 01 main meadow — mid overview showing path, sand, trees, knoll (not washed sky)
	_aim(player, Vector3(29, 7.2, 44), 0.2, -0.22)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir.path_join("01_main_building_area.png"))

	# Compact playhouse: warm planks + wood trim + leaf roof (reads clearly with face shade)
	var wood := BlockDB.get_id("wood")
	var planks := BlockDB.get_id("planks")
	var leaves := BlockDB.get_id("leaves")
	var glass := BlockDB.get_id("glass")
	var wool := BlockDB.get_id("wool_pink")
	for x in range(35, 39):
		for z in range(35, 39):
			world.set_block(x, VoxelWorld.GROUND_Y + 1, z, planks, true)
	for y in range(VoxelWorld.GROUND_Y + 2, VoxelWorld.GROUND_Y + 5):
		for x in range(35, 39):
			world.set_block(x, y, 35, planks, true)
			world.set_block(x, y, 38, planks, true)
		for z in range(35, 39):
			world.set_block(35, y, z, wood, true)
			world.set_block(38, y, z, wood, true)
	for x in range(35, 39):
		for z in range(35, 39):
			world.set_block(x, VoxelWorld.GROUND_Y + 5, z, leaves, true)
	world.set_block(36, VoxelWorld.GROUND_Y + 2, 35, 0, true)
	world.set_block(37, VoxelWorld.GROUND_Y + 2, 35, 0, true)
	world.set_block(36, VoxelWorld.GROUND_Y + 3, 35, 0, true)
	world.set_block(37, VoxelWorld.GROUND_Y + 3, 35, 0, true)
	world.set_block(38, VoxelWorld.GROUND_Y + 3, 36, glass, true)
	world.set_block(38, VoxelWorld.GROUND_Y + 3, 37, glass, true)
	world.set_block(35, VoxelWorld.GROUND_Y + 2, 35, wool, true)

	var house_center := Vector3(37, 6.8, 37)
	var cam_pos := Vector3(42, 7.4, 44)
	var dir := (house_center - cam_pos).normalized()
	var yaw := atan2(-dir.x, -dir.z)
	_aim(player, cam_pos, yaw, -0.22)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir.path_join("02_built_structure.png"))

	# Garden / animals — close eye-level framing of the pen
	var base := showcase.global_position
	_aim(player, base + Vector3(0.0, 1.85, 6.0), 0.0, -0.05)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir.path_join("04_showcase_animals.png"))

	# Flower nook
	_aim(player, base + Vector3(-6, 2.4, 12), 0.0, -0.2)
	await get_tree().process_frame
	await _shot(out_dir.path_join("03_showcase_environment.png"))

	# Sitting corner
	_aim(player, base + Vector3(6, 2.4, 12), 0.0, -0.2)
	await get_tree().process_frame
	await _shot(out_dir.path_join("05_showcase_furniture.png"))

	# Block palette
	_aim(player, base + Vector3(0, 2.5, 18), 0.0, -0.25)
	await get_tree().process_frame
	await _shot(out_dir.path_join("06_showcase_materials.png"))

	# Crafting UI
	_aim(player, cam_pos, yaw, -0.3)
	ui.toggle_craft()
	await get_tree().process_frame
	await _shot(out_dir.path_join("07_crafting_ui.png"))
	ui.toggle_craft()

	ui._detect_touch()
	await get_tree().process_frame
	await _shot(out_dir.path_join("08_touch_controls.png"))

	# Extra: path / meadow overview
	_aim(player, Vector3(26, 9.0, 48), 0.35, -0.35)
	await get_tree().process_frame
	await _shot(out_dir.path_join("09_meadow_path_overview.png"))

	# Extra: garden wide
	_aim(player, base + Vector3(-2, 4.0, 16), 0.1, -0.35)
	await get_tree().process_frame
	await _shot(out_dir.path_join("10_garden_wide.png"))

	print("[SHOTS] saved to ", out_dir)


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SHOTS] ", path)
