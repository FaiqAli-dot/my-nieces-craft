extends Node
## House-side Phase 2 build shots: catalog, green/red preview, rotate, undo.
## COZY_PHASE2_HOUSE_SHOTS=1 COZY_PHASE2_BUILD_QUIT=1

var _dir: String
var _house: Node


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_dir = OS.get_environment("COZY_SHOT_DIR")
	if _dir == "":
		_dir = "/opt/cursor/artifacts/phase2_build"
	DirAccess.make_dir_recursive_absolute(_dir)
	_apply_viewport_size()
	_house = get_parent()
	if _house == null or not _house.has_method("start_place"):
		push_error("phase2_house_build_shots: bad parent")
		_quit(1)
		return
	# Ensure offline decorate
	if _house.has_method("_enter_offline_mode") and _house.get("_offline_mode") == false:
		_house._enter_offline_mode("Offline demo")
	await get_tree().process_frame
	await _run()
	_quit(0)


func _apply_viewport_size() -> void:
	var spec := OS.get_environment("COZY_SHOT_SIZE")
	if spec == "":
		spec = "1792x828"
	var parts := spec.split("x")
	if parts.size() != 2:
		return
	DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	get_viewport().size = Vector2i(int(parts[0]), int(parts[1]))


func _run() -> void:
	var tag := OS.get_environment("COZY_SHOT_TAG")
	if tag == "":
		tag = "house_phone"
	var ui = _house.ui
	var placement = _house.placement
	ui.open_catalog()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("08_house_catalog_%s.png" % tag)

	ui.panels.close("catalog")
	_house.start_place("chair")
	await get_tree().process_frame
	placement._anchor = Vector2i(3, 3)
	placement._valid = true
	placement._last_reason = FurnitureValidator.Reason.OK
	placement._update_preview_xform()
	placement._tint(true)
	await get_tree().process_frame
	await _shot("09_house_preview_valid_%s.png" % tag)

	placement._valid = false
	placement._last_reason = FurnitureValidator.Reason.OVERLAP
	placement._tint(false)
	await get_tree().process_frame
	await _shot("10_house_preview_invalid_%s.png" % tag)

	placement._valid = true
	placement._last_reason = FurnitureValidator.Reason.OK
	placement._tint(true)
	placement.rotate_preview(1)
	await get_tree().process_frame
	await _shot("11_house_preview_rotated_%s.png" % tag)

	placement.confirm()
	await get_tree().process_frame
	_house.cancel_placement()
	await get_tree().process_frame

	# Select + move/copy/remove toolbar context
	if not _house._furniture.is_empty():
		var iid := str(_house._furniture.keys()[0])
		_house._set_selected(iid)
	ui.open_catalog()
	await get_tree().process_frame
	await _shot("12_house_tools_catalog_%s.png" % tag)
	ui.panels.close_all()

	_house.undo_build()
	await get_tree().process_frame
	await _shot("13_house_after_undo_%s.png" % tag)
	_house.redo_build()
	await get_tree().process_frame
	await _shot("14_house_after_redo_%s.png" % tag)


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var path := _dir.path_join(name)
	img.save_png(path)
	print("SHOT: ", path)


func _quit(code: int) -> void:
	if OS.get_environment("COZY_PHASE2_BUILD_QUIT") == "1" or OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(code)
