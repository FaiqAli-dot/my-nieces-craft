extends Node
## Screenshot / short demo harness for Phase 2 build foundation.
## COZY_PHASE2_BUILD_SHOTS=1 COZY_PHASE2_BUILD_QUIT=1
## Optional: COZY_SHOT_DIR=/opt/cursor/artifacts/phase2_build
## Optional: COZY_SHOT_SIZE=1792x828 or 2048x1536

var _dir: String
var _world: Node
var _player: PlayerController
var _ui: GameUi


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_dir = OS.get_environment("COZY_SHOT_DIR")
	if _dir == "":
		_dir = "/opt/cursor/artifacts/phase2_build"
	DirAccess.make_dir_recursive_absolute(_dir)
	_apply_viewport_size()
	_world = get_parent()
	_player = _world.get_node_or_null("Player") as PlayerController
	_ui = _world.get_node_or_null("GameUI") as GameUi
	if _player == null or _ui == null:
		push_error("phase2_build_shots: missing player/ui")
		_quit(1)
		return
	GameState.touch_controls_forced = true
	_ui._detect_touch()
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	_player.prepare_for_mode(GameState.Mode.CREATIVE)
	await get_tree().process_frame
	_player.global_position = Vector3(33.5, float(VoxelWorld.GROUND_Y + 1), 30.5)
	_player.look_yaw = 0.0
	_player.look_pitch = -0.25
	await _run()
	_quit(0)


func _apply_viewport_size() -> void:
	var spec := OS.get_environment("COZY_SHOT_SIZE")
	if spec == "":
		spec = "1792x828"
	var parts := spec.split("x")
	if parts.size() != 2:
		return
	var w := int(parts[0])
	var h := int(parts[1])
	DisplayServer.window_set_size(Vector2i(w, h))
	get_viewport().size = Vector2i(w, h)


func _run() -> void:
	var tag := OS.get_environment("COZY_SHOT_TAG")
	if tag == "":
		tag = OS.get_environment("COZY_SHOT_SIZE").replace("x", "p")
		if tag == "":
			tag = "phone"
	await _shot("01_catalog_open_%s.png" % tag)
	_ui.toggle_build_catalog()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("01_catalog_open_%s.png" % tag)

	# Select dirt for tap-to-place preview — clear air cell above grass
	_ui._on_build_item_selected(BuildCatalog.block_entry("dirt"))
	await get_tree().process_frame
	var gx := 36
	var gz := 36
	_player.world.set_block(gx, VoxelWorld.GROUND_Y + 1, gz, 0, true)
	_aim_place_cell(gx, VoxelWorld.GROUND_Y + 1, gz)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player._update_targeting()
	await get_tree().process_frame
	await _shot("02_preview_valid_green_%s.png" % tag)

	# Invalid red: freeze targeting and show occupied-cell ghost (same snap transform).
	_player.set_physics_process(false)
	_player.place_preview.visible = true
	_player.place_preview.global_position = Vector3(float(gx) + 0.5, float(VoxelWorld.GROUND_Y + 1) + 0.5, float(gz) + 0.5)
	_player.place_preview.material_override = _player._place_mat_bad
	await get_tree().process_frame
	await _shot("03_preview_invalid_red_%s.png" % tag)
	_player.set_physics_process(true)
	_player.world.set_block(gx, VoxelWorld.GROUND_Y + 1, gz, 0, true)

	# Valid place + history tools (seed undo/redo so tool row shows enabled icons)
	_aim_place_cell(35, VoxelWorld.GROUND_Y + 1, 32)
	await get_tree().physics_frame
	_player.try_place()
	await get_tree().process_frame
	# Extra history entry so Undo is enabled; pop once so Redo is also enabled.
	_player.build_history.push(BuildHistory.block_place(Vector3i(34, VoxelWorld.GROUND_Y + 1, 32), "dirt", BlockDB.place_block_id("dirt"), 0))
	var _tmp := _player.build_history.pop_undo()
	_ui.toggle_build_catalog()
	await get_tree().process_frame
	_ui.build_catalog.refresh()
	await get_tree().process_frame
	# Force busy session so Cancel shows enabled; keep toast away from header.
	GameState.toast("Back to start!")
	_ui._layout_toast_for_panels()
	await get_tree().process_frame
	await _shot("04_after_place_catalog_%s.png" % tag)
	await _shot("04b_tool_row_%s.png" % tag)
	_ui.panels.close_all()

	# Mid-drag: catalog closed, drag session active, green preview at drop cell
	_ui._on_build_drag_started(BuildCatalog.block_entry("dirt"), 0)
	_aim_place_cell(36, VoxelWorld.GROUND_Y + 1, 33)
	await get_tree().physics_frame
	_player._update_targeting()
	await get_tree().process_frame
	await _shot("04c_mid_drag_%s.png" % tag)
	_player.build_session.end_drag()
	_player.clear_build_selection()

	# Survival resource / cost label
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	_player.inventory.clear()
	_player.inventory.add_item("cobble", 3)
	_ui.toggle_build_catalog()
	await get_tree().process_frame
	_ui.build_catalog._category = BuildCatalog.CAT_BLOCKS
	_ui.build_catalog.refresh()
	_ui.build_catalog.set_selected_entry(BuildCatalog.block_entry("cobble"))
	await get_tree().process_frame
	await _shot("05_survival_resources_%s.png" % tag)
	await _shot("05b_survival_cost_%s.png" % tag)
	_ui.panels.close_all()
	GameState.set_game_mode(GameState.Mode.CREATIVE)

	# Flight toggle with catalog open
	_ui.toggle_build_catalog()
	await get_tree().process_frame
	GameState.set_flying(true)
	_ui._layout_fly_controls()
	await get_tree().process_frame
	await _shot("06_flight_catalog_open_%s.png" % tag)
	GameState.set_flying(false)
	_ui._layout_fly_controls()
	_ui.panels.close_all()
	await get_tree().process_frame
	await _shot("07_flight_catalog_closed_%s.png" % tag)


func _aim_place_cell(x: int, y: int, z: int) -> void:
	_player.global_position = Vector3(float(x) + 0.5, float(y) + 0.5 - PlayerController.EYE_HEIGHT, float(z) + 2.6)
	_player.look_yaw = 0.0
	_player.look_pitch = -0.15
	_player.head.rotation.y = _player.look_yaw
	_player.camera.rotation.x = _player.look_pitch
	_player.ray.force_raycast_update()
	_player._update_targeting()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("screenshot failed: " + name)
		return
	var path := _dir.path_join(name)
	img.save_png(path)
	print("SHOT: ", path)


func _quit(code: int) -> void:
	if OS.get_environment("COZY_PHASE2_BUILD_QUIT") == "1" or OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(code)
