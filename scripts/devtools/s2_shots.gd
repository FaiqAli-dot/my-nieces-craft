extends Node
## COZY_S2_SHOTS=1 — capture Survival UI / progression stills for the S2 report.

const OUT := "user://s2_shots"

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	DirAccess.make_dir_recursive_absolute(OUT)
	var main := get_parent()
	var ui: GameUi = main.get_node("GameUI")
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")

	# 1) Mode select
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	ui.show_mode_select()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.35).timeout
	await _shot("01_mode_select")

	# 2) Survival empty HUD
	ui.hide_mode_select()
	player.prepare_for_mode(GameState.Mode.SURVIVAL)
	ui.refresh_hotbar()
	ui._on_creative(false)
	GameState.touch_controls_forced = true
	ui._detect_touch()
	await get_tree().create_timer(0.4).timeout
	await _shot("02_survival_hud_empty")

	# 3) Mining feedback — stand at tree and start dig
	player.global_position = Vector3(26.5, VoxelWorld.GROUND_Y + 1.1, 28.5)
	player.look_yaw = 0.0
	player.look_pitch = -0.15
	player._touch_mining = true
	player._break_held = true
	for _i in 20:
		await get_tree().physics_frame
	await _shot("03_mining_progress")
	player.cancel_mining()

	# 4) Voxel tree view
	player.global_position = Vector3(26.5, VoxelWorld.GROUND_Y + 1.1, 26.0)
	player.look_yaw = PI
	player.look_pitch = 0.2
	await get_tree().create_timer(0.3).timeout
	await _shot("04_voxel_tree")

	# 5) Crafting table UI with recipes
	player.inventory.clear()
	player.inventory.add_item("wood", 16)
	player.inventory.add_item("planks", 16)
	player.inventory.add_item("sticks", 16)
	player.inventory.add_item("crafting_table", 1)
	player.inventory.add_item("cobble", 16)
	# Place table at feet
	var tx := 32
	var tz := 33
	world.set_block(tx, VoxelWorld.GROUND_Y + 1, tz, BlockDB.get_id("crafting_table"), true)
	player.global_position = Vector3(tx + 0.5, VoxelWorld.GROUND_Y + 1.1, tz + 2.0)
	ui.toggle_craft()
	await get_tree().create_timer(0.35).timeout
	await _shot("05_crafting_table_ui")
	ui.panels.close_all()

	# 6) Wooden + stone pickaxe in hotbar
	player.inventory.clear()
	player.inventory.add_item("wooden_pickaxe", 1)
	player.inventory.add_item("stone_pickaxe", 1)
	player.inventory.add_item("wood", 8)
	player.inventory.add_item("cobble", 8)
	player.inventory.select(0)
	ui.refresh_hotbar()
	await get_tree().create_timer(0.3).timeout
	await _shot("06_pickaxes_hotbar")

	# 7) Inventory 9+27 phone
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.toggle_inventory()
	await get_tree().create_timer(0.35).timeout
	await _shot("07_inventory_phone")
	ui.panels.close_all()

	# 8) Inventory tablet
	get_window().size = Vector2i(1024, 768)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.toggle_inventory()
	await get_tree().create_timer(0.35).timeout
	await _shot("08_inventory_tablet")
	ui.panels.close_all()

	print("[S2_SHOTS] wrote to ", ProjectSettings.globalize_path(OUT))
	# Copy into artifacts if present
	var art := "/opt/cursor/artifacts/s2_shots"
	DirAccess.make_dir_recursive_absolute(art)
	var dir := DirAccess.open(OUT)
	if dir:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if fn.ends_with(".png"):
				DirAccess.copy_absolute(OUT.path_join(fn), art.path_join(fn))
			fn = dir.get_next()
	if OS.get_environment("COZY_SMOKE_QUIT") == "1" or OS.get_environment("COZY_S2_SHOTS_QUIT") == "1":
		get_tree().quit(0)


func _shot(name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := OUT.path_join(name + ".png")
	img.save_png(path)
	print("[S2_SHOTS] ", path)
