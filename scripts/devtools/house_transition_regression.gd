extends Node
## Ten consecutive meadow↔house transitions without a stuck disconnecting state.
## Reparents onto the SceneTree root so it survives change_scene_to_file.

const CYCLES := 10


func _ready() -> void:
	# Survive house→meadow scene swaps.
	if get_parent() != get_tree().root:
		var keep := self
		get_parent().remove_child(keep)
		get_tree().root.add_child(keep)
		keep.call_deferred("_start")
		return
	await _start()


func _start() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var failures := 0
	# Ensure we start from the house scene.
	if get_tree().current_scene == null or not str(get_tree().current_scene.scene_file_path).ends_with("house.tscn"):
		SceneFlow.go_to_house()
		if not await _wait_scene("house.tscn"):
			print("TRANSITION FAIL: could not open house")
			get_tree().quit(1)
			return

	for i in CYCLES:
		var house := get_tree().current_scene
		if house and house.get("ui") != null and is_instance_valid(house.ui) and house.ui.status_chip:
			var st := str(house.ui.status_chip.text).to_lower()
			if st.find("disconnect") >= 0:
				failures += 1
				print("TRANSITION FAIL cycle %d pre-leave status=%s" % [i + 1, house.ui.status_chip.text])
		if house and house.has_method("go_voxel_world"):
			house.go_voxel_world()
		else:
			SceneFlow.return_to_meadow()
		if not await _wait_scene("main.tscn"):
			failures += 1
			print("TRANSITION FAIL cycle %d meadow missing" % [i + 1])
			break
		if NetClient.connection_status() in ["connecting", "closing"]:
			failures += 1
			print("TRANSITION FAIL cycle %d net=%s on meadow" % [i + 1, NetClient.connection_status()])
		# Stuck reconnect toast path should be idle after intentional leave.
		if NetClient.connection_status() != "idle" and NetClient.connection_status() != "offline":
			# connected would be wrong on meadow
			if NetClient.connection_status() == "connected":
				failures += 1
				print("TRANSITION FAIL cycle %d still connected on meadow" % [i + 1])
		var meadow := get_tree().current_scene
		SceneFlow.go_to_house(meadow.get_node_or_null("Player") if meadow else null)
		if not await _wait_scene("house.tscn"):
			failures += 1
			print("TRANSITION FAIL cycle %d house re-enter missing" % [i + 1])
			break
		await get_tree().process_frame
		await get_tree().process_frame
		house = get_tree().current_scene
		if house and house.get("ui") != null and is_instance_valid(house.ui) and house.ui.status_chip:
			var st2 := str(house.ui.status_chip.text).to_lower()
			if st2.begins_with("disconnect"):
				failures += 1
				print("TRANSITION FAIL cycle %d house status=%s" % [i + 1, house.ui.status_chip.text])
		print("TRANSITION PASS cycle %d" % [i + 1])

	if failures == 0:
		print("TRANSITION RESULTS: %d/%d cycles OK" % [CYCLES, CYCLES])
		get_tree().quit(0)
	else:
		print("TRANSITION RESULTS: failures=%d" % failures)
		get_tree().quit(1)


func _wait_scene(suffix: String) -> bool:
	for _i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene and str(scene.scene_file_path).ends_with(suffix):
			await get_tree().process_frame
			return true
	return false
