extends Node
## COZY_S2_DEMO=1 — short automated wood→stone progression for screen recording.

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var main := get_parent()
	var ui: GameUi = main.get_node("GameUI")
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")

	ui.hide_mode_select()
	player.prepare_for_mode(GameState.Mode.SURVIVAL)
	ui.refresh_hotbar()
	GameState.touch_controls_forced = true
	ui._detect_touch()

	# Harvest several logs quickly (scripted breaks for demo pacing)
	for y in range(1, 5):
		var drop := world.break_block_survival(26, VoxelWorld.GROUND_Y + y, 30, "")
		if drop != "":
			world.spawn_drop(drop, 1, Vector3(26.5, VoxelWorld.GROUND_Y + y + 0.5, 30.5))
	await get_tree().create_timer(0.4).timeout
	for c in world.drop_root.get_children():
		var d := c as WorldDrop
		if d:
			d.age = 1.0
	player.global_position = Vector3(26.5, VoxelWorld.GROUND_Y + 1.1, 30.5)
	world.collect_nearby_drops(player.inventory, player.global_position, 3.0)
	# Ensure enough materials for demo
	player.inventory.add_item("wood", 10)
	await get_tree().create_timer(0.4).timeout

	var craft := player.crafting
	for _i in 5:
		craft.craft("wood_to_planks", player.inventory, false)
	craft.craft("planks_to_sticks", player.inventory, false)
	craft.craft("planks_to_sticks", player.inventory, false)
	craft.craft("crafting_table", player.inventory, false)
	ui.toggle_craft()
	await get_tree().create_timer(0.8).timeout
	ui.panels.close_all()

	# Place table + craft pickaxes
	world.set_block(32, VoxelWorld.GROUND_Y + 1, 34, BlockDB.get_id("crafting_table"), true)
	player.global_position = Vector3(32.5, VoxelWorld.GROUND_Y + 1.1, 35.5)
	craft.craft("wooden_pickaxe", player.inventory, true)
	ui.refresh_hotbar()
	await get_tree().create_timer(0.6).timeout

	# Mine stone outcrop with pick
	player.inventory.select(0)
	# Put pickaxe in slot 0 if needed
	for i in player.inventory.hotbar.size():
		if str(player.inventory.hotbar[i].get("item", "")) == "wooden_pickaxe":
			player.inventory.select(i)
			break
	player.global_position = Vector3(44.5, VoxelWorld.GROUND_Y + 1.1, 28.5)
	player.look_yaw = 0.0
	await get_tree().create_timer(0.3).timeout
	var cobble := world.break_block_survival(44, VoxelWorld.GROUND_Y + 1, 30, "wooden_pickaxe")
	if cobble != "":
		world.spawn_drop(cobble, 1, Vector3(44.5, VoxelWorld.GROUND_Y + 1.5, 30.5))
	for c2 in world.drop_root.get_children():
		var d2 := c2 as WorldDrop
		if d2:
			d2.age = 1.0
	world.collect_nearby_drops(player.inventory, Vector3(44.5, VoxelWorld.GROUND_Y + 1.5, 30.5), 3.0)
	player.inventory.add_item("cobble", 6)
	player.inventory.add_item("sticks", 4)
	craft.craft("stone_pickaxe", player.inventory, true)
	craft.craft("stone_axe", player.inventory, true)
	ui.refresh_hotbar()
	await get_tree().create_timer(0.8).timeout
	ui.toggle_inventory()
	await get_tree().create_timer(1.0).timeout
	print("[S2_DEMO] wood-to-stone progression complete")
	if OS.get_environment("COZY_S2_DEMO_QUIT") == "1":
		get_tree().quit(0)
