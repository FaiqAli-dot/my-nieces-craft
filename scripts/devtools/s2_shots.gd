extends Node
## COZY_S2_SHOTS=1 — capture Survival UI stills for the S2 report.

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

	# 1) Mode select with card pictures
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
	await get_tree().create_timer(0.35).timeout
	await _shot("02_survival_hud_empty")

	# 3) Crafting UI — available (planks) + unavailable (pickaxe / missing items)
	player.inventory.clear()
	player.inventory.add_item("wood", 4)
	player.inventory.add_item("planks", 2)
	# No sticks → stick/table/tool recipes show red missing counts
	player.global_position = Vector3(32.5, VoxelWorld.GROUND_Y + 1.1, 35.0)
	ui.panels.open("craft")
	ui._build_craft_list()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(0.45).timeout
	await _shot("03_crafting_available_unavailable")
	ui.panels.close_all()

	# 4) Crafting with table nearby + ingredients for pickaxe
	world.set_block(32, VoxelWorld.GROUND_Y + 1, 33, BlockDB.get_id("crafting_table"), true)
	player.inventory.clear()
	player.inventory.add_item("planks", 16)
	player.inventory.add_item("sticks", 16)
	player.inventory.add_item("cobble", 8)
	player.global_position = Vector3(32.5, VoxelWorld.GROUND_Y + 1.1, 34.5)
	ui.panels.open("craft")
	ui._build_craft_list()
	await get_tree().create_timer(0.45).timeout
	await _shot("04_crafting_table_ready")
	ui.panels.close_all()

	# 5) Hotbar with tool icons + durability bars
	player.inventory.clear()
	player.inventory.hotbar[0] = {"item": "wooden_pickaxe", "count": 1, "durability": 20}
	player.inventory.hotbar[1] = {"item": "stone_pickaxe", "count": 1, "durability": 100}
	player.inventory.hotbar[2] = {"item": "wooden_axe", "count": 1, "durability": 59}
	player.inventory.hotbar[3] = {"item": "stone_axe", "count": 1, "durability": 40}
	player.inventory.hotbar[4] = {"item": "sticks", "count": 12}
	player.inventory.hotbar[5] = {"item": "crafting_table", "count": 1}
	player.inventory.select(0)
	GameState.notify_inventory()
	ui.refresh_hotbar()
	await get_tree().create_timer(0.4).timeout
	await _shot("05_hotbar_tools_durability")

	# 6) Inventory phone 9+27
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.panels.open("inventory")
	ui._refresh_inventory_panel()
	await get_tree().create_timer(0.4).timeout
	await _shot("06_inventory_phone")
	ui.panels.close_all()

	# 7) Inventory tablet
	get_window().size = Vector2i(1024, 768)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.panels.open("inventory")
	ui._refresh_inventory_panel()
	await get_tree().create_timer(0.4).timeout
	await _shot("07_inventory_tablet")
	ui.panels.close_all()

	# 8) Menu shows New World prominently
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	ui._layout_hotbar()
	ui.panels.open("menu")
	await get_tree().create_timer(0.35).timeout
	await _shot("08_menu_new_world")
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
