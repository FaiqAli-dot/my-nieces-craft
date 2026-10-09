extends Node
## Captures PNG screenshots for walkthrough artifacts when COZY_SCREENSHOTS=1.

@onready var main := get_parent()

func _ready() -> void:
	if OS.get_environment("COZY_SCREENSHOTS") != "1":
		queue_free()
		return
	GameState.touch_controls_forced = true
	await get_tree().create_timer(2.0).timeout
	await _capture_all()
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)


func _capture_all() -> void:
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	ui._detect_touch()
	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "user://screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)

	# 1) Main building area
	player.global_position = Vector3(32.5, 6.5, 40)
	player.look_yaw = PI
	player.look_pitch = -0.25
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir.path_join("01_main_building_area.png"))

	# Build a small structure for visual proof
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var wood := BlockDB.get_id("wood")
	var planks := BlockDB.get_id("planks")
	for x in range(30, 34):
		for z in range(30, 34):
			world.set_block(x, VoxelWorld.GROUND_Y + 1, z, planks, true)
	for y in range(VoxelWorld.GROUND_Y + 2, VoxelWorld.GROUND_Y + 5):
		world.set_block(30, y, 30, wood, true)
		world.set_block(33, y, 30, wood, true)
		world.set_block(30, y, 33, wood, true)
		world.set_block(33, y, 33, wood, true)
	player.global_position = Vector3(36, 7, 36)
	player.look_yaw = -2.4
	player.look_pitch = -0.2
	await get_tree().process_frame
	await _shot(out_dir.path_join("02_built_structure.png"))

	# 2) Asset showcase sections
	player.global_position = Vector3(48, 7, 6)
	player.look_yaw = 0.0
	player.look_pitch = -0.15
	await get_tree().process_frame
	await _shot(out_dir.path_join("03_showcase_environment.png"))
	player.global_position = Vector3(48, 7, 14)
	await get_tree().process_frame
	await _shot(out_dir.path_join("04_showcase_animals.png"))
	player.global_position = Vector3(48, 7, 22)
	await get_tree().process_frame
	await _shot(out_dir.path_join("05_showcase_furniture.png"))
	player.global_position = Vector3(48, 7, 30)
	await get_tree().process_frame
	await _shot(out_dir.path_join("06_showcase_materials.png"))

	# 3) Hotbar / crafting UI
	player.global_position = Vector3(32.5, 6.5, 34)
	player.look_yaw = 0.0
	ui.toggle_craft()
	await get_tree().process_frame
	await _shot(out_dir.path_join("07_crafting_ui.png"))
	ui.toggle_craft()

	# 4) Touch controls
	ui._detect_touch()
	await get_tree().process_frame
	await _shot(out_dir.path_join("08_touch_controls.png"))

	print("[SHOTS] saved to ", out_dir)


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SHOTS] ", path)
