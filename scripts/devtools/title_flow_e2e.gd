extends Node
## Windowed end-to-end: title → Play → meadow → title → Continue → house → meadow.
## COZY_TITLE_E2E=1 COZY_SAVE_PATH=/tmp/cozy_e2e/world.json \
##   COZY_SETTINGS_PATH=/tmp/cozy_e2e/settings.cfg COZY_HOUSE_DATA=/tmp/cozy_e2e/houses \
##   COZY_SHOT_DIR=/tmp/cozy_shots godot --path . --resolution 1280x720
## Lives on the tree root so it survives scene changes.

var passed := 0
var failed := 0
var _shots := ""


func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)


func _ready() -> void:
	_shots = OS.get_environment("COZY_SHOT_DIR")
	_run.call_deferred()


func _scene() -> Node:
	return get_tree().current_scene


func _wait_for(pred: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		if pred.call():
			return true
		await get_tree().process_frame
	return false


func _shot(name: String) -> void:
	if _shots == "":
		return
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots.path_join("e2e_%s.png" % name))


func _run() -> void:
	print("=== Title flow E2E ===")
	_assert(SaveGame.save_path != SaveGame.SAVE_PATH, "harness uses an isolated save")
	SaveGame.delete_save()
	await _wait_for(func(): return _scene() is TitleScreen, 5.0)
	var title: TitleScreen = _scene()
	title.refresh()
	_assert((title.buttons["Continue"] as Button).disabled, "fresh install: Continue disabled")
	await _shot("01_title_fresh")
	title.press("Settings")
	await _shot("02_settings")
	title.settings_panel.close()
	title._last_press = -100000
	title.press("Play")
	_assert(title.loading_panel.visible, "loading card visible")
	await _shot("03_loading")
	var ok := await _wait_for(func(): return _scene() != null and _scene().has_method("save_now"), 20.0)
	_assert(ok, "Play reaches the meadow")
	if not ok:
		_finish()
		return
	await get_tree().process_frame
	var main := _scene()
	_assert(main.autosave_enabled and SaveGame.save_exists(), "new world saved")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var player: PlayerController = main.get_node("Player")
	var g := VoxelWorld.GROUND_Y
	var marker := Vector3i(int(player.global_position.x) + 2, g + 1, int(player.global_position.z) + 2)
	world.set_block(marker.x, marker.y, marker.z, BlockDB.get_id("planks"), true)
	await _shot("04_meadow_new")
	main.ui.toggle_menu()
	await _shot("04b_meadow_menu")
	main.ui.toggle_menu()

	SceneFlow.go_to_title()
	ok = await _wait_for(func(): return _scene() is TitleScreen, 10.0)
	_assert(ok, "menu → title screen")
	title = _scene()
	await get_tree().process_frame
	_assert(not (title.buttons["Continue"] as Button).disabled, "Continue enabled after playing")
	await _shot("05_title_continue")
	title._last_press = -100000
	title.press("Continue")
	ok = await _wait_for(func(): return _scene() != null and _scene().has_method("save_now"), 20.0)
	_assert(ok, "Continue reaches the meadow")
	if ok:
		await get_tree().process_frame
		world = _scene().get_node("VoxelWorld")
		_assert(world.get_block(marker.x, marker.y, marker.z) == BlockDB.get_id("planks"), "Continue restored the block")
		player = _scene().get_node("Player")
		SceneFlow.go_to_house(player)
		ok = await _wait_for(func(): return _scene() != null and _scene().has_method("toggle_door"), 10.0)
		_assert(ok, "meadow → house")
		await get_tree().create_timer(0.5).timeout
		SceneFlow.return_to_meadow()
		ok = await _wait_for(func(): return _scene() != null and _scene().has_method("save_now"), 10.0)
		_assert(ok, "house → meadow")
		if ok:
			await get_tree().process_frame
			world = _scene().get_node("VoxelWorld")
			_assert(world.get_block(marker.x, marker.y, marker.z) == BlockDB.get_id("planks"), "meadow kept after visiting home")
	_finish()


func _finish() -> void:
	print("=== TITLE E2E Results: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
