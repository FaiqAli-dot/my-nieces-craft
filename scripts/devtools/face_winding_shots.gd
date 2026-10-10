extends Node
## Visual proof that block faces are solid from front/side/above.
## COZY_FACE_SHOTS=1 godot --path . --resolution 1280x720 \
##   --rendering-method gl_compatibility --rendering-driver opengl3

func _ready() -> void:
	if OS.get_environment("COZY_FACE_SHOTS") != "1":
		queue_free()
		return
	await get_tree().create_timer(2.0).timeout
	await _capture()
	get_tree().quit(0)


func _capture() -> void:
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var ui: GameUi = main.get_node("GameUI")
	ui.touch_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "/opt/cursor/artifacts/screenshots/face_winding_fix"
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Build a small solid tower of mixed blocks for multi-angle proof.
	var cx := 36
	var cz := 30
	var gy := VoxelWorld.GROUND_Y
	var wood := BlockDB.get_id("wood")
	var stone := BlockDB.get_id("stone")
	var pink := BlockDB.get_id("wool_pink")
	var yellow := BlockDB.get_id("wool_yellow")
	var planks := BlockDB.get_id("planks")
	for x in range(cx, cx + 3):
		for z in range(cz, cz + 2):
			world.set_block(x, gy, z, planks, true)
	world.set_block(cx, gy + 1, cz, yellow, true)
	world.set_block(cx + 1, gy + 1, cz, stone, true)
	world.set_block(cx + 2, gy + 1, cz, pink, true)
	world.set_block(cx + 1, gy + 2, cz, wood, true)
	world.set_block(cx + 1, gy + 1, cz + 1, wood, true)
	# Occlusion probe: pink BEHIND yellow — if yellow front is solid, pink must not show through.
	world.set_block(cx, gy + 1, cz - 1, pink, true)

	var focus := Vector3(cx + 1.0, gy + 1.5, cz + 0.5)
	# Existing world pad + corner wool (voxel_world gen around 32–42).
	var house := Vector3(36.5, float(gy) + 1.5, 36.5)
	var shots := [
		# name, cam_pos, pitch, optional focus override
		["13_faces_front.png", Vector3(cx + 1.0, gy + 2.0, cz + 5.5), -0.12, focus],
		["14_faces_side.png", Vector3(cx + 5.5, gy + 2.0, cz + 0.8), -0.10, focus],
		["15_faces_above.png", Vector3(cx + 1.0, gy + 6.5, cz + 4.0), -0.95, focus],
		["16_faces_placed_wood.png", Vector3(cx + 1.0, gy + 1.8, cz + 4.2), -0.18, focus],
		# Straight-on at yellow; pink sits one cell behind. Solid front ⇒ yellow; hollow ⇒ pink.
		["17_occlusion_probe.png", Vector3(float(cx) + 0.5, float(gy) + 1.55, float(cz) + 3.5), 0.0, Vector3(float(cx) + 0.5, float(gy) + 1.5, float(cz) + 0.5)],
		["18_world_pad_front.png", Vector3(36.5, float(gy) + 2.2, 44.0), -0.18, house],
		["19_world_pad_side.png", Vector3(44.0, float(gy) + 2.2, 36.5), -0.15, house],
		["20_world_pad_above.png", Vector3(36.5, float(gy) + 8.0, 42.0), -0.95, house],
	]
	# Camera is on Head at local y≈1.55 — subtract so requested cam_pos is eye position.
	var eye_offset_y := 1.55
	for s in shots:
		var cam_pos: Vector3 = s[1]
		var pitch: float = s[2]
		var look_at: Vector3 = s[3]
		var to := (look_at - cam_pos).normalized()
		var yaw := atan2(-to.x, -to.z)
		if str(s[0]).begins_with("17_"):
			pitch = -asin(clampf(to.y, -0.99, 0.99))
		player.global_position = Vector3(cam_pos.x, cam_pos.y - eye_offset_y, cam_pos.z)
		player.look_yaw = yaw
		player.look_pitch = pitch
		player.head.rotation.y = yaw
		player.camera.rotation.x = pitch
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = out_dir.path_join(s[0])
		img.save_png(path)
		print("[FACE_SHOTS] ", path)
	print("[FACE_SHOTS] done")
