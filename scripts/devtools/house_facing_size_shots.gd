extends Node
## Capture house facing + height + size-tier screenshots.
## COZY_HOUSE_FACING_SIZE_SHOTS=1 COZY_NET_AUTOSTART=0 COZY_SMOKE_QUIT=1 \
##   xvfb-run -a godot --path . res://scenes/house/house.tscn \
##   --rendering-method gl_compatibility --rendering-driver opengl3

func _ready() -> void:
	if OS.get_environment("COZY_HOUSE_FACING_SIZE_SHOTS") != "1":
		queue_free()
		return
	await get_tree().create_timer(1.2).timeout
	var house: Node = get_parent()
	var player: ThirdPersonController = house.get_node("Player")
	var space: HouseSpace = house.get_node("HouseSpace")
	var ui: HouseUi = house.get_node("HouseUI")
	var out := OS.get_environment("COZY_SHOT_DIR")
	if out == "":
		out = "/opt/cursor/artifacts/screenshots/house_facing_size"
	DirAccess.make_dir_recursive_absolute(out)

	# Offline furniture so the room isn't empty.
	if house.has_method("_rebuild_furniture"):
		house._rebuild_furniture([
			{"instance_id": "shot_chair", "def_id": "chair", "cell_x": 4, "cell_z": 5, "rotation": 0},
			{"instance_id": "shot_table", "def_id": "table", "cell_x": 6, "cell_z": 5, "rotation": 0},
			{"instance_id": "shot_shelf", "def_id": "bookshelf", "cell_x": 2, "cell_z": 3, "rotation": 90},
		])

	# Camera behind the character looking into the room (−Z).
	player.global_position = Vector3(6.0, 0.0, 8.5)
	player.yaw = 0.0
	player.pitch = deg_to_rad(-12)
	player.pivot.rotation.y = player.yaw
	player.pivot.rotation.x = player.pitch
	player.cam_distance = 3.6
	player.spring.spring_length = player.cam_distance

	# Walking away from camera (−Z): back of avatar should be visible.
	player.face_direction(Vector3(0, 0, -1))
	for _i in 12:
		player._physics_process(0.016)
		await get_tree().physics_frame
	await _shot(out.path_join("facing_walk_away_back.png"))

	# Walking toward the camera (+Z): face should be visible.
	player.face_direction(Vector3(0, 0, 1))
	for _i in 8:
		player._physics_process(0.016)
		await get_tree().physics_frame
	await _shot(out.path_join("facing_walk_toward.png"))

	# Taller room — pitch up toward beams/ceiling with character mid-room facing away.
	player.global_position = Vector3(6.0, 0.0, 6.5)
	player.yaw = 0.0
	player.pitch = deg_to_rad(-35)
	player.pivot.rotation.y = player.yaw
	player.pivot.rotation.x = player.pitch
	player.cam_distance = 5.0
	player.spring.spring_length = player.cam_distance
	player.face_direction(Vector3(0, 0, -1))
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out.path_join("taller_room.png"))
	print("[HOUSE_SHOTS] wall_h=", HouseSpace.WALL_H, " ceiling=", space.ceiling_y(), " door=", space.door_clearance())

	# Each size tier: apply, show room, then open size panel for UI proof.
	for tier in HouseLayout.SIZE_ORDER:
		if house.has_method("apply_house_size_local"):
			house.apply_house_size_local(tier)
		await get_tree().process_frame
		await get_tree().process_frame
		if house.has_method("_rebuild_furniture"):
			house._rebuild_furniture([
				{"instance_id": "shot_chair", "def_id": "chair", "cell_x": 4, "cell_z": 5, "rotation": 0},
				{"instance_id": "shot_table", "def_id": "table", "cell_x": 6, "cell_z": 5, "rotation": 0},
				{"instance_id": "shot_shelf", "def_id": "bookshelf", "cell_x": 2, "cell_z": 3, "rotation": 90},
			])
		player.global_position = space.spawn_position()
		player.yaw = 0.65
		player.pitch = deg_to_rad(-20)
		player.pivot.rotation.y = player.yaw
		player.pivot.rotation.x = player.pitch
		player.cam_distance = 5.5 if tier != HouseLayout.SIZE_SMALL else 4.2
		player.spring.spring_length = player.cam_distance
		player.face_direction(Vector3(sin(player.yaw), 0, -cos(player.yaw)).normalized())
		if ui:
			ui.refresh_size_chip(tier)
			ui.panels.close_all()
		await get_tree().process_frame
		await _shot(out.path_join("house_size_%s.png" % tier))
		if ui:
			ui._is_owner = true
			ui.open_size_panel()
			await get_tree().process_frame
			await _shot(out.path_join("house_size_%s_panel.png" % tier))
			ui.panels.close("size")

	print("[HOUSE_SHOTS] done → ", out)
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		get_tree().quit(0)


func _shot(path: String) -> void:
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[HOUSE_SHOTS] ", path)
