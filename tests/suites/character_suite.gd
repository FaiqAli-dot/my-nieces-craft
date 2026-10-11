extends Node
## Milestone B — CozyCharacter rig/animation, remote avatars, meadow behind-view.

var runner: Node


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[character] " + msg)


func run() -> void:
	await _test_rig_proportions()
	await _test_locomotion_animation()
	await _test_actions_and_feedback()
	await _test_held_item()
	await _test_remote_avatar()
	await _test_house_controller_uses_character()
	await _test_meadow_behind_view()


func _step(c: CozyCharacter, frames: int, dt: float = 1.0 / 60.0) -> void:
	for i in frames:
		c._process(dt)


func _mesh_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.mesh != null and n.visible:
			var box: AABB = (n as MeshInstance3D).global_transform * n.mesh.get_aabb()
			if first:
				out = box
				first = false
			else:
				out = out.merge(box)
	return out


func _test_rig_proportions() -> void:
	var c := CozyCharacter.new()
	add_child(c)
	await get_tree().process_frame
	var box := _mesh_aabb(c)
	check(absf(box.position.y) < 0.05, "feet rest at y=0 (got %.2f)" % box.position.y)
	check(box.end.y > 1.6 and box.end.y < 1.95, "height ~1.75m fits 1.8 capsule (got %.2f)" % box.end.y)
	check(box.size.x < 0.9 and box.size.z < 0.9, "silhouette fits capsule footprint")
	check(c.get_node_or_null("Body/Torso/Head/Face") != null, "has drawn face")
	check(c.face_state() == "open", "eyes open at rest")
	# Faces +Z: face quad sits in front of the head centre.
	var face: Node3D = c.get_node("Body/Torso/Head/Face")
	check(face.global_position.z > 0.2, "faces +Z like ThirdPersonController expects")
	c.queue_free()
	await get_tree().process_frame


func _test_locomotion_animation() -> void:
	var c := CozyCharacter.new()
	add_child(c)
	await get_tree().process_frame
	_step(c, 30)
	var idle := c.limb_angles()
	check(absf(idle["leg_l"]) < 0.05 and absf(idle["leg_r"]) < 0.05, "idle legs at rest")
	var max_swing := 0.0
	var opposite := true
	c.set_locomotion(4.2, true, 0.0)
	for i in 40:
		c._process(1.0 / 60.0)
		var a := c.limb_angles()
		max_swing = maxf(max_swing, absf(a["leg_l"]))
		if absf(a["leg_l"]) > 0.15 and signf(a["leg_l"]) == signf(a["leg_r"]):
			opposite = false
	check(max_swing > 0.35, "walking swings legs (%.2f)" % max_swing)
	check(opposite, "legs alternate while walking")
	var run_swing := 0.0
	c.set_locomotion(6.4, true, 0.0, true)
	for i in 40:
		c._process(1.0 / 60.0)
		run_swing = maxf(run_swing, absf(c.limb_angles()["leg_l"]))
	check(run_swing > max_swing, "running strides wider than walking")
	c.set_locomotion(0.0, false, 5.0)
	_step(c, 20)
	check(c.limb_angles()["arm_l"] < -1.5, "jump pose raises arms")
	c.set_locomotion(0.0, false, -8.0)
	_step(c, 5)
	c.set_locomotion(0.0, true, -8.0)
	c._process(1.0 / 60.0)
	check(c.scale.y < 0.97, "landing squashes (%.3f)" % c.scale.y)
	_step(c, 30)
	check(absf(c.scale.y - 1.0) < 0.01, "squash recovers")
	c.set_locomotion(0.0, true, 0.0)
	_step(c, 40)
	check(absf(c.limb_angles()["leg_l"]) < 0.08, "returns to idle smoothly")
	c.queue_free()
	await get_tree().process_frame


