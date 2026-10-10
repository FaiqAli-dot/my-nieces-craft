extends Node
## Live demo: exclusive menus, flight, house floor, meadow return.
## Reparents to root so it survives scene changes.


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if get_parent() != tree.root:
		var parent := get_parent()
		if parent:
			parent.remove_child(self)
		name = "CozyPhase16Demo"
		tree.root.add_child(self)
	await _run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	if not _path_ends("main.tscn"):
		SceneFlow.go_to_house() # noop path; prefer meadow start
		SceneFlow.return_to_meadow()
		await _wait("main.tscn")
	await _demo_meadow()
	await _demo_house()
	print("[PHASE16_DEMO] done")
	get_tree().quit(0)


func _path_ends(suffix: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and str(scene.scene_file_path).ends_with(suffix)


func _wait(suffix: String) -> bool:
	for _i in 240:
		await get_tree().process_frame
		if _path_ends(suffix):
			await get_tree().process_frame
			return true
	return false


func _demo_meadow() -> void:
	GameState.touch_controls_forced = true
	var main := get_tree().current_scene
	var ui: GameUi = main.get_node("GameUI")
	var player: PlayerController = main.get_node("Player")
	ui._detect_touch()
	ui._layout_fly_controls()
	ui.toggle_inventory()
	await get_tree().create_timer(0.9).timeout
	ui.toggle_craft()
	await get_tree().create_timer(0.9).timeout
	ui.panels.close_all()
	await get_tree().create_timer(0.4).timeout
	GameState.set_flying(true)
	ui._layout_fly_controls()
	await get_tree().create_timer(0.3).timeout
	player.set_touch_fly_vertical(1.0)
	for _i in 50:
		await get_tree().physics_frame
	player.set_touch_fly_vertical(0.0)
	await get_tree().create_timer(0.35).timeout
	player.set_touch_fly_vertical(-1.0)
	for _i in 45:
		await get_tree().physics_frame
	player.set_touch_fly_vertical(0.0)
	GameState.set_flying(false)
	await get_tree().create_timer(0.5).timeout
	SceneFlow.go_to_house(player)
	await _wait("house.tscn")


func _demo_house() -> void:
	var house := get_tree().current_scene
	if house == null or not house.has_method("go_voxel_world"):
		return
	if house.has_method("_rebuild_furniture"):
		house._rebuild_furniture([
			{"instance_id": "d1", "def_id": "chair", "cell_x": 4, "cell_z": 5, "rotation": 0},
			{"instance_id": "d2", "def_id": "table", "cell_x": 6, "cell_z": 5, "rotation": 0},
			{"instance_id": "d3", "def_id": "bookshelf", "cell_x": 2, "cell_z": 3, "rotation": 90},
		])
	var p: ThirdPersonController = house.get_node("Player")
	p.global_position = Vector3(6, 0, 8.5)
	p.yaw = 0.1
	for _i in 25:
		await get_tree().physics_frame
	await get_tree().create_timer(0.7).timeout
	p.set_touch_move(Vector2(0, -1))
	for _i in 35:
		await get_tree().physics_frame
	p.set_touch_move(Vector2.ZERO)
	await get_tree().create_timer(0.7).timeout
	# Exclusive house panels
	if house.ui:
		house.ui.open_catalog()
		await get_tree().create_timer(0.7).timeout
		house.ui.open_visit_panel()
		await get_tree().create_timer(0.7).timeout
		house.ui.panels.close_all()
	await get_tree().create_timer(0.4).timeout
	house.go_voxel_world()
	await _wait("main.tscn")
	await get_tree().create_timer(0.6).timeout
