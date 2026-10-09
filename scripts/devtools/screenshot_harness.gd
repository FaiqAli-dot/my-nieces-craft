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
	var base := showcase.global_position

	# 1) Main building area — stand near spawn looking at ambient Kenney props (-Z forward)
	_aim(player, Vector3(26, 7.0, 32), 0.0, -0.18)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir.path_join("01_main_building_area.png"))

	# Build a small house near spawn
	var wood := BlockDB.get_id("wood")
	var planks := BlockDB.get_id("planks")
	var wool := BlockDB.get_id("wool_pink")
	for x in range(34, 40):
		for z in range(34, 40):
			world.set_block(x, VoxelWorld.GROUND_Y + 1, z, planks, true)
	for y in range(VoxelWorld.GROUND_Y + 2, VoxelWorld.GROUND_Y + 5):
		for x in range(34, 40):
			world.set_block(x, y, 34, wood, true)
			world.set_block(x, y, 39, wood, true)
		for z in range(34, 40):
			world.set_block(34, y, z, wood, true)
			world.set_block(39, y, z, wood, true)
	for x in range(34, 40):
		for z in range(34, 40):
			world.set_block(x, VoxelWorld.GROUND_Y + 5, z, wool, true)
	world.set_block(36, VoxelWorld.GROUND_Y + 2, 34, 0, true)
	world.set_block(37, VoxelWorld.GROUND_Y + 2, 34, 0, true)
	world.set_block(36, VoxelWorld.GROUND_Y + 3, 34, 0, true)
	world.set_block(37, VoxelWorld.GROUND_Y + 3, 34, 0, true)

	# Stand SE of house; yaw = atan2(-dir.x, -dir.z) so camera -Z faces the house
	var house_center := Vector3(37, 7.0, 37)
	var cam_pos := Vector3(44, 8.0, 46)
	var dir := (house_center - cam_pos).normalized()
	var yaw := atan2(-dir.x, -dir.z)
	_aim(player, cam_pos, yaw, -0.32)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_dir.path_join("02_built_structure.png"))

	# Showcase: camera looks -Z, so stand at higher Z than each section
	# Sections at local z = 0,8,16,24,32 → world z = base.z + local
	var section_zs := [0.0, 8.0, 16.0, 24.0, 32.0]
	var names := [
		"03_showcase_environment.png",
		"04_showcase_animals.png",
		"05_showcase_furniture.png",
		"06_showcase_materials.png",
		"06b_showcase_other.png",
	]
	for i in 4:
		var sz: float = base.z + section_zs[i]
		_aim(player, Vector3(base.x, base.y + 2.4, sz + 6.0), 0.0, -0.2)
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(out_dir.path_join(names[i]))

	# Crafting UI over the house
	_aim(player, cam_pos, yaw, -0.32)
	ui.toggle_craft()
	await get_tree().process_frame
	await _shot(out_dir.path_join("07_crafting_ui.png"))
	ui.toggle_craft()

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