func _test_actions_and_feedback() -> void:
	var c := CozyCharacter.new()
	add_child(c)
	await get_tree().process_frame
	_step(c, 10)
	c.play_action("swing")
	var lowest := 0.0
	for i in 20:
		c._process(1.0 / 60.0)
		lowest = minf(lowest, c.limb_angles()["arm_r"])
	check(lowest < -1.2, "swing lifts the tool arm (%.2f)" % lowest)
	_step(c, 40)
	check(c.limb_angles()["arm_r"] > -0.4, "swing settles back")
	c.set_mining(true)
	var swings := 0
	var was_up := false
	for i in 120:
		c._process(1.0 / 60.0)
		var up: bool = c.limb_angles()["arm_r"] < -1.2
		if up and not was_up:
			swings += 1
		was_up = up
	check(swings >= 3, "mining repeats swings (%d in 2s)" % swings)
	c.set_mining(false)
	c.play_action("hurt")
	c._process(1.0 / 60.0)
	check(c.face_state() == "hurt", "hurt face shows")
	_step(c, 40)
	check(c.face_state() != "hurt", "hurt face clears")
	c.play_action("cheer")
	c._process(1.0 / 60.0)
	check(c.face_state() == "happy", "cheer is happy")
	# Blink happens within a few seconds.
	var blinked := false
	for i in 400:
		c._process(1.0 / 60.0)
		if c.face_state() == "closed":
			blinked = true
			break
	check(blinked, "idle blink")
	c.queue_free()
	await get_tree().process_frame


func _test_held_item() -> void:
	var c := CozyCharacter.new()
	add_child(c)
	await get_tree().process_frame
	var hand := c.get_node("Body/Torso/ArmR/HandR")
	c.set_held_item("wooden_pickaxe")
	check(hand.get_node_or_null("Held") != null and hand.get_node("Held").get_child_count() >= 3, "pickaxe modelled in hand")
	c.set_held_item("grass")
	await get_tree().process_frame
	var held := hand.get_node_or_null("Held")
	check(held != null and held.get_child_count() == 1, "block shows as mini cube")
	c.set_held_item("")
	await get_tree().process_frame
	check(hand.get_node_or_null("Held") == null, "empty hand")
	c.queue_free()
	await get_tree().process_frame


func _test_remote_avatar() -> void:
	var idx_a := RemotePlayer.look_index_for("pid_alice")
	check(idx_a == RemotePlayer.look_index_for("pid_alice"), "remote palette stable per player")
	var never_default := true
	for i in 50:
		if RemotePlayer.look_index_for("pid_%d" % i) == 0:
			never_default = false
	check(never_default, "friends never share the local default palette")
	var rp := RemotePlayer.new()
	rp.setup("pid_alice", "Alice")
	add_child(rp)
	rp.snap_to(Vector3(5, 0.1, 7))
	for i in 10:
		await get_tree().physics_frame
	check(rp.global_position.distance_to(Vector3(5, 0.1, 7)) < 0.01, "spawned remote stays put (no glide from origin)")
	check(rp.character != null, "remote uses CozyCharacter")
	rp.apply_state(Vector3(8, 0.1, 7), 1.2, true)
	for i in 30:
		await get_tree().physics_frame
	check(rp.global_position.x > 7.5, "remote interpolates to new position")
	check(absf(rp.character.rotation.y - 1.2) < 0.1, "remote faces sent yaw")
	rp.queue_free()
	await get_tree().process_frame


