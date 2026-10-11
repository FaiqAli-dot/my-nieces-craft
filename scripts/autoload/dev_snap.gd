extends Node
## Dev-only screenshot hook (no-op unless COZY_SNAP_PATH is set).
## COZY_SNAP_PATH=/tmp/a.png COZY_SNAP_FRAMES=90 godot --path . <scene>
## Optional COZY_SNAP_POSE: "yaw_deg,pitch_deg,x,y,z" to pose the current player first.

func _ready() -> void:
	var path := OS.get_environment("COZY_SNAP_PATH")
	if path == "":
		set_process(false)
		return
	_run(path)


func _run(path: String) -> void:
	var frames := int(OS.get_environment("COZY_SNAP_FRAMES")) if OS.get_environment("COZY_SNAP_FRAMES") != "" else 90
	for _i in frames:
		await get_tree().process_frame
	_apply_pose()
	for _i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SNAP] ", path)
	get_tree().quit(0)


func _apply_pose() -> void:
	var expr := OS.get_environment("COZY_SNAP_POSE")
	if expr == "":
		return
	var parts := expr.split(",")
	if parts.size() < 5:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player")
	if player == null:
		return
	player.global_position = Vector3(float(parts[2]), float(parts[3]), float(parts[4]))
	if "look_yaw" in player:
		player.look_yaw = deg_to_rad(float(parts[0]))
		player.look_pitch = deg_to_rad(float(parts[1]))
	elif "yaw" in player:
		player.yaw = deg_to_rad(float(parts[0]))
		player.pitch = deg_to_rad(float(parts[1]))
