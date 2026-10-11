extends Node
## COZY_S2_SHOTS=1 — capture Survival UI / progression stills for the S2 report.

const OUT := "user://s2_shots"
const ART := "/opt/cursor/artifacts/s2_shots"

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ART)
	var main := get_parent()
	var ui: GameUi = main.get_node("GameUI")
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	player.crafting.reload()

	# 1) Mode select
	ui.show_mode_select()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.4).timeout
	await _shot("01_mode_select")

	# 2) Survival empty HUD
	ui.hide_mode_select()
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	player.inventory.clear()
	GameState.set_flying(false)
	ui.refresh_hotbar()
	ui._on_creative(false)
	GameState.touch_controls_forced = true
	ui._detect_touch()
	await get_tree().create_timer(0.4).timeout
	await _shot("02_survival_hud_empty")

	# 3) Mining feedback overlay
	ui.mining_bar.visible = true
	ui.mining_bar.value = 0.55
	player.global_position = Vector3(26.5, VoxelWorld.GROUND_Y + 1.1, 28.5)
	player.look_yaw = 0.0
	player.look_pitch = -0.2
	await get_tree().create_timer(0.35).timeout
	await _shot("03_mining_progress")
	ui.mining_bar.visible = false

	# 4) Voxel tree
	player.global_position = Vector3(26.5, VoxelWorld.GROUND_Y + 1.1, 26.0)
	player.look_yaw = PI
	player.look_pitch = 0.25
	await get_tree().create_timer(0.35).timeout
	await _shot("04_voxel_tree")

	# 5) Crafting UI near table
	player.inventory.clear()
	player.inventory.add_item("wood", 16)
	player.inventory.add_item("planks", 16)
	player.inventory.add_item("sticks", 16)
	player.inventory.add_item("cobble", 16)
	world.set_block(32, VoxelWorld.GROUND_Y + 1, 33, BlockDB.get_id("crafting_table"), true)
	player.global_position = Vector3(32.5, VoxelWorld.GROUND_Y + 1.1, 35.0)
	ui.panels.open("craft")
	ui._build_craft_list()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.4).timeout
	await _shot("05_crafting_table_ui")
	ui.panels.close_all()

	# 6) Pickaxes in hotbar
	player.inventory.clear()
	player.inventory.hotbar[0] = {"item": "wooden_pickaxe", "count": 1, "durability": 59}
	player.inventory.hotbar[1] = {"item": "stone_pickaxe", "count": 1, "durability": 131}
	player.inventory.hotbar[2] = {"item": "wood", "count": 8}
	player.inventory.hotbar[3] = {"item": "cobble", "count": 8}
	player.inventory.select(0)
	GameState.notify_inventory()
	ui.refresh_hotbar()
	await get_tree().create_timer(0.35).timeout
	await _shot("06_pickaxes_hotbar")

	# 7) Inventory phone
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.panels.open("inventory")
	ui._refresh_inventory_panel()
	await get_tree().create_timer(0.4).timeout
	await _shot("07_inventory_phone")
	ui.panels.close_all()

	# 8) Inventory tablet
	get_window().size = Vector2i(1024, 768)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.panels.open("inventory")
	ui._refresh_inventory_panel()
	await get_tree().create_timer(0.4).timeout
	await _shot("08_inventory_tablet")
	ui.panels.close_all()

	print("[S2_SHOTS] done → ", ART)
	get_tree().quit(0)


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var user_path := OUT.path_join(name + ".png")
	img.save_png(user_path)
	var abs_user := ProjectSettings.globalize_path(user_path)
	DirAccess.copy_absolute(abs_user, ART.path_join(name + ".png"))
	print("[S2_SHOTS] ", ART.path_join(name + ".png"))
