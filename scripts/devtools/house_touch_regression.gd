extends Node
## Touch-path regression for house furniture controls (COZY_HOUSE_TOUCH_TEST=1).

var passed := 0
var failed := 0
var _world: Node


func _ready() -> void:
	if OS.get_environment("COZY_HOUSE_TOUCH_TEST") != "1":
		queue_free()
		return
	print("=== House Touch Regression ===")
	GameState.touch_controls_forced = true
	_world = get_parent()
	await get_tree().create_timer(1.0).timeout
	var ui: HouseUi = _world.ui
	ui._detect_touch()
	_assert(ui.touch_layer.visible, "touch layer visible")
	_assert(ui.place_btn != null and ui.rotate_btn != null and ui.cancel_btn != null, "touch place/rotate/cancel exist")
	_assert(ui.joystick != null and ui.look_area != null, "shared TouchJoystick + LookArea present")
	_assert(ui.move_stick != null and ui.look_pad != null, "move/look pads exist")
	_assert(ui.place_btn is ActionButton, "place uses ActionButton from #7")
	_assert(ui.joystick.floating_mode, "house joystick uses floating_mode")
	ui._layout_touch()
	await get_tree().process_frame
	var hspawn := Vector2(ui.joystick.size.x * 0.4, ui.joystick.size.y * 0.4)
	ui.joystick.simulate_touch(0, hspawn, true)
	ui.joystick.simulate_drag(0, hspawn + Vector2(40, 0))
	_assert(ui.joystick.is_active(), "house floating stick spawns in zone")
	_assert(ui.joystick.get_vector().x > 0.2, "house floating stick emits +x")
	ui.joystick.simulate_touch(0, hspawn, false)
	_assert(ui.joystick.get_vector() == Vector2.ZERO, "house stick release clears move")
	_assert(ui.joystick.visual_center().distance_to(ui.joystick.rest_center()) < 2.0, "house stick returns to rest hint")

	# Offline decorate path if no server
	_world.placement.can_decorate = true
	if _world._furniture.is_empty():
		_world._spawn_furniture({"instance_id": "touch_table", "def_id": "table", "cell_x": 5, "cell_z": 5, "rotation": 0})
		_world.placement.set_instances(_world._furniture)

	_world.start_place("chair")
	_assert(_world.placement.mode == PlacementController.Mode.PLACE, "catalog/start_place enters place mode")
	_assert(_world.placement._grid_root != null, "placement grid shown")
	_world.placement._anchor = Vector2i(2, 2)
	_world.placement._valid = true
	_world.placement._update_preview_xform()
	_world.placement._tint(true)

	# Touch rotate
	ui.rotate_btn.pressed.emit()
	_assert(_world.placement.rotation_deg == 90, "touch rotate increments 90")

	# Touch cancel
	ui.cancel_btn.pressed.emit()
	_assert(_world.placement.mode == PlacementController.Mode.IDLE, "touch cancel clears placement")

	# Place again and confirm via Place button (will request net; offline still clears mode after confirm if valid)
	_world.start_place("lamp")
	_world.placement._anchor = Vector2i(1, 1)
	_world.placement._valid = true
	_world.placement._update_preview_xform()
	ui.place_btn.pressed.emit()
	_assert(_world.placement.mode == PlacementController.Mode.IDLE, "touch Place confirms and exits mode")

	# Move path via begin_move + rotate + cancel
	var vis: FurnitureVisual = null
	for iid in _world._furniture.keys():
		vis = _world._furniture[iid]
		break
	if vis:
		_world.player.placement_locked = true
		_world.placement.begin_move(vis)
		_assert(_world.placement.mode == PlacementController.Mode.MOVE, "touch/select move mode")
		ui.rotate_btn.pressed.emit()
		ui.cancel_btn.pressed.emit()
		_assert(_world.placement.mode == PlacementController.Mode.IDLE, "touch cancel move")
		_assert(vis.visible, "original furniture restored after cancel move")

	# Camera look via touch pad drag simulation
	var before_yaw: float = float(_world.player.yaw)
	_world.player.add_touch_look(Vector2(40, 0))
	_world.player._physics_process(0.016)
	_assert(not is_equal_approx(float(_world.player.yaw), before_yaw), "touch look rotates camera yaw")

	# Move stick API
	_world.player.set_touch_move(Vector2(1, 0))
	_assert(_world.player.touch_move.x > 0.5, "touch move stick sets vector")
	_world.player.set_touch_move(Vector2.ZERO)

	print("=== Touch Results: %d passed, %d failed ===" % [passed, failed])
	if OS.get_environment("COZY_HOUSE_TOUCH_QUIT") == "1" or OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(1 if failed > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)
