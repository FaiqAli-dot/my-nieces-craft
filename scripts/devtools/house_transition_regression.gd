extends Node
## Ten consecutive meadow↔house transitions without a stuck disconnecting state.
## Single root-level runner (survives change_scene_to_file).

const CYCLES := 10
const RUNNER_NAME := "CozyTransitionRegression"


func _ready() -> void:
	call_deferred("_reparent_and_start")


func _reparent_and_start() -> void:
	var tree := get_tree()
	if tree == null:
		return
	# Only one runner may exist on the root.
	var existing := tree.root.get_node_or_null(RUNNER_NAME)
	if existing != null and existing != self:
		queue_free()
		return
	name = RUNNER_NAME
	if get_parent() != tree.root:
		var parent := get_parent()
		if parent:
			parent.remove_child(self)
		tree.root.add_child(self)
	await _run()


func _scene_path_ends(suffix: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and str(scene.scene_file_path).ends_with(suffix)


func _house_status_text() -> String:
	if not _scene_path_ends("house.tscn"):
		return ""
	var house := get_tree().current_scene
	if house == null or not ("ui" in house):
		return ""
	var ui = house.ui
	if ui == null or not is_instance_valid(ui):
		return ""
	if not ("status_chip" in ui) or ui.status_chip == null:
		return ""
	return str(ui.status_chip.text)


func _run() -> void:
	var failures := 0
	if not _scene_path_ends("house.tscn"):
		SceneFlow.go_to_house()
		if not await _wait_scene("house.tscn"):
			print("TRANSITION FAIL: could not open house")
			get_tree().quit(1)
			return

	for i in CYCLES:
		var st := _house_status_text().to_lower()
		if st.find("disconnect") >= 0:
			failures += 1
			print("TRANSITION FAIL cycle %d pre-leave status=%s" % [i + 1, st])

		var house := get_tree().current_scene
		if house and house.has_method("go_voxel_world"):
			house.go_voxel_world()
		else:
			SceneFlow.return_to_meadow()

		if not await _wait_scene("main.tscn"):
			failures += 1
			print("TRANSITION FAIL cycle %d meadow missing" % [i + 1])
			break

		var net := NetClient.connection_status()
		if net in ["connecting", "closing", "connected"]:
			failures += 1
			print("TRANSITION FAIL cycle %d net=%s on meadow" % [i + 1, net])

		var meadow := get_tree().current_scene
		var player: Node = meadow.get_node_or_null("Player") if meadow else null
		SceneFlow.go_to_house(player)
		if not await _wait_scene("house.tscn"):
			failures += 1
			print("TRANSITION FAIL cycle %d house re-enter missing" % [i + 1])
			break

		await get_tree().process_frame
		await get_tree().process_frame
		st = _house_status_text().to_lower()
		if st.begins_with("disconnect"):
			failures += 1
			print("TRANSITION FAIL cycle %d house status=%s" % [i + 1, st])
		print("TRANSITION PASS cycle %d" % [i + 1])

	if failures == 0:
		print("TRANSITION RESULTS: %d/%d cycles OK" % [CYCLES, CYCLES])
		get_tree().quit(0)
	else:
		print("TRANSITION RESULTS: failures=%d" % failures)
		get_tree().quit(1)


func _wait_scene(suffix: String) -> bool:
	for _i in 300:
		await get_tree().process_frame
		if _scene_path_ends(suffix):
			await get_tree().process_frame
			return true
	return false
