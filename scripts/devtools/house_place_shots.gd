extends Node
## Screenshots: placed bed, green ghost, red ghost + toast.
## COZY_HOUSE_PLACE_SHOTS=1 COZY_NET_AUTOSTART=0 COZY_SMOKE_QUIT=1 \
##   xvfb-run -a godot --path . res://scenes/house/house.tscn ...

func _ready() -> void:
	if OS.get_environment("COZY_HOUSE_PLACE_SHOTS") != "1":
		queue_free()
		return
	await get_tree().create_timer(1.0).timeout
	var house: Node = get_parent()
	var player: ThirdPersonController = house.player
	var ui: HouseUi = house.ui
	var placement: PlacementController = house.placement
	var out := OS.get_environment("COZY_SHOT_DIR")
	if out == "":
		out = "/opt/cursor/artifacts/screenshots/house_place"
	DirAccess.make_dir_recursive_absolute(out)

	if house.has_method("_enter_offline_mode") and not house.is_offline_mode():
		house._enter_offline_mode("Offline demo")
	house._rebuild_furniture([])
	placement.set_instances(house._furniture)
	placement.can_decorate = true

	player.global_position = Vector3(6.0, 0.0, 9.0)
	player.yaw = 0.15
	player.pitch = deg_to_rad(-16)
	player.pivot.rotation.y = player.yaw
	player.pivot.rotation.x = player.pitch
	player.face_direction(Vector3(0, 0, -1))

	# Green ghost preview for bed.
	house.start_place("bed")
	await get_tree().process_frame
	for _i in 8:
		placement._physics_process(0.016)
		await get_tree().physics_frame
	placement._anchor = Vector2i(4, 4)
	placement._valid = true
	placement._last_reason = FurnitureValidator.Reason.OK
	placement._update_preview_xform()
	placement._tint(true)
	await _shot(out.path_join("place_ghost_valid_green.png"))

	# Confirm place → bed in room.
	ui.place_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.toast("Placed Bed!")
	await _shot(out.path_join("place_bed_placed.png"))

	# Red ghost overlapping the bed + kid-friendly toast.
	house.start_place("table")
	await get_tree().process_frame
	placement._anchor = Vector2i(4, 4)
	placement._valid = false
	placement._last_reason = FurnitureValidator.Reason.OVERLAP
	placement._update_preview_xform()
	placement._tint(false)
	GameState.toast(FurnitureValidator.reason_text(FurnitureValidator.Reason.OVERLAP))
	await get_tree().process_frame
	await _shot(out.path_join("place_ghost_invalid_red.png"))

	print("[HOUSE_PLACE_SHOTS] done → ", out)
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)


func _shot(path: String) -> void:
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[HOUSE_PLACE_SHOTS] ", path)
