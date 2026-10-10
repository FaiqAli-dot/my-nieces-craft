extends Node
## Capture Phase 1.6 verification screenshots (house scale/floor + meadow flight UI).


func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	var out := OS.get_environment("COZY_SHOT_DIR")
	if out == "":
		out = "/opt/cursor/artifacts/screenshots/phase16"
	DirAccess.make_dir_recursive_absolute(out)

	var scene := get_tree().current_scene
	if scene and str(scene.scene_file_path).ends_with("house.tscn"):
		await _house_shots(scene, out)
	elif scene and str(scene.scene_file_path).ends_with("main.tscn"):
		await _meadow_shots(scene, out)
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)


func _house_shots(house: Node, out: String) -> void:
	var player: ThirdPersonController = house.get_node("Player")
	var space: HouseSpace = house.get_node("HouseSpace")
	# Seed offline furniture so collisions/scale are visible.
	if house.has_method("_rebuild_furniture"):
		house._rebuild_furniture([
			{"instance_id": "shot_chair", "def_id": "chair", "cell_x": 4, "cell_z": 5, "rotation": 0},
			{"instance_id": "shot_table", "def_id": "table", "cell_x": 6, "cell_z": 5, "rotation": 0},
			{"instance_id": "shot_shelf", "def_id": "bookshelf", "cell_x": 2, "cell_z": 3, "rotation": 90},
			{"instance_id": "shot_bed", "def_id": "bed", "cell_x": 8, "cell_z": 2, "rotation": 0},
		])
	player.global_position = Vector3(6.0, 0.0, 9.2)
	player.yaw = 0.05
	player.pitch = deg_to_rad(-12)
	player.model_root.rotation.y = PI
	# Settle onto floor.
	for _i in 20:
		player._physics_process(0.016)
		await get_tree().physics_frame
	await _shot(out.path_join("after_house_character_scale.png"))
	player.global_position = Vector3(5.5, 0.0, 6.5)
	player.yaw = -0.4
	await get_tree().process_frame
	await _shot(out.path_join("after_house_furniture_collision_view.png"))
	# Force-touch overlays for rotate icon
	GameState.touch_controls_forced = true
	OS.set_environment("COZY_FORCE_TOUCH", "1")
	if house.ui:
		house.ui._detect_touch()
		house.ui._layout_touch()
	await get_tree().process_frame
	await _shot(out.path_join("after_house_rotate_icon.png"))
	print("[PHASE16] house shots done y=", player.global_position.y, " floor_bodies=", space.floor_collision_count())


func _meadow_shots(main: Node, out: String) -> void:
	GameState.set_creative(true)
	GameState.touch_controls_forced = true
	OS.set_environment("COZY_FORCE_TOUCH", "1")
	var ui: GameUi = main.get_node("GameUI")
	ui._detect_touch()
	ui._layout_fly_controls()
	GameState.set_flying(false)
	await get_tree().process_frame
	await _shot(out.path_join("after_meadow_fly_toggle.png"))
	GameState.set_flying(true)
	ui._layout_fly_controls()
	await get_tree().process_frame
	await _shot(out.path_join("after_meadow_flight_active.png"))
	# Exclusive menus
	ui.toggle_inventory()
	await get_tree().process_frame
	await _shot(out.path_join("after_meadow_bag_only.png"))
	ui.toggle_craft()
	await get_tree().process_frame
	await _shot(out.path_join("after_meadow_craft_replaces_bag.png"))
	ui.panels.close_all()
	print("[PHASE16] meadow shots done")


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SHOT] ", path)