func _test_house_controller_uses_character() -> void:
	var p: ThirdPersonController = load("res://scenes/player/third_person_player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	check(p.character != null and p.character.get_parent() == p.model_root, "house player uses CozyCharacter")
	p.face_direction(Vector3(1, 0, 0))
	var fwd := ThirdPersonController.visual_forward_from_yaw(p.model_root.rotation.y)
	check(fwd.dot(Vector3(1, 0, 0)) > 0.99, "face_direction still aims +Z mesh")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.queue_free()
	await get_tree().process_frame


func _test_meadow_behind_view() -> void:
	OS.set_environment("COZY_SKIP_MODE_SELECT", "1")
	var main: Node3D = load("res://scenes/world/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	check(player.third_person == bool(Settings.DEFAULTS["third_person"]), "view comes from settings")
	player.set_third_person(true)

	# Clear an arena and stand the player in it, facing -Z.
	var g := VoxelWorld.GROUND_Y
	for x in range(18, 33):
		for z in range(10, 40):
			for y in range(g + 1, g + 12):
				world.set_block(x, y, z, 0, false)
			world.set_block(x, g, z, BlockDB.get_id("grass"), false)
	_rebuild_all(world)
	var stone := BlockDB.get_id("stone")
	world.set_block(25, g + 2, 22, stone, true)
	world.set_block(25, g + 3, 22, stone, true)
	player.global_position = Vector3(25.5, g + 1.0, 25.5)
	player.velocity = Vector3.ZERO
	player.look_yaw = 0.0
	player.look_pitch = 0.0
	for i in 6:
		await get_tree().physics_frame
	player.global_position = Vector3(25.5, g + 1.0, 25.5)
	player._physics_process(0.0)
	player._update_camera_rig()
	check(player.camera.position.length() > 2.0, "behind-view camera sits behind the eye (%.2f)" % player.camera.position.length())
	check(is_equal_approx(player.camera.rotation.x, player.look_pitch), "pitch contract kept for harnesses")
	check(player.avatar.visible, "avatar visible in behind-view")
	var t := player.get_target_block()
	check(t.x == 25 and t.z == 22 and (t.y == g + 2 or t.y == g + 3), "crosshair targets block in front (got %s)" % str(t))

	# Beyond eye reach but within camera ray length: must not target.
	world.set_block(25, g + 2, 22, 0, true)
	world.set_block(25, g + 3, 22, 0, true)
	world.set_block(25, g + 3, 25 - 8, stone, true)
	world.set_block(25, g + 2, 25 - 8, stone, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player._update_camera_rig()
	check(player.get_target_block().x == -9999, "no reach extension from behind-view")

	# Wall behind the player pulls the camera in (no seeing through terrain).
	for x in range(22, 29):
		for y in range(g + 1, g + 7):
			world.set_block(x, y, 27, stone, false)
	_rebuild_all(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player._update_camera_rig()
	check(player.camera.position.length() < 2.0, "camera pulled in by wall (%.2f)" % player.camera.position.length())

	# Eye view: model hidden, camera at eye, placement unchanged.
	player.set_third_person(false)
	check(player.camera.position == Vector3.ZERO, "eye view camera at the eye")
	check(not player.avatar.visible, "avatar hidden in eye view")
	# Toggle persists through Settings (runner redirects the file).
	player.toggle_view()
	check(player.third_person and bool(Settings.get_value("third_person")), "toggle saved")
	Settings.load_from_disk()
	check(bool(Settings.get_value("third_person")), "view survives reload")
	player.toggle_view()
	Settings.load_from_disk()
	check(not bool(Settings.get_value("third_person")), "eye view survives reload")
	player.set_third_person(true, true)

	# Held item follows the hotbar.
	var follows := true
	for i in 3:
		player.inventory.select(i)
		await get_tree().physics_frame
		if player.avatar.held_item != player.inventory.selected_item():
			follows = false
	check(follows, "avatar holds the selected hotbar item")

	# Creative flight still works with the behind-view.
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	GameState.set_flying(true)
	var y0 := player.global_position.y
	player.set_touch_fly_vertical(1.0)
	for i in 20:
		await get_tree().physics_frame
	player.set_touch_fly_vertical(0.0)
	check(player.global_position.y > y0 + 0.5, "creative flight rises in behind-view")
	GameState.set_flying(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.queue_free()
	await get_tree().process_frame
	OS.set_environment("COZY_SKIP_MODE_SELECT", "")


func _rebuild_all(world: VoxelWorld) -> void:
	for chunk in world.chunks.values():
		chunk.rebuild_mesh()
